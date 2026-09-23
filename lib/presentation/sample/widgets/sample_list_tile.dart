import 'package:flutter/material.dart';
import 'package:word_stock/domain/entities/sample.dart';

class SampleListTile extends StatelessWidget {
  const SampleListTile({
    super.key,
    required this.sample,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.menuEnabled = true,
  });

  final Sample sample;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 削除の処理中など、この行への操作を受け付けないときに false にする。
  final bool menuEnabled;

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
        // 削除の処理中はこの行への操作を受け付けない（タップが遷移に抜けないよう行ごと止める）
        onTap: menuEnabled ? onTap : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.science_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          sample.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: PopupMenuButton<_Action>(
          enabled: menuEnabled,
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
