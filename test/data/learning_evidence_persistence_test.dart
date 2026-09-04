import 'dart:io';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/domain/engines/placement_engine.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support-aware evidence is idempotent and survives restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'czechify-learning-evidence-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/learning.sqlite');
    var database = AppDatabase.forTesting(NativeDatabase(file));
    final evidence = LearningEvidence(
      evidenceId: 'evidence-1',
      lessonId: 101,
      exerciseId: 1001,
      skill: LearningSkill.listening,
      phase: LearningPhase.delayedTransfer,
      correct: true,
      novelTask: true,
      supports: const {SupportKind.replay},
      conceptKeys: const {'vowel_length'},
      responseLatency: const Duration(seconds: 14),
      observedAt: DateTime.utc(2026, 7, 30),
    );

    expect(await database.progressDao.recordLearningEvidence(evidence), isTrue);
    expect(
      await database.progressDao.recordLearningEvidence(evidence),
      isFalse,
    );
    await database.progressDao.savePlacement(
      const PlacementResult(
        estimates: {LearningSkill.listening: 0.6},
        provisionalUnit: 12,
        sampleSize: 8,
      ),
    );
    await database.close();

    database = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database.close);
    final restored = await database.progressDao.getLearningEvidence();
    expect(restored, hasLength(1));
    expect(restored.single.supports, {SupportKind.replay});
    expect(restored.single.independent, isFalse);
    expect(restored.single.isDelayedTransfer, isTrue);
    expect(
      await database.select(database.placementProfiles).get(),
      hasLength(1),
    );
  });
}
