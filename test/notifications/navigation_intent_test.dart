import 'dart:async';

import 'package:czechify/core/notifications/navigation_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains a cold-launch target until the UI subscribes', () async {
    NavigationIntent.queue(NavigationTarget.curriculum);

    expect(await NavigationIntent.stream.first, NavigationTarget.curriculum);
  });

  test('delivers a warm tap to an active UI subscription', () async {
    final result = Completer<NavigationTarget>();
    final subscription = NavigationIntent.stream.listen(result.complete);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    NavigationIntent.queue(NavigationTarget.review);

    expect(await result.future, NavigationTarget.review);
  });
}
