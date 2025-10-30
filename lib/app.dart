import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/app_router.dart';
import 'core/providers/auth_providers.dart';

class BlessedFamApp extends ConsumerWidget {
  const BlessedFamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(appThemeProvider);

    // Central auth listener: when the global auth notifier changes, drive
    // top-level navigation here so auth state changes are handled in one
    // place rather than scattered across screens. This avoids races where
    // a screen navigates before the router recognizes the new session.
    ref.listen<ValueNotifier<int>>(authStateListenableProvider, (prev, next) {
      // Use a microtask to ensure this runs after the current frame.
      Future.microtask(() {
        final session = ref.read(currentSessionProvider);
        try {
          if (session == null) {
            router.go('/login');
          } else {
            router.go('/');
          }
        } catch (_) {
          // ignore navigation errors — router may not be ready during hot
          // reload cycles.
        }
      });
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
