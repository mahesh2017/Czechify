import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/common/lesson_image.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise exercise(Map<String, dynamic> data) => Exercise(
  id: 1,
  lessonId: 1,
  type: ExerciseType.dialogue,
  prompt: 'p',
  data: data,
);

/// [LessonImage.precacheFor] warms whatever [LessonImage.assetFor] finds. If
/// that lookup returns null for a shape the content actually uses, nothing
/// throws and nothing is warmed — the illustration simply goes back to
/// decoding on arrival, which is invisible in every other test. So the lookup
/// is worth pinning to the shapes the lesson JSON really carries.
void main() {
  test('finds the illustration four exercise types carry directly', () {
    expect(
      LessonImage.assetFor(exercise({'image': 'assets/images/unit16/a.webp'})),
      'assets/images/unit16/a.webp',
    );
  });

  test('finds the first illustration on an image-card teaching exercise', () {
    expect(
      LessonImage.assetFor(
        exercise({
          'style': 'image_cards',
          'items': [
            {'cz': 'káva'},
            {'cz': 'čaj', 'image': 'assets/images/unit02/tea.webp'},
            {'cz': 'voda', 'image': 'assets/images/unit02/water.webp'},
          ],
        }),
      ),
      'assets/images/unit02/tea.webp',
    );
  });

  test('prefers the exercise-level image over an item one', () {
    expect(
      LessonImage.assetFor(
        exercise({
          'image': 'assets/images/unit05/scene.webp',
          'items': [
            {'image': 'assets/images/unit05/item.webp'},
          ],
        }),
      ),
      'assets/images/unit05/scene.webp',
    );
  });

  test('returns nothing for an exercise with no illustration', () {
    expect(LessonImage.assetFor(exercise({'prompt': 'no picture'})), isNull);
    expect(LessonImage.assetFor(exercise({'image': '   '})), isNull);
    expect(
      LessonImage.assetFor(
        exercise({
          'items': [
            {'cz': 'káva'},
            {'cz': 'čaj'},
          ],
        }),
      ),
      isNull,
    );
  });

  test('survives an items list that is not a list of maps', () {
    expect(LessonImage.assetFor(exercise({'items': 'not a list'})), isNull);
    expect(
      LessonImage.assetFor(
        exercise({
          'items': ['káva', 42],
        }),
      ),
      isNull,
    );
  });
}
