import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/copybook_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/wash_background.dart';

class CopybookScreen extends ConsumerStatefulWidget {
  const CopybookScreen({super.key});

  @override
  ConsumerState<CopybookScreen> createState() => _CopybookScreenState();
}

class _CopybookScreenState extends ConsumerState<CopybookScreen> {
  final Set<int> _done = {};

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

  Future<void> _toggle(int id) async {
    setState(() => _done.contains(id) ? _done.remove(id) : _done.add(id));
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
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/copybook_hero_v1.png',
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: l10n.copybookImageLabel,
              ),
            ),
            const SizedBox(height: 20),
            items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                              onTap: () => _toggle(item.id),
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
                                  Icon(
                                    _done.contains(item.id)
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color:
                                        _done.contains(item.id)
                                            ? t.greenInk
                                            : t.faint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (dailyItems.isEmpty)
                        _MessageCard(message: l10n.copybookOfflineEmpty),
                      if (dailyItems.isNotEmpty &&
                          dailyItems.every((item) => _done.contains(item.id)))
                        SoftCard(
                          color: t.greenSoft,
                          child: Text(
                            l10n.copybookComplete,
                            style: TextStyle(
                              color: t.greenInk,
                              fontWeight: FontWeight.w700,
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
