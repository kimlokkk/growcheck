import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_group_assessment_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_subject_result_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_assessment_history_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3StudentAssessmentPage extends StatefulWidget {
  final String teacherId;
  final String assignmentId;
  final String subjectName;
  final Map<String, dynamic> student;

  const KssV3StudentAssessmentPage(
      {super.key,
      required this.teacherId,
      required this.assignmentId,
      required this.subjectName,
      required this.student});

  @override
  State<KssV3StudentAssessmentPage> createState() =>
      _KssV3StudentAssessmentPageState();
}

class _KssV3StudentAssessmentPageState
    extends State<KssV3StudentAssessmentPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _softPurple = Color(0xFFEDEDF7);
  static const _success = Color(0xFF2E7D32);
  static const _warning = Color(0xFFA85D00);
  List<Map<String, dynamic>> _groups = [];
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
          Uri.parse(ApiConfig.flutter('kss_v3_student_assessment.php')),
          body: {
            'teacher_id': widget.teacherId,
            'assignment_id': widget.assignmentId,
            'student_id': widget.student['student_id'].toString(),
          });
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load assessment.').toString()
            : 'Unable to load assessment.');
      }
      final data = decoded['data'] as Map? ?? {};
      if (!mounted) return;
      setState(() => _groups = (data['tp_groups'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList());
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
  Widget build(BuildContext context) {
    final completed = _groups
        .where((group) => group['status']?.toString() == 'FINALIZED')
        .length;
    final allComplete = _groups.isNotEmpty && completed == _groups.length;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
          title: Text(widget.student['student_name'].toString()),
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'History',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KssV3AssessmentHistoryPage(
                    teacherId: widget.teacherId,
                    assignmentId: widget.assignmentId,
                    studentId: widget.student['student_id'].toString(),
                    studentName: widget.student['student_name'].toString(),
                  ),
                ),
              ),
            ),
          ]),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: allComplete
                  ? FilledButton.icon(
                      onPressed: _openOverallResult,
                      style: FilledButton.styleFrom(
                          backgroundColor: Growkids.purpleFlo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Review overall result'))
                  : OutlinedButton.icon(
                      onPressed: _openOverallResult,
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Review overall result'))),
      body: LayoutBuilder(builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 860
            ? (constraints.maxWidth - 760) / 2
            : 20.0;
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) return Center(child: Text(_error!));
        return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 96),
                children: [
                  Text(widget.subjectName,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(widget.student['student_name'].toString(),
                      style: const TextStyle(color: _muted, fontSize: 13)),
                  const SizedBox(height: 16),
                  _progressCard(),
                  const SizedBox(height: 20),
                  const Text('Assessment sections',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ..._groups.map((group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _surface(
                          child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => KssV3TpGroupAssessmentPage(
                                        teacherId: widget.teacherId,
                                        assignmentId: widget.assignmentId,
                                        studentId: widget.student['student_id']
                                            .toString(),
                                        tpGroup: group,
                                      )));
                          _load();
                        },
                        leading: _sectionIcon(group),
                        title: Text('${group['code']} ${group['title']}',
                            style: const TextStyle(
                                color: _ink, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${group['observation_groups']} observation sections',
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          if (group['tp_level'] != null)
                            KssV3TpStyle.badge(group['tp_level'])
                          else
                            _sectionStatus(group['status']),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: _muted),
                        ]),
                      )))),
                ]));
      }),
    );
  }

  Future<void> _openOverallResult() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KssV3SubjectResultPage(
          teacherId: widget.teacherId,
          assignmentId: widget.assignmentId,
          studentId: widget.student['student_id'].toString(),
        ),
      ),
    );
    _load();
  }

  Widget _progressCard() {
    final completed = _groups
        .where((group) => group['status']?.toString() == 'FINALIZED')
        .length;
    final total = _groups.length;
    final progress = total == 0 ? 0.0 : completed / total;
    return _surface(
        color: _softPurple,
        borderColor: GrowkidsPastel.purple2,
        child: Container(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.track_changes_outlined,
                    color: Growkids.purpleFlo),
                const SizedBox(width: 8),
                Text('$completed of $total sections completed',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white,
                      color: Growkids.purpleFlo)),
            ])));
  }

  Widget _surface(
          {required Widget child,
          Color color = Colors.white,
          Color borderColor = _border}) =>
      Material(
          color: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor)),
          clipBehavior: Clip.antiAlias,
          child: child);

  Widget _sectionIcon(Map<String, dynamic> group) {
    final finalized = group['status']?.toString() == 'FINALIZED';
    return CircleAvatar(
        radius: 18,
        backgroundColor: finalized ? const Color(0xFFE6F4E8) : _softPurple,
        foregroundColor: finalized ? _success : Growkids.purpleFlo,
        child: Icon(finalized ? Icons.check_rounded : Icons.edit_outlined,
            size: 18));
  }

  Widget _sectionStatus(dynamic rawStatus) {
    final status = rawStatus?.toString() ?? 'NOT_STARTED';
    final inProgress = status == 'IN PROGRESS' || status == 'IN_PROGRESS';
    final color = inProgress ? _warning : _muted;
    return Text(inProgress ? 'In progress' : 'Not started',
        style: TextStyle(color: color, fontSize: 11));
  }
}
