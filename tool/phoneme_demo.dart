// Tuning harness for the phoneme scorer.
//
// Printing to the console is the entire point of this harness; it is a
// developer tool under tool/ and never ships in the app.
// ignore_for_file: avoid_print
//
// `dart run` can't load this package (other dependencies need the native-assets
// experiment), so run it through the test harness:
//
//   cp tool/phoneme_demo.dart test/zz_demo_test.dart   # wrap main() in a test
//
// or simply call PhonemeScorer from a scratch test. Kept here as the reference
// set of learner errors to judge weights and thresholds against.
//
// Feeds realistic learner errors through PhonemeScorer so thresholds and
// weights can be judged against output a learner would actually see, rather
// than against unit-test assertions alone.

import 'package:czechify/domain/engines/phoneme_scorer.dart';

void main() {
  final scorer = PhonemeScorer();

  // (word, expected IPA from assets/vocabulary, what the learner produced, note)
  const cases = <List<String>>[
    ['řeka', 'ˈr̝ɛka', 'r̝ɛka', 'said correctly'],
    ['řeka', 'ˈr̝ɛka', 'rɛka', 'ř flattened to r — the classic error'],
    ['řeka', 'ˈr̝ɛka', 'ʒɛka', 'ř replaced with ž'],
    ['dobrý den', 'ˈdobriː dɛn', 'dobriː dɛn', 'said correctly'],
    ['dobrý den', 'ˈdobriː dɛn', 'dobri dɛn', 'long í shortened'],
    ['být (to be)', 'biːt', 'bit', 'být → byt, meaning changes'],
    ['děkuji', 'ˈjɛkujɪ', 'jɛkujɪ', 'said correctly'],
    ['čaj', 't͡ʃaj', 'tsaj', 'č produced as c'],
    ['dobrý den', 'ˈdobriː dɛn', 'blaːblaː', 'gibberish'],
  ];

  const bandLabel = {
    PronunciationBand.excellent: 'EXCELLENT',
    PronunciationBand.good: 'GOOD',
    PronunciationBand.needsWork: 'NEEDS WORK',
    PronunciationBand.tryAgain: 'TRY AGAIN',
  };

  for (final c in cases) {
    final r = scorer.score(expectedIpa: c[1], actualIpa: c[2]);
    final pct = (r.overallScore * 100).round();
    print('${c[0]}  (${c[3]})');
    print('   expected ${c[1]}   heard ${c[2]}');
    print('   ${bandLabel[r.band]}  [$pct%]');
    // The engine deals in codes; this tool has no l10n to render them with,
    // so it shows the code and what it carries.
    for (final tip in r.displayTips) {
      final detail = [
        if (tip.sound != null) 'sound: ${tip.sound}',
        if (tip.word != null) 'word: ${tip.word}',
        if (tip.heard != null) 'heard: ${tip.heard}',
      ].join(', ');
      print('   → ${tip.code.name}${detail.isEmpty ? '' : '  ($detail)'}');
    }
    print('');
  }
}
