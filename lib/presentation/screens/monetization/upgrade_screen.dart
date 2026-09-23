import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/course_catalog.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/referral_providers.dart';
import '../../widgets/common/soft_ui.dart';

/// Where a learner lands at paid content: subscribe to Core, or (for A1 only)
/// invite friends to unlock units for good. No reward is promised for A2.
class UpgradeScreen extends ConsumerWidget {
  /// The unit that led here, when known; decides whether invitations apply.
  final int? unitId;
  const UpgradeScreen({super.key, this.unitId});

  bool get _a2 =>
      unitId != null && CourseCatalog.a1ReferralV1.a2UnitIds.contains(unitId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final invites =
        !_a2 && (ref.watch(referralsEnabledProvider).value ?? false);
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
                  tooltip: l10n.a11yBack,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: DisplayText(l10n.upgradeTitle, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.upgradeIntro,
              style: TextStyle(fontSize: 15, height: 1.45, color: t.muted),
            ),
            const SizedBox(height: 18),
            _Option(
              icon: Icons.workspace_premium_outlined,
              title: l10n.upgradeCoreTitle,
              body: l10n.upgradeCoreBody,
              action: l10n.upgradeCoreAction,
              onTap: () => context.push('/subscriptions'),
            ),
            if (invites) ...[
              const SizedBox(height: 14),
              _Option(
                icon: Icons.group_add_outlined,
                title: l10n.upgradeInviteTitle,
                body: l10n.upgradeInviteBody,
                action: l10n.upgradeInviteAction,
                onTap: () => context.push('/referrals'),
              ),
            ],
            if (_a2) ...[
              const SizedBox(height: 16),
              Text(
                l10n.upgradeA2Note,
                style: TextStyle(fontSize: 14, height: 1.4, color: t.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;
  const _Option({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, tint: t.priSoft, fg: t.pri, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(fontSize: 14, height: 1.4, color: t.muted),
          ),
          const SizedBox(height: 14),
          PrimaryButton(label: action, height: 48, onPressed: onTap),
        ],
      ),
    );
  }
}
