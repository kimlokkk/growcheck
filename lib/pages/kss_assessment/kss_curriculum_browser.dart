import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_sk_observation_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_sk_finalize_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssCurriculumBrowser extends StatefulWidget {
  final String teacherId;
  final String classId;

  const KssCurriculumBrowser({
    super.key,
    required this.teacherId,
    required this.classId,
  });

  @override
  State<KssCurriculumBrowser> createState() => _KssCurriculumBrowserState();
}

class _KssCurriculumBrowserState extends State<KssCurriculumBrowser> {
  List<Map<String, dynamic>> _domains = [];
  int _selectedDomainIndex = 0;
  bool _loading = true;
  bool _startingSemester2 = false;
  bool _startingRevision = false;
  String _reportingPeriod = 'SEM1';
  bool _canStartSemester2 = false;
  List<String> _availablePeriods = const ['SEM1'];
  bool _hasLoaded = false;
  Map<String, dynamic> _currentBatch = {};
  bool _publishingBatch = false;
  String? _error;

  // ignore: unused_element
  List<Map<String, dynamic>> get _allStandards => _domains
      .expand((domain) => (domain['content_standards'] as List? ?? []))
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  Future<void> _openStandard(Map<String, dynamic> standard) async {
    final progress = Map<String, dynamic>.from(
      standard['progress'] as Map? ?? const {},
    );
    final status = (progress['assessment_status'] ?? '').toString();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => status == 'ASSIGNING_TP' ||
                status == 'READY_TO_COMPLETE' ||
                status == 'COMPLETED'
            ? KssSkFinalizePage(
                teacherId: widget.teacherId,
                assessmentCycleId: progress['assessment_cycle_id'].toString(),
              )
            : KssSkObservationPage(
                teacherId: widget.teacherId,
                classId: widget.classId,
                standard: standard,
                reportingPeriod: _reportingPeriod,
                cycleAction: status == 'NOT_STARTED' ? 'START' : 'OPEN',
              ),
      ),
    );
    await _load();
  }

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
        Uri.parse(ApiConfig.flutter('kss_class_curriculum.php')),
        body: {
          'teacher_id': widget.teacherId,
          'class_id': widget.classId,
          if (_hasLoaded) 'reporting_period': _reportingPeriod,
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load curriculum.').toString()
            : 'Unable to load curriculum.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      if (!mounted) return;
      setState(() {
        _domains = (data['domains'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _reportingPeriod = (data['active_reporting_period'] ?? 'SEM1').toString();
        _canStartSemester2 = data['can_start_semester_2'] == true;
        _availablePeriods = (data['available_reporting_periods'] as List? ?? const ['SEM1'])
            .map((item) => item.toString())
            .toList();
        _hasLoaded = true;
        _currentBatch = Map<String, dynamic>.from(
          data['current_batch'] as Map? ?? const {},
        );
        if (_selectedDomainIndex >= _domains.length) {
          _selectedDomainIndex = 0;
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

  Future<void> _startSemester2() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start Semester 2?'),
        content: const Text(
          'Semester 2 assessment will begin for every Standard Kandungan. Semester 1 results will remain unchanged and available in Progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
            child: const Text('Start Semester 2'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _startingSemester2 = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_start_semester_2.php')),
        body: {'teacher_id': widget.teacherId, 'class_id': widget.classId},
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to start Semester 2.').toString()
            : 'Unable to start Semester 2.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semester 2 assessment started.')),
      );
      setState(() {
        _selectedDomainIndex = 0;
        _reportingPeriod = 'SEM2';
      });
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingSemester2 = false);
    }
  }

  Future<void> _startRevision() async {
    final semester = _reportingPeriod == 'SEM2' ? 'Semester 2' : 'Semester 1';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start Revision?'),
        content: Text(
          'This starts a new revision for every Standard Kandungan in $semester. The completed assessment remains available in Progress history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
            child: const Text('Start Revision'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _startingRevision = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_start_revision.php')),
        body: {
          'teacher_id': widget.teacherId,
          'class_id': widget.classId,
          'reporting_period': _reportingPeriod,
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to start revision.').toString()
            : 'Unable to start revision.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$semester revision started.')),
      );
      setState(() => _selectedDomainIndex = 0);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _startingRevision = false);
    }
  }

  Future<void> _publishBatch() async {
    final batchId = (_currentBatch['assessment_batch_id'] ?? '').toString();
    if (batchId.isEmpty) return;
    final isRevision = _currentBatch['assessment_type'] == 'REVISION';
    final revisionNo = _currentBatch['revision_no'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isRevision ? 'Publish Revision $revisionNo?' : 'Publish Assessment?'),
        content: const Text(
          'All results will become the new official progress at the same time. The previous published assessment will remain in History.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
            child: const Text('Complete & Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishingBatch = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_publish_assessment_batch.php')),
        body: {'teacher_id': widget.teacherId, 'class_id': widget.classId, 'assessment_batch_id': batchId},
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? decoded['message'] : 'Unable to publish assessment.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment published. Progress has been updated.')),
      );
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _publishingBatch = false);
    }
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
    if (_error != null) {
      return _stateCard(
        Icons.error_outline_rounded,
        'Unable to load curriculum',
        _error!,
        _load,
      );
    }
    if (_domains.isEmpty) {
      return _stateCard(
        Icons.menu_book_outlined,
        'No curriculum content',
        'No active DSKP content is available for this class.',
        _load,
      );
    }

    final allStandards = _allStandards;
    final completedCount = allStandards.where((standard) {
      final progress = standard['progress'] as Map?;
      return progress?['assessment_status'] == 'COMPLETED';
    }).length;
    final allCompleted =
        allStandards.isNotEmpty && completedCount == allStandards.length;
    final batchInProgress = _currentBatch['status'] == 'IN_PROGRESS';
    final selectedDomain = _domains[_selectedDomainIndex];
    final selectedStandards =
        (selectedDomain['content_standards'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${_reportingPeriod == 'SEM2' ? 'Semester 2' : 'Semester 1'} ${_currentBatch['assessment_type'] == 'REVISION' ? 'Revision ${_currentBatch['revision_no']}' : 'Assessment'}',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('Choose a domain to view its Standard Kandungan.',
                    style: TextStyle(color: Color(0xFF777486))),
              ],
            );
            final progress = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFEDE8FF),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$completedCount / ${allStandards.length} completed',
                  style: const TextStyle(
                      color: Growkids.purpleFlo,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 10), progress],
              );
            }
            return Row(children: [Expanded(child: heading), progress]);
          },
        ),
        if (_availablePeriods.length > 1) ...[
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'SEM1', label: Text('Semester 1')),
              ButtonSegment(value: 'SEM2', label: Text('Semester 2')),
            ],
            selected: {_reportingPeriod},
            onSelectionChanged: (selection) async {
              final period = selection.first;
              if (period == _reportingPeriod) return;
              setState(() => _reportingPeriod = period);
              await _load();
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : Growkids.purpleFlo,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Growkids.purpleFlo
                    : Colors.white,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _domainSelector(),
        const SizedBox(height: 20),
        Text(
          '${selectedDomain['domain_code']}  ${selectedDomain['domain_title']}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text('${selectedStandards.length} Standard Kandungan',
            style: const TextStyle(color: Color(0xFF777486))),
        const SizedBox(height: 12),
        ...selectedStandards.map(_standardTile),
        if (allCompleted) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E1E8)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final message = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batchInProgress ? 'Ready to publish' : 'Assessment completed',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                        batchInProgress
                            ? 'All SK are complete. Publish them together when you are ready to update official Progress.'
                            : _reportingPeriod == 'SEM1'
                            ? 'The results are locked. You may revise Semester 1 or continue to Semester 2.'
                            : 'The results are locked. Start a revision if another assessment round is needed.',
                        style: const TextStyle(color: Color(0xFF777486))),
                  ],
                );
                final revisionButton = OutlinedButton.icon(
                  onPressed: _startingRevision || _startingSemester2
                      ? null
                      : _startRevision,
                  icon: _startingRevision
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.replay_rounded),
                  label: const Text('Start Revision'),
                  style: OutlinedButton.styleFrom(foregroundColor: Growkids.purpleFlo),
                );
                final semesterButton = OutlinedButton.icon(
                  onPressed: _startingSemester2 || _startingRevision
                      ? null
                      : _startSemester2,
                  icon: _startingSemester2
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Start Semester 2'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Growkids.purpleFlo),
                );
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      message,
                      const SizedBox(height: 12),
                      if (batchInProgress)
                        FilledButton.icon(
                          onPressed: _publishingBatch ? null : _publishBatch,
                          icon: const Icon(Icons.publish_rounded),
                          label: const Text('Complete & Publish'),
                          style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
                        )
                      else
                        revisionButton,
                      if (!batchInProgress && _reportingPeriod == 'SEM1' && _canStartSemester2) ...[
                        const SizedBox(height: 8),
                        semesterButton,
                      ],
                    ],
                  );
                }
                return Row(children: [
                  Expanded(child: message),
                  const SizedBox(width: 16),
                  if (batchInProgress)
                    FilledButton.icon(
                      onPressed: _publishingBatch ? null : _publishBatch,
                      icon: const Icon(Icons.publish_rounded),
                      label: const Text('Complete & Publish'),
                      style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
                    )
                  else
                    revisionButton,
                  if (!batchInProgress && _reportingPeriod == 'SEM1' && _canStartSemester2) ...[
                    const SizedBox(width: 8),
                    semesterButton,
                  ],
                ]);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _domainSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final items = List.generate(_domains.length, (index) {
          final domain = _domains[index];
          final selected = index == _selectedDomainIndex;
          final standards = (domain['content_standards'] as List? ?? []);
          final pending = standards.where((standard) {
            final progress = (standard as Map)['progress'] as Map?;
            final status =
                (progress?['assessment_status'] ?? 'NOT_STARTED').toString();
            return status != 'NOT_STARTED' && status != 'COMPLETED';
          }).length;
          return Padding(
            padding: const EdgeInsets.all(4),
            child: InkWell(
              onTap: () => setState(() => _selectedDomainIndex = index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? Growkids.purpleFlo : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected
                          ? Growkids.purpleFlo
                          : const Color(0xFFE2E1E8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text((domain['domain_code'] ?? '').toString(),
                        style: TextStyle(
                            color: selected ? Colors.white : Growkids.purpleFlo,
                            fontWeight: FontWeight.w900)),
                    if (pending > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFD97706),
                              shape: BoxShape.circle)),
                    ],
                  ],
                ),
              ),
            ),
          );
        });
        final columns = constraints.maxWidth < 600 ? 3 : 5;
        final itemWidth = constraints.maxWidth / columns;
        return Wrap(
          children: items
              .map((item) => SizedBox(width: itemWidth, child: item))
              .toList(),
        );
      },
    );
  }

  Widget _standardTile(Map<String, dynamic> standard) {
    final learningStandards = (standard['learning_standards'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final progress = Map<String, dynamic>.from(
      standard['progress'] as Map? ?? const {},
    );
    final status = (progress['assessment_status'] ?? 'NOT_STARTED').toString();
    final completed = int.tryParse(
          (progress['completed_students'] ?? 0).toString(),
        ) ??
        0;
    final finalized = int.tryParse(
          (progress['finalized_students'] ?? 0).toString(),
        ) ??
        0;
    final total =
        int.tryParse((progress['total_students'] ?? 0).toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E8EF)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SK ${standard['sk_code'] ?? ''}',
                          style: const TextStyle(
                            color: Growkids.purpleFlo,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 9),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text((standard['sk_statement'] ?? '-').toString()),
                    const SizedBox(height: 7),
                    Text(
                      _progressText(
                        status,
                        completed,
                        finalized,
                        total,
                        learningStandards.length,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF777486),
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
                final action = FilledButton(
                  onPressed: () => _openStandard(standard),
                  style: FilledButton.styleFrom(
                    backgroundColor: Growkids.purpleFlo,
                  ),
                  child: Text(_actionLabel(status)),
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [details, const SizedBox(height: 12), action],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    action,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _progressText(
    String status,
    int completed,
    int finalized,
    int total,
    int spCount,
  ) {
    if (status == 'NOT_STARTED') return '$spCount Standard Pembelajaran';
    if (status == 'COMPLETED') return '$total student results completed';
    if (status == 'ASSIGNING_TP') {
      return '$finalized of $total student TP results assigned';
    }
    if (status == 'READY_TO_COMPLETE') {
      return 'All $total student TP results ready for final review';
    }
    return '$completed of $total students completed observations • $spCount SP';
  }

  String _actionLabel(String status) {
    switch (status) {
      case 'READY_TO_FINALIZE':
        return 'Review & Proceed to TP';
      case 'ASSIGNING_TP':
        return 'Continue Assigning TP';
      case 'READY_TO_COMPLETE':
        return 'Review & Complete';
      case 'COMPLETED':
        return 'View Result';
      case 'IN_PROGRESS':
        return 'Continue Observations';
      default:
        return 'Start';
    }
  }

  // ignore: unused_element
  Widget _actionCard(
    Map<String, dynamic> standard, {
    required bool readyToFinalize,
  }) {
    final progress = Map<String, dynamic>.from(standard['progress'] as Map);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Growkids.purpleFlo),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEDE8FF),
            child: Icon(Icons.play_arrow_rounded, color: Growkids.purpleFlo),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  readyToFinalize
                      ? 'Observations Complete'
                      : 'Continue Assessment',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'SK ${standard['sk_code']} • ${progress['completed_students']} / ${progress['total_students']} students complete',
                  style: const TextStyle(color: Color(0xFF777486)),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _openStandard(standard),
            style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo),
            child: Text(
              readyToFinalize ? 'Assign SK TP' : 'Continue',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final ready =
        status == 'READY_TO_FINALIZE' || status == 'READY_TO_COMPLETE';
    final completed = status == 'COMPLETED';
    final active = status == 'IN_PROGRESS' || status == 'ASSIGNING_TP';
    final color = ready || completed
        ? const Color(0xFF0A7D5B)
        : active
            ? const Color(0xFFD97706)
            : const Color(0xFF777486);
    final label = status == 'READY_TO_FINALIZE'
        ? 'READY FOR TP'
        : status == 'READY_TO_COMPLETE'
            ? 'READY TO COMPLETE'
            : status == 'ASSIGNING_TP'
                ? 'ASSIGNING TP'
                : status == 'IN_PROGRESS'
                    ? 'RECORDING SP'
                    : status == 'NOT_STARTED'
                        ? 'NOT STARTED'
                        : 'COMPLETED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _stateCard(
    IconData icon,
    String title,
    String message,
    VoidCallback action,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E8EF)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Growkids.purpleFlo),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: action, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
