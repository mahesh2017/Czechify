import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only lesson checkpoints. Writes are serialized so a slower earlier
/// draft cannot overwrite a newer answer or resurrect a completed attempt.
class LessonCheckpointStore {
  static const preferenceKey = 'lesson_checkpoints';
  Future<void> _pending = Future.value();

  static const _epochKey = 'lesson_admission_epoch';

  Future<int> accountEpoch() async {
    await _pending;
    return (await SharedPreferences.getInstance()).getInt(_epochKey) ?? 0;
  }

  Future<void> revokePermits() {
    final operation = _pending.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setInt(_epochKey, (prefs.getInt(_epochKey) ?? 0) + 1)) {
        throw StateError('Could not revoke lesson permits');
      }
    });
    _pending = operation;
    return operation;
  }

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return jsonDecode(prefs.getString(preferenceKey) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> load(int lessonId) async {
    await _pending;
    final value = (await _read())['$lessonId'];
    return value is Map<String, dynamic> ? value : null;
  }

  Future<void> write(int lessonId, Map<String, dynamic>? checkpoint) {
    final operation = _pending.then((_) async {
      final all = await _read();
      if (checkpoint == null) {
        all.remove('$lessonId');
      } else {
        all['$lessonId'] = checkpoint;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(preferenceKey, jsonEncode(all))) {
        throw StateError('Could not save lesson checkpoint');
      }
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
