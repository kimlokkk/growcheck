import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_student_report_pdf_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3StudentReportPage extends StatefulWidget {
  final String teacherId, classId, studentId, studentName;
  const KssV3StudentReportPage(
      {super.key,
      required this.teacherId,
      required this.classId,
      required this.studentId,
      required this.studentName});
  @override
  State<KssV3StudentReportPage> createState() => _KssV3StudentReportPageState();
}

class _KssV3StudentReportPageState extends State<KssV3StudentReportPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  Map? _data;
  String? _error;
  String? _semester;
  bool _loading = true;
  Map<String, String> get _body => {
        'teacher_id': widget.teacherId,
        'class_id': widget.classId,
        'student_id': widget.studentId
      };
  Future<Map> _request(Map<String, String> body) async {
    final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_v3_student_report.php')),
        body: body);
    final decoded = json.decode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['success'] != true) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Unable to load report.').toString()
          : 'Unable to load report.');
    }
    return decoded;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _request({
        ..._body,
        'action': 'load',
        if (_semester != null) 'semester_code': _semester!,
      });
      if (mounted) {
        setState(() {
          _data = result['data'] as Map?;
          _semester ??= _data?['semester']?.toString();
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = (_data?['subjects'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    final complete = _data?['completed_subject_count'] ?? 0;
    final required = _data?['required_subject_count'] ?? 0;
    final focus = (_data?['focus_subjects'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final strengths = (_data?['strength_subjects'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final semesters = (_data?['semesters'] as List? ?? [])
        .map((item) => item.toString())
        .toList();
    final history = (_data?['history'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
            title: Text(widget.studentName),
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
                    return ListView(
                        padding:
                            EdgeInsets.fromLTRB(horizontal, 22, horizontal, 48),
                        children: [
                          const Text('Student performance',
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          if (semesters.length > 1) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _semester,
                              decoration:
                                  const InputDecoration(labelText: 'Semester'),
                              items: semesters
                                  .map((semester) => DropdownMenuItem(
                                      value: semester,
                                      child: Text(semester == 'SEM2'
                                          ? 'Semester 2'
                                          : 'Semester 1')))
                                  .toList(),
                              onChanged: (semester) {
                                if (semester == null || semester == _semester) {
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
                          const SizedBox(height: 10),
                          Text(
                              '$complete / $required required subjects completed',
                              style: const TextStyle(color: _muted)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _summary('Average TP', _data?['average_tp'] ?? '-',
                                Growkids.purpleFlo),
                            _summary('Strengths', strengths.length,
                                Growkids.purpleBright),
                            _summary('Focus areas', focus.length,
                                const Color(0xFF6042E6)),
                          ]),
                          if (strengths.isNotEmpty || focus.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            if (strengths.isNotEmpty)
                              _insight('Strengths', strengths,
                                  const Color(0xFFD9EAD3)),
                            if (focus.isNotEmpty)
                              _insight('Focus areas', focus,
                                  const Color(0xFFF4CCCC)),
                          ],
                          const SizedBox(height: 14),
                          const Text('Subjects',
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          ...subjects.map((s) => Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: _border),
                                  borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                  title: Text(s['name'].toString()),
                                  subtitle: Text(
                                      '${s['teacher_name'] ?? 'No teacher assigned'} • ${s['completed_groups'] ?? 0} sections completed • ${_trend(s)}'),
                                  trailing: s['final_tp'] == null
                                      ? null
                                      : KssV3TpStyle.badge(s['final_tp'])))),
                          if (history.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text('Assessment timeline',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            ...history.map((item) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.more_time_outlined,
                                    color: Growkids.purpleFlo),
                                title: Text(item['subject_name'].toString()),
                                subtitle: Text(
                                    '${item['semester'] == 'SEM2' ? 'Semester 2' : 'Semester 1'} • ${item['cycle_type'] == 'REVISION' ? 'Reassessment' : 'Initial assessment'}'),
                                trailing: item['final_tp'] == null
                                    ? const Text('In progress')
                                    : KssV3TpStyle.badge(item['final_tp']))),
                          ],
                          const SizedBox(height: 16),
                          if (complete == required)
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => KssV3StudentReportPdfPage(
                                    report: Map<String, dynamic>.from(_data!),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Generate PDF / Print'),
                            ),
                          if (complete != required)
                            const Text('Complete every required subject first.')
                        ]);
                  }));
  }

  Widget _summary(String label, dynamic value, Color color) => Container(
      width: 130,
      padding: const EdgeInsets.all(10),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: .78))),
      ]));

  Widget _insight(
          String label, List<Map<String, dynamic>> subjects, Color color) =>
      Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
          child: Text(
              '$label: ${subjects.map((subject) => subject['name']).join(', ')}'));

  String _trend(Map<String, dynamic> subject) {
    final current = int.tryParse(subject['final_tp']?.toString() ?? '');
    final previous = int.tryParse(subject['previous_tp']?.toString() ?? '');
    if (current == null) {
      return subject['subject_status']?.toString() ?? 'NOT STARTED';
    }
    if (previous == null) return 'TP $current • First completed result';
    final change = current - previous;
    if (change > 0) return 'TP $current • ↑ Improved by $change';
    if (change < 0) return 'TP $current • ↓ Down by ${change.abs()}';
    return 'TP $current • — Maintained';
  }
}
