import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A half-translated locale is worse than no locale: the learner gets a
/// screen of Czech with English words scattered through it, and nothing in
/// the build fails. These tests keep the two ARB files in lockstep.
void main() {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// Message keys only — `@@locale` and the `@key` metadata entries are not
  /// translatable strings.
  Set<String> messageKeys(Map<String, dynamic> source) =>
      source.keys.where((key) => !key.startsWith('@')).toSet();

  test('Czech translates every English message', () {
    final missing = messageKeys(arb('en')).difference(messageKeys(arb('cs')));
    expect(
      missing,
      isEmpty,
      reason: 'Untranslated keys would render in English inside a Czech UI',
    );
  });

  test('Czech defines no message English does not have', () {
    final extra = messageKeys(arb('cs')).difference(messageKeys(arb('en')));
    expect(
      extra,
      isEmpty,
      reason: 'A key absent from the template ARB is dead weight',
    );
  });

  test('placeholders match between locales', () {
    final english = arb('en');
    final czech = arb('cs');
    // Only `{name}` — a bare identifier in braces. Anything else is ICU
    // syntax: `{count,plural,` opens a selector and `one{Zbývá …}` is a
    // branch body, neither of which is a placeholder reference.
    final placeholder = RegExp(r'\{(\w+)\}');
    Set<String> names(String source) =>
        placeholder.allMatches(source).map((match) => match.group(1)!).toSet();

    for (final key in messageKeys(english)) {
      expect(
        names(czech[key] as String),
        names(english[key] as String),
        reason: 'Placeholder mismatch in "$key" would throw at runtime',
      );
    }
  });

  test('no message is left as its English source text', () {
    final english = arb('en');
    final czech = arb('cs');
    // Brand names and single-token labels legitimately match across locales.
    const sharedByDesign = {'appTitle'};

    final untranslated = messageKeys(english)
        .where((key) => !sharedByDesign.contains(key))
        .where((key) => czech[key] == english[key])
        .toSet();

    expect(
      untranslated,
      isEmpty,
      reason: 'These look copied from English rather than translated',
    );
  });
}
