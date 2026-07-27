import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_tokens.dart';
import '../../providers/account_providers.dart';
import '../../widgets/common/soft_ui.dart';

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
    final account = ref.watch(accountUserProvider);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        title: const Text('Account & data'),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, _) => const _Message(
              icon: Icons.cloud_off,
              title: 'Cloud account unavailable',
              message:
                  'The app is offline or cloud configuration is unavailable.',
            ),
        data:
            (user) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _AccountHeader(user: user),
                const SizedBox(height: 20),
                if (user?.isAnonymous ?? true) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _linkEmail,
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('Protect progress with email'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signInExisting,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in to an existing account'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _setPassword,
                    icon: const Icon(Icons.password),
                    label: const Text('Set or change password'),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : _sendRecovery,
                  child: const Text('Send password recovery email'),
                ),
                const SizedBox(height: 24),
                const SectionLabel('Your data'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _exportData,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export my data as JSON'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: t.red),
                  onPressed: _busy ? null : _deleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete cloud account and local data'),
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
      _showError('The request could not be completed. Try again.');
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

  Future<void> _linkEmail() async {
    final email = await _askText(
      title: 'Protect progress',
      label: 'Email',
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null) return;
    await _run(
      () => ref.read(accountServiceProvider).linkEmail(email),
      'Verification email sent. Open its link, then set a password here.',
    );
  }

  Future<void> _setPassword() async {
    final password = await _askText(
      title: 'Set password',
      label: 'Password (at least 8 characters)',
      obscure: true,
    );
    if (password == null) return;
    if (password.length < 8) {
      _showError('Use at least 8 characters.');
      return;
    }
    await _run(
      () => ref.read(accountServiceProvider).setPassword(password),
      'Password updated.',
    );
  }

  Future<void> _signInExisting() async {
    final credentials = await _askCredentials();
    if (credentials == null) return;
    final confirmed = await _confirm(
      title: 'Replace local learner data?',
      message:
          'This device will remove its current learner progress, sign in, and '
          'download the selected account. Export first if you need a copy.',
      confirmLabel: 'Sign in and replace',
    );
    if (!confirmed) return;
    await _run(() async {
      await ref
          .read(accountServiceProvider)
          .switchToExistingAccount(
            email: credentials.email,
            password: credentials.password,
          );
    }, 'Account recovered and synchronized.');
  }

  Future<void> _sendRecovery() async {
    final email = await _askText(
      title: 'Password recovery',
      label: 'Account email',
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null) return;
    await _run(
      () => ref.read(accountServiceProvider).sendPasswordRecovery(email),
      'If that account exists, a recovery email has been sent.',
    );
  }

  Future<void> _exportData() => _run(
    () => ref.read(accountServiceProvider).shareExport(),
    'Export prepared.',
  );

  Future<void> _deleteAccount() async {
    final phrase = await _askText(
      title: 'Permanently delete account',
      label: 'Type DELETE MY ACCOUNT',
    );
    if (phrase != 'DELETE MY ACCOUNT') {
      if (phrase != null) _showError('Confirmation phrase did not match.');
      return;
    }

    // The phrase proves intent; the password proves identity. Without it a
    // stolen session could delete the account, so the server refuses a
    // deletion unless the session was minted moments ago.
    String? password;
    if (ref.read(accountServiceProvider).deletionNeedsPassword) {
      password = await _askText(
        title: 'Confirm it is you',
        label: 'Account password',
        obscure: true,
      );
      if (password == null || password.isEmpty) return;
    }

    await _run(
      () => ref
          .read(accountServiceProvider)
          .deleteAccountAndLocalData(password: password),
      'Cloud account and learner data deleted.',
    );
  }

  Future<String?> _askText({
    required String title,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
    controller.dispose();
    return value?.isEmpty == true ? null : value;
  }

  Future<_Credentials?> _askCredentials() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final value = await showDialog<_Credentials>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Sign in'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      dialogContext,
                      _Credentials(email.text.trim(), password.text),
                    ),
                child: const Text('Sign in'),
              ),
            ],
          ),
    );
    email.dispose();
    password.dispose();
    return value;
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
                  child: const Text('Cancel'),
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
    return _Message(
      icon: anonymous ? Icons.person_outline : Icons.verified_user_outlined,
      title: anonymous ? 'Anonymous account' : 'Protected account',
      message:
          anonymous
              ? 'Progress syncs on this installation, but cannot be recovered on '
                  'another device until you link an email.'
              : user?.email ?? 'Email identity linked',
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.tokens.pri),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Credentials {
  const _Credentials(this.email, this.password);
  final String email;
  final String password;
}
