import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

// Import path based on your project structure
import 'package:growcheck_app_v2/pages/journal/add_daily_progress.dart';
import 'package:growcheck_app_v2/pages/journal/journal_history.dart';
import 'package:growcheck_app_v2/pages/student_hub/student_hub.dart'; // To access UserRoleHub enum

bool _useDesktopJournalHomeLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class JournalPage extends StatefulWidget {
  final String teacherId;
  final UserRoleHub role; // Added role

  const JournalPage({
    super.key,
    required this.teacherId,
    required this.role, // Added role
  });

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  // Endpoints
  static final String _therapistUrl = ApiConfig.flutter('children_active.php');

  static final String _teacherUrl = ApiConfig.flutter('student_school.php');

  /*static const String _therapistUrl =
      'http://app-kizzu.test/growkids/flutter/children_active.php';
  
  static const String _teacherUrl =
      'http://app-kizzu.test/growkids/flutter/student_school.php';*/

  bool _loading = true;
  String? _error;
  List<_Student> _assigned = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (widget.teacherId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing ID';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await _fetchAssignedStudents();
      if (!mounted) return;
      setState(() {
        _assigned = students;
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

  Future<List<_Student>> _fetchAssignedStudents() async {
    final bool isTeacher = widget.role == UserRoleHub.teacher;

    // 1. Select Endpoint
    final String url = isTeacher ? _teacherUrl : _therapistUrl;

    // 2. Select Body Parameter
    final Map<String, String> body = isTeacher
        ? {'teacher_id': widget.teacherId}
        : {'therapist_id': widget.teacherId};

    final res = await http.post(Uri.parse(url), body: body);

    if (res.statusCode != 200) {
      throw Exception('Failed to load students (HTTP ${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) throw Exception('Invalid student list response');

    final out = <_Student>[];
    for (final row in decoded) {
      if (row is! Map) continue;

      final sid = (row['stud_id'] ?? row['student_id'] ?? '').toString();
      if (sid.isEmpty) continue;

      final name =
          (row['stud_name'] ?? row['student'] ?? row['name'] ?? '-').toString();
      final branch = (row['stud_branch'] ?? row['branch'] ?? '').toString();

      out.add(_Student(studId: sid, name: name, branch: branch));
    }

    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<void> _openCreatePicker() async {
    if (_loading) return;

    final items = _assigned
        .map((s) => _PickStudent(
              studId: s.studId,
              name: s.name,
              subtitle: s.branch.isEmpty ? 'Student' : s.branch,
            ))
        .toList();

    final picked = _useDesktopJournalHomeLayout(context)
        ? await showDialog<_PickStudent>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.48),
            builder: (_) => _DesktopStudentPickerDialog(items: items),
          )
        : await showModalBottomSheet<_PickStudent>(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFFF6F7FB),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            builder: (_) => _StudentPickerSheet(
              title: 'Select Student',
              items: items,
            ),
          );

    if (picked == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDailyProgressPage(
          studId: picked.studId,
          studentName: picked.name,
          teacherId: widget.teacherId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopJournalHomeLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Journal'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadStudents,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStudents,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 14),
            children: [
              const _HeaderJournal(),
              const SizedBox(height: 14),
              if (_error != null) ...[
                _ErrorBanner(text: _error!),
                const SizedBox(height: 14),
              ],
              _ResponsiveGrid(
                forcedCount: 2,
                minTileWidth: 12,
                children: [
                  _ActionTileV2(
                    title: 'Create Journal',
                    icon: Icons.add_circle_rounded,
                    accent: const Color(0xFF3B82F6),
                    onTap: _loading ? () {} : _openCreatePicker,
                  ),
                  _ActionTileV2(
                      title: 'Journal History',
                      icon: Icons.history_rounded,
                      accent: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JournalHistoryPage(
                              teacherId: widget.teacherId,
                            ),
                          ),
                        );
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final roleLabel =
        widget.role == UserRoleHub.teacher ? 'Teacher' : 'Therapist';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Journal',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadStudents,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
            child: Column(
              children: [
                _desktopHero(roleLabel),
                if (_error != null) ...[
                  const SizedBox(height: 15),
                  _desktopErrorBanner(_error!),
                ],
                const SizedBox(height: 22),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 390,
                        child: Column(
                          children: [
                            _desktopActionCard(
                              title: 'Create Journal',
                              subtitle:
                                  'Record daily progress, observations and media.',
                              icon: Icons.add_circle_rounded,
                              color: const Color(0xFF3478F6),
                              buttonLabel: 'Select student',
                              onTap: _loading ? null : _openCreatePicker,
                            ),
                            const SizedBox(height: 16),
                            _desktopActionCard(
                              title: 'Journal History',
                              subtitle:
                                  'Review previous entries across your students.',
                              icon: Icons.history_rounded,
                              color: const Color(0xFF8057E8),
                              buttonLabel: 'View history',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JournalHistoryPage(
                                      teacherId: widget.teacherId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _desktopStudentPanel()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHero(String roleLabel) {
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
              Icons.menu_book_rounded,
              color: Growkids.purpleFlo,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STUDENT JOURNAL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Daily Progress Journal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Capture meaningful observations and track student development.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _desktopHeroMetric(
            Icons.people_alt_outlined,
            _assigned.length.toString(),
            'Students',
          ),
          const SizedBox(width: 12),
          _desktopHeroMetric(
            Icons.person_outline_rounded,
            roleLabel,
            'Role',
          ),
        ],
      ),
    );
  }

  Widget _desktopHeroMetric(IconData icon, String value, String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 125),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 21),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonLabel,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3E5EC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF292B35),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF777C8D),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Text(
                      buttonLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopStudentPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 17),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned students',
                        style: TextStyle(
                          color: Color(0xFF242631),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select a student to create a new journal entry.',
                        style:
                            TextStyle(color: Color(0xFF777C8D), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${_assigned.length} students',
                    style: const TextStyle(
                      color: Growkids.purpleFlo,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EAF0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _assigned.isEmpty
                    ? const Center(
                        child: Text(
                          'No assigned students found.',
                          style: TextStyle(color: Color(0xFF858A98)),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(18),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          mainAxisExtent: 92,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _assigned.length,
                        itemBuilder: (context, index) {
                          final student = _assigned[index];
                          return InkWell(
                            onTap: () => _openStudentJournal(student),
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FC),
                                borderRadius: BorderRadius.circular(13),
                                border:
                                    Border.all(color: const Color(0xFFE4E6ED)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Growkids.purpleFlo
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      student.name.isEmpty
                                          ? '?'
                                          : student.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Growkids.purpleFlo,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF343640),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          student.branch.isEmpty
                                              ? 'Student · ${student.studId}'
                                              : '${student.branch} · ${student.studId}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF858A98),
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.add_rounded,
                                    color: Color(0xFF3478F6),
                                    size: 20,
                                  ),
                                ],
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

  void _openStudentJournal(_Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDailyProgressPage(
          studId: student.studId,
          studentName: student.name,
          teacherId: widget.teacherId,
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

// Model classes and UI sub-components remain unchanged to preserve UI...

class _Student {
  final String studId;
  final String name;
  final String branch;
  const _Student(
      {required this.studId, required this.name, required this.branch});
}

class _PickStudent {
  final String studId;
  final String name;
  final String subtitle;
  const _PickStudent(
      {required this.studId, required this.name, required this.subtitle});
}

class _HeaderJournal extends StatelessWidget {
  const _HeaderJournal();
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
            child:
                Icon(Icons.book_rounded, color: Growkids.purpleFlo, size: 3.h),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text('Journal',
                style: TextStyle(fontSize: 16.sp, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final double minTileWidth;
  final List<Widget> children;
  final int? forcedCount;
  const _ResponsiveGrid(
      {required this.minTileWidth, required this.children, this.forcedCount});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 1,
      mainAxisSpacing: 10,
      childAspectRatio: 5,
      children: children,
    );
  }
}

class _ActionTileV2 extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ActionTileV2(
      {required this.title,
      required this.icon,
      required this.accent,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(1.5.h),
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
              height: 5.h,
              width: 7.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 3.h),
            ),
            SizedBox(width: 2.w),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14.sp))),
            Icon(Icons.chevron_right_rounded,
                color: Colors.black.withValues(alpha: 0.35), size: 3.h),
          ],
        ),
      ),
    );
  }
}

class _DesktopStudentPickerDialog extends StatefulWidget {
  final List<_PickStudent> items;

  const _DesktopStudentPickerDialog({required this.items});

  @override
  State<_DesktopStudentPickerDialog> createState() =>
      _DesktopStudentPickerDialogState();
}

class _DesktopStudentPickerDialogState
    extends State<_DesktopStudentPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<_PickStudent> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? List.from(widget.items)
          : widget.items
              .where((student) =>
                  student.name.toLowerCase().contains(query) ||
                  student.subtitle.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Growkids.purpleFlo,
                      Growkids.purpleFlo.withValues(alpha: 0.78),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_search_rounded,
                        color: Growkids.purpleFlo,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Student',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Choose a student for the new journal entry.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filter,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search student or branch...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 21),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No students found.',
                          style: TextStyle(color: Color(0xFF858A98)),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 86,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final student = _filtered[index];
                          return InkWell(
                            onTap: () => Navigator.pop(context, student),
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                                border:
                                    Border.all(color: const Color(0xFFE3E5EC)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 21,
                                    backgroundColor: Growkids.purpleFlo
                                        .withValues(alpha: 0.10),
                                    child: Text(
                                      student.name.isEmpty
                                          ? '?'
                                          : student.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Growkids.purpleFlo,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF343640),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          student.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF858A98),
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF9A9EAA),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentPickerSheet extends StatefulWidget {
  final String title;
  final List<_PickStudent> items;
  const _StudentPickerSheet({required this.title, required this.items});

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<_PickStudent> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? List.from(widget.items)
          : widget.items
              .where((s) => s.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(
        children: [
          _PickerHero(title: widget.title),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _filtered[i];
                        return Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            onTap: () => Navigator.pop(context, s),
                            leading: CircleAvatar(
                                child: Text(s.name[0].toUpperCase())),
                            title: Text(s.name),
                            subtitle: Text(s.subtitle),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerHero extends StatelessWidget {
  final String title;
  const _PickerHero({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white))
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.red)),
    );
  }
}
