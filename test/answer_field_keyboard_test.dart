import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Typing an answer used to end with the Check button under the keyboard: the
/// field scrolled itself just clear of the keys and the button that submits it
/// stayed below, so the learner had to scroll to do anything with what they
/// had typed.
void main() {
  testWidgets('focusing the answer reserves room for what sits below it', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 600),
                AnswerField(controller: controller),
                const SizedBox(height: 40),
                KeyCta(label: 'Check', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));

    // 20px is Flutter's default and is only enough for the field itself.
    // The reserve has to cover the gap plus the button under it.
    expect(field.scrollPadding.vertical, greaterThan(40 + 56));
    expect(field.scrollPadding, isA<EdgeInsets>());
  });

  testWidgets('the field still works normally with the larger reserve', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          body: AnswerField(
            controller: controller,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'káva');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.text, 'káva');
    expect(submitted, 'káva');
  });
}
