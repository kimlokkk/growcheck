import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_subject_report_pdf_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3SubjectReportPage extends StatefulWidget {
  final String teacherId, assignmentId, studentId;
  const KssV3SubjectReportPage(
      {super.key,
      required this.teacherId,
      required this.assignmentId,
      required this.studentId});
  @override
  State<KssV3SubjectReportPage> createState() => _KssV3SubjectReportPageState();
}

class _KssV3SubjectReportPageState extends State<KssV3SubjectReportPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _softPurple = Color(0xFFEDEDF7);
  Map? _data;
  bool _loading = true;
  String? _error;
  Map<String, String> get _body => {
        'teacher_id': widget.teacherId,
        'assignment_id': widget.assignmentId,
        'student_id': widget.studentId
      };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map> _request(Map<String, String> body) async {
    final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_v3_subject_report.php')),
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

  Future<void> _load() async {
    try {
      final decoded = await _request({..._body, 'action': 'load'});
      if (mounted) {
        setState(() {
          _data = decoded['data'] as Map?;
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
    final items = (_data?['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
            title: const Text('Subject report'),
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
                          Text(_data?['subject_name']?.toString() ?? '',
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: _softPurple,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                const Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Completed assessment',
                                          style: TextStyle(
                                              color: _ink,
                                              fontWeight: FontWeight.w800)),
                                      SizedBox(height: 3),
                                      Text(
                                          'Ready to generate as an official PDF.',
                                          style: TextStyle(
                                              color: _muted, fontSize: 12)),
                                    ])),
                                KssV3TpStyle.badge(_data?['final_tp']),
                              ])),
                          const SizedBox(height: 16),
                          const Text('Section results',
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          ...items.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: _border),
                                  borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                  title: Text(
                                      '${item['tp_group_code_snapshot']} ${item['tp_group_title_snapshot']}'),
                                  subtitle: (item['teacher_summary_snapshot']
                                              ?.toString()
                                              .isNotEmpty ??
                                          false)
                                      ? Text(item['teacher_summary_snapshot']
                                          .toString())
                                      : null,
                                  trailing:
                                      KssV3TpStyle.badge(item['tp_level'])))),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KssV3SubjectReportPdfPage(
                                  report: Map<String, dynamic>.from(_data!),
                                ),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                                backgroundColor: Growkids.purpleFlo,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48)),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Generate PDF / Print'),
                          ),
                        ]);
                  }));
  }
}
