import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'customer_terms_page.dart';
import 'customer_privacy_page.dart';

class CustomerSettingsPage extends StatelessWidget {
  final Map<String, dynamic> customer;
  const CustomerSettingsPage({Key? key, required this.customer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primary,
      ),
      body: ListView(
        children: [
          _tile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerTermsPage()),
            ),
          ),
          _tile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerPrivacyPage()),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'App Version: 1.0.0',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
