import 'package:ceskina_pro/data/content/curriculum_pack_source.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/repositories/drift_curriculum_repository.dart';
import 'package:ceskina_pro/data/seeds/content_seeder.dart';
import 'package:ceskina_pro/data/sync/backend_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Unit 2 follows context, patterns, guided use, then mission', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final source = CurriculumPackSource(backend: BackendService());
    final seeder = ContentSeeder(database, source);
    final repository = DriftCurriculumRepository(database);

    await seeder.reinstallBundledContent();

    final lessons = await repository.getLessons(2);
    expect(lessons.map((lesson) => lesson.id), [201, 202, 203, 204]);
    expect(lessons.map((lesson) => lesson.title), [
      'Hello: Formal or Friendly?',
      'Names: Ask and Answer',
      'Where Are You From?',
      'Mission: Meet Someone',
    ]);

    final opening = await repository.getExercises(201);
    expect(opening.first.id, 2000);
    expect(opening.first.data['style'], 'image_cards');
    expect(opening[1].type.name, 'listeningComprehension');

    final mission = await repository.getExercises(204);
    expect(mission.first.id, 2300);
    expect(mission.last.id, 2311);
    expect(
      mission.map((exercise) => exercise.type.name),
      containsAll([
        'listeningComprehension',
        'readingComprehension',
        'speakingTask',
        'writingTask',
      ]),
    );
  });
}
