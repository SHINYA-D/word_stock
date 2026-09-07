import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/word/widgets/animated_word_card.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

enum _Side { front, back }

class WordEditPage extends ConsumerStatefulWidget {
  const WordEditPage({
    super.key,
    required this.folderId,
    required this.word,
  });

  final String folderId;
  final Word word;

  @override
  ConsumerState<WordEditPage> createState() => _WordEditPageState();
}

class _WordEditPageState extends ConsumerState<WordEditPage> {
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  late String _savedFront;
  late String _savedBack;
  _Side? _expandedSide;
  String _preExpandFront = '';
  String _preExpandBack = '';
  bool _showValidationError = false;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.word.front);
    _backController = TextEditingController(text: widget.word.back);
    _savedFront = widget.word.front;
    _savedBack = widget.word.back;
    // 入力中の差分の有無（保存ボタンの表示切り替え）を再描画に反映させるため監視する
    _frontController.addListener(_onTextChanged);
    _backController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _frontController.removeListener(_onTextChanged);
    _backController.removeListener(_onTextChanged);
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _isDirty =>
      _frontController.text != _savedFront || _backController.text != _savedBack;

  void _expand(_Side side) {
    setState(() {
      _preExpandFront = _frontController.text;
      _preExpandBack = _backController.text;
      _expandedSide = side;
      _showValidationError = false;
    });
  }

  void _collapse({required bool discard}) {
    setState(() {
      if (discard) {
        _frontController.text = _preExpandFront;
        _backController.text = _preExpandBack;
      }
      _expandedSide = null;
      _showValidationError = false;
    });
  }

  void _dismissValidationError() => setState(() => _showValidationError = false);

  Future<void> _save() async {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();
    if (front.isEmpty || back.isEmpty) {
      setState(() => _showValidationError = true);
      return;
    }
    final controller = ref.read(wordListViewModelProvider(widget.folderId).notifier);
    await controller.updateWord(wordId: widget.word.id, front: front, back: back);
    if (!mounted) return;
    setState(() {
      _savedFront = front;
      _savedBack = back;
      _expandedSide = null;
      _showValidationError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wordListViewModelProvider(widget.folderId), (prev, next) {
      if (next is! AsyncError) return;
      if (prev is AsyncError) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
    });

    return PopScope(
      canPop: _expandedSide == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _collapse(discard: true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('単語を編集')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 16.0;
                final availableHeight = constraints.maxHeight;
                final collapsedHeight = (availableHeight - gap) / 2;

                final frontHeight = switch (_expandedSide) {
                  _Side.front => availableHeight,
                  _Side.back => 0.0,
                  null => collapsedHeight,
                };
                final backHeight = switch (_expandedSide) {
                  _Side.front => 0.0,
                  _Side.back => availableHeight,
                  null => collapsedHeight,
                };

                return Column(
                  children: [
                    AnimatedWordCard(
                      height: frontHeight,
                      fullHeight: availableHeight,
                      label: '表',
                      controller: _frontController,
                      expanded: _expandedSide == _Side.front,
                      showSaveButton: _isDirty,
                      showValidationError: _showValidationError,
                      onTap: () => _expand(_Side.front),
                      onClose: () => _collapse(discard: true),
                      onSave: _save,
                      onDismissValidationError: _dismissValidationError,
                    ),
                    AnimatedContainer(
                      duration: AnimatedWordCard.animationDuration,
                      curve: AnimatedWordCard.animationCurve,
                      height: _expandedSide == null ? gap : 0,
                    ),
                    AnimatedWordCard(
                      height: backHeight,
                      fullHeight: availableHeight,
                      label: '裏',
                      controller: _backController,
                      expanded: _expandedSide == _Side.back,
                      showSaveButton: _isDirty,
                      showValidationError: _showValidationError,
                      onTap: () => _expand(_Side.back),
                      onClose: () => _collapse(discard: true),
                      onSave: _save,
                      onDismissValidationError: _dismissValidationError,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
