import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/router/router.dart';
import 'package:word_stock/core/utils/folder_name_validator.dart';
import 'package:word_stock/core/widgets/error_screen.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/presentation/home/home_view_model.dart';
import 'package:word_stock/presentation/home/widgets/folder_list_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final controller = ref.read(homeViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WordStock'),
      ),
      body: state.folders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorScreen(
          message: 'フォルダの読み込みに失敗しました',
          onRetry: controller.refresh,
        ),
        data: (folders) => folders.isEmpty
            ? _EmptyView(onAdd: () => _showCreateDialog(context, controller))
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, i) => FolderListTile(
                    folder: folders[i],
                    onTap: () => FolderRoute(
                      folderId: folders[i].id,
                      $extra: folders[i].name,
                    ).push(context),
                    onEdit: () => _showEditDialog(context, controller, folders[i]),
                    onDelete: () => _showDeleteDialog(context, controller, folders[i]),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, controller),
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, HomeViewModel controller) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => _FolderNameDialog(
        title: 'フォルダを作成',
        textController: textController,
        confirmLabel: '作成',
        onConfirm: (name) {
          controller.createFolder(name: name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, HomeViewModel controller, Folder folder) {
    final textController = TextEditingController(text: folder.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => _FolderNameDialog(
        title: 'フォルダ名を変更',
        textController: textController,
        confirmLabel: '保存',
        onConfirm: (name) {
          controller.updateFolder(folderId: folder.id, name: name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, HomeViewModel controller, Folder folder) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('フォルダを削除'),
        content: Text(
          '「${folder.name}」を削除しますか？\n配下の単語・サブフォルダ・成績データもすべて削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              controller.deleteFolder(folderId: folder.id);
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('フォルダがありません'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('フォルダを作成'),
          ),
        ],
      ),
    );
  }
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.textController,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final TextEditingController textController;
  final String confirmLabel;
  final ValueChanged<String> onConfirm;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _canConfirm => widget.textController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: widget.textController,
        autofocus: true,
        maxLines: 1,
        inputFormatters: const [FolderNameLengthFormatter()],
        decoration: const InputDecoration(
          labelText: 'フォルダ名',
          helperText: '半角20文字（全角10文字）まで',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () => widget.onConfirm(widget.textController.text.trim())
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
