import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/account/account_service.dart';
import '../../../data/account/account_identity.dart';
import '../../providers/account_providers.dart';
import '../../providers/curriculum_providers.dart';
import '../../utils/external_links.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/text_prompt_dialog.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountUserProvider);
    final entitlement = ref.watch(curriculumEntitlementProvider);
    final hasReviewerAccess =
        entitlement.asData?.value.isActiveAt(DateTime.now().toUtc()) ?? false;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, title: Text(l10n.accountTitle)),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, _) => _Message(
              icon: Icons.cloud_off,
              title: l10n.accountCloudUnavailableTitle,
              message: l10n.accountCloudUnavailableBody,
            ),
        data:
            (user) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _AccountHeader(user: user),
                if (hasReviewerAccess) ...[
                  const SizedBox(height: 12),
                  _Message(
                    icon: Icons.lock_open_outlined,
                    title: l10n.accountReviewerAccessTitle,
                    message: l10n.accountReviewerAccessBody,
                  ),
                ],
                const SizedBox(height: 20),
                if (userHasIdentityProvider(user, 'google')) ...[
                  _Message(
                    icon: Icons.check_circle_outline,
                    title: l10n.accountGoogleConnectedTitle,
                    message: l10n.accountGoogleConnectedBody,
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  _GoogleSignInButton(
                    onPressed: _busy ? null : _continueWithGoogle,
                  ),
                  const SizedBox(height: 10),
                ],
                if (user?.isAnonymous ?? true) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _linkEmail,
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: Text(l10n.accountProtectWithEmail),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signInExisting,
                    icon: const Icon(Icons.login),
                    label: Text(l10n.accountSignInExisting),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _setPassword,
                    icon: const Icon(Icons.password),
                    label: Text(l10n.accountSetOrChangePassword),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : _sendRecovery,
                  child: Text(l10n.accountSendRecovery),
                ),
                const SizedBox(height: 24),
                SectionLabel(l10n.accountYourData),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _exportData,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l10n.accountExportJson),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: t.red),
                  onPressed: _busy ? null : _deleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(l10n.accountDeleteCloudLocal),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed:
                      () => openExternalPage(context, kAccountDeletionUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.accountDeletionInstructions),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(l10n.accountRequestFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _continueWithGoogle() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final service = ref.read(accountServiceProvider);
      final result = await service.startGoogleSignIn();
      String? success;
      switch (result) {
        case GoogleAccountLinked():
          success = l10n.accountGoogleLinkedSuccess;
        case GoogleAccountAlreadyLinked():
          success = l10n.accountGoogleAlreadyLinked;
        case GoogleAccountNeedsSwitch():
          final accountLabel = result.email ?? l10n.accountGoogleDefaultLabel;
          final confirmed = await _confirm(
            title: l10n.accountUseExistingTitle,
            message: l10n.accountUseExistingBody(accountLabel),
            confirmLabel: l10n.accountSignInReplace,
          );
          if (!confirmed) return;
          await service.completeGoogleSwitch(result);
          success = l10n.accountGoogleRecovered;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(l10n.accountGoogleFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkEmail() async {
    final l10n = AppLocalizations.of(context);
    final email = await _askText(
      title: l10n.accountProtectProgress,
      label: l10n.accountEmail,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null) return;
    await _run(
      () => ref.read(accountServiceProvider).linkEmail(email),
      l10n.accountVerificationSent,
    );
  }

  Future<void> _setPassword() async {
    final l10n = AppLocalizations.of(context);
    final password = await _askText(
      title: l10n.accountSetPassword,
      label: l10n.accountPasswordMinimum,
      obscure: true,
    );
    if (password == null) return;
    if (password.length < 8) {
      _showError(l10n.accountPasswordTooShort);
      return;
    }
    await _run(
      () => ref.read(accountServiceProvider).setPassword(password),
      l10n.accountPasswordUpdated,
    );
  }

  Future<void> _signInExisting() async {
    final l10n = AppLocalizations.of(context);
    final credentials = await _askCredentials();
    if (credentials == null) return;
    final confirmed = await _confirm(
      title: l10n.accountReplaceLocalTitle,
      message: l10n.accountReplaceLocalBody,
      confirmLabel: l10n.accountSignInReplace,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref
          .read(accountServiceProvider)
          .switchToExistingAccount(
            email: credentials.email,
            password: credentials.password,
          );
    }, l10n.accountRecovered);
  }

  Future<void> _sendRecovery() async {
    final l10n = AppLocalizations.of(context);
    final email = await _askText(
      title: l10n.accountPasswordRecovery,
      label: l10n.accountAccountEmail,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null) return;
    await _run(
      () => ref.read(accountServiceProvider).sendPasswordRecovery(email),
      l10n.accountRecoverySent,
    );
  }

  Future<void> _exportData() => _run(
    () => ref.read(accountServiceProvider).shareExport(),
    AppLocalizations.of(context).accountExportPrepared,
  );

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final phrase = await _askText(
      title: l10n.accountPermanentDelete,
      label: l10n.accountDeletePhrase,
    );
    if (phrase != 'DELETE MY ACCOUNT') {
      if (phrase != null) _showError(l10n.accountPhraseMismatch);
      return;
    }

    // The phrase proves intent; a password or Google account chooser proves
    // identity. The server refuses deletion unless the session was minted
    // moments ago.
    String? password;
    if (ref.read(accountServiceProvider).deletionNeedsPassword) {
      password = await _askText(
        title: l10n.accountConfirmIdentity,
        label: l10n.accountPassword,
        obscure: true,
      );
      if (password == null || password.isEmpty) return;
    }

    await _run(
      () => ref
          .read(accountServiceProvider)
          .deleteAccountAndLocalData(password: password),
      l10n.accountDeleted,
    );
  }

  Future<String?> _askText({
    required String title,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
  }) async {
    final result = await showTextPromptDialog(
      context: context,
      title: title,
      confirmLabel: AppLocalizations.of(context).continueLabel,
      fields: [
        TextPromptField(
          label: label,
          obscureText: obscure,
          keyboardType: keyboardType,
        ),
      ],
    );
    final value = result?.single.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<_Credentials?> _askCredentials() async {
    final l10n = AppLocalizations.of(context);
    final result = await showTextPromptDialog(
      context: context,
      title: l10n.accountSignIn,
      confirmLabel: l10n.accountSignIn,
      fields: [
        TextPromptField(
          label: l10n.accountEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        TextPromptField(label: l10n.accountPassword, obscureText: true),
      ],
    );
    if (result == null) return null;
    return _Credentials(result[0].trim(), result[1]);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmLabel),
                ),
              ],
            ),
      ) ??
      false;
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final anonymous = user?.isAnonymous ?? true;
    final l10n = AppLocalizations.of(context);
    return _Message(
      icon: anonymous ? Icons.person_outline : Icons.verified_user_outlined,
      title:
          anonymous ? l10n.accountAnonymousTitle : l10n.accountProtectedTitle,
      message:
          anonymous
              ? l10n.accountAnonymousBody
              : user?.email ?? l10n.accountEmailLinked,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(
          icon: icon,
          tint: context.tokens.priSoft,
          fg: context.tokens.priInk,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: context.tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Uses Google's pre-approved 2026 button artwork unchanged. The graphic has
/// platform-specific padding, so Android and iOS intentionally use different
/// assets instead of approximating the brand treatment with a Material icon.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platform = isIos ? 'ios' : 'android';
    final theme = isDark ? 'dark' : 'light';
    return Center(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: AppLocalizations.of(context).accountSignInGoogle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Opacity(
            opacity: onPressed == null ? 0.5 : 1,
            child: SizedBox(
              height: 48,
              child: ExcludeSemantics(
                child: Image.asset(
                  'assets/images/google_sign_in_${platform}_$theme.png',
                  height: isIos ? 44 : 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Credentials {
  const _Credentials(this.email, this.password);
  final String email;
  final String password;
}
