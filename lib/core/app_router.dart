import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/attendance/presentation/admin_attendance_screen.dart';
import '../features/attendance/presentation/my_attendance_screen.dart';
import '../features/announcements/presentation/announcements_screen.dart';
import '../features/announcements/presentation/admin_create_announcement_screen.dart';
import '../features/admin/presentation/admin_create_user_screen.dart';
import '../features/admin/presentation/admin_analytics_screen.dart';
import '../features/admin/presentation/manage_sessions_screen.dart';
import 'providers/auth_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateListenable = ref.watch(authStateListenableProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authStateListenable,
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/forgot', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
      GoRoute(
          path: '/admin/attendance',
          builder: (c, s) => const AdminAttendanceScreen()),
      GoRoute(
          path: '/my-attendance',
          builder: (c, s) => const MyAttendanceScreen()),
      GoRoute(
          path: '/announcements',
          builder: (c, s) => const AnnouncementsScreen()),
      GoRoute(
          path: '/admin/announce',
          builder: (c, s) => const AdminCreateAnnouncementScreen()),
      GoRoute(
          path: '/admin/create-user',
          builder: (c, s) => const AdminCreateUserScreen()),
      GoRoute(
          path: '/admin/analytics',
          builder: (c, s) => const AdminAnalyticsScreen()),
      GoRoute(
          path: '/admin/manage-sessions',
          builder: (c, s) => const ManageSessionsScreen()),
    ],
    redirect: (context, state) {
      // Allow a small set of public, unauthenticated routes so things like
      // "Forgot password" can be visited without being bounced back to
      // /login by the global redirect.
      final publicPaths = {'/splash', '/login', '/forgot'};
      final isSplash = state.uri.toString() == '/splash';
      final session = ref.read(currentSessionProvider);
      final isAdminFuture = ref.read(isAdminProvider.future);

      if (isSplash) return null; // allow splash to decide

      if (session == null && !publicPaths.contains(state.uri.toString())) {
        return '/login';
      }
      if (session != null &&
          (state.uri.toString() == '/login' ||
              state.uri.toString() == '/splash')) {
        return '/';
      }
      // guard admin routes
      final path = state.uri.toString();
      if (path.startsWith('/admin')) {
        // Defer until profile loaded; if not admin, send home
        return isAdminFuture
            .then((isAdmin) => isAdmin ? null : '/')
            .catchError((_) => '/');
      }
      return null;
    },
  );
});
