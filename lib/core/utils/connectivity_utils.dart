import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple connectivity checker using Supabase health endpoint
class ConnectivityChecker {
  ConnectivityChecker(this._client);
  
  final SupabaseClient _client;
  bool _isOnline = true;
  final _controller = StreamController<bool>.broadcast();
  Timer? _timer;

  Stream<bool> get onlineStream => _controller.stream;
  bool get isOnline => _isOnline;

  void startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnection());
    _checkConnection(); // Initial check
  }

  void stopMonitoring() {
    _timer?.cancel();
  }

  Future<void> _checkConnection() async {
    try {
      // Try a simple query to check connectivity
      await _client.from('sessions').select('id').limit(1);
      if (!_isOnline) {
        _isOnline = true;
        _controller.add(true);
      }
    } catch (e) {
      if (_isOnline) {
        _isOnline = false;
        _controller.add(false);
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

/// Offline indicator banner widget
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key, required this.isOffline});
  
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No internet connection. Some features may be unavailable.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

/// Retry wrapper for operations that might fail due to network issues
Future<T> retryOperation<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration delay = const Duration(seconds: 2),
  void Function(String)? onRetry,
}) async {
  int attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      return await operation();
    } catch (e) {
      attempts++;
      
      if (attempts >= maxRetries) {
        rethrow;
      }
      
      onRetry?.call('Retry attempt $attempts of $maxRetries...');
      await Future<void>.delayed(delay);
    }
  }
  
  throw Exception('Operation failed after $maxRetries attempts');
}
