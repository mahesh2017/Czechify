import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/widgets/common/degraded_mode_banner.dart';
import 'package:ceskina_pro/presentation/providers/tts_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A healthy app was reported broken three times because it silently swapped
/// in a substitute — offline device TTS instead of the recorded pack. The
/// banner exists to say so.
///
/// The two properties that matter: it appears when a substitute is in use, and
/// it is completely absent otherwise. A banner that lingers is noise, and
/// noise gets ignored precisely when it matters.
void main() {
  Future<void> pump(WidgetTester tester, CzechTts tts) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [czechTtsProvider.overrideWithValue(tts)],
        child: MaterialApp(
          theme: lightTheme(),
          home: const Scaffold(body: DegradedModeBanner()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says nothing while the recorded voice is playing', (
    tester,
  ) async {
    final tts = _FakeTts(usingFallback: false);
    await pump(tester, tts);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('explains the substitute when one is in use', (tester) async {
    final tts = _FakeTts(usingFallback: true);
    await pump(tester, tts);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.textContaining('device\'s voice'), findsOneWidget);
  });

  testWidgets('appears and disappears as the state changes', (tester) async {
    final tts = _FakeTts(usingFallback: false);
    await pump(tester, tts);
    expect(find.textContaining('Offline'), findsNothing);

    tts.usingFallbackVoice.value = true;
    await tester.pump();
    expect(find.textContaining('Offline'), findsOneWidget);

    // Reconnecting must clear it without needing a rebuild of the screen.
    tts.usingFallbackVoice.value = false;
    await tester.pump();
    expect(find.textContaining('Offline'), findsNothing);
  });
}

/// Minimal stand-in: the banner only reads [usingFallbackVoice], and building
/// a real CzechTts would drag in platform channels and an audio player.
class _FakeTts implements CzechTts {
  _FakeTts({required bool usingFallback})
    : usingFallbackVoice = ValueNotifier(usingFallback);

  @override
  final ValueNotifier<bool> usingFallbackVoice;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
