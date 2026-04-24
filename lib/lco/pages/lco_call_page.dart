import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_config.dart'; // ✅ IMPORTANT

class LcoCallPage extends StatefulWidget {
  const LcoCallPage({Key? key}) : super(key: key);

  @override
  State<LcoCallPage> createState() => _LcoCallPageState();
}

class _LcoCallPageState extends State<LcoCallPage> {
  String? _supportPhone;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSupportPhone();
  }

  Future<void> _fetchSupportPhone() async {
    try {
      final res = await ApiConfig.get('/api/config/support');

      if (res['statusCode'] == 200 &&
          res['body']?['supportPhone'] != null) {
        _supportPhone = res['body']['supportPhone'].toString();
      } else {
        _supportPhone = null;
      }
    } catch (_) {
      _supportPhone = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call(BuildContext context, String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (sanitized.isEmpty) {
      _showError(context, 'Invalid phone number');
      return;
    }

    final uri = Uri(scheme: 'tel', path: sanitized);

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
    required BuildContext context,
    required String title,
    required String subtitle,
    required String? phone,
  }) {
    final isValid = phone != null && phone.isNotEmpty;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Text(
                  phone ?? 'Not available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isValid
                        ? Colors.black
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: isValid ? () => _call(context, phone!) : null,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isValid
                    ? Colors.green.shade50
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.call,
                color: isValid
                    ? Colors.green.shade700
                    : Colors.grey.shade500,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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

            _callRow(
              context: context,
              title: 'CablePay Support',
              subtitle: 'Central support team',
              phone: _supportPhone,
            ),
          ],
        ),
      ),
    );
  }
}