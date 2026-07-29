import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/ssp/sensory_profile_result.dart';
import 'package:growcheck_app_v2/pages/ssp/sensory_profile_result_2.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopSspHomeLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class SspPage extends StatefulWidget {
  final String therapistId;

  const SspPage({
    super.key,
    required this.therapistId,
  });

  @override
  State<SspPage> createState() => _SspPageState();
}

class _SspPageState extends State<SspPage> {
  // Therapist student list
  static final String _childrenUrl = ApiConfig.flutter('children_v2.php');

  // Your PHP: returns LIST of sensory_assessments rows for given studentId
  static final String _sensoryStatusUrl =
      ApiConfig.flutter('check_sensory_status.php');

  /*static const String _childrenUrl =
      'http://app-kizzu.test/growkids/flutter/children_v2.php';

  static const String _sensoryStatusUrl =
      'http://app-kizzu.test/growkids/flutter/check_sensory_status.php';*/

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  List<_StudentWithSsp> _all = [];
  List<_StudentWithSsp> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.therapistId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing therapistId';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Load therapist students
      final res = await http.post(
        Uri.parse(_childrenUrl),
        body: {'therapist_id': widget.therapistId},
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to load students (HTTP ${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) throw Exception('Invalid student list response');

      final base = <_BaseStudent>[];
      for (final row in decoded) {
        if (row is! Map) continue;

        final sid = (row['stud_id'] ?? row['student_id'] ?? '').toString();
        if (sid.isEmpty) continue;

        final name = (row['stud_name'] ?? row['student'] ?? row['name'] ?? '-')
            .toString();
        final dob = (row['stud_dob'] ?? row['dob'] ?? '').toString();

        final months = _ageMonths(dob);
        base.add(
          _BaseStudent(
            studId: sid,
            name: name,
            dob: dob,
            ageMonths: months,
            agePretty: _agePrettyFromMonths(months),
          ),
        );
      }

      // 2) Fetch latest SSP for each student (keep only those with result)
      // Keep it simple, but still reasonably fast with Future.wait.
      final futures = base
          .map((s) =>
              _fetchLatestAssessmentRow(s.studId).then((row) => (s, row)))
          .toList();
      final pairs = await Future.wait(futures);

      final out = <_StudentWithSsp>[];
      for (final pair in pairs) {
        final s = pair.$1;
        final row = pair.$2;
        if (row == null) continue;

        final assessmentId =
            _extractInt(row, ['id', 'assessment_id', 'assessmentId']);
        if (assessmentId == null) continue;

        out.add(
          _StudentWithSsp(
            studId: s.studId,
            name: s.name,
            ageMonths: s.ageMonths,
            agePretty: s.agePretty,
            assessmentId: assessmentId,
            summary: _buildSummary(row),
            assessmentDateLabel: _buildDateLabel(row),
          ),
        );
      }

      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _all = out;
        _filtered = List.from(out);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestAssessmentRow(
      String studentId) async {
    final res = await http.post(
      Uri.parse(_sensoryStatusUrl),
      body: {'studentId': studentId},
    );

    if (res.statusCode != 200) return null;

    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;

    // pick row with max id
    Map<String, dynamic>? bestRow;
    int? bestId;

    for (final r in decoded) {
      if (r is! Map) continue;
      final row = r.cast<String, dynamic>();
      final id = _extractInt(row, ['id', 'assessment_id', 'assessmentId']);
      if (id == null) continue;

      if (bestId == null || id > bestId) {
        bestId = id;
        bestRow = row;
      }
    }

    return bestRow;
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = List.from(_all));
      return;
    }

    setState(() {
      _filtered =
          _all.where((s) => s.name.toLowerCase().contains(query)).toList();
    });
  }

  void _openDetails(_StudentWithSsp s) {
    final page = s.ageMonths < 37
        ? SensoryProfileResult(
            assessmentId: s.assessmentId,
            studName: s.name,
          )
        : SensoryProfileResult2(
            assessmentId: s.assessmentId,
            studName: s.name,
          );

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  static int? _extractInt(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      if (!row.containsKey(k)) continue;
      final v = row[k];
      final parsed = int.tryParse(v?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _buildDateLabel(Map<String, dynamic> row) {
    // Try common date fields
    final candidates = [
      'created_at',
      'createdAt',
      'date_created',
      'assessment_date',
      'assessmentDate',
      'submit_date',
      'submitted_at',
      'date',
    ];

    for (final k in candidates) {
      final v = row[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;

      // Try parse
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return DateFormat('d MMM yyyy').format(dt);
      }

      // If not parseable, just show raw
      return s;
    }

    return '';
  }

  static String _buildSummary(Map<String, dynamic> row) {
    // We keep this robust: look for a few likely score fields.
    // If none exist, show Assessment ID.

    final total = _firstValue(row, [
      'total_score',
      'totalScore',
      'overall_score',
      'overallScore',
      'raw_total',
      'rawTotal',
      'grand_total',
      'grandTotal',
      'ssp_total',
      'sspTotal',
      'score',
      'total',
    ]);

    final classification = _firstValue(row, [
      'classification',
      'category',
      'result_category',
      'resultCategory',
      'interpretation',
      'summary',
    ]);

    final parts = <String>[];
    if (total != null && total.toString().trim().isNotEmpty) {
      parts.add('Total: ${total.toString()}');
    }
    if (classification != null && classification.toString().trim().isNotEmpty) {
      parts.add(classification.toString());
    }

    if (parts.isNotEmpty) return parts.join(' • ');

    final id = _firstValue(row, ['id', 'assessment_id', 'assessmentId']);
    return id == null ? 'SSP result available' : 'Assessment #${id.toString()}';
  }

  static dynamic _firstValue(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      return v;
    }
    return null;
  }

  static int _ageMonths(String dobString) {
    if (dobString.isEmpty) return 0;
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int totalMonths = (now.year - dob.year) * 12 + (now.month - dob.month);
      if (now.day < dob.day) totalMonths--;
      if (totalMonths < 0) totalMonths = 0;
      return totalMonths;
    } catch (_) {
      return 0;
    }
  }

  static String _agePrettyFromMonths(int totalMonths) {
    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;
    return '$years yrs $months mo';
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSspHomeLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('SSP Results'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(2.h, 14, 2.h, 12),
              child: Column(
                children: [
                  const _Header(),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(
                      fontSize: 14.sp,
                    ),
                    controller: _searchCtrl,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Growkids.purpleFlo.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _ErrorBanner(text: _error!),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No SSP results found.',
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black.withValues(alpha: 0.6)),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(2.h, 0, 2.h, 14),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = _filtered[i];

                            return InkWell(
                              onTap: () => _openDetails(s),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: EdgeInsets.all(2.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          Colors.black.withValues(alpha: 0.06)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 14,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 3.h,
                                      backgroundColor: Growkids.purple
                                          .withValues(alpha: 0.12),
                                      child: Text(
                                        s.name.isNotEmpty
                                            ? s.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            fontSize: 16.sp,
                                            color: Growkids.purple),
                                      ),
                                    ),
                                    SizedBox(width: 2.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  s.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 14.sp),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: 0.5.h,
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                s.agePretty,
                                                style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.6)),
                                              ),
                                              if (s.assessmentDateLabel
                                                  .isNotEmpty) ...[
                                                Text(
                                                  '  •  ${s.assessmentDateLabel}',
                                                  style: TextStyle(
                                                      fontSize: 12.sp,
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.55)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color:
                                          Colors.black.withValues(alpha: 0.35),
                                      size: 3.h,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final youngerCount = _all.where((s) => s.ageMonths < 37).length;
    final olderCount = _all.length - youngerCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'SSP Results',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
            child: Column(
              children: [
                _desktopHero(youngerCount, olderCount),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student assessments',
                            style: TextStyle(
                              color: Color(0xFF242631),
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Open a student to review their latest sensory profile.',
                            style: TextStyle(
                              color: Color(0xFF777C8D),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 390,
                      height: 46,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _filter,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search student...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9A9EAA),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF737887),
                            size: 21,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0E3EA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0E3EA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Growkids.purpleFlo,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _desktopErrorBanner(_error!),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? _desktopEmptyState()
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 1050
                                    ? 3
                                    : constraints.maxWidth >= 680
                                        ? 2
                                        : 1;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    mainAxisExtent: 176,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) =>
                                      _desktopStudentCard(_filtered[index]),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHero(int youngerCount, int olderCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Growkids.purpleFlo,
              size: 37,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SENSORY ASSESSMENT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Short Sensory Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Review the latest SSP assessment results for your students.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _desktopHeroMetric(
            Icons.assignment_turned_in_outlined,
            _all.length.toString(),
            'Results',
          ),
          const SizedBox(width: 12),
          _desktopHeroMetric(
            Icons.child_care_rounded,
            youngerCount.toString(),
            'SSP ≤ 36 mo',
          ),
          const SizedBox(width: 12),
          _desktopHeroMetric(
            Icons.face_rounded,
            olderCount.toString(),
            'SSP2 ≥ 37 mo',
          ),
        ],
      ),
    );
  }

  Widget _desktopHeroMetric(IconData icon, String value, String label) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopStudentCard(_StudentWithSsp student) {
    final isYoung = student.ageMonths < 37;
    final profileLabel = isYoung ? 'SSP · ≤ 36 months' : 'SSP2 · ≥ 37 months';
    final accent = isYoung ? Growkids.purpleFlo : const Color(0xFF0AAE7A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(student),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE3E5EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      student.name.isEmpty
                          ? '?'
                          : student.name[0].toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF292B35),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${student.agePretty}  •  ID ${student.studId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7D8290),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: accent,
                    size: 20,
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        profileLabel,
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (student.assessmentDateLabel.isNotEmpty) ...[
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF8A8E9A),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        student.assessmentDateLabel,
                        style: const TextStyle(
                          color: Color(0xFF777C89),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      student.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF696E7C),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '#${student.assessmentId}',
                    style: const TextStyle(
                      color: Color(0xFF9A9EAA),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopEmptyState() {
    return Center(
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E5EC)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Color(0xFF9B9FAC),
              size: 40,
            ),
            SizedBox(height: 12),
            Text(
              'No SSP results found',
              style: TextStyle(
                color: Color(0xFF343640),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Try a different student name or refresh the results.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF858A98), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopErrorBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF2C5C9)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFCF3948),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF9A2934),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================= Models =========================

class _BaseStudent {
  final String studId;
  final String name;
  final String dob;
  final int ageMonths;
  final String agePretty;

  const _BaseStudent({
    required this.studId,
    required this.name,
    required this.dob,
    required this.ageMonths,
    required this.agePretty,
  });
}

class _StudentWithSsp {
  final String studId;
  final String name;
  final int ageMonths;
  final String agePretty;
  final int assessmentId;
  final String summary;
  final String assessmentDateLabel;

  const _StudentWithSsp({
    required this.studId,
    required this.name,
    required this.ageMonths,
    required this.agePretty,
    required this.assessmentId,
    required this.summary,
    required this.assessmentDateLabel,
  });
}

// ========================= UI Bits =========================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .70)
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 3.h,
            backgroundColor: Colors.white,
            child: Icon(Icons.psychology_rounded,
                color: Growkids.purpleFlo, size: 3.h),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Short Sensory Profile (SSP)',
                    style: TextStyle(fontSize: 16.sp, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.red.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12.sp, color: Colors.black.withValues(alpha: 0.75)),
            ),
          ),
        ],
      ),
    );
  }
}
