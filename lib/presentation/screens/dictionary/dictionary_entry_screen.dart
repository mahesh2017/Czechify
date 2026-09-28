import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/dictionary/dictionary_entry.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/dictionary_providers.dart';
import '../../providers/tts_providers.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/soft_ui.dart';

/// One word: what it means, how it sounds, its key forms, all its forms on
/// request, examples from the course, and where the course teaches it.
///
/// A browsing screen: it scrolls, and the full tables are folded away until
/// asked for so the page opens on what a learner needs first.
class DictionaryEntryScreen extends ConsumerStatefulWidget {
  const DictionaryEntryScreen({
    super.key,
    required this.level,
    required this.entryId,
  });

  final String level;
  final String entryId;

  @override
  ConsumerState<DictionaryEntryScreen> createState() =>
      _DictionaryEntryScreenState();
}

class _DictionaryEntryScreenState extends ConsumerState<DictionaryEntryScreen> {
  bool _allForms = false;

  void _say(String text) {
    ref.read(czechTtsProvider).speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(dictionaryProvider(widget.level));
    final unlocked = ref.watch(unlockedUnitIdsProvider).value ?? const {};

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(l10n.dictionaryLoadFailed)),
          data: (dictionary) {
            final entry = dictionary.byId(widget.entryId);
            if (entry == null) {
              return Center(child: Text(l10n.dictionaryLoadFailed));
            }
            final locked =
                entry.unit != null && !unlocked.contains(entry.unit);
            return ListView(
              key: const ValueKey('dictionary-entry'),
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: const Offset(-8, 0),
                    child: RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onTap: () => context.pop(),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.cz,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(
                      key: const ValueKey('dictionary-listen'),
                      icon: Icons.volume_up_rounded,
                      tooltip: l10n.dictionaryListen,
                      onTap: () => _say(entry.cz),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _grammarLine(entry),
                  style: TextStyle(fontSize: 14, color: t.muted),
                ),
                const SizedBox(height: 10),
                Text(
                  entry.meanings.join('; '),
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                if (entry.unit != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        locked
                            ? Icons.lock_outline_rounded
                            : Icons.school_outlined,
                        size: 16,
                        color: locked ? t.muted : t.pri,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          locked
                              ? l10n.dictionaryTaughtInLocked(entry.unit!)
                              : l10n.dictionaryTaughtIn(entry.unit!),
                          style: TextStyle(
                            fontSize: 13,
                            color: locked ? t.muted : t.priInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (entry.caseGoverned != null) ...[
                  const SizedBox(height: 16),
                  _Labelled(
                    label: l10n.dictionaryUsedWith,
                    child: Text(
                      entry.caseGoverned!,
                      style: TextStyle(fontSize: 16, color: t.ink),
                    ),
                  ),
                ],
                if (entry.keyForms.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionLabel(l10n.dictionaryKeyForms),
                  const SizedBox(height: 8),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        for (final (i, k) in entry.keyForms.indexed)
                          _KeyFormRow(
                            label: k.label,
                            form: k.cz,
                            divider: i > 0,
                            onSay: () => _say(k.cz),
                          ),
                      ],
                    ),
                  ),
                ],
                if (entry.hasTables) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('dictionary-all-forms'),
                      onPressed: () => setState(() => _allForms = !_allForms),
                      icon: Icon(
                        _allForms
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      label: Text(
                        _allForms
                            ? l10n.dictionaryHideAllForms
                            : l10n.dictionaryShowAllForms,
                      ),
                    ),
                  ),
                  if (_allForms)
                    for (final table in entry.tables) _FormsTable(table: table),
                ],
                if (entry.note != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.amberSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: t.amberInk,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.note!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (entry.examples.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SectionLabel(l10n.dictionaryExamples),
                  const SizedBox(height: 8),
                  for (final example in entry.examples)
                    _ExampleRow(
                      example: example,
                      onSay: () => _say(example.cz),
                    ),
                ],
                if (entry.see.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SectionLabel(l10n.dictionarySeeAlso),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cz in entry.see)
                        if (dictionary.byCzech(cz) case final other?)
                          ActionChip(
                            label: Text(other.cz),
                            onPressed:
                                () => context.push(
                                  '/dictionary/${widget.level}/${other.id}',
                                ),
                          ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "noun · feminine", "verb · ongoing or repeated (imperfective)".
String _grammarLine(DictionaryEntry e) {
  final parts = <String>[e.posLabel];
  if (e.genderLabel != null) parts.add(e.genderLabel!);
  if (e.aspect != null) parts.add(e.aspect!);
  return parts.join(' · ');
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SectionLabel(label), const SizedBox(height: 4), child],
    );
  }
}

class _KeyFormRow extends StatelessWidget {
  const _KeyFormRow({
    required this.label,
    required this.form,
    required this.divider,
    required this.onSay,
  });

  final String label;
  final String form;
  final bool divider;
  final VoidCallback onSay;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border:
            divider ? Border(top: BorderSide(color: t.line)) : null,
      ),
      child: InkWell(
        onTap: onSay,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 118,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: t.muted),
                ),
              ),
              Expanded(
                child: Text(
                  form,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
              Icon(
                Icons.volume_up_outlined,
                size: 18,
                color: t.muted,
                semanticLabel: l10n.dictionaryListen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A table of forms. Alternatives ("moje/má") stack in their cell, so a
/// four-column table still fits a small phone without scrolling sideways.
class _FormsTable extends StatelessWidget {
  const _FormsTable({required this.table});

  final DictionaryTable table;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final many = table.columns.length > 2;
    final cellStyle = TextStyle(
      fontSize: many ? 14 : 16,
      height: 1.3,
      color: t.ink,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              table.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.muted,
              ),
            ),
            const SizedBox(height: 6),
            Table(
              columnWidths: const {0: IntrinsicColumnWidth()},
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: [
                if (table.hasHeadings)
                  TableRow(
                    children: [
                      const SizedBox.shrink(),
                      for (final c in table.columns)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 2, 4, 6),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                for (final row in table.rows)
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.line)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 7, 6, 7),
                        child: Text(
                          row.label,
                          style: TextStyle(fontSize: 12, color: t.muted),
                        ),
                      ),
                      for (final cell in row.cells)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                          child: Text(
                            cell
                                .split('/')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .join('\n'),
                            style: cellStyle,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.example, required this.onSay});

  final DictionaryExample example;
  final VoidCallback onSay;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        onTap: onSay,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    example.cz,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    example.en,
                    style: TextStyle(fontSize: 14, color: t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.volume_up_outlined,
              size: 20,
              color: t.pri,
              semanticLabel: l10n.dictionaryListen,
            ),
          ],
        ),
      ),
    );
  }
}
