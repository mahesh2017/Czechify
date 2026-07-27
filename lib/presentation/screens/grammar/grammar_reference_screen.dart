import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          highlightRuleId != null ? 'Grammar Rule' : 'Grammar Reference',
        ),
      ),
      body: unitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load units')),
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
          ]..sort((a, b) => b.orderIndex.compareTo(a.orderIndex));

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

class _UnitGrammarSection extends ConsumerWidget {
  final Unit unit;
  final String? highlightRuleId;

  const _UnitGrammarSection({required this.unit, this.highlightRuleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final rulesAsync = ref.watch(grammarRulesByUnitProvider(unit.id));

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: ExpansionTile(
        initiallyExpanded: highlightRuleId != null,
        title: Text(
          'Unit ${unit.id}: ${unit.title}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: t.ink,
          ),
        ),
        subtitle: Text(
          unit.grammarTags.join(', '),
          style: TextStyle(fontSize: 13, color: t.muted),
        ),
        children: [
          rulesAsync.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
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
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children:
                      rules.map((rule) {
                        final isHighlighted = highlightRuleId == rule.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isHighlighted ? t.priSoft : t.elev,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                isHighlighted
                                    ? Border.all(color: t.pri, width: 2)
                                    : null,
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
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      rule.id,
                                      style: TextStyle(
                                        fontSize: 11,
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
