import 'dictionary_entry.dart';

/// The Home card's word of the day: a word the learner has already met.
///
/// Only words from units they have reached, so the card is a reminder, never
/// a spoiler of a unit still locked; and only content words with an example
/// (nouns, verbs, adjectives, adverbs), because "a" or "v" make a thin page.
/// The same word all day, a different one each day, the same on every device.
DictionaryEntry? wordOfTheDay(
  DictionaryData dictionary,
  Set<int> unlockedUnits,
  DateTime now,
) {
  const kinds = {'noun', 'verb', 'adj', 'adv'};
  // The learner's own level: an A2 learner's dictionary holds A1's words
  // too, and the card is about what they are learning now.
  final own = [
    for (final e in dictionary.entries)
      if (!dictionary.isEarlier(e) &&
          e.unit != null &&
          kinds.contains(e.pos) &&
          e.examples.isNotEmpty)
        e,
  ];
  List<DictionaryEntry> from(Set<int> units) => [
    for (final e in own)
      if (units.contains(e.unit)) e,
  ];

  var words = from(unlockedUnits);
  // Nothing reached yet (a first launch before the course has loaded):
  // the level's first unit's words are the ones the learner is about to meet.
  if (words.isEmpty && own.isNotEmpty) {
    final first = own.map((e) => e.unit!).reduce((a, b) => a < b ? a : b);
    words = from({first});
  }
  if (words.isEmpty) return null;

  final day = DateTime.utc(now.year, now.month, now.day);
  final dayNumber = day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  // A stride co-prime with most list lengths spreads consecutive days across
  // the alphabet instead of walking it word by word.
  return words[(dayNumber * 7919) % words.length];
}
