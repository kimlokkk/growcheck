import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_student_assessment_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_class_performance_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3TeachingStudentsPage extends StatefulWidget {
  final String teacherId;
  final Map<String, dynamic> teaching;

  const KssV3TeachingStudentsPage({
    super.key,
    required this.teacherId,
    required this.teaching,
  });

  @override
  State<KssV3TeachingStudentsPage> createState() =>
      _KssV3TeachingStudentsPageState();
}

class _KssV3TeachingStudentsPageState extends State<KssV3TeachingStudentsPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _softPurple = Color(0xFFEDEDF7);
  static const _success = Color(0xFF2E7D32);
  static const _warning = Color(0xFFA85D00);
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_v3_teaching_students.php')),
        body: {
          'teacher_id': widget.teacherId,
          'assignment_id': widget.teaching['assignment_id'].toString(),
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load students.').toString()
            : 'Unable to load students.');
      }
      if (!mounted) return;
      setState(() {
        _students = (decoded['data']['students'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          title: Text(widget.teaching['subject_name'].toString()),
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
                tooltip: 'Class performance',
                icon: const Icon(Icons.insights_outlined),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => KssV3ClassPerformancePage(
                            teacherId: widget.teacherId,
                            teaching: widget.teaching)))),
          ],
        ),
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
                      const Center(child: CircularProgressIndicator())
                    else if (_error != null)
                      Center(child: Text(_error!))
                    else ...[
                      _header(),
                      const SizedBox(height: 22),
                      Row(children: [
                        const Expanded(
                            child: Text('Students',
                                style: TextStyle(
                                    color: _ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800))),
                        Text('${_students.length}',
                            style: const TextStyle(color: _muted)),
                      ]),
                      const SizedBox(height: 10),
                      ..._students.map((student) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _surface(
                              child: ListTile(
                            contentPadding:
                                const EdgeInsets.fromLTRB(14, 8, 12, 8),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          KssV3StudentAssessmentPage(
                                              teacherId: widget.teacherId,
                                              assignmentId: widget
                                                  .teaching['assignment_id']
                                                  .toString(),
                                              subjectName: widget
                                                  .teaching['subject_name']
                                                  .toString(),
                                              student: student)));
                              _load();
                            },
                            leading: CircleAvatar(
                                backgroundColor: _softPurple,
                                foregroundColor: Growkids.purpleFlo,
                                child: Text(_initial(student['student_name']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            title: Text(student['student_name'].toString(),
                                style: const TextStyle(
                                    color: _ink, fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${student['student_no'] ?? ''} • ${student['completed_tp_groups'] ?? 0} / ${student['total_tp_groups'] ?? 0} sections completed',
                              style:
                                  const TextStyle(color: _muted, fontSize: 12),
                            ),
                            trailing: student['final_tp'] == null
                                ? _statusPill(student['status'])
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _statusPill(student['status']),
                                      const SizedBox(width: 7),
                                      KssV3TpStyle.badge(student['final_tp']),
                                    ],
                                  ),
                          )))),
                    ]
                  ]));
        }),
      );

  Widget _header() {
    final completed =
        _students.where((student) => student['status'] == 'COMPLETED').length;
    final progress = _students.isEmpty ? 0.0 : completed / _students.length;
    return Column(children: [
      _surface(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _softPurple,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.menu_book_outlined,
                        color: Growkids.purpleFlo)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.teaching['subject_name'].toString(),
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                          '${widget.teaching['class_name']} • Year ${widget.teaching['year_level']}',
                          style: const TextStyle(color: _muted, fontSize: 13)),
                    ])),
                IconButton(
                    tooltip: 'Class performance',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => KssV3ClassPerformancePage(
                                teacherId: widget.teacherId,
                                teaching: widget.teaching))),
                    icon: const Icon(Icons.insights_outlined,
                        color: Growkids.purpleFlo)),
              ]))),
      const SizedBox(height: 10),
      _surface(
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            backgroundColor: _softPurple,
                            color: _success))),
                const SizedBox(width: 12),
                Text('$completed / ${_students.length} completed',
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]))),
    ]);
  }

  Widget _surface({required Widget child}) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border)),
      clipBehavior: Clip.antiAlias,
      child: child);

  Widget _statusPill(dynamic rawStatus) {
    final status = rawStatus?.toString() ?? 'NOT_STARTED';
    final color = status == 'COMPLETED'
        ? _success
        : status == 'IN_PROGRESS'
            ? _warning
            : _muted;
    final label = status == 'COMPLETED'
        ? 'Completed'
        : status == 'IN_PROGRESS'
            ? 'In progress'
            : 'Not started';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)));
  }

  String _initial(dynamic name) {
    final value = name?.toString().trim() ?? '';
    return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
  }
}
