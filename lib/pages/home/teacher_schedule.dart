import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import 'add_daily_progress.dart';
import 'view_daily_progress.dart';

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
  static const _childrenUrl = 'https://app.kizzukids.com.my/growkids/flutter/student_school.php';

  // ✅ USE EXISTING endpoint (status by date)
  // teacher_progress_today.php accepts: teacher_id, log_date (defaults to today if not given)
  static const _statusUrl = 'https://app.kizzukids.com.my/growkids/flutter/teacher_progress_today.php';

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
    return Container(
      color: const Color(0xFFF6F7FB),
      child: RefreshIndicator(
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
                      SizedBox(
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
                              color: Colors.black.withOpacity(0.55),
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

                final progressId = (_row(studId)?['progress_id'] ?? '').toString();

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
                            progressId: hasProgress ? progressId : null,
                          ),
                        ),
                      );

                      if (changed == true) {
                        _fetchStatusForDate(selectedDate);
                      }
                    },
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
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
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                    color: Colors.black.withOpacity(0.55),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Growkids.purpleFlo.withOpacity(0.6)),
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
        ? const Color(0xFF0AAE7A).withOpacity(0.10)
        : isDraft
            ? Colors.amber.withOpacity(0.16)
            : Colors.red.withOpacity(0.12);

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
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 3.h,
              backgroundColor: done ? const Color(0xFF0AAE7A).withOpacity(0.12) : Growkids.purpleFlo.withOpacity(0.12),
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
                  Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.sp)),
                  SizedBox(height: 0.5.h),
                  Text(branch,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black.withOpacity(0.55),
                            fontSize: 12.sp,
                          )),
                  if (updatedText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(updatedText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black.withOpacity(0.50),
                              fontSize: 12.sp,
                            )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
              decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(999)),
              child: Text(pillLabel, style: TextStyle(fontSize: 14.sp, color: pillText)),
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
        color: tint.withOpacity(0.10),
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
              Text(value, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
              Text(label, style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 14.sp)),
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
              color: Colors.black.withOpacity(0.55),
              fontSize: 14.sp,
            ),
      ),
    );
  }
}
