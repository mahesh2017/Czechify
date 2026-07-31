import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../providers/chat_providers.dart';

/// Adaptive scaffold — bottom nav on mobile, side rail on desktop.
class AdaptiveScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 600;
    final labels = _labels(context);
    final location = GoRouterState.of(context).uri.path;
    final conversationActive =
        location == '/chat' &&
        ref.watch(chatProvider.select((chat) => chat.conversationId != null));
    final hideBottomNavigation = conversationActive;

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
      extendBody: !hideBottomNavigation,
      body: child,
      bottomNavigationBar:
          hideBottomNavigation
              ? null
              : _PrototypeTabBar(
                selectedIndex: _selectedIndex(context),
                labels: labels,
                onSelected: (i) => context.go(_destinations[i].path),
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

class _PrototypeTabBar extends StatelessWidget {
  const _PrototypeTabBar({
    required this.selectedIndex,
    required this.labels,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 92,
          // The design's bar is a fixed 92pt with `padding:10px 8px 0` and no
          // bottom inset of its own — the icon/label stack sits in the top
          // 60pt and the home indicator overlaps the empty remainder. Adding
          // the safe-area inset here instead squeezed the stack into 50pt and
          // overflowed the column.
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: Row(
            children: [
              for (final (index, destination)
                  in AdaptiveScaffold._destinations.indexed)
                Expanded(
                  child: Semantics(
                    selected: selectedIndex == index,
                    button: true,
                    label: labels[index],
                    child: InkResponse(
                      onTap: () => onSelected(index),
                      radius: 30,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 44,
                            height: 30,
                            decoration: BoxDecoration(
                              color:
                                  selectedIndex == index
                                      ? t.priSoft
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              destination.icon,
                              size: 21,
                              color: selectedIndex == index ? t.pri : t.faint,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: selectedIndex == index ? t.pri : t.faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
