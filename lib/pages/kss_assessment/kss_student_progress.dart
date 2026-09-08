import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_report_preview.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_assessment_history_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssStudentProgress extends StatefulWidget {
  final String teacherId;
  final String classId;

  const KssStudentProgress({
    super.key,
    required this.teacherId,
    required this.classId,
  });

  @override
  State<KssStudentProgress> createState() => _KssStudentProgressState();
}

class _KssStudentProgressState extends State<KssStudentProgress> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _standards = [];
  Map<String, dynamic> _classData = {};
  Map<String, dynamic>? _activeBatch;
  String? _selectedStudentId;
  String _reportingPeriod = 'SEM1';
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
        Uri.parse(ApiConfig.flutter('kss_student_progress.php')),
        body: {
          'teacher_id': widget.teacherId,
          'class_id': widget.classId,
          'reporting_period': _reportingPeriod,
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load student progress.')
                .toString()
            : 'Unable to load student progress.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final students = (data['students'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _students = students;
        _classData = Map<String, dynamic>.from(data['class'] as Map? ?? const {});
        final activeRaw = data['active_batch'];
        _activeBatch = activeRaw is Map ? Map<String, dynamic>.from(activeRaw) : null;
        _standards = (data['standards'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (students.isNotEmpty &&
            !students.any((student) =>
                student['student_id'].toString() == _selectedStudentId)) {
          _selectedStudentId = students.first['student_id'].toString();
        }
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

  Map<String, dynamic> get _selectedStudent => _students.firstWhere(
        (student) => student['student_id'].toString() == _selectedStudentId,
      );

  Future<void> _openReport(Map<String, dynamic> summary) async {
    final completed = int.tryParse('${summary['completed_sk'] ?? 0}') ?? 0;
    final total = int.tryParse('${summary['total_sk'] ?? 0}') ?? 0;
    if (total == 0 || completed != total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all SK before generating the report.')),
      );
      return;
    }
    var overallTp = int.tryParse('${summary['recommended_tp'] ?? ''}');
    if (summary['has_mode_tie'] == true) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.flutter('kss_overall_tp.php')),
          body: {
            'teacher_id': widget.teacherId,
            'class_id': widget.classId,
            'student_id': _selectedStudent['student_id'].toString(),
            'reporting_period': _reportingPeriod,
            'action': 'LOAD',
          },
        );
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
          final report = (decoded['data'] as Map?)?['report'] as Map?;
          overallTp = int.tryParse('${report?['final_tp'] ?? ''}');
        }
      } catch (_) {}
    }
    if (overallTp == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set the Overall TP professional judgement before generating the report.')),
      );
      return;
    }
    final int reportOverallTp = overallTp;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KssReportPreviewPage(
          classData: _classData,
          student: _selectedStudent,
          standards: _standards,
          reportingPeriod: _reportingPeriod,
          overallTp: reportOverallTp,
        ),
      ),
    );
  }

  Color _tpColor(int level) {
    if (level <= 2) return const Color(0xFFB42318);
    if (level <= 4) return const Color(0xFF9A6700);
    return const Color(0xFF087A55);
  }

  Color _tpBackground(int level) {
    if (level <= 2) return const Color(0xFFFDE8E7);
    if (level <= 4) return const Color(0xFFFFF1C2);
    return const Color(0xFFDDF7ED);
  }

  Map<String, int> _studentMovement(Map<String, dynamic> student) {
    final history = Map<String, dynamic>.from(
        student['history'] as Map? ?? const {});
    var improved = 0, stable = 0, decreased = 0;
    for (final raw in history.values) {
      final attempts = (raw as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (attempts.length < 2) continue;
      final latest = int.tryParse('${attempts[0]['tp_level']}');
      final previous = int.tryParse('${attempts[1]['tp_level']}');
      if (latest == null || previous == null) continue;
      if (latest > previous) {
        improved++;
      } else if (latest < previous) {
        decreased++;
      } else {
        stable++;
      }
    }
    return {'improved': improved, 'stable': stable, 'decreased': decreased};
  }

  String _studentTrend(Map<String, dynamic> student) {
    final movement = _studentMovement(student);
    final up = movement['improved'] ?? 0;
    final same = movement['stable'] ?? 0;
    final down = movement['decreased'] ?? 0;
    if (up + same + down == 0) return 'baseline';
    if (up > 0 && down > 0) return 'mixed';
    if (up > 0) return 'improving';
    if (down > 0) return 'review';
    return 'stable';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(
          child: CircularProgressIndicator(color: Growkids.purpleFlo),
        ),
      );
    }
    if (_error != null) return _state(_error!, _load);
    if (_students.isEmpty) {
      return _state('No students are enrolled in this class.', null);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final detail = constraints.maxWidth >= 900
          ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 250, child: _studentList()),
              const SizedBox(width: 18),
              Expanded(child: _studentProgress()),
            ],
          )
          : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _studentDropdown(),
            const SizedBox(height: 16),
            _studentProgress(),
          ],
        );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _classOverview(),
        const SizedBox(height: 18),
        detail,
      ]);
    });
  }

  Widget _classOverview() {
    final trendCounts = <String, int>{};
    final tpCounts = <int, int>{};
    final decreasedByStandard = <String, int>{};
    for (final student in _students) {
      final trend = _studentTrend(student);
      trendCounts[trend] = (trendCounts[trend] ?? 0) + 1;
      final summary = Map<String, dynamic>.from(
          student['summary'] as Map? ?? const {});
      final overall = int.tryParse(
          '${summary['confirmed_overall_tp'] ?? summary['recommended_tp'] ?? ''}');
      if (overall != null) tpCounts[overall] = (tpCounts[overall] ?? 0) + 1;
      final history = Map<String, dynamic>.from(
          student['history'] as Map? ?? const {});
      for (final entry in history.entries) {
        final attempts = (entry.value as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (attempts.length < 2) continue;
        final latest = int.tryParse('${attempts[0]['tp_level']}');
        final previous = int.tryParse('${attempts[1]['tp_level']}');
        if (latest != null && previous != null && latest < previous) {
          decreasedByStandard[entry.key] =
              (decreasedByStandard[entry.key] ?? 0) + 1;
        }
      }
    }
    final focus = decreasedByStandard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E1E8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final heading = Row(children: [
            Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE8FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.groups_2_rounded,
                color: Growkids.purpleFlo),
          ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Class Performance',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              Text('${_reportingPeriod == 'SEM1' ? 'Semester 1' : 'Semester 2'} • ${_students.length} students • Published results',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF777486))),
            ])),
          ]);
          if (constraints.maxWidth < 560) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              heading,
              const SizedBox(height: 12),
              _periodDropdown(double.infinity),
            ]);
          }
          return Row(children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            _periodDropdown(190),
          ]);
        }),
        const SizedBox(height: 15),
        Wrap(spacing: 9, runSpacing: 9, children: [
          _classStat('Improving', trendCounts['improving'] ?? 0,
              Icons.trending_up_rounded, const Color(0xFF087A55), const Color(0xFFDDF7ED)),
          _classStat('Mixed', trendCounts['mixed'] ?? 0,
              Icons.swap_horiz_rounded, const Color(0xFF9A6700), const Color(0xFFFFF1C2)),
          _classStat('Stable', trendCounts['stable'] ?? 0,
              Icons.trending_flat_rounded, const Color(0xFF6552D9), const Color(0xFFEDE8FF)),
          _classStat('Review', trendCounts['review'] ?? 0,
              Icons.priority_high_rounded, const Color(0xFFB42318), const Color(0xFFFDE8E7)),
          if ((trendCounts['baseline'] ?? 0) > 0)
            _classStat('Baseline', trendCounts['baseline'] ?? 0,
                Icons.flag_outlined, const Color(0xFF5F5B6B), const Color(0xFFF3F2F7)),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 13),
        LayoutBuilder(builder: (context, constraints) {
          final distribution = _tpDistribution(tpCounts);
          final focusAreas = _focusAreas(focus.take(3).toList());
          if (constraints.maxWidth < 700) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              distribution,
              const SizedBox(height: 14),
              focusAreas,
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: distribution),
            const SizedBox(width: 22),
            Expanded(child: focusAreas),
          ]);
        }),
      ]),
    );
  }

  Widget _classStat(
    String label,
    int value,
    IconData icon,
    Color color,
    Color background,
  ) {
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF5F5B6B), fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _periodDropdown(double width) {
    return SizedBox(
      width: width,
      height: 58,
      child: DropdownButtonFormField<String>(
        initialValue: _reportingPeriod,
        style: const TextStyle(
          fontFamily: 'Renogare',
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF302A3A),
        ),
        decoration: InputDecoration(
          labelText: 'Reporting Period',
          labelStyle: const TextStyle(
            fontFamily: 'Renogare',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5F5B6B),
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: const [
          DropdownMenuItem(value: 'SEM1', child: Text('Semester 1')),
          DropdownMenuItem(value: 'SEM2', child: Text('Semester 2')),
        ],
        onChanged: (value) async {
          if (value == null || value == _reportingPeriod) return;
          setState(() => _reportingPeriod = value);
          await _load();
        },
      ),
    );
  }

  Widget _tpDistribution(Map<int, int> counts) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Overall TP Distribution',
          style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      const Text('Current published Overall TP across the class.',
          style: TextStyle(fontSize: 11, color: Color(0xFF777486))),
      const SizedBox(height: 9),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: List.generate(6, (index) {
          final tp = index + 1;
          final count = counts[tp] ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: count == 0 ? const Color(0xFFF5F4F8) : _tpBackground(tp),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('TP$tp  $count', style: TextStyle(
              color: count == 0 ? const Color(0xFF9996A3) : _tpColor(tp),
              fontWeight: FontWeight.w900,
              fontSize: 11,
            )),
          );
        }),
      ),
    ]);
  }

  Widget _focusAreas(List<MapEntry<String, int>> focus) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Class Focus Areas',
          style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      const Text('Skills that decreased for the most students.',
          style: TextStyle(fontSize: 11, color: Color(0xFF777486))),
      const SizedBox(height: 9),
      if (focus.isEmpty)
        const Text('No decreased SK detected in the latest comparison.',
            style: TextStyle(fontSize: 12, color: Color(0xFF087A55), fontWeight: FontWeight.w700))
      else
        ...focus.map((entry) {
          Map<String, dynamic>? standard;
          for (final item in _standards) {
            if (item['content_standard_id'].toString() == entry.key) {
              standard = item;
              break;
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('SK ${standard?['sk_code'] ?? entry.key}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFB42318), fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(
                (standard?['sk_statement'] ?? 'Learning skill').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              )),
              Text('${entry.value} student${entry.value == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF777486))),
            ]),
          );
        }),
    ]);
  }

  Widget _studentList() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E1E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 5, 6, 10),
            child: Text('Students',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          ..._students.map((student) {
            final selected =
                student['student_id'].toString() == _selectedStudentId;
            final summary = Map<String, dynamic>.from(
                student['summary'] as Map? ?? const {});
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: selected ? const Color(0xFFEDE8FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  onTap: () => setState(() =>
                      _selectedStudentId = student['student_id'].toString()),
                  borderRadius: BorderRadius.circular(11),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (student['student_name'] ?? '-').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${summary['completed_sk'] ?? 0}/${summary['total_sk'] ?? 0} SK completed',
                          style: const TextStyle(
                              color: Color(0xFF777486), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _studentDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedStudentId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Student',
        prefixIcon: const Icon(Icons.person_rounded, color: Growkids.purpleFlo),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: _students
          .map((student) => DropdownMenuItem(
                value: student['student_id'].toString(),
                child: Text((student['student_name'] ?? '-').toString()),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedStudentId = value),
    );
  }

  Widget _studentProgress() {
    final student = _selectedStudent;
    final summary =
        Map<String, dynamic>.from(student['summary'] as Map? ?? const {});
    final results =
        Map<String, dynamic>.from(student['results'] as Map? ?? const {});
    final history =
        Map<String, dynamic>.from(student['history'] as Map? ?? const {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          (student['student_name'] ?? '-').toString(),
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, actionConstraints) => Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: actionConstraints.maxWidth < 650
                  ? actionConstraints.maxWidth
                  : 285,
              height: 58,
              child: FilledButton.icon(
                onPressed: () => _openReport(summary),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text(
                  'Preview Report',
                  style: TextStyle(
                    fontFamily: 'Renogare',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Growkids.purpleFlo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: actionConstraints.maxWidth < 650
                  ? actionConstraints.maxWidth
                  : 285,
              height: 58,
              child: Material(
                color: Growkids.purpleFlo,
                borderRadius: BorderRadius.circular(14),
                elevation: 3,
                shadowColor: Growkids.purpleFlo.withValues(alpha: .28),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KssAssessmentHistoryPage(
                        teacherId: widget.teacherId,
                        classId: widget.classId,
                        studentId: student['student_id'].toString(),
                        initialPeriod: _reportingPeriod,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0x33FFFFFF),
                        child: Icon(Icons.insights_rounded, color: Colors.white, size: 21),
                      ),
                      SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Student Performance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        Text('View learning progression', style: TextStyle(color: Color(0xFFDCD4FF), fontSize: 11)),
                      ])),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        )),
        const SizedBox(height: 12),
        if (_activeBatch != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7DA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE9C85A)),
            ),
            child: Row(children: [
              const Icon(Icons.pending_actions_rounded, color: Color(0xFF9A6700)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _activeBatch!['assessment_type'] == 'REVISION'
                      ? 'Revision ${_activeBatch!['revision_no']} in progress'
                      : 'Initial assessment in progress',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${_activeBatch!['completed_sk']} of ${_activeBatch!['total_sk']} SK complete. Official Progress remains unchanged until publishing.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6D5B16)),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        _summaryCard(summary),
        const SizedBox(height: 18),
        const Text('Progress Map',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        const Text('Select an SK to view SP observations and result details.',
            style: TextStyle(color: Color(0xFF777486), fontSize: 12)),
        const SizedBox(height: 10),
        _progressMap(results, history),
      ],
    );
  }

  Widget _progressMap(
    Map<String, dynamic> results,
    Map<String, dynamic> history,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final standard in _standards) {
      grouped
          .putIfAbsent(standard['domain_id'].toString(), () => [])
          .add(standard);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final domainWidth = constraints.maxWidth >= 1050
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: grouped.values.map((standards) {
          final first = standards.first;
          return SizedBox(
            width: domainWidth,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E1E8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEDE8FF),
                          borderRadius: BorderRadius.circular(9)),
                      child: Text(first['domain_code'].toString(),
                          style: const TextStyle(
                              color: Growkids.purpleFlo,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(first['domain_title'].toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, tileConstraints) {
                    final columns = tileConstraints.maxWidth < 420 ? 2 : 3;
                    final tileWidth =
                        (tileConstraints.maxWidth - ((columns - 1) * 8)) /
                            columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: standards.map((standard) {
                        final id = standard['content_standard_id'].toString();
                        final raw = results[id];
                        final result =
                            raw is Map ? Map<String, dynamic>.from(raw) : null;
                        final rows = (history[id] as List? ?? [])
                            .map((item) =>
                                Map<String, dynamic>.from(item as Map))
                            .toList();
                        return SizedBox(
                            width: tileWidth,
                            child: _progressTile(standard, result, rows));
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _progressTile(
    Map<String, dynamic> standard,
    Map<String, dynamic>? result,
    List<Map<String, dynamic>> history,
  ) {
    final level = result == null ? null : int.tryParse('${result['tp_level']}');
    return Material(
      color: level == null ? const Color(0xFFF3F2F7) : _tpBackground(level),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showSkDetails(standard, result, history),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SK ${standard['sk_code']}',
                      style: TextStyle(
                          color: level == null
                              ? const Color(0xFF777486)
                              : _tpColor(level),
                          fontWeight: FontWeight.w900,
                          fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(level == null ? 'Pending' : 'TP$level',
                      style: TextStyle(
                          color: level == null
                              ? const Color(0xFF777486)
                              : _tpColor(level),
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 19,
                color:
                    level == null ? const Color(0xFF9996A3) : _tpColor(level)),
          ]),
        ),
      ),
    );
  }

  Future<void> _showSkDetails(
    Map<String, dynamic> standard,
    Map<String, dynamic>? result,
    List<Map<String, dynamic>> history,
  ) async {
    final level = result == null ? null : int.tryParse('${result['tp_level']}');
    final learning = (standard['learning_standards'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final observations = Map<String, dynamic>.from(
        result?['sp_observations'] as Map? ?? const {});
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.sizeOf(context).height * .88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                child: Row(children: [
                  Container(
                    width: 54,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: level == null
                            ? const Color(0xFFF3F2F7)
                            : _tpBackground(level),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(level == null ? '—' : 'TP$level',
                        style: TextStyle(
                            color: level == null
                                ? const Color(0xFF777486)
                                : _tpColor(level),
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('SK ${standard['sk_code']}',
                            style: const TextStyle(
                                color: Growkids.purpleFlo,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(standard['sk_statement'].toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ])),
                  IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (result != null) ...[
                      const Text('Tafsiran TP',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(result['interpretation'].toString(),
                          style: const TextStyle(
                              color: Color(0xFF3F3B49),
                              fontSize: 16,
                              height: 1.45,
                              fontWeight: FontWeight.w600)),
                      if ((result['teacher_summary'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(result['teacher_summary'].toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 16),
                    ],
                    Row(children: [
                      const Expanded(
                          child: Text('Standard Pembelajaran',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900))),
                      if (history.length > 1)
                        TextButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _showHistory(standard, history);
                            },
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('History')),
                    ]),
                    const SizedBox(height: 6),
                    ...learning.map((sp) {
                      final raw =
                          observations[sp['learning_standard_id'].toString()];
                      final observation =
                          raw is Map ? Map<String, dynamic>.from(raw) : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF7F7FB),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SP ${sp['sp_code']}',
                                  style: const TextStyle(
                                      color: Growkids.purpleFlo,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(sp['sp_statement'].toString()),
                              if (observation != null) ...[
                                const SizedBox(height: 8),
                                Text(observation['observation_text'].toString(),
                                    style: const TextStyle(
                                        color: Color(0xFF5F5B6B),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic)),
                              ],
                            ]),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _responsiveDomainLayout(
    Map<String, dynamic> results,
    Map<String, dynamic> history,
  ) {
    final sections = _domainSections(results, history);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1050) {
          return Column(children: sections);
        }
        final left = <Widget>[];
        final right = <Widget>[];
        for (var index = 0; index < sections.length; index++) {
          if (index.isEven) {
            left.add(sections[index]);
          } else {
            right.add(sections[index]);
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            const SizedBox(width: 14),
            Expanded(child: Column(children: right)),
          ],
        );
      },
    );
  }

  List<Widget> _domainSections(
    Map<String, dynamic> results,
    Map<String, dynamic> history,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final standard in _standards) {
      grouped
          .putIfAbsent(standard['domain_id'].toString(), () => [])
          .add(standard);
    }
    return grouped.values.map((standards) {
      final first = standards.first;
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E1E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F0FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(first['domain_code'].toString(),
                        style: const TextStyle(
                            color: Growkids.purpleFlo,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(first['domain_title'].toString(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900))),
                  Text('${standards.length} SK',
                      style: const TextStyle(
                          color: Color(0xFF777486), fontSize: 12)),
                ],
              ),
            ),
            ...standards.map((standard) {
              final id = standard['content_standard_id'].toString();
              final raw = results[id];
              final result = raw is Map ? Map<String, dynamic>.from(raw) : null;
              final rows = (history[id] as List? ?? [])
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: _standardResult(standard, result, rows),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      );
    }).toList();
  }

  Widget _summaryCard(Map<String, dynamic> summary) {
    final completed = int.tryParse('${summary['completed_sk'] ?? 0}') ?? 0;
    final total = int.tryParse('${summary['total_sk'] ?? 0}') ?? 0;
    final recommended = int.tryParse('${summary['recommended_tp'] ?? ''}');
    final tie = summary['has_mode_tie'] == true;
    final confirmed =
        int.tryParse('${summary['confirmed_overall_tp'] ?? ''}');
    final displayedTp = confirmed ?? recommended;
    final needsJudgement = tie && confirmed == null;
    final candidates = (summary['mode_candidates'] as List? ?? [])
        .map((item) => 'TP$item')
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E1E8)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final progress = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assessment Progress',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('$completed of $total SK completed',
                style: const TextStyle(color: Color(0xFF777486))),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 7,
              borderRadius: BorderRadius.circular(10),
              color: Growkids.purpleFlo,
              backgroundColor: const Color(0xFFEDE8FF),
            ),
          ],
        );
        final overall = Container(
          constraints: const BoxConstraints(minWidth: 190, minHeight: 118),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: needsJudgement
                ? const Color(0xFFFFF1C2)
                : displayedTp == null
                    ? const Color(0xFFF3F2F7)
                    : _tpBackground(displayedTp),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: needsJudgement
                  ? const Color(0xFF9A6700)
                  : displayedTp == null
                      ? const Color(0xFFD8D6DF)
                      : _tpColor(displayedTp),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OVERALL TP',
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: .5,
                      color: Color(0xFF5F5B6B),
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                needsJudgement
                    ? 'Judgement needed'
                    : displayedTp == null
                        ? 'Not available'
                        : 'TP$displayedTp',
                style: TextStyle(
                  fontSize: needsJudgement ? 16 : 28,
                  fontWeight: FontWeight.w900,
                  color: needsJudgement
                      ? const Color(0xFF9A6700)
                      : displayedTp == null
                          ? const Color(0xFF777486)
                          : _tpColor(displayedTp),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                needsJudgement
                    ? 'Professional judgement required'
                    : confirmed != null && tie
                        ? 'Confirmed by teacher'
                        : 'Calculated by mode',
                style: TextStyle(
                  fontSize: 11,
                  color: needsJudgement
                      ? const Color(0xFF9A6700)
                      : const Color(0xFF5F5B6B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (needsJudgement)
                Text(candidates, style: const TextStyle(fontSize: 11)),
              if (needsJudgement) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _showJudgementDialog(summary),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9A6700),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Set Overall TP'),
                ),
              ],
            ],
          ),
        );
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [overall, const SizedBox(height: 14), progress],
          );
        }
        return Row(children: [
          overall,
          const SizedBox(width: 18),
          Expanded(child: progress),
        ]);
      }),
    );
  }

  Future<void> _showJudgementDialog(Map<String, dynamic> summary) async {
    final student = _selectedStudent;
    final candidates = (summary['mode_candidates'] as List? ?? [])
        .map((item) => int.parse(item.toString()))
        .toList();
    Map<String, dynamic>? savedReport;
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_overall_tp.php')),
        body: {
          'teacher_id': widget.teacherId,
          'class_id': widget.classId,
          'student_id': student['student_id'].toString(),
          'reporting_period': _reportingPeriod,
          'action': 'LOAD',
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(
            decoded is Map ? decoded['message'] : 'Unable to load Overall TP.');
      }
      final reportRaw = (decoded['data'] as Map?)?['report'];
      if (reportRaw is Map) savedReport = Map<String, dynamic>.from(reportRaw);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
      return;
    }
    if (!mounted) return;
    var selectedTp = int.tryParse('${savedReport?['final_tp'] ?? ''}');
    final note = TextEditingController(
        text: (savedReport?['professional_judgement_note'] ?? '').toString());
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Professional Judgement'),
                content: SizedBox(
                  width: 520,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${student['student_name']} • $_reportingPeriod',
                            style: const TextStyle(color: Color(0xFF777486))),
                        const SizedBox(height: 12),
                        const Text(
                            'The TP frequency has a tie. Select the most appropriate Overall TP using professional judgement.'),
                        const SizedBox(height: 14),
                        Wrap(
                            spacing: 10,
                            children: candidates
                                .map((level) => ChoiceChip(
                                      label: Text('TP$level'),
                                      selected: selectedTp == level,
                                      selectedColor: _tpBackground(level),
                                      onSelected: (_) => setDialogState(
                                          () => selectedTp = level),
                                    ))
                                .toList()),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: note,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                              labelText: 'Professional judgement reason',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder()),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Reason is required.'
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: selectedTp == null
                        ? null
                        : () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(dialogContext, true);
                            }
                          },
                    style: FilledButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo),
                    child: const Text('Confirm Overall TP'),
                  ),
                ],
              )),
    );
    if (saved == true) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.flutter('kss_overall_tp.php')),
          body: {
            'teacher_id': widget.teacherId,
            'class_id': widget.classId,
            'student_id': student['student_id'].toString(),
            'reporting_period': _reportingPeriod,
            'action': 'SAVE',
            'final_tp': selectedTp.toString(),
            'professional_judgement_note': note.text.trim(),
          },
        );
        final decoded = json.decode(response.body);
        if (response.statusCode != 200 ||
            decoded is! Map ||
            decoded['success'] != true) {
          throw Exception(decoded is Map
              ? decoded['message']
              : 'Unable to save Overall TP.');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Overall TP confirmed successfully.')));
        }
        await _load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))));
        }
      }
    }
    note.dispose();
  }

  Widget _standardResult(
    Map<String, dynamic> standard,
    Map<String, dynamic>? result,
    List<Map<String, dynamic>> history,
  ) {
    final level = result == null ? null : int.tryParse('${result['tp_level']}');
    final learningStandards = (standard['learning_standards'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final observations = Map<String, dynamic>.from(
        result?['sp_observations'] as Map? ?? const {});
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E1E8)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: level == null
                        ? const Color(0xFFF3F2F7)
                        : _tpBackground(level),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    level == null ? '—' : 'TP$level',
                    style: TextStyle(
                      color: level == null
                          ? const Color(0xFF9996A3)
                          : _tpColor(level),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SK ${standard['sk_code']}',
                          style: const TextStyle(
                              color: Growkids.purpleFlo,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text((standard['sk_statement'] ?? '-').toString()),
                      const SizedBox(height: 5),
                      Text(
                        '${learningStandards.length} Standard Pembelajaran${history.length > 1 ? ' • ${history.length} attempts' : ''}',
                        style: const TextStyle(
                            color: Color(0xFF777486), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (history.length > 1)
                  IconButton(
                    tooltip: 'View history',
                    onPressed: () => _showHistory(standard, history),
                    icon: const Icon(Icons.history_rounded,
                        color: Growkids.purpleFlo),
                  ),
              ],
            ),
          ),
          if (learningStandards.isNotEmpty)
            ExpansionTile(
              dense: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              title: const Text('View Standard Pembelajaran',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              children: learningStandards.map((sp) {
                final observationRaw =
                    observations[sp['learning_standard_id'].toString()];
                final observation = observationRaw is Map
                    ? Map<String, dynamic>.from(observationRaw)
                    : null;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFFE9E8EF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SP ${sp['sp_code']}',
                          style: const TextStyle(
                              color: Growkids.purpleFlo,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(sp['sp_statement'].toString()),
                      if (observation != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F7FB),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            observation['observation_text'].toString(),
                            style: const TextStyle(
                                color: Color(0xFF5F5B6B), fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _showHistory(
    Map<String, dynamic> standard,
    List<Map<String, dynamic>> history,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('SK ${standard['sk_code']} History'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: history.map((result) {
              final level = int.tryParse('${result['tp_level']}') ?? 1;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 46,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tpBackground(level),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'TP$level',
                    style: TextStyle(
                      color: _tpColor(level),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  result['cycle_type'] == 'REVISION'
                      ? 'Revision ${result['revision_no'] ?? ''}'
                      : 'Initial Assessment',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text((result['finalized_at'] ?? '').toString()),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Growkids.purpleFlo,
              fontSize: 9,
              fontWeight: FontWeight.w900)),
    );
  }

  Widget _state(String message, VoidCallback? action) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.insights_rounded, color: Growkids.purpleFlo, size: 40),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: action, child: const Text('Try Again')),
        ],
      ]),
    );
  }
}
