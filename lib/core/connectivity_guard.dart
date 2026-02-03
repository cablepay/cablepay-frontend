import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityGuard extends StatefulWidget {
  final Widget child;
  const ConnectivityGuard({super.key, required this.child});

  @override
  State<ConnectivityGuard> createState() => _ConnectivityGuardState();
}

class _ConnectivityGuardState extends State<ConnectivityGuard> {
  bool _offline = false;
  late final StreamSubscription _sub;


  @override
  void initState() {
    super.initState();
    _checkInitial();

    _sub = Connectivity().onConnectivityChanged.listen((_) async {
      final offline = await _isReallyOffline();
      if (mounted && offline != _offline) {
        setState(() => _offline = offline);
      }
    });
  }

  Future<void> _checkInitial() async {
    final offline = await _isReallyOffline();
    if (mounted) setState(() => _offline = offline);
  }



  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<bool> _isReallyOffline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isEmpty;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // 🔴 INTERNET LOST BANNER
        if (_offline)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.red.shade700,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  child: Row(
                    children: const [
                      Icon(Icons.wifi_off, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No internet connection',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
