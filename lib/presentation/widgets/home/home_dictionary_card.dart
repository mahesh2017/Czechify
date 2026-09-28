import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/dictionary/word_of_the_day.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/dictionary_providers.dart';
import '../../providers/tts_providers.dart';
import '../common/lesson_ui.dart';
import '../common/soft_ui.dart';

/// The dictionary on Home: a search bar that opens it, and a word of the day
/// from the units the learner has reached, as a small daily reminder.
class HomeDictionaryCard extends ConsumerWidget {
  const HomeDictionaryCard({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final dictionary = ref.watch(dictionaryProvider(level)).value;
    final unlocked = ref.watch(unlockedUnitIdsProvider).value ?? const <int>{};
    final word =
        dictionary == null
            ? null
            : wordOfTheDay(dictionary, unlocked, DateTime.now());
    final example = word?.examples.firstOrNull;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Looks like the search field it opens, so its job is obvious.
          Semantics(
            button: true,
            label: l10n.homeDictionarySearch,
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('home-dictionary-search'),
              onTap: () => context.push('/dictionary'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                // A 48pt target, like every other control on Home.
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: t.elev,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: t.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.homeDictionarySearch,
                        style: TextStyle(fontSize: 15, color: t.muted),
                      ),
                    ),
                    Icon(Icons.menu_book_rounded, size: 18, color: t.pri),
                  ],
                ),
              ),
            ),
          ),
          if (dictionary != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.homeDictionaryCount(
                dictionary.entries.length,
                dictionary.level,
              ),
              style: TextStyle(fontSize: 12, color: t.faint),
            ),
          ],
          if (word != null) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: t.line),
            const SizedBox(height: 12),
            Text(
              l10n.homeWordOfTheDay,
              style: TextStyle(
                color: t.priInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('home-word-of-the-day'),
                    onTap: () => context.push('/dictionary/$level/${word.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DisplayText(
                            word.cz,
                            size: 24,
                            weight: FontWeight.w800,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            word.meanings.join('; '),
                            style: TextStyle(fontSize: 14, color: t.muted),
                          ),
                          if (example != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              example.cz,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                            Text(
                              example.en,
                              style: TextStyle(fontSize: 13, color: t.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: Icons.volume_up_rounded,
                  tooltip: l10n.dictionaryListen,
                  onTap: () => ref.read(czechTtsProvider).speak(word.cz),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
