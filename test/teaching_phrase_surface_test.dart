import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/core/theme/app_tokens.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/teaching_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
  testWidgets('a resting listening row has an opaque fill over its shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeachingView(
                exercise: const Exercise(
                  id: 1,
                  lessonId: 1,
                  type: ExerciseType.teaching,
                  prompt: 'Listen',
                  data: {
                    'heading': 'Useful words',
                    'style': 'list',
                    'items': [
                      {'cz': 'káva', 'en': 'long á'},
                    ],
                  },
                ),
                onAnswered: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final ancestors = tester.widgetList<Container>(
      find.ancestor(of: find.text('káva'), matching: find.byType(Container)),
    );
    final surface = ancestors
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .singleWhere((decoration) => decoration.boxShadow?.isNotEmpty ?? false);

    expect(surface.color, AppTokens.light.card);
    expect(surface.border, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
