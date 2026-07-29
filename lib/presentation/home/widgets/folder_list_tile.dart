import 'package:flutter/material.dart';
import 'package:word_stock/domain/entities/folder.dart';

class FolderListTile extends StatelessWidget {
  const FolderListTile({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Folder folder;
  final VoidCallback onTap;
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.folder_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: PopupMenuButton<_Action>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            if (action == _Action.edit) onEdit();
            if (action == _Action.delete) onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _Action.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('名前を変更'),
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
        onTap: onTap,
      ),
    );
  }
}

enum _Action { edit, delete }
