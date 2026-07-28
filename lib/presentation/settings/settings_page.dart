import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/router/router.dart';
import 'package:word_stock/core/theme/app_theme.dart';
import 'package:word_stock/core/widgets/error_screen.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/presentation/settings/settings_view_model.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userId = user?.id ?? '';
    final state = ref.watch(settingsViewModelProvider(userId));
    final controller = ref.read(settingsViewModelProvider(userId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorScreen(
          message: '設定の読み込みに失敗しました',
          onRetry: () {},
        ),
        data: (settings) => ListView(
          children: [
            const ListTile(
              title: Text('外観',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              title: const Text('ダークモード'),
              value: settings.darkMode,
              onChanged: (v) => controller.updateSettings(settings.copyWith(darkMode: v)),
            ),
            ListTile(
              title: const Text('カラーテーマ'),
              trailing: DropdownButton<String>(
                value: settings.colorTheme,
                underline: const SizedBox(),
                items: AppTheme.colorThemes.keys.map((key) {
                  return DropdownMenuItem(
                    value: key,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppTheme.colorThemes[key],
                        ),
                        const SizedBox(width: 8),
                        Text(key),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) controller.updateSettings(settings.copyWith(colorTheme: v));
                },
              ),
            ),
            const Divider(),
            const ListTile(
              title: Text('アカウント',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('ログアウト'),
              leading: const Icon(Icons.logout),
              onTap: () => _showSignOutDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(signOutUseCaseProvider).call();
              if (context.mounted) const LoginRoute().go(context);
            },
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }
}
