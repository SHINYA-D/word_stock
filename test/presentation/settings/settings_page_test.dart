import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/presentation/settings/settings_page.dart';
import 'package:word_stock/presentation/settings/settings_view_model.dart';

import '../../helpers/test_helpers.dart';

const _userId = 'mock-user-id';

Widget buildSettingsPage({List<Override> extra = const []}) {
  return buildWithMockRepositories(child: const SettingsPage(), extra: extra);
}

void main() {
  group('SettingsPage', () {
    testWidgets('ローディング中は CircularProgressIndicator が表示される', (tester) async {
      await tester.pumpWidget(buildSettingsPage(extra: [
        settingsViewModelProvider(_userId)
            .overrideWith(LoadingSettingsViewModel.new),
      ]));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('設定が読み込まれるとダークモードスイッチが表示される', (tester) async {
      await tester.pumpWidget(buildSettingsPage(extra: [
        settingsViewModelProvider(_userId)
            .overrideWith(DataSettingsViewModel.new),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('ダークモード'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('カラーテーマのドロップダウンが表示される', (tester) async {
      await tester.pumpWidget(buildSettingsPage(extra: [
        settingsViewModelProvider(_userId)
            .overrideWith(DataSettingsViewModel.new),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('カラーテーマ'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('ログアウト項目が表示される', (tester) async {
      await tester.pumpWidget(buildSettingsPage(extra: [
        settingsViewModelProvider(_userId)
            .overrideWith(DataSettingsViewModel.new),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('ログアウト'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('ログアウトをタップすると確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(buildSettingsPage(extra: [
        settingsViewModelProvider(_userId)
            .overrideWith(DataSettingsViewModel.new),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();

      expect(find.text('ログアウトしますか？'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });
  });
}

class LoadingSettingsViewModel extends SettingsViewModel {
  @override
  Future<UserSettings> build(String userId) =>
      Completer<UserSettings>().future;
}

class DataSettingsViewModel extends SettingsViewModel {
  @override
  Future<UserSettings> build(String userId) async =>
      const UserSettings(colorTheme: 'indigo', darkMode: false);
}
