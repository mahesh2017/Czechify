import 'package:czechify/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() => database.close());

  test('onboarding cannot lower an existing provisional unit', () async {
    await database.progressDao.setProvisionalUnit(24);

    await database.progressDao.setProvisionalUnit(16);

    final placement =
        await database.select(database.placementProfiles).getSingle();
    expect(placement.provisionalUnit, 24);
  });
}
