import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/flashcard.dart';
import 'curriculum_providers.dart';
import 'database_providers.dart';

class CopybookItem {
  const CopybookItem({
    required this.id,
    required this.czech,
    required this.english,
    required this.example,
  });

  final int id;
  final String czech;
  final String english;
  final String example;
}

/// Four deterministic, writable items from curriculum the learner can access.
final dailyCopybookProvider = FutureProvider<List<CopybookItem>>((ref) async {
  final unlocked = await ref.watch(unlockedUnitIdsProvider.future);
  final repository = ref.read(vocabularyRepositoryProvider);
  final cards = <Flashcard>[];
  for (final unitId in unlocked.toList()..sort()) {
    cards.addAll(await repository.getCardsForUnit(unitId));
  }

  final suitable = <Flashcard>[];
  final seen = <String>{};
  for (final card in cards) {
    final word = card.wordCz.trim();
    if (word.isEmpty ||
        word.length > 24 ||
        word.split(RegExp(r'\s+')).length > 2 ||
        !RegExp(r'[A-Za-zÁ-ž]').hasMatch(word) ||
        !seen.add(word.toLowerCase())) {
      continue;
    }
    suitable.add(card);
  }
  suitable.sort((a, b) => a.id.compareTo(b.id));
  if (suitable.isEmpty) return const [];

  final now = DateTime.now();
  final day =
      DateTime(now.year, now.month, now.day).difference(DateTime(2024)).inDays;
  final start = day % suitable.length;
  return [
    for (var offset = 0; offset < 4 && offset < suitable.length; offset++)
      (() {
        final card = suitable[(start + offset) % suitable.length];
        return CopybookItem(
          id: card.id,
          czech: card.wordCz,
          english: card.wordEn,
          example:
              card.exampleCz?.trim().isNotEmpty == true
                  ? card.exampleCz!.trim()
                  : 'Napište: ${card.wordCz}.',
        );
      })(),
  ];
});
