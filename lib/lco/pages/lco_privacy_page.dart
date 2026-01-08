import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

import '../../common/legal_content.dart';

class LcoPrivacyPage extends StatelessWidget {
  const LcoPrivacyPage({super.key});

  @override
  Widget build(context) {
    return const LegalPage(
      title: 'Privacy Policy',
      content: LcoLegalText.privacy,
    );
  }
}

