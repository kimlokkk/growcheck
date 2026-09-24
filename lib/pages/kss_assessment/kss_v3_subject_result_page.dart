import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_subject_report_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3SubjectResultPage extends StatefulWidget {
  final String teacherId, assignmentId, studentId;
  const KssV3SubjectResultPage(
      {super.key,
      required this.teacherId,
      required this.assignmentId,
      required this.studentId});
  @override
  State<KssV3SubjectResultPage> createState() => _KssV3SubjectResultPageState();
}

class _KssV3SubjectResultPageState extends State<KssV3SubjectResultPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _softPurple = Color(0xFFEDEDF7);
  static const _success = Color(0xFF2E7D32);
  final _note = TextEditingController();
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true, _saving = false;
  String? _error;
  int? _recommendedTp, _finalTp;
  List<int> _tieCandidates = [];
  int _complete = 0, _total = 0;
  bool _confirmed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Map<String, String> get _body => {
        'teacher_id': widget.teacherId,
        'assignment_id': widget.assignmentId,
        'student_id': widget.studentId
      };
  Future<Map> _request(Map<String, String> body) async {
    final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_v3_subject_result.php')),
        body: body);
    final decoded = json.decode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['success'] != true) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Unable to load overall result.').toString()
          : 'Unable to load overall result.');
    }
    return decoded;
  }

  Future<void> _load() async {
    try {
      final decoded = await _request({..._body, 'action': 'load'});
      final data = decoded['data'] as Map? ?? {};
      final saved = data['saved_result'] as Map?;
      if (!mounted) return;
      setState(() {
        _groups = (data['groups'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _complete = int.tryParse(data['complete_groups'].toString()) ?? 0;
        _total = int.tryParse(data['total_groups'].toString()) ?? 0;
        _recommendedTp = int.tryParse(data['recommended_tp']?.toString() ?? '');
        _tieCandidates = (data['tie_candidates'] as List? ?? [])
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .where((level) => level >= 1 && level <= 6)
            .toSet()
            .toList()
          ..sort();
        final allowedLevels = _tieCandidates.length > 1
            ? _tieCandidates
            : List.generate(6, (index) => index + 1);
        final savedTp = int.tryParse(saved?['final_tp']?.toString() ?? '');
        _finalTp = allowedLevels.contains(savedTp)
            ? savedTp
            : (allowedLevels.contains(_recommendedTp)
                ? _recommendedTp
                : allowedLevels.first);
        _note.text = saved?['professional_judgement_note']?.toString() ?? '';
        _confirmed = saved?['status']?.toString() == 'COMPLETED';
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      await _request({
        ..._body,
        'action': 'confirm',
        'final_tp': _finalTp.toString(),
        'professional_judgement_note': _note.text.trim()
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Overall TP confirmed.')));
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startRevision() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start reassessment?'),
        content: const Text(
            'The current result will remain in History. A new assessment cycle will be created.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start reassessment')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final response = await http.post(
          Uri.parse(ApiConfig.flutter('kss_v3_start_revision.php')),
          body: _body);
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to start reassessment.').toString()
            : 'Unable to start reassessment.');
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
            title: const Text('Overall result'),
            backgroundColor: Growkids.purpleFlo,
            foregroundColor: Colors.white),
        bottomNavigationBar: _loading ||
                _error != null ||
                _confirmed ||
                _complete != _total
            ? null
            : Material(
                color: Colors.white,
                elevation: 8,
                child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: FilledButton(
                                onPressed: _saving ? null : _confirm,
                                style: FilledButton.styleFrom(
                                    backgroundColor: Growkids.purpleFlo,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48)),
                                child: const Text('Confirm overall TP')))))),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : LayoutBuilder(builder: (context, constraints) {
                    final horizontal = constraints.maxWidth > 860
                        ? (constraints.maxWidth - 760) / 2
                        : 20.0;
                    final progress = _total == 0 ? 0.0 : _complete / _total;
                    return ListView(
                        padding:
                            EdgeInsets.fromLTRB(horizontal, 22, horizontal, 96),
                        children: [
                          const Text('Overall subject result',
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text('$_complete of $_total sections confirmed',
                              style:
                                  const TextStyle(color: _muted, fontSize: 13)),
                          const SizedBox(height: 10),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 7,
                                  backgroundColor: _softPurple,
                                  color: Growkids.purpleFlo)),
                          const SizedBox(height: 18),
                          ..._groups.map((group) => Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: _border),
                                  borderRadius: BorderRadius.circular(13)),
                              child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 5),
                                  title: Text(
                                      '${group['code']} ${group['title']}'),
                                  trailing: group['tp_level'] == null
                                      ? const Text('Not completed',
                                          style: TextStyle(
                                              color: _muted, fontSize: 11))
                                      : KssV3TpStyle.badge(
                                          group['tp_level'])))),
                          const SizedBox(height: 16),
                          if (_complete != _total)
                            const Text(
                                'Confirm the TP for every section first to get the overall result.',
                                style: TextStyle(color: _muted))
                          else ...[
                            _recommendationCard(),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                                initialValue: _finalTp,
                                decoration: const InputDecoration(
                                    labelText: 'Overall TP'),
                                items: (_tieCandidates.length > 1
                                        ? _tieCandidates.toSet().toList()
                                        : List.generate(
                                            6, (index) => index + 1))
                                    .map((level) => DropdownMenuItem(
                                        value: level,
                                        child: KssV3TpStyle.badge(level)))
                                    .toList(),
                                onChanged: _saving || _confirmed
                                    ? null
                                    : (level) =>
                                        setState(() => _finalTp = level)),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _note,
                                maxLines: 3,
                                readOnly: _confirmed,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Reason for teacher choice (required if different from recommendation)')),
                            if (_confirmed) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KssV3SubjectReportPage(
                                      teacherId: widget.teacherId,
                                      assignmentId: widget.assignmentId,
                                      studentId: widget.studentId,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.description_outlined),
                                label: const Text('View subject report'),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _startRevision,
                                icon: const Icon(Icons.restart_alt),
                                label: const Text('Start reassessment'),
                              ),
                            ],
                          ],
                        ]);
                  }),
      );

  Widget _recommendationCard() => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _confirmed ? const Color(0xFFE6F4E8) : _softPurple,
          borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        Icon(_confirmed ? Icons.verified_outlined : Icons.auto_awesome_outlined,
            color: _confirmed ? _success : Growkids.purpleFlo),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                _confirmed
                    ? 'Overall result confirmed: TP $_finalTp'
                    : _recommendedTp == null
                        ? 'There is a tie. Select the final result.'
                        : 'System recommendation: TP $_recommendedTp',
                style:
                    const TextStyle(color: _ink, fontWeight: FontWeight.w800))),
      ]));
}
