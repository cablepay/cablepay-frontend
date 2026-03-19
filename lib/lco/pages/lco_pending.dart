import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_config.dart';
import '../../core/local_storage.dart';
import '../../core/app_theme.dart';
import '../../routes.dart';
import '../widgets/lco_bottom_navigation.dart';

class LcoPendingPage extends StatefulWidget {
  const LcoPendingPage({super.key});

  @override
  State<LcoPendingPage> createState() => _LcoPendingPageState();
}

class _LcoPendingPageState extends State<LcoPendingPage> {

  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {

    if (_checking) return;

    setState(() => _checking = true);

    try {

      final res = await ApiConfig.get('/api/lcos/me');

      if (res['statusCode'] == 200) {

        final user = Map<String, dynamic>.from(res['body']);

        if (user['status'] == 'active') {

          await LocalStorage.saveLco(user);

          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LcoBottomNavigation(lco: user),
            ),
                (_) => false,
          );

          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still waiting for admin approval')),
        );
      }

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to check status')),
      );

    }

    setState(() => _checking = false);
  }

  Future<void> _logout() async {

    await LocalStorage.clearSession();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.lcoLogin,
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text("Approval Pending"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStatus,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(
                Icons.hourglass_empty,
                size: 90,
                color: Colors.orange,
              ),

              const SizedBox(height: 20),

              const Text(
                "Your account is waiting for admin approval.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Tap refresh after admin approval.",
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              _checking
                  ? const CircularProgressIndicator()
                  : const SizedBox(),

            ],
          ),
        ),
      ),
    );
  }
}