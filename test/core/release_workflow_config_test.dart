import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release workflow is locked to Czechify-prod', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();

    expect(
      workflow,
      contains(
        'PRODUCTION_SUPABASE_URL: '
        'https://twhvcxtieolvnbnczypj.supabase.co',
      ),
    );
    expect(
      RegExp(
        r'test "\$SUPABASE_URL" = "\$PRODUCTION_SUPABASE_URL"',
      ).allMatches(workflow),
      hasLength(2),
      reason: 'Both Android and iOS must reject non-production backends.',
    );
  });

  test('private production define file cannot be committed', () {
    final gitignore = File('.gitignore').readAsStringSync();

    expect(gitignore.split('\n'), contains('/env/prod.json'));
  });
}
