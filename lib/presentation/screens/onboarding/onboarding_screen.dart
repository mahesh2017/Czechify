import 'package:flutter/material.dart';
import '../../../core/diagnostics/safe_diagnostics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/settings_providers.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/tts_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../../domain/entities/enums.dart';

/// Onboarding flow — welcome → level assessment → goal setting.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  CEFRLevel _selectedLevel = CEFRLevel.preA1;
  int _selectedGoal = 50;
  TtsVoiceGender _selectedVoice = TtsVoiceGender.female;
  bool _finishing = false;
  final _nameController = TextEditingController();
  // name → welcome → level → voice → goal
  static const _totalSteps = 5;

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    // Persist choices, but never let a storage hiccup trap the user on
    // onboarding — always mark it complete and navigate home.
    try {
      final settings = ref.read(settingsProvider.notifier);
      await settings.setLearnerName(_nameController.text);
      await settings.setDailyGoalXp(_selectedGoal);
      await settings.setStartingLevel(_selectedLevel);
      // Already written when previewed, but re-asserted so a learner who never
      // tapped a card still gets an explicitly stored choice.
      await settings.setTtsVoiceGender(_selectedVoice);
      await ref.read(gamificationProvider.notifier).setDailyGoal(_selectedGoal);
      await settings.completeOnboarding();
    } catch (error, stack) {
      SafeDiagnostics.error('onboarding_settings_not_saved', error, stack);
      // Best-effort: still try to flip the onboarding flag. If this fails too
      // the learner is stuck being asked to onboard on every launch, so it is
      // worth its own diagnostic rather than silence.
      try {
        await ref.read(settingsProvider.notifier).completeOnboarding();
      } catch (error, stack) {
        SafeDiagnostics.error('onboarding_flag_not_set', error, stack);
      }
    }

    // Straight into the offline download rather than home: this is the first
    // point the chosen voice is known, and only that voice is fetched.
    if (mounted) context.go('/setup');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: SoftProgressBar(
                value: (_step + 1) / _totalSteps,
                height: 6,
              ),
            ),
            Expanded(
              // The footer is pinned, so a step taller than the viewport gets
              // clipped mid-widget right where the Continue button starts. The
              // fade below the scroll area keeps that reading as "there is more
              // to scroll" rather than as two overlapping buttons.
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                    child: _buildStep(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 28,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [t.bg.withValues(alpha: 0), t.bg],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _finishing ? null : _back,
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: t.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                  Expanded(
                    child: PrimaryButton(
                      label:
                          _step < _totalSteps - 1 ? 'Continue' : 'Get started',
                      onPressed: _finishing ? null : _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildNameStep(),
      1 => _buildWelcomeStep(),
      2 => _buildLevelStep(),
      3 => _buildVoiceStep(),
      4 => _buildGoalStep(),
      _ => const SizedBox(),
    };
  }

  Widget _buildNameStep() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: t.priSoft, shape: BoxShape.circle),
            child: Icon(Icons.waving_hand_outlined, size: 44, color: t.pri),
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: DisplayText('Ahoj! 👋', size: 34)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'What should we call you?',
            style: TextStyle(fontSize: 16, color: t.muted),
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Your first name',
            hintStyle: TextStyle(color: t.faint),
            filled: true,
            fillColor: t.elev,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
          style: TextStyle(
            fontSize: 17,
            color: t.ink,
            fontWeight: FontWeight.w600,
          ),
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll use your name to personalize your learning experience. '
          'You can change it later in Settings.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: t.faint, height: 1.4),
        ),
      ],
    );
  }

  Widget _stepHeader(
    IconData icon,
    Color tint,
    Color fg,
    String title,
    String subtitle,
  ) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: fg),
          ),
        ),
        const SizedBox(height: 22),
        Center(child: DisplayText(title, size: 26)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.5, color: t.muted, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildWelcomeStep() {
    final t = context.tokens;
    const features = [
      (
        Icons.route_outlined,
        'A clear path',
        'Short lessons that build from your first sound to real conversations',
      ),
      (
        Icons.mic_none_rounded,
        'Speak from day one',
        'Pronunciation practice and patient, practical feedback',
      ),
      (
        Icons.forum_outlined,
        'Czech for your life',
        'Role-play cafés, doctors, work and everyday situations',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 3,
            child: Image.asset(
              'assets/images/onboarding_hero_v2.png',
              fit: BoxFit.cover,
              semanticLabel:
                  'A learner practising Czech with a tutor at a Prague café',
            ),
          ),
        ),
        const SizedBox(height: 22),
        const DisplayText(
          'Czech that actually sticks.',
          size: 32,
          height: 1.06,
        ),
        const SizedBox(height: 9),
        Text(
          'Built for people living in Czechia — from your first word to everyday independence.',
          style: TextStyle(fontSize: 16, color: t.muted, height: 1.5),
        ),
        const SizedBox(height: 22),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: t.card,
                border: Border(bottom: BorderSide(color: t.line)),
              ),
              child: Row(
                children: [
                  IconTile(
                    icon: f.$1,
                    tint: t.priSoft,
                    fg: t.pri,
                    size: 36,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.$2,
                          style: TextStyle(
                            fontSize: 15,
                            color: t.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f.$3,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: t.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Sign-up / Sign-in — only when the cloud backend is configured.
        if (BackendConfig.isConfigured) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Create an account'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.login),
            label: const Text('I already have an account'),
          ),
          const SizedBox(height: 8),
          Text(
            'You can also continue without an account and sign in later from Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.faint, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _buildLevelStep() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.assessment_outlined,
          t.priSoft,
          t.pri,
          'What\'s your Czech level?',
          'This sets your AI tutor\'s difficulty. Lessons always start from Unit 1 so nothing is skipped.',
        ),
        const SizedBox(height: 28),
        _ChoiceCard(
          title: 'Complete beginner',
          subtitle: 'I don\'t know any Czech yet',
          isSelected: _selectedLevel == CEFRLevel.preA1,
          onTap: () => setState(() => _selectedLevel = CEFRLevel.preA1),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Some Czech (A1)',
          subtitle: 'I know basic greetings and simple phrases',
          isSelected: _selectedLevel == CEFRLevel.a1,
          onTap: () => setState(() => _selectedLevel = CEFRLevel.a1),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Intermediate (A2)',
          subtitle: 'I can have basic conversations',
          isSelected: _selectedLevel == CEFRLevel.a2,
          onTap: () => setState(() => _selectedLevel = CEFRLevel.a2),
        ),
      ],
    );
  }

  /// Tapping a voice applies it immediately and speaks a sample.
  ///
  /// The setting has to be written before speaking, not at the end of
  /// onboarding: the neural path picks its clip by the *current* voice, so a
  /// preview that ignored the tap would play the other voice.
  Future<void> _previewVoice(TtsVoiceGender voice) async {
    setState(() => _selectedVoice = voice);
    await ref.read(settingsProvider.notifier).setTtsVoiceGender(voice);
    if (!mounted) return;
    await ref.read(czechTtsProvider).speak(kVoicePreviewPhrase);
  }

  Widget _buildVoiceStep() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.record_voice_over_outlined,
          t.priSoft,
          t.pri,
          'Choose your teacher\'s voice',
          'Every Czech word in the course is spoken by this voice. Tap to hear each one — you can change it any time from Settings.',
        ),
        const SizedBox(height: 28),
        _ChoiceCard(
          title: 'Female voice',
          subtitle: 'Tap to hear a sample',
          isSelected: _selectedVoice == TtsVoiceGender.female,
          onTap: () => _previewVoice(TtsVoiceGender.female),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Male voice',
          subtitle: 'Tap to hear a sample',
          isSelected: _selectedVoice == TtsVoiceGender.male,
          onTap: () => _previewVoice(TtsVoiceGender.male),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_up_outlined, size: 16, color: t.faint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Both are studio-recorded native Czech.',
                style: TextStyle(fontSize: 13, color: t.faint),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalStep() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.flag_outlined,
          t.amberSoft,
          t.amber,
          'Set your daily goal',
          'How much do you want to practice each day?',
        ),
        const SizedBox(height: 28),
        for (final g in const [
          (20, 'Casual', '5 minutes/day'),
          (50, 'Regular', '15 minutes/day'),
          (100, 'Serious', '30 minutes/day'),
          (150, 'Intense', '45+ minutes/day'),
        ]) ...[
          _ChoiceCard(
            title: '${g.$2} — ${g.$1} XP',
            subtitle: g.$3,
            isSelected: _selectedGoal == g.$1,
            onTap: () => setState(() => _selectedGoal = g.$1),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// A selectable option card used for the level and goal steps.
class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: isSelected ? t.priSoft : t.card,
      border: isSelected ? Border.all(color: t.pri, width: 1.5) : null,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? t.pri : t.faint,
            size: 24,
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
                    color: isSelected ? t.priInk : t.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 14, color: t.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
