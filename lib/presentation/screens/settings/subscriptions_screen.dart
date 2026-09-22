import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/monetization/billing_flow.dart';
import '../../../data/monetization/monetization_api.dart';
import '../../../domain/entities/monetization_snapshot.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/account_providers.dart';
import '../../providers/billing_providers.dart';
import '../../providers/monetization_providers.dart';
import '../../utils/external_links.dart';
import '../../widgets/common/soft_ui.dart';

/// Core and AI chat subscriptions: Store prices, current status, purchase,
/// restore and management in Google Play. Access shown here comes only from
/// the server-signed entitlement snapshot, never from the store on its own.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final supported = ref.watch(billingPlatformSupportedProvider);
    final checkout = ref.watch(checkoutEnabledProvider).value ?? false;
    // The AI plan states the limit the server enforces, not a copy of it.
    final aiDailyTurnLimit =
        ref.watch(monetizationConfigurationProvider).value?.aiDailyTurnLimit ??
        MonetizationConfiguration.defaultAiDailyTurnLimit;
    final user = ref.watch(accountUserProvider).value;
    final linked = user != null && !user.isAnonymous;
    final billing = ref.watch(billingProvider);
    final load = ref.watch(monetizationLoadProvider).value;
    final snapshot = load?.document?.snapshot;
    bool active(FeatureEntitlement? feature) =>
        feature != null &&
        load != null &&
        feature.isActiveAt(load.now, offline: load.offline);

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
                Expanded(child: DisplayText(l10n.subscriptionsTitle, size: 24)),
              ],
            ),
            const SizedBox(height: 16),
            if (!supported)
              _Message(text: l10n.subscriptionsUnavailable)
            else ...[
              if (!checkout) _Message(text: l10n.billingNoticeCheckoutDisabled),
              if (!linked) ...[
                _LinkAccountCard(onLink: () => context.push('/account')),
                const SizedBox(height: 16),
              ],
              if (billing.notice != BillingNotice.none) ...[
                _Message(text: _noticeText(l10n, billing.notice)),
                const SizedBox(height: 16),
              ],
              // Support can move a purchase that belongs to another account.
              if (billing.notice == BillingNotice.bindingMismatch &&
                  billing.supportReference != null) ...[
                _SupportRecovery(reference: billing.supportReference!),
                const SizedBox(height: 16),
              ],
              for (final (id, title, body, feature) in [
                (
                  'czechify_core',
                  l10n.subscriptionsCoreTitle,
                  l10n.subscriptionsCoreBody,
                  snapshot?.core,
                ),
                (
                  'czechify_ai',
                  l10n.subscriptionsAiTitle,
                  l10n.subscriptionsAiBodyLimit(aiDailyTurnLimit),
                  snapshot?.aiChat,
                ),
              ]) ...[
                _ProductCard(
                  title: title,
                  body: body,
                  price: billing.products[id]?.price,
                  activeUntil: active(feature) ? feature!.validUntil : null,
                  busy: billing.busyProductId == id,
                  onSubscribe:
                      checkout &&
                              linked &&
                              !active(feature) &&
                              billing.products[id] != null &&
                              billing.busyProductId == null &&
                              !billing.restoring
                          ? () => ref.read(billingProvider.notifier).buy(id)
                          : null,
                ),
                const SizedBox(height: 14),
              ],
              Text(
                l10n.subscriptionsSeparateNote,
                style: TextStyle(fontSize: 14, height: 1.4, color: t.muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed:
                    linked &&
                            !billing.restoring &&
                            billing.busyProductId == null
                        ? () => ref.read(billingProvider.notifier).restore()
                        : null,
                icon:
                    billing.restoring
                        ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.restore),
                label: Text(l10n.subscriptionsRestore),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _manage(context),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.subscriptionsManage),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Google Play's own subscription management; cancelling happens there.
  Future<void> _manage(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    await openExternalPage(
      context,
      'https://play.google.com/store/account/subscriptions'
      '?package=${Uri.encodeQueryComponent(info.packageName)}',
    );
  }

  static String _noticeText(AppLocalizations l10n, BillingNotice notice) =>
      switch (notice) {
        BillingNotice.none => '',
        BillingNotice.checkoutDisabled => l10n.billingNoticeCheckoutDisabled,
        BillingNotice.linkedAccountRequired => l10n.subscriptionsLinkTitle,
        BillingNotice.storeUnavailable => l10n.billingNoticeStoreUnavailable,
        BillingNotice.paymentPending => l10n.billingNoticePaymentPending,
        BillingNotice.verifying => l10n.billingNoticeVerifying,
        BillingNotice.provisioned => l10n.billingNoticeProvisioned,
        BillingNotice.nothingToRestore => l10n.billingNoticeNothingToRestore,
        BillingNotice.accountChanged => l10n.billingNoticeAccountChanged,
        BillingNotice.bindingMismatch => l10n.billingNoticeBindingMismatch,
        BillingNotice.canceled => l10n.billingNoticeCanceled,
        BillingNotice.failed => l10n.billingNoticeFailed,
      };
}

class _ProductCard extends StatelessWidget {
  final String title;
  final String body;
  final String? price;
  final DateTime? activeUntil;
  final bool busy;
  final VoidCallback? onSubscribe;

  const _ProductCard({
    required this.title,
    required this.body,
    required this.price,
    required this.activeUntil,
    required this.busy,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final until = activeUntil;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 14, height: 1.4, color: t.muted),
          ),
          const SizedBox(height: 12),
          Text(
            price == null
                ? l10n.subscriptionsPriceUnavailable
                : l10n.subscriptionsPerMonth(price!),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            until == null
                ? l10n.subscriptionsNotSubscribed
                : l10n.subscriptionsActiveUntil(
                  DateFormat.yMMMd(locale).format(until.toLocal()),
                ),
            style: TextStyle(
              fontSize: 14,
              color: until == null ? t.muted : t.pri,
            ),
          ),
          if (until == null) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: l10n.subscriptionsSubscribe,
              height: 48,
              onPressed: busy ? null : onSubscribe,
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkAccountCard extends StatelessWidget {
  final VoidCallback onLink;
  const _LinkAccountCard({required this.onLink});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return SoftCard(
      color: t.priSoft,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.subscriptionsLinkTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.subscriptionsLinkBody,
            style: TextStyle(fontSize: 14, height: 1.4, color: t.ink),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: l10n.subscriptionsLinkAction,
            height: 48,
            onPressed: onLink,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: TextStyle(fontSize: 15, height: 1.4, color: t.ink),
      ),
    );
  }
}

class _SupportRecovery extends StatelessWidget {
  final String reference;
  const _SupportRecovery({required this.reference});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.subscriptionsRecoveryBody,
          style: TextStyle(fontSize: 14, height: 1.4, color: t.muted),
        ),
        const SizedBox(height: 6),
        SelectableText(
          l10n.subscriptionsRecoveryReference(reference),
          style: TextStyle(fontSize: 14, color: t.ink),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.mail_outline),
          label: Text(l10n.subscriptionsRecoveryContact),
          // Percent-encoded through Uri, so the reference survives intact.
          onPressed:
              () => openExternalPage(
                context,
                Uri(
                  scheme: 'mailto',
                  path: kSupportEmail,
                  queryParameters: {
                    'subject': 'Czechify purchase recovery $reference',
                  },
                ).toString(),
              ),
        ),
      ],
    );
  }
}
