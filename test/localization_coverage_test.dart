import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when a user-visible string is written into Dart instead of the ARB.
///
/// The app teaches Czech to people who read English, so `kInterfaceLocales`
/// offers English only and every hardcoded English string looks correct. It is
/// only when a second *source* language is added — teaching Czech to German or
/// Ukrainian speakers — that they show up, all at once, as English text
/// stranded in someone else's UI. `l10n_parity_test` cannot see them: it
/// compares the two ARB files against each other, and a string that never
/// reached either one is invisible to it.
///
/// The allowlist below is the remaining backlog, and it exists to be emptied.
/// Adding to it has to be a deliberate act with a reason; every entry removed
/// is one less thing standing between this app and a second audience.
void main() {
  /// Positions where a literal ends up in front of a learner.
  ///
  /// Deliberately not "every string in the file" — that would drown the real
  /// findings in map keys, asset paths and JSON field names.
  // The `\b(?:` prefix lives here so the RegExp below is a single raw string.
  const attributes =
      r'\b(?:hintText|labelText|semanticLabel|tooltip|label|helperText'
      r'|errorText|title|message|body|eyebrow|confirmLabel|dismissLabel'
      r'|primaryLabel|subtitle)';
  final patterns = <RegExp>[
    RegExp(r"""\bText\(\s*(?:const\s+)?['"]([^'"\n]{2,})['"]"""),
    RegExp(r"""\bDisplayText\(\s*(?:const\s+)?['"]([^'"\n]{2,})['"]"""),
    RegExp(attributes + r""":\s*(?:const\s+)?['"]([^'"\n]{2,})['"]"""),
  ];

  /// Files whose strings never reach a learner.
  bool exempt(String path) =>
      // Content-authoring validation: these are read by whoever is writing a
      // lesson pack, in a test failure, and never shipped to a device.
      path.endsWith('curriculum_contract_validator.dart') ||
      // The app's own name.
      path.endsWith('main.dart');

  /// Strings that are correct as literals, keyed by the file they belong to.
  ///
  /// Scoping by file matters: "Try again" is unavoidable on the loading screen
  /// and a plain oversight in the pronunciation view, and a bare string set
  /// would have exempted both.
  const permanent = <String, Set<String>>{
    // Rendered before MaterialApp.router exists, so there is no Localizations
    // ancestor and `AppLocalizations.of` would return null.
    'loading_screen.dart': {'Try again'},
    // Czech on purpose: the greeting the learner is being taught, not UI
    // copy. It stays Czech whatever language the interface is in.
    'daily_arrival_screen.dart': {'DOBRÝ DEN', 'VÍTEJTE ZPĚT', 'SKVĚLÁ PRÁCE'},
    'reward_toast.dart': {'Přijď zítra zas · come back tomorrow'},
    // The app's own name.
    'about_screen.dart': {'Czechify'},
    // A bullet and a value, not a sentence.
    'mock_exam_screen.dart': {'• \$criterion'},
  };

  /// Whole files exempted from the scan.
  ///
  /// Empty, and meant to stay that way. It held notification messages,
  /// learning tips and chat scenario names — all three built user-visible
  /// text away from a `BuildContext`, which is a different problem from
  /// moving a string off a widget and was worth naming separately while it
  /// lasted. Each was solved by splitting identity from wording: the entity
  /// keeps an id, and whoever displays it resolves the words. Anything added
  /// back here needs the same kind of reason.
  const backlogFiles = <String>{};

  test('user-visible strings live in the ARB, not in Dart', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (exempt(file.path)) continue;
      if (backlogFiles.any(file.path.endsWith)) continue;
      // Generated localizations are literals by definition.
      if (file.path.contains('/l10n/')) continue;

      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        for (final pattern in patterns) {
          for (final match in pattern.allMatches(code)) {
            final text = match.group(1)!;
            // Needs letters to be prose; skips '• ', ':', asset keys.
            if (!RegExp(r'[A-Za-z]{3}').hasMatch(text)) continue;
            if (text.startsWith(r'$')) continue;
            final allowed =
                permanent.entries
                    .firstWhere(
                      (e) => file.path.endsWith(e.key),
                      orElse: () => const MapEntry('', <String>{}),
                    )
                    .value;
            if (allowed.contains(text)) continue;
            offenders.add('${file.path}:${i + 1}  "$text"');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These are shown to a learner but written in Dart, so they stay '
          'English in every other interface language:\n'
          '${offenders.join('\n')}\n'
          'Move them into app_en.arb and app_cs.arb and read them through '
          'AppLocalizations.',
    );
  });

  test('the allowlists only shrink', () {
    // An entry that no longer appears in lib/ silently exempts whatever text
    // is written in its place next.
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
    final sources = {for (final f in files) f.path: f.readAsStringSync()};

    final stale = <String>[];
    permanent.forEach((suffix, strings) {
      final matching = sources.entries.where((e) => e.key.endsWith(suffix));
      if (matching.isEmpty) {
        stale.add('$suffix (file is gone)');
        return;
      }
      for (final text in strings) {
        if (!matching.any((e) => e.value.contains(text))) {
          stale.add('$suffix: "$text"');
        }
      }
    });
    for (final suffix in backlogFiles) {
      if (!sources.keys.any((p) => p.endsWith(suffix))) {
        stale.add('$suffix (file is gone)');
      }
    }

    expect(stale, isEmpty, reason: 'Remove these from the allowlists: $stale');
  });
}
