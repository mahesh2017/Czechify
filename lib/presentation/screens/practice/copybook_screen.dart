import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/copybook_providers.dart';
import '../../providers/notebook_providers.dart';
import '../../widgets/common/motion_widgets.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/wash_background.dart';
import '../../widgets/common/motion_async.dart';

class CopybookScreen extends ConsumerStatefulWidget {
  const CopybookScreen({super.key});

  @override
  ConsumerState<CopybookScreen> createState() => _CopybookScreenState();
}

class _CopybookScreenState extends ConsumerState<CopybookScreen> {
  final Set<int> _done = {};
  final Set<int> _liveChangedItems = {};
  bool _completionChangedLive = false;

  String get _dayKey => DateUtils.dateOnly(DateTime.now()).toIso8601String();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('copybook_done_$_dayKey') ?? const [];
    if (mounted) setState(() => _done.addAll(saved.map(int.parse)));
  }

  Future<void> _toggle(int id, List<CopybookItem> dailyItems) async {
    final wasComplete = dailyItems.every((item) => _done.contains(item.id));
    setState(() {
      _done.contains(id) ? _done.remove(id) : _done.add(id);
      _liveChangedItems.add(id);
      final isComplete = dailyItems.every((item) => _done.contains(item.id));
      _completionChangedLive = wasComplete != isComplete;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'copybook_done_$_dayKey',
      _done.map((value) => '$value').toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(dailyCopybookProvider);
    return WashBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.copybookTitle),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            DisplayText(l10n.copybookHeading, size: 28),
            const SizedBox(height: 8),
            Text(
              l10n.copybookBody,
              style: TextStyle(fontSize: 16, height: 1.45, color: t.muted),
            ),
            const _NotebookTodoSection(),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/copybook_hero_v1.webp',
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: l10n.copybookImageLabel,
              ),
            ),
            const SizedBox(height: 20),
            MotionAsync(
              value: items,
              loading:
                  () => Center(
                    child:
                        context.motionDisabled
                            ? Icon(Icons.hourglass_top_rounded, color: t.muted)
                            : const CircularProgressIndicator(),
                  ),
              error:
                  (_, __) => _MessageCard(
                    message: l10n.copybookLoadError,
                    action: TextButton(
                      onPressed: () => ref.invalidate(dailyCopybookProvider),
                      child: Text(l10n.copybookTryAgain),
                    ),
                  ),
              data:
                  (dailyItems) => Column(
                    children: [
                      for (final item in dailyItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            button: true,
                            checked: _done.contains(item.id),
                            label: '${item.czech}, ${item.english}',
                            child: SoftCard(
                              onTap: () => _toggle(item.id, dailyItems),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.czech,
                                          style: TextStyle(
                                            fontFamily: AppFonts.display,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: t.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.english,
                                          style: TextStyle(color: t.muted),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          item.example,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: t.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  MotionSwap(
                                    duration:
                                        _liveChangedItems.contains(item.id)
                                            ? AppMotion.selection
                                            : Duration.zero,
                                    offset: const Offset(0, 0.12),
                                    child: Icon(
                                      _done.contains(item.id)
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      key: ValueKey(_done.contains(item.id)),
                                      color:
                                          _done.contains(item.id)
                                              ? t.greenInk
                                              : t.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (dailyItems.isEmpty)
                        _MessageCard(message: l10n.copybookOfflineEmpty),
                      MotionDisclosure(
                        visible:
                            dailyItems.isNotEmpty &&
                            dailyItems.every((item) => _done.contains(item.id)),
                        duration:
                            _completionChangedLive
                                ? AppMotion.reward
                                : Duration.zero,
                        child: SoftCard(
                          color: t.greenSoft,
                          child: Text(
                            l10n.copybookComplete,
                            style: TextStyle(
                              color: t.greenInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notebook steps the learner put off in a lesson with "I don't have a pen right now".
///
/// Shown first because it is unfinished work from a lesson, where the daily
/// words below are optional practice. Hidden entirely when empty.
class _NotebookTodoSection extends ConsumerWidget {
  const _NotebookTodoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final todos = ref.watch(notebookTodoProvider).asData?.value ?? const [];
    if (todos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.copybookTodoTitle,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.copybookTodoBody,
            style: TextStyle(fontSize: 14, height: 1.4, color: t.muted),
          ),
          const SizedBox(height: 10),
          for (final todo in todos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.heading,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                          ),
                          if (todo.instruction.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              todo.instruction,
                              style: TextStyle(fontSize: 15, color: t.ink),
                            ),
                          ],
                          if (todo.model.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final row in todo.model)
                              Text(
                                row.en.isEmpty
                                    ? row.cz
                                    : '${row.cz} — ${row.en}',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: t.muted,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.copybookTodoDone,
                      icon: Icon(Icons.check_circle_outline, color: t.greenInk),
                      onPressed: () async {
                        await ref
                            .read(notebookStoreProvider)
                            .markWritten(todo.exerciseId);
                        ref.invalidate(notebookTodoProvider);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      children: [
        Text(message, style: TextStyle(color: context.tokens.muted)),
        if (action != null) action!,
      ],
    ),
  );
}
