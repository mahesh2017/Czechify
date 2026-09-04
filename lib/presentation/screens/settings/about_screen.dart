import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../l10n/app_localizations.dart';

import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_tokens.dart';
import '../../utils/external_links.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/app_update_coordinator.dart';

/// What the app does, and who made it.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  bool _checkingForUpdate = false;

  Future<void> _checkForUpdate() async {
    if (_checkingForUpdate) return;
    setState(() => _checkingForUpdate = true);
    try {
      await showAppUpdateFlow(ref: ref, automatic: false);
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final features = [
      (
        kAppFeatures[0].icon,
        l10n.aboutFeatureCourseTitle,
        l10n.aboutFeatureCourseBody,
      ),
      (
        kAppFeatures[1].icon,
        l10n.aboutFeatureAudioTitle,
        l10n.aboutFeatureAudioBody,
      ),
      (
        kAppFeatures[2].icon,
        l10n.aboutFeaturePronunciationTitle,
        l10n.aboutFeaturePronunciationBody,
      ),
      (
        kAppFeatures[3].icon,
        l10n.aboutFeatureTutorTitle,
        l10n.aboutFeatureTutorBody,
      ),
      (
        kAppFeatures[4].icon,
        l10n.aboutFeatureReviewTitle,
        l10n.aboutFeatureReviewBody,
      ),
      (
        kAppFeatures[5].icon,
        l10n.aboutFeatureGrammarTitle,
        l10n.aboutFeatureGrammarBody,
      ),
      (
        kAppFeatures[6].icon,
        l10n.aboutFeatureExamTitle,
        l10n.aboutFeatureExamBody,
      ),
      (
        kAppFeatures[7].icon,
        l10n.aboutFeatureProgressTitle,
        l10n.aboutFeatureProgressBody,
      ),
    ];
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
                DisplayText(l10n.aboutTitle, size: 24),
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
                    l10n.aboutTagline,
                    style: TextStyle(fontSize: 15, color: t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _GroupLabel(l10n.aboutFeatures),
            for (final feature in features) ...[
              SoftCard(
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(
                      icon: feature.$1,
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
                            feature.$2,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            feature.$3,
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
            _GroupLabel(l10n.aboutYourAccount),
            SoftCard(
              radius: 18,
              padding: const EdgeInsets.all(18),
              child: Text(
                l10n.aboutAccountBody,
                style: TextStyle(fontSize: 14, height: 1.5, color: t.muted),
              ),
            ),
            const SizedBox(height: 18),
            _GroupLabel(l10n.aboutDeveloper),
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
                    l10n.aboutDeveloperBody(kDeveloperName),
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
            _GroupLabel(l10n.aboutUpdates),
            SoftCard(
              radius: 18,
              padding: EdgeInsets.zero,
              child: _ActionLink(
                icon: Icons.system_update_alt,
                title: l10n.updateCheckTitle,
                subtitle: l10n.updateCheckBody,
                busy: _checkingForUpdate,
                onTap: _checkForUpdate,
              ),
            ),
            const SizedBox(height: 18),
            _GroupLabel(l10n.aboutOnline),
            SoftCard(
              radius: 18,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _WebLink(
                    icon: Icons.language_outlined,
                    title: l10n.aboutOfficialWebsite,
                    subtitle: kWebsiteUrl,
                    onTap: () => openExternalPage(context, kWebsiteUrl),
                  ),
                  Divider(height: 1, color: t.line),
                  _WebLink(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.aboutOnlinePrivacy,
                    subtitle: kPrivacyPolicyUrl,
                    onTap: () => openExternalPage(context, kPrivacyPolicyUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  final value =
                      info == null
                          ? '…'
                          : info.buildNumber.isEmpty
                          ? info.version
                          : '${info.version} (${info.buildNumber})';
                  return Text(
                    '${AppLocalizations.of(context).settingsVersion} $value',
                    style: TextStyle(fontSize: 13, color: t.faint),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconTile(
              icon: icon,
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
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.pri),
              )
            else
              Icon(Icons.refresh, size: 19, color: t.pri),
          ],
        ),
      ),
    );
  }
}

class _WebLink extends StatelessWidget {
  const _WebLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconTile(
              icon: icon,
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
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: t.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 17, color: t.faint),
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
