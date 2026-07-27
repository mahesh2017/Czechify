import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../../core/theme/app_tokens.dart';
import '../../providers/curriculum_providers.dart';

/// Screen for quick-reference content: cheat sheets, declension tables,
/// conjugation tables.
///
/// Cheat sheets are per-unit, so they follow the same rule as the grammar
/// reference: only units the learner has reached, most recent first. The
/// declension and conjugation tables are not unit-scoped and are shown whole.
class QuickReferenceScreen extends ConsumerStatefulWidget {
  /// Which reference type to show: 'cheat_sheets', 'declension_tables',
  /// or 'conjugation_tables'.
  final String type;

  const QuickReferenceScreen({super.key, required this.type});

  @override
  ConsumerState<QuickReferenceScreen> createState() =>
      _QuickReferenceScreenState();
}

class _QuickReferenceScreenState extends ConsumerState<QuickReferenceScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _assetPath => 'assets/curriculum/${widget.type}.json';

  String get _title {
    switch (widget.type) {
      case 'cheat_sheets':
        return 'Cheat Sheets';
      case 'declension_tables':
        return 'Declension Tables';
      case 'conjugation_tables':
        return 'Conjugation Tables';
      default:
        return 'Reference';
    }
  }

  Future<void> _load() async {
    try {
      final json = await rootBundle.loadString(_assetPath);
      setState(() => _data = jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(appBar: AppBar(title: Text(_title)), body: _buildBody(t));
  }

  Widget _buildBody(AppTokens t) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: t.red),
              const SizedBox(height: 16),
              Text('Could not load $_title.', style: TextStyle(color: t.muted)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.type == 'cheat_sheets') {
      return _buildCheatSheets(t);
    } else if (widget.type == 'conjugation_tables') {
      return _buildConjugationTables(t);
    } else {
      return _buildDeclensionTables(t);
    }
  }

  Widget _buildCheatSheets(AppTokens t) {
    final all = _data!['cheat_sheets'] as List<dynamic>? ?? [];
    final unlocked = ref.watch(unlockedUnitIdsProvider).asData?.value;

    // Same rule as the grammar reference. Falling back to everything while
    // access is loading is deliberate: showing extra reference material is a
    // much smaller failure than hiding the sheet for the unit being studied.
    final sheets = [
      for (final sheet in all)
        if (unlocked == null ||
            unlocked.contains((sheet as Map<String, dynamic>)['unit_id']))
          sheet,
    ]..sort((a, b) {
      final left = (a as Map<String, dynamic>)['unit_id'] as int? ?? 0;
      final right = (b as Map<String, dynamic>)['unit_id'] as int? ?? 0;
      return right.compareTo(left);
    });

    if (sheets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Cheat sheets appear here as you reach each unit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: t.muted),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sheets.length,
      itemBuilder: (context, i) {
        final sheet = sheets[i] as Map<String, dynamic>;
        final unitId = sheet['unit_id'];
        final title = sheet['title'] as String? ?? '';
        final description = sheet['description'] as String? ?? '';
        final grammarRules = (sheet['grammar_rules'] as List<dynamic>?) ?? [];
        final coreVocab = (sheet['core_vocabulary'] as List<dynamic>?) ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: t.card,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: t.line),
            ),
            child: ExpansionTile(
              title: Text(
                'Unit $unitId: $title',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: t.ink,
                ),
              ),
              subtitle: Text(
                description,
                style: TextStyle(fontSize: 13, color: t.muted),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (grammarRules.isNotEmpty) ...[
                        Text(
                          'Grammar Rules',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: t.pri,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...grammarRules.take(5).map((r) {
                          final rule = r as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.arrow_right,
                                  size: 14,
                                  color: t.faint,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: t.ink,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${rule['name']}: ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${rule['pattern']}',
                                          style: TextStyle(color: t.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (coreVocab.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Key Vocabulary',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: t.pri,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...coreVocab.take(8).map((v) {
                          final vocab = v as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${vocab['cz']} — ${vocab['en']}',
                              style: TextStyle(fontSize: 13, color: t.ink),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Czech case order for declension rows (asset provides it top-level, with
  /// a fallback to the canonical school order).
  List<String> get _caseOrder =>
      (_data!['cases'] as List<dynamic>?)?.cast<String>() ??
      const [
        'nominative',
        'genitive',
        'dative',
        'accusative',
        'vocative',
        'locative',
        'instrumental',
      ];

  Widget _buildDeclensionTables(AppTokens t) {
    final tables = _data!['tables'] as List<dynamic>? ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      itemBuilder: (context, i) {
        final table = tables[i] as Map<String, dynamic>;
        final title = table['title'] as String? ?? '';
        final patternWord = table['pattern_word'] as String? ?? '';
        final singular = table['singular'] as Map<String, dynamic>? ?? {};
        final plural = table['plural'] as Map<String, dynamic>? ?? {};
        final notes = table['notes'] as String? ?? '';
        final exampleWords =
            (table['example_words'] as List<dynamic>?)?.cast<String>() ?? [];

        String cell(Map<String, dynamic> forms, String caseName) {
          final entry = forms[caseName] as Map<String, dynamic>?;
          if (entry == null) return '—';
          final form = entry['form'] as String? ?? '—';
          final ending = entry['ending'] as String? ?? '';
          return ending.isEmpty || ending == '—' ? form : '$form ($ending)';
        }

        return _referenceCard(
          t,
          title: title,
          subtitle: patternWord.isEmpty ? null : 'pattern: $patternWord',
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: [
                  DataColumn(label: _headerText(t, 'Case')),
                  DataColumn(label: _headerText(t, 'Singular')),
                  DataColumn(label: _headerText(t, 'Plural')),
                ],
                rows: [
                  for (final caseName in _caseOrder)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            // "nominative" → "Nom."
                            '${caseName[0].toUpperCase()}${caseName.substring(1, 3)}.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.muted,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            cell(singular, caseName),
                            style: TextStyle(fontSize: 13, color: t.ink),
                          ),
                        ),
                        DataCell(
                          Text(
                            cell(plural, caseName),
                            style: TextStyle(fontSize: 13, color: t.ink),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (exampleWords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    exampleWords
                        .map(
                          (w) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t.pri.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              w,
                              style: TextStyle(fontSize: 12, color: t.pri),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                notes,
                style: TextStyle(
                  fontSize: 12.5,
                  color: t.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildConjugationTables(AppTokens t) {
    final tables = _data!['tables'] as List<dynamic>? ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      itemBuilder: (context, i) {
        final table = tables[i] as Map<String, dynamic>;
        final verb = table['verb'] as String? ?? '';
        final meaning = table['meaning'] as String? ?? '';
        final tense = table['tense'] as String? ?? '';
        final aspect = table['aspect'] as String? ?? '';
        final conjugation = table['conjugation'] as Map<String, dynamic>? ?? {};
        final notes = table['notes'] as String? ?? '';
        final example = table['example'] as Map<String, dynamic>?;

        return _referenceCard(
          t,
          title: tense.isEmpty ? verb : '$verb — $tense',
          subtitle: [
            if (meaning.isNotEmpty) meaning,
            if (aspect.isNotEmpty) aspect,
          ].join(' · '),
          children: [
            Table(
              columnWidths: const {0: IntrinsicColumnWidth()},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children:
                  conjugation.entries
                      .map(
                        (entry) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 16,
                                bottom: 6,
                              ),
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: t.muted,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${entry.value}',
                                style: TextStyle(fontSize: 14, color: t.ink),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
            ),
            if (example != null) ...[
              const SizedBox(height: 8),
              Text(
                '${example['cz']}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: t.pri,
                ),
              ),
              Text(
                '${example['en']}',
                style: TextStyle(fontSize: 12.5, color: t.muted),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: TextStyle(
                  fontSize: 12.5,
                  color: t.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Shared expandable card chrome for reference entries.
  Widget _referenceCard(
    AppTokens t, {
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      // Material (not a decorated Container) so the tile's ink splashes and
      // background render correctly.
      child: Material(
        color: t.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.line),
        ),
        child: ExpansionTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: t.ink,
            ),
          ),
          subtitle:
              subtitle == null || subtitle.isEmpty
                  ? null
                  : Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: t.muted),
                  ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Text _headerText(AppTokens t, String label) => Text(
    label,
    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: t.pri),
  );
}
