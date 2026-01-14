import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

class SensoryProfileResult extends StatefulWidget {
  final int assessmentId;

  const SensoryProfileResult({super.key, required this.assessmentId});

  @override
  State<SensoryProfileResult> createState() => _SensoryProfileResultState();
}

class _SensoryProfileResultState extends State<SensoryProfileResult> {
  bool isLoading = true;

  /// Payload penuh dari API get_sensory_result.php
  Map<String, dynamic> resultData = {};

  /// Shorthand untuk results blob
  Map<String, dynamic> get results => (resultData['results'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get categorySummary => (results['category_raw_score'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get quadrantSummary => (results['quadrant_raw_score'] as Map?)?.cast<String, dynamic>() ?? {};

  @override
  void initState() {
    super.initState();
    fetchResultData();
  }

  Future<void> fetchResultData() async {
    try {
      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter_growcheck_parents/get_sensory_result.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'assessment_id': widget.assessmentId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          resultData = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // =================== UTIL & PARSERS ===================

  String _readStr(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) {
        final v = m[k];
        if (v is String) return v;
        return v.toString();
      }
    }
    return '';
  }

  num? _readNum(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) {
        final v = m[k];
        if (v is num) return v;
        if (v is String) {
          final p = num.tryParse(v);
          if (p != null) return p;
        }
      }
    }
    return null;
  }

  /// answers boleh berada di results.answers atau di root.answers
  List<Map<String, dynamic>> _extractAnswers(Map<String, dynamic> data) {
    final res = (data['results'] is Map) ? Map<String, dynamic>.from(data['results']) : const <String, dynamic>{};
    final raw = (res['answers'] is List)
        ? res['answers']
        : (data['answers'] is List)
            ? data['answers']
            : const [];

    final out = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final it in raw) {
        if (it is Map) out.add(it.cast<String, dynamic>());
      }
    }
    return out;
  }

  /// Group by category (follow categorySummary order first, then leftovers)
  Map<String, List<Map<String, dynamic>>> _groupAnswersByCategory(
    List<Map<String, dynamic>> answers,
    Map<String, dynamic> categorySummary,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final a in answers) {
      final cat = _readStr(a, ['category', 'category_name', 'cat', 'section']).trim();
      final key = cat.isEmpty ? 'Uncategorized' : cat;
      (grouped[key] ??= []).add(a);
    }

    // Sort within each category by question id if available
    for (final entry in grouped.entries) {
      entry.value.sort((x, y) {
        final xi = _readNum(x, ['question_id', 'qid', 'id']) ?? 0;
        final yi = _readNum(y, ['question_id', 'qid', 'id']) ?? 0;
        return xi.compareTo(yi);
      });
    }

    // Reorder categories: those in categorySummary first (by alpha), then leftovers (alpha)
    final ordered = <String, List<Map<String, dynamic>>>{};
    final summaryKeys = categorySummary.keys.map((e) => e.toString()).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final k in summaryKeys) {
      if (grouped.containsKey(k)) {
        ordered[k] = grouped.remove(k)!;
      }
    }

    final leftover = grouped.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final k in leftover) {
      ordered[k] = grouped[k]!;
    }
    return ordered;
  }

  // =================== UI SECTIONS ===================

  Widget buildSummaryCard() {
    final rawDate = resultData['assessment_date'] ?? '';
    String formattedDate = '';
    try {
      final date = DateTime.parse(rawDate.toString());
      formattedDate = DateFormat('d MMM y').format(date);
    } catch (_) {
      formattedDate = rawDate.toString();
    }

    return Container(
      margin: EdgeInsets.only(right: 2.w, bottom: 2.h),
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purple,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: GrowkidsPastel.purple,
            child: const Icon(Icons.calendar_today, color: Growkids.purple),
          ),
          SizedBox(width: 3.w),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          Text(formattedDate, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 1.h, bottom: 0.8.h),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Color _badgeColor(bool needsAttention) =>
      needsAttention ? Colors.red.withOpacity(0.12) : Growkids.purple.withOpacity(0.1);

  Color _badgeTextColor(bool needsAttention) => needsAttention ? Colors.red : Growkids.purple;

  Widget _chip(String text, {bool subtle = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: subtle ? Colors.black.withOpacity(0.05) : Growkids.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: subtle ? Colors.black87 : Growkids.purple,
        ),
      ),
    );
  }

  Widget _scorePill(num score) {
    final isInt = score == score.roundToDouble();
    final text = isInt ? score.toInt().toString() : score.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Growkids.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Growkids.purple.withOpacity(0.35)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Growkids.purple)),
    );
  }

  Widget buildCategoryCards() {
    if (categorySummary.isEmpty) return const SizedBox.shrink();

    final entries = categorySummary.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Category Breakdown'),
        ...entries.map((e) {
          final name = e.key;
          final v = (e.value as Map).cast<String, dynamic>();
          final total = v['total'] ?? 0;
          final count = v['count'] ?? 0;
          final band = (v['band'] ?? '').toString();
          final needs = (v['needs_attention'] == true);

          return Container(
            margin: EdgeInsets.only(bottom: 1.2.h),
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Growkids.purple.withOpacity(0.25)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                // Left: title + band
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 0.4.h),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _badgeColor(needs),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          band.isEmpty ? '-' : band,
                          style: TextStyle(
                            color: _badgeTextColor(needs),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: total + count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _chip('Total: $total'),
                    SizedBox(height: 0.4.h),
                    _chip('Items: $count', subtle: true),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Tunjuk quadrant untuk setiap soalan hanya jika wujud & bukan "No Quadrant"
  String _formatQuadrantLabel(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    if (s.toLowerCase() == 'no quadrant') return '';

    final l = s.toLowerCase();
    if (l.startsWith('sk')) return 'Seeking';
    if (l.startsWith('av')) return 'Avoiding/Avoider';
    if (l.startsWith('sn')) return 'Sensitivity/Sensor';
    if (l.startsWith('rg')) return 'Registration/Bystander';
    return s; // fallback label DB
  }

  Widget buildQuadrantCards() {
    if (quadrantSummary.isEmpty) return const SizedBox.shrink();

    final entries = quadrantSummary.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Quadrant Analysis'),
        ...entries.map((e) {
          final name = e.key;
          final v = (e.value as Map).cast<String, dynamic>();
          final total = v['total'] ?? 0;
          final count = v['count'] ?? 0;
          final band = (v['band'] ?? '').toString();
          final def = (v['definition'] ?? '').toString();
          final needs = (v['needs_attention'] == true);

          return Container(
            margin: EdgeInsets.only(bottom: 1.2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Growkids.purple.withOpacity(0.25)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: ListTile(
              title: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    width: 50.w,
                    padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: _badgeColor(needs),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      band.isEmpty ? '-' : band,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _badgeTextColor(needs),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (def.isNotEmpty) Text(def),
                    SizedBox(height: 0.6.h),
                    Row(
                      children: [
                        _chip('Score: $total'),
                        SizedBox(width: 1.w),
                        _chip('Items: $count', subtle: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// NEW: Questions grouped by Category, each with its numeric score
  Widget buildQuestionsByCategory() {
    final answers = _extractAnswers(resultData);
    if (answers.isEmpty) return const SizedBox.shrink();

    final grouped = _groupAnswersByCategory(answers, categorySummary);
    if (grouped.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Questions by Category'),
        ...grouped.entries.map((entry) {
          final cat = entry.key;
          final items = entry.value;

          return Container(
            margin: EdgeInsets.only(bottom: 1.2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Theme(
              data: ThemeData().copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: 2.2.h, vertical: 0.6.h),
                childrenPadding: EdgeInsets.fromLTRB(2.2.h, 0, 2.2.h, 1.6.h),
                title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${items.length} item(s)'),
                initiallyExpanded: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                children: items.map((q) {
                  final qText = _readStr(q, ['question_text', 'question', 'text', 'q']).trim();
                  final score = _readNum(q, ['value', 'score', 'points', 'selected', 'selected_score']) ?? 0;
                  final quadRaw = _readStr(q, ['quadrant', 'quadrant_name', 'quad']).trim();
                  final quad = _formatQuadrantLabel(quadRaw);
                  final isRev = (_readNum(q, ['reverse', 'is_reverse']) ?? 0) == 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question text
                        Text(
                          qText.isEmpty ? '—' : qText,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        // Score + optional quadrant/reverse flags
                        Row(
                          children: [
                            _scorePill(score),
                            if (quad.isNotEmpty) ...[
                              SizedBox(width: 8),
                              _chip(quad, subtle: true),
                            ],
                            if (isRev) ...[
                              SizedBox(width: 8),
                              const Text('(Reverse scored)',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  // =================== BUILD ===================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Sensory Result', style: TextStyle(color: Growkids.purple)),
        centerTitle: true,
        leading: const BackButton(color: Growkids.purple),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/bg-home.jpg'),
                  fit: BoxFit.fill,
                  colorFilter: ColorFilter.mode(Growkids.purple, BlendMode.color),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSummaryCard(),

                    // 1) Quadrant dulu
                    buildQuadrantCards(),
                    SizedBox(height: 1.5.h),

                    // 2) Lepas tu Category
                    buildCategoryCards(),
                    SizedBox(height: 1.5.h),

                    // 3) Questions grouped by Category (NEW)
                    buildQuestionsByCategory(),

                    SizedBox(height: 5.h),
                  ],
                ),
              ),
            ),
    );
  }
}
