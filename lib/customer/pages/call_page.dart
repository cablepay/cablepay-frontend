import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_config.dart';

class CallPage extends StatefulWidget {
  final String customerId;

  const CallPage({
    super.key,
    required this.customerId,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  static const String supportPhone = '1800123456';

  bool _loading = true;
  String? _operatorPhone;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOperatorPhone();
  }

  Future<void> _fetchOperatorPhone() async {
    try {
      final res = await ApiConfig.get(
        '/api/customers/${widget.customerId}/operator-phone',
      );

      if (res['statusCode'] == 200 &&
          res['body']?['operatorPhone'] != null) {
        _operatorPhone = res['body']['operatorPhone'].toString();
      } else {
        _error = 'Operator number not available';
      }
    } catch (_) {
      _error = 'Failed to load operator contact';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 🇮🇳 Normalize India phone numbers safely
  String? _normalizeIndiaPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');

    // Toll-free (1800XXXXXX)
    if (digits.startsWith('1800') && digits.length == 10) {
      return digits;
    }

    // 10-digit mobile → add +91
    if (digits.length == 10) {
      return '+91$digits';
    }

    // Already has country code
    if (digits.length >= 11 && digits.startsWith('91')) {
      return '+$digits';
    }

    return null;
  }

  Future<void> _call(String phone) async {
    final normalized = _normalizeIndiaPhone(phone);

    if (normalized == null) {
      _showError('Invalid phone number');
      return;
    }

    final uri = Uri(scheme: 'tel', path: normalized);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showError('Unable to open phone dialer');
      }
    } catch (_) {
      _showError('Calling not supported on this device');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  Widget _callRow({
    required String title,
    required String subtitle,
    required String? phone,
  }) {
    final isEnabled = phone != null && phone.isNotEmpty;

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
                    color: isEnabled
                        ? Colors.black
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          if (isEnabled)
            InkWell(
              onTap: () => _call(phone!),
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
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.call,
                color: Colors.grey.shade500,
                size: 22,
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
            const Text('Need help?',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'You can call your operator or CablePay support',
              style:
              TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            _callRow(
              title: 'Your Operator',
              subtitle: 'Local service operator',
              phone: _operatorPhone,
            ),

            _callRow(
              title: 'CablePay Support',
              subtitle: 'Central support team',
              phone: supportPhone,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade600, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
