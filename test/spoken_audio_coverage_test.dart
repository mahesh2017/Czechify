import 'dart:convert';
import 'dart:io';

import 'package:czechify/core/utils/text_normalizer.dart';
import 'package:czechify/data/services/audio/audio_pack_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the two ways Czech ends up spoken in the phone's voice instead of the
/// recorded teacher's.
///
/// Both had shipped. Settings' "Test voice" passed a hardcoded phrase to
/// `speak()`, whose clip is neither bundled nor pre-fetched — so the one
/// control whose entire purpose is *"what does my teacher sound like?"* would
/// answer in the device voice on a weak connection, with no banner in Settings
/// to say why. And the placement test, which decides where a learner starts
/// from audio they must understand, spoke through the raw `FlutterTts` provider
/// and so never consulted the pack at all.
///
/// Neither is visible in review: both compile, both make a sound, and the sound
/// is only wrong if you know which voice you were owed.
void main() {
  final dartFiles =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

  String sourceOf(File file) => file
      .readAsStringSync()
      // Comments quote both of these patterns when explaining them.
      .split('\n')
      .map((line) {
        final comment = line.indexOf('//');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  test('nothing speaks through the raw TTS engine', () {
    // `ttsProvider` is the bare FlutterTts. Only CzechTts may drive it: it is
    // what consults the recorded pack, re-asserts cs-CZ, applies the learner's
    // speed and raises `usingFallbackVoice` when it had to substitute.
    final offenders = <String>[];
    for (final file in dartFiles) {
      if (file.path.endsWith('tts_providers.dart')) continue;
      final source = sourceOf(file);
      final uses = RegExp(
        r'(?:read|watch)\(\s*ttsProvider\s*\)',
      ).allMatches(source);
      for (final _ in uses) {
        offenders.add(file.path);
        break;
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These read the raw FlutterTts provider and so bypass the recorded '
          'audio pack entirely — they will always speak in the device voice: '
          '${offenders.join(', ')}. Use czechTtsProvider instead.',
    );
  });

  test('every Czech phrase spoken from a literal has a recorded clip', () {
    // Curriculum text is covered by the generation pipeline, which walks the
    // lesson JSON. A literal in Dart is invisible to it, so each one has to be
    // registered by hand — and forgetting is silent.
    final manifest =
        jsonDecode(File('assets/audio/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final voices = manifest['voices'] as Map<String, dynamic>;
    bool recorded(String text) {
      final key = AudioPackCache.keyFor(TextNormalizer.forSpeech(text));
      return ['female', 'male'].every((gender) {
        final entries =
            (voices[gender] as Map<String, dynamic>)['entries']
                as Map<String, dynamic>;
        return entries.containsKey(key);
      });
    }

    // Clips commissioned but not yet generated and uploaded. Emptying this is
    // the signal that the gap is closed; adding to it has to be deliberate.
    // Now empty: the placement prompts were recorded in both voices — Oliver,
    // and Hanka for the female side once Azure's credit ran out.
    const pendingGeneration = <String>{};

    // Czech literals reaching an utterance: spoken directly, or declared as a
    // placement prompt (`spoken:`) that the screen later speaks.
    final literal = RegExp(
      r"""(?:\.speak\(\s*|spoken:\s*)'([^']*[áčďéěíňóřšťúůýž][^']*)'""",
    );
    final found = <String, String>{};
    for (final file in dartFiles) {
      for (final match in literal.allMatches(sourceOf(file))) {
        found[match.group(1)!] = file.path;
      }
    }

    expect(
      found,
      isNotEmpty,
      reason:
          'The scan found no spoken Czech literals at all — the pattern has '
          'stopped matching and this guard is checking nothing.',
    );

    final uncovered = {
      for (final entry in found.entries)
        if (!recorded(entry.key) && !pendingGeneration.contains(entry.key))
          entry.key: entry.value,
    };
    expect(
      uncovered,
      isEmpty,
      reason:
          'These Czech phrases are spoken from a Dart literal but have no clip '
          'in assets/audio/manifest.json, so they fall back to the device '
          'voice: $uncovered. Register them in tool/audio_utterances.py '
          '(LITERAL_TEXTS), generate the pack, and upload it.',
    );

    // A pending entry that has since been recorded should leave the list, or it
    // hides the next real gap.
    final stale = pendingGeneration.where(recorded).toList();
    expect(
      stale,
      isEmpty,
      reason:
          'These now have clips and should be removed from pendingGeneration: '
          '$stale',
    );
  });
}
