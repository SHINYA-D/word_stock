import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:word_stock/core/router/router.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/flashcard_mode/flashcard_mode_state.dart';
import 'package:word_stock/presentation/flashcard_mode/flashcard_mode_view_model.dart';

class FlashcardModePage extends ConsumerStatefulWidget {
  const FlashcardModePage({
    super.key,
    required this.folderId,
    required this.words,
    required this.shuffle,
    required this.folderName,
    required this.userId,
  });

  final String folderId;
  final List<Word> words;
  final bool shuffle;
  final String folderName;
  final String userId;

  @override
  ConsumerState<FlashcardModePage> createState() => _FlashcardModePageState();
}

class _FlashcardModePageState extends ConsumerState<FlashcardModePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flipAnimation;
  bool _hasFlippedOnce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _flipAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flashcardModeViewModelProvider.notifier).start(
            words: widget.words,
            shuffle: widget.shuffle,
            userId: widget.userId,
            folderId: widget.folderId,
          );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _flip(FlashcardModeViewModel vm) async {
    if (_controller.isAnimating) return;
    await _controller.animateTo(0.5);
    vm.flip();
    setState(() => _hasFlippedOnce = true);
    await _controller.animateTo(1.0);
    _controller.reset();
  }

  void _resetFlipForNext() {
    _controller.reset();
    setState(() => _hasFlippedOnce = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(flashcardModeViewModelProvider);
    final vm = ref.read(flashcardModeViewModelProvider.notifier);

    ref.listen<FlashcardModeState>(flashcardModeViewModelProvider, (prev, next) {
      if (!next.isFinished) return;
      if (prev?.isFinished ?? false) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        FlashcardModeResultRoute(
          correctCount: next.correctCount,
          total: next.total,
        ).pushReplacement(context);
      });
    });

    ref.listen<FlashcardModeState>(flashcardModeViewModelProvider, (prev, next) {
      if (next.errorMessage == null) return;
      if (prev?.errorMessage == next.errorMessage) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('テストを中断しますか？'),
            content: const Text('途中の結果は保存されません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('続ける'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('中断する'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: SafeArea(
          child: Builder(
            builder: (context) {
              if (!state.isStarted || state.isFinished) {
                return const Center(child: CircularProgressIndicator());
              }
              return _InProgressView(
                word: state.currentWord!,
                currentIndex: state.currentIndex,
                total: state.total,
                isFlipped: state.isFlipped,
                hasFlippedOnce: _hasFlippedOnce,
                isSubmitting: state.isSubmitting,
                flipAnimation: _flipAnimation,
                onFlip: () => _flip(vm),
                onCorrect: () {
                  _resetFlipForNext();
                  vm.answer(isCorrect: true);
                },
                onIncorrect: () {
                  _resetFlipForNext();
                  vm.answer(isCorrect: false);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InProgressView extends StatelessWidget {
  const _InProgressView({
    required this.word,
    required this.currentIndex,
    required this.total,
    required this.isFlipped,
    required this.hasFlippedOnce,
    required this.isSubmitting,
    required this.flipAnimation,
    required this.onFlip,
    required this.onCorrect,
    required this.onIncorrect,
  });

  final Word word;
  final int currentIndex;
  final int total;
  final bool isFlipped;
  final bool hasFlippedOnce;
  final bool isSubmitting;
  final Animation<double> flipAnimation;
  final VoidCallback onFlip;
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${currentIndex + 1} / $total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _confirmExit(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / total,
                  minHeight: 6,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: GestureDetector(
              onTap: onFlip,
              child: AnimatedBuilder(
                animation: flipAnimation,
                builder: (context, _) {
                  final angle = flipAnimation.value * math.pi;
                  final isShowingBack = flipAnimation.value >= 0.5;

                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(isShowingBack ? angle - math.pi : angle);

                  return Transform(
                    alignment: Alignment.center,
                    transform: transform,
                    child: _FlashCard(
                      text: isFlipped ? word.back : word.front,
                      label: isFlipped ? '裏' : '表',
                      showHint: !isFlipped,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: hasFlippedOnce
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _JudgeButton(
                          label: '不正解',
                          icon: Icons.close_rounded,
                          color: Theme.of(context).colorScheme.error,
                          onTap: isSubmitting ? null : onIncorrect,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _JudgeButton(
                          label: '正解',
                          icon: Icons.check_rounded,
                          color: Colors.green.shade600,
                          onTap: isSubmitting ? null : onCorrect,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(height: 100),
        ),
      ],
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テストを途中終了しますか？'),
        content: const Text('テストを途中終了すると成績には含まれません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('いいえ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('はい'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      const HomeRoute().go(context);
    }
  }
}

class _FlashCard extends StatelessWidget {
  const _FlashCard({
    required this.text,
    required this.label,
    required this.showHint,
  });

  final String text;
  final String label;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                      ),
                    ),
                    if (showHint) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'タップして裏面を確認',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _JudgeButton extends StatelessWidget {
  const _JudgeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
