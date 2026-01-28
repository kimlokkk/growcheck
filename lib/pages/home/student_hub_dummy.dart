import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/pages/home/profile_student.dart';
import 'package:growcheck_app_v2/pages/home/result_pdf.dart';
import 'package:growcheck_app_v2/pages/home/screening_details.dart';
import 'package:growcheck_app_v2/pages/home/screening_result.dart';
import 'package:growcheck_app_v2/pages/home/sensory_profile_result.dart';
import 'package:growcheck_app_v2/pages/home/view_suggestion.dart';
import 'package:growcheck_app_v2/screening/score.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

import 'sensory_profile_result_2.dart';

enum UserRoleHub { therapist, teacher }

enum _WorkState { todo, draft, done }

class _StudentFlags {
  final _WorkState screening;
  final _WorkState suggestion;
  final _WorkState sensory;
  final _WorkState progress;

  const _StudentFlags({
    required this.screening,
    required this.suggestion,
    required this.sensory,
    required this.progress,
  });

  _StudentFlags copyWith({
    _WorkState? screening,
    _WorkState? suggestion,
    _WorkState? sensory,
    _WorkState? progress,
  }) {
    return _StudentFlags(
      screening: screening ?? this.screening,
      suggestion: suggestion ?? this.suggestion,
      sensory: sensory ?? this.sensory,
      progress: progress ?? this.progress,
    );
  }
}

class _HubStudent {
  final String studId;
  final String name;
  final String age;
  final String months;
  final String branch;
  final _StudentFlags flags;

  const _HubStudent({
    required this.studId,
    required this.name,
    required this.age,
    required this.months,
    required this.branch,
    required this.flags,
  });

  _HubStudent copyWith({
    String? studId,
    String? name,
    String? age,
    String? months,
    String? branch,
    _StudentFlags? flags,
  }) {
    return _HubStudent(
      studId: studId ?? this.studId,
      name: name ?? this.name,
      age: age ?? this.age,
      months: months ?? this.months,
      branch: branch ?? this.branch,
      flags: flags ?? this.flags,
    );
  }
}

class StudentHubPage extends StatefulWidget {
  final String staffId;
  final UserRoleHub role;

  final String childrenUrl; // therapist list
  final String kssStudentUrl; // teacher list

  // Therapist tools endpoints (single student)
  final String checkScreeningUrl;
  final String checkSuggestionUrl;
  final String checkSensoryUrl;

  final String? initialStudId;
  final VoidCallback? onConsumedInitial;

  // Teacher tools endpoint
  final String teacherProgressTodayUrl;

  // Therapist bulk status endpoint (LATEST)
  final String bulkStatusUrl;

  const StudentHubPage({
    super.key,
    required this.staffId,
    required this.role,
    this.childrenUrl = 'https://app.kizzukids.com.my/growkids/flutter/children_v2.php',
    this.kssStudentUrl = 'https://app.kizzukids.com.my/growkids/flutter/student_school.php',
    this.checkScreeningUrl = 'https://app.kizzukids.com.my/growkids/flutter/check_screening_data.php',
    this.checkSuggestionUrl = 'https://app.kizzukids.com.my/growkids/flutter/check_suggestion_data.php',
    this.checkSensoryUrl = 'https://app.kizzukids.com.my/growkids/flutter/check_sensory_status.php',
    this.teacherProgressTodayUrl = 'https://app.kizzukids.com.my/growkids/flutter/teacher_progress_today.php',
    this.bulkStatusUrl = 'https://app.kizzukids.com.my/growkids/flutter/check_student_status_bulk.php',
    this.initialStudId,
    this.onConsumedInitial,
  });

  @override
  State<StudentHubPage> createState() => _StudentHubPageState();
}

class _StudentHubPageState extends State<StudentHubPage> {
  // ===== Data =====
  List<_HubStudent> _all = [];

  // ===== UI State =====
  final TextEditingController _searchCtrl = TextEditingController();
  List<_HubStudent> _filtered = [];
  int _selectedIndex = 0;
  bool _leftCollapsed = false;

  // ===== Loading / Error =====
  bool _loading = false;
  String? _error;

  bool get _isWide => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _refresh();
  }

  Future<void> _refresh() async {
    if (widget.staffId.trim().isEmpty) {
      setState(() {
        _error = 'Missing staffId';
        _all = [];
        _filtered = [];
        _selectedIndex = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final baseStudents = await _fetchStudentList();

      final enriched = widget.role == UserRoleHub.teacher
          ? await _enrichForTeacher(baseStudents)
          : await _enrichForTherapist(baseStudents);

      setState(() {
        _all = enriched;
        _filtered = List.from(_all);
        _selectedIndex = 0;
      });
      _applyInitialStudentIfAny();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _all = [];
        _filtered = [];
        _selectedIndex = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // Role helpers
  // =========================
  List<_WorkState> _relevantStatesForRole(_StudentFlags f) {
    if (widget.role == UserRoleHub.teacher) {
      return [f.progress];
    }
    return [f.screening, f.suggestion, f.sensory];
  }

  // =========================
  // Fetch: Student list
  // =========================
  Future<List<Map<String, dynamic>>> _fetchStudentList() async {
    final isTeacher = widget.role == UserRoleHub.teacher;

    final url = isTeacher ? widget.kssStudentUrl : widget.childrenUrl;
    final body = isTeacher ? {'teacher_id': widget.staffId} : {'therapist_id': widget.staffId};

    final res = await http.post(Uri.parse(url), body: body);

    if (res.statusCode != 200) {
      throw Exception('Failed to load students (HTTP ${res.statusCode})');
    }

    final decoded = json.decode(res.body);
    if (decoded is! List) return [];

    return List<Map<String, dynamic>>.from(decoded);
  }

  Future<List<Map<String, dynamic>>> _fetchFailData({
    required String studId,
    required String screeningId,
  }) async {
    if (screeningId.trim().isEmpty) return [];

    final res = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/screening_result.php'),
      body: {
        'stud_id': studId,
        'screening_id': screeningId,
      },
    );

    if (res.statusCode != 200) return [];

    final decoded = json.decode(res.body);
    if (decoded is! List) return [];

    return List<Map<String, dynamic>>.from(decoded);
  }

  // =========================
  // Therapist BULK status (LATEST + CORRECT PARAM)
  // =========================
  Future<Map<String, _StudentFlags>> _fetchBulkStatusMap() async {
    final res = await http.post(
      Uri.parse(widget.bulkStatusUrl),
      body: {'staff_id': widget.staffId}, // ✅ LATEST: staff_id
    );

    if (res.statusCode != 200) return {};

    final decoded = json.decode(res.body);
    if (decoded is! List) return {};

    _WorkState parse(dynamic v) {
      final s = (v ?? '').toString().toLowerCase();
      if (s == 'done') return _WorkState.done;
      if (s == 'draft') return _WorkState.draft;
      return _WorkState.todo;
    }

    final map = <String, _StudentFlags>{};

    for (final row in decoded) {
      if (row is! Map) continue;

      final studId = (row['stud_id'] ?? row['student_id'] ?? '').toString();
      if (studId.isEmpty) continue;

      map[studId] = _StudentFlags(
        screening: parse(row['screening']),
        suggestion: parse(row['suggestion']),
        sensory: parse(row['sensory']),
        progress: _WorkState.done, // therapist ignore
      );
    }

    return map;
  }

  // =========================
  // Bundles for navigation
  // =========================
  Future<Map<String, dynamic>?> _fetchLatestScreeningBundle(String studId) async {
    final res = await http.post(
      Uri.parse(widget.checkScreeningUrl),
      body: {'stud_id': studId},
    );

    if (res.statusCode != 200) return null;

    final decoded = json.decode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final row = decoded.first;
    if (row is! Map) return null;

    double _toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String _toS(dynamic v) => (v ?? '').toString();

    final screeningId = _toS(row['screening_id'] ?? row['screeningId'] ?? row['id']);
    final screeningDate = _toS(row['screening_date'] ?? row['date'] ?? row['created_at']);
    final therapistSuggestion = _toS(row['therapist_suggestion'] ?? row['suggestion'] ?? row['plan'] ?? '');

    final age = _toD(row['age'] ?? row['age']);
    final ageFineMotor = _toD(row['age_fine_motor'] ?? row['fine_motor_age']);
    final ageGrossMotor = _toD(row['age_gross_motor'] ?? row['gross_motor_age']);
    final agePersonal = _toD(row['age_personal'] ?? row['personal_age'] ?? row['age_personal_social']);
    final ageLanguage = _toD(row['age_language'] ?? row['language_age']);

    final failData = await _fetchFailData(
      studId: studId,
      screeningId: screeningId,
    );

    return {
      'screeningId': screeningId,
      'screeningDate': screeningDate,
      'therapistSuggestion': therapistSuggestion,
      'age': age,
      'ageFineMotor': ageFineMotor,
      'ageGrossMotor': ageGrossMotor,
      'agePersonal': agePersonal,
      'ageLanguage': ageLanguage,
      'failData': failData,
    };
  }

  Future<int?> _fetchSensoryAssessmentId(String studId) async {
    final res = await http.post(
      Uri.parse(widget.checkSensoryUrl),
      body: {'studentId': studId},
    );

    if (res.statusCode != 200) return null;

    final decoded = json.decode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final row = decoded.first;
    if (row is! Map) return null;

    final v = row['assessment_id'] ?? row['assessmentId'] ?? row['id'];
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<T?> _runWithLoading<T>(Future<T?> Function() task) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      return await task();
    } finally {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  // =========================
  // Enrich: Therapist flags (BULK ONLY)
  // =========================
  Future<List<_HubStudent>> _enrichForTherapist(List<Map<String, dynamic>> raw) async {
    final out = <_HubStudent>[];

    // ✅ 1 API call sahaja
    final bulkMap = await _fetchBulkStatusMap();

    for (final s in raw) {
      final studId = (s['stud_id'] ?? s['student_id'] ?? '').toString();
      final name = (s['stud_name'] ?? s['student'] ?? s['name'] ?? '-').toString();
      final branch = (s['stud_branch'] ?? s['branch'] ?? '-').toString();
      final dob = (s['stud_dob'] ?? s['dob'] ?? '').toString();

      final ageYears = _calculateAgeYears(dob);
      final ageMonths = _calculateAgeMonths(dob);

      final flags = bulkMap[studId] ??
          const _StudentFlags(
            screening: _WorkState.todo,
            suggestion: _WorkState.todo,
            sensory: _WorkState.todo,
            progress: _WorkState.done,
          );

      out.add(
        _HubStudent(
          studId: studId,
          name: name,
          age: ageYears,
          months: ageMonths,
          branch: branch,
          flags: flags,
        ),
      );
    }

    return out;
  }

  // =========================
  // Enrich: Teacher flags
  // =========================
  Future<List<_HubStudent>> _enrichForTeacher(List<Map<String, dynamic>> raw) async {
    final out = <_HubStudent>[];

    final todayMap = await _fetchTeacherProgressTodayMap();

    for (final s in raw) {
      final studId = (s['stud_id'] ?? s['student_id'] ?? '').toString();
      final name = (s['stud_name'] ?? s['student'] ?? s['name'] ?? '-').toString();
      final branch = (s['stud_branch'] ?? s['branch'] ?? '-').toString();
      final dob = (s['stud_dob'] ?? s['dob'] ?? '').toString();

      final ageYears = _calculateAgeYears(dob);
      final ageMonths = _calculateAgeMonths(dob);

      final progressState = _progressStateFromRow(todayMap[studId]);

      final flags = _StudentFlags(
        screening: _WorkState.done, // hidden
        suggestion: _WorkState.done, // hidden
        sensory: _WorkState.done, // hidden
        progress: progressState,
      );

      out.add(
        _HubStudent(
          studId: studId,
          name: name,
          age: ageYears,
          months: ageMonths,
          branch: branch,
          flags: flags,
        ),
      );
    }

    return out;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchTeacherProgressTodayMap() async {
    final res = await http.post(
      Uri.parse(widget.teacherProgressTodayUrl),
      body: {'teacher_id': widget.staffId},
    );

    if (res.statusCode != 200) return {};

    final decoded = json.decode(res.body);
    if (decoded is! List) return {};

    final map = <String, Map<String, dynamic>>{};
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final studId = (item['stud_id'] ?? item['student_id'] ?? '').toString();
        if (studId.isNotEmpty) map[studId] = item;
      }
    }
    return map;
  }

  _WorkState _progressStateFromRow(Map<String, dynamic>? row) {
    if (row == null) return _WorkState.todo;
    final status = (row['status'] ?? row['progress_status'] ?? '').toString().toLowerCase();

    if (status == 'draft') return _WorkState.draft;
    if (status == 'submit') return _WorkState.done;

    return _WorkState.draft;
  }

  // =========================
  // Search / Select
  // =========================
  void _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filtered = List.from(_all);
        _selectedIndex = 0;
      });
      return;
    }

    final res = _all.where((s) => s.name.toLowerCase().contains(query)).toList();
    setState(() {
      _filtered = res;
      _selectedIndex = 0;
    });
  }

  void _selectStudent(int index) {
    if (index < 0 || index >= _filtered.length) return;
    setState(() => _selectedIndex = index);
  }

  void _applyInitialStudentIfAny() {
    final sid = widget.initialStudId;
    if (sid == null || sid.trim().isEmpty) return;

    // pastikan ada data
    if (_filtered.isEmpty) return;

    final idx = _filtered.indexWhere((x) => x.studId == sid);
    if (idx < 0) return;

    setState(() {
      _selectedIndex = idx;

      // optional: kalau nak paksa expand bila collapsed
      // _leftCollapsed = false;
    });

    // consume sekali sahaja supaya next buka StudentHub tak melekat
    widget.onConsumedInitial?.call();
  }

  // =========================
  // Age helpers
  // =========================
  String _calculateAgeYears(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
      if (years < 0) years = 0;
      return '$years yrs';
    } catch (_) {
      return '-';
    }
  }

  String _calculateAgeMonths(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int months = (now.year - dob.year) * 12 + (now.month - dob.month);
      if (now.day < dob.day) months--;
      if (months < 0) months = 0;
      return '$months mo';
    } catch (_) {
      return '-';
    }
  }

  int _monthsIntFromString(String months) {
    final m = RegExp(r'(\d+)').firstMatch(months);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =========================
  // BUILD (UI unchanged)
  // =========================
  @override
  Widget build(BuildContext context) {
    final sel = _filtered.isEmpty ? null : _filtered[_selectedIndex.clamp(0, _filtered.length - 1)];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(1.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Student Hub',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16.sp),
                  ),
                  const Spacer(),
                  if (_loading)
                    SizedBox(
                      height: 2.5.h,
                      width: 2.5.h,
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _refresh,
                    icon: Icon(Icons.refresh_rounded, size: 3.h),
                  ),
                ],
              ),
              Text(
                'Select a student to view details & actions.',
                style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.6)),
              ),
              SizedBox(height: 1.h),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.red.withOpacity(0.8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.75)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 1.h),
              Expanded(
                child: _isWide
                    ? Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            width: _leftCollapsed ? 100 : 360,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _buildStudentListPanel(wide: true),
                            ),
                          ),
                          SizedBox(width: 1.2.w),
                          Expanded(
                            child: sel == null
                                ? _EmptyState(text: _loading ? 'Loading…' : 'No student found.')
                                : _buildDetailPanel(sel),
                          ),
                        ],
                      )
                    : _buildPhoneList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // LEFT PANEL
  // =========================
  Widget _buildStudentListPanel({required bool wide}) {
    return Container(
      padding: !_leftCollapsed ? EdgeInsets.all(1.6.h) : EdgeInsets.all(1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          if (_leftCollapsed)
            Center(
              child: IconButton(
                tooltip: 'Expand',
                icon: Icon(Icons.chevron_right_rounded, size: 2.5.h),
                onPressed: () => setState(() => _leftCollapsed = false),
              ),
            )
          else
            Row(
              children: [
                Text('Students', style: TextStyle(fontSize: 14.sp)),
                const Spacer(),
                IconButton(
                  tooltip: 'Collapse',
                  icon: Icon(Icons.chevron_left_rounded, size: 2.5.h),
                  onPressed: () => setState(() => _leftCollapsed = true),
                ),
              ],
            ),
          if (!_leftCollapsed) ...[
            SizedBox(height: 1.h),
            TextField(
              style: TextStyle(fontSize: 14.sp),
              controller: _searchCtrl,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search student...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Growkids.purple.withOpacity(0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Growkids.purple.withOpacity(0.6)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 4),
          ],
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      _loading ? 'Loading…' : 'No students',
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 14.sp),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      final selected = i == _selectedIndex;

                      if (_leftCollapsed) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 0.2.h),
                          child: InkWell(
                            onTap: () => _selectStudent(i),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? Growkids.purple.withOpacity(0.10) : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Growkids.purple.withOpacity(0.12),
                                      child: Text(
                                        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                        style: TextStyle(color: Growkids.purple, fontSize: 14.sp),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: _StatusDot(states: _relevantStatesForRole(s.flags)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _selectStudent(i),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(1.4.h),
                            decoration: BoxDecoration(
                              color: selected ? Growkids.purple.withOpacity(0.08) : const Color(0xFFF8F9FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14.sp),
                                      ),
                                      SizedBox(height: 0.3.h),
                                      Text(
                                        '${s.age} • ${s.months}',
                                        style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.6)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.35), size: 3.h),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =========================
  // RIGHT PANEL (DETAIL)
  // =========================
  Widget _buildDetailPanel(_HubStudent s) {
    // ---- gating logic (LATEST) ----
    final isScreeningDone = s.flags.screening == _WorkState.done;

    // Screening Result & PDF ONLY bila submit (done)
    final canResult = isScreeningDone;
    final canPdf = isScreeningDone;

    // ✅ Suggestion: enable bila screening submit (DONE)
    final canSuggestion = isScreeningDone;

    // Sensory: enable hanya bila parents dah jawab (done)
    final canSensory = s.flags.sensory == _WorkState.done;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: EdgeInsets.all(2.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Growkids.purpleFlo,
                Growkids.purpleFlo.withOpacity(.70),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                  style: TextStyle(color: Growkids.purple, fontSize: 16.sp),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: TextStyle(fontSize: 16.sp, color: Colors.white)),
                    SizedBox(height: 0.3.h),
                    Text('${s.age} • ${s.months}',
                        style: TextStyle(fontSize: 14.sp, color: Colors.white.withOpacity(0.85))),
                    SizedBox(height: 0.3.h),
                    Text(
                      s.branch,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.sp, color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.4.h),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today checklist', style: TextStyle(fontSize: 14.sp)),
              SizedBox(height: 2.h),
              if (widget.role == UserRoleHub.therapist) ...[
                _ChecklistRow(label: 'Screening', state: s.flags.screening),
                _ChecklistRow(label: 'Suggestion / Plan', state: s.flags.suggestion),
                _ChecklistRow(label: 'Sensory Profile', state: s.flags.sensory),
              ] else ...[
                _ChecklistRow(label: 'Daily Progress', state: s.flags.progress),
              ],
            ],
          ),
        ),
        SizedBox(height: 1.4.h),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student tools', style: TextStyle(fontSize: 14.sp)),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: _leftCollapsed ? 2 : 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: _leftCollapsed ? 3 : 4.5,
                children: widget.role == UserRoleHub.therapist
                    ? [
                        _ActionTile(
                          title: 'Profile',
                          subtitle: 'Student info',
                          icon: Icons.person_rounded,
                          accent: const Color(0xFF3B82F6),
                          onTap: () {
                            final monthsInt = _monthsIntFromString(s.months);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileStudent(
                                  studentId: s.studId,
                                  studentName: s.name,
                                  age: s.age,
                                  ageInMonths: s.months,
                                  ageInMonthsINT: monthsInt,
                                ),
                              ),
                            );
                          },
                        ),
                        _ActionTile(
                          title: 'Screening Result',
                          subtitle: 'View result',
                          icon: Icons.assessment_rounded,
                          accent: const Color(0xFF0AAE7A),
                          disabled: !canResult,
                          onTap: () async {
                            final bundle = await _fetchLatestScreeningBundle(s.studId);

                            if (bundle == null || (bundle['screeningId'] ?? '').toString().isEmpty) {
                              _snack('No screening data found.');
                              return;
                            }

                            //final monthsInt = _monthsIntFromString(s.months);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScreeningResult(
                                  studentId: s.studId,
                                  studentName: s.name,
                                  age: (bundle['age']),
                                  ageFineMotor: (bundle['ageFineMotor'] as double),
                                  ageGrossMotor: (bundle['ageGrossMotor'] as double),
                                  agePersonal: (bundle['agePersonal'] as double),
                                  ageLanguage: (bundle['ageLanguage'] as double),
                                  therapist_suggestion: bundle['therapistSuggestion'],
                                  screeningId: bundle['screeningId'],
                                  screeningDate: bundle['screeningDate'],
                                ),
                              ),
                            );
                          },
                        ),
                        _ActionTile(
                          title: 'Print PDF',
                          subtitle: 'Generate report',
                          icon: Icons.print_rounded,
                          accent: const Color(0xFFF59E0B),
                          disabled: !canPdf,
                          onTap: () async {
                            final bundle = await _fetchLatestScreeningBundle(s.studId);

                            if (bundle == null || (bundle['screeningId'] ?? '').toString().isEmpty) {
                              _snack('No screening data found.');
                              return;
                            }

                            final monthsInt = _monthsIntFromString(s.months);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultPdf(
                                  studentId: s.studId,
                                  screeningId: bundle['screeningId'],
                                  studentName: s.name,
                                  ageString: s.age,
                                  age: monthsInt.toDouble(),
                                  ageFineMotor: bundle['ageFineMotor'],
                                  ageGrossMotor: bundle['ageGrossMotor'],
                                  agePersonal: bundle['agePersonal'],
                                  ageLanguage: bundle['ageLanguage'],
                                  therapist_suggestion: bundle['therapistSuggestion'],
                                  screeningDate: bundle['screeningDate'],
                                  failData: List<Map<String, dynamic>>.from(bundle['failData']),
                                ),
                              ),
                            );
                          },
                        ),
                        _ActionTile(
                          title: 'Suggestion',
                          subtitle: 'View / Add',
                          icon: Icons.checklist_rounded,
                          accent: const Color(0xFF0AAE7A),
                          disabled: !canSuggestion,
                          onTap: () async {
                            final bundle = await _fetchLatestScreeningBundle(s.studId);

                            if (bundle == null || (bundle['screeningId'] ?? '').toString().isEmpty) {
                              _snack('No screening found.');
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ViewSuggestion(
                                  studentId: s.studId,
                                  screeningId: bundle['screeningId'],
                                  studentName: s.name,
                                  age: _monthsIntFromString(s.months).toDouble(),
                                  ageFineMotor: bundle['ageFineMotor'],
                                  ageGrossMotor: bundle['ageGrossMotor'],
                                  agePersonal: bundle['agePersonal'],
                                  ageLanguage: bundle['ageLanguage'],
                                ),
                              ),
                            );
                          },
                        ),
                        _ActionTile(
                          title: 'Sensory Profile',
                          subtitle: 'View / Add',
                          icon: Icons.psychology_rounded,
                          accent: const Color(0xFF8B5CF6),
                          disabled: !canSensory,
                          onTap: () async {
                            final assessmentId = await _fetchSensoryAssessmentId(s.studId);

                            if (assessmentId == null) {
                              _snack('No sensory assessment found yet.');
                              return;
                            }

                            // 🔑 umur dalam bulan
                            final monthsInt = _monthsIntFromString(s.months);

                            if (monthsInt >= 37) {
                              // ✅ 3 tahun ke atas → Short Sensory Profile
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SensoryProfileResult2(
                                    assessmentId: assessmentId,
                                  ),
                                ),
                              );
                            } else {
                              // ✅ bawah 37 bulan → Infant/Toddler Sensory Profile
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SensoryProfileResult(
                                    assessmentId: assessmentId,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ]
                    : [
                        _ActionTile(
                            title: 'Profile',
                            subtitle: 'Student info',
                            icon: Icons.person_rounded,
                            accent: const Color(0xFF3B82F6),
                            onTap: () {
                              final monthsInt = _monthsIntFromString(s.months);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileStudent(
                                    studentId: s.studId,
                                    studentName: s.name,
                                    age: s.age,
                                    ageInMonths: s.months,
                                    ageInMonthsINT: monthsInt,
                                  ),
                                ),
                              );
                            }),
                        _ActionTile(
                          title: 'Progress',
                          subtitle: 'Daily update',
                          icon: Icons.edit_note_rounded,
                          accent: const Color(0xFFEC4899),
                          onTap: () => _snack('Open Daily Progress (dummy)'),
                          disabled: s.flags.progress == _WorkState.todo,
                        ),
                      ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // PHONE LAYOUT
  // =========================
  Widget _buildPhoneList() {
    return Container(
      padding: EdgeInsets.all(1.6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Search student...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Growkids.purple.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Growkids.purple.withOpacity(0.6)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? _EmptyState(text: _loading ? 'Loading…' : 'No student found.')
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _StudentDetailPhonePage(student: s, role: widget.role),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(1.4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                        style: TextStyle(fontWeight: FontWeight.w900, color: Growkids.purple),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: _StatusDot(states: _relevantStatesForRole(s.flags)),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 1.2.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900),
                                      ),
                                      SizedBox(height: 0.3.h),
                                      Text(
                                        '${s.age} • ${s.months} • ${s.branch}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11.sp, color: Colors.black.withOpacity(0.6)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.35)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================
// PHONE DETAIL PAGE (unchanged)
// ==========================
class _StudentDetailPhonePage extends StatelessWidget {
  final _HubStudent student;
  final UserRoleHub role;
  const _StudentDetailPhonePage({required this.student, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(student.name),
        backgroundColor: Growkids.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Growkids.purple,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Growkids.purple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${student.age} • ${student.months}',
                            style: TextStyle(color: Colors.white.withOpacity(0.85))),
                        const SizedBox(height: 2),
                        Text(
                          student.branch,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Today checklist', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (role == UserRoleHub.therapist) ...[
                    _ChecklistRow(label: 'Screening', state: student.flags.screening),
                    _ChecklistRow(label: 'Suggestion / Plan', state: student.flags.suggestion),
                    _ChecklistRow(label: 'Sensory Profile', state: student.flags.sensory),
                  ] else ...[
                    _ChecklistRow(label: 'Daily Progress', state: student.flags.progress),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================
// UI atoms (UNCHANGED)
// ==========================
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
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
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool disabled;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = disabled ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(1.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 4.h,
                width: 5.w,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent),
              ),
              SizedBox(width: 1.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 14.sp),
                    ),
                    SizedBox(height: 0.1.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black.withOpacity(0.60),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.sp,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.35), size: 3.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final _WorkState state;

  const _ChecklistRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String text;
    Color color;

    switch (state) {
      case _WorkState.todo:
        icon = Icons.close_rounded;
        text = 'Not done';
        color = Colors.redAccent;
        break;
      case _WorkState.draft:
        icon = Icons.edit_rounded;
        text = 'Draft';
        color = Colors.orange;
        break;
      case _WorkState.done:
        icon = Icons.check_circle_rounded;
        text = 'Done';
        color = Colors.green;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 2.h,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 2.h, color: color),
          ),
          SizedBox(width: 1.w),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14.sp))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text, style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.65))),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final List<_WorkState> states;
  const _StatusDot({required this.states});

  @override
  Widget build(BuildContext context) {
    Color c;
    if (states.contains(_WorkState.todo)) {
      c = Colors.redAccent;
    } else if (states.contains(_WorkState.draft)) {
      c = Colors.orange;
    } else {
      c = Colors.green;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(fontSize: 13.sp, color: Colors.black.withOpacity(0.55)),
      ),
    );
  }
}
