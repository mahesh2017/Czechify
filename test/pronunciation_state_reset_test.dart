import 'package:ceskina_pro/domain/entities/pronunciation_result.dart';
import 'package:ceskina_pro/presentation/providers/pronunciation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A score from the previous exercise appeared on the next one before the
/// learner had spoken: [pronunciationProvider] outlives the exercise widget,
/// so its result was still there when the new exercise first built.
void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  PronunciationState withResult(PronunciationState base) => base.copyWith(
    result: const PronunciationResult(
      overallScore: 0.92,
      wordScores: [],
      problemSounds: [],
      feedback: 'Skvělé! Výborná výslovnost.',
    ),
  );

  test('moving to a new target clears the previous result', () {
    final container = makeContainer();
    final notifier = container.read(pronunciationProvider.notifier);

    notifier.setExpectedText('řeka');
    notifier.state = withResult(container.read(pronunciationProvider));
    expect(container.read(pronunciationProvider).result, isNotNull);

    notifier.setExpectedText('voda');
    expect(
      container.read(pronunciationProvider).result,
      isNull,
      reason: 'the next exercise must start with no score',
    );
  });

  test('repeating the same target still clears the result', () {
    // The original bug: setExpectedText short-circuited when the text was
    // unchanged, so two exercises sharing a target kept the old score.
    final container = makeContainer();
    final notifier = container.read(pronunciationProvider.notifier);

    notifier.setExpectedText('řeka');
    notifier.state = withResult(container.read(pronunciationProvider));

    notifier.setExpectedText('řeka');
    expect(container.read(pronunciationProvider).result, isNull);
  });

  test('each target gets a distinct attempt id', () {
    // The view adopts a result only when the attempt id matches the one it
    // started, so ids must advance even when the text repeats.
    final container = makeContainer();
    final notifier = container.read(pronunciationProvider.notifier);

    notifier.setExpectedText('řeka');
    final first = container.read(pronunciationProvider).attemptId;
    notifier.setExpectedText('řeka');
    final second = container.read(pronunciationProvider).attemptId;

    expect(second, greaterThan(first));
  });
}
