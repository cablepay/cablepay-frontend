import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/api_config.dart';


class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<String?> initAndGetToken() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 🔔 HANDLE TOKEN ROTATION
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await ApiConfig.post(
          '/api/devices/register',
          {
            'fcmToken': newToken,
            'platform': 'android',
          },
        );
      } catch (_) {
        // fail silently – retry on next refresh
      }
    });

    return await _messaging.getToken();
  }
}

