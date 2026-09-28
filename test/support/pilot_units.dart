import 'package:czechify/core/config/unit_guide_pilot.dart';

/// The units whose lessons use the no-scroll layouts (slides, slim frame,
/// feedback over the exercise). Tests of those layouts cover every one, so
/// switching a unit on needs no test edits.
List<int> get pilotUnits =>
    [for (var unit = 1; unit <= 31; unit++) if (unitGuideEnabled(unit)) unit];

/// A unit still on the one-page layouts, for tests of those layouts.
///
/// Every course unit is switched on since A2 (28 Sep 2026), so this is unit
/// 0, which no shipped lesson belongs to: the one-page layouts are kept, and
/// tested on made-up lessons, until they are removed.
int get outsidePilotUnit => [
  for (var unit = 1; unit <= 31; unit++)
    if (!unitGuideEnabled(unit)) unit,
  0,
].first;

/// Lesson [n] (1-based) of [outsidePilotUnit], as a lesson id.
int outsidePilotLesson(int n) => outsidePilotUnit * 100 + n;
