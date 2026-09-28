import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dictionary/dictionary_entry.dart';
import '../../data/dictionary/dictionary_search.dart';

/// Levels that have a dictionary, in course order. A2 joins as its units are
/// rebuilt; its file is assets/dictionary/a2_dictionary.json.
const List<String> kDictionaryLevels = ['a1'];

/// One level's dictionary, loaded once from the bundle.
final dictionaryProvider = FutureProvider.family<DictionaryData, String>((
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

/// The search index for a level, built once per level.
final dictionarySearchProvider =
    FutureProvider.family<DictionarySearch, String>((ref, level) async {
      return DictionarySearch(await ref.watch(dictionaryProvider(level).future));
    });
