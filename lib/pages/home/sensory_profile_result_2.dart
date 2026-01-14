import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';

class SensoryProfileResult2 extends StatefulWidget {
  final int assessmentId;

  const SensoryProfileResult2({super.key, required this.assessmentId});

  @override
  State<SensoryProfileResult2> createState() => _SensoryProfileResult2State();
}

class _SensoryProfileResult2State extends State<SensoryProfileResult2> {
  bool isLoading = true;
  Map<String, dynamic> resultData = {};
  String? errorMsg;

  // Urutan kategori (Short Sensory Profile)
  final List<String> sspOrder = const [
    'Touch',
    'Taste and Smell Sensitivity',
    'Movement',
    'Under-responsive and Sensory Seeking',
    'Auditory',
    'Low Energy and Weak',
    'Visual and Auditory Sensitivity',
  ];

  @override
  void initState() {
    super.initState();
    fetchResultData();
  }

  Future<void> fetchResultData() async {
    try {
      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter_growcheck_parents/get_sensory_result_2.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'assessment_id': widget.assessmentId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && (data['status'] == 'success' || data['assessment_date'] != null)) {
          setState(() {
            resultData = Map<String, dynamic>.from(data);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMsg = (data is Map && data['message'] != null) ? '${data['message']}' : 'Unable to load result.';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMsg = 'Server error (${response.statusCode}).';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Failed to load result: $e';
        isLoading = false;
      });
    }
  }

  // --- UTIL: warna ikut band ---
  Color _bandColor(String band) {
    final b = band.toLowerCase();
    if (b.contains('definite')) return Colors.red;
    if (b.contains('probable')) return Colors.orange;
    if (b.contains('typical')) return Colors.green;
    return Growkids.purple; // fallback
  }

  /// =========================
  /// SAFE GETTERS & GROUPING
  /// =========================

  /// Try multiple keys for a string value; return '' if missing
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

  /// Try multiple keys for an int/double (score/value); return null if missing
  num? _readNum(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) {
        final v = m[k];
        if (v is num) return v;
        if (v is String) {
          final parsed = num.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  /// If score exists, use it as the displayed answer; else fall back to label or 'No answer'
  String _formatAnswerLabel(String label, num? value) {
    if (value != null) {
      final isInt = value == value.roundToDouble();
      return isInt ? value.toInt().toString() : value.toString();
    }
    return label.trim().isNotEmpty ? label : 'No answer';
  }

  /// Normalize any dynamic `answers` payload to a clean List<Map<String, dynamic>>
  List<Map<String, dynamic>> _extractAnswers(Map<String, dynamic> rd) {
    final results = rd['results'] is Map ? Map<String, dynamic>.from(rd['results']) : const <String, dynamic>{};

    final dynamic raw = (results['answers'] is List)
        ? results['answers']
        : (rd['answers'] is List)
            ? rd['answers']
            : const [];

    final List<Map<String, dynamic>> out = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          out.add(item.cast<String, dynamic>());
        }
      }
    }
    return out;
  }

  /// Group answers by category following `sspOrder` first, then any leftovers
  Map<String, List<Map<String, dynamic>>> _groupByCategory(
    List<dynamic> answersDyn,
    List<String> sspOrder,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final a in answersDyn) {
      if (a is! Map) continue;
      final am = a.cast<String, dynamic>();

      final cat = _readStr(am, ['category', 'category_name', 'cat', 'section']).isEmpty
          ? 'Uncategorized'
          : _readStr(am, ['category', 'category_name', 'cat', 'section']);

      (grouped[cat] ??= []).add(am);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((x, y) {
        final xi = _readNum(x, ['question_id', 'qid', 'id']) ?? 0;
        final yi = _readNum(y, ['question_id', 'qid', 'id']) ?? 0;
        return xi.compareTo(yi);
      });
    }

    final Map<String, List<Map<String, dynamic>>> ordered = {};
    for (final cat in sspOrder) {
      if (grouped.containsKey(cat)) ordered[cat] = grouped.remove(cat)!;
    }
    for (final entry in grouped.entries) {
      ordered[entry.key] = entry.value;
    }
    return ordered;
  }

  /// Compact badge for an answer label/value
  Widget _answerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Growkids.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Growkids.purple.withOpacity(0.35)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  /// ===============================
  /// QUESTIONS & ANSWERS (UI PART)
  /// ===============================
  Widget buildQuestionsAndAnswersSection(
    Map<String, dynamic> rd,
    List<String> sspOrder,
  ) {
    final answers = _extractAnswers(rd);
    if (answers.isEmpty) {
      return const SizedBox.shrink();
    }

    final grouped = _groupByCategory(answers, sspOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Questions & Answers', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 1.h),
        ...grouped.entries.map((entry) {
          final cat = entry.key;
          final items = entry.value;

          return Container(
            margin: EdgeInsets.only(bottom: 1.2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              border: Border.all(color: Colors.black12),
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
                  final qText = _readStr(q, ['question_text', 'question', 'text', 'q']);
                  final aLabel = _readStr(q, [
                    'answer_label',
                    'answer_text',
                    'answer',
                    'response',
                    'selected',
                    'selected_option',
                    'selected_label',
                    'option_text',
                    'choice_label',
                  ]);
                  final aValue = _readNum(q, ['value', 'score', 'points']); // score IS the answer
                  final isRev = (_readNum(q, ['reverse', 'is_reverse']) ?? 0) == 1;

                  final display = _formatAnswerLabel(aLabel, aValue);

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
                        Text(qText.isEmpty ? '—' : qText, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _answerChip(display),
                            if (isRev) ...[
                              const SizedBox(width: 8),
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

  /// Summary (Date + Total Score/Band)
  Widget buildSummaryCard() {
    final rawDate = resultData['assessment_date'] ?? '';
    String formattedDate = '';
    try {
      final date = DateTime.parse(rawDate);
      formattedDate = DateFormat('d MMM y').format(date);
    } catch (_) {
      formattedDate = rawDate.toString();
    }

    final totalScore = resultData['total_score'] ?? 0;
    final totalBand = (resultData['total_band'] ?? '') as String;
    final totalRange = (resultData['total_band_range'] ?? '') as String;

    return Column(
      children: [
        // Date card
        Container(
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
        ),
        SizedBox(height: 1.h),
        // Total card (score + band)
        Container(
          padding: EdgeInsets.all(2.h),
          decoration: BoxDecoration(
            color: Growkids.pink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: GrowkidsPastel.pink,
                child: const Icon(Icons.bar_chart_rounded, color: Growkids.pink),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Score', style: TextStyle(color: Colors.white)),
                    Text('$totalScore', style: TextStyle(color: Colors.white, fontSize: 18.sp)),
                    if (totalBand.isNotEmpty) const SizedBox(height: 4),
                    if (totalBand.isNotEmpty)
                      Text(
                        'Band: $totalBand${totalRange.isNotEmpty ? " ($totalRange)" : ""}',
                        style: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.h),
      ],
    );
  }

  Widget buildCategorySummary(Map<String, dynamic> categorySummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sspOrder.map((cat) {
        if (!categorySummary.containsKey(cat)) {
          return const SizedBox.shrink();
        }
        final raw = categorySummary[cat];
        if (raw is! Map) return const SizedBox.shrink();
        final data = Map<String, dynamic>.from(raw as Map);

        final total = data['total'] ?? 0;
        final count = data['count'] ?? 0;
        final band = (data['band'] ?? '-') as String;
        final range = (data['range'] ?? '') as String;
        final bandColor = _bandColor(band);

        return Container(
          margin: EdgeInsets.only(bottom: 1.5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bandColor.withOpacity(0.35)),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: ListTile(
            title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge with the band text and optional range
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bandColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: bandColor.withOpacity(0.6)),
                    ),
                    child: Text(
                      range.isNotEmpty ? '$band ($range)' : band,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Items: $count'),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Growkids.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Score: $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> categorySummary = (resultData['category_summary'] is Map)
        ? Map<String, dynamic>.from(resultData['category_summary'])
        : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Sensory Result', style: TextStyle(color: Growkids.purple)),
        centerTitle: true,
        leading: const BackButton(color: Growkids.purple),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (errorMsg != null)
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Text(errorMsg!, textAlign: TextAlign.center),
                  ),
                )
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
                        // --- Summary (Date + Total) ---
                        buildSummaryCard(),

                        // --- Category Summary ---
                        const Text('Category Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 1.h),
                        buildCategorySummary(categorySummary),
                        SizedBox(height: 2.h),

                        // --- Questions & Answers (score is the answer) ---
                        buildQuestionsAndAnswersSection(resultData, sspOrder),

                        SizedBox(height: 5.h),
                      ],
                    ),
                  ),
                ),
    );
  }
}
