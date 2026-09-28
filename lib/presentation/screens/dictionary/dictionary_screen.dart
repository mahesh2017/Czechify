import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/dictionary/dictionary_entry.dart';
import '../../../data/dictionary/dictionary_search.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/dictionary_providers.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/soft_ui.dart';

/// The level's dictionary: every word, A–Z, searchable in Czech (any form,
/// with or without accents) and in English.
///
/// A browsing screen, so it scrolls. Words from units the learner has not
/// reached are listed and open like the rest, marked with the unit.
class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key, this.level});

  /// Which level's dictionary; defaults to the first one there is.
  final String? level;

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  final _query = TextEditingController();
  late String _level = widget.level ?? kDictionaryLevels.first;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(DictionaryEntry entry) {
    FocusScope.of(context).unfocus();
    context.push('/dictionary/$_level/${entry.id}');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(dictionaryProvider(_level));
    final search = ref.watch(dictionarySearchProvider(_level)).value;
    final unlocked = ref.watch(unlockedUnitIdsProvider).value ?? const {};
    final query = _query.text.trim();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.dictionaryTitle,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ),
                  if (kDictionaryLevels.length > 1)
                    for (final level in kDictionaryLevels)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(level.toUpperCase()),
                          selected: level == _level,
                          onSelected: (_) => setState(() => _level = level),
                        ),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: TextField(
                key: const ValueKey('dictionary-search'),
                controller: _query,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 17, color: t.ink),
                decoration: InputDecoration(
                  hintText: l10n.dictionarySearchHint,
                  prefixIcon: Icon(Icons.search_rounded, color: t.muted),
                  suffixIcon:
                      query.isEmpty
                          ? null
                          : IconButton(
                            tooltip: l10n.dictionaryClearSearch,
                            icon: Icon(Icons.close_rounded, color: t.muted),
                            onPressed: _query.clear,
                          ),
                  filled: true,
                  fillColor: t.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: t.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: t.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: t.pri, width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: data.when(
                loading:
                    () => const Center(child: CircularProgressIndicator()),
                error:
                    (_, __) => _Message(
                      title: l10n.dictionaryLoadFailed,
                      icon: Icons.error_outline_rounded,
                    ),
                data: (dictionary) {
                  if (query.isEmpty) {
                    return _Browse(
                      dictionary: dictionary,
                      unlocked: unlocked,
                      onOpen: _open,
                    );
                  }
                  final hits = search?.search(query) ?? const [];
                  if (hits.isEmpty) {
                    return _Message(
                      title: l10n.dictionaryNoResults(query),
                      body: l10n.dictionaryNoResultsHint,
                      icon: Icons.search_off_rounded,
                    );
                  }
                  return ListView.builder(
                    key: const ValueKey('dictionary-results'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: hits.length,
                    itemBuilder:
                        (context, i) => _WordRow(
                          entry: hits[i].entry,
                          matchedForm: hits[i].matchedForm,
                          locked: _isLocked(hits[i].entry, unlocked),
                          onTap: () => _open(hits[i].entry),
                        ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isLocked(DictionaryEntry entry, Set<int> unlocked) =>
    entry.unit != null && !unlocked.contains(entry.unit);

/// Every word A–Z, under letter headings.
class _Browse extends StatelessWidget {
  const _Browse({
    required this.dictionary,
    required this.unlocked,
    required this.onOpen,
  });

  final DictionaryData dictionary;
  final Set<int> unlocked;
  final ValueChanged<DictionaryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    // Headings and words in one list, so the list stays lazy.
    final items = <Object>[];
    String? letter;
    for (final e in dictionary.entries) {
      final first = foldCzech(e.cz).characters.first.toUpperCase();
      if (first != letter) {
        letter = first;
        items.add(first);
      }
      items.add(e);
    }
    return ListView.builder(
      key: const ValueKey('dictionary-browse'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.dictionaryWordCount(
                dictionary.entries.length,
                dictionary.level,
              ),
              style: TextStyle(fontSize: 13, color: t.muted),
            ),
          );
        }
        final item = items[i - 1];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              item,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.pri,
              ),
            ),
          );
        }
        final entry = item as DictionaryEntry;
        return _WordRow(
          entry: entry,
          locked: _isLocked(entry, unlocked),
          onTap: () => onOpen(entry),
        );
      },
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.entry,
    required this.locked,
    required this.onTap,
    this.matchedForm,
  });

  final DictionaryEntry entry;
  final bool locked;
  final VoidCallback onTap;
  final String? matchedForm;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: entry.cz,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        if (matchedForm != null)
                          TextSpan(
                            text: '   ${l10n.dictionaryFormOf(matchedForm!)}',
                            style: TextStyle(fontSize: 13, color: t.pri),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.meanings.join('; '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: t.muted),
                  ),
                ],
              ),
            ),
            if (entry.unit != null) ...[
              const SizedBox(width: 10),
              PillChip(
                label: l10n.dictionaryUnit(entry.unit!),
                icon: locked ? Icons.lock_outline_rounded : null,
                bg: locked ? t.elev : t.priSoft,
                fg: locked ? t.muted : t.priInk,
                bold: false,
                fontSize: 11,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.icon, this.body});

  final String title;
  final String? body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      children: [
        Icon(icon, size: 40, color: t.muted),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.muted, height: 1.4),
          ),
        ],
      ],
    );
  }
}
