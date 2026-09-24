import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// How the learner closed a notebook step.
enum NotebookOutcome {
  /// Wrote it from memory and it matched the model.
  allCorrect,

  /// Wrote it, compared it with the model and fixed what was wrong.
  corrected,

  /// "No pen right now": put on the notebook to-do instead.
  deferred,
}

/// A notebook step put off with "No pen right now".
///
/// Carries its own copy of the task and the model, so the to-do list still
/// shows exactly what to write even if a later content release rewords the
/// lesson.
class NotebookTodo {
  final int exerciseId;
  final int lessonId;
  final String heading;
  final String instruction;
  final List<({String cz, String en})> model;
  final DateTime deferredAt;

  const NotebookTodo({
    required this.exerciseId,
    required this.lessonId,
    required this.heading,
    required this.instruction,
    required this.model,
    required this.deferredAt,
  });

  Map<String, dynamic> toJson() => {
    'exercise_id': exerciseId,
    'lesson_id': lessonId,
    'heading': heading,
    'instruction': instruction,
    'model': [
      for (final row in model) {'cz': row.cz, 'en': row.en},
    ],
    'deferred_at': deferredAt.toIso8601String(),
  };

  static NotebookTodo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['exercise_id'];
    final lesson = json['lesson_id'];
    final at = DateTime.tryParse('${json['deferred_at']}');
    if (id is! int || lesson is! int || at == null) return null;
    return NotebookTodo(
      exerciseId: id,
      lessonId: lesson,
      heading: '${json['heading'] ?? ''}',
      instruction: '${json['instruction'] ?? ''}',
      model: [
        for (final row in (json['model'] as List? ?? const []))
          if (row is Map) (cz: '${row['cz'] ?? ''}', en: '${row['en'] ?? ''}'),
      ],
      deferredAt: at,
    );
  }
}

/// Local-only record of notebook steps: the to-do list, and how each step
/// was closed.
///
/// Deliberately not learning evidence. The router reads any supported answer
/// as a reason to send the learner back to a lesson, so a self-report here
/// would flag every lesson with a notebook step for revisiting. The outcome
/// log exists so a tester's device can show how the steps were used.
class NotebookStore {
  static const todoKey = 'notebook_todo_v1';
  static const outcomesKey = 'notebook_outcomes_v1';

  /// Kept short: it answers "how are the steps being used", not a history.
  static const maxOutcomes = 500;

  Future<void> _pending = Future.value();

  Future<List<NotebookTodo>> todos() async {
    await _pending;
    final prefs = await SharedPreferences.getInstance();
    return _decodeTodos(prefs.getString(todoKey));
  }

  /// Adds [todo], replacing an earlier deferral of the same step.
  Future<void> defer(NotebookTodo todo) => _update((prefs) async {
    final all = _decodeTodos(prefs.getString(todoKey))
      ..removeWhere((t) => t.exerciseId == todo.exerciseId)
      ..add(todo);
    await prefs.setString(
      todoKey,
      jsonEncode([for (final t in all) t.toJson()]),
    );
    await _appendOutcome(prefs, todo.exerciseId, NotebookOutcome.deferred);
  });

  /// The learner wrote a deferred step: it leaves the to-do list.
  Future<void> markWritten(int exerciseId) => _update((prefs) async {
    final all = _decodeTodos(prefs.getString(todoKey))
      ..removeWhere((t) => t.exerciseId == exerciseId);
    await prefs.setString(
      todoKey,
      jsonEncode([for (final t in all) t.toJson()]),
    );
  });

  /// Records how a step was closed in the lesson. A step completed in the
  /// lesson also leaves the to-do list, in case it was deferred before.
  Future<void> record(int exerciseId, NotebookOutcome outcome) =>
      _update((prefs) async {
        await _appendOutcome(prefs, exerciseId, outcome);
        if (outcome != NotebookOutcome.deferred) {
          final all = _decodeTodos(prefs.getString(todoKey))
            ..removeWhere((t) => t.exerciseId == exerciseId);
          await prefs.setString(
            todoKey,
            jsonEncode([for (final t in all) t.toJson()]),
          );
        }
      });

  /// Counts per outcome, for a tester's own device.
  Future<Map<NotebookOutcome, int>> outcomeCounts() async {
    await _pending;
    final prefs = await SharedPreferences.getInstance();
    final counts = {for (final o in NotebookOutcome.values) o: 0};
    for (final entry in _decodeOutcomes(prefs.getString(outcomesKey))) {
      final outcome = NotebookOutcome.values.asNameMap()[entry['outcome']];
      if (outcome != null) counts[outcome] = counts[outcome]! + 1;
    }
    return counts;
  }

  Future<void> _update(Future<void> Function(SharedPreferences) change) {
    final operation = _pending.then((_) async {
      await change(await SharedPreferences.getInstance());
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _appendOutcome(
    SharedPreferences prefs,
    int exerciseId,
    NotebookOutcome outcome,
  ) async {
    final all = _decodeOutcomes(prefs.getString(outcomesKey))..add({
      'exercise_id': exerciseId,
      'outcome': outcome.name,
      'at': DateTime.now().toIso8601String(),
    });
    final kept =
        all.length > maxOutcomes ? all.sublist(all.length - maxOutcomes) : all;
    await prefs.setString(outcomesKey, jsonEncode(kept));
  }

  static List<NotebookTodo> _decodeTodos(String? raw) {
    try {
      return [
        for (final item in (jsonDecode(raw ?? '[]') as List))
          if (NotebookTodo.fromJson(item) case final todo?) todo,
      ];
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _decodeOutcomes(String? raw) {
    try {
      return [
        for (final item in (jsonDecode(raw ?? '[]') as List))
          if (item is Map<String, dynamic>) item,
      ];
    } catch (_) {
      return [];
    }
  }
}
