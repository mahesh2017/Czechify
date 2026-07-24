import 'package:ceskina_pro/data/content/curriculum_pack_source.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/seeds/content_seeder.dart';
import 'package:ceskina_pro/data/sync/backend_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ContentSeeder seeder;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    seeder = ContentSeeder(
      database,
      CurriculumPackSource(backend: BackendService()),
    );
  });

  tearDown(() => database.close());

  test('bundled course bootstraps a complete usable local snapshot', () async {
    expect(await seeder.hasUsableLocalContent(), isFalse);

    await seeder.ensureBundledContent();

    expect(await seeder.hasUsableLocalContent(), isTrue);
    expect(await database.select(database.units).get(), hasLength(31));
    expect(await database.select(database.lessons).get(), hasLength(61));
    expect(await database.vocabularyDao.srsCardCount(), greaterThan(0));
  });

  test('failed content install leaves no partial curriculum', () async {
    await database.customStatement('''
      CREATE TRIGGER reject_exercise_install
      BEFORE INSERT ON exercises
      BEGIN
        SELECT RAISE(ABORT, 'simulated content failure');
      END
    ''');

    await expectLater(seeder.ensureBundledContent(), throwsA(anything));

    expect(await database.select(database.units).get(), isEmpty);
    expect(await database.select(database.lessons).get(), isEmpty);
    expect(await database.select(database.exercises).get(), isEmpty);
    expect(await seeder.hasUsableLocalContent(), isFalse);
  });
}
