import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/providers/notifications_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(supabaseInitProvider, (prev, next) {
      if (!next.isLoading) {
        // kick off notifications registration (non-blocking)
        ref.read(notificationsInitProvider);
        final session = ref.read(currentSessionProvider);
        if (session == null) {
          context.go('/login');
        } else {
          context.go('/');
        }
      }
    });

    final init = ref.watch(supabaseInitProvider);
    return Scaffold(
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: init.isLoading
              ? const CircularProgressIndicator()
              : const Column(
                  key: ValueKey('ready'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.church, size: 48),
                    SizedBox(height: 12),
                    Text('BlessedFam', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      ),
    );
  }
}

