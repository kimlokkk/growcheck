import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

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

  // =========================
  // FETCH (SAFE) + DEBUG
  // =========================
  Future<void> fetchResultData() async {
    try {
      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter_growcheck_parents/get_sensory_result_2.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'assessment_id': widget.assessmentId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);

          final ok = (map['status']?.toString().toLowerCase() == 'success') ||
              map.containsKey('results') ||
              map.containsKey('answers') ||
              map.containsKey('category_summary');

          if (ok) {
            setState(() {
              resultData = map;
              isLoading = false;
              errorMsg = null;
            });
          } else {
            setState(() {
              errorMsg = (map['message'] != null) ? map['message'].toString() : 'Unable to load result.';
              isLoading = false;
            });
          }
        } else {
          setState(() {
            errorMsg = 'Invalid response format.';
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

    // Debug (kau boleh buang bila dah ok)
    debugPrint('RESULT KEYS: ${resultData.keys}');
    debugPrint('RESULTS TYPE: ${resultData['results']?.runtimeType}');
    debugPrint('ANSWERS LENGTH: ${answers.length}');
  }

  // =========================
  // SAFE GETTERS
  // =========================
  Map<String, dynamic> get _resultsMap {
    final r = resultData['results'];
    if (r is Map) return Map<String, dynamic>.from(r);
    return <String, dynamic>{};
  }

  Map<String, dynamic> get _categorySummary {
    // Endpoint SSP2: category_summary kat root (contoh JSON kau bagi)
    final root = resultData['category_summary'];
    if (root is Map) return Map<String, dynamic>.from(root);

    // fallback kalau letak dalam results
    final inResults = _resultsMap['category_summary'];
    if (inResults is Map) return Map<String, dynamic>.from(inResults);

    // fallback lain
    final raw = _resultsMap['category_raw_score'];
    if (raw is Map) return Map<String, dynamic>.from(raw);

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> get answers {
    if (resultData.isEmpty) return [];

    // ✅ CASE UTAMA (based on JSON kau bagi): answers dalam results.answers
    final res = resultData['results'];
    if (res is Map && res['answers'] is List) {
      final List raw = res['answers'];
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    // fallback: answers di root
    if (resultData['answers'] is List) {
      final List raw = resultData['answers'];
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  // =========================
  // UTILS
  // =========================
  String _formatDateSafe(dynamic raw) {
    try {
      return DateFormat('d MMMM yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw?.toString() ?? '-';
    }
  }

  String _safeStr(dynamic v, [String fallback = '-']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  num _safeNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  Color _bandColor(String band) {
    final b = band.toLowerCase();
    if (b.contains('definite')) return Colors.red;
    if (b.contains('probable')) return Colors.orange;
    if (b.contains('typical')) return Colors.green;
    return Growkids.purple;
  }

  // =========================
  // GROUPING (Questions)
  // =========================
  Map<String, List<Map<String, dynamic>>> groupByCategory() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final q in answers) {
      final cat = (q['category'] ?? q['category_name'] ?? 'Uncategorized').toString();

      grouped.putIfAbsent(cat, () => []);
      grouped[cat]!.add(q);
    }

    // susun ikut sspOrder dulu, then baki
    final ordered = <String, List<Map<String, dynamic>>>{};
    for (final cat in sspOrder) {
      if (grouped.containsKey(cat)) ordered[cat] = grouped.remove(cat)!;
    }
    final leftovers = grouped.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final k in leftovers) {
      ordered[k] = grouped[k]!;
    }

    return ordered;
  }

  // =========================
  // PREMIUM UI ATOMS
  // =========================
  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget _pill({required String text, required Color bg, required Color fg, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(color: fg, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  // =========================
  // UI: HERO HEADER (PURPLEFLOW)
  // =========================
  Widget _heroHeader() {
    final dateText = _formatDateSafe(resultData['assessment_date']);
    final age = _safeStr(resultData['age'], '-');

    final totalScore = _safeStr(resultData['total_score'], '0');
    final totalBand = _safeStr(resultData['total_band'], '');
    final totalRange = _safeStr(resultData['total_band_range'], '');

    final bandColor = _bandColor(totalBand);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(2.2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white,
            child: Icon(Icons.psychology_rounded, color: Growkids.purple, size: 3.2.h),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sensory Profile Result',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'Age: $age months • $dateText',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                SizedBox(height: 1.2.h),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      text: 'Total Score: $totalScore',
                      bg: Colors.white.withOpacity(0.14),
                      fg: Colors.white,
                      icon: Icons.bar_chart_rounded,
                    ),
                    if (totalBand.trim().isNotEmpty)
                      _pill(
                        text: totalRange.trim().isNotEmpty ? '$totalBand ($totalRange)' : totalBand,
                        bg: bandColor.withOpacity(0.20),
                        fg: Colors.white,
                        icon: Icons.verified_rounded,
                      ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // =========================
  // UI: CATEGORY SUMMARY (WHITE CARDS)
  // =========================
  Widget _categorySummarySection() {
    final summary = _categorySummary;

    return _glassCard(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category Summary',
              style: TextStyle(
                fontSize: 14.sp,
              )),
          SizedBox(height: 1.4.h),
          if (summary.isEmpty)
            Text(
              'Category summary not available.',
              style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.65), fontWeight: FontWeight.w600),
            )
          else
            ...sspOrder.map((cat) {
              if (!summary.containsKey(cat)) return const SizedBox.shrink();

              final raw = summary[cat];
              if (raw is! Map) return const SizedBox.shrink();
              final data = Map<String, dynamic>.from(raw);

              final total = _safeNum(data['total']).toInt();
              final count = _safeNum(data['count']).toInt();
              final band = _safeStr(data['band'], '-');
              final range = _safeStr(data['range'], '');
              final color = _bandColor(band);

              return Container(
                margin: EdgeInsets.only(bottom: 1.2.h),
                padding: EdgeInsets.all(1.8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat,
                              style: TextStyle(
                                fontSize: 14.sp,
                              )),
                          SizedBox(height: 0.7.h),
                          _pill(
                            text: range.isNotEmpty ? '$band ($range)' : band,
                            bg: color.withOpacity(0.12),
                            fg: color,
                            icon: Icons.flag_rounded,
                          ),
                          SizedBox(height: 0.7.h),
                          Text(
                            'Items: $count',
                            style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Growkids.purple.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Growkids.purple.withOpacity(0.12)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Score', style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.55))),
                          SizedBox(height: 0.4.h),
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // =========================
  // UI: QUESTIONS (White cards, Expansion)
  // =========================
  Widget _questionsSection() {
    final grouped = groupByCategory();

    if (grouped.isEmpty) {
      return _glassCard(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.black.withOpacity(0.55)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No questions available.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Questions & Answers', style: TextStyle(fontSize: 14.sp)),
        SizedBox(height: 1.2.h),
        ...grouped.entries.map((entry) {
          final cat = entry.key;
          final items = entry.value;

          return Container(
            margin: EdgeInsets.only(bottom: 1.4.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8)),
              ],
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              childrenPadding: EdgeInsets.fromLTRB(2.h, 0, 2.h, 1.6.h),
              title: Text(
                cat,
                style: TextStyle(
                  fontSize: 14.sp,
                ),
              ),
              subtitle: Text(
                '${items.length} item(s)',
                style: TextStyle(fontSize: 12.sp),
              ),
              children: items.map((q) {
                final qText = _safeStr(q['question_text'], '-');
                final score = _safeNum(q['score']).toInt();
                final quad = _safeStr(q['quadrant'], '');

                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 1.2.h),
                  padding: EdgeInsets.all(1.6.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qText,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.88),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill(
                            text: 'Score: $score',
                            bg: Growkids.purple.withOpacity(0.10),
                            fg: Growkids.purple,
                            icon: Icons.bar_chart_rounded,
                          ),
                          if (quad.trim().isNotEmpty && quad.trim().toLowerCase() != 'no quadrant')
                            _pill(
                              text: quad,
                              bg: Colors.black.withOpacity(0.06),
                              fg: Colors.black87,
                              icon: Icons.layers_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  // =========================
  // BUILD (WHITE BG, PURPLEFLOW APPBAR)
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ putih
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo, // ✅ purpleFlo
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sensory Profile',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (errorMsg != null)
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: _glassCard(
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.red.withOpacity(0.9)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: TextStyle(
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(2.h, 2.h, 2.h, 3.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroHeader(), // ✅ purpleFlo full card
                      SizedBox(height: 1.6.h),
                      _categorySummarySection(), // ✅ putih card
                      SizedBox(height: 2.h),
                      _questionsSection(), // ✅ putih cards + expansion
                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
    );
  }
}
