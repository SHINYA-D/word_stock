import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/home', '/results', '/sample', '/settings'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _tabIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '成績',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'テスト',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }

  int _tabIndex(String location) {
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }
}
