import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LcoCallPage extends StatelessWidget {
  /// 🔹 Single fixed number for LCO app (India toll-free)
  static const String lcoSupportPhone = '1800123456';

  const LcoCallPage({Key? key}) : super(key: key);

  Future<void> _call(BuildContext context, String phone) async {
    // Preserve +, allow India +91, 10-digit, toll-free
    final sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (sanitized.isEmpty) {
      _showError(context, 'Invalid phone number');
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: sanitized,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showError(context, 'Unable to open phone dialer');
      }
    } catch (_) {
      _showError(context, 'Calling not supported on this device');
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  Widget _callRow({
    required BuildContext context, // ✅ FIX
    required String title,
    required String subtitle,
    required String phone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          /// LEFT CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          /// RIGHT CALL BUTTON
          InkWell(
            onTap: () => _call(context, phone),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.call,
                color: Colors.green.shade700,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Call Support'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You can call CablePay central support',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            /// 🔹 FIXED SUPPORT NUMBER
            _callRow(
              context: context, // ✅ PASS CONTEXT
              title: 'CablePay Support',
              subtitle: 'Central support team',
              phone: lcoSupportPhone,
            ),
          ],
        ),
      ),
    );
  }
}
