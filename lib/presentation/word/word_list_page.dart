import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/router/router.dart';
import 'package:word_stock/core/widgets/error_screen.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/presentation/word/word_list_view_model.dart';

class WordListPage extends ConsumerStatefulWidget {
  const WordListPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String folderId;
  final String folderName;

  @override
  ConsumerState<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends ConsumerState<WordListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wordListViewModelProvider(widget.folderId));
    final controller = ref.read(wordListViewModelProvider(widget.folderId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'テストを開始',
            onPressed: () => FlashcardModeSettingsRoute(
              folderId: widget.folderId,
              $extra: widget.folderName,
            ).push(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '単語を検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorScreen(
          message: '単語の読み込みに失敗しました',
          onRetry: controller.refresh,
        ),
        data: (words) {
          final filtered = _searchQuery.isEmpty
              ? words
              : words.where((w) => w.front.contains(_searchQuery) || w.back.contains(_searchQuery)).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(_searchQuery.isEmpty ? '単語がありません' : '一致する単語がありません'),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) => _WordTile(
                word: filtered[i],
                onEdit: () => _showFormDialog(context, controller, word: filtered[i]),
                onDelete: () => _showDeleteDialog(context, controller, filtered[i]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(context, controller),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFormDialog(
    BuildContext context,
    WordListViewModel controller, {
    Word? word,
  }) {
    final frontController = TextEditingController(text: word?.front);
    final backController = TextEditingController(text: word?.back);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(word == null ? '単語を追加' : '単語を編集'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: frontController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '単語（表面）'),
                validator: (v) => (v == null || v.isEmpty) ? '入力してください' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: backController,
                decoration: const InputDecoration(labelText: '意味（裏面）'),
                validator: (v) => (v == null || v.isEmpty) ? '入力してください' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                if (word == null) {
                  controller.createWord(
                    front: frontController.text.trim(),
                    back: backController.text.trim(),
                  );
                } else {
                  controller.updateWord(
                    wordId: word.id,
                    front: frontController.text.trim(),
                    back: backController.text.trim(),
                  );
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WordListViewModel controller, Word word) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('単語を削除'),
        content: Text('「${word.front}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              controller.deleteWord(wordId: word.id);
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.onEdit,
    required this.onDelete,
  });

  final Word word;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          word.front,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(word.back),
        ),
        trailing: PopupMenuButton<_Action>(
          icon: const Icon(Icons.more_vert),
          onSelected: (a) {
            if (a == _Action.edit) onEdit();
            if (a == _Action.delete) onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _Action.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('編集'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _Action.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('削除', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Action { edit, delete }
