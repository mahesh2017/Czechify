import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/safe_diagnostics.dart';
import '../../../core/legal/legal_content.dart';
import '../../../core/updates/app_update_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/app_update_providers.dart';
import '../../routes/app_shell_keys.dart';
import '../../utils/external_links.dart';

/// Runs a quiet Play check after the learner reaches the real app, and checks
/// again when a long-backgrounded app resumes. Nothing here can gate startup.
class AppUpdateCoordinator extends ConsumerStatefulWidget {
  const AppUpdateCoordinator({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  ConsumerState<AppUpdateCoordinator> createState() =>
      _AppUpdateCoordinatorState();
}

class _AppUpdateCoordinatorState extends ConsumerState<AppUpdateCoordinator>
    with WidgetsBindingObserver {
  Timer? _initialCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant AppUpdateCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) _scheduleCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initialCheck?.cancel();
    super.dispose();
  }

  void _scheduleCheck() {
    if (!widget.enabled) return;
    _initialCheck?.cancel();
    // Do not make a Play dialog compete with the first frame, navigation, or
    // the daily-arrival sheet. The check itself is fast and this runs only once
    // per 15-minute foreground session.
    _initialCheck = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final manager = ref.read(appUpdateManagerProvider);
      if (!manager.shouldRunAutomaticCheck()) return;
      unawaited(showAppUpdateFlow(ref: ref, automatic: true));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shared presentation flow used by the automatic coordinator and About.
Future<void> showAppUpdateFlow({
  required WidgetRef ref,
  required bool automatic,
}) async {
  final manager = ref.read(appUpdateManagerProvider);
  if (!manager.tryBeginUiFlow()) {
    final context = rootNavigatorKey.currentContext;
    if (!automatic && context != null) {
      _message(AppLocalizations.of(context).updateCheckAlreadyRunning);
    }
    return;
  }

  try {
    final check = await manager.checkForUpdate();
    ref.read(appUpdateAvailableProvider.notifier).record(check);
    if (automatic && !await manager.shouldOfferAutomatically(check)) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    switch (check.availability) {
      case AppUpdateAvailability.unsupported:
        if (!automatic) {
          _message(AppLocalizations.of(context).updateUnsupported);
        }
      case AppUpdateAvailability.upToDate:
        if (!automatic) {
          _message(AppLocalizations.of(context).updateUpToDate);
        }
      case AppUpdateAvailability.readyToInstall:
        manager.rememberReadyToInstall();
        _showRestartMessage(manager);
      case AppUpdateAvailability.availableInPlayStoreOnly:
        await _offerPlayStoreUpdate(context, manager, check, automatic);
      case AppUpdateAvailability.available:
        await _offerFlexibleUpdate(context, manager, check);
    }
  } catch (error, stack) {
    SafeDiagnostics.error('play_update_check_failed', error, stack);
    final context = rootNavigatorKey.currentContext;
    if (!automatic && context != null && context.mounted) {
      _message(AppLocalizations.of(context).updateCheckFailed);
    }
  } finally {
    manager.endUiFlow();
  }
}

Future<void> _offerFlexibleUpdate(
  BuildContext context,
  AppUpdateManager manager,
  AppUpdateCheck check,
) async {
  final l10n = AppLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder:
        (dialogContext) => AlertDialog(
          icon: const Icon(Icons.system_update_alt),
          title: Text(l10n.updateAvailableTitle),
          content: Text(l10n.updateAvailableBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.updateNotNow),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.updateNow),
            ),
          ],
        ),
  );
  if (accepted == false) {
    await manager.rememberDismissal(check.availableVersionCode);
    return;
  }
  if (accepted == null) return;

  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.updateDownloading),
      duration: const Duration(seconds: 8),
    ),
  );

  try {
    final result = await manager.startFlexibleUpdate();
    messenger.hideCurrentSnackBar();
    switch (result) {
      case AppUpdateDownloadResult.downloaded:
        _showRestartMessage(manager);
      case AppUpdateDownloadResult.cancelled:
        await manager.rememberDismissal(check.availableVersionCode);
        _message(l10n.updateCancelled);
      case AppUpdateDownloadResult.failed:
        _message(l10n.updateStartFailed);
    }
  } catch (error, stack) {
    SafeDiagnostics.error('play_update_download_failed', error, stack);
    _message(l10n.updateStartFailed);
  }
}

Future<void> _offerPlayStoreUpdate(
  BuildContext context,
  AppUpdateManager manager,
  AppUpdateCheck check,
  bool automatic,
) async {
  final l10n = AppLocalizations.of(context);
  final openStore = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder:
        (dialogContext) => AlertDialog(
          icon: const Icon(Icons.shop_outlined),
          title: Text(l10n.updateAvailableTitle),
          content: Text(l10n.updatePlayStoreOnlyBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.updateNotNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.updateOpenPlayStore),
            ),
          ],
        ),
  );
  if (!context.mounted) return;
  if (openStore == true) {
    await openExternalPage(context, kGooglePlayStoreUrl);
  } else if (openStore == false && automatic) {
    await manager.rememberDismissal(check.availableVersionCode);
  }
}

void _showRestartMessage(AppUpdateManager manager) {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !manager.updateReady) return;
  final l10n = AppLocalizations.of(context);
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.updateReady),
      duration: const Duration(days: 1),
      action: SnackBarAction(
        label: l10n.updateRestart,
        onPressed: () async {
          try {
            await manager.completeFlexibleUpdate();
          } catch (error, stack) {
            SafeDiagnostics.error('play_update_install_failed', error, stack);
            final currentContext = rootNavigatorKey.currentContext;
            if (currentContext != null && currentContext.mounted) {
              _message(AppLocalizations.of(currentContext).updateStartFailed);
            }
          }
        },
      ),
    ),
  );
}

void _message(String text) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
