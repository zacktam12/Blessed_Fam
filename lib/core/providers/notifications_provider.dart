import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'supabase_provider.dart';

final notificationsInitProvider = FutureProvider<void>((ref) async {
  if (kIsWeb) return; // web push not configured here
  try {
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null) {
      final client = ref.read(supabaseProvider);
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        await client.from('device_tokens').upsert({
          'user_id': uid,
          'token': token,
          'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
        });
      }
    }
  } catch (_) {
    // ignore initialization failures silently
  }
});


