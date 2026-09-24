import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_student_report_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_teaching_students_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3ClassPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String teacherId;

  const KssV3ClassPage({
    super.key,
    required this.classData,
    required this.teacherId,
  });

  @override
  State<KssV3ClassPage> createState() => _KssV3ClassPageState();
}

class _KssV3ClassPageState extends State<KssV3ClassPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _softPurple = Color(0xFFEDEDF7);
  static const _success = Color(0xFF2E7D32);
  static const _warning = Color(0xFFA85D00);
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _availableSubjects = [];
  List<Map<String, dynamic>> _teachers = [];
  String _activeSemester = 'SEM1';
  String _activeView = 'STUDENTS';
  bool _loading = true;
  String? _error;

  int get _classId => int.parse(widget.classData['id'].toString());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, String> body) async {
    final response =
        await http.post(Uri.parse(ApiConfig.flutter(endpoint)), body: body);
    final decoded = json.decode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['success'] != true) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Request failed.').toString()
          : 'Request failed.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _post('kss_v3_class_overview.php',
            {'class_id': '$_classId', 'teacher_id': widget.teacherId}),
        _post('kss_v3_class_subjects.php',
            {'class_id': '$_classId', 'action': 'list'}),
        _post('kss_v3_setup_options.php', {}),
        _post('kss_v3_class_semester.php',
            {'class_id': '$_classId', 'teacher_id': widget.teacherId}),
      ]);
      if (!mounted) return;
      setState(() {
        _students = _rows((results[0]['data'] as Map?)?['students']);
        _subjects = _rows(results[1]['data']);
        final options = Map<String, dynamic>.from(results[2]['data'] as Map);
        _availableSubjects = _rows(options['subjects']);
        _teachers = _rows(options['teachers']);
        _activeSemester = results[3]['data']['active_semester'].toString();
      });
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.map((item) => Map<String, dynamic>.from(item as Map)).toList()
      : [];

  Future<void> _addStudent() async {
    try {
      final response = await _post('kss_v3_class_students.php', {
        'class_id': '$_classId',
        'action': 'available',
      });
      final options = _rows(response['data']);
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        builder: (_) => ListView(
          children: options.isEmpty
              ? const [ListTile(title: Text('No available students.'))]
              : options
                  .map((student) => ListTile(
                        title: Text(student['stud_name'].toString()),
                        subtitle: Text(student['stud_no']?.toString() ?? ''),
                        onTap: () => Navigator.pop(context, student),
                      ))
                  .toList(),
        ),
      );
      if (selected == null) return;
      await _post('kss_v3_class_students.php', {
        'class_id': '$_classId',
        'action': 'add',
        'student_id': selected['student_id'].toString(),
      });
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addSubject() async {
    if (_availableSubjects.isEmpty || _teachers.isEmpty) return;
    Map<String, dynamic>? subject = _availableSubjects.first;
    Map<String, dynamic>? teacher = _teachers.first;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Add Subject'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: subject,
              items: _availableSubjects
                  .map((item) => DropdownMenuItem(
                      value: item, child: Text(item['name'].toString())))
                  .toList(),
              onChanged: (value) => setDialogState(() => subject = value),
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: teacher,
              items: _teachers
                  .map((item) => DropdownMenuItem(
                      value: item, child: Text(item['staff_name'].toString())))
                  .toList(),
              onChanged: (value) => setDialogState(() => teacher = value),
              decoration: const InputDecoration(labelText: 'Teacher'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'))
          ],
        ),
      ),
    );
    if (save != true || subject == null || teacher == null) return;
    try {
      await _post('kss_v3_class_subjects.php', {
        'class_id': '$_classId',
        'action': 'save',
        'subject_id': subject!['id'].toString(),
        'teacher_id': teacher!['teacher_id'].toString(),
      });
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );

  Future<void> _archiveClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove class?'),
        content: const Text(
            'This class will be archived and removed from My Classes. Previous assessment records will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _post('kss_v3_archive_class.php', {
        'teacher_id': widget.teacherId,
        'class_id': '$_classId',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _startSemester2() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Semester 2?'),
        content: const Text(
            'New assessments will be recorded in Semester 2. Semester 1 records remain in History.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start Sem 2')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _post('kss_v3_class_semester.php', {
        'class_id': '$_classId',
        'teacher_id': widget.teacherId,
        'action': 'start_sem2',
      });
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
            title: Text(widget.classData['class_name'].toString()),
            backgroundColor: Growkids.purpleFlo,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded)),
              PopupMenuButton<String>(
                  tooltip: 'More options',
                  onSelected: (value) {
                    if (value == 'REMOVE') _archiveClass();
                  },
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'REMOVE',
                            child: Row(children: [
                              Icon(Icons.archive_outlined),
                              SizedBox(width: 10),
                              Text('Remove class'),
                            ]))
                      ])
            ]),
        body: LayoutBuilder(builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 860
              ? (constraints.maxWidth - 760) / 2
              : 20.0;
          return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 48),
                  children: [
                    if (_loading)
                      _loadingState()
                    else if (_error != null)
                      _errorState()
                    else ...[
                      _classHeader(),
                      const SizedBox(height: 18),
                      SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                              style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  side: WidgetStateProperty.all(
                                      const BorderSide(color: _border))),
                              segments: const [
                                ButtonSegment(
                                    value: 'STUDENTS',
                                    icon: Icon(Icons.people_outline),
                                    label: Text('Students')),
                                ButtonSegment(
                                    value: 'SUBJECTS',
                                    icon: Icon(Icons.menu_book_outlined),
                                    label: Text('Subjects')),
                                ButtonSegment(
                                    value: 'PERFORMANCE',
                                    icon: Icon(Icons.insights_outlined),
                                    label: Text('Performance')),
                              ],
                              selected: {_activeView},
                              onSelectionChanged: (value) =>
                                  setState(() => _activeView = value.first))),
                      const SizedBox(height: 20),
                      if (_activeView == 'STUDENTS') _studentsView(),
                      if (_activeView == 'SUBJECTS') _subjectsView(),
                      if (_activeView == 'PERFORMANCE') _performanceSummary(),
                    ]
                  ]));
        }),
      );

  Widget _classHeader() => _surface(
      color: Growkids.purpleFlo,
      borderColor: Growkids.purpleBright,
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.class_outlined, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.classData['class_name'].toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(
                      'Year ${widget.classData['year_level']} • ${widget.classData['academic_year']}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                      'Homeroom teacher: ${widget.classData['homeroom_teacher_name'] ?? '-'}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 12)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _semesterPill(),
              if (_activeSemester == 'SEM1') ...[
                const SizedBox(height: 5),
                TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _startSemester2,
                    child: const Text('Start Semester 2')),
              ]
            ]),
          ])));

  Widget _semesterPill() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(20)),
      child: Text(_activeSemester == 'SEM2' ? 'Semester 2' : 'Semester 1',
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)));

  Widget _studentsView() => Column(children: [
        _viewHeader('Students', '${_students.length} students', _addStudent),
        const SizedBox(height: 10),
        if (_students.isEmpty)
          _emptyState('No students added yet.')
        else
          ..._students.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _surface(
                  child: ListTile(
                      onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KssV3StudentReportPage(
                                teacherId: widget.teacherId,
                                classId: '$_classId',
                                studentId: item['student_id'].toString(),
                                studentName: item['stud_name'].toString(),
                              ),
                            ),
                          ),
                      contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      leading: CircleAvatar(
                          backgroundColor: _softPurple,
                          foregroundColor: Growkids.purpleFlo,
                          child: Text(_initial(item['stud_name']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      title: Text(item['stud_name'].toString(),
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${item['stud_no'] ?? ''} • ${item['completed_subjects'] ?? 0} / ${item['total_subjects'] ?? 0} subjects completed',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        _statusChip(item['status']),
                        PopupMenuButton<String>(
                            tooltip: 'Student options',
                            onSelected: (value) async {
                              if (value != 'REMOVE') return;
                              await _post('kss_v3_class_students.php', {
                                'class_id': '$_classId',
                                'action': 'remove',
                                'student_id': item['student_id'].toString()
                              });
                              await _load();
                            },
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'REMOVE',
                                      child: Text('Remove from class'))
                                ])
                      ]))))),
      ]);

  Widget _subjectsView() => Column(children: [
        _viewHeader('Subjects', '${_subjects.length} subjects', _addSubject),
        const SizedBox(height: 10),
        if (_subjects.isEmpty)
          _emptyState('No subjects added yet.')
        else
          ..._subjects.map((item) {
            final canOpen = item['assignment_id'] != null &&
                item['teacher_id'].toString() == widget.teacherId;
            return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _surface(
                    onTap: canOpen
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => KssV3TeachingStudentsPage(
                                          teacherId: widget.teacherId,
                                          teaching: {
                                            ...item,
                                            'class_id': _classId,
                                            'class_name':
                                                widget.classData['class_name'],
                                            'year_level':
                                                widget.classData['year_level'],
                                            'subject_name': item['name'],
                                            'student_count': _students.length,
                                          })),
                            )
                        : null,
                    child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        leading: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: _softPurple,
                                borderRadius: BorderRadius.circular(11)),
                            child: const Icon(Icons.menu_book_outlined,
                                color: Growkids.purpleFlo, size: 21)),
                        title: Text(item['name'].toString(),
                            style: const TextStyle(
                                color: _ink, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            item['teacher_name']?.toString() ??
                                'No teacher assigned',
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                        trailing: canOpen
                            ? const Icon(Icons.arrow_forward_ios_rounded,
                                size: 15, color: _muted)
                            : null)));
          }),
      ]);

  Widget _viewHeader(String title, String count, VoidCallback add) =>
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(count, style: const TextStyle(color: _muted, fontSize: 12)),
        ])),
        FilledButton.icon(
            onPressed: add,
            style: FilledButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add')),
      ]);

  Widget _statusChip(dynamic status) {
    final value = status?.toString() ?? 'NOT_STARTED';
    final color = switch (value) {
      'COMPLETED' => const Color(0xFF2E7D32),
      'IN_PROGRESS' => const Color(0xFFB26A00),
      _ => _muted,
    };
    final label = switch (value) {
      'COMPLETED' => 'Completed',
      'IN_PROGRESS' => 'In progress',
      _ => 'Not started',
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)));
  }

  Widget _performanceSummary() {
    final completed =
        _students.where((student) => student['status'] == 'COMPLETED').length;
    final inProgress =
        _students.where((student) => student['status'] == 'IN_PROGRESS').length;
    final notStarted = _students.length - completed - inProgress;
    final total = _students.length;
    final progress = total == 0 ? 0.0 : completed / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Class performance',
          style: TextStyle(
              color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Overall assessment completion for this semester.',
          style: TextStyle(color: _muted, fontSize: 13)),
      const SizedBox(height: 14),
      _surface(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(children: [
                  _summaryValue('$completed', 'Completed', _success),
                  _summaryValue('$inProgress', 'In progress', _warning),
                  _summaryValue('$notStarted', 'Not started', _muted),
                ]),
                const SizedBox(height: 18),
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: _softPurple,
                        color: _success)),
              ]))),
      const SizedBox(height: 12),
      const Text(
          'Open a subject under My Teaching for detailed TP distribution and learning-area insights.',
          style: TextStyle(color: _muted, fontSize: 12)),
    ]);
  }

  Widget _summaryValue(String value, String label, Color color) => Expanded(
          child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      ]));

  Widget _surface({
    required Widget child,
    VoidCallback? onTap,
    Color color = Colors.white,
    Color borderColor = _border,
  }) =>
      Material(
          color: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: child));

  Widget _emptyState(String message) => _surface(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: Text(message, style: const TextStyle(color: _muted)))));

  Widget _loadingState() => Column(
          children: List.generate(4, (index) {
        return Container(
            height: index == 0 ? 112 : 74,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: _softPurple, borderRadius: BorderRadius.circular(14)));
      }));

  Widget _errorState() => _surface(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.cloud_off_outlined, color: _muted, size: 34),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ])));

  String _initial(dynamic name) {
    final value = name?.toString().trim() ?? '';
    return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
  }
}
