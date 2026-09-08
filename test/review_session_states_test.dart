import 'package:czechify/data/database/database.dart' as db;
import 'package:czechify/domain/repositories/vocabulary_repository.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loading a review session has three outcomes the screen has to tell apart:
/// cards to review, nothing due, and a load that failed. It used to report the
/// second as "session complete" and the third as an eternal spinner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith(VocabularyRepository repo) {
    // An in-memory database so the curriculum gates the loader consults do not
    // reach for the real one on disk.
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        vocabularyRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('an empty queue is not a finished session', () async {
    final container = containerWith(_EmptyRepository());

    await container.read(reviewSessionProvider.notifier).loadDueCards();
    final state = container.read(reviewSessionProvider);

    expect(state.isLoading, isFalse);
    expect(state.dueCards, isEmpty);
    // The screen's no-cards-due branch requires !isComplete. Reporting an
    // empty load as complete made that branch unreachable and sent a learner
    // who reviewed nothing to the congratulations screen.
    expect(state.isComplete, isFalse);
    expect(state.loadError, isNull);
  });

  test('a failed load surfaces an error instead of spinning forever', () async {
    final container = containerWith(_FailingRepository());

    await container.read(reviewSessionProvider.notifier).loadDueCards();
    final state = container.read(reviewSessionProvider);

    // isLoading stuck true is what left an unbreakable spinner with no retry.
    expect(state.isLoading, isFalse);
    expect(state.loadError, isNotNull);
    expect(state.isComplete, isFalse);
  });

  test('a failed load does not masquerade as nothing being due', () async {
    final container = containerWith(_FailingRepository());

    await container.read(reviewSessionProvider.notifier).loadDueCards();
    final state = container.read(reviewSessionProvider);

    // Both states have no cards; only the error distinguishes them, which is
    // why the screen checks loadError first.
    expect(state.dueCards, isEmpty);
    expect(state.loadError, isNotNull);
  });
}

/// Nothing due — a perfectly ordinary day for a learner who is caught up.
class _EmptyRepository implements VocabularyRepository {
  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) async => const [];

  @override
  Future<int> introducedCardCountForDay(DateTime day) async => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The first awaited query fails, which is what used to strand the screen.
class _FailingRepository implements VocabularyRepository {
  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) async =>
      throw Exception('database unavailable');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
