import 'package:ceskina_pro/data/content/curriculum_pack_source.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/repositories/drift_curriculum_repository.dart';
import 'package:ceskina_pro/data/seeds/content_seeder.dart';
import 'package:ceskina_pro/data/sync/backend_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Unit 1 follows meaning, perception, guided use, then mission',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final source = CurriculumPackSource(backend: BackendService());
      final seeder = ContentSeeder(database, source);
      final repository = DriftCurriculumRepository(database);

      await seeder.reinstallBundledContent();

      final lessons = await repository.getLessons(1);
      expect(lessons.map((lesson) => lesson.id), [100, 101, 102, 103]);
      expect(lessons.map((lesson) => lesson.title), [
        'Hear Czech in Useful Words',
        'The First Beat and Long Vowels',
        'Czech Spelling Clues',
        'Mission: Keep the Conversation Going',
      ]);

      final opening = await repository.getExercises(100);
      expect(opening.take(3).map((exercise) => exercise.id), [898, 899, 900]);
      expect(opening.first.data['style'], 'image_cards');
      expect(opening[2].type.name, 'listeningComprehension');

      final mission = await repository.getExercises(103);
      expect(mission.first.id, 1121);
      expect(mission.last.id, 1133);
      expect(
        mission.map((exercise) => exercise.type.name),
        containsAll([
          'listeningComprehension',
          'readingComprehension',
          'speakingTask',
          'writingTask',
        ]),
      );
    },
  );
}
