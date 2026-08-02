import 'package:ceskina_pro/data/seeds/content_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires the complete lesson-pack set for every A1 and A2 unit', () {
    final lessonPacks = ContentSeeder.requiredPackPaths.where(
      (path) => path.startsWith('assets/curriculum/lessons/'),
    );

    expect(lessonPacks, hasLength(124));

    // Unit 1 has a meaning-first opening lesson and a fourth communication
    // mission in addition to the two standard lesson slots.
    expect(
      lessonPacks,
      contains('assets/curriculum/lessons/unit01_lesson00.json'),
      reason: 'Unit 1 must ship its meaning-first opening lesson.',
    );
    expect(
      lessonPacks,
      contains('assets/curriculum/lessons/unit01_lesson03.json'),
      reason: 'Unit 1 must ship its communication mission.',
    );

    expect(
      lessonPacks,
      containsAll([
        'assets/curriculum/lessons/unit02_lesson03.json',
        'assets/curriculum/lessons/unit02_lesson04.json',
      ]),
      reason: 'Unit 2 must ship its guided-use and communication mission.',
    );

    expect(
      lessonPacks,
      containsAll([
        'assets/curriculum/lessons/unit03_lesson03.json',
        'assets/curriculum/lessons/unit03_lesson04.json',
      ]),
      reason: 'Unit 3 must ship its guided-use and visual mission lessons.',
    );

    for (var unit = 4; unit <= 15; unit++) {
      final unitNumber = unit.toString().padLeft(2, '0');
      expect(
        lessonPacks,
        containsAll([
          'assets/curriculum/lessons/unit${unitNumber}_lesson03.json',
          'assets/curriculum/lessons/unit${unitNumber}_lesson04.json',
        ]),
        reason:
            'Unit $unit must ship its guided-use and communication mission lessons.',
      );
    }

    expect(
      lessonPacks,
      containsAll([
        'assets/curriculum/lessons/unit16_lesson03.json',
        'assets/curriculum/lessons/unit16_lesson04.json',
      ]),
      reason: 'A2 Unit 16 must ship guided use and a communication mission.',
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
    for (final unit in [28, 30]) {
      final unitNumber = unit.toString().padLeft(2, '0');
      expect(
        lessonPacks,
        containsAll([
          'assets/curriculum/lessons/unit${unitNumber}_lesson03.json',
          'assets/curriculum/lessons/unit${unitNumber}_lesson04.json',
        ]),
        reason: 'A1 Unit $unit must ship its complete four-lesson progression.',
      );
    }

    for (final unit in [29, 31]) {
      final unitNumber = unit.toString().padLeft(2, '0');
      expect(
        lessonPacks,
        containsAll([
          'assets/curriculum/lessons/unit${unitNumber}_lesson03.json',
          'assets/curriculum/lessons/unit${unitNumber}_lesson04.json',
        ]),
        reason: 'A2 Unit $unit must ship its complete four-lesson progression.',
      );
    }
  });
}
