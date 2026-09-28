import 'package:czechify/presentation/widgets/common/slide_deck.dart';
import 'package:flutter_test/flutter_test.dart';

/// Turns a step's slides with Next until the last, where its answer, record
/// button or check is: every several-part step is a deck. Fixed frames, not
/// settling: a step may animate for as long as it plays audio.
Future<void> toLastSlide(WidgetTester tester) async {
  Future<void> frames() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  await frames();
  for (var i = 0; i < 20 && find.byKey(SlideDeck.nextKey).evaluate().isNotEmpty; i++) {
    await tester.tap(find.byKey(SlideDeck.nextKey));
    await frames();
  }
}
