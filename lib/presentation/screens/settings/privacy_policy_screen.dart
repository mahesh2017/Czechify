import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_tokens.dart';
import '../../widgets/common/soft_ui.dart';

/// The full privacy policy, in the app.
///
/// Deliberately not a link to a website: a learner should be able to read what
/// happens to their data offline, without a browser, and without leaving the
/// app to find out.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).a11yBack,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
                ),
                const Expanded(child: DisplayText('Privacy', size: 24)),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Version $kPrivacyPolicyVersion',
                style: TextStyle(fontSize: 13, color: t.faint),
              ),
            ),
            const SizedBox(height: 18),
            for (final section in kPrivacyPolicy) ...[
              SoftCard(
                radius: 18,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
