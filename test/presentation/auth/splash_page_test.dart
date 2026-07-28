import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/presentation/auth/splash/splash_page.dart';

void main() {
  group('SplashPage', () {
    // ナビゲーション（GoRouter 依存）を防ぐため authStateProvider をローディングのまま固定する
    ProviderScope buildSplash() {
      return ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) {
            final sc = StreamController<AppUser?>();
            ref.onDispose(sc.close);
            return sc.stream; // 決して emit しない → AsyncLoading のまま
          }),
        ],
        child: const MaterialApp(home: SplashPage()),
      );
    }

    testWidgets('スプラッシュ画像が表示される', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump(const Duration(seconds: 2)); // SplashPage の遅延タイマーを消化
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
