import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_class_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_teaching_students_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_student_assessment_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3AssessmentHome extends StatefulWidget {
  final String teacherId;

  const KssV3AssessmentHome({super.key, required this.teacherId});

  @override
  State<KssV3AssessmentHome> createState() => _KssV3AssessmentHomeState();
}

class _KssV3AssessmentHomeState extends State<KssV3AssessmentHome> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _softPurple = Color(0xFFEDEDF7);
  static const _success = Color(0xFF2E7D32);
  static const _warning = Color(0xFFA85D00);
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _teaching = [];
  List<Map<String, dynamic>> _dashboardAssignments = [];
  Map<String, dynamic> _dashboardSummary = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        http.post(Uri.parse(ApiConfig.flutter('kss_v3_classes.php')),
            body: {'teacher_id': widget.teacherId}),
        http.post(Uri.parse(ApiConfig.flutter('kss_v3_my_teaching.php')),
            body: {'teacher_id': widget.teacherId}),
        http.post(Uri.parse(ApiConfig.flutter('kss_v3_teacher_dashboard.php')),
            body: {'teacher_id': widget.teacherId}),
      ]);
      final decoded = json.decode(responses[0].body);
      final teachingDecoded = json.decode(responses[1].body);
      final dashboardDecoded = json.decode(responses[2].body);
      if (responses[0].statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true ||
          responses[1].statusCode != 200 ||
          teachingDecoded is! Map ||
          teachingDecoded['success'] != true ||
          responses[2].statusCode != 200 ||
          dashboardDecoded is! Map ||
          dashboardDecoded['success'] != true) {
        throw Exception(
          decoded is Map
              ? (decoded['message'] ?? 'Unable to load classes.').toString()
              : 'Unable to load classes.',
        );
      }

      final data = decoded['data'];
      if (!mounted) return;
      setState(() {
        _classes = data is List
            ? data
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList()
            : [];
        final teachingData = teachingDecoded['data'];
        _teaching = teachingData is List
            ? teachingData
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList()
            : [];
        final dashboard = dashboardDecoded['data'] as Map? ?? {};
        _dashboardSummary =
            Map<String, dynamic>.from(dashboard['summary'] as Map? ?? {});
        _dashboardAssignments = (dashboard['assignments'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _classes = [];
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateClass() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => KssV3CreateClassPage(teacherId: widget.teacherId),
      ),
    );
    if (created == true) await _loadClasses();
  }

  int _count(dynamic value) => int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Renogare'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Renogare'),
      ),
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          title: const Text('KSS Assessment',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          centerTitle: false,
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(
              bottom: BorderSide(
                  color: Growkids.purpleBright.withValues(alpha: .65))),
          actions: [
            IconButton(
              tooltip: 'Refresh workspace',
              onPressed: _loading ? null : _loadClasses,
              icon: const Icon(Icons.refresh_rounded, size: 21),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 1184
              ? (constraints.maxWidth - 1120) / 2
              : constraints.maxWidth < 600
                  ? 20.0
                  : 32.0;
          return RefreshIndicator(
            onRefresh: _loadClasses,
            color: Growkids.purpleFlo,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 32, horizontal, 40),
              children: [
                _workspaceHeader(),
                const SizedBox(height: 28),
                if (_loading)
                  _loadingState()
                else if (_error != null)
                  _MessageCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load assessment workspace',
                    message: _error!,
                    actionLabel: 'Try Again',
                    onPressed: _loadClasses,
                  )
                else ...[
                  _summary(),
                  const SizedBox(height: 24),
                  _dashboard(),
                  const SizedBox(height: 32),
                  if (constraints.maxWidth >= 1000)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _teachingPanel()),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _classesPanel()),
                        ])
                  else ...[
                    _teachingPanel(),
                    const SizedBox(height: 28),
                    _classesPanel(),
                  ],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _workspaceHeader() {
    const heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TEACHER WORKSPACE',
            style: TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 11,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 10),
        Text('A clear view of your classroom.',
            style: TextStyle(
                color: _ink,
                fontSize: 28,
                height: 1.2,
                letterSpacing: -.7,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 10),
        Text('Your classes, assessments and next steps, all in one place.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5)),
      ],
    );
    final action = FilledButton.icon(
      onPressed: _openCreateClass,
      style: _primaryButtonStyle(),
      icon: const Icon(Icons.add_rounded, size: 19),
      label: const Text('Create class'),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 720) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading,
          const SizedBox(height: 20),
          action,
        ]);
      }
      return Row(children: [
        const Expanded(child: heading),
        const SizedBox(width: 24),
        action,
      ]);
    });
  }

  ButtonStyle _primaryButtonStyle() => FilledButton.styleFrom(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontFamily: 'Renogare', fontSize: 14, fontWeight: FontWeight.w600),
      );

  Widget _summary() => LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          _stat('My classes', '${_classes.length}', Icons.school_outlined,
              Growkids.purpleFlo, width),
          _stat('Teaching assignments', '${_teaching.length}',
              Icons.menu_book_outlined, Growkids.purpleBright, width),
          _stat('In progress', '${_count(_dashboardSummary['in_progress'])}',
              Icons.timelapse_rounded, const Color(0xFF6042E6), width),
          _stat(
              'Pending assessments',
              '${_count(_dashboardSummary['not_completed'])}',
              Icons.pending_actions_rounded,
              const Color(0xFF5539C8),
              width),
        ]);
      });

  Widget _stat(String label, String value, IconData icon, Color color,
          double width) =>
      SizedBox(
        width: width,
        child: _surface(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 21, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.1,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(label,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 12,
                            height: 1.4)),
                  ]),
            ),
            color: color),
      );

  Widget _classesPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('My Classes', _classes.length),
          const SizedBox(height: 6),
          const Text('The classes you lead as homeroom teacher.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          _content(),
        ],
      );

  Widget _teachingPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('My Teaching Classes', _teaching.length),
          const SizedBox(height: 6),
          const Text('Open a subject to view students and assessments.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          _teachingSection(),
        ],
      );

  Widget _content() {
    if (_classes.isEmpty) {
      return _emptyState(Icons.school_outlined, 'No homeroom classes yet',
          'Classes where you are the homeroom teacher will appear here.');
    }
    return Column(
        children: _classes
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _surface(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => KssV3ClassPage(
                                classData: item, teacherId: widget.teacherId),
                          ));
                      await _loadClasses();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _iconBox(Icons.class_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['class_name']}',
                                      style: const TextStyle(
                                          color: _ink,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35)),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Year ${item['year_level']} · ${item['academic_year']}',
                                      style: const TextStyle(
                                          color: _muted, fontSize: 12)),
                                ],
                              )),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded,
                                  color: _muted, size: 20),
                            ]),
                            const SizedBox(height: 18),
                            Wrap(spacing: 16, runSpacing: 8, children: [
                              _detail(Icons.people_outline_rounded,
                                  '${item['student_count']} students'),
                              _detail(Icons.menu_book_outlined,
                                  '${item['subject_count']} subjects'),
                            ]),
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(height: 1, color: _border)),
                            Text(
                                'Homeroom teacher: ${item['homeroom_teacher_name'] ?? '-'}',
                                style: const TextStyle(
                                    color: _muted, fontSize: 12, height: 1.5)),
                          ]),
                    ),
                  ),
                ))
            .toList());
  }

  Widget _teachingSection() {
    if (_teaching.isEmpty) {
      return _emptyState(
          Icons.menu_book_outlined,
          'No teaching assignments yet',
          'Subjects assigned to you will appear here.');
    }
    return Column(
        children: _teaching.map((item) {
      final dashboard = _dashboardAssignments
          .cast<Map<String, dynamic>?>()
          .firstWhere(
              (row) =>
                  row?['assignment_id'].toString() ==
                  item['assignment_id'].toString(),
              orElse: () => null);
      final total =
          _count(dashboard?['total_students'] ?? item['student_count']);
      final completed = _count(dashboard?['completed_students']);
      final pending = (total - completed).clamp(0, total);
      final complete = dashboard != null && total > 0 && pending == 0;
      final label = total == 0
          ? 'No students'
          : dashboard == null
              ? 'View assessments'
              : complete
                  ? 'Completed'
                  : '$pending pending';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _surface(
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KssV3TeachingStudentsPage(
                      teacherId: widget.teacherId, teaching: item),
                ));
            await _loadClasses();
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _iconBox(Icons.menu_book_outlined),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['subject_name']}',
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${item['class_name']} · Year ${item['year_level']}',
                        style: const TextStyle(
                            color: _muted, fontSize: 13, height: 1.4)),
                  ],
                )),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: _muted),
              ]),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _statusPill(
                      label,
                      total == 0 || dashboard == null
                          ? _muted
                          : complete
                              ? _success
                              : _warning),
                  Text(
                      dashboard == null
                          ? '$total students'
                          : '$completed of $total students completed',
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
              if (dashboard != null && total > 0) ...[
                const SizedBox(height: 14),
                _progress(
                    completed, total, complete ? _success : Growkids.purpleFlo),
              ],
            ]),
          ),
        ),
      );
    }).toList());
  }

  Widget _dashboard() {
    final pendingAssignments = _dashboardAssignments
        .where((item) => item['continue_student_id'] != null)
        .toList();
    if (pendingAssignments.isEmpty) {
      final hasStudents = _dashboardAssignments
          .any((item) => _count(item['total_students']) > 0);
      return _surface(
          child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          _iconBox(
              hasStudents
                  ? Icons.check_circle_outline_rounded
                  : Icons.auto_stories_outlined,
              color: hasStudents ? _success : Growkids.purpleFlo),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  hasStudents
                      ? 'You’re all caught up'
                      : 'Your workspace is ready',
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.4)),
              const SizedBox(height: 4),
              Text(
                  hasStudents
                      ? 'All assigned assessments are complete. Explore your classes below.'
                      : 'Your next assessment will appear here when students are assigned.',
                  style: const TextStyle(
                      color: _muted, fontSize: 13, height: 1.5)),
            ],
          )),
        ]),
      ));
    }
    final item = pendingAssignments.first;
    final completed = _count(item['completed_sections']);
    final total = _count(item['total_sections']);
    Future<void> openAssessment() async {
      await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KssV3StudentAssessmentPage(
              teacherId: widget.teacherId,
              assignmentId: item['assignment_id'].toString(),
              subjectName: item['subject_name'].toString(),
              student: {
                'student_id': item['continue_student_id'],
                'student_name': item['continue_student_name'],
              },
            ),
          ));
      await _loadClasses();
    }

    return _surface(
      color: _softPurple,
      borderColor: const Color(0xFFE1DAF8),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NEXT ASSESSMENT',
              style: TextStyle(
                  color: Growkids.purpleFlo,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Text('${item['continue_student_name']}',
              style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  height: 1.35,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${item['subject_name']} · ${item['class_name']}',
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.5)),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final progress = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$completed of $total sections completed',
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                _progress(completed, total, Growkids.purpleFlo),
              ],
            );
            final action = FilledButton.icon(
              onPressed: openAssessment,
              style: _primaryButtonStyle(),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Continue assessment'),
            );
            if (constraints.maxWidth < 620) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [progress, const SizedBox(height: 20), action]);
            }
            return Row(children: [
              Expanded(child: progress),
              const SizedBox(width: 32),
              action,
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _progress(int completed, int total, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : (completed / total).clamp(0.0, 1.0),
          minHeight: 5,
          backgroundColor: color.withValues(alpha: .10),
          color: color,
        ),
      );

  Widget _detail(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      );

  Widget _emptyState(IconData icon, String title, String message) => _surface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _iconBox(icon),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    color: _ink, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style:
                    const TextStyle(color: _muted, fontSize: 13, height: 1.6)),
          ]),
        ),
      );

  Widget _sectionHeader(String title, int count) => Row(children: [
        Flexible(
            child: Text(title,
                style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3))),
        const SizedBox(width: 10),
        _statusPill('$count', _muted),
      ]);

  Widget _surface({
    required Widget child,
    VoidCallback? onTap,
    Color color = Colors.white,
    Color borderColor = _border,
  }) =>
      Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? child
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: child),
      );

  Widget _iconBox(IconData icon, {Color color = Growkids.purpleFlo}) =>
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 21),
      );

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600)),
      );

  Widget _loadingState() => Column(
        children: List.generate(
            4,
            (index) => Container(
                  height: index == 0 ? 112 : 100,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: GrowkidsPastel.purple3,
                    borderRadius: BorderRadius.circular(16),
                  ),
                )),
      );
}

class KssV3CreateClassPage extends StatefulWidget {
  final String teacherId;

  const KssV3CreateClassPage({super.key, required this.teacherId});

  @override
  State<KssV3CreateClassPage> createState() => _KssV3CreateClassPageState();
}

class _KssV3CreateClassPageState extends State<KssV3CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _className = TextEditingController();
  final _academicYear = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  int? _yearLevel;
  List<Map<String, dynamic>> _teachers = [];
  String? _homeroomTeacherId;
  bool _loadingTeachers = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _className.dispose();
    _academicYear.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_v3_setup_options.php')),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception('Unable to load teachers.');
      }
      final teachers = (decoded['data']['teachers'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _homeroomTeacherId = teachers.any((teacher) =>
                teacher['teacher_id'].toString() == widget.teacherId)
            ? widget.teacherId
            : null;
        _loadingTeachers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTeachers = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_v3_create_class.php')),
        body: {
          'teacher_id': widget.teacherId,
          'homeroom_teacher_id': _homeroomTeacherId ?? '',
          'class_name': _className.text.trim(),
          'year_level': _yearLevel.toString(),
          'academic_year': _academicYear.text.trim(),
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(
          decoded is Map
              ? (decoded['message'] ?? 'Unable to create class.').toString()
              : 'Unable to create class.',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Growkids.purpleFlo),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GrowkidsPastel.purple)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text('Create Class'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: GrowkidsPastel.purple),
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Class Details',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select the class teacher. Subjects and subject teachers can be added afterwards.',
                        style: TextStyle(color: Color(0xFF5F5B6B)),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _className,
                        maxLength: 150,
                        decoration:
                            _decoration('Class Name', Icons.class_rounded),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a class name.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _yearLevel,
                        decoration:
                            _decoration('Year Level', Icons.school_rounded),
                        items: List.generate(
                          6,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('Year ${index + 1}'),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _yearLevel = value),
                        validator: (value) =>
                            value == null ? 'Select a year level.' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _homeroomTeacherId,
                        decoration:
                            _decoration('Class Teacher', Icons.person_outline),
                        items: _teachers
                            .map((teacher) => DropdownMenuItem(
                                value: teacher['teacher_id'].toString(),
                                child: Text(teacher['staff_name'].toString())))
                            .toList(),
                        onChanged: _loadingTeachers
                            ? null
                            : (value) =>
                                setState(() => _homeroomTeacherId = value),
                        validator: (value) =>
                            value == null ? 'Select a class teacher.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _academicYear,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration:
                            _decoration('Academic Year', Icons.event_rounded),
                        validator: (value) {
                          final year = int.tryParse(value ?? '');
                          return year == null || year < 2020 || year > 2100
                              ? 'Enter a valid academic year.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Growkids.purpleFlo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(_saving ? 'Creating...' : 'Create Class'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: GrowkidsPastel.purple),
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 38, color: Growkids.purpleFlo),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
