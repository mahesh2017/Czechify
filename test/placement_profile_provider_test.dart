import 'dart:async';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('placement provider refetches after a remote-style merge', () async {
    final remotePlacement = Completer<PlacementProfile?>();
    final subscription = container.listen(placementProfileProvider, (
      previous,
      next,
    ) {
      final value = next.value;
      if (value?.provisionalUnit == 24 && !remotePlacement.isCompleted) {
        remotePlacement.complete(value);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);

    expect(await container.read(placementProfileProvider.future), isNull);

    await database.progressDao.mergeRemotePlacement(
      provisionalUnit: 24,
      estimatesJson: '{}',
      sampleSize: 0,
      updatedAt: DateTime.utc(2026, 8, 31),
    );

    expect(
      (await remotePlacement.future.timeout(
        const Duration(seconds: 2),
      ))?.provisionalUnit,
      24,
    );
  });
}
