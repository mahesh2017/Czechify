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
  List<DictionaryEntry> from(Set<int> units) => [
    for (final e in dictionary.entries)
      if (e.unit != null &&
          units.contains(e.unit) &&
          kinds.contains(e.pos) &&
          e.examples.isNotEmpty)
        e,
  ];

  var words = from(unlockedUnits);
  // Nothing reached yet (a first launch before the course has loaded):
  // the first unit's words are the ones the learner is about to meet.
  if (words.isEmpty) words = from(const {1});
  if (words.isEmpty) return null;

  final day = DateTime.utc(now.year, now.month, now.day);
  final dayNumber = day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  // A stride co-prime with most list lengths spreads consecutive days across
  // the alphabet instead of walking it word by word.
  return words[(dayNumber * 7919) % words.length];
}
