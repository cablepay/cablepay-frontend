import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_config.dart';


class CallPage extends StatefulWidget {
  /// Customer ID (required to resolve LCO via backend)
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
          res['body'] != null &&
          res['body']['operatorPhone'] != null) {
        _operatorPhone = res['body']['operatorPhone'].toString();
      } else {
        _error = 'Operator number not available';
      }
    } catch (e) {
      _error = 'Failed to load operator contact';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _callRow({
    required String title,
    required String subtitle,
    required String? phone,
    bool enabled = true,
  }) {
    final isEnabled = enabled && phone != null && phone.isNotEmpty;

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
                  phone ?? 'Not available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: isEnabled
                        ? Colors.black
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: isEnabled ? () => _call(phone!) : null,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isEnabled
                    ? Colors.green.shade50
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.call,
                color: isEnabled
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
              'You can call your operator or CablePay support',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            /// 🔹 Operator (from backend)
            _callRow(
              title: 'Your Operator',
              subtitle: 'Local service operator',
              phone: _operatorPhone,
              enabled: _operatorPhone != null,
            ),

            /// 🔹 Platform support (always available)
            _callRow(
              title: 'CablePay Support',
              subtitle: 'Central support team',
              phone: supportPhone,
              enabled: true,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
