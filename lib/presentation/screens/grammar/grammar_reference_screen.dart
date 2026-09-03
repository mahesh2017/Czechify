import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/unit.dart';
import '../../providers/curriculum_providers.dart';

/// Full-screen grammar reference browser.
/// - No highlight: shows a unit-picker then rules per unit.
/// - With highlightRuleId: scrolls to that specific rule.
///
/// Only units the learner has reached are listed, most recent first, so the
/// grammar they are actually working through is at the top rather than buried
/// under every unit in the course. A rule opened by id is always shown, even
/// if its unit is still locked — a direct link should never dead-end.
class GrammarReferenceScreen extends ConsumerWidget {
  final String? highlightRuleId;

  const GrammarReferenceScreen({super.key, this.highlightRuleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(allUnitsProvider);
    final unlockedAsync = ref.watch(unlockedUnitIdsProvider);
    final highlightedRule =
        highlightRuleId == null
            ? null
            : ref.watch(grammarRuleByIdProvider(highlightRuleId!)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          highlightRuleId != null ? 'Grammar Rule' : 'Grammar Reference',
        ),
      ),
      body: unitsAsync.when(
        loading:
            () => Center(
              child:
                  context.motionDisabled
                      ? Icon(
                        Icons.hourglass_top_rounded,
                        color: context.tokens.muted,
                      )
                      : const CircularProgressIndicator(),
            ),
        error:
            (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Grammar reference will be available after the first lesson.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (allUnits) {
          // Falling back to every unit while access is loading or errored is
          // deliberate: showing too much reference material is a far smaller
          // failure than hiding the grammar for the unit they are on.
          final unlocked = unlockedAsync.asData?.value;
          final visible = [
            for (final unit in allUnits)
              if (highlightRuleId != null ||
                  unlocked == null ||
                  unlocked.contains(unit.id))
                unit,
          ]..sort((a, b) {
            final targetUnitId = highlightedRule?.unitId;
            if (a.id == targetUnitId) return -1;
            if (b.id == targetUnitId) return 1;
            return b.orderIndex.compareTo(a.orderIndex);
          });

          if (visible.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Grammar notes appear here as you reach each unit.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final unit in visible) ...[
                _UnitGrammarSection(
                  unit: unit,
                  highlightRuleId: highlightRuleId,
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UnitGrammarSection extends ConsumerStatefulWidget {
  final Unit unit;
  final String? highlightRuleId;

  const _UnitGrammarSection({required this.unit, this.highlightRuleId});

  @override
  ConsumerState<_UnitGrammarSection> createState() =>
      _UnitGrammarSectionState();
}

class _UnitGrammarSectionState extends ConsumerState<_UnitGrammarSection> {
  final _expansionController = ExpansibleController();
  final _highlightKey = GlobalKey();
  bool _highlightRevealScheduled = false;

  @override
  void didUpdateWidget(covariant _UnitGrammarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightRuleId != widget.highlightRuleId) {
      _highlightRevealScheduled = false;
    }
  }

  void _scheduleHighlightReveal() {
    if (_highlightRevealScheduled) return;
    _highlightRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _expansionController.expand();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final target = _highlightKey.currentContext;
      if (target == null || !target.mounted) return;
      await Scrollable.ensureVisible(
        target,
        alignment: .22,
        duration: context.motionDuration(AppMotion.reveal),
        curve: AppMotion.enter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rulesAsync = ref.watch(grammarRulesByUnitProvider(widget.unit.id));

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: ExpansionTile(
        controller: _expansionController,
        expansionAnimationStyle: AnimationStyle(
          duration: context.motionDuration(AppMotion.content),
          curve: AppMotion.enter,
          reverseDuration: context.motionDuration(AppMotion.selection),
          reverseCurve: AppMotion.exit,
        ),
        title: Text(
          'Unit ${widget.unit.id}: ${widget.unit.title}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: t.ink,
          ),
        ),
        subtitle: Text(
          widget.unit.grammarTags.join(', '),
          style: TextStyle(fontSize: 13, color: t.muted),
        ),
        children: [
          rulesAsync.when(
            loading:
                () => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child:
                        context.motionDisabled
                            ? Icon(Icons.hourglass_top_rounded, color: t.muted)
                            : const CircularProgressIndicator(),
                  ),
                ),
            error:
                (_, __) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load grammar rules.',
                    style: TextStyle(color: t.muted),
                  ),
                ),
            data: (rules) {
              if (rules.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No grammar rules for this unit.',
                    style: TextStyle(color: t.muted),
                  ),
                );
              }
              if (widget.highlightRuleId != null &&
                  rules.any((rule) => rule.id == widget.highlightRuleId)) {
                _scheduleHighlightReveal();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children:
                      rules.map((rule) {
                        final isHighlighted = widget.highlightRuleId == rule.id;
                        return TweenAnimationBuilder<double>(
                          key:
                              isHighlighted ? _highlightKey : ValueKey(rule.id),
                          tween: Tween(begin: 0, end: 1),
                          duration:
                              isHighlighted
                                  ? context.motionDuration(AppMotion.reward)
                                  : Duration.zero,
                          curve: AppMotion.enter,
                          builder:
                              (context, emphasis, child) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      isHighlighted
                                          ? Color.lerp(
                                            t.priFill,
                                            t.priSoft,
                                            emphasis,
                                          )
                                          : t.elev,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      isHighlighted
                                          ? Border.all(
                                            color: t.pri,
                                            width: 2 + (1 - emphasis),
                                          )
                                          : null,
                                  boxShadow:
                                      isHighlighted && emphasis < 1
                                          ? [
                                            BoxShadow(
                                              color: t.pri.withValues(
                                                alpha: .22 * (1 - emphasis),
                                              ),
                                              blurRadius: 18 * (1 - emphasis),
                                              spreadRadius: 3 * (1 - emphasis),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: child,
                              ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.priFill,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      rule.id,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: t.onFill,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rule.ruleName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: t.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                rule.pattern,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: t.pri,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                rule.explanation,
                                style: TextStyle(fontSize: 14, color: t.muted),
                              ),
                              // Examples
                              ..._parseExamples(rule.examples, t),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _parseExamples(String examplesJson, AppTokens t) {
    try {
      final examples = jsonDecode(examplesJson) as List<dynamic>;
      return examples.take(2).map((ex) {
        final exMap = ex as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_right, size: 16, color: t.faint),
              const SizedBox(width: 4),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: t.ink),
                    children: [
                      TextSpan(
                        text: '${exMap['cz']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' — ${exMap['en']}',
                        style: TextStyle(color: t.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
