import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/local_storage.dart';
import '../splash_screen.dart';


final String _today =
    '${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}';



class TermsAndPrivacyPage extends StatefulWidget {
  const TermsAndPrivacyPage({super.key});

  @override
  State<TermsAndPrivacyPage> createState() => _TermsAndPrivacyPageState();
}

class _TermsAndPrivacyPageState extends State<TermsAndPrivacyPage> {
  bool _accepted = false;

  Future<void> _continue() async {
    if (!_accepted) return;
    await LocalStorage.setTermsAccepted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _termsText,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.text,
                    ),
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.divider),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _accepted,
                        onChanged: (v) =>
                            setState(() => _accepted = v ?? false),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'I have read and agree to the Terms & Conditions and Privacy Policy.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _accepted ? _continue : null,
                      child: const Text('Accept & Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




final String _termsText = '''
TERMS & CONDITIONS

Last Updated: ${_today}

1. About Cable Smart Pay
CableSmartPay is a digital billing, payment, and settlement platform operated by Hurryep Technologies Private Limited (“Company”, “we”, “us”). CableSmartPay enables customers to pay cable TV subscription charges and enables Local Cable Operators (LCOs) to manage billing records. CableSmartPay does NOT provide cable television services.

2. Eligibility
The App is intended for users aged 18 years or above. By using CableSmartPay, you confirm that you are legally eligible to enter into this agreement.

3. Role of CableSmartPay
CableSmartPay acts only as a technology facilitator. All cable services, activations, service quality, maintenance, and disconnections are solely the responsibility of the respective cable operator. CableSmartPay is not responsible for service outages, signal quality, or operator disputes.

4. Payments
Payments are processed through RBI-compliant third-party payment gateways (including UPI). Payment success is provisional until backend verification and gateway settlement confirmation.

5. Activation
Successful payment does not guarantee immediate activation. Service activation is performed by the cable operator after verification of payment and internal processes.

6. Wallet, Rewards & Referrals
Wallet credits and referral rewards are promotional in nature, non-transferable, and cannot be withdrawn as cash. CableSmartPay reserves the right to modify or revoke reward programs.

7. Refunds
Refunds, if applicable, are subject to payment gateway rules and operator policies. CableSmartPay does not guarantee refunds for operator-related service issues.

8. Suspension & Termination
CableSmartPay reserves the right to suspend or terminate access in cases of fraud, misuse, regulatory violations, or breach of these terms.

9. Limitation of Liability
CableSmartPay shall not be liable for indirect, incidental, or consequential damages including service interruptions, delayed activations, or disputes between customers and operators.

10. Changes to Terms
These Terms may be updated periodically. Continued use of the App constitutes acceptance of revised Terms.

––––––––––––––––––––––
PRIVACY POLICY

1. Introduction
CableSmartPay (www.CableSmartPay.com), operated by Hurryep Technologies Private Limited, is committed to protecting your privacy and personal information. By using the App, you consent to the collection and use of information as described below.

2. Information We Collect
We may collect:
• Name, phone number, email, address
• Device and application identifiers (IP address, OS, device info)
• Transaction references and payment metadata
• Usage data and interaction patterns

3. Information We Do NOT Collect
• UPI PIN
• Bank login credentials
• Card CVV or sensitive authentication data

4. Purpose of Collection
Information is collected solely to:
• Authenticate users
• Process payments
• Provide notifications
• Prevent fraud and comply with legal obligations
• Improve service quality

5. Payment Security
All financial transactions are securely processed via encrypted, authorized third-party payment gateways. CableSmartPay does not store sensitive payment credentials.

6. Cookies & Tracking
We may use cookies or similar technologies for authentication, analytics, and service improvement. You may restrict cookies via device or browser settings, but some features may be affected.

7. Data Sharing
Information may be shared with:
• Payment gateways
• Notification and cloud service providers
• Regulatory or legal authorities when required
All such sharing is limited and legally compliant.

8. Data Retention
Personal data is retained only as long as required for operational, legal, accounting, and regulatory purposes.

9. User Rights
Users may request access, correction, or deletion of personal data by contacting support.

10. External Links
The App may contain links to third-party websites. CableSmartPay is not responsible for third-party privacy practices.

11. Security
Industry-standard technical and organizational safeguards are implemented. However, no system is completely secure, and users accept inherent risks.

12. Grievance Redressal
For privacy or data concerns, contact:
Email: CableSmartPay@hurryep.com  
Grievances will be addressed within legally prescribed timelines.

13. Jurisdiction & Dispute Resolution
This policy is governed by Indian law. Disputes shall follow mediation and arbitration procedures. Courts in India shall have jurisdiction.

By using CableSmartPay, you acknowledge that you have read, understood, and agreed to these Terms & Privacy Policy.
''';

