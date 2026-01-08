import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

import '../../common/legal_content.dart';

class LcoTermsPage extends StatelessWidget {
  const LcoTermsPage({super.key});

  @override
  Widget build(context) {
    return const LegalPage(
      title: 'Terms & Conditions',
      content: LcoLegalText.terms,
    );
  }
}

