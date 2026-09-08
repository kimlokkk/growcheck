import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_sk_finalize_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssSkObservationPage extends StatefulWidget {
  final String teacherId;
  final String classId;
  final Map<String, dynamic> standard;
  final String cycleAction;
  final String reportingPeriod;

  const KssSkObservationPage({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.standard,
    required this.reportingPeriod,
    this.cycleAction = 'OPEN',
  });

  @override
  State<KssSkObservationPage> createState() => _KssSkObservationPageState();
}

class _KssSkObservationPageState extends State<KssSkObservationPage> {
  Map<String, dynamic> _cycle = {};
  Map<String, dynamic> _sk = {};
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _standards = [];
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _saving = {};
  final Set<String> _failed = {};
  final Map<String, String> _savedText = {};
  final Map<String, DateTime> _savedAt = {};
  String? _selectedStudentId;
  bool _loading = true;
  bool _openingTpAssignment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openCycle();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _key(String studentId, String spId) => '$studentId:$spId';

  Future<void> _openCycle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_open_sk_cycle.php')),
        body: {
          'teacher_id': widget.teacherId,
          'class_id': widget.classId,
          'content_standard_id':
              widget.standard['content_standard_id'].toString(),
          'action': widget.cycleAction,
          'reporting_period': widget.reportingPeriod,
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to open assessment cycle.')
                .toString()
            : 'Unable to open assessment cycle.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final students = (data['students'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final standards = (data['learning_standards'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _savedText.clear();
      _savedAt.clear();
      _failed.clear();
      for (final observation in (data['observations'] as List? ?? [])) {
        final item = Map<String, dynamic>.from(observation as Map);
        _controllers[_key(
          item['student_id'].toString(),
          item['learning_standard_id'].toString(),
        )] = TextEditingController(
          text: (item['observation_text'] ?? '').toString(),
        );
        final key = _key(
          item['student_id'].toString(),
          item['learning_standard_id'].toString(),
        );
        _savedText[key] = (item['observation_text'] ?? '').toString().trim();
        final savedTime = DateTime.tryParse(
          (item['observed_at'] ?? '').toString(),
        );
        if (savedTime != null) _savedAt[key] = savedTime;
      }
      if (!mounted) return;
      setState(() {
        _cycle = Map<String, dynamic>.from(data['cycle'] as Map);
        _sk = Map<String, dynamic>.from(data['content_standard'] as Map);
        _students = students;
        _standards = standards;
        if (_selectedStudentId == null && students.isNotEmpty) {
          _selectedStudentId = students.first['student_id'].toString();
        }
      });
      if (_cycle['phase'] == 'TP_ASSIGNMENT') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openTpAssignment();
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

  TextEditingController _controller(String studentId, String spId) {
    return _controllers.putIfAbsent(
      _key(studentId, spId),
      TextEditingController.new,
    );
  }

  bool _isDirty(String key) {
    final current = _controllers[key]?.text.trim() ?? '';
    return current != (_savedText[key] ?? '');
  }

  bool get _hasUnsavedChanges => _controllers.keys.any(_isDirty);

  void _observationChanged(String key) {
    setState(() => _failed.remove(key));
  }

  Future<bool> _save(
    Map<String, dynamic> sp, {
    String? studentIdOverride,
    bool showSuccessMessage = true,
  }) async {
    final studentId = studentIdOverride ?? _selectedStudentId!;
    final spId = sp['learning_standard_id'].toString();
    final key = _key(studentId, spId);
    final text = _controller(studentId, spId).text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an observation first.')),
      );
      return false;
    }
    setState(() => _saving.add(key));
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_save_sp_observation.php')),
        body: {
          'teacher_id': widget.teacherId,
          'assessment_cycle_id': _cycle['assessment_cycle_id'].toString(),
          'student_id': studentId,
          'learning_standard_id': spId,
          'observation_text': text,
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to save observation.').toString()
            : 'Unable to save observation.');
      }
      if (!mounted) return false;
      setState(() {
        _savedText[key] = text;
        _savedAt[key] = DateTime.now();
        _failed.remove(key);
      });
      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SP ${sp['sp_code']} observation saved.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _failed.add(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Future<bool> _saveAll({bool showSummary = true}) async {
    final studentId = _selectedStudentId!;
    final dirty = _standards.where((sp) {
      final key = _key(
        studentId,
        sp['learning_standard_id'].toString(),
      );
      return _isDirty(key);
    }).toList();
    if (dirty.isEmpty) return true;
    var saved = 0;
    for (final sp in dirty) {
      if (await _save(
        sp,
        studentIdOverride: studentId,
        showSuccessMessage: false,
      )) {
        saved++;
      }
    }
    if (!mounted) return false;
    if (showSummary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$saved / ${dirty.length} observations saved.')),
      );
    }
    return saved == dirty.length && !_hasUnsavedChanges;
  }

  Future<void> _changeStudent(String? value) async {
    if (value == null || value == _selectedStudentId) return;
    if (_hasUnsavedChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save your changes before switching student.'),
        ),
      );
      return;
    }
    setState(() => _selectedStudentId = value);
  }

  int _studentCompletedCount(String studentId) {
    return _standards.where((sp) {
      final key = _key(studentId, sp['learning_standard_id'].toString());
      return (_savedText[key] ?? '').isNotEmpty;
    }).length;
  }

  bool get _allObservationsComplete =>
      _students.isNotEmpty &&
      _standards.isNotEmpty &&
      _students.every((student) =>
          _studentCompletedCount(student['student_id'].toString()) ==
          _standards.length);

  Future<void> _proceedToAssignTp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Proceed to Assign TP?'),
        content: const Text(
          'This will lock all SP observations for this assessment cycle. After proceeding, observations cannot be edited and you will continue with TP assignment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not Yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
            child: const Text('Lock & Proceed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_proceed_to_tp.php')),
        body: {
          'teacher_id': widget.teacherId,
          'assessment_cycle_id': _cycle['assessment_cycle_id'].toString(),
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to proceed to TP assignment.')
                .toString()
            : 'Unable to proceed to TP assignment.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    await _openTpAssignment();
  }

  Future<void> _openTpAssignment() async {
    if (_openingTpAssignment || !mounted) return;
    _openingTpAssignment = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KssSkFinalizePage(
          teacherId: widget.teacherId,
          assessmentCycleId: _cycle['assessment_cycle_id'].toString(),
        ),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ignore: unused_element
  Future<void> _saveAndNextStudent() async {
    final saved = await _saveAll(showSummary: false);
    if (!saved || !mounted) return;
    final currentIndex = _students.indexWhere(
      (student) => student['student_id'].toString() == _selectedStudentId,
    );
    Map<String, dynamic>? next;
    for (var offset = 1; offset <= _students.length; offset++) {
      final candidate = _students[(currentIndex + offset) % _students.length];
      final candidateId = candidate['student_id'].toString();
      if (_studentCompletedCount(candidateId) < _standards.length) {
        next = candidate;
        break;
      }
    }
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All students have complete SP observations.'),
        ),
      );
      return;
    }
    setState(() => _selectedStudentId = next!['student_id'].toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opened ${next['student_name']} next.')),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved observations'),
        content: const Text(
          'Some observations have not been saved successfully. Leave this page anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: const Text('SP Observations'),
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _loading ? null : _openCycle,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final padding = width >= 1100
                ? 36.0
                : width >= 600
                    ? 24.0
                    : 16.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                padding,
                width >= 600 ? 24 : 16,
                padding,
                32,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: _body(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(
          child: CircularProgressIndicator(color: Growkids.purpleFlo),
        ),
      );
    }
    if (_error != null) {
      return _state('Unable to open assessment', _error!, _openCycle);
    }
    if (_students.isEmpty) {
      return _state(
        'No students enrolled',
        'Add students to this class before recording observations.',
        null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Growkids.purpleFlo, Growkids.purpleBright],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SK ${_sk['sk_code'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                (_sk['sk_statement'] ?? '').toString(),
                style: const TextStyle(color: Color(0xFFEDE8FF)),
              ),
              const SizedBox(height: 10),
              Text(
                '${_cycle['reporting_period'] == 'SEM2' ? 'Semester 2' : 'Semester 1'}${_cycle['cycle_type'] == 'REVISION' ? ' • Revision' : ''} • Step 1 of 2 • SP Observations',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _studentRoster(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _selectedStudentHeading()),
            _studentProgressBadge(),
          ],
        ),
        const SizedBox(height: 12),
        ..._standards.map(_observationCard),
        if (_allObservationsComplete) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDDF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const message = Text(
                  'All observations are complete. Review them or proceed when you are ready.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                );
                final button = FilledButton(
                  onPressed: _proceedToAssignTp,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF087A55),
                  ),
                  child: const Text('Proceed to Assign TP'),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF087A55)),
                        SizedBox(width: 10),
                        Expanded(child: message),
                      ]),
                      const SizedBox(height: 12),
                      button,
                    ],
                  );
                }
                return Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF087A55)),
                  const SizedBox(width: 10),
                  const Expanded(child: message),
                  const SizedBox(width: 10),
                  button,
                ]);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _studentProgressBadge() {
    final completed = _studentCompletedCount(_selectedStudentId!);
    final complete = completed == _standards.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: complete ? const Color(0xFFDDF7ED) : const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$completed/${_standards.length} completed',
        style: TextStyle(
          color: complete ? const Color(0xFF087A55) : Growkids.purpleFlo,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _studentRoster() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Student Progress',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select a student to record or continue observations.',
            style: TextStyle(color: Color(0xFF777486)),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 800
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 520
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _students.map((student) {
                  final id = student['student_id'].toString();
                  final completed = _studentCompletedCount(id);
                  final selected = id == _selectedStudentId;
                  final complete = completed == _standards.length;
                  return SizedBox(
                    width: cardWidth,
                    child: Material(
                      color: selected
                          ? const Color(0xFFEDE8FF)
                          : const Color(0xFFF9F9FC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _saving.isNotEmpty
                            ? null
                            : () => _changeStudent(id),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? Growkids.purpleFlo
                                  : const Color(0xFFE9E8EF),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: complete
                                    ? const Color(0xFFDDF7ED)
                                    : const Color(0xFFEDE8FF),
                                child: Icon(
                                  complete
                                      ? Icons.check_rounded
                                      : Icons.person_rounded,
                                  color: complete
                                      ? const Color(0xFF0A7D5B)
                                      : Growkids.purpleFlo,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (student['student_name'] ?? '-')
                                          .toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$completed / ${_standards.length} SP',
                                      style: TextStyle(
                                        color: complete
                                            ? const Color(0xFF0A7D5B)
                                            : const Color(0xFF777486),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _selectedStudentHeading() {
    final student = _students.firstWhere(
      (item) => item['student_id'].toString() == _selectedStudentId,
    );
    return Text(
      (student['student_name'] ?? '-').toString(),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }

  // ignore: unused_element
  Widget _progressCard() {
    final studentId = _selectedStudentId!;
    final completed = _standards.where((sp) {
      final key = _key(studentId, sp['learning_standard_id'].toString());
      return (_savedText[key] ?? '').isNotEmpty;
    }).length;
    final allSaved = !_hasUnsavedChanges && _saving.isEmpty && _failed.isEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, color: Growkids.purpleFlo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed / ${_standards.length} SP observations recorded',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  _saving.isNotEmpty
                      ? 'Saving changes...'
                      : _failed.isNotEmpty
                          ? 'Some changes failed to save.'
                          : allSaved
                              ? 'All changes saved.'
                              : 'Unsaved changes.',
                  style: const TextStyle(color: Color(0xFF6D6880)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _observationCard(Map<String, dynamic> sp) {
    final studentId = _selectedStudentId!;
    final spId = sp['learning_standard_id'].toString();
    final key = _key(studentId, spId);
    final observation = _savedText[key] ?? '';
    final recorded = observation.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E8EF)),
      ),
      child: InkWell(
        onTap: _saving.contains(key) ? null : () => _showObservationDialog(sp),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: recorded
                      ? const Color(0xFFDDF7ED)
                      : const Color(0xFFF0EFF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  recorded ? Icons.check_rounded : Icons.edit_note_rounded,
                  color: recorded
                      ? const Color(0xFF087A55)
                      : const Color(0xFF777486),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SP ${sp['sp_code'] ?? ''}',
                      style: const TextStyle(
                        color: Growkids.purpleFlo,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (sp['sp_statement'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recorded) ...[
                      const SizedBox(height: 5),
                      Text(
                        observation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF777486),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                recorded ? 'Edit' : 'Record',
                style: const TextStyle(
                  color: Growkids.purpleFlo,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Growkids.purpleFlo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showObservationDialog(Map<String, dynamic> sp) async {
    final studentId = _selectedStudentId!;
    final spId = sp['learning_standard_id'].toString();
    final key = _key(studentId, spId);
    final editor = TextEditingController(
      text: _controller(studentId, spId).text,
    );
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('SP ${sp['sp_code'] ?? ''}'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((sp['sp_statement'] ?? '').toString()),
              const SizedBox(height: 16),
              TextField(
                controller: editor,
                autofocus: true,
                minLines: 4,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: 'Teacher Observation',
                  hintText: 'Record qualitative evidence...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (editor.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Observation'),
            style: FilledButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
            ),
          ),
        ],
      ),
    );
    if (shouldSave == true) {
      _controller(studentId, spId).text = editor.text.trim();
      _observationChanged(key);
      await _save(sp, studentIdOverride: studentId);
    }
    editor.dispose();
  }

  // ignore: unused_element
  Widget _saveStatus(String key, bool saving) {
    if (saving) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Saving...'),
        ],
      );
    }
    if (_failed.contains(key)) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
          SizedBox(width: 6),
          Text(
            'Failed to save • Use Save All to retry',
            style: TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (_isDirty(key)) {
      return const Align(
        alignment: Alignment.centerRight,
        child: Text('Unsaved changes', style: TextStyle(color: Colors.orange)),
      );
    }
    if ((_savedText[key] ?? '').isNotEmpty) {
      final time = _savedAt[key];
      final label = time == null
          ? 'Saved'
          : 'Saved at ${TimeOfDay.fromDateTime(time).format(context)}';
      return Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF0AAE7A), size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF0A7D5B))),
          ],
        ),
      );
    }
    return const Align(
      alignment: Alignment.centerRight,
      child: Text('Not recorded', style: TextStyle(color: Color(0xFF9996A3))),
    );
  }

  Widget _state(String title, String message, VoidCallback? action) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Growkids.purpleFlo, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: action, child: const Text('Try Again')),
          ],
        ],
      ),
    );
  }
}
