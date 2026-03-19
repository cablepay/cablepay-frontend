// lib/app_routes.dart
import 'package:flutter/material.dart';
import 'customer/pages/customer_history.dart';
import 'customer/pages/customer_login.dart';
import 'customer/pages/customer_detail.dart';
import 'lco/pages/lco_login.dart';
import 'lco/pages/lco_detail.dart';
import 'lco/pages/lco_home.dart';
import 'lco/pages/lco_networks.dart';
import 'lco/pages/lco_network_detail.dart';
import 'lco/widgets/lco_bottom_navigation.dart';
import 'lco/pages/lco_pending.dart';

class AppRoutes {
  static const String customerLogin = '/customer/login';
  static const String customerDetail = '/customer/detail';
  static const String customerHistory = '/customer/history';
  static const String lcoLogin = '/lco/login';
  static const lcoPending = '/lco/pending';
  static const String lcoHome = '/lco/home';
  static const String lcoDetail = '/lco/detail';
  static const String lcoNetworks = '/lco/networks';
  static const String lcoNetworkDetail = '/lco/network';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case customerLogin:
        return MaterialPageRoute(builder: (_) => CustomerLoginPage());
      case customerDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(builder: (_) => CustomerDetailPage(data: args));
      case customerHistory:
        final args = settings.arguments as Map<String, dynamic>?;
        final customer = args?['customer'] as Map<String, dynamic>? ?? {};
        final boxId = args?['boxId'] as String?;
        return MaterialPageRoute(builder: (_) => CustomerHistoryPage(customer: customer, boxId: boxId));
      case lcoLogin:
        return MaterialPageRoute(builder: (_) => const LcoLoginPage());
      case lcoPending:
        return MaterialPageRoute(
          builder: (_) => const LcoPendingPage(),
        );
      case lcoHome:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final lco = Map<String, dynamic>.from(args);
        // Return the shell that hosts Home/History/Call/Profile/Chat
        return MaterialPageRoute(builder: (_) => LcoBottomNavigation(lco: lco));
      case lcoDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(builder: (_) => LcoDetailPage(data: args));
      case lcoNetworks:
        final args = settings.arguments as Map<String, dynamic>?;
        final lco = args ?? <String, dynamic>{};
        return MaterialPageRoute(builder: (_) => LcoNetworksPage(lco: Map<String, dynamic>.from(lco)));
      case lcoNetworkDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final lcoId = args['lcoId'] as String? ?? '';
        final network = args['network'] as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => NetworkDetailPage(lcoId: lcoId, network: network));
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
