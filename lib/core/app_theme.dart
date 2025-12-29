// lib/core/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Simple color tokens used across your pages (keeps pages unchanged)
  //static const Color primary = Color(0xFF0077FF); // OLX-like blue
  static const Color primary = Color(0xFF1B4683);
  //static const Color primaryLight = Color(0xFF66A9FF);
  static const Color primaryLight = Color(0xFF4F7AC0);
  // static const Color primaryDark = Color(0xFF0056CC);
  static const Color onPrimary = Colors.white;
  static const Color grey1= Color(0xFFF6F6F6);

  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F7FA);
  static const Color scaffoldBackground = Color(0xFFF4F7FB);
  static const Color muted = Color(0xFF6B7280);
  static const Color text = Color(0xFF0F172A);
  static const Color divider = Color(0xFFE6EDF7);

  // static const LinearGradient loginButtonGradient = LinearGradient(
  //   begin: Alignment.centerLeft,
  //   end: Alignment.centerRight,
  //   colors: [
  //     Color(0xFF24969a), // teal side
  //     Color(0xFF44c5b0), // smooth green
  //   ],
  // );

  // static const LinearGradient loginButtonGradient = LinearGradient(
  //   begin: Alignment.centerLeft,
  //   end: Alignment.centerRight,
  //   colors: [
  //     Color(0xFF1B4683), // teal side
  //     Color(0xFF1B4683), // smooth green
  //   ],
  // );

  // small numeric tokens
  static const double cardElevation = 2.0;
  static const double borderRadius = 10.0;

  // Expose an easy-to-use ThemeData you can assign to MaterialApp.theme
  static ThemeData get theme {
    final base = ThemeData.light();
    return base.copyWith(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: onPrimary,
        secondary: primary,
        background: scaffoldBackground,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(color: onPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: onPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: divider),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        labelStyle: const TextStyle(color: AppTheme.muted),
        hintStyle: const TextStyle(color: AppTheme.muted),
      ),
      cardTheme: CardThemeData(
        elevation: cardElevation,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: const TextStyle(color: onPrimary),
        actionTextColor: onPrimary,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text),
        contentTextStyle: const TextStyle(fontSize: 14, color: text),
      ),
      dividerTheme: const DividerThemeData(color: AppTheme.divider, thickness: 1),
      textTheme: base.textTheme.apply(
        fontFamily: 'Roboto',
        bodyColor: text,
        displayColor: text,
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
    );
  }
}

extension TextThemeX on TextTheme {
  TextStyle? get headline6 => titleLarge;
  TextStyle? get bodyText2 => bodyMedium;
  TextStyle? get subtitle1 => titleMedium;
}
