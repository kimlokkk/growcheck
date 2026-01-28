import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import 'add_daily_progress.dart';
import 'view_daily_progress.dart';

enum _TeacherTab { today, pending, recent }

class TeacherTask {
  final String studId;
  final String name;
  final String age;
  final String branch;

  /// not_done | draft | done
  final String status;

  final DateTime? updatedAt;
  final String? progressId;

  /// show date on tile (clear no confusion)
  final DateTime? logDate;

  TeacherTask({
    required this.studId,
    required this.name,
    required this.age,
    required this.branch,
    required this.status,
    this.updatedAt,
    this.progressId,
    this.logDate,
  });
}

class TeacherActivityPage extends StatefulWidget {
  final String teacherId;

  const TeacherActivityPage({super.key, required this.teacherId});

  @override
  State<TeacherActivityPage> createState() => _TeacherActivityPageState();
}

class _TeacherActivityPageState extends State<TeacherActivityPage> {
  _TeacherTab tab = _TeacherTab.today;
  bool loading = true;

  // ===== ENDPOINTS =====
  static const _studentsUrl = 'https://app.kizzukids.com.my/growkids/flutter/student_school.php';
  static const _todayUrl = 'https://app.kizzukids.com.my/growkids/flutter/teacher_progress_today.php';
  static const _recentUrl = 'https://app.kizzukids.com.my/growkids/flutter/teacher_progress_recent.php';

  // ===== DATA =====
  List<TeacherTask> todayTasks = [];
  List<TeacherTask> pendingTasks = [];
  List<TeacherTask> recentTasks = [];

  int todayCount = 0;
  int pendingCount = 0;
  int doneCount = 0;

  Future<List<Map<String, dynamic>>> _fetchAssignedStudents() async {
    final res = await http.post(
      Uri.parse(_studentsUrl),
      body: {'teacher_id': widget.teacherId},
    );
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(json.decode(res.body));
  }

  Future<List<Map<String, dynamic>>> _fetchTodayProgress() async {
    final res = await http.post(
      Uri.parse(_todayUrl),
      body: {'teacher_id': widget.teacherId},
    );
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(json.decode(res.body));
  }

  Future<List<Map<String, dynamic>>> _fetchRecentProgress() async {
    final res = await http.post(
      Uri.parse(_recentUrl),
      body: {'teacher_id': widget.teacherId},
    );
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(json.decode(res.body));
  }

  void _buildTasks({
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> todayProgress,
    required List<Map<String, dynamic>> recentProgress,
  }) {
    todayTasks.clear();
    pendingTasks.clear();
    recentTasks.clear();

    // todayProgress should include: stud_id, progress_id, status, updated_at, log_date
    final todayMap = {for (final p in todayProgress) p['stud_id'].toString(): p};

    for (final s in students) {
      final studId = s['stud_id'].toString();
      final progress = todayMap[studId];

      if (progress == null) {
        // no log today -> pending not_done
        pendingTasks.add(_mapStudentToTask(s, 'not_done'));
      } else {
        final statusDb = (progress['status'] ?? '').toString(); // Draft / Submit
        if (statusDb == 'Draft') {
          pendingTasks.add(_mapStudentToTask(s, 'draft', progress));
        } else {
          todayTasks.add(_mapStudentToTask(s, 'done', progress));
        }
      }
    }

    // recentProgress should include: stud_id, stud_name, stud_dob, stud_branch, progress_id, status, updated_at, log_date
    for (final p in recentProgress) {
      final statusDb = (p['status'] ?? '').toString(); // Draft / Submit
      final mapped = (statusDb == 'Draft') ? 'draft' : 'done';

      recentTasks.add(TeacherTask(
        studId: p['stud_id'].toString(),
        name: (p['stud_name'] ?? '').toString(),
        age: _calcAge(p['stud_dob']?.toString()),
        branch: (p['stud_branch'] ?? '').toString(),
        status: mapped,
        updatedAt: DateTime.tryParse((p['updated_at'] ?? '').toString()),
        progressId: p['progress_id']?.toString(),
        logDate: DateTime.tryParse((p['log_date'] ?? '').toString()),
      ));
    }

    todayCount = todayTasks.length;
    pendingCount = pendingTasks.length;
    doneCount = recentTasks.where((x) => x.status == 'done').length;
  }

  TeacherTask _mapStudentToTask(
    Map<String, dynamic> s,
    String status, [
    Map<String, dynamic>? progress,
  ]) {
    DateTime? logDate;
    if (progress != null) {
      logDate = DateTime.tryParse((progress['log_date'] ?? '').toString());
    } else {
      // for not_done -> due today
      logDate = DateTime.now();
    }

    return TeacherTask(
      studId: s['stud_id'].toString(),
      name: (s['stud_name'] ?? '').toString(),
      age: _calcAge(s['stud_dob']?.toString()),
      branch: (s['stud_branch'] ?? '').toString(),
      status: status,
      updatedAt: progress != null ? DateTime.tryParse((progress['updated_at'] ?? '').toString()) : null,
      progressId: progress != null ? progress['progress_id']?.toString() : null,
      logDate: logDate,
    );
  }

  String _calcAge(String? dob) {
    if (dob == null || dob.isEmpty) return '-';
    final d = DateTime.tryParse(dob);
    if (d == null) return '-';

    final now = DateTime.now();
    int y = now.year - d.year;
    int m = now.month - d.month;
    if (m < 0) {
      y--;
      m += 12;
    }
    return '${y}y ${m}m';
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);

    try {
      final students = await _fetchAssignedStudents();
      final todayProgress = await _fetchTodayProgress();
      final recentProgress = await _fetchRecentProgress();

      _buildTasks(
        students: students,
        todayProgress: todayProgress,
        recentProgress: recentProgress,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16.sp,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your teaching tasks today',
              style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.6)),
            ),
            SizedBox(height: 2.h),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2,
              children: [
                _MiniStat(label: 'Today', value: '$todayCount', accent: Growkids.purpleFlo, icon: Icons.today),
                _MiniStat(label: 'Pending', value: '$pendingCount', accent: Colors.orange, icon: Icons.pending),
                _MiniStat(label: 'Done', value: '$doneCount', accent: Colors.green, icon: Icons.done),
              ],
            ),
            SizedBox(height: 2.h),
            _Tabs(tab: tab, onChanged: (t) => setState(() => tab = t)),
            SizedBox(height: 1.6.h),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
            else ...[
              if (tab == _TeacherTab.today) _buildList(todayTasks, emptyText: "No completed logs yet today."),
              if (tab == _TeacherTab.pending) _buildList(pendingTasks, emptyText: "No pending items."),
              if (tab == _TeacherTab.recent) _buildList(recentTasks, emptyText: "No recent logs yet."),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<TeacherTask> list, {required String emptyText}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 10.h),
          child: Text(emptyText,
              style: TextStyle(
                color: Colors.black.withOpacity(.55),
                fontSize: 14.sp,
              )),
        ),
      );
    }
    return Column(children: list.map(_taskCard).toList());
  }

  Widget _taskCard(TeacherTask t) => _TeacherTaskCard(
        name: t.name,
        age: t.age,
        branch: t.branch,
        status: t.status,
        logDate: t.logDate,

// inside onTap:
        onTap: () async {
          if (t.status == 'done') {
            // view only
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewDailyProgressPage(
                  progressId: t.progressId ?? '',
                  teacherId: widget.teacherId,
                  studentName: t.name,
                  studId: t.studId,
                ),
              ),
            );
            return;
          }

          // not_done OR draft -> edit/create
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDailyProgressPage(
                studId: t.studId,
                studentName: t.name,
                teacherId: widget.teacherId,
                progressId: t.progressId, // draft has it, not_done null
              ),
            ),
          );

          if (changed == true) _loadAll();
        },
      );
}

class _TeacherTaskCard extends StatelessWidget {
  final String name;
  final String age;
  final String branch;

  /// not_done | draft | done
  final String status;

  final DateTime? logDate;
  final VoidCallback? onTap;

  const _TeacherTaskCard({
    required this.name,
    required this.age,
    required this.branch,
    required this.status,
    required this.logDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = status == 'done';
    final isDraft = status == 'draft';

    final d = logDate;
    final dateStr = d == null ? '-' : DateFormat('d MMM yyyy').format(d);

    final info = isDone
        ? 'Completed: $dateStr'
        : isDraft
            ? 'Draft for: $dateStr'
            : 'Due: $dateStr';

    final pillLabel = isDone
        ? 'Completed'
        : isDraft
            ? 'Draft saved'
            : 'Need action';

    final pillBg = isDone
        ? Growkids.purpleFlo.withOpacity(0.12)
        : isDraft
            ? Colors.amber.withOpacity(0.12)
            : Colors.red.withOpacity(0.12);

    final pillText = isDone
        ? Growkids.purpleFlo
        : isDraft
            ? Colors.amber[800]!
            : Colors.red;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.all(1.5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 3.h,
              backgroundColor: Growkids.purpleFlo.withOpacity(0.12),
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1),
                style: TextStyle(color: Growkids.purpleFlo, fontSize: 18.sp),
              ),
            ),
            SizedBox(width: 1.2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14.sp)),
                  Text(
                    '$age • $branch',
                    style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.6.h),
                  Text(
                    info,
                    style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.55)),
                  ),
                  SizedBox(height: 0.9.h),
                  _pill(pillLabel, pillBg, pillText),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.5), size: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color colour, Color textColour) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.2.h, vertical: 0.65.h),
      decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 13.sp, color: textColour)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(1.4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 3.h,
            backgroundColor: accent.withOpacity(0.12),
            child: Icon(icon, color: accent, size: 3.h),
          ),
          SizedBox(width: 1.2.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
                Text(label, style: TextStyle(fontSize: 14.sp, color: Colors.black.withOpacity(0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final _TeacherTab tab;
  final ValueChanged<_TeacherTab> onChanged;

  const _Tabs({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabBtn(label: 'Today', active: tab == _TeacherTab.today, onTap: () => onChanged(_TeacherTab.today)),
          const SizedBox(width: 6),
          _TabBtn(
              label: 'Need action', active: tab == _TeacherTab.pending, onTap: () => onChanged(_TeacherTab.pending)),
          const SizedBox(width: 6),
          _TabBtn(label: 'Recent', active: tab == _TeacherTab.recent, onTap: () => onChanged(_TeacherTab.recent)),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.2.h),
          decoration: BoxDecoration(
            color: active ? Growkids.purpleFlo.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: active ? Growkids.purpleFlo : Colors.black.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
