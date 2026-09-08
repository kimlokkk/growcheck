import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssSkFinalizePage extends StatefulWidget {
  final String teacherId;
  final String assessmentCycleId;

  const KssSkFinalizePage({
    super.key,
    required this.teacherId,
    required this.assessmentCycleId,
  });

  @override
  State<KssSkFinalizePage> createState() => _KssSkFinalizePageState();
}

class _KssSkFinalizePageState extends State<KssSkFinalizePage> {
  Map<String, dynamic> _cycle = {};
  Map<String, dynamic> _sk = {};
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _tpOptions = [];
  Map<String, List<Map<String, dynamic>>> _observations = {};
  final Map<String, int> _selectedTp = {};
  final Map<String, TextEditingController> _summaries = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _summaries.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_sk_finalize_data.php')),
        body: {
          'teacher_id': widget.teacherId,
          'assessment_cycle_id': widget.assessmentCycleId,
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load TP assessment.').toString()
            : 'Unable to load TP assessment.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final students = (data['students'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      for (final controller in _summaries.values) {
        controller.dispose();
      }
      _summaries.clear();
      _selectedTp.clear();
      for (final student in students) {
        final id = student['student_id'].toString();
        final result = student['result'] as Map?;
        if (result != null) {
          _selectedTp[id] = int.parse(result['tp_level'].toString());
        }
        _summaries[id] = TextEditingController(
            text: (result?['teacher_summary'] ?? '').toString());
      }
      final obsRaw =
          Map<String, dynamic>.from(data['observations'] as Map? ?? const {});
      if (!mounted) return;
      setState(() {
        _cycle = Map<String, dynamic>.from(data['cycle'] as Map);
        _sk = Map<String, dynamic>.from(data['content_standard'] as Map);
        _students = students;
        _tpOptions = (data['performance_standards'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _observations = obsRaw.map((key, value) => MapEntry(
            key,
            (value as List)
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList()));
        if (students.isNotEmpty &&
            !students.any((item) =>
                item['student_id'].toString() == _selectedStudentId)) {
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

  Map<String, dynamic>? _tpForLevel(int level) {
    for (final option in _tpOptions) {
      if (int.tryParse(option['tp_level'].toString()) == level) return option;
    }
    return null;
  }

  Color _tpColor(int level) {
    if (level <= 2) return const Color(0xFFB42318);
    if (level <= 4) return const Color(0xFF9A6700);
    return const Color(0xFF087A55);
  }

  Color _tpBackgroundColor(int level) {
    if (level <= 2) return const Color(0xFFFDE8E7);
    if (level <= 4) return const Color(0xFFFFF1C2);
    return const Color(0xFFDDF7ED);
  }

  Future<void> _saveStudent(Map<String, dynamic> student) async {
    final id = student['student_id'].toString();
    final level = _selectedTp[id];
    final option = level == null ? null : _tpForLevel(level);
    if (option == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a TP level first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_save_sk_result.php')),
        body: {
          'teacher_id': widget.teacherId,
          'assessment_cycle_id': widget.assessmentCycleId,
          'student_id': id,
          'performance_standard_id':
              option['performance_standard_id'].toString(),
          'teacher_summary': _summaries[id]!.text.trim(),
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to save SK TP.').toString()
            : 'Unable to save SK TP.');
      }
      if (!mounted) return;
      final completed = (decoded['data'] as Map?)?['cycle_completed'] == true;
      if (completed) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF087A55),
              size: 48,
            ),
            title: const Text('Assessment Completed'),
            content: const Text(
              'All student TP results have been saved. You can view the results from the Assessment page.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: FilledButton.styleFrom(
                  backgroundColor: Growkids.purpleFlo,
                ),
                child: const Text('Back to Assessment'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student['student_name']} TP saved.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _allTpAssigned =>
      _students.isNotEmpty &&
      _students.every((student) => student['result'] != null);

  Future<void> _completeAssessment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.fact_check_rounded,
          color: Growkids.purpleFlo,
          size: 42,
        ),
        title: const Text('Complete Assessment?'),
        content: const Text(
          'Please review every student TP before completing. Once completed, the observations and TP results for this semester will be locked.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review Again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
            child: const Text('Complete Assessment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_complete_sk_assessment.php')),
        body: {
          'teacher_id': widget.teacherId,
          'assessment_cycle_id': widget.assessmentCycleId,
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to complete assessment.')
                .toString()
            : 'Unable to complete assessment.');
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF087A55),
            size: 48,
          ),
          title: const Text('Assessment Completed'),
          content: const Text(
            'All results are now locked and saved as the completed assessment.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
              ),
              child: const Text('Back to Assessment'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showStudentResult(Map<String, dynamic> student) async {
    final id = student['student_id'].toString();
    var selectedTp = _selectedTp[id];
    final observations = _observations[id] ?? [];
    final completed = _cycle['status'] == 'COMPLETED';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final width = MediaQuery.sizeOf(context).width;
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: width < 600 ? 12 : 40,
              vertical: width < 600 ? 16 : 32,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 760,
                maxHeight: MediaQuery.sizeOf(context).height * 0.90,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (student['student_name'] ?? '-').toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                completed ? 'SK TP Result' : 'Assign SK TP',
                                style: const TextStyle(
                                  color: Color(0xFF777486),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExpansionTile(
                            initiallyExpanded: selectedTp == null,
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: Text(
                              'SP Evidence (${observations.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            children: observations
                                .map(
                                  (obs) => Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7FB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SP ${obs['sp_code']}',
                                          style: const TextStyle(
                                            color: Growkids.purpleFlo,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          (obs['observation_text'] ?? '')
                                              .toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Achievement Level',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._tpOptions.map((tp) {
                            final level = int.parse(tp['tp_level'].toString());
                            final selected = selectedTp == level;
                            final tpColor = _tpColor(level);
                            final tpBackground = _tpBackgroundColor(level);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Material(
                                color: selected
                                    ? tpBackground
                                    : const Color(0xFFF9F9FC),
                                borderRadius: BorderRadius.circular(13),
                                child: InkWell(
                                  onTap: completed
                                      ? null
                                      : () => setDialogState(
                                            () => selectedTp = level,
                                          ),
                                  borderRadius: BorderRadius.circular(13),
                                  child: Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: selected
                                            ? tpColor
                                            : const Color(0xFFE9E8EF),
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? tpColor
                                                : tpBackground,
                                            borderRadius:
                                                BorderRadius.circular(11),
                                          ),
                                          child: Text(
                                            'TP$level',
                                            style: TextStyle(
                                              color: selected
                                                  ? Colors.white
                                                  : tpColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            (tp['interpretation'] ?? '')
                                                .toString(),
                                          ),
                                        ),
                                        if (selected)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: tpColor,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _summaries[id],
                            enabled: !completed,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Teacher Summary (optional)',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(completed ? 'Close' : 'Cancel'),
                        ),
                        if (!completed) ...[
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: selectedTp == null
                                ? null
                                : () {
                                    _selectedTp[id] = selectedTp!;
                                    Navigator.pop(dialogContext, true);
                                  },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Confirm TP'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Growkids.purpleFlo,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (saved == true) await _saveStudent(student);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
          title: const Text('Assign SK TP'),
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white),
      body: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = width >= 1100
            ? 36.0
            : width >= 600
                ? 24.0
                : 16.0;
        return SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(padding, width >= 600 ? 24 : 16, padding, 32),
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: _body())),
        );
      }),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo)));
    }
    if (_error != null) {
      return Center(
          child: Column(children: [
        Text(_error!),
        FilledButton(onPressed: _load, child: const Text('Try Again'))
      ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Growkids.purpleFlo, Growkids.purpleBright]),
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SK ${_sk['sk_code']}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text((_sk['sk_statement'] ?? '').toString(),
                style: const TextStyle(color: Color(0xFFEDE8FF))),
            const SizedBox(height: 9),
            Text(
                _cycle['status'] == 'COMPLETED'
                    ? 'Assessment Completed'
                    : '${_cycle['reporting_period'] == 'SEM2' ? 'Semester 2' : 'Semester 1'}${_cycle['cycle_type'] == 'REVISION' ? ' • Revision' : ''} • Step 2 of 2 • Assign TP',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700))
          ])),
      const SizedBox(height: 14),
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(14)),
          child: const Text(
              'Use the SP observations as evidence, then assign one TP to this SK using professional judgement.',
              style: TextStyle(color: Color(0xFF7A5412)))),
      if (_cycle['status'] != 'COMPLETED') ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _allTpAssigned
                ? const Color(0xFFDDF7ED)
                : const Color(0xFFEDE8FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final message = Text(
                _allTpAssigned
                    ? 'All student TP drafts are ready. Review the results, then complete the assessment.'
                    : 'TP assignment is in progress. Saved TP results can still be edited until you complete the assessment.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              );
              final button = FilledButton.icon(
                onPressed:
                    _allTpAssigned && !_saving ? _completeAssessment : null,
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Complete Assessment'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF087A55),
                ),
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    message,
                    if (_allTpAssigned) ...[
                      const SizedBox(height: 12),
                      button,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: message),
                  if (_allTpAssigned) ...[
                    const SizedBox(width: 12),
                    button,
                  ],
                ],
              );
            },
          ),
        ),
      ],
      const SizedBox(height: 16),
      _studentResultsList(),
    ]);
  }

  Widget _studentResultsList() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Student Results',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${_students.where((s) => s['result'] != null).length} / ${_students.length} assigned',
                style: const TextStyle(color: Color(0xFF777486)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._students.map((student) {
            final result = student['result'] as Map?;
            final tpLevel = result == null
                ? null
                : int.tryParse(result['tp_level'].toString());
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE9E8EF)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: result == null
                        ? const Color(0xFFEDE8FF)
                        : const Color(0xFFDDF7ED),
                    child: Icon(
                      result == null
                          ? Icons.person_rounded
                          : Icons.check_rounded,
                      color: result == null
                          ? Growkids.purpleFlo
                          : const Color(0xFF0A7D5B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (student['student_name'] ?? '-').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          result == null ? 'TP not assigned' : 'Result saved',
                          style: TextStyle(
                            color: result == null
                                ? const Color(0xFF777486)
                                : const Color(0xFF0A7D5B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 68),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: result == null
                          ? const Color(0xFFF0EFF4)
                          : _tpBackgroundColor(tpLevel!),
                      border: result == null
                          ? null
                          : Border.all(color: _tpColor(tpLevel!), width: 1.5),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: result == null
                          ? null
                          : [
                              BoxShadow(
                                color: _tpColor(tpLevel!).withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Text(
                      result == null ? 'Pending' : 'TP${result['tp_level']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: result == null
                            ? const Color(0xFF777486)
                            : _tpColor(tpLevel!),
                        fontSize: result == null ? 12 : 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed:
                        _saving ? null : () => _showStudentResult(student),
                    style: FilledButton.styleFrom(
                      backgroundColor: result == null
                          ? Growkids.purpleFlo
                          : const Color(0xFF6D6880),
                    ),
                    child: Text(result == null ? 'Assign TP' : 'View Result'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _studentRoster() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9E8EF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Text('Students',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        ..._students.map((student) {
          final id = student['student_id'].toString();
          final selected = id == _selectedStudentId;
          final done = student['result'] != null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color:
                  selected ? const Color(0xFFEDE8FF) : const Color(0xFFF9F9FC),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => setState(() => _selectedStudentId = id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 17,
                        backgroundColor: done
                            ? const Color(0xFFDDF7ED)
                            : const Color(0xFFE5E0FF),
                        child: Icon(
                            done ? Icons.check_rounded : Icons.person_rounded,
                            size: 18,
                            color: done
                                ? const Color(0xFF0A7D5B)
                                : Growkids.purpleFlo)),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text((student['student_name'] ?? '-').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                              done
                                  ? 'TP${(student['result'] as Map)['tp_level']} assigned'
                                  : 'TP not assigned',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: done
                                      ? const Color(0xFF0A7D5B)
                                      : const Color(0xFF777486)))
                        ])),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  // ignore: unused_element
  Widget _mobileStudentSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedStudentId,
      decoration: InputDecoration(
          labelText: 'Student',
          prefixIcon:
              const Icon(Icons.person_rounded, color: Growkids.purpleFlo),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      items: _students
          .map((student) => DropdownMenuItem(
              value: student['student_id'].toString(),
              child: Text(
                  '${student['student_name']}${student['result'] == null ? '' : '  •  TP${(student['result'] as Map)['tp_level']}'}')))
          .toList(),
      onChanged: (value) => setState(() => _selectedStudentId = value),
    );
  }

  // ignore: unused_element
  Widget _assessmentPanel(Map<String, dynamic> student) {
    final id = student['student_id'].toString();
    final observations = _observations[id] ?? [];
    final selected = _selectedTp[id];
    final cycleCompleted = _cycle['status'] == 'COMPLETED';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9E8EF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text((student['student_name'] ?? '-').toString(),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800))),
          if (student['result'] != null)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFDDF7ED),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    'TP${(student['result'] as Map)['tp_level']} assigned',
                    style: const TextStyle(
                        color: Color(0xFF0A7D5B), fontWeight: FontWeight.w800)))
        ]),
        const SizedBox(height: 12),
        ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text('SP Evidence (${observations.length})',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          children: observations
              .map((obs) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FC),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SP ${obs['sp_code']}',
                            style: const TextStyle(
                                color: Growkids.purpleFlo,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text((obs['observation_text'] ?? '').toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text((obs['sp_statement'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF777486), fontSize: 12))
                      ])))
              .toList(),
        ),
        const SizedBox(height: 6),
        const Text('Choose Achievement Level',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final itemWidth = constraints.maxWidth >= 620
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth;
          return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tpOptions.map((tp) {
                final level = int.parse(tp['tp_level'].toString());
                final isSelected = selected == level;
                return SizedBox(
                    width: itemWidth,
                    child: Material(
                        color: isSelected
                            ? const Color(0xFFEDE8FF)
                            : const Color(0xFFF9F9FC),
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                            onTap: cycleCompleted
                                ? null
                                : () => setState(() => _selectedTp[id] = level),
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                        color: isSelected
                                            ? Growkids.purpleFlo
                                            : const Color(0xFFE9E8EF),
                                        width: isSelected ? 1.5 : 1)),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                          width: 38,
                                          height: 38,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Growkids.purpleFlo
                                                  : const Color(0xFFE5E0FF),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Text('TP$level',
                                              style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Growkids.purpleFlo,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w800))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(
                                              (tp['interpretation'] ?? '')
                                                  .toString(),
                                              style: const TextStyle(
                                                  fontSize: 13, height: 1.3)))
                                    ])))));
              }).toList());
        }),
        const SizedBox(height: 16),
        TextField(
            controller: _summaries[id],
            enabled: !cycleCompleted,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
                labelText: 'Teacher Summary (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 14),
        FilledButton.icon(
            onPressed:
                _saving || cycleCompleted ? null : () => _saveStudent(student),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(student['result'] == null
                ? 'Confirm TP for ${student['student_name']}'
                : 'Update TP for ${student['student_name']}'),
            style: FilledButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                padding: const EdgeInsets.symmetric(vertical: 16))),
      ]),
    );
  }
}
