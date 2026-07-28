import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:word_stock/core/widgets/error_screen.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/presentation/result/result_view_model.dart';

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resultViewModelProvider);
    final controller = ref.read(resultViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('成績表'),
        centerTitle: false,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorScreen(
          message: '成績の読み込みに失敗しました',
          onRetry: controller.refresh,
        ),
        data: (results) {
          if (results.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('まだ成績データがありません'),
                  SizedBox(height: 8),
                  Text(
                    'テストを完了すると成績が記録されます',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          final folderNames = ref.watch(folderNamesProvider).valueOrNull ?? {};
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: results.length,
              itemBuilder: (context, i) => _ResultCard(
                result: results[i],
                folderName: folderNames[results[i].folderId],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, this.folderName});

  final FlashcardResult result;
  final String? folderName;

  @override
  Widget build(BuildContext context) {
    final rate = result.correctRate;
    final percentage = (rate * 100).round();
    final color = _gradeColor(rate);
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(result.date.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: rate,
                    strokeWidth: 5,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      '$percentage%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (folderName != null)
                    Text(
                      folderName!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  if (folderName != null) const SizedBox(height: 2),
                  Text(
                    '${result.correctCount} / ${result.totalCount} 正解',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
          ],
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
}
