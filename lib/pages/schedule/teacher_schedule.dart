import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../journal/add_daily_progress.dart';
import '../journal/view_daily_progress.dart';

bool _useDesktopTeacherScheduleLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class TeacherSchedulePage extends StatefulWidget {
  final String teacherId;

  const TeacherSchedulePage({
    super.key,
    required this.teacherId,
  });

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  // ✅ student list endpoint (assigned to teacher)
  static final String _childrenUrl = ApiConfig.flutter('student_school.php');
  /*static const _childrenUrl =
      'http://app-kizzu.test/growkids/flutter/student_school.php';*/

  // ✅ USE EXISTING endpoint (status by date)
  // teacher_progress_today.php accepts: teacher_id, log_date (defaults to today if not given)
  static final String _statusUrl =
      ApiConfig.flutter('teacher_progress_today.php');
  /*static const _statusUrl =
      'http://app-kizzu.test/growkids/flutter/teacher_progress_today.php';*/

  bool loading = true;
  bool statusLoading = true;

  List<Map<String, dynamic>> students = [];

  /// stud_id -> row from teacher_progress_today.php
  /// row contains: progress_id, stud_id, teacher_id, log_date, status, updated_at, etc
  Map<String, Map<String, dynamic>> statusByStudId = {};

  DateTime selectedDate = DateTime.now();
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _bootstrap() async {
    await _fetchStudents();
    await _fetchStatusForDate(selectedDate);
  }

  Future<void> _fetchStudents() async {
    if (widget.teacherId.isEmpty) {
      setState(() {
        loading = false;
        students = [];
      });
      return;
    }

    try {
      final res = await http.post(
        Uri.parse(_childrenUrl),
        body: {"teacher_id": widget.teacherId},
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => loading = false);
        return;
      }

      final decoded = json.decode(res.body);
      final List data = decoded is List ? decoded : [];

      setState(() {
        students = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _fetchStatusForDate(DateTime date) async {
    setState(() {
      statusLoading = true;
      statusByStudId = {};
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_day(date));

      final res = await http.post(
        Uri.parse(_statusUrl),
        body: {
          "teacher_id": widget.teacherId,
          "log_date": dateStr, // ✅ endpoint expects log_date
        },
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => statusLoading = false);
        return;
      }

      final decoded = json.decode(res.body);

      // Your PHP returns: respond(true, $out, 200);
      // so decoded is List, not {"success":true,"data":[...]}
      final List data = decoded is List ? decoded : [];

      final map = <String, Map<String, dynamic>>{};
      for (final item in data) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final id = (m['stud_id'] ?? '').toString();
          if (id.isNotEmpty) map[id] = m;
        }
      }

      setState(() {
        statusByStudId = map;
        statusLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => statusLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    await _fetchStudents();
    await _fetchStatusForDate(selectedDate);
  }

  void _changeDate(DateTime d) async {
    setState(() => selectedDate = _day(d));
    await _fetchStatusForDate(selectedDate);
  }

  Map<String, dynamic>? _row(String studId) => statusByStudId[studId];

  // ✅ BACKEND STATUS: Draft / Submit
  bool _isSubmit(String studId) {
    final r = _row(studId);
    if (r == null) return false;
    final st = (r['status'] ?? '').toString().trim().toLowerCase();
    return st == 'submit' || st == 'submitted';
  }

  bool _isDraft(String studId) {
    final r = _row(studId);
    if (r == null) return false;
    final st = (r['status'] ?? '').toString().trim().toLowerCase();
    return st == 'draft';
  }

  bool _hasProgress(String studId) {
    final r = _row(studId);
    if (r == null) return false;
    final pid = (r['progress_id'] ?? '').toString();
    return pid.isNotEmpty;
  }

  String _updatedAtText(String studId) {
    final r = _row(studId);
    if (r == null) return '';
    final raw = (r['updated_at'] ?? '').toString();
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (dt == null) return 'Updated';
    return 'Updated ${DateFormat('h:mma').format(dt)}';
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final q = searchCtrl.text.trim().toLowerCase();

    final list = students.where((s) {
      if (q.isEmpty) return true;
      final name = (s['stud_name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();

    // sort: pending first (not Submit), then name
    list.sort((a, b) {
      final aId = (a['stud_id'] ?? '').toString();
      final bId = (b['stud_id'] ?? '').toString();

      final aDone = _isSubmit(aId);
      final bDone = _isSubmit(bId);

      if (aDone != bDone) return aDone ? 1 : -1;

      final aName = (a['stud_name'] ?? '').toString();
      final bName = (b['stud_name'] ?? '').toString();
      return aName.compareTo(bName);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopTeacherScheduleLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            _buildTopBar(),
            SizedBox(height: 1.h),
            _buildDateAndSummary(),
            SizedBox(height: 1.2.h),
            _buildSearch(),
            SizedBox(height: 1.2.h),
            if (loading) ...[
              const SizedBox(height: 60),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 60),
            ] else if (students.isEmpty) ...[
              const _EmptyState(text: 'No students found for this teacher.'),
            ] else ...[
              if (statusLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Growkids.purpleFlo,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Checking progress status…',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black.withValues(alpha: 0.55),
                              fontSize: 14.sp,
                            ),
                      )
                    ],
                  ),
                ),
              ..._filteredStudents.map((s) {
                final studId = (s['stud_id'] ?? '').toString();

                final done = _isSubmit(studId);
                final draft = _isDraft(studId);
                final hasProgress = _hasProgress(studId);

                final progressId =
                    (_row(studId)?['progress_id'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TeacherChecklistTile(
                    student: s,
                    done: done,
                    isDraft: draft,
                    updatedText: _updatedAtText(studId),
                    onTap: () async {
                      // ✅ If Submit -> View
                      if (done && progressId.isNotEmpty) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewDailyProgressPage(
                              progressId: progressId,
                              teacherId: widget.teacherId,
                            ),
                          ),
                        );
                        return;
                      }

                      // ✅ Draft OR Not done -> open Add/Edit
                      final changed = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddDailyProgressPage(
                            studId: studId,
                            studentName: (s['stud_name'] ?? '').toString(),
                            teacherId: widget.teacherId,
                            //progressId: hasProgress ? progressId : null,
                          ),
                        ),
                      );

                      if (changed == true) {
                        _fetchStatusForDate(selectedDate);
                      }
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    var submitted = 0;
    var drafts = 0;
    for (final student in students) {
      final id = (student['stud_id'] ?? '').toString();
      if (_isSubmit(id)) submitted++;
      if (_isDraft(id)) drafts++;
    }
    final pending = (students.length - submitted).clamp(0, students.length);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Schedule',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
            child: Column(
              children: [
                _desktopTeacherHero(submitted, drafts, pending),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE3E6EC)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeDate(
                          selectedDate.subtract(const Duration(days: 1)),
                        ),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      InkWell(
                        onTap: _desktopPickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Growkids.purpleFlo.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                color: Growkids.purpleFlo,
                                size: 18,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                DateFormat('EEEE, d MMMM yyyy')
                                    .format(selectedDate),
                                style: TextStyle(
                                  color: Growkids.purpleFlo,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeDate(
                          selectedDate.add(const Duration(days: 1)),
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 330,
                        height: 42,
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 10),
                          decoration: InputDecoration(
                            hintText: 'Search student...',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF7F8FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Growkids.purpleFlo,
                          ),
                        )
                      : students.isEmpty
                          ? const _DesktopTeacherScheduleEmpty()
                          : statusLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Growkids.purpleFlo,
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisExtent: 142,
                                    crossAxisSpacing: 13,
                                    mainAxisSpacing: 13,
                                  ),
                                  itemCount: _filteredStudents.length,
                                  itemBuilder: (_, index) {
                                    final student = _filteredStudents[index];
                                    final id =
                                        (student['stud_id'] ?? '').toString();
                                    return _DesktopTeacherScheduleCard(
                                      student: student,
                                      done: _isSubmit(id),
                                      draft: _isDraft(id),
                                      updatedText: _updatedAtText(id),
                                      onTap: () =>
                                          _openStudentProgress(student),
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

  Widget _desktopTeacherHero(int submitted, int drafts, int pending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .76),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.today_rounded,
              color: Growkids.purpleFlo,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY STUDENT PROGRESS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Teacher Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete or review each student’s daily journal.',
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
          _desktopTeacherMetric(
            'Submitted',
            submitted,
            const Color(0xFF8EE7BC),
          ),
          const SizedBox(width: 8),
          _desktopTeacherMetric(
            'Draft',
            drafts,
            const Color(0xFFFFD68A),
          ),
          const SizedBox(width: 8),
          _desktopTeacherMetric(
            'Pending',
            pending,
            const Color(0xFFFFAEB4),
          ),
        ],
      ),
    );
  }

  Widget _desktopTeacherMetric(String label, int value, Color accent) {
    return Container(
      width: 94,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 7),
          ),
        ],
      ),
    );
  }

  Future<void> _desktopPickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) _changeDate(picked);
  }

  Future<void> _openStudentProgress(Map<String, dynamic> student) async {
    final studId = (student['stud_id'] ?? '').toString();
    final done = _isSubmit(studId);
    final progressId = (_row(studId)?['progress_id'] ?? '').toString();

    if (done && progressId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewDailyProgressPage(
            progressId: progressId,
            teacherId: widget.teacherId,
          ),
        ),
      );
      return;
    }

    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDailyProgressPage(
          studId: studId,
          studentName: (student['stud_name'] ?? '').toString(),
          teacherId: widget.teacherId,
        ),
      ),
    );
    if (changed == true) _fetchStatusForDate(selectedDate);
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Text(
          'Schedule',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 16.sp,
              ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _refresh,
          icon: Icon(Icons.refresh_rounded, size: 3.h),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildDateAndSummary() {
    final d = _day(selectedDate);
    final dateText = DateFormat('EEE, d MMM yyyy').format(d);

    int submittedCount = 0;
    int draftCount = 0;

    for (final s in students) {
      final id = (s['stud_id'] ?? '').toString();
      if (_isSubmit(id)) submittedCount++;
      if (_isDraft(id)) draftCount++;
    }

    final total = students.length;
    final pending = (total - submittedCount).clamp(0, total);

    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16.sp,
                    ),
              ),
              const Spacer(),
              _MiniDateNav(
                onPrev: () => _changeDate(d.subtract(const Duration(days: 1))),
                onNext: () => _changeDate(d.add(const Duration(days: 1))),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Submitted',
                  value: '$submittedCount',
                  icon: Icons.check_circle_rounded,
                  tint: const Color(0xFF0AAE7A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Pending',
                  value: '$pending',
                  icon: Icons.pending_actions_rounded,
                  tint: Growkids.purpleFlo,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.0.h),
          if (draftCount > 0)
            Text(
              'Drafts: $draftCount (not submitted yet)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12.sp,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: searchCtrl,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: 14.sp, color: Colors.black87),
      decoration: InputDecoration(
        hintText: 'Search student...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: Growkids.purpleFlo.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

// =================== UI bits ===================

class _TeacherChecklistTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool done; // Submit
  final bool isDraft; // Draft
  final String updatedText;
  final VoidCallback onTap;

  const _TeacherChecklistTile({
    required this.student,
    required this.done,
    required this.isDraft,
    required this.updatedText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (student['stud_name'] ?? '-').toString();
    final branch = (student['stud_branch'] ?? '').toString();

    final pillLabel = done
        ? 'Submitted'
        : isDraft
            ? 'Draft'
            : 'Pending';

    final pillBg = done
        ? const Color(0xFF0AAE7A).withValues(alpha: 0.10)
        : isDraft
            ? Colors.amber.withValues(alpha: 0.16)
            : Colors.red.withValues(alpha: 0.12);

    final pillText = done
        ? const Color(0xFF0AAE7A)
        : isDraft
            ? Colors.amber[900]!
            : Colors.red;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 3.h,
              backgroundColor: done
                  ? const Color(0xFF0AAE7A).withValues(alpha: 0.12)
                  : Growkids.purpleFlo.withValues(alpha: 0.12),
              child: Icon(
                done ? Icons.check_rounded : Icons.edit_note_rounded,
                size: 3.h,
                color: done ? const Color(0xFF0AAE7A) : Growkids.purpleFlo,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 14.sp)),
                  SizedBox(height: 0.5.h),
                  Text(branch,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black.withValues(alpha: 0.55),
                            fontSize: 12.sp,
                          )),
                  if (updatedText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(updatedText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black.withValues(alpha: 0.50),
                              fontSize: 12.sp,
                            )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
              decoration: BoxDecoration(
                  color: pillBg, borderRadius: BorderRadius.circular(999)),
              child: Text(pillLabel,
                  style: TextStyle(fontSize: 14.sp, color: pillText)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDateNav extends StatelessWidget {
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MiniDateNav({required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: Icon(Icons.chevron_left_rounded, size: 3.h),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(Icons.chevron_right_rounded, size: 3.h),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(1.6.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 3.h,
            backgroundColor: Colors.white,
            child: Icon(icon, color: tint, size: 3.h),
          ),
          SizedBox(width: 2.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style:
                      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
              Text(label,
                  style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                      fontSize: 14.sp)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.55),
              fontSize: 14.sp,
            ),
      ),
    );
  }
}

class _DesktopTeacherScheduleCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool done;
  final bool draft;
  final String updatedText;
  final VoidCallback onTap;

  const _DesktopTeacherScheduleCard({
    required this.student,
    required this.done,
    required this.draft,
    required this.updatedText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (student['stud_name'] ?? '-').toString();
    final branch = (student['stud_branch'] ?? '').toString();
    final color = done
        ? const Color(0xFF16A36D)
        : draft
            ? const Color(0xFFD7900B)
            : const Color(0xFFE0525E);
    final label = done
        ? 'Submitted'
        : draft
            ? 'Draft'
            : 'Pending';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE3E6EC)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.edit_note_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3E414C),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (branch.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      branch,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF898E9A),
                        fontSize: 8,
                      ),
                    ),
                  ],
                  if (updatedText.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      updatedText,
                      style: const TextStyle(
                        color: Color(0xFF9A9EAA),
                        fontSize: 7,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9A9EAA),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopTeacherScheduleEmpty extends StatelessWidget {
  const _DesktopTeacherScheduleEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: Color(0xFFB0B4BF),
            size: 46,
          ),
          SizedBox(height: 10),
          Text(
            'No students found for this teacher.',
            style: TextStyle(color: Color(0xFF8B8F9C), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
