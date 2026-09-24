import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_subject_report_pdf_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_cycle_comparison_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3AssessmentHistoryPage extends StatefulWidget {
  final String teacherId, assignmentId, studentId, studentName;
  const KssV3AssessmentHistoryPage(
      {super.key,
      required this.teacherId,
      required this.assignmentId,
      required this.studentId,
      required this.studentName});
  @override
  State<KssV3AssessmentHistoryPage> createState() =>
      _KssV3AssessmentHistoryPageState();
}

class _KssV3AssessmentHistoryPageState
    extends State<KssV3AssessmentHistoryPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _softPurple = Color(0xFFEDEDF7);
  List<Map<String, dynamic>> _rows = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.post(
          Uri.parse(ApiConfig.flutter('kss_v3_assessment_history.php')),
          body: {
            'teacher_id': widget.teacherId,
            'assignment_id': widget.assignmentId,
            'student_id': widget.studentId
          });
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load history.').toString()
            : 'Unable to load history.');
      }
      if (mounted) {
        setState(() => _rows = (decoded['data'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList());
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

  Future<void> _openReport(Map<String, dynamic> row) async {
    if (row['subject_status'] != 'COMPLETED') return;
    try {
      final response = await http.post(
          Uri.parse(ApiConfig.flutter('kss_v3_historical_subject_report.php')),
          body: {
            'teacher_id': widget.teacherId,
            'assignment_id': widget.assignmentId,
            'student_id': widget.studentId,
            'cycle_id': row['cycle_id'].toString(),
          });
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to open report.').toString()
            : 'Unable to open report.');
      }
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => KssV3SubjectReportPdfPage(
                    report:
                        Map<String, dynamic>.from(decoded['data'] as Map))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  void _compare() {
    final completed =
        _rows.where((row) => row['subject_status'] == 'COMPLETED').toList();
    if (completed.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete two assessment cycles to compare them.')));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => KssV3CycleComparisonPage(
                teacherId: widget.teacherId,
                assignmentId: widget.assignmentId,
                studentId: widget.studentId,
                cycles: completed)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
            title: const Text('Assessment History'),
            backgroundColor: Growkids.purpleFlo,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  tooltip: 'Compare assessments',
                  onPressed: _loading ? null : _compare,
                  icon: const Icon(Icons.compare_arrows_outlined))
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _rows.isEmpty
                    ? const Center(child: Text('No assessment records yet.'))
                    : LayoutBuilder(builder: (context, constraints) {
                        final horizontal = constraints.maxWidth > 860
                            ? (constraints.maxWidth - 760) / 2
                            : 20.0;
                        return ListView(
                            padding: EdgeInsets.fromLTRB(
                                horizontal, 22, horizontal, 48),
                            children: [
                              Text(widget.studentName,
                                  style: const TextStyle(
                                      color: _ink,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('${_rows.length} assessment cycles',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 13)),
                              const SizedBox(height: 16),
                              ..._rows.map((row) => Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: _border),
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: ListTile(
                                      onTap:
                                          row['subject_status'] == 'COMPLETED'
                                              ? () => _openReport(row)
                                              : null,
                                      leading: const CircleAvatar(
                                          backgroundColor: _softPurple,
                                          foregroundColor: Growkids.purpleFlo,
                                          child: Icon(Icons.history)),
                                      title: Text(
                                          '${row['semester'] == 'SEM2' ? 'Semester 2' : 'Semester 1'} • Cycle ${row['cycle_no']}'),
                                      subtitle: Text(
                                          '${row['completed_groups']} sections completed • ${row['subject_status'] == 'COMPLETED' ? 'PDF available' : row['subject_status'] ?? row['cycle_status']}',
                                          style: const TextStyle(
                                              color: _muted, fontSize: 12)),
                                      trailing: row['final_tp'] == null
                                          ? null
                                          : KssV3TpStyle.badge(row['final_tp']),
                                    ),
                                  )),
                            ]);
                      }),
      );
}
