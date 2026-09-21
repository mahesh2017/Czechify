import 'dart:convert';
import 'dart:io';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/domain/engines/placement_ceilings.dart';
import 'package:czechify/domain/engines/placement_engine.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('select 1').get();
  });
  tearDown(() => db.close());

  test(
    'A1 30 then A2 16 preserves both ceilings and skill estimates',
    () async {
      await db.progressDao.savePlacement(
        const PlacementResult(
          estimates: {},
          provisionalUnit: 30,
          sampleSize: 12,
        ),
      );
      await db.progressDao.setProvisionalUnit(16);
      final row = await db.select(db.placementProfiles).getSingle();
      expect(jsonDecode(row.phaseCeilingsJson!), {'a1': 30, 'a2': 16});
      expect(row.sampleSize, 12);
      expect(row.provisionalUnit, 30); // Old-client compatibility only.
    },
  );
  test('independent merges retain progress in both phases', () async {
    await db.progressDao.setProvisionalUnit(30);
    await db.progressDao.mergeRemotePlacement(
      provisionalUnit: 24,
      phaseCeilingsJson: '{"a2":24}',
      estimatesJson: '{}',
      sampleSize: 3,
      updatedAt: DateTime.utc(2020),
    );
    await db.progressDao.mergeRemotePlacement(
      provisionalUnit: 2,
      phaseCeilingsJson: '{"a1":2}',
      estimatesJson: '{}',
      sampleSize: 0,
      updatedAt: DateTime.utc(2019),
    );
    final row = await db.select(db.placementProfiles).getSingle();
    expect(jsonDecode(row.phaseCeilingsJson!), {'a1': 30, 'a2': 24});
    final queue = await db.select(db.syncQueue).get();
    expect(queue, isNotEmpty);
    // Remote merge never queues another local write.
    expect(queue.length, 1);
  });
  test(
    'legacy scalar preserves formerly open span once, explicit map stays phase-local',
    () {
      final units = PlacementCeilings.bundledUnits;
      expect(
        PlacementCeilings.read(
          json: null,
          legacyUnit: 24,
          units: units,
        ).throughUnitIds,
        {Phase.a1: 15, Phase.a2: 24},
      );
      expect(
        PlacementCeilings.read(
          json: '{"a1":30}',
          legacyUnit: 30,
          units: units,
        ).throughUnitIds,
        {Phase.a1: 30},
      );
      expect(
        () => PlacementCeilings.read(
          json: '{"a1":16}',
          legacyUnit: null,
          units: units,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'version 8 upgrade backfills placement without losing existing access',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'phase-placement-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('''create table placement_profiles (
      key text primary key, provisional_unit integer not null, learner_override_unit integer,
      estimates_json text not null,sample_size integer not null,updated_at integer not null);
      insert into placement_profiles values('primary',30,null,'{}',12,1700000000);
      pragma user_version=8;''');
      legacy.close();
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      final row = await upgraded.select(upgraded.placementProfiles).getSingle();
      expect(jsonDecode(row.phaseCeilingsJson!), {'a1': 30, 'a2': 29});
      expect(row.sampleSize, 12);
      expect(
        await upgraded.select(upgraded.monetizationSnapshots).get(),
        isEmpty,
      );
    },
  );
}
