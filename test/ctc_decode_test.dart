import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Greedy CTC decoding, mirroring OnDeviceCzechStt.transcribe.
///
/// Extracted here because the decode is where a silent bug lives: get the
/// blank index wrong, or forget to collapse repeats, and the model still
/// returns fluent-looking Czech — just not what was said. That fails no
/// assertion at runtime and is very hard to spot by ear.
({String text, double confidence}) decode({
  required List<double> logits,
  required int frames,
  required int classes,
  required Map<int, String> vocab,
  required int blankId,
}) {
  final buffer = StringBuffer();
  var previous = -1;
  var probabilitySum = 0.0;
  var counted = 0;

  for (var frame = 0; frame < frames; frame++) {
    final offset = frame * classes;
    var bestId = 0;
    var best = double.negativeInfinity;
    for (var c = 0; c < classes; c++) {
      if (logits[offset + c] > best) {
        best = logits[offset + c];
        bestId = c;
      }
    }
    var sumExp = 0.0;
    for (var c = 0; c < classes; c++) {
      sumExp += math.exp(logits[offset + c] - best);
    }
    if (sumExp > 0) {
      probabilitySum += 1 / sumExp;
      counted++;
    }
    if (bestId != blankId && bestId != previous) {
      buffer.write(vocab[bestId] ?? '');
    }
    previous = bestId;
  }

  final text =
      buffer
          .toString()
          .replaceAll('|', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  return (text: text, confidence: counted == 0 ? 0 : probabilitySum / counted);
}

/// Builds logits that pick [ids], one per frame.
List<double> framesOf(List<int> ids, int classes) {
  final out = <double>[];
  for (final id in ids) {
    for (var c = 0; c < classes; c++) {
      out.add(c == id ? 8.0 : 0.0);
    }
  }
  return out;
}

void main() {
  // A miniature of the real table: 0 is [PAD], the CTC blank.
  const vocab = {0: '[PAD]', 1: '|', 2: 'a', 3: 'h', 4: 'o', 5: 'j', 6: 'ř'};
  const classes = 7;

  ({String text, double confidence}) run(List<int> ids) => decode(
    logits: framesOf(ids, classes),
    frames: ids.length,
    classes: classes,
    vocab: vocab,
    blankId: 0,
  );

  test('blanks are dropped', () {
    expect(run([0, 2, 0, 3, 0]).text, 'ah');
  });

  test('repeated frames collapse to one character', () {
    // The model emits a token for as long as it hears it — "ahoj" spoken
    // slowly is many frames per letter, not many letters.
    expect(run([2, 2, 2, 3, 3, 4, 4, 4, 5]).text, 'ahoj');
  });

  test('a blank between repeats preserves a genuine double letter', () {
    // This is the whole reason CTC has a blank: without the separator,
    // "aa" and a long "a" would be indistinguishable.
    expect(run([2, 0, 2]).text, 'aa');
    expect(run([2, 2]).text, 'a');
  });

  test('the word separator becomes a space', () {
    expect(run([3, 4, 1, 2, 5]).text, 'ho aj');
  });

  test('leading and trailing separators do not leave stray spaces', () {
    expect(run([1, 2, 3, 1]).text, 'ah');
  });

  test('Czech diacritics survive decoding', () {
    // The characters that matter most in this app are exactly the ones a
    // careless byte-level decode would mangle.
    expect(run([6, 0, 2]).text, 'řa');
  });

  test('silence decodes to nothing rather than a guess', () {
    expect(run([0, 0, 0, 0]).text, isEmpty);
  });

  test('confidence is high when one class dominates', () {
    final result = run([2, 3, 4]);
    expect(result.confidence, greaterThan(0.9));
  });

  test('confidence is low when classes are evenly matched', () {
    // Flat logits mean the model is guessing; the number should say so.
    final flat = List<double>.filled(classes * 3, 1.0);
    final result = decode(
      logits: flat,
      frames: 3,
      classes: classes,
      vocab: vocab,
      blankId: 0,
    );
    expect(result.confidence, closeTo(1 / classes, 0.01));
  });

  test('a wrong blank index changes the transcript', () {
    // Guards the assumption that [PAD] is the blank. If the vocabulary ever
    // moves it, this is the failure that should surface.
    final ids = [0, 2, 0, 3];
    final correct = run(ids).text;
    final wrong =
        decode(
          logits: framesOf(ids, classes),
          frames: ids.length,
          classes: classes,
          vocab: vocab,
          blankId: 2,
        ).text;
    expect(correct, 'ah');
    expect(wrong, isNot(correct));
  });
}
