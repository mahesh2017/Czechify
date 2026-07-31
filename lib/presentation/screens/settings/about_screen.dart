import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_tokens.dart';
import '../../widgets/common/soft_ui.dart';

/// What the app does, and who made it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                const DisplayText('About', size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: t.priSoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.school_outlined, size: 38, color: t.pri),
                  ),
                  const SizedBox(height: 14),
                  const DisplayText('Czechify', size: 28),
                  const SizedBox(height: 6),
                  Text(
                    'Learn Czech properly — CEFR A1 to A2',
                    style: TextStyle(fontSize: 15, color: t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const _GroupLabel('What Czechify gives you'),
            for (final feature in kAppFeatures) ...[
              SoftCard(
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(
                      icon: feature.icon,
                      tint: t.priSoft,
                      fg: t.pri,
                      size: 38,
                      radius: 12,
                      iconSize: 19,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            feature.body,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: t.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            const _GroupLabel('Your account'),
            SoftCard(
              radius: 18,
              padding: const EdgeInsets.all(18),
              child: Text(
                'Czechify sets up an anonymous account for you automatically — '
                'no email address, no password, nothing personal. Your progress '
                'syncs to it so a lost or reset phone does not cost you your '
                'learning. If you later want to learn on a second device, you '
                'can add an email address and password to that same account and '
                'everything carries across.',
                style: TextStyle(fontSize: 14, height: 1.5, color: t.muted),
              ),
            ),
            const SizedBox(height: 18),
            const _GroupLabel('Developer'),
            SoftCard(
              radius: 18,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kDeveloperName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Designed, built and maintained by $kDeveloperName.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(fontSize: 13, color: t.faint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: t.faint,
        ),
      ),
    );
  }
}
