import 'package:czechify/data/content/curriculum_pack_source.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/repositories/drift_curriculum_repository.dart';
import 'package:czechify/data/seeds/content_seeder.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Unit 3 follows meaning, noun cues, guided use, then mission', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final source = CurriculumPackSource(backend: BackendService());
    final seeder = ContentSeeder(database, source);
    final repository = DriftCurriculumRepository(database);

    await seeder.reinstallBundledContent();

    final lessons = await repository.getLessons(3);
    expect(lessons.map((lesson) => lesson.id), [301, 302, 303, 304]);
    expect(lessons.map((lesson) => lesson.title), [
      'Who or What?',
      'Gender Travels with the Noun',
      'Find and Identify',
      'Mission: Identify the Scene',
    ]);

    final opening = await repository.getExercises(301);
    expect(opening.first.id, 3000);
    expect(opening.first.data['style'], 'image_cards');
    expect(opening[1].type.name, 'listeningComprehension');

    final mission = await repository.getExercises(304);
    expect(mission.first.id, 3300);
    expect(mission.last.id, 3311);
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
