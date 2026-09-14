import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/lesson_session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Home follows level changes without removing access to earlier lessons',
    () async {
      SharedPreferences.setMockInitialValues({});
      const units = [
        Unit(
          id: 1,
          title: 'A1',
          description: '',
          phase: Phase.a1,
          orderIndex: 1,
        ),
        Unit(
          id: 16,
          title: 'A2',
          description: '',
          phase: Phase.a2,
          orderIndex: 16,
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          allUnitsProvider.overrideWith((ref) async => units),
          unlockedLessonIdsProvider.overrideWith((ref) async => {1, 16}),
          completedLessonIdsProvider.overrideWith((ref) async => <int>{}),
          learningEvidenceProvider.overrideWith((ref) async => []),
          for (final unit in units)
            unitLessonsProvider(unit.id).overrideWith(
              (ref) async => [
                Lesson(
                  id: unit.id,
                  unitId: unit.id,
                  orderInUnit: 1,
                  title: unit.title,
                  description: '',
                ),
              ],
            ),
          curriculumRepositoryProvider.overrideWithValue(
            FakeCurriculumRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider.notifier);
      await settings.ready;
      await settings.setStartingLevel(CEFRLevel.a2);
      expect((await container.read(nextLessonProvider.future))?.lesson.id, 16);
      await settings.setStartingLevel(CEFRLevel.a1);
      expect((await container.read(nextLessonProvider.future))?.lesson.id, 1);
      expect(await container.read(unlockedLessonIdsProvider.future), {1, 16});
    },
  );
}
