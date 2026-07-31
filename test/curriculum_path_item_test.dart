import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:ceskina_pro/l10n/app_localizations.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/lesson.dart';
import 'package:ceskina_pro/domain/entities/unit.dart';
import 'package:ceskina_pro/presentation/models/curriculum_path_item.dart';

void main() {
  const unit = Unit(
    id: 1,
    title: 'Introductions',
    description: 'Introduce yourself politely',
    phase: Phase.a1,
    orderIndex: 0,
  );

  test('keeps presentation metadata separate from curriculum entities', () {
    const lesson = Lesson(
      id: 10,
      unitId: 1,
      orderInUnit: 0,
      title: 'Hello',
      description: 'Greetings',
      durationMinutes: 12,
    );
    const item = CurriculumPathItem(
      unit: unit,
      lessons: [lesson],
      state: CurriculumPathState.current,
      section: 'A1 Foundations',
      payoff: 'Introduce yourself politely.',
      durationMinutes: 12,
      recommendation: 'Recommended next',
    );

    expect(item.unit.id, 1);
    expect(item.durationMinutes, 12);
    expect(item.state, CurriculumPathState.current);
    expect(item.recommendation, isNotNull);
  });

  test('derives stable section and payoff labels', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(CurriculumPathItem.sectionFor(unit, 0, 10, l10n), 'A1 Foundations');
    expect(
      CurriculumPathItem.payoffFor(unit, l10n),
      'Introduce yourself politely.',
    );
  });
}
