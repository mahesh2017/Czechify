import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

/// Adaptive scaffold — bottom nav on mobile, side rail on desktop.
class AdaptiveScaffold extends StatelessWidget {
  final Widget child;

  const AdaptiveScaffold({super.key, required this.child});

  static const _destinations = [
    (icon: Icons.home_outlined, path: '/'),
    (icon: Icons.school_outlined, path: '/curriculum'),
    (icon: Icons.style_outlined, path: '/review'),
    (icon: Icons.chat_outlined, path: '/chat'),
    (icon: Icons.bar_chart_outlined, path: '/stats'),
  ];

  /// Labels are resolved per build so they follow the app locale; the
  /// destination list itself stays const.
  static List<String> _labels(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      l10n.navHome,
      l10n.navLearn,
      l10n.navReview,
      l10n.navChat,
      l10n.navStats,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 600;
    final labels = _labels(context);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex(context),
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              destinations: [
                for (final (index, d) in _destinations.indexed)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon),
                    label: Text(labels[index]),
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
          for (final (index, d) in _destinations.indexed)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.icon),
              label: labels[index],
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
