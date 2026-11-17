import 'dart:io';

import 'package:czechify/core/legal/legal_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app and the public pages must name the same operator.
///
/// The About screen said "Mahesh Pathak" in a production build after the
/// Play account became Sabiko Global's, because the pages and the app were
/// updated separately.
void main() {
  test('the in-app privacy policy names the operator', () {
    final who = kPrivacyPolicy.first;
    expect(who.body, contains(kOperatorName));
    expect(who.body, contains(kDeveloperName));
  });

  for (final page in ['privacy.html', 'terms.html', 'delete-account.html']) {
    test('docs/site/$page names the same operator', () {
      final html = File('docs/site/$page').readAsStringSync();
      expect(html, contains(kOperatorName));
      expect(html, contains(kDeveloperName));
    });
  }

  test('the site pages carry the company ID and register entry', () {
    for (final page in ['privacy.html', 'terms.html', 'index.html']) {
      final html = File('docs/site/$page').readAsStringSync();
      expect(html, contains('30050642'), reason: page);
      expect(html, contains('C 456524'), reason: page);
    }
  });
}
