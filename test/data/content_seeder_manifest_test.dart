import 'package:ceskina_pro/data/seeds/content_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires both lesson packs for every A1 and A2 unit', () {
    final lessonPacks = ContentSeeder.requiredPackPaths.where(
      (path) => path.startsWith('assets/curriculum/lessons/'),
    );

    expect(lessonPacks, hasLength(61));

    // Unit 1 opens with a dedicated alphabet-pronunciation lesson (lesson00)
    // before the two standard lessons.
    expect(
      lessonPacks,
      contains('assets/curriculum/lessons/unit01_lesson00.json'),
      reason: 'Unit 1 must ship the alphabet-pronunciation lesson.',
    );

    for (var unit = 1; unit <= 29; unit++) {
      final unitNumber = unit.toString().padLeft(2, '0');
      for (var lesson = 1; lesson <= 2; lesson++) {
        final lessonNumber = lesson.toString().padLeft(2, '0');
        expect(
          lessonPacks,
          contains(
            'assets/curriculum/lessons/'
            'unit${unitNumber}_lesson$lessonNumber.json',
          ),
          reason: 'Unit $unit lesson $lesson must be part of every release.',
        );
      }
    }
    // Units 30-31 have one lesson each
    for (var unit = 30; unit <= 31; unit++) {
      final unitNumber = unit.toString().padLeft(2, '0');
      expect(
        lessonPacks,
        contains(
          'assets/curriculum/lessons/'
          'unit${unitNumber}_lesson01.json',
        ),
        reason: 'Unit $unit lesson 1 must be part of every release.',
      );
    }
  });
}
