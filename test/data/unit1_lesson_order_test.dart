import 'package:ceskina_pro/data/content/curriculum_pack_source.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/repositories/drift_curriculum_repository.dart';
import 'package:ceskina_pro/data/seeds/content_seeder.dart';
import 'package:ceskina_pro/data/sync/backend_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Unit 1 teaches the alphabet before illustrated vocabulary', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final source = CurriculumPackSource(backend: BackendService());
    final seeder = ContentSeeder(database, source);

    await seeder.reinstallBundledContent();

    final exercises = await DriftCurriculumRepository(
      database,
    ).getExercises(100);

    expect(exercises.take(2).map((exercise) => exercise.id), [899, 898]);
    expect(exercises.first.data['style'], isNot('image_cards'));
    expect(exercises[1].data['style'], 'image_cards');
  });
}
