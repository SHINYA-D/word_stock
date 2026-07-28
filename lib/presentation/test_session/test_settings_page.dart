import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/router/router.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

class TestSettingsPage extends ConsumerStatefulWidget {
  const TestSettingsPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String folderId;
  final String folderName;

  @override
  ConsumerState<TestSettingsPage> createState() => _TestSettingsPageState();
}

class _TestSettingsPageState extends ConsumerState<TestSettingsPage> {
  bool _shuffle = true;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    final wordsState = ref.watch(wordListViewModelProvider(widget.folderId));

    return Scaffold(
      appBar: AppBar(title: const Text('テスト設定')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.folderName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            wordsState.when(
              loading: () => const Text('単語数を読み込み中...'),
              error: (_, __) => const Text('単語数の取得に失敗しました'),
              data: (words) => Text('単語数: ${words.length}枚', style: Theme.of(context).textTheme.bodyLarge),
            ),
            const Divider(height: 32),
            SwitchListTile(
              title: const Text('シャッフル出題'),
              subtitle: const Text('オフにすると登録順に出題されます'),
              value: _shuffle,
              onChanged: (v) => setState(() => _shuffle = v),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: wordsState.valueOrNull?.isEmpty ?? true
                  ? null
                  : () {
                      TestRoute(
                        folderId: widget.folderId,
                        $extra: TestRouteExtra(
                          words: wordsState.valueOrNull!,
                          shuffle: _shuffle,
                          folderName: widget.folderName,
                          userId: userId,
                        ),
                      ).push(context);
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('テスト開始'),
            ),
            if (wordsState.valueOrNull?.isEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '単語が1枚以上必要です',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
