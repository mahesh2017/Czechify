import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Adaptive scaffold — bottom nav on mobile, side rail on desktop.
class AdaptiveScaffold extends StatelessWidget {
  final Widget child;

  const AdaptiveScaffold({super.key, required this.child});

  static const _destinations = [
    (icon: Icons.home_outlined, label: 'Home', path: '/'),
    (icon: Icons.school_outlined, label: 'Learn', path: '/curriculum'),
    (icon: Icons.style_outlined, label: 'Review', path: '/review'),
    (icon: Icons.chat_outlined, label: 'Chat', path: '/chat'),
    (icon: Icons.bar_chart_outlined, label: 'Stats', path: '/stats'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 600;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex(context),
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Cap content width on wide screens so cards don't stretch
            // edge-to-edge on desktop.
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.icon),
              label: d.label,
            ),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _destinations.length; i++) {
      final path = _destinations[i].path;
      // '/' prefixes every location, so home only matches exactly.
      final matches = path == '/' ? location == '/' : location.startsWith(path);
      if (matches) return i;
    }
    return 0;
  }
}
