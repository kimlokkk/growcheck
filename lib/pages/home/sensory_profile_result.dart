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
  String? errorMsg;

  /// Payload penuh dari API get_sensory_result.php
  Map<String, dynamic> resultData = {};

  /// Shorthand untuk results blob (SAFE)
  Map<String, dynamic> get results {
    final r = resultData['results'];
    if (r is Map) return Map<String, dynamic>.from(r);
    return <String, dynamic>{};
  }

  /// Endpoint “<37 months” biasanya ada quadrant/category di results.* (atau kadang root)
  Map<String, dynamic> get categorySummary {
    final r = results['category_raw_score'];
    if (r is Map) return Map<String, dynamic>.from(r);

    // fallback kalau ada category_summary
    final cs = results['category_summary'];
    if (cs is Map) return Map<String, dynamic>.from(cs);

    final root = resultData['category_summary'];
    if (root is Map) return Map<String, dynamic>.from(root);

    return <String, dynamic>{};
  }

  Map<String, dynamic> get quadrantSummary {
    final r = results['quadrant_raw_score'];
    if (r is Map) return Map<String, dynamic>.from(r);

    final qs = results['quadrant_summary'];
    if (qs is Map) return Map<String, dynamic>.from(qs);

    final root = resultData['quadrant_summary'];
    if (root is Map) return Map<String, dynamic>.from(root);

    return <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    fetchResultData();
  }

  // =========================
  // FETCH (SAFE) + HANDLE MAP/LIST
  // =========================
  Future<void> fetchResultData() async {
    try {
      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter_growcheck_parents/get_sensory_result.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'assessment_id': widget.assessmentId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        Map<String, dynamic>? normalized;

        // Support jika API return LIST[ {..} ]
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          normalized = Map<String, dynamic>.from(decoded.first);
        } else if (decoded is Map) {
          normalized = Map<String, dynamic>.from(decoded);
        }

        if (normalized == null) {
          setState(() {
            errorMsg = 'Invalid response format.';
            isLoading = false;
          });
          return;
        }

        final ok = (normalized['status']?.toString().toLowerCase() == 'success') ||
            normalized.containsKey('results') ||
            normalized.containsKey('answers');

        if (!ok) {
          setState(() {
            errorMsg = normalized?['message']?.toString() ?? 'Unable to load result.';
            isLoading = false;
          });
          return;
        }

        setState(() {
          resultData = normalized!;
          isLoading = false;
          errorMsg = null;
        });
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

  // =========================
  // UTIL
  // =========================
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

  String _formatDateSafe(dynamic raw) {
    try {
      return DateFormat('d MMMM yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw?.toString() ?? '-';
    }
  }

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

  /// answers boleh berada di results.answers atau root.answers
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

    for (final entry in grouped.entries) {
      entry.value.sort((x, y) {
        final xi = _readNum(x, ['question_id', 'qid', 'id']) ?? 0;
        final yi = _readNum(y, ['question_id', 'qid', 'id']) ?? 0;
        return xi.compareTo(yi);
      });
    }

    // Order categories: by summary keys (alpha) then leftovers (alpha)
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

  // =========================
  // THEME / UI ATOMS (match SensoryProfileResult2 spec)
  // =========================
  TextStyle get _t16 => TextStyle(fontSize: 16.sp);
  TextStyle get _t14 => TextStyle(fontSize: 14.sp);
  TextStyle get _t12 => TextStyle(fontSize: 12.sp);

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
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 2.h, color: fg),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(color: fg, fontSize: 12.sp)),
        ],
      ),
    );
  }

  Color _badgeBg(bool needs) => needs ? Colors.red.withOpacity(0.12) : Growkids.purple.withOpacity(0.10);
  Color _badgeFg(bool needs) => needs ? Colors.red : Growkids.purple;

  // =========================
  // HEADER (PURPLEFLOW FULL)
  // =========================
  Widget _heroHeader() {
    final dateText = _formatDateSafe(resultData['assessment_date']);
    final age = _safeStr(resultData['age'], '-');

    // For SP (<37) mungkin tak ada total di root. Support dua2: root.total_score / results.total_score
    final totalScore = _safeStr(resultData['total_score'] ?? results['total_score'], '0');
    final totalBand = _safeStr(resultData['total_band'] ?? results['total_band'], '');
    final totalRange = _safeStr(resultData['total_band_range'] ?? results['total_band_range'], '');

    // kalau band tak wujud, guna purple
    Color bandColor() {
      final b = totalBand.toLowerCase();
      if (b.contains('definite')) return Colors.red;
      if (b.contains('probable')) return Colors.orange;
      if (b.contains('typical')) return Colors.green;
      return Colors.white;
    }

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
            child: Icon(Icons.psychology_rounded, color: Growkids.purple, size: 4.h),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sensory Profile Result',
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'Age: $age months • $dateText',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // QUADRANT (WHITE CARD)
  // =========================
  Widget _quadrantSection() {
    if (quadrantSummary.isEmpty) return const SizedBox.shrink();

    final entries = quadrantSummary.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return _glassCard(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quadrant Overview', style: _t14),
          SizedBox(height: 1.4.h),
          ...entries.map((e) {
            final v = (e.value is Map) ? Map<String, dynamic>.from(e.value as Map) : <String, dynamic>{};
            final total = v['total'] ?? 0;
            final count = v['count'] ?? 0;
            final band = _safeStr(v['band'], '-');
            final def = _safeStr(v['definition'], '');
            final needs = (v['needs_attention'] == true);

            return Container(
              margin: EdgeInsets.only(bottom: 1.2.h),
              padding: EdgeInsets.all(1.8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _badgeFg(needs).withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title row
                  Row(
                    children: [
                      Expanded(child: Text(e.key.toString(), style: _t14)),
                      _pill(
                        text: band,
                        bg: _badgeBg(needs),
                        fg: _badgeFg(needs),
                        icon: Icons.flag_rounded,
                      ),
                    ],
                  ),
                  if (def.isNotEmpty) ...[
                    SizedBox(height: 0.8.h),
                    Text(def, style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.70))),
                  ],
                  SizedBox(height: 0.9.h),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        text: 'Score: $total',
                        bg: Growkids.purple.withOpacity(0.10),
                        fg: Growkids.purple,
                        icon: Icons.bar_chart_rounded,
                      ),
                      _pill(
                        text: 'Items: $count',
                        bg: Colors.black.withOpacity(0.06),
                        fg: Colors.black87,
                        icon: Icons.list_alt_rounded,
                      ),
                    ],
                  )
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // =========================
  // CATEGORY SUMMARY (WHITE CARD)
  // =========================
  Widget _categorySection() {
    if (categorySummary.isEmpty) return const SizedBox.shrink();

    final entries = categorySummary.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return _glassCard(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category Breakdown', style: _t14),
          SizedBox(height: 1.4.h),
          ...entries.map((e) {
            final v = (e.value is Map) ? Map<String, dynamic>.from(e.value as Map) : <String, dynamic>{};
            final total = v['total'] ?? 0;
            final count = v['count'] ?? 0;
            final band = _safeStr(v['band'], '-');
            final needs = (v['needs_attention'] == true);

            return Container(
              margin: EdgeInsets.only(bottom: 1.2.h),
              padding: EdgeInsets.all(1.8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _badgeFg(needs).withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key.toString(), style: _t14),
                        SizedBox(height: 0.7.h),
                        _pill(
                          text: band,
                          bg: _badgeBg(needs),
                          fg: _badgeFg(needs),
                          icon: Icons.flag_rounded,
                        ),
                        SizedBox(height: 0.7.h),
                        Text('Items: $count', style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  _pill(
                    text: 'Score: $total',
                    bg: Growkids.purple.withOpacity(0.10),
                    fg: Growkids.purple,
                    icon: Icons.bar_chart_rounded,
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
  // QUESTIONS by CATEGORY (WHITE cards + expansion)
  // =========================
  String _formatQuadrantLabel(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    if (s.toLowerCase() == 'no quadrant') return '';
    return s;
  }

  Widget _questionsSection() {
    final answers = _extractAnswers(resultData);
    if (answers.isEmpty) return const SizedBox.shrink();

    final grouped = _groupAnswersByCategory(answers, categorySummary);
    if (grouped.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Questions & Answers', style: _t14),
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
              title: Text(cat, style: _t14),
              subtitle: Text('${items.length} item(s)', style: TextStyle(fontSize: 12.sp)),
              children: items.map((q) {
                final qText = _readStr(q, ['question_text', 'question', 'text', 'q']).trim();
                final score = _readNum(q, ['value', 'score', 'points', 'selected', 'selected_score']) ?? 0;
                final quadRaw = _readStr(q, ['quadrant', 'quadrant_name', 'quad']).trim();
                final quad = _formatQuadrantLabel(quadRaw);

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
                        qText.isEmpty ? '—' : qText,
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      SizedBox(height: 1.h),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill(
                            text: 'Score: ${_safeNum(score).toInt()}',
                            bg: Growkids.purple.withOpacity(0.10),
                            fg: Growkids.purple,
                            icon: Icons.bar_chart_rounded,
                          ),
                          if (quad.isNotEmpty)
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
  // BUILD (WHITE BG, PURPLEFLO APPBAR)
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ putih
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo, // ✅ purpleFlo
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Sensory Profile',
          style: TextStyle(color: Colors.white),
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
                              style: TextStyle(fontSize: 12.sp),
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
                      _heroHeader(), // ✅ purpleFlow full card
                      SizedBox(height: 1.6.h),

                      // Quadrant (if available)
                      if (quadrantSummary.isNotEmpty) ...[
                        _quadrantSection(),
                        SizedBox(height: 1.6.h),
                      ],

                      // Category breakdown (if available)
                      if (categorySummary.isNotEmpty) ...[
                        _categorySection(),
                        SizedBox(height: 1.8.h),
                      ],

                      // Questions grouped by category (always try)
                      _questionsSection(),

                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
    );
  }
}
