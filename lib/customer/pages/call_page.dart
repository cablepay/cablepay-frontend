import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CallPage extends StatelessWidget {
  /// 🔹 Operator number (varies per LCO / user)
  final String operatorPhone;

  /// 🔹 Backend support number (same for all users)
  static const String supportPhone = '1800123456';

  const CallPage({
    super.key,
    required this.operatorPhone,
  });

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _callRow({
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
          )
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
            onTap: () => _call(phone),
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
              'You can call your operator or CablePay support',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            /// 🔹 YOUR OPERATOR (dynamic per LCO)
            _callRow(
              title: 'Your Operator',
              subtitle: 'Local service operator',
              phone: operatorPhone,
            ),

            /// 🔹 BACKEND SUPPORT (same for all)
            _callRow(
              title: 'CablePay Support',
              subtitle: 'Central support team',
              phone: supportPhone,
            ),
          ],
        ),
      ),
    );
  }
}
