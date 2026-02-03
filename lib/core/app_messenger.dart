import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> appMessengerKey =
GlobalKey<ScaffoldMessengerState>();

void showGlobalSnack(String message) {
  appMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
