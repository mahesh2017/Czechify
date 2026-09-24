import 'package:czechify/data/services/notebook_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "No pen right now" must never lose the step: it waits on the notebook
/// to-do, with its own copy of the task, until the learner writes it — here
/// or by completing the same step in a later lesson.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  NotebookTodo todo(int id, {String heading = 'Start your Unit 6 page'}) =>
      NotebookTodo(
        exerciseId: id,
        lessonId: 601,
        heading: heading,
        instruction: 'Write the four café phrases from memory.',
        model: const [(cz: 'Dám si kávu.', en: "I'll have a coffee.")],
        deferredAt: DateTime(2026, 9, 24, 10),
      );

  test('a deferred step waits on the to-do with its own copy of the task', () async {
    final store = NotebookStore();

    await store.defer(todo(6001));

    final todos = await store.todos();
    expect(todos, hasLength(1));
    expect(todos.single.heading, 'Start your Unit 6 page');
    expect(todos.single.model.single.cz, 'Dám si kávu.');
    expect((await store.outcomeCounts())[NotebookOutcome.deferred], 1);
  });

  test('deferring the same step twice keeps one entry, the latest', () async {
    final store = NotebookStore();

    await store.defer(todo(6001));
    await store.defer(todo(6001, heading: 'Reworded in a later release'));

    final todos = await store.todos();
    expect(todos, hasLength(1));
    expect(todos.single.heading, 'Reworded in a later release');
  });

  test('marking it written clears it', () async {
    final store = NotebookStore();
    await store.defer(todo(6001));
    await store.defer(todo(6002));

    await store.markWritten(6001);

    expect((await store.todos()).map((t) => t.exerciseId), [6002]);
  });

  test('completing the step in a lesson also clears an earlier deferral', () async {
    final store = NotebookStore();
    await store.defer(todo(6001));

    await store.record(6001, NotebookOutcome.corrected);

    expect(await store.todos(), isEmpty);
    final counts = await store.outcomeCounts();
    expect(counts[NotebookOutcome.corrected], 1);
    expect(counts[NotebookOutcome.deferred], 1);
  });

  test('the outcome log keeps only the most recent entries', () async {
    final store = NotebookStore();

    for (var i = 0; i < NotebookStore.maxOutcomes + 20; i++) {
      await store.record(i, NotebookOutcome.allCorrect);
    }

    expect(
      (await store.outcomeCounts())[NotebookOutcome.allCorrect],
      NotebookStore.maxOutcomes,
    );
  });

  test('a damaged saved value reads as empty rather than throwing', () async {
    SharedPreferences.setMockInitialValues({
      NotebookStore.todoKey: 'not json',
      NotebookStore.outcomesKey: '{"also": "wrong"}',
    });
    final store = NotebookStore();

    expect(await store.todos(), isEmpty);
    expect((await store.outcomeCounts()).values, everyElement(0));
  });
}
