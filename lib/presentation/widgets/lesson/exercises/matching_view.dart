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

  Color _pairColor(int pairIdx) {
    const colors = [
      Color(0xFF6366F1), // indigo
      Color(0xFFEC4899), // pink
      Color(0xFF10B981), // emerald
      Color(0xFFF59E0B), // amber
      Color(0xFF8B5CF6), // violet
      Color(0xFF06B6D4), // cyan
      Color(0xFFF97316), // orange
      Color(0xFF84CC16), // lime
    ];
    return colors[pairIdx % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final promptEn = widget.exercise.data['prompt_en'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prompt
          Text(
            promptEn ?? widget.exercise.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a Czech word, then tap its English match.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

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
                  '$_matchedCount/${_leftItems.length} matched',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isCorrect
                            ? '✓ All correct!'
                            : '✗ Some pairs are wrong — try again',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color:
                              _isCorrect
                                  ? context.tokens.green
                                  : context.tokens.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!_isCorrect) ...[
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: _tryAgain,
                          child: Text(AppLocalizations.of(context).tryAgain),
                        ),
                      ],
                    ],
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
        final item = items[i];
        final isSelected = side == _Side.left && _selectedLeftIdx == i;

        Color? borderColor;
        Color? bgColor;
        if (item.matched) {
          final c = _pairColor(item.pairIdx);
          borderColor = c;
          bgColor = c.withValues(alpha: 0.12);
        } else if (isSelected) {
          borderColor = Theme.of(context).colorScheme.primary;
          bgColor = Theme.of(context).colorScheme.primaryContainer;
        }

        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color:
                  bgColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor ?? context.tokens.line,
                width: isSelected ? 2 : (item.matched ? 2 : 1),
              ),
            ),
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: item.matched ? FontWeight.w600 : FontWeight.normal,
                color: item.matched ? _pairColor(item.pairIdx) : null,
              ),
              textAlign: TextAlign.center,
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
