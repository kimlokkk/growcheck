import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_student_assessment_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3ClassPerformancePage extends StatefulWidget {
  final String teacherId;
  final Map<String, dynamic> teaching;
  const KssV3ClassPerformancePage(
      {super.key, required this.teacherId, required this.teaching});

  @override
  State<KssV3ClassPerformancePage> createState() =>
      _KssV3ClassPerformancePageState();
}

class _KssV3ClassPerformancePageState extends State<KssV3ClassPerformancePage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  Map<String, dynamic>? _data;
  String _filter = 'ALL';
  String? _semester;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.post(
          Uri.parse(ApiConfig.flutter('kss_v3_class_performance.php')),
          body: {
            'teacher_id': widget.teacherId,
            'assignment_id': widget.teaching['assignment_id'].toString(),
            if (_semester != null) 'semester_code': _semester!,
          });
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load class performance.')
                .toString()
            : 'Unable to load class performance.');
      }
      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(decoded['data'] as Map);
          _semester ??= _data?['semester']?.toString();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(Map<String, dynamic> student) {
    if (_filter == 'ALL') return true;
    if (_filter == 'NEEDS_ATTENTION') {
      final tp = int.tryParse(student['final_tp']?.toString() ?? '');
      return tp != null && tp <= 2;
    }
    return student['status'] == _filter;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map? ?? {};
    final distribution = Map<String, dynamic>.from(
        (summary['tp_distribution'] as Map?)?.cast<String, dynamic>() ?? {});
    final sections = (summary['section_insights'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final focusSections = [...sections]..sort((left, right) =>
        _number(right['needs_attention'])
            .compareTo(_number(left['needs_attention'])));
    final strongSections = sections
        .where((section) => section['average_tp'] != null)
        .toList()
      ..sort((left, right) =>
          _number(right['average_tp']).compareTo(_number(left['average_tp'])));
    final students = (_data?['students'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where(_matches)
        .toList();
    final semesters = (_data?['semesters'] as List? ?? [])
        .map((item) => item.toString())
        .toList();
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
          title: const Text('Class performance'),
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : LayoutBuilder(builder: (context, constraints) {
                  final horizontal = constraints.maxWidth > 860
                      ? (constraints.maxWidth - 760) / 2
                      : 20.0;
                  return RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                          padding: EdgeInsets.fromLTRB(
                              horizontal, 22, horizontal, 48),
                          children: [
                            Text(_data?['subject_name']?.toString() ?? '',
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800)),
                            Text(
                                '${_data?['class_name']} • Year ${_data?['year_level']}',
                                style: const TextStyle(color: _muted)),
                            if (semesters.length > 1) ...[
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                key: ValueKey(_semester),
                                initialValue: _semester,
                                decoration: const InputDecoration(
                                    labelText: 'Semester'),
                                items: semesters
                                    .map((semester) => DropdownMenuItem(
                                        value: semester,
                                        child: Text(semester == 'SEM2'
                                            ? 'Semester 2'
                                            : 'Semester 1')))
                                    .toList(),
                                onChanged: (semester) {
                                  if (semester == null ||
                                      semester == _semester) {
                                    return;
                                  }
                                  setState(() {
                                    _semester = semester;
                                    _loading = true;
                                  });
                                  _load();
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _summaryCard(
                                  'Students',
                                  summary['total_students'],
                                  Growkids.purpleFlo),
                              _summaryCard(
                                  'Completed',
                                  summary['completed_students'],
                                  Growkids.purpleBright),
                              _summaryCard(
                                  'In progress',
                                  summary['in_progress_students'],
                                  const Color(0xFF6042E6)),
                              _summaryCard(
                                  'Average TP',
                                  summary['average_tp'] ?? '-',
                                  const Color(0xFF5539C8)),
                            ]),
                            const SizedBox(height: 20),
                            const Text('Class insights',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (var level = 1; level <= 6; level++)
                                _distributionChip(
                                    level, distribution['$level']),
                            ]),
                            const SizedBox(height: 10),
                            if (focusSections.isNotEmpty &&
                                _number(focusSections
                                        .first['needs_attention']) >
                                    0)
                              _sectionInsight(
                                  'Needs attention',
                                  focusSections.first,
                                  const Color(0xFFF4CCCC),
                                  '${focusSections.first['needs_attention']} students at TP 1–2 • ${focusSections.first['assessed_students']} / ${summary['total_students']} assessed'),
                            if (strongSections.isNotEmpty)
                              _sectionInsight(
                                  'Strongest section',
                                  strongSections.first,
                                  const Color(0xFFD9EAD3),
                                  'Average TP ${strongSections.first['average_tp']} • ${strongSections.first['assessed_students']} / ${summary['total_students']} assessed'),
                            const SizedBox(height: 18),
                            const Text('Students',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  _filterChip('ALL', 'All'),
                                  _filterChip('NOT_STARTED', 'Not started'),
                                  _filterChip('IN_PROGRESS', 'In progress'),
                                  _filterChip('COMPLETED', 'Completed'),
                                  _filterChip(
                                      'NEEDS_ATTENTION', 'Needs attention'),
                                ])),
                            const SizedBox(height: 8),
                            ...students.map((student) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: _border),
                                    borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => KssV3StudentAssessmentPage(
                                                teacherId: widget.teacherId,
                                                assignmentId: widget
                                                    .teaching['assignment_id']
                                                    .toString(),
                                                subjectName: widget
                                                    .teaching['subject_name']
                                                    .toString(),
                                                student: student))),
                                    title: Text(
                                        student['student_name'].toString()),
                                    subtitle: Text(_subtitle(student)),
                                    trailing: student['final_tp'] == null
                                        ? Chip(
                                            label: Text(
                                                student['status'].toString()))
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              KssV3TpStyle.badge(
                                                  student['final_tp']),
                                              if (student['change'] != null)
                                                Text(
                                                    _changeLabel(
                                                        student['change']),
                                                    style: TextStyle(
                                                        color: _change(
                                                                    student) >
                                                                0
                                                            ? Colors
                                                                .green.shade700
                                                            : _change(student) <
                                                                    0
                                                                ? Colors.red
                                                                    .shade700
                                                                : _muted,
                                                        fontSize: 11)),
                                            ],
                                          )))),
                          ]));
                }),
    );
  }

  Widget _summaryCard(String label, dynamic value, Color color) => Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: .78))),
      ]));

  Widget _filterChip(String value, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value)));

  Widget _distributionChip(int level, dynamic count) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: KssV3TpStyle.background(level),
          borderRadius: BorderRadius.circular(16)),
      child: Text('TP $level: ${count ?? 0}',
          style: TextStyle(
              color: KssV3TpStyle.foreground(level),
              fontWeight: FontWeight.w800)));

  Widget _sectionInsight(String label, Map<String, dynamic> section,
          Color color, String detail) =>
      Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${section['code']} ${section['title']}'),
            Text(detail, style: const TextStyle(fontSize: 12)),
          ]));

  String _subtitle(Map<String, dynamic> student) =>
      '${student['completed_groups']} / ${student['total_groups']} sections completed • ${student['status']}';

  String _changeLabel(dynamic value) {
    final change = int.tryParse(value.toString()) ?? 0;
    if (change > 0) return '↑ Improved by $change';
    if (change < 0) return '↓ Down by ${change.abs()}';
    return '— Maintained';
  }

  int _change(Map<String, dynamic> student) =>
      int.tryParse(student['change'].toString()) ?? 0;

  double _number(dynamic value) => double.tryParse(value.toString()) ?? 0;
}
