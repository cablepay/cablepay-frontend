import 'package:flutter/material.dart';
import '../core/api_config.dart';
import '../core/local_storage.dart';
import '../routes.dart';
bool _isLoggingOut = false;

Future<void> performLogout(BuildContext context) async {
  if (_isLoggingOut) return;
  _isLoggingOut = true;

  try {
    // Backend logout (best effort)
    await ApiConfig.post('/api/auth/logout', {});
  } catch (_) {}

  // Clear local state
  await LocalStorage.clearSession();
  await LocalStorage.clearCustomer();
  await LocalStorage.clearLco();

  ApiConfig.setSessionKey(null);

  // 🔴 ALWAYS navigate using root navigator
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      AppRoutes.customerLogin,
          (_) => false,
    );
  }

  _isLoggingOut = false;
}

