import 'package:czechify/data/services/lesson_checkpoint_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a checkpoint reads back, per lesson', () async {
    final store = LessonCheckpointStore();

    await store.write(1, {'index': 3});
    await store.write(2, {'index': 5});

    expect(await store.load(1), {'index': 3});
    expect(await store.load(2), {'index': 5});
    expect(await store.load(3), isNull);
  });

  test('writing null removes only that lesson', () async {
    final store = LessonCheckpointStore();
    await store.write(1, {'index': 3});
    await store.write(2, {'index': 5});

    await store.write(1, null);

    expect(await store.load(1), isNull);
    expect(await store.load(2), {'index': 5});
  });

  test('writes land in the order they were made', () async {
    // A draft save still in flight must not resurrect a lesson that was
    // finished — and cleared — straight after it.
    final store = LessonCheckpointStore();

    final draft = store.write(1, {'draft': 'Ahoj'});
    final finished = store.write(1, null);
    await Future.wait([draft, finished]);

    expect(await store.load(1), isNull);
  });

  test('a new store instance sees what an earlier one wrote', () async {
    await LessonCheckpointStore().write(4, {'index': 1});

    expect(await LessonCheckpointStore().load(4), {'index': 1});
  });

  test('unreadable storage reads as no checkpoint rather than throwing', () async {
    SharedPreferences.setMockInitialValues({
      LessonCheckpointStore.preferenceKey: 'not json',
    });
    final store = LessonCheckpointStore();

    expect(await store.load(1), isNull);

    // And the next save replaces it cleanly.
    await store.write(1, {'index': 2});
    expect(await store.load(1), {'index': 2});
  });
}
