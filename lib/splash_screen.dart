// lib/splash_screen.dart
// Clean SPLASH:
// - Uses app_logo.png ONLY
// - Logo + text visible from frame 0
// - Slow, smooth text animation
// - Ticker leak FIXED (await forward(), dispose controller safely)

import 'dart:async';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/local_storage.dart';
import '../core/api_config.dart';
import '../main.dart';
import 'common/terms_and_privacy_page.dart';

const Color _teal = Color(0xFF22C1A9);
const Color _navyText = Color(0xFF092D4A);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  late Animation<double> _cableFade;
  late Animation<Offset> _cableSlide;

  late Animation<double> _payFade;
  late Animation<Offset> _paySlide;
  late Animation<double> _payScale;

  late Animation<double> _metaFade;

  // MUCH slower
  final Duration _duration = const Duration(milliseconds: 2200);
  final Duration _minVisible = const Duration(milliseconds: 600);

  static const String _assetPath = 'assets/app_logo.png';

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: _duration);

    // Slow + clean stagger
    _cableFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.20, 0.45, curve: Curves.easeIn));
    _cableSlide = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.20, 0.45, curve: Curves.easeOut)));

    _payFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.40, 0.70, curve: Curves.easeIn));
    _paySlide = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.40, 0.70, curve: Curves.easeOut)));

    _payScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.90, end: 1.10)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 55),
      TweenSequenceItem(
          tween:
          Tween(begin: 1.10, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
          weight: 45),
    ]).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.45, 0.85)));

    _metaFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeIn));

    _start();
  }

  Future<void> _start() async {
    final start = DateTime.now();

    // FIX: Await the animation so ticker completes cleanly
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
    if (remaining > Duration.zero) await Future.delayed(remaining);

    if (!mounted) return;

    // Navigator.of(context).pushReplacement(
    //   PageRouteBuilder(
    //     pageBuilder: (_, __, ___) => const StartupRouter(),
    //     transitionsBuilder: (_, anim, __, child) =>
    //         FadeTransition(opacity: anim, child: child),
    //     transitionDuration: const Duration(milliseconds: 400),
    //   ),
    // );

    final accepted = await LocalStorage.isTermsAccepted();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
        accepted ? const StartupRouter() : const TermsAndPrivacyPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

  }

  @override
  void dispose() {
    _ctrl.stop();       // extra safety
    _ctrl.dispose();    // dispose BEFORE super
    super.dispose();
  }

  Widget _textBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SlideTransition(
              position: _cableSlide,
              child: FadeTransition(
                opacity: _cableFade,
                child: Text(
                  'Cable',
                  style: TextStyle(
                      color: _navyText,
                      fontSize: 32,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SlideTransition(
              position: _paySlide,
              child: FadeTransition(
                opacity: _payFade,
                child: ScaleTransition(
                  scale: _payScale,
                  child: Text(
                    'Pay',
                    style: TextStyle(
                        color: _teal,
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        FadeTransition(
          opacity: _metaFade,
          child: RichText(
            text: TextSpan(
              style:
              TextStyle(color: AppTheme.text.withOpacity(0.78), fontSize: 14),
              children: [
                const TextSpan(text: 'by '),
                const TextSpan(
                    text: 'Hurry', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                    text: 'ep',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: _teal)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        _assetPath,
                        width: 86,
                        height: 86,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 18),
                      _textBlock(),
                    ],
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: 170,
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      color: _teal,
                      backgroundColor: _teal.withOpacity(0.12),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
