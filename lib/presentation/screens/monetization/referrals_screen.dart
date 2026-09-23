import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/referrals/referral_status.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/account_providers.dart';
import '../../providers/referral_providers.dart';
import '../../widgets/common/soft_ui.dart';

/// Invite friends and follow what they unlock. Friends appear only as
/// numbers with their progress; no names, emails or study details. A reward
/// is shown only once the server has committed it.
class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _getCode() async {
    final api = ref.read(referralApiProvider);
    if (api == null) return;
    setState(() => _busy = true);
    final result = await api.inviteCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.code == null ? _refusal(result.refusal) : null;
    });
    ref.invalidate(referralStatusProvider);
  }

  Future<void> _claim() async {
    if (_code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final refusal = await ref.read(referralClaimProvider)(_code.text);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = false;
      _message = refusal == null ? l10n.referralsJoined : _refusal(refusal);
    });
    if (refusal == null) {
      _code.clear();
      ref.invalidate(referralStatusProvider);
    }
  }

  String _refusal(String? code) {
    final l10n = AppLocalizations.of(context);
    return switch (code) {
      'referral_already_claimed' => l10n.referralsErrorClaimed,
      'referral_ineligible' => l10n.referralsErrorIneligible,
      'campaign_unavailable' => l10n.referralsErrorClosed,
      'rate_limited' => l10n.referralsErrorRateLimited,
      'linked_account_required' => l10n.referralsLinkNeeded,
      _ => l10n.referralsErrorGeneric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(referralsEnabledProvider).value ?? false;
    final user = ref.watch(accountUserProvider).value;
    final linked = user != null && !user.isAnonymous;
    final status = ref.watch(referralStatusProvider);

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
                Expanded(child: DisplayText(l10n.referralsTitle, size: 24)),
              ],
            ),
            const SizedBox(height: 12),
            if (!enabled)
              Text(
                l10n.referralsUnavailable,
                style: TextStyle(fontSize: 15, color: t.ink),
              )
            else ...[
              Text(
                l10n.referralsHowItWorks,
                style: TextStyle(fontSize: 15, height: 1.45, color: t.muted),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _message!,
                    style: TextStyle(fontSize: 15, height: 1.4, color: t.ink),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ...switch (status) {
                AsyncData(:final value) => _content(context, value, linked),
                AsyncError() => [
                  Text(
                    l10n.referralsErrorGeneric,
                    style: TextStyle(color: t.muted),
                  ),
                ],
                _ => [const Center(child: CircularProgressIndicator())],
              },
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    ReferralStatus? status,
    bool linked,
  ) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final s = status ?? const ReferralStatus();
    return [
      // Your code and what it has earned.
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Without a loaded status there is nothing true to say about
            // rewards, so say nothing rather than a default.
            if (status != null) ...[
              Text(
                l10n.referralsUnitsEarned(s.unitsEarned, s.unitsAvailable),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              if (s.nextRewardUnit case final unit?) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.referralsNextUnit(unit),
                  style: TextStyle(fontSize: 14, color: t.muted),
                ),
              ] else if (s.unitsEarned >= s.unitsAvailable) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.referralsAllEarned,
                  style: TextStyle(fontSize: 14, color: t.muted),
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (!linked) ...[
              Text(
                l10n.referralsLinkNeeded,
                style: TextStyle(fontSize: 14, height: 1.4, color: t.ink),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: l10n.referralsLinkAction,
                height: 48,
                onPressed: () => context.push('/account'),
              ),
            ] else if (s.inviteCode == null)
              PrimaryButton(
                label: l10n.referralsGetCode,
                height: 48,
                onPressed: _busy ? null : _getCode,
              )
            else ...[
              Text(
                l10n.referralsYourCode,
                style: TextStyle(fontSize: 13, color: t.muted),
              ),
              const SizedBox(height: 4),
              SelectableText(
                s.inviteCode!,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: l10n.referralsShare,
                      icon: Icons.share_outlined,
                      height: 48,
                      onPressed:
                          () => SharePlus.instance.share(
                            ShareParams(
                              text: l10n.referralsShareMessage(s.inviteCode!),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: s.inviteCode!),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.referralsCopied)),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.referralsCopy),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      SectionLabel(l10n.referralsFriendsTitle),
      const SizedBox(height: 8),
      if (s.friends.isEmpty)
        Text(l10n.referralsNoFriends, style: TextStyle(color: t.muted))
      else
        for (final friend in s.friends)
          _MilestoneCard(
            title: l10n.referralsFriend(friend.number),
            milestones: friend.milestones,
          ),
      const SizedBox(height: 20),
      // As an invited learner: either your progress or a code to enter.
      SectionLabel(l10n.referralsJoinTitle),
      const SizedBox(height: 8),
      if (s.ownClaim case final own?)
        _MilestoneCard(
          title: l10n.referralsOwnProgress(
            own.lessonsCompleted,
            own.lessonsRequired,
          ),
          milestones: own.milestones,
        )
      else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.referralsJoinHint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _claim(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _busy ? null : _claim,
                // The theme stretches filled buttons; this one shares a row.
                style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                child: Text(l10n.referralsJoinAction),
              ),
            ),
          ],
        ),
    ];
  }
}

class _MilestoneCard extends StatelessWidget {
  final String title;
  final List<ReferralMilestoneStatus> milestones;
  const _MilestoneCard({required this.title, required this.milestones});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    String label(ReferralMilestoneStatus s) => switch (s) {
      ReferralMilestoneStatus.waitingForLearning =>
        l10n.referralsStatusLearning,
      ReferralMilestoneStatus.waitingForAccountLink => l10n.referralsStatusLink,
      ReferralMilestoneStatus.verificationPending =>
        l10n.referralsStatusPending,
      ReferralMilestoneStatus.rewardGranted => l10n.referralsStatusGranted,
      ReferralMilestoneStatus.capReached => l10n.referralsStatusCap,
      ReferralMilestoneStatus.needsReview => l10n.referralsStatusReview,
      ReferralMilestoneStatus.rejected => l10n.referralsStatusRejected,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
            ),
            const SizedBox(height: 6),
            for (final (index, status) in milestones.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${index == 0 ? l10n.referralsFirstUnit : l10n.referralsSecondUnit}: ${label(status)}',
                  style: TextStyle(fontSize: 14, height: 1.35, color: t.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
