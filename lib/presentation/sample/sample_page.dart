import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/core/router/router.dart';
import 'package:word_stock/core/utils/folder_name_validator.dart';
import 'package:word_stock/core/widgets/error_screen.dart';
import 'package:word_stock/core/widgets/network_error_dialog.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/presentation/sample/sample_state.dart';
import 'package:word_stock/presentation/sample/sample_view_model.dart';
import 'package:word_stock/presentation/sample/widgets/sample_list_tile.dart';

/// テストパイプライン検証用の画面。HomePage（フォルダ一覧）と同じ構成。
class SamplePage extends ConsumerWidget {
  const SamplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sampleViewModelProvider);
    final controller = ref.read(sampleViewModelProvider.notifier);

    ref.listen<SampleState>(sampleViewModelProvider, (prev, next) {
      final failure = next.operationFailure;
      if (failure == null || failure == prev?.operationFailure) return;
      // 初期読み込みの通信・認証エラーだけは、NetworkErrorDialog を出してログアウトする
      final isInitialLoad = prev?.samples.isLoading ?? true;
      if (isInitialLoad && (failure is NetworkFailure || failure is AuthFailure)) {
        _showNetworkErrorAndSignOut(context, ref);
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作が失敗しました。')));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('テスト'),
      ),
      body: state.samples.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorScreen(
          message: 'サンプルの読み込みに失敗しました',
          onRetry: controller.refresh,
        ),
        data: (samples) => samples.isEmpty
            ? _EmptyView(onAdd: () => _showCreateDialog(context, controller))
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.builder(
                  itemCount: samples.length,
                  itemBuilder: (context, i) => SampleListTile(
                    sample: samples[i],
                    onTap: () => FolderRoute(
                      folderId: samples[i].id,
                      $extra: samples[i].name,
                    ).push(context),
                    onEdit: () => _showEditDialog(context, controller, samples[i]),
                    onDelete: () => _showDeleteDialog(context, controller, samples[i]),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, controller),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showNetworkErrorAndSignOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showNetworkErrorDialog(context);
    // ログアウトすると、ルーターの redirect がログイン画面へ移動させる
    await ref.read(signOutUseCaseProvider).call();
  }

  void _showCreateDialog(BuildContext context, SampleViewModel controller) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => _SampleNameDialog(
        title: 'サンプルを作成',
        textController: textController,
        confirmLabel: '作成',
        onConfirm: (name) async {
          // 失敗したときはダイアログを閉じず、入力を残す
          final succeeded = await controller.createSample(name: name);
          if (succeeded && ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, SampleViewModel controller, Sample sample) {
    final textController = TextEditingController(text: sample.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => _SampleNameDialog(
        title: 'サンプルを編集',
        textController: textController,
        confirmLabel: '保存',
        onConfirm: (name) async {
          // 失敗したときはダイアログを閉じず、入力を残す
          final succeeded =
              await controller.updateSample(sampleId: sample.id, name: name);
          if (succeeded && ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, SampleViewModel controller, Sample sample) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('サンプルを削除'),
        content: Text('※「${sample.name}」を削除しますか？'),
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
              controller.deleteSample(sampleId: sample.id);
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
          const Icon(Icons.science_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('サンプルがありません'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('サンプルを作成'),
          ),
        ],
      ),
    );
  }
}

class _SampleNameDialog extends StatefulWidget {
  const _SampleNameDialog({
    required this.title,
    required this.textController,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final TextEditingController textController;
  final String confirmLabel;
  final Future<void> Function(String name) onConfirm;

  @override
  State<_SampleNameDialog> createState() => _SampleNameDialogState();
}

class _SampleNameDialogState extends State<_SampleNameDialog> {
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

  /// 確定の処理中は確定ボタンを無効にし、二重送信を防ぐ。
  bool _submitting = false;

  bool get _canConfirm =>
      !_submitting && widget.textController.text.trim().isNotEmpty;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      await widget.onConfirm(widget.textController.text.trim());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
          labelText: 'サンプル名',
          helperText: '半角20文字（全角10文字）まで',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
