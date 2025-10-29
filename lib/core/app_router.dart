import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/attendance/presentation/admin_attendance_screen.dart';
import '../features/performance/presentation/leaderboard_screen.dart';
import '../features/announcements/presentation/announcements_screen.dart';
import '../features/announcements/presentation/admin_create_announcement_screen.dart';
import 'providers/auth_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateListenable = ref.watch(authStateListenableProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authStateListenable,
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/admin/attendance', builder: (c, s) => const AdminAttendanceScreen()),
      GoRoute(path: '/leaderboard', builder: (c, s) => const LeaderboardScreen()),
      GoRoute(path: '/announcements', builder: (c, s) => const AnnouncementsScreen()),
      GoRoute(path: '/admin/announce', builder: (c, s) => const AdminCreateAnnouncementScreen()),
    ],
    redirect: (context, state) {
      final isSplash = state.uri.toString() == '/splash';
      final isLoggingIn = state.uri.toString() == '/login';
      final session = ref.read(currentSessionProvider);
      final isAdminFuture = ref.read(isAdminProvider.future);

      if (isSplash) return null; // allow splash to decide

      if (session == null && !isLoggingIn) {
        return '/login';
      }
      if (session != null && (isLoggingIn || state.uri.toString() == '/splash')) {
        return '/';
      }
      // guard admin routes
      final path = state.uri.toString();
      if (path.startsWith('/admin')) {
        // Defer until profile loaded; if not admin, send home
        return isAdminFuture.then((isAdmin) => isAdmin ? null : '/').catchError((_) => '/');
      }
      return null;
    },
  );
});

