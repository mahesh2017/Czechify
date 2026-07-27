import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tts_providers.dart';
import '../onboarding/offline_setup_screen.dart';
import '../../../data/services/audio/offline_audio_prefetch.dart';
import '../../providers/audio_prefetch_providers.dart';
import '../../widgets/common/soft_ui.dart';

/// Settings screen — theme, daily goal, TTS rate, cache management.
/// The AI tutor credential lives in the `deepseek-proxy` Edge Function, never
/// in the client, so there is no API-key entry here.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: ref.read(settingsProvider).learnerName,
    );
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Your name'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your first name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) {
      await ref.read(settingsProvider.notifier).setLearnerName(result);
    }
  }

  /// Switch voice, and fetch that voice's audio if it is not on device yet.
  ///
  /// Only the voice chosen at onboarding is downloaded, so switching can leave
  /// a learner with no clips for the new voice. Offline that means silence —
  /// which reads as a broken app rather than a missing download, so it is
  /// explained rather than left to be discovered.
  Future<void> _switchVoice(TtsVoiceGender gender) async {
    await ref.read(settingsProvider.notifier).setTtsVoiceGender(gender);

    final prefetch = ref.read(offlineAudioPrefetchProvider);
    final missing = await prefetch.missingFiles(
      OfflineSetupScreen.unitsToPrefetch,
      gender.name,
    );
    if (missing.isEmpty) {
      if (mounted) await ref.read(czechTtsProvider).speak(kVoicePreviewPhrase);
      return;
    }

    // Try to fetch it now. If the network is there this is a few megabytes and
    // finishes while the dialog is open; if not, we say so plainly.
    if (!mounted) return;
    final downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _VoiceDownloadDialog(
            gender: gender,
            missingCount: missing.length,
          ),
    );

    if (!mounted) return;
    if (downloaded ?? false) {
      await ref.read(czechTtsProvider).speak(kVoicePreviewPhrase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
                ),
                const DisplayText('Settings', size: 24),
              ],
            ),
            const SizedBox(height: 8),

            // ── Profile ──
            const _GroupLabel('Profile'),
            _Group(
              children: [
                _Row(
                  icon: Icons.person_outline,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsYourName,
                  subtitle:
                      settings.learnerName.isEmpty
                          ? 'Not set'
                          : settings.learnerName,
                  onTap: () => _editName(context, ref),
                ),
              ],
            ),

            // ── Account (only when backend is configured) ──
            if (BackendConfig.isConfigured) ...[
              const _GroupLabel('Account'),
              _Group(
                children: [
                  _Row(
                    icon: Icons.manage_accounts_outlined,
                    tint: t.priSoft,
                    fg: t.pri,
                    title: 'Account, sign in & data',
                    subtitle: 'Protect, recover, export, or delete your data',
                    onTap: () => context.push('/account'),
                  ),
                ],
              ),
            ],

            // ── Appearance ──
            const _GroupLabel('Appearance'),
            _Group(
              children: [
                _Row(
                  icon: Icons.dark_mode_outlined,
                  tint: t.violetSoft,
                  fg: t.violet,
                  title: l10n.settingsTheme,
                  subtitle: _themeLabel(settings.themeMode),
                  trailing: _ThemeToggle(
                    mode: settings.themeMode,
                    onChanged:
                        (m) =>
                            ref.read(settingsProvider.notifier).setThemeMode(m),
                  ),
                ),
                _Row(
                  icon: Icons.translate_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsLanguage,
                  subtitle: switch (settings.locale?.languageCode) {
                    'cs' => 'Čeština',
                    'en' => 'English',
                    _ => l10n.settingsLanguageSystem,
                  },
                  trailing: DropdownButton<String>(
                    value: settings.locale?.languageCode ?? '',
                    underline: const SizedBox.shrink(),
                    style: TextStyle(
                      color: t.pri,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n.settingsLanguageSystem),
                      ),
                      const DropdownMenuItem(
                        value: 'en',
                        child: Text('English'),
                      ),
                      const DropdownMenuItem(
                        value: 'cs',
                        child: Text('Čeština'),
                      ),
                    ],
                    onChanged: (code) {
                      ref
                          .read(settingsProvider.notifier)
                          .setLocale(
                            code == null || code.isEmpty ? null : Locale(code),
                          );
                    },
                  ),
                ),
              ],
            ),

            // ── Learning ──
            const _GroupLabel('Learning'),
            _Group(
              children: [
                _Row(
                  icon: Icons.flag_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsDailyGoal,
                  subtitle: l10n.settingsXpPerDay(settings.dailyGoalXp),
                  trailing: DropdownButton<int>(
                    value: settings.dailyGoalXp,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(
                      color: t.pri,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    onChanged: (xp) {
                      if (xp != null) {
                        ref.read(settingsProvider.notifier).setDailyGoalXp(xp);
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 20, child: Text('Casual')),
                      DropdownMenuItem(value: 50, child: Text('Regular')),
                      DropdownMenuItem(value: 100, child: Text('Serious')),
                      DropdownMenuItem(value: 150, child: Text('Intense')),
                    ],
                  ),
                ),
                _Divider(),
                _Row(
                  icon: Icons.favorite_border,
                  tint: t.redSoft,
                  fg: t.red,
                  title: l10n.settingsHearts,
                  subtitle: 'Off = practice freely',
                  trailing: Switch(
                    value: settings.heartsEnabled,
                    onChanged:
                        (v) => ref
                            .read(settingsProvider.notifier)
                            .setHeartsEnabled(v),
                  ),
                ),
                _Divider(),
                // Separate from the Czech audio below on purpose: someone who
                // wants a quiet app still needs to hear the language.
                _Row(
                  icon: Icons.music_note_outlined,
                  tint: t.amberSoft,
                  fg: t.amber,
                  title: l10n.settingsSoundEffects,
                  subtitle: 'Answers and celebrations',
                  trailing: Switch(
                    value: settings.soundEffectsEnabled,
                    onChanged:
                        (v) => ref
                            .read(settingsProvider.notifier)
                            .setSoundEffectsEnabled(v),
                  ),
                ),
                _Divider(),
                _Row(
                  icon: Icons.vibration,
                  tint: t.violetSoft,
                  fg: t.violet,
                  title: l10n.settingsVibration,
                  subtitle: 'A tap you can feel',
                  trailing: Switch(
                    value: settings.hapticsEnabled,
                    onChanged:
                        (v) => ref
                            .read(settingsProvider.notifier)
                            .setHapticsEnabled(v),
                  ),
                ),
              ],
            ),

            // ── Audio ──
            const _GroupLabel('Audio'),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconTile(
                            icon: Icons.person_outline,
                            tint: t.priSoft,
                            fg: t.pri,
                            size: 36,
                            radius: 12,
                            iconSize: 17,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Teacher\'s voice',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: t.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Speaks every Czech word in the course',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<TtsVoiceGender>(
                        segments: const [
                          ButtonSegment(
                            value: TtsVoiceGender.female,
                            label: Text('Female'),
                          ),
                          ButtonSegment(
                            value: TtsVoiceGender.male,
                            label: Text('Male'),
                          ),
                        ],
                        selected: {settings.ttsVoiceGender},
                        onSelectionChanged: (selection) async {
                          await _switchVoice(selection.single);
                        },
                      ),
                    ],
                  ),
                ),
                _Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconTile(
                            icon: Icons.record_voice_over_outlined,
                            tint: t.amberSoft,
                            fg: t.amber,
                            size: 36,
                            radius: 12,
                            iconSize: 15,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Speech rate',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.ink,
                                  ),
                                ),
                                Text(
                                  '${(settings.ttsSpeechRate * 100).round()}% — slower is easier',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.ttsSpeechRate,
                        min: 0.2,
                        max: 1.0,
                        divisions: 8,
                        onChanged:
                            (value) => ref
                                .read(settingsProvider.notifier)
                                .setTtsSpeechRate(value),
                      ),
                    ],
                  ),
                ),
                _Divider(),
                _Row(
                  icon: Icons.play_arrow_rounded,
                  tint: t.greenSoft,
                  fg: t.green,
                  title: l10n.settingsTestVoice,
                  subtitle: 'Play a sample Czech phrase',
                  onTap:
                      () =>
                          ref.read(czechTtsProvider).speak('Ahoj, jak se máš?'),
                ),
                _Divider(),
                _Row(
                  icon: Icons.delete_outline,
                  tint: t.chipBg,
                  fg: t.muted,
                  title: l10n.settingsClearAudioCache,
                  subtitle: 'Remove cached audio files',
                  onTap: () async {
                    await ref.read(czechTtsProvider).clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('TTS cache cleared')),
                      );
                    }
                  },
                ),
              ],
            ),

            // ── AI configuration ──
            const _GroupLabel('Account & data'),
            _Group(
              children: [
                _Row(
                  icon: Icons.manage_accounts_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: 'Account, export & deletion',
                  subtitle: 'Protect, recover, export, or delete your data',
                  onTap: () => context.push('/account'),
                ),
              ],
            ),

            // ── About ──
            const _GroupLabel('About'),
            _Group(
              children: [
                _Row(
                  icon: Icons.school_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsAbout,
                  subtitle: 'What the app does · by $kDeveloperName',
                  onTap: () => context.push('/about'),
                  trailing: Icon(Icons.chevron_right, size: 15, color: t.faint),
                ),
                _Divider(),
                _Row(
                  icon: Icons.code,
                  tint: t.chipBg,
                  fg: t.muted,
                  title: l10n.settingsVersion,
                  subtitle: '1.0.0',
                  trailing: const SizedBox.shrink(),
                ),
                _Divider(),
                _Row(
                  icon: Icons.privacy_tip_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsPrivacyPolicy,
                  subtitle: 'Read in full, in the app',
                  onTap: () => context.push('/privacy'),
                  trailing: Icon(Icons.chevron_right, size: 15, color: t.faint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => 'System default',
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
    };
  }
}

class _GroupLabel extends StatelessWidget {
  final String title;
  const _GroupLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: SectionLabel(title),
    );
  }
}

/// A rounded card grouping settings rows.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: t.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.tokens.line);
}

/// A settings row: tinted icon tile, title, subtitle, optional trailing.
class _Row extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final Color fg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.tint,
    required this.fg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              tint: tint,
              fg: fg,
              size: 36,
              radius: 12,
              iconSize: 15,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: t.muted,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right, size: 15, color: t.faint)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// Light / Auto / Dark segmented control.
class _ThemeToggle extends StatelessWidget {
  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  const _ThemeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(String label, AppThemeMode m) {
      final selected = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? t.card : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? t.shadow : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? t.ink : t.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('Light', AppThemeMode.light),
          seg('Auto', AppThemeMode.system),
          seg('Dark', AppThemeMode.dark),
        ],
      ),
    );
  }
}

/// Downloads the newly chosen voice's audio, or explains why it cannot.
///
/// The distinction matters: silence from a missing download is not a broken
/// app, and a learner who is told "connect to Wi-Fi to save this voice" will
/// wait, whereas one who just hears nothing concludes the app is faulty and
/// leaves. Pops `true` once the audio is on device.
class _VoiceDownloadDialog extends ConsumerStatefulWidget {
  const _VoiceDownloadDialog({
    required this.gender,
    required this.missingCount,
  });

  final TtsVoiceGender gender;
  final int missingCount;

  @override
  ConsumerState<_VoiceDownloadDialog> createState() =>
      _VoiceDownloadDialogState();
}

class _VoiceDownloadDialogState extends ConsumerState<_VoiceDownloadDialog> {
  PrefetchProgress? _progress;
  bool _offline = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _offline = false;
      _done = false;
      _progress = null;
    });
    try {
      await for (final progress in ref
          .read(offlineAudioPrefetchProvider)
          .download(OfflineSetupScreen.unitsToPrefetch, widget.gender.name)) {
        if (!mounted) return;
        setState(() => _progress = progress);
        if (progress.finished) {
          // Everything failing is a connection problem, not bad luck.
          _offline = progress.total > 0 && progress.failed == progress.total;
          _done = true;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _offline = _done = true);
    }
    if (mounted && _done && !_offline) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = widget.gender == TtsVoiceGender.male ? 'male' : 'female';
    final progress = _progress;

    return AlertDialog(
      icon: Icon(
        _offline ? Icons.wifi_off_rounded : Icons.download_rounded,
        color: _offline ? t.amber : t.pri,
      ),
      title: Text(
        _offline ? 'Connect to save this voice' : 'Saving the $label voice',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _offline
                ? 'The $label voice isn\'t saved on your device yet, and there\'s '
                    'no connection right now. Connect to Wi-Fi or mobile data '
                    'and try again — it\'s only a few megabytes.'
                : 'Downloading ${widget.missingCount} clips so this voice works '
                    'offline too.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: t.muted, height: 1.45),
          ),
          if (!_offline) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress?.fraction ?? 0),
          ],
        ],
      ),
      actions: [
        if (_offline)
          TextButton(onPressed: _run, child: const Text('Try again')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_offline ? 'Not now' : 'Hide'),
        ),
      ],
    );
  }
}
