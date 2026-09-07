import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/presentation/word/widgets/animated_word_card.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

enum _Side { front, back }

class WordCreatePage extends ConsumerStatefulWidget {
  const WordCreatePage({super.key, required this.folderId});

  final String folderId;

  @override
  ConsumerState<WordCreatePage> createState() => _WordCreatePageState();
}

class _WordCreatePageState extends ConsumerState<WordCreatePage> {
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  _Side? _expandedSide;
  bool _showValidationError = false;
  // 表の「保存」はDBへは反映せず、確定した表の値をここに保持するだけにする。
  // 確定後に表の内容が変更された場合は再確定が必要（現在値と一致しなくなるため）。
  String? _confirmedFrontText;

  @override
  void initState() {
    super.initState();
    // 保存ボタンの表示切り替え（入力有無）を再描画に反映させるため監視する
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

  bool get _canConfirmFront => _frontController.text.trim().isNotEmpty;
  bool get _canSaveBack => _backController.text.trim().isNotEmpty;
  bool get _isFrontConfirmed =>
      _confirmedFrontText != null && _confirmedFrontText == _frontController.text.trim();

  void _expandFront() => setState(() {
        _expandedSide = _Side.front;
        _showValidationError = false;
      });

  Future<void> _expandBack() async {
    if (!_isFrontConfirmed) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('入力が未完了です'),
          content: const Text('表カードの入力を完了させてください'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _expandedSide = _Side.back;
      _showValidationError = false;
    });
  }

  void _collapse() => setState(() {
        _expandedSide = null;
        _showValidationError = false;
      });

  void _dismissValidationError() => setState(() => _showValidationError = false);

  // 表側の「保存」はDB更新をせず、値を確定させて裏側の入力に進めるだけ
  Future<void> _confirmFront() async {
    if (!_canConfirmFront) {
      setState(() => _showValidationError = true);
      return;
    }
    setState(() {
      _confirmedFrontText = _frontController.text.trim();
      _expandedSide = null;
      _showValidationError = false;
    });
  }

  // 裏側の「保存」で初めてローカルDB・リモートDBへ実際に登録する
  Future<void> _saveBack() async {
    if (!_canSaveBack) {
      setState(() => _showValidationError = true);
      return;
    }
    final front = _confirmedFrontText ?? _frontController.text.trim();
    final back = _backController.text.trim();
    final controller = ref.read(wordListViewModelProvider(widget.folderId).notifier);
    await controller.createWord(front: front, back: back);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wordListViewModelProvider(widget.folderId), (prev, next) {
      if (next is! AsyncError) return;
      if (prev is AsyncError) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('追加に失敗しました')));
    });

    return PopScope(
      canPop: _expandedSide == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _collapse();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('単語を追加')),
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
                      showSaveButton: _canConfirmFront,
                      showValidationError: _showValidationError,
                      onTap: _expandFront,
                      onClose: _collapse,
                      onSave: _confirmFront,
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
                      showSaveButton: _canSaveBack,
                      showValidationError: _showValidationError,
                      onTap: _expandBack,
                      onClose: _collapse,
                      onSave: _saveBack,
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
