import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final String content;

  const LegalPage({
    Key? key,
    required this.title,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: SingleChildScrollView(
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppTheme.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class CustomerLegalText {
  static const terms = '''
TERMS & CONDITIONS – CUSTOMERS

CableSmartPay is a digital billing and payment platform operated by Hurryep Technologies Private Limited.

• CableSmartPay does NOT provide cable TV services.
• Service delivery is the responsibility of your local cable operator.
• Payments are processed via RBI-compliant gateways.
• Wallet balance is non-transferable and non-withdrawable.
• Users must be 18 years or older.
• Continued use implies acceptance of updated terms.

Jurisdiction: India
Support: CableSmartPay@hurryep.com
''';

  static const privacy = '''
PRIVACY POLICY – CUSTOMERS

We collect minimal personal data for service operation.

Collected:
• Name, phone number
• Transaction references
• Device metadata

Not collected:
• UPI PIN
• Card CVV
• Bank credentials

Data is encrypted and never sold.

Contact: privacy@hurryep.com
''';
}

class LcoLegalText {
  static const terms = '''
TERMS & CONDITIONS – LCO

CableSmartPay provides billing and settlement tools to LCOs.

• LCOs control pricing and service delivery.
• Platform fees apply as agreed.
• Settlements depend on gateway timelines.
• Misuse may lead to suspension.

Jurisdiction: India
Support: lco-support@hurryep.com
''';

  static const privacy = '''
PRIVACY POLICY – LCO

We store LCO business and customer operational data.

• Data is encrypted at rest and transit.
• Access is role-restricted.
• Data retained per Indian law.

Contact: privacy@hurryep.com
''';
}

