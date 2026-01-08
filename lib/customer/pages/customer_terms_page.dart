import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

import '../../common/legal_content.dart';

class CustomerTermsPage extends StatelessWidget {
  const CustomerTermsPage({super.key});

  @override
  Widget build(context) {
    return const LegalPage(
      title: 'Terms & Conditions',
      content: CustomerLegalText.terms,
    );
  }
}

