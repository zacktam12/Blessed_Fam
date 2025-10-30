import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/connectivity_utils.dart';
import 'supabase_provider.dart';

// Provider for connectivity checker
final connectivityCheckerProvider = Provider<ConnectivityChecker>((ref) {
  final client = ref.watch(supabaseProvider);
  final checker = ConnectivityChecker(client);
  
  // Start monitoring when provider is created
  checker.startMonitoring();
  
  // Clean up when provider is disposed
  ref.onDispose(() {
    checker.stopMonitoring();
    checker.dispose();
  });
  
  return checker;
});

// Stream provider for online/offline status
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final checker = ref.watch(connectivityCheckerProvider);
  return checker.onlineStream;
});

// Provider for current online status (synchronous)
final isOnlineProvider = Provider<bool>((ref) {
  final checker = ref.watch(connectivityCheckerProvider);
  return checker.isOnline;
});
