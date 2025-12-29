import 'package:flutter/material.dart';
import '../core/api_config.dart';
import '../core/local_storage.dart';
import '../routes.dart';

Future<void> performLogout(BuildContext context) async {
  try {
    // 🔴 IMPORTANT: tell backend to deactivate devices
    await ApiConfig.post('/api/auth/logout', {});
  } catch (_) {
    // ignore network / token errors — logout must continue
  }

  // Clear all local persistence
  await LocalStorage.clearSession();
  await LocalStorage.clearCustomer();
  await LocalStorage.clearLco();

  // Clear in-memory auth
  ApiConfig.setSessionKey(null);

  // Hard reset navigation stack
  Navigator.of(context).pushNamedAndRemoveUntil(
    AppRoutes.customerLogin,
        (route) => false,
  );
}
