import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/router/router.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _minDelayDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _minDelayDone = true);
      _tryNavigate();
    });
  }

  void _tryNavigate() {
    if (!_minDelayDone || !mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return;
    if (authState.hasError || authState.valueOrNull == null) {
      const LoginRoute().go(context);
    } else {
      const HomeRoute().go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, __) => _tryNavigate());

    return const Scaffold(
      backgroundColor: Color(0xFFF0F0F5),
      body: Center(
        child: Image(
          image: AssetImage('assets/images/splash.png'),
          width: 240,
        ),
      ),
    );
  }
}
