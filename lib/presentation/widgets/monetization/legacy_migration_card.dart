import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/monetization/monetization_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/legacy_migration_providers.dart';
import '../common/soft_ui.dart';

/// Tells a learner from before subscriptions what they keep: the whole
/// course until grace ends, and the units they had reached for good. Offers
/// the one offline claim when this device's record would add units.
///
/// On Home it can be put away and disappears when grace ends; on the upgrade
/// screen it always explains why the paywall looks the way it does.
class LegacyMigrationCard extends ConsumerStatefulWidget {
  final bool dismissible;
  const LegacyMigrationCard({super.key, this.dismissible = false});

  @override
  ConsumerState<LegacyMigrationCard> createState() =>
      _LegacyMigrationCardState();
}

class _LegacyMigrationCardState extends ConsumerState<LegacyMigrationCard> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(legacyMigrationStatusProvider).value;
    if (status == null || !status.eligible) return const SizedBox.shrink();
    final graceActive = DateTime.now().isBefore(status.graceEndsAt);
    if (widget.dismissible &&
        (!graceActive ||
            ref.watch(legacyNoticeDismissedProvider).value != false)) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final format = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String date(DateTime value) => format.format(value.toLocal());
    final record = ref.watch(legacyLessonRecordProvider).value;
    final pending =
        status.claim?.status == 'needs_review' ? l10n.legacyClaimReview : null;
    final message = _message ?? pending;
    final text = TextStyle(fontSize: 14, height: 1.4, color: t.muted);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.dismissible ? 12 : 14),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: Icons.workspace_premium_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.legacyTitle,
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
              graceActive
                  ? l10n.legacyGraceBody(
                    date(status.cutoffAt),
                    date(status.graceEndsAt),
                  )
                  : l10n.legacyGraceEndedBody(date(status.graceEndsAt)),
              style: text,
            ),
            const SizedBox(height: 8),
            Text(
              status.legacyUnitIds.isEmpty
                  ? l10n.legacyNoKeptUnits
                  : l10n.legacyKeptUnits(status.legacyUnitIds.join(', ')),
              style: text,
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: TextStyle(fontSize: 14, height: 1.4, color: t.ink),
                ),
              ),
            ] else if (record != null) ...[
              const SizedBox(height: 12),
              Text(l10n.legacyClaimBody(date(status.cutoffAt)), style: text),
              const SizedBox(height: 12),
              PrimaryButton(
                label: l10n.legacyClaimAction,
                height: 48,
                onPressed: _busy ? null : _claim,
              ),
            ],
            if (widget.dismissible) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => ref.read(dismissLegacyNoticeProvider)(),
                  child: Text(l10n.legacyDismiss),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _claim() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    String message;
    try {
      final claim = await ref.read(legacyClaimProvider)();
      message = switch (claim.status) {
        'applied' when claim.unitIds.isEmpty => l10n.legacyClaimNothingNew,
        'applied' => l10n.legacyClaimApplied(claim.unitIds.join(', ')),
        'needs_review' => l10n.legacyClaimReview,
        _ => l10n.legacyClaimRejected,
      };
    } on LegacyClaimException catch (error) {
      message = switch (error.code) {
        'already_claimed' => l10n.legacyClaimAlready,
        'claim_window_closed' => l10n.legacyClaimClosed,
        _ => l10n.legacyClaimFailed,
      };
    } on Exception {
      message = l10n.legacyClaimFailed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      // A failure leaves the button for another try.
      _message = message == l10n.legacyClaimFailed ? null : message;
    });
    if (_message == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
