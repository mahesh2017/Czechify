import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:czechify/data/services/exam_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ExamCheckpoint checkpoint({DateTime? savedAt}) => ExamCheckpoint(
    level: 'a1',
    sectionIndex: 1,
    questionIndex: 3,
    secondsLeft: 421,
    answers: {
      0: {0: 2, 1: 'napsaná odpověď', 2: 0},
      1: {0: 1},
    },
    speakingTranscriptions: {'3:0': 'ahoj jak se máš'},
    speakingScores: {'3:0': 85},
    writingScores: {'2:0': 70},
    savedAt: savedAt ?? DateTime.now(),
  );

  test('checkpoint round-trips through save/load intact', () async {
    final store = ExamSessionStore();
    await store.save(checkpoint());

    final restored = await store.load('a1');
    expect(restored, isNotNull);
    expect(restored!.sectionIndex, 1);
    expect(restored.questionIndex, 3);
    expect(restored.secondsLeft, 421);
    expect(restored.answers[0]![1], 'napsaná odpověď');
    expect(restored.answers[1]![0], 1);
    expect(restored.speakingTranscriptions['3:0'], 'ahoj jak se máš');
    expect(restored.speakingScores['3:0'], 85);
    expect(restored.writingScores['2:0'], 70);
  });

  test('checkpoints are per-level and clear() removes them', () async {
    final store = ExamSessionStore();
    await store.save(checkpoint());

    expect(await store.load('a2'), isNull);
    await store.clear('a1');
    expect(await store.load('a1'), isNull);
  });

  test('stale checkpoints are discarded', () async {
    final store = ExamSessionStore();
    await store.save(
      checkpoint(savedAt: DateTime.now().subtract(const Duration(hours: 25))),
    );

    expect(await store.load('a1'), isNull);
  });

  test('malformed stored data is treated as absent', () async {
    SharedPreferences.setMockInitialValues({
      'exam_checkpoint_a1': '{not valid json',
    });
    final store = ExamSessionStore();
    expect(await store.load('a1'), isNull);
  });
}
