// lib/main.dart
import 'package:cable_pay/lco/widgets/lco_bottom_navigation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'common/terms_and_privacy_page.dart';
import 'core/api_error.dart';
import 'core/app_messenger.dart';
import 'core/app_theme.dart';
import 'core/connectivity_guard.dart';
import 'core/local_storage.dart';
import 'core/api_config.dart';
import 'core/local_session.dart'; // optional if you use it
import 'routes.dart';
import 'lco/pages/lco_login.dart';
import 'lco/pages/lco_home.dart';
import 'customer/pages/customer_login.dart';
import 'customer/pages/customer_detail.dart';
import 'lco/pages/lco_detail.dart';
import 'lco/pages/lco_networks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'splash_screen.dart'; // new splash screen file

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();

    //  REQUIRED FOR KILLED / BACKGROUND STATE
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  // 🔴 PRODUCTION BACKEND OVERRIDE (THIS IS MANDATORY)
  if (kReleaseMode) {
    ApiConfig.setHost(
      'cablepay-backend-44811766138.asia-south1.run.app',
      protocol: 'https',
    );
  }

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cable Smart Pay',
      theme: AppTheme.theme,

      scaffoldMessengerKey: appMessengerKey,
      // Show splash first; splash will navigate to StartupRouter
      // home: const SplashScreen(),
      home: ConnectivityGuard(
        child: const SplashScreen(),
      ),
      // Keep your route generator intact
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

// class _EntryGate extends StatefulWidget {
//   const _EntryGate();
//
//   @override
//   State<_EntryGate> createState() => _EntryGateState();
// }
//
// class _EntryGateState extends State<_EntryGate> {
//   bool _loading = true;
//   bool _accepted = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _check();
//   }
//
//   Future<void> _check() async {
//     final accepted = await LocalStorage.isTermsAccepted();
//     if (!mounted) return;
//     setState(() {
//       _accepted = accepted;
//       _loading = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     if (!_accepted) {
//       return const TermsAndPrivacyPage();
//     }
//
//     return const SplashScreen();
//   }
// }


/// StartupRouter left unchanged — splash will navigate to this widget
class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  _StartupRouterState createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  bool _loading = true;
  Map<String, dynamic>? _session;    // session object persisted from backend
  Map<String, dynamic>? _lco;        // stored LCO profile (if any)
  Map<String, dynamic>? _customer;   // stored customer profile (if any)

  @override
  void initState() {
    super.initState();
    _init();

    if (!kIsWeb) {
      FirebaseMessaging.onMessage.listen((message) async {
        final session = await LocalStorage.getSession();
        if (session == null) return;
        if (!mounted) return;

        final data = message.data;
        final type = data['type'];

        String? text;

        switch (type) {
          case 'BOX_ACTIVATED':
            text = 'Your box has been activated';
            break;

          case 'BOX_EXPIRY_REMINDER':
            final days = data['daysLeft'];
            text = 'Your box will expire in $days day${days == '1' ? '' : 's'}';
            break;

          case 'BOX_EXPIRED':
            text = 'Your box has expired. Please pay to continue service';
            break;

          case 'SUPPORT_NEW_TICKET':
            text = 'New support request from customer';
            break;

          case 'SUPPORT_CUSTOMER_REPLY':
            text = 'Customer replied to your support ticket';
            break;

          case 'SUPPORT_LCO_REPLY':
            text = 'Operator replied to your ticket';
            break;

          case 'SUPPORT_TICKET_RESOLVED':
            text = 'Your ticket has been resolved';
            break;


          default:
            return; // ignore unknown notifications
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (!mounted) return;

        final data = message.data;
        final type = data['type'];

        switch (type) {
          case 'BOX_ACTIVATED':
          // 🔁 Soft refresh – backend already updated
            setState(() {});
            break;

          case 'BOX_EXPIRY_REMINDER':
          // Optional: navigate to billing / detail page later
            break;

          default:
            break;
        }
      });


    }
  }


  Future<void> _init() async {
    try {
      // restore session first (if any). LocalStorage.getSession must exist and return a Map
      final session = await LocalStorage.getSession();
      if (session != null && session['sessionKey'] != null) {
        ApiConfig.setSessionKey(session['sessionKey'].toString());
        _session = Map<String, dynamic>.from(session);
      }

      if (_session != null) {
        final me = await ApiConfig.get('/api/auth/me');

        if (me['statusCode'] == 200) {
          // OK
        } else if (me['statusCode'] == 401 || me['statusCode'] == 403) {
          // Auth is truly invalid
          await LocalStorage.clearSession();
          _session = null;
        } else {
          // 🔴 DO NOT CLEAR SESSION
          // backend might be warming up
          debugPrint('WARN: /me failed with ${me['statusCode']}');
        }
      }



      // restore profiles depending on session type
      if (_session != null && _session!['userType'] == 'lco') {
        final storedLco = await LocalStorage.getLco();
        if (storedLco != null) _lco = Map<String, dynamic>.from(storedLco);
      } else if (_session != null && _session!['userType'] == 'customer') {
        final storedCustomer = await LocalStorage.getCustomer();
        if (storedCustomer != null) _customer = Map<String, dynamic>.from(storedCustomer);
      }
    } catch (e) {
      if (e is ApiError) {

        if (e.type != 'auth') {
          showGlobalSnack(e.message); // ✅ ADD
        }
        debugPrint('API error: ${e.type}');

        if (e.type == 'auth') {
          await LocalStorage.clearSession();
          _session = null;
        }

        // 🔥 DO NOTHING for network / server / timeout
        // Session is preserved
      } else {
        debugPrint('StartupRouter init failed: $e');
      }
    }
    finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // No session -> default login screen (customer login chosen)
    if (_session == null) {
      return const CustomerLoginPage();
    }

    // Session present -> route based on userType
    final userType = (_session!['userType'] ?? '').toString();
    if (userType == 'lco') {
      if (_lco != null) {
        return LcoBottomNavigation(lco: _lco!);
      } else {
        return const LcoLoginPage();
      }
    }

    if (userType == 'customer') {
      if (_customer != null) {
        return CustomerDetailPage(data: _customer);
      } else {
        return const CustomerLoginPage();
      }
    }

    // Fallback
    return const CustomerLoginPage();
  }
}
