import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the one change in this release that touches data already on
/// learners' devices.
///
/// The conversations table used to store the scenario's English *title*, and
/// `resumeConversation` matched rows back by comparing that string — a display
/// string carrying identity. Rows now store the id. Every conversation saved
/// before this build still holds a title, so `ChatScenario.idFor` is the only
/// thing standing between a returning learner and every past conversation
/// resuming as Casual Chat.
///
/// The titles below are not retyped from memory: they are what the previous
/// version of `chat_providers.dart` wrote, and are pinned here so that
/// renaming a scenario in the ARB can never quietly invalidate the mapping.
void main() {
  const legacyTitles = <String, String>{
    'Casual Chat': 'casual_chat',
    'At the Restaurant': 'restaurant',
    'Asking Directions': 'directions',
    'Shopping': 'shopping',
    'At the Doctor': 'doctor',
    'Job Interview': 'job_interview',
  };

  test('every title an older build wrote still resolves', () {
    for (final entry in legacyTitles.entries) {
      expect(
        ChatScenario.idFor(entry.key),
        entry.value,
        reason:
            '"${entry.key}" was written into the conversations table by an '
            'older build and no longer maps to a scenario',
      );
    }
  });

  test(
    'the legacy map covers every scenario, not just the ones remembered',
    () {
      // A scenario added later needs no legacy entry — nothing ever stored its
      // title. One that existed before this change and is missing here would
      // strand its conversations.
      expect(
        legacyTitles.values.toSet(),
        ChatScenario.all.map((s) => s.id).toSet(),
        reason:
            'The set of scenarios and the set of legacy titles have diverged; '
            'if a scenario was added after the id migration, add it here with '
            'its id as its own key and say so.',
      );
    },
  );

  test('an id passes through untouched', () {
    // Rows written from this build on hold ids, and they go through the same
    // call. Mapping one to something else would break new conversations to
    // fix old ones.
    for (final scenario in ChatScenario.all) {
      expect(ChatScenario.idFor(scenario.id), scenario.id);
    }
  });

  test('an unrecognised value is returned as-is, not silently rewritten', () {
    // The caller falls back to the first scenario when no id matches. That
    // decision belongs there, where it is visible, rather than here.
    expect(
      ChatScenario.idFor('something else entirely'),
      'something else entirely',
    );
    expect(ChatScenario.idFor(''), '');
  });
}
