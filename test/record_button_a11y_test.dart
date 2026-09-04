import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:czechify/presentation/widgets/common/record_button.dart';

/// The record button is the primary control of the pronunciation flow; it must
/// expose a screen-reader label that reflects its state (not color alone).
void main() {
  testWidgets('record button announces its state to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordButton(isRecording: false, onPressed: () {}),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Start recording'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecordButton(isRecording: true, onPressed: () {})),
      ),
    );
    expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);

    handle.dispose();
  });
}
