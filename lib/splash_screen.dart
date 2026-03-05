// lib/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../core/local_storage.dart';
import '../core/api_config.dart';
import '../main.dart';
import 'common/terms_and_privacy_page.dart';

const Color _brandBlue = Color(0xFF1B4683);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _logoFade;

  final Duration _animDuration = const Duration(milliseconds: 1200);
  final Duration _minVisible  = const Duration(milliseconds: 2800);

  static const String _assetPath = 'assets/app_logo.png';

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: _animDuration);

    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    );

    _start();
  }

  Future<void> _start() async {
    final start = DateTime.now();

    try {
      await _ctrl.forward();
    } catch (_) {}

    try {
      final session = await LocalStorage.getSession();
      if (session != null && session['sessionKey'] != null) {
        ApiConfig.setSessionKey(session['sessionKey'].toString());
      }
    } catch (_) {}

    final elapsed = DateTime.now().difference(start);
    final remaining = _minVisible - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    final accepted = await LocalStorage.isTermsAccepted();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
        accepted ? const StartupRouter() : const TermsAndPrivacyPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandBlue,
      body: SafeArea(
        child: Stack(
          children: [
            // Centered logo (unchanged behavior)
            Center(
              child: FadeTransition(
                opacity: _logoFade,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final shortestSide =
                    constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;

                    final double logoSize = shortestSide * 0.7;

                    return Image.asset(
                      _assetPath,
                      width: logoSize.clamp(180.0, 340.0),
                      height: logoSize.clamp(180.0, 340.0),
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),

            // 👇 Powered by footer (NEW, non-intrusive)
            Positioned(
              bottom: 40, // 👈 move slightly up from bottom
              left: 0,
              right: 0,
              child: Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14, // 👈 slightly bigger font
                      color: Colors.white70,
                      fontWeight: FontWeight.w600, // 👈 a bit stronger weight
                      letterSpacing: 0.4,
                    ),
                    children: const [
                      TextSpan(text: 'Powered by Hurry'),
                      TextSpan(
                        text: 'e',
                        style: TextStyle(
                          color: Color(0xFF00C853), // green "e"
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: 'p'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}