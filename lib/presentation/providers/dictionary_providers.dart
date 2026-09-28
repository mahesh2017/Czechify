import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dictionary/dictionary_entry.dart';
import '../../data/dictionary/dictionary_search.dart';
import '../../domain/entities/enums.dart';
import 'settings_providers.dart';

/// Levels that have a dictionary, in course order; each has its file at
/// `assets/dictionary/<level>_dictionary.json`.
const List<String> kDictionaryLevels = ['a1', 'a2'];

/// The dictionary of the learner's level: 'a2' for a learner on A2, who sees
/// A1's words too; 'a1' otherwise. The app keeps a learner on one level at a
/// time, so this is the one dictionary every entry point opens.
final learnerDictionaryLevelProvider = Provider<String>((ref) {
  final level = ref.watch(settingsProvider.select((s) => s.startingLevel));
  return level == CEFRLevel.a2 ? 'a2' : 'a1';
});

/// One level's own words, loaded once from the bundle.
final dictionaryFileProvider = FutureProvider.family<DictionaryData, String>((
  ref,
  level,
) async {
  final text = await rootBundle.loadString(
    'assets/dictionary/${level}_dictionary.json',
  );
  // Several hundred kilobytes of JSON: decoded off the UI thread so opening
  // the dictionary does not drop frames.
  return Isolate.run(
    () => DictionaryData.fromJson(jsonDecode(text) as Map<String, dynamic>),
  );
});

/// A learner's dictionary for [level]: that level's words and every earlier
/// level's (Mahesh, 28 Sep 2026: "when user is on A2, they get to see both
/// A1 and A2 words").
final dictionaryProvider = FutureProvider.family<DictionaryData, String>((
  ref,
  level,
) async {
  final index = kDictionaryLevels.indexOf(level);
  var data = await ref.watch(dictionaryFileProvider(kDictionaryLevels[0]).future);
  for (var i = 1; i <= index; i++) {
    data = DictionaryData.merged(
      data,
      await ref.watch(dictionaryFileProvider(kDictionaryLevels[i]).future),
    );
  }
  return data;
});

/// The search index for a learner's dictionary, built once per level.
final dictionarySearchProvider =
    FutureProvider.family<DictionarySearch, String>((ref, level) async {
      return DictionarySearch(await ref.watch(dictionaryProvider(level).future));
    });
