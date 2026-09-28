/// The unit-guide pilot: which units get the guide, rule slides and the
/// in-lesson Rule button instead of "Lecture & notebook". Unit 2 first, to
/// see how it works before the rest of the course follows.
const unitGuidePilotUnits = {
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
  22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
};

bool unitGuideEnabled(int? unitId) =>
    unitId != null && unitGuidePilotUnits.contains(unitId);

/// A lesson's unit, from its id: lesson 203 is in Unit 2, lesson 1601 in
/// Unit 16. Every bundled lesson follows this (pinned by
/// test/curriculum_v12_contract_test.dart), so lesson widgets can tell their
/// unit without a database lookup.
int unitOfLesson(int lessonId) => lessonId ~/ 100;

/// A lesson's place in its unit as the learner sees it: A, B, C, D.
String lessonLetter(int orderInUnit) => String.fromCharCode(65 + orderInUnit);
