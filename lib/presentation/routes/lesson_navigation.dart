import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Leaves a lesson without assuming it was pushed onto another screen.
///
/// Curriculum and Home push lessons, so they should reveal their caller.
/// Daily Arrival and external links can open a lesson as the root route; in
/// that case there is nothing to pop and Home is the safe destination.
void leaveLesson(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
  } else {
    router.go('/');
  }
}
