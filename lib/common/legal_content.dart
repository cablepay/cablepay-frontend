import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final String content;

  const LegalPage({Key? key, required this.title, required this.content})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(title: Text(title)),
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

CableSmartPay is a digital billing and payment facilitation platform operated by Hurryep Technologies Private Limited.

• CableSmartPay does NOT provide cable television services.
• All services, activations, and service quality are managed by the respective Local Cable Operator (LCO).
• Payments are processed through RBI-authorized third-party payment gateways.
• Successful payment is subject to gateway confirmation and backend verification.
• Users must be at least 18 years of age to use this platform.
• Misuse, fraudulent activity, or violation of these terms may result in account suspension.
• Continued use of the platform constitutes acceptance of updated terms.

Jurisdiction: India  
Support: cablepay@hurryep.com
''';

  static const privacy = '''
PRIVACY POLICY – CUSTOMERS

CableSmartPay collects minimal personal information required to operate the service.

Information we collect:
• Name and mobile number
• Email address (if provided)
• Transaction references and payment metadata
• Device information (IP address, OS version, app version)
• Push notification tokens for service alerts

Information we do NOT collect:
• UPI PIN
• Card CVV
• Bank login credentials
• Sensitive authentication data

Personal information is used only for authentication, billing, service notifications, and fraud prevention.

We do not sell or rent personal data. Limited data may be shared with trusted service providers such as payment gateways and notification services.

Support: cablepay@hurryep.com
''';
}

class LcoLegalText {
  static const terms = '''
TERMS & CONDITIONS – LCO

CableSmartPay provides billing management and payment facilitation tools for Local Cable Operators (LCOs).

• LCOs are responsible for cable service delivery, pricing, and customer management.
• CableSmartPay only provides the technology platform.
• Platform service fees may apply as agreed.
• Settlement timelines depend on payment gateway processing cycles.
• Misuse, fraudulent activity, or violation of platform policies may lead to account suspension.

Jurisdiction: India  
Support: cablepay@hurryep.com
''';

  static const privacy = '''
PRIVACY POLICY – LCO

CableSmartPay stores operational data required for billing and settlement services.

Information stored may include:
• Business and contact information
• Customer billing records
• Transaction references
• Device and access logs

All sensitive data is encrypted in transit and at rest.

Access to LCO data is restricted through role-based access controls.

Data retention follows applicable Indian legal and regulatory requirements.

Support: cablepay@hurryep.com
''';
}
