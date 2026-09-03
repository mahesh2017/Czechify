import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import '../providers/chat_providers.dart';
import '../widgets/common/motion_widgets.dart';

/// Adaptive scaffold — bottom nav on mobile, side rail on desktop.
class AdaptiveScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdaptiveScaffold({super.key, required this.navigationShell});

  static const _destinations = [
    Icons.home_outlined,
    Icons.school_outlined,
    Icons.style_outlined,
    Icons.chat_outlined,
    Icons.bar_chart_outlined,
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
    final selectedIndex = navigationShell.currentIndex;
    final conversationActive =
        location == '/chat' &&
        ref.watch(chatProvider.select((chat) => chat.conversationId != null));
    final hideBottomNavigation = conversationActive;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => _selectBranch(i),
              destinations: [
                for (final (index, icon) in _destinations.indexed)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(icon),
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
                  child: _BranchEntrance(
                    index: selectedIndex,
                    child: navigationShell,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: _BranchEntrance(index: selectedIndex, child: navigationShell),
      bottomNavigationBar: MotionDisclosure(
        visible: !hideBottomNavigation,
        duration: AppMotion.content,
        alignment: Alignment.bottomCenter,
        offset: const Offset(0, 0.08),
        child: _PrototypeTabBar(
          selectedIndex: selectedIndex,
          labels: labels,
          onSelected: _selectBranch,
        ),
      ),
    );
  }

  void _selectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// A subtle incoming-only branch transition. The indexed shell itself stays
/// mounted, so this polish cannot reset a tab's Navigator or scroll state.
class _BranchEntrance extends StatefulWidget {
  const _BranchEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchEntrance> createState() => _BranchEntranceState();
}

class _BranchEntranceState extends State<_BranchEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.content,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motionDisabled) {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _BranchEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (context.motionDisabled) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = AppMotion.enter.transform(_controller.value);
        return Opacity(
          key: const ValueKey('branch-transition-opacity'),
          opacity: 0.88 + 0.12 * value,
          child: FractionalTranslation(
            translation: Offset(0, 0.015 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
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
              for (final (index, icon)
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
                            duration: context.motionDuration(
                              AppMotion.selection,
                            ),
                            curve: AppMotion.enter,
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
                              icon,
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
