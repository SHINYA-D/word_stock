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
class SamplePage extends ConsumerStatefulWidget {
  const SamplePage({super.key});

  @override
  ConsumerState<SamplePage> createState() => _SamplePageState();
}

class _SamplePageState extends ConsumerState<SamplePage> {
  final _scrollController = ScrollController();

  /// 削除の処理中のアイテム。完了するまでその行への操作を受け付けない（二重送信の防止）。
  String? _deletingId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作が失敗しました。')));
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
        // 0件表示でもプルして更新できるようにする（別端末で作ったデータを取り込む手段が要るため）
        data: (samples) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: samples.isEmpty
              ? _EmptyView(onAdd: () => _showCreateDialog(context, controller))
              : ListView.builder(
                  controller: _scrollController,
                  // controller を渡すと primary が false になり、既定で付く
                  // AlwaysScrollableScrollPhysics が外れる。件数が少なくても
                  // プルして更新できるよう明示する
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: samples.length,
                  itemBuilder: (context, i) => SampleListTile(
                    sample: samples[i],
                    menuEnabled: _deletingId != samples[i].id,
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
      // 一覧が決まっていない間（読み込み中・ErrorScreen 表示中）は作成させない
      floatingActionButton: state.samples.hasValue
          ? FloatingActionButton(
              onPressed: () => _showCreateDialog(context, controller),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// 作成したアイテムは一覧の末尾に追加されるため、末尾まで送って画面内に見えるようにする。
  /// ListView.builder は末尾を遅れて組み立てるので、伸びなくなるまで数フレーム追いかける。
  void _scrollToNewest([int remaining = 3]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (_scrollController.offset >= max) return;
      _scrollController.jumpTo(max);
      if (remaining > 0) _scrollToNewest(remaining - 1);
    });
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
          if (!succeeded) return;
          if (ctx.mounted) Navigator.pop(ctx);
          _scrollToNewest();
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
          final succeeded = await controller.updateSample(sampleId: sample.id, name: name);
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
              // ダイアログを閉じてから削除する（概要 §削除ダイアログ）。
              // ダイアログ内では二重送信を防げないため、完了までその行の操作を止める
              Navigator.pop(ctx);
              setState(() => _deletingId = sample.id);
              controller.deleteSample(sampleId: sample.id).whenComplete(() {
                if (mounted) setState(() => _deletingId = null);
              });
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
    // 0件でもプルして更新できるよう、画面いっぱいの高さを持つスクロール可能なウィジェットにする
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
          ),
        ),
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

  bool get _canConfirm => !_submitting && widget.textController.text.trim().isNotEmpty;

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
    // 処理中は閉じられないようにする。閉じた後に成功すると一覧に反映され、
    // 「キャンセルには副作用がない」（原則-7）と食い違うため。
    // バリアのタップも Navigator.maybePop を通るので、PopScope で両方まとめて止まる
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
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
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _canConfirm ? _confirm : null,
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
