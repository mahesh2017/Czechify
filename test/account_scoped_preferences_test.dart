import 'package:czechify/data/account/account_restore_materializer.dart';
import 'package:czechify/data/services/lesson_checkpoint_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('account-scoped preferences include the notebook', () async {
    // The notebook's to-dos and the copybook's ticks outlived an account
    // switch and deletion, so the next learner inherited them.
    SharedPreferences.setMockInitialValues({
      'notebook_todo_v1': '[]',
      'notebook_outcomes_v1': '[]',
      'copybook_done_2026-11-16T00:00:00.000': ['1'],
      'copybook_done_2026-11-15T00:00:00.000': ['2'],
      'settings_theme_mode': 1,
      'notebook_intro_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await AccountRestoreMaterializer.clearAccountScopedPreferences(prefs);

    expect(prefs.getKeys(), {'settings_theme_mode', 'notebook_intro_seen'});
  });

  test('a failed permit revocation does not stop later saves', () async {
    // The failed future was kept as the chain head, so every later load and
    // write rethrew it until the app restarted.
    SharedPreferences.setMockInitialValues({'lesson_admission_epoch': 'bad'});
    final store = LessonCheckpointStore();

    await expectLater(store.revokePermits(), throwsA(anything));

    await store.write(7, {'index': 2});
    expect(await store.load(7), {'index': 2});
  });
}
