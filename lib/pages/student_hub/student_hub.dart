import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/student_hub/profile_student.dart';
import 'package:growcheck_app_v2/pages/denver/screening_result.dart';
import 'package:growcheck_app_v2/pages/ssp/sensory_profile_result.dart';
import 'package:growcheck_app_v2/pages/student_hub/attendance_student_history.dart';
import 'package:growcheck_app_v2/pages/student_hub/journal_student_history.dart';
import 'package:growcheck_app_v2/pages/student_hub/student_home_program_page.dart';
import 'package:growcheck_app_v2/pages/soap/soap_report_list.dart';
import 'package:growcheck_app_v2/pages/sspsc/sspsc_result.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

import '../ssp/sensory_profile_result_2.dart';

enum UserRoleHub { therapist, teacher }

enum _WorkState { todo, draft, done }

bool get _runsOnDesktopPlatform => switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };

bool _isNativeDesktop(BuildContext context) {
  return _runsOnDesktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

// =========================
// MODEL
// =========================
class _StudentFlags {
  final _WorkState denver;
  final _WorkState ssp;
  final _WorkState sspsc;
  final _WorkState journal;
  final _WorkState soap;
  final _WorkState attendance;

  const _StudentFlags({
    required this.denver,
    required this.ssp,
    required this.sspsc,
    required this.journal,
    required this.soap,
    required this.attendance,
  });

  factory _StudentFlags.fromJson(Map<String, dynamic> json) {
    _WorkState parse(dynamic v) {
      final s = (v ?? '').toString().toLowerCase();
      if (s == 'done') return _WorkState.done;
      if (s == 'draft') return _WorkState.draft;
      return _WorkState.todo;
    }

    return _StudentFlags(
      denver: parse(json['denver']),
      ssp: parse(json['ssp']),
      sspsc: parse(json['sspsc']),
      journal: parse(json['journal']),
      soap: parse(json['soap']),
      attendance: parse(json['attendance']),
    );
  }
}

class _HubStudent {
  final String studId;
  final String name;

  /// Display age: "X yrs Y mo"
  final String age;

  /// Backend-friendly: "Z mo" (keep this, DO NOT remove)
  final String months;

  /// Keep branch in data (even if we don't show it in UI)
  final String branch;

  final String status;

  final _StudentFlags flags;

  const _HubStudent({
    required this.studId,
    required this.name,
    required this.age,
    required this.months,
    required this.branch,
    required this.status,
    required this.flags,
  });

  bool get isOfficial => status.trim().toLowerCase() == 'official';
}

// =========================
// PAGE
// =========================
class StudentHubPage extends StatefulWidget {
  final String staffId;
  final UserRoleHub role;

  final String? hubDataUrl;
  final String? getSSPSCHistoryUrl;
  final String? checkScreeningUrl;
  final String? checkScreeningResultUrl;
  final String? checkSensoryUrl;

  String get resolvedHubDataUrl =>
      hubDataUrl ?? ApiConfig.flutter('studenthub_get_data.php');

  String get resolvedGetSSPSCHistoryUrl =>
      getSSPSCHistoryUrl ?? ApiConfig.flutter('sp2_get_history.php');

  String get resolvedCheckScreeningUrl =>
      checkScreeningUrl ?? ApiConfig.flutter('check_screening_data.php');

  String get resolvedCheckScreeningResultUrl =>
      checkScreeningResultUrl ?? ApiConfig.flutter('screening_result.php');

  String get resolvedCheckSensoryUrl =>
      checkSensoryUrl ?? ApiConfig.flutter('check_sensory_status.php');

  final String? initialStudId;
  final VoidCallback? onConsumedInitial;

  const StudentHubPage({
    super.key,
    required this.staffId,
    required this.role,
    this.hubDataUrl,
    this.getSSPSCHistoryUrl,
    this.checkScreeningUrl,
    this.checkScreeningResultUrl,
    this.checkSensoryUrl,
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

  bool get _isDesktop {
    return _isNativeDesktop(context);
  }

  bool get _isTablet {
    if (_runsOnDesktopPlatform) return false;
    return MediaQuery.sizeOf(context).shortestSide >= 700;
  }

  bool get _isWide => _isDesktop || _isTablet;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================
  // Role helpers
  // =========================
  List<_WorkState> _summaryStatesForRole(_StudentFlags f) {
    if (widget.role == UserRoleHub.teacher) {
      // Teacher: ringkaskan (SSPSC + Journal + Attendance)
      return [f.sspsc, f.journal, f.attendance];
    }
    // Therapist: semua
    return [f.denver, f.ssp, f.sspsc, f.soap, f.journal, f.attendance];
  }

  // =========================
  // Fetch: Hub dashboard (new backend)
  // =========================
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
      final res = await http.post(
        Uri.parse(widget.resolvedHubDataUrl),
        body: {
          'staff_id': widget.staffId,
          'role': widget.role == UserRoleHub.teacher ? 'teacher' : 'therapist',
        },
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to load hub data (HTTP ${res.statusCode})');
      }

      final decoded = json.decode(res.body);
      if (decoded is! List) {
        throw Exception('Unexpected response from server.');
      }

      final loaded = <_HubStudent>[];
      for (final row in decoded) {
        if (row is! Map) continue;

        final studId = (row['stud_id'] ?? row['student_id'] ?? '').toString();
        final name = (row['name'] ?? row['stud_name'] ?? row['student'] ?? '-')
            .toString();
        final dob = (row['dob'] ?? row['stud_dob'] ?? '').toString();
        final branch =
            (row['branch'] ?? row['stud_branch'] ?? row['centre'] ?? '')
                .toString();
        final status =
            (row['status'] ?? row['stud_status'] ?? row['student_status'] ?? '')
                .toString();

        loaded.add(
          _HubStudent(
            studId: studId,
            name: name,
            age: _calculateAgeYearsMonths(dob),
            months: _calculateAgeMonthsTotalString(dob),
            branch: branch,
            status: status,
            flags: _StudentFlags.fromJson(
                Map<String, dynamic>.from(row['flags'] ?? {})),
          ),
        );
      }

      setState(() {
        _all = loaded;
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
  // Bundles for navigation
  // =========================
  Future<List<Map<String, dynamic>>> _fetchFailData({
    required String studId,
    required String screeningId,
  }) async {
    if (screeningId.trim().isEmpty) return [];

    final res = await http.post(
      Uri.parse(widget.resolvedCheckScreeningResultUrl),
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

  Future<Map<String, dynamic>?> _fetchLatestScreeningBundle(
      String studId) async {
    final res = await http.post(
      Uri.parse(widget.resolvedCheckScreeningUrl),
      body: {'stud_id': studId},
    );

    if (res.statusCode != 200) return null;

    final decoded = json.decode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final row = decoded.first;
    if (row is! Map) return null;

    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String toS(dynamic v) => (v ?? '').toString();

    final screeningId =
        toS(row['screening_id'] ?? row['screeningId'] ?? row['id']);
    final screeningDate =
        toS(row['screening_date'] ?? row['date'] ?? row['created_at']);
    final therapistSuggestion = toS(
        row['therapist_suggestion'] ?? row['suggestion'] ?? row['plan'] ?? '');

    final age = toD(row['age']);
    final ageFineMotor = toD(row['age_fine_motor'] ?? row['fine_motor_age']);
    final ageGrossMotor = toD(row['age_gross_motor'] ?? row['gross_motor_age']);
    final agePersonal = toD(row['age_personal'] ?? row['age_personal_social']);
    final ageLanguage = toD(row['age_language'] ?? row['language_age']);

    final failData =
        await _fetchFailData(studId: studId, screeningId: screeningId);

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
      Uri.parse(widget.resolvedCheckSensoryUrl),
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

  Future<String?> _fetchLatestSSPSCId(String studId) async {
    try {
      final res = await http.post(
        Uri.parse(widget.resolvedGetSSPSCHistoryUrl),
        body: {'student_id': studId},
      );
      final decoded = jsonDecode(res.body);
      if (decoded is Map &&
          decoded['status'] == 'success' &&
          decoded['data'] is List &&
          (decoded['data'] as List).isNotEmpty) {
        final first = (decoded['data'] as List).first;
        if (first is Map) {
          final v = first['assessment_id'] ?? first['id'];
          return v?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  // =========================
  // UI helpers
  // =========================
  void _filter(String q) {
    if (q.trim().isEmpty) {
      setState(() {
        _filtered = List.from(_all);
        _selectedIndex = 0;
      });
      return;
    }

    final v = q.toLowerCase();
    setState(() {
      _filtered = _all.where((s) => s.name.toLowerCase().contains(v)).toList();
      _selectedIndex = 0;
    });
  }

  void _selectStudent(int i) {
    if (i >= 0 && i < _filtered.length) setState(() => _selectedIndex = i);
  }

  void _applyInitialStudentIfAny() {
    if (widget.initialStudId != null && _filtered.isNotEmpty) {
      final i = _filtered.indexWhere((x) => x.studId == widget.initialStudId);
      if (i >= 0) setState(() => _selectedIndex = i);
      widget.onConsumedInitial?.call();
    }
  }

  String _calculateAgeYearsMonths(String dob) {
    if (dob.isEmpty) return '-';
    try {
      final d = DateTime.parse(dob);
      final n = DateTime.now();
      var m = (n.year - d.year) * 12 + (n.month - d.month);
      if (n.day < d.day) m--;
      if (m < 0) m = 0;
      return '${m ~/ 12} yrs ${m % 12} mo';
    } catch (_) {
      return '-';
    }
  }

  String _calculateAgeMonthsTotalString(String dob) {
    if (dob.isEmpty) return '0 mo';
    try {
      final d = DateTime.parse(dob);
      final n = DateTime.now();
      var m = (n.year - d.year) * 12 + (n.month - d.month);
      if (n.day < d.day) m--;
      if (m < 0) m = 0;
      return '$m mo';
    } catch (_) {
      return '0 mo';
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
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    final sel = _filtered.isEmpty
        ? null
        : _filtered[_selectedIndex.clamp(0, _filtered.length - 1)];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        title: const Text(
          'Student Hub',
          style: TextStyle(color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: _isDesktop ? 10 : 1.w),
            child: InkWell(
              child: IconButton(
                onPressed: _loading ? null : _refresh,
                icon: Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: _isDesktop ? 25 : 2.5.h,
                ),
              ),
            ),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Padding(
                  padding: EdgeInsets.all(_isDesktop ? 16 : 1.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: Colors.red.withValues(alpha: 0.8)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black
                                            .withValues(alpha: 0.75)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: _isDesktop ? 10 : 1.h),
                      Expanded(
                        child: _isWide
                            ? Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    width: _leftCollapsed
                                        ? (_isDesktop ? 82 : 100)
                                        : (_isDesktop ? 380 : 360),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: _buildStudentListPanel(wide: true),
                                    ),
                                  ),
                                  SizedBox(width: _isDesktop ? 14 : 1.2.w),
                                  Expanded(
                                    child: sel == null
                                        ? _EmptyState(
                                            text: _loading
                                                ? 'Loading…'
                                                : 'No student found.')
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
            ),
          );
        },
      ),
    );
  }

  // =========================
  // LEFT PANEL
  // =========================
  Widget _buildStudentListPanel({required bool wide}) {
    return Container(
      padding: !_leftCollapsed
          ? EdgeInsets.all(_isDesktop ? 16 : 1.6.h)
          : EdgeInsets.all(_isDesktop ? 10 : 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          if (_leftCollapsed)
            Center(
              child: IconButton(
                tooltip: 'Expand',
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: _isDesktop ? 25 : 2.5.h,
                ),
                onPressed: () => setState(() => _leftCollapsed = false),
              ),
            )
          else
            Row(
              children: [
                Text(
                  'Students',
                  style: TextStyle(
                    fontSize: _isDesktop ? 16 : 14.sp,
                    fontWeight:
                        _isDesktop ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (_isDesktop) ...[
                  const SizedBox(width: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Growkids.purple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _filtered.length.toString(),
                      style: const TextStyle(
                        color: Growkids.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Collapse',
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: _isDesktop ? 25 : 2.5.h,
                  ),
                  onPressed: () => setState(() => _leftCollapsed = true),
                ),
              ],
            ),
          if (!_leftCollapsed) ...[
            SizedBox(height: _isDesktop ? 10 : 1.h),
            TextField(
              style: TextStyle(fontSize: _isDesktop ? 14 : 14.sp),
              controller: _searchCtrl,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search student...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Growkids.purple.withValues(alpha: 0.08),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Growkids.purple.withValues(alpha: 0.6)),
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
                      style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontSize: _isDesktop ? 14 : 14.sp),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      final selected = i == _selectedIndex;

                      if (_leftCollapsed) {
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: _isDesktop ? 2 : 0.2.h,
                          ),
                          child: InkWell(
                            onTap: () => _selectStudent(i),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Growkids.purple.withValues(alpha: 0.10)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Growkids.purple
                                          .withValues(alpha: 0.12),
                                      child: Text(
                                        s.name.isNotEmpty
                                            ? s.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: Growkids.purple,
                                          fontSize: _isDesktop ? 14 : 14.sp,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: _StatusDot(
                                          states:
                                              _summaryStatesForRole(s.flags)),
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
                            padding: EdgeInsets.all(_isDesktop ? 14 : 1.4.h),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Growkids.purple.withValues(
                                      alpha: _isDesktop ? 0.10 : 0.08)
                                  : const Color(0xFFF8F9FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isDesktop && selected
                                    ? Growkids.purple.withValues(alpha: 0.38)
                                    : Colors.black.withValues(alpha: 0.06),
                                width: _isDesktop && selected ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_isDesktop) ...[
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Growkids.purple
                                            .withValues(alpha: 0.12),
                                        child: Text(
                                          s.name.isNotEmpty
                                              ? s.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Growkids.purple,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -3,
                                        bottom: -3,
                                        child: _StatusDot(
                                          states:
                                              _summaryStatesForRole(s.flags),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: _isDesktop ? 14 : 14.sp,
                                        ),
                                      ),
                                      SizedBox(height: _isDesktop ? 4 : 0.3.h),
                                      Text(
                                        s.age,
                                        style: TextStyle(
                                            fontSize: _isDesktop ? 12 : 12.sp,
                                            color: Colors.black
                                                .withValues(alpha: 0.6)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: Colors.black.withValues(alpha: 0.35),
                                    size: _isDesktop ? 28 : 3.h),
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
    final isTeacher = widget.role == UserRoleHub.teacher;
    final soapApplicable = !isTeacher && s.isOfficial;

    final denverDone = s.flags.denver == _WorkState.done;
    final denverOngoing = s.flags.denver == _WorkState.draft;

    final canResult = denverDone;
    final canSensory = s.flags.ssp == _WorkState.done;
    final canSSPSC = s.flags.sspsc == _WorkState.done;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: EdgeInsets.all(_isDesktop ? 20 : 2.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Growkids.purpleFlo,
                Growkids.purpleFlo.withValues(alpha: .70),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
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
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Growkids.purple,
                    fontSize: _isDesktop ? 20 : 16.sp,
                  ),
                ),
              ),
              SizedBox(width: _isDesktop ? 16 : 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        fontSize: _isDesktop ? 20 : 16.sp,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: _isDesktop ? 4 : 0.3.h),
                    Text(
                      s.age,
                      style: TextStyle(
                          fontSize: _isDesktop ? 14 : 14.sp,
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _isDesktop ? 14 : 1.4.h),

        // Checklist (UI kekal)
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isDesktop) ...[
                const Text(
                  'Assessment overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 680 ? 3 : 2;
                    final tileWidth =
                        (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _ChecklistRow(
                            compact: true,
                            label: 'Denver',
                            state: s.flags.denver,
                            overrideText: isTeacher
                                ? 'Not Applicable'
                                : denverOngoing
                                    ? 'Ongoing'
                                    : null,
                            overrideColor:
                                isTeacher ? const Color(0xFF9CA3AF) : null,
                            overrideIcon: isTeacher
                                ? Icons.do_not_disturb_on_rounded
                                : null,
                            useOverrideOnlyWhenNotDone: !isTeacher,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _ChecklistRow(
                            compact: true,
                            label: 'Sensory Profile',
                            state: _WorkState.todo,
                            overrideText: isTeacher ? 'Not Applicable' : null,
                            overrideColor:
                                isTeacher ? const Color(0xFF9CA3AF) : null,
                            overrideIcon: isTeacher
                                ? Icons.do_not_disturb_on_rounded
                                : null,
                            stateForTherapist: isTeacher ? null : s.flags.ssp,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _ChecklistRow(
                            compact: true,
                            label: 'SSPSC',
                            state: s.flags.sspsc,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _ChecklistRow(
                            compact: true,
                            label: 'Journal',
                            state: s.flags.journal,
                            overrideText: 'Ongoing',
                            overrideIcon: Icons.edit_rounded,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _ChecklistRow(
                            compact: true,
                            label: 'SOAP',
                            state: s.flags.soap,
                            overrideText:
                                soapApplicable ? 'Ongoing' : 'Not Applicable',
                            overrideColor:
                                soapApplicable ? null : const Color(0xFF9CA3AF),
                            overrideIcon: soapApplicable
                                ? null
                                : Icons.do_not_disturb_on_rounded,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ] else ...[
                _ChecklistRow(
                  label: 'Denver',
                  state: s.flags.denver,
                  overrideText: isTeacher
                      ? 'Not Applicable'
                      : denverOngoing
                          ? 'Ongoing'
                          : null,
                  overrideColor: isTeacher ? const Color(0xFF9CA3AF) : null,
                  overrideIcon:
                      isTeacher ? Icons.do_not_disturb_on_rounded : null,
                  useOverrideOnlyWhenNotDone: !isTeacher,
                ),
                _ChecklistRow(
                  label: 'Sensory Profile',
                  state: _WorkState.todo,
                  overrideText: isTeacher ? 'Not Applicable' : null,
                  overrideColor: isTeacher ? const Color(0xFF9CA3AF) : null,
                  overrideIcon:
                      isTeacher ? Icons.do_not_disturb_on_rounded : null,
                  stateForTherapist: isTeacher ? null : s.flags.ssp,
                ),
                _ChecklistRow(label: 'SSPSC', state: s.flags.sspsc),
                _ChecklistRow(
                  label: 'Journal',
                  state: s.flags.journal,
                  overrideText: 'Ongoing',
                  overrideIcon: Icons.edit_rounded,
                ),
                _ChecklistRow(
                  label: 'SOAP',
                  state: s.flags.soap,
                  overrideText: soapApplicable ? 'Ongoing' : 'Not Applicable',
                  overrideColor:
                      soapApplicable ? null : const Color(0xFF9CA3AF),
                  overrideIcon:
                      soapApplicable ? null : Icons.do_not_disturb_on_rounded,
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: _isDesktop ? 14 : 1.4.h),

        // Student Tools (UI kekal)
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnCount = _isDesktop
                      ? constraints.maxWidth >= 680
                          ? 3
                          : constraints.maxWidth >= 500
                              ? 2
                              : 1
                      : (_leftCollapsed ? 2 : 1);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columnCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: _isDesktop
                        ? columnCount == 3
                            ? 2.55
                            : columnCount == 2
                                ? 3.0
                                : 4.2
                        : (_leftCollapsed ? 3 : 4),
                    children: [
                      _ActionTile(
                        title: 'Profile',
                        subtitle: null,
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
                        title: 'Denver Result',
                        subtitle: null,
                        icon: Icons.assessment_rounded,
                        accent: const Color(0xFF0AAE7A),
                        disabled: isTeacher ? true : !canResult,
                        onTap: () async {
                          if (isTeacher) return;

                          final bundle =
                              await _fetchLatestScreeningBundle(s.studId);
                          if (!context.mounted) return;
                          if (bundle == null ||
                              (bundle['screeningId'] ?? '')
                                  .toString()
                                  .isEmpty) {
                            _snack('No screening data found.');
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScreeningResult(
                                studentId: s.studId,
                                studentName: s.name,
                                age: (bundle['age'] as double),
                                ageFineMotor:
                                    (bundle['ageFineMotor'] as double),
                                ageGrossMotor:
                                    (bundle['ageGrossMotor'] as double),
                                agePersonal: (bundle['agePersonal'] as double),
                                ageLanguage: (bundle['ageLanguage'] as double),
                                therapist_suggestion:
                                    bundle['therapistSuggestion'],
                                screeningId: bundle['screeningId'],
                                screeningDate: bundle['screeningDate'],
                              ),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        title: 'SSP Result',
                        subtitle: null,
                        icon: Icons.psychology_rounded,
                        accent: const Color(0xFF8B5CF6),
                        disabled: isTeacher ? true : !canSensory,
                        onTap: () async {
                          if (isTeacher) return;

                          final assessmentId =
                              await _fetchSensoryAssessmentId(s.studId);
                          if (!context.mounted) return;
                          if (assessmentId == null) {
                            _snack('No sensory assessment found yet.');
                            return;
                          }

                          final monthsInt = _monthsIntFromString(s.months);
                          if (monthsInt >= 37) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SensoryProfileResult2(
                                  assessmentId: assessmentId,
                                  studName: s.name,
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SensoryProfileResult(
                                  assessmentId: assessmentId,
                                  studName: s.name,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _ActionTile(
                        title: 'SSPSC Result',
                        subtitle: null,
                        icon: Icons.psychology_rounded,
                        accent: const Color(0xFF8B5CF6),
                        disabled: !canSSPSC,
                        onTap: () async {
                          final id = await _fetchLatestSSPSCId(s.studId);
                          if (!context.mounted) return;
                          if (id == null || id.isEmpty) {
                            _snack('No SSPSC assessment found yet.');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SSPSCResult(
                                assessmentId: id,
                                studentName: s.name,
                              ),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        title: 'Journal History',
                        subtitle: null,
                        icon: Icons.menu_book_rounded,
                        accent: const Color(0xFFEC4899),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentJournalPage(
                                studentName: s.name,
                                teacherId: id,
                                studentId: s.studId,
                              ),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        title: 'Home Program',
                        subtitle: null,
                        icon: Icons.home_work_rounded,
                        accent: const Color(0xFF14B8A6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentHomeProgramPage(
                                studentId: s.studId,
                                studentName: s.name,
                                therapistId: widget.staffId,
                              ),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        title: 'SOAP History',
                        subtitle: null,
                        icon: Icons.description_rounded,
                        accent: const Color(0xFF111827),
                        disabled: !soapApplicable,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SoapReportListPage(
                                therapistId: id, // dari session/user
                                studId: s.studId,
                              ),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        title: 'Attendance History',
                        subtitle: null,
                        icon: Icons.how_to_reg_rounded,
                        accent: const Color(0xFF3B82F6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentAttendanceHistoryPage(
                                studId: s.studId,
                                studentName: s.name,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your students',
                      style: TextStyle(
                        color: Color(0xFF252733),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Select a student to view records and tools.',
                      style: TextStyle(
                        color: Color(0xFF7D8290),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_filtered.length}',
                  style: const TextStyle(
                    color: Growkids.purpleFlo,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by student name',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Growkids.purpleFlo,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F5FF),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Growkids.purple.withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? _EmptyState(text: _loading ? 'Loading…' : 'No student found.')
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
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
                                builder: (_) => _buildPhoneDetailPage(s),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(1.4.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.06)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF26324A)
                                      .withValues(alpha: .05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Growkids.purpleFlo
                                          .withValues(alpha: .10),
                                      child: Text(
                                        s.name.isNotEmpty
                                            ? s.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Growkids.purple),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: _StatusDot(
                                          states:
                                              _summaryStatesForRole(s.flags)),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF292B35),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 0.3.h),
                                      Text(
                                        '${s.age}  |  ${s.isOfficial ? 'Official' : s.status}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF7D8290),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color:
                                        Colors.black.withValues(alpha: 0.35)),
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

  Widget _buildPhoneDetailPage(_HubStudent student) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Student details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildDetailPanel(student),
        ),
      ),
    );
  }
}

// ==========================
// PHONE DETAIL PAGE (UI style kekal; checklist rules ikut flags baru)
/// Note: Page ni "light" (tiada tools grid).
// ==========================
class _StudentDetailPhonePage extends StatelessWidget {
  final _HubStudent student;
  final UserRoleHub role;
  const _StudentDetailPhonePage({required this.student, required this.role});

  @override
  Widget build(BuildContext context) {
    final isTeacher = role == UserRoleHub.teacher;
    final soapApplicable = !isTeacher && student.isOfficial;

    final denverOngoing = student.flags.denver == _WorkState.draft;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(student.name),
        backgroundColor: Growkids.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(3.w),
        child: ListView(
          children: [
            Container(
              padding: EdgeInsets.all(1.6.h),
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
                      student.name.isNotEmpty
                          ? student.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: Growkids.purple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          student.age,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85)),
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
                  _ChecklistRow(
                    label: 'Denver',
                    state: student.flags.denver,
                    overrideText: isTeacher
                        ? 'Not Applicable'
                        : denverOngoing
                            ? 'Ongoing'
                            : null,
                    overrideColor: isTeacher ? const Color(0xFF9CA3AF) : null,
                    overrideIcon:
                        isTeacher ? Icons.do_not_disturb_on_rounded : null,
                  ),
                  _ChecklistRow(
                    label: 'Sensory Profile',
                    state: _WorkState.todo,
                    overrideText: isTeacher ? 'Not Applicable' : null,
                    overrideColor: isTeacher ? const Color(0xFF9CA3AF) : null,
                    overrideIcon:
                        isTeacher ? Icons.do_not_disturb_on_rounded : null,
                    stateForTherapist: isTeacher ? null : student.flags.ssp,
                  ),
                  _ChecklistRow(
                    label: 'SSPSC',
                    state: student.flags.sspsc,
                  ),
                  _ChecklistRow(
                    label: 'Journal',
                    state: student.flags.journal,
                    overrideText: 'Ongoing',
                    overrideIcon: Icons.edit_rounded,
                  ),
                  _ChecklistRow(
                    label: 'SOAP',
                    state: student.flags.soap,
                    overrideText: soapApplicable ? 'Ongoing' : 'Not Applicable',
                    overrideColor:
                        soapApplicable ? null : const Color(0xFF9CA3AF),
                    overrideIcon:
                        soapApplicable ? null : Icons.do_not_disturb_on_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              title: 'Home Program',
              subtitle: null,
              icon: Icons.home_work_rounded,
              accent: const Color(0xFF14B8A6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentHomeProgramPage(
                      studentId: student.studId,
                      studentName: student.name,
                      therapistId: id,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================
// UI atoms (UI style unchanged)
// ==========================
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isNativeDesktop(context);
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;

  /// subtitle optional (if null -> not rendered)
  final String? subtitle;

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
    final isDesktop = _isNativeDesktop(context);

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 10 : 1.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: isDesktop ? 48 : 5.h,
                width: isDesktop ? 52 : 7.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: isDesktop ? 28 : 3.h,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 2.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: isDesktop ? 14 : 14.sp),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.black.withValues(alpha: 0.35),
                size: isDesktop ? 28 : 3.h,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;

  /// Base state (used if no stateForTherapist)
  final _WorkState state;

  /// Therapist-only state override (used for Sensory Profile)
  final _WorkState? stateForTherapist;

  /// Override label text (e.g. "Ongoing", "Not Applicable")
  final String? overrideText;

  /// Override icon (e.g. Not Applicable icon)
  final IconData? overrideIcon;

  /// Override color (e.g. grey)
  final Color? overrideColor;

  /// Only show override when not done
  final bool useOverrideOnlyWhenNotDone;
  final bool compact;

  const _ChecklistRow({
    required this.label,
    required this.state,
    this.stateForTherapist,
    this.overrideText,
    this.overrideIcon,
    this.overrideColor,
    this.useOverrideOnlyWhenNotDone = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final actualState = stateForTherapist ?? state;
    final isDesktop = _isNativeDesktop(context);

    IconData icon;
    String text;
    Color color;

    switch (actualState) {
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

    final shouldOverride = overrideText != null &&
        (!useOverrideOnlyWhenNotDone || actualState != _WorkState.done);

    if (shouldOverride) {
      text = overrideText!;
      if (overrideIcon != null) icon = overrideIcon!;
      if (overrideColor != null) {
        color = overrideColor!;
      } else {
        if (text.toLowerCase() == 'ongoing') {
          color = Colors.orange;
          icon = overrideIcon ?? Icons.edit_rounded;
        }
      }
    }

    final content = Row(
      children: [
        CircleAvatar(
          radius: compact ? 17 : (isDesktop ? 20 : 2.h),
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            icon,
            size: compact ? 17 : (isDesktop ? 20 : 2.h),
            color: color,
          ),
        ),
        SizedBox(width: isDesktop ? 10 : 1.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 13 : (isDesktop ? 14 : 14.sp),
                  fontWeight: compact ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (compact) ...[
                const SizedBox(height: 3),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: isDesktop ? 12 : 12.sp,
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),
      ],
    );

    if (compact) {
      return Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: content,
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
    final isDesktop = _isNativeDesktop(context);
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: isDesktop ? 13 : 13.sp,
          color: Colors.black.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
