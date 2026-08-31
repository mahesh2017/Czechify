import 'package:czechify/data/database/database.dart' hide Unit;
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:czechify/domain/engines/placement_engine.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ids deliberately out of curriculum order, as the real curriculum is:
/// A1 owns 1, 2, 28, 30 and A2 starts at 16.
const List<Unit> _units = [
  Unit(id: 1, title: 'a', description: '', phase: Phase.a1, orderIndex: 1),
  Unit(id: 2, title: 'b', description: '', phase: Phase.a1, orderIndex: 2),
  Unit(id: 28, title: 'c', description: '', phase: Phase.a1, orderIndex: 3),
  Unit(id: 30, title: 'd', description: '', phase: Phase.a1, orderIndex: 4),
  Unit(id: 16, title: 'e', description: '', phase: Phase.a2, orderIndex: 5),
  Unit(id: 17, title: 'f', description: '', phase: Phase.a2, orderIndex: 6),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        allUnitsProvider.overrideWith((ref) async => _units),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<int?> storedProvisionalUnit() async =>
      (await database.select(database.placementProfiles).getSingleOrNull())
          ?.provisionalUnit;

  test('switching to A2 writes both pieces of state, not just the setting', () async {
    // Settings alone changes chat difficulty and offline downloads while every
    // A2 unit stays locked — which is exactly the half-switch that left a
    // learner stranded before.
    final moved = await container.read(levelSwitchProvider)(CEFRLevel.a2);

    expect(moved, isTrue);
    expect(container.read(settingsProvider).startingLevel, CEFRLevel.a2);
    expect(await storedProvisionalUnit(), 16);
  });

  test('a learner with no placement row gets one created', () async {
    expect(await storedProvisionalUnit(), isNull);
    await container.read(levelSwitchProvider)(CEFRLevel.a2);
    expect(await storedProvisionalUnit(), 16);
  });

  test('dropping back to A1 keeps the unlocked span', () async {
    await container.read(levelSwitchProvider)(CEFRLevel.a2);

    final moved = await container.read(levelSwitchProvider)(CEFRLevel.a1);

    expect(moved, isFalse, reason: 'the ceiling did not move');
    expect(container.read(settingsProvider).startingLevel, CEFRLevel.a1);
    // The setting follows the learner; access does not come back down.
    expect(await storedProvisionalUnit(), 16);
  });

  test('an existing placement keeps its estimates when level changes', () async {
    await database.progressDao.savePlacement(
      const PlacementResult(
        estimates: {LearningSkill.reading: 0.82},
        provisionalUnit: 1,
        sampleSize: 12,
      ),
    );

    await container.read(levelSwitchProvider)(CEFRLevel.a2);

    final row =
        await database.select(database.placementProfiles).getSingleOrNull();
    expect(row?.provisionalUnit, 16);
    // Changing level is not retaking the placement test. Going through
    // savePlacement would have reset both of these.
    expect(row?.sampleSize, 12);
    expect(row?.estimatesJson, contains('0.82'));
  });

  test('switching to the level already held changes nothing', () async {
    await container.read(levelSwitchProvider)(CEFRLevel.a2);
    final before =
        await database.select(database.placementProfiles).getSingleOrNull();

    final moved = await container.read(levelSwitchProvider)(CEFRLevel.a2);

    expect(moved, isFalse);
    expect((await storedProvisionalUnit()), before?.provisionalUnit);
  });
}
