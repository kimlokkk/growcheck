import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

class SensoryResultDesktop extends StatelessWidget {
  final String studentName;
  final String assessmentDate;
  final String age;
  final String totalScore;
  final String totalBand;
  final Map<String, dynamic> quadrantSummary;
  final Map<String, dynamic> categorySummary;
  final Map<String, List<Map<String, dynamic>>> groupedAnswers;

  const SensoryResultDesktop({
    super.key,
    required this.studentName,
    required this.assessmentDate,
    required this.age,
    required this.totalScore,
    required this.totalBand,
    required this.quadrantSummary,
    required this.categorySummary,
    required this.groupedAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F5FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 420, child: _overviewColumn()),
                    const SizedBox(width: 20),
                    Expanded(child: _answersPanel()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final initial = studentName.trim().isEmpty
        ? '?'
        : studentName.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x253F2A91),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Growkids.purple,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SENSORY ASSESSMENT RESULT',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _headerDetail(
                        Icons.calendar_today_outlined, assessmentDate),
                    if (age != '-' && age.trim().isNotEmpty)
                      _headerDetail(Icons.cake_outlined, '$age months'),
                  ],
                ),
              ],
            ),
          ),
          if (totalScore != '0' || totalBand.trim().isNotEmpty)
            Container(
              constraints: const BoxConstraints(minWidth: 160),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL SCORE',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalScore,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (totalBand.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      totalBand,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xD9FFFFFF)),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _overviewColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quadrantSummary.isNotEmpty) ...[
          _summaryPanel('Quadrant overview', quadrantSummary),
          const SizedBox(height: 20),
        ],
        _summaryPanel('Category summary', categorySummary),
      ],
    );
  }

  Widget _summaryPanel(String title, Map<String, dynamic> summary) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF202331),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${summary.length} result ${summary.length == 1 ? 'group' : 'groups'}',
            style: const TextStyle(color: Color(0xFF858A99), fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (summary.isEmpty)
            const _DesktopEmpty(message: 'Summary is not available.')
          else
            ...summary.entries.map((entry) {
              final data = entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : <String, dynamic>{};
              final band = (data['band'] ?? '-').toString();
              final score = data['total'] ?? data['score'] ?? 0;
              final count = data['count'];
              final color = _bandColor(band, data['needs_attention'] == true);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7E9F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: Color(0xFF303341),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _badge(band, color),
                              if (count != null)
                                _badge('$count items', const Color(0xFF727787)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Growkids.purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$score',
                        style: const TextStyle(
                          color: Growkids.purple,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _answersPanel() {
    final totalAnswers = groupedAnswers.values.fold<int>(
      0,
      (total, items) => total + items.length,
    );

    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Questions & Answers',
                  style: TextStyle(
                    color: Color(0xFF202331),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _badge('$totalAnswers items', Growkids.purple),
            ],
          ),
          const SizedBox(height: 18),
          if (groupedAnswers.isEmpty)
            const _DesktopEmpty(message: 'No questions are available.')
          else
            ...groupedAnswers.entries.map((entry) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE5E7EE)),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 5,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    title: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Color(0xFF303341),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${entry.value.length} item(s)',
                      style: const TextStyle(
                        color: Color(0xFF858A99),
                        fontSize: 12,
                      ),
                    ),
                    children: entry.value.map(_answerTile).toList(),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _answerTile(Map<String, dynamic> answer) {
    final question = _firstValue(
      answer,
      ['question_text', 'question', 'text', 'q'],
      '-',
    );
    final score = _firstValue(
      answer,
      ['score', 'value', 'points', 'selected', 'selected_score'],
      '0',
    );
    final quadrant = _firstValue(
      answer,
      ['quadrant', 'quadrant_name', 'quad'],
      '',
    );
    final showQuadrant = quadrant.isNotEmpty &&
        quadrant.toLowerCase() != 'no quadrant' &&
        quadrant != '-';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E9F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              question,
              style: const TextStyle(
                color: Color(0xFF424654),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.end,
            children: [
              _badge('Score $score', Growkids.purple),
              if (showQuadrant) _badge(quadrant, const Color(0xFF5D6372)),
            ],
          ),
        ],
      ),
    );
  }

  String _firstValue(
    Map<String, dynamic> source,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  Color _bandColor(String band, bool needsAttention) {
    final value = band.toLowerCase();
    if (needsAttention || value.contains('definite')) return Colors.red;
    if (value.contains('probable')) return Colors.orange;
    if (value.contains('typical')) return Colors.green;
    return Growkids.purple;
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _surface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DesktopEmpty extends StatelessWidget {
  final String message;

  const _DesktopEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF777C8B), fontSize: 13),
      ),
    );
  }
}
