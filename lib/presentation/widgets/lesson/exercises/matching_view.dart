import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import 'exercise_shared.dart';

/// Matching exercise — pair Czech items with their English equivalents
/// by tapping matching pairs in two columns.
class MatchingView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const MatchingView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<MatchingView> createState() => _MatchingViewState();
}

class _MatchingViewState extends State<MatchingView> {
  late final List<_MatchItem> _leftItems;
  late final List<_MatchItem> _rightItems;
  final Random _random = Random();
  int? _selectedLeftIdx;
  bool answered = false;

  @override
  void initState() {
    super.initState();
    final data = widget.exercise.data;
    final rawPairs = data['pairs'] as List<dynamic>? ?? [];

    // Normalise: support both {left, right} and {cz, en} key shapes.
    final pairs =
        rawPairs.map((p) {
          final m = p as Map<String, dynamic>;
          final left = (m['left'] ?? m['cz'] ?? '') as String;
          final right = (m['right'] ?? m['en'] ?? '') as String;
          return (left, right);
        }).toList();

    final leftShuffle = List.generate(pairs.length, (i) => i);
    leftShuffle.shuffle(_random);
    final rightShuffle = List.generate(pairs.length, (i) => i);
    rightShuffle.shuffle(_random);

    _leftItems =
        pairs.asMap().entries.map((e) {
          return _MatchItem(text: e.value.$1, pairIdx: e.key);
        }).toList();
    _leftItems.sort(
      (a, b) => leftShuffle
          .indexOf(a.pairIdx)
          .compareTo(leftShuffle.indexOf(b.pairIdx)),
    );

    _rightItems =
        pairs.asMap().entries.map((e) {
          return _MatchItem(text: e.value.$2, pairIdx: e.key);
        }).toList();
    _rightItems.sort(
      (a, b) => rightShuffle
          .indexOf(a.pairIdx)
          .compareTo(rightShuffle.indexOf(b.pairIdx)),
    );
  }

  bool get _allMatched =>
      _leftItems.every((i) => i.matched) && _rightItems.every((i) => i.matched);

  bool get _isCorrect =>
      _leftItems.every((i) => i.pairIdx == _rightItems[i.matchedTo].pairIdx);

  int get _matchedCount => _leftItems.where((i) => i.matched).length;

  void _onLeftTap(int idx) {
    if (answered) return;
    final item = _leftItems[idx];
    if (item.matched) {
      // Un-match: tap a matched left item to break the pair
      final partnerIdx = item.matchedTo;
      setState(() {
        item.matched = false;
        item.matchedTo = -1;
        _rightItems[partnerIdx].matched = false;
        _rightItems[partnerIdx].matchedTo = -1;
      });
      return;
    }
    setState(() => _selectedLeftIdx = idx);
  }

  void _onRightTap(int idx) {
    if (answered || _selectedLeftIdx == null) return;
    final leftItem = _leftItems[_selectedLeftIdx!];
    final rightItem = _rightItems[idx];
    if (leftItem.matched || rightItem.matched) return;

    setState(() {
      leftItem.matched = true;
      leftItem.matchedTo = idx;
      rightItem.matched = true;
      rightItem.matchedTo = _selectedLeftIdx!;
      _selectedLeftIdx = null;
    });

    // Auto-submit when all pairs are matched.
    if (_allMatched) {
      _submit();
    }
  }

  void _submit() {
    final data = widget.exercise.data;
    final correct = _leftItems.every(
      (i) => i.pairIdx == _rightItems[i.matchedTo].pairIdx,
    );
    final explanation = data['explanation'] as String?;
    final answerKey = widget.exercise.answerKey;

    setState(() => answered = true);

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correct,
        explanation: explanation,
        correctAnswer: answerKey,
      ),
    );
  }

  void _tryAgain() {
    setState(() {
      answered = false;
      _selectedLeftIdx = null;
      for (final item in _leftItems) {
        item.matched = false;
        item.matchedTo = -1;
      }
      for (final item in _rightItems) {
        item.matched = false;
        item.matchedTo = -1;
      }
    });
  }

  /// Which pair number a matched item belongs to, in the order the learner
  /// made the matches.
  ///
  /// Pair identity used to be carried by eight arbitrary hues, which says
  /// nothing in this palette and fails for anyone who cannot separate them.
  /// A number is legible, countable and colour-independent.
  int _pairBadge(_MatchItem item, List<_MatchItem> left) {
    final order = <int>[];
    for (final l in left) {
      if (l.matched && !order.contains(l.pairIdx)) order.add(l.pairIdx);
    }
    return order.indexOf(item.pairIdx) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final promptEn = widget.exercise.data['prompt_en'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: promptEn ?? widget.exercise.prompt),
          const SizedBox(height: 8),
          Text(
            l10n.exerciseTapCzechThenEnglish,
            style: TextStyle(fontSize: 14, height: 1.4, color: t.muted),
          ),
          const SizedBox(height: 18),

          // Two-column matching area
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column (Czech)
                Expanded(
                  child: _buildColumn(
                    items: _leftItems,
                    side: _Side.left,
                    onTap: _onLeftTap,
                  ),
                ),
                const SizedBox(width: 8),
                // Right column (English)
                Expanded(
                  child: _buildColumn(
                    items: _rightItems,
                    side: _Side.right,
                    onTap: _onRightTap,
                  ),
                ),
              ],
            ),
          ),

          // Progress + submit
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.exerciseMatchedOfTotal(_matchedCount, _leftItems.length),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.muted,
                  ),
                ),
                if (_allMatched && !answered)
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: kRowButtonMinSize,
                    ),
                    child: Text(AppLocalizations.of(context).check),
                  ),
                if (answered)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCorrect ? Icons.check_circle : Icons.cancel,
                          size: 18,
                          color: _isCorrect ? t.greenInk : t.redInk,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _isCorrect
                                ? l10n.exerciseAllCorrect
                                : l10n.exerciseSomePairsWrong,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _isCorrect ? t.greenInk : t.redInk,
                            ),
                          ),
                        ),
                        if (!_isCorrect) ...[
                          const SizedBox(width: 10),
                          FilledButton.tonal(
                            onPressed: _tryAgain,
                            style: FilledButton.styleFrom(
                              minimumSize: kRowButtonMinSize,
                            ),
                            child: Text(AppLocalizations.of(context).tryAgain),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn({
    required List<_MatchItem> items,
    required _Side side,
    required void Function(int) onTap,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = context.tokens;
        final item = items[i];
        final isSelected = side == _Side.left && _selectedLeftIdx == i;
        final instant = MediaQuery.disableAnimationsOf(context);

        final (bg, border, fg) = switch ((item.matched, isSelected)) {
          (true, _) => (t.priSoft, t.pri, t.priInk),
          (_, true) => (t.priSoft, t.pri, t.priInk),
          _ => (t.card, t.line, t.ink),
        };

        return Semantics(
          button: true,
          selected: isSelected || item.matched,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration:
                    instant ? Duration.zero : const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: border,
                    width: isSelected || item.matched ? 1.5 : 1,
                  ),
                  boxShadow: item.matched || isSelected ? null : t.shadow,
                ),
                child: Row(
                  children: [
                    // The pair number is the match, so both halves of a pair
                    // carry the same badge.
                    if (item.matched)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.pri,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_pairBadge(item, _leftItems)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: t.onFill,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              item.matched ? FontWeight.w700 : FontWeight.w600,
                          height: 1.3,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _Side { left, right }

class _MatchItem {
  final String text;
  final int pairIdx;
  bool matched;
  int matchedTo; // index in the other column

  _MatchItem({required this.text, required this.pairIdx})
    : matched = false,
      matchedTo = -1;
}
