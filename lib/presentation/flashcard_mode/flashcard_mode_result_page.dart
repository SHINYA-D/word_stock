import 'package:flutter/material.dart';
import 'package:word_stock/core/router/router.dart';

class FlashcardModeResultPage extends StatelessWidget {
  const FlashcardModeResultPage({
    super.key,
    required this.correctCount,
    required this.total,
  });

  final int correctCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rate = total == 0 ? 0.0 : correctCount / total;
    final percentage = (rate * 100).round();
    final color = _gradeColor(rate);
    final message = _gradeMessage(rate);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: rate,
                        strokeWidth: 12,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$percentage%',
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$correctCount / $total 問正解',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 48),
              _ScoreRow(
                label: '正解',
                value: '$correctCount',
                color: Colors.green.shade600,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 8),
              _ScoreRow(
                label: '不正解',
                value: '${total - correctCount}',
                color: Theme.of(context).colorScheme.error,
                icon: Icons.cancel_outlined,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => const HomeRoute().go(context),
                icon: const Icon(Icons.home_rounded),
                label: const Text('ホームに戻る'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _gradeColor(double rate) {
    if (rate >= 0.9) return Colors.green.shade600;
    if (rate >= 0.7) return Colors.blue.shade600;
    if (rate >= 0.5) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  String _gradeMessage(double rate) {
    if (rate >= 0.9) return '素晴らしい！';
    if (rate >= 0.7) return 'よくできました！';
    if (rate >= 0.5) return 'もう少し！';
    return 'もっと練習しましょう';
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
