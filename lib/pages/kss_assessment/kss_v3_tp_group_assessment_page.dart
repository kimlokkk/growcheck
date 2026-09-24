import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:http/http.dart' as http;

class KssV3TpGroupAssessmentPage extends StatefulWidget {
  final String teacherId;
  final String assignmentId;
  final String studentId;
  final Map<String, dynamic> tpGroup;

  const KssV3TpGroupAssessmentPage(
      {super.key,
      required this.teacherId,
      required this.assignmentId,
      required this.studentId,
      required this.tpGroup});

  @override
  State<KssV3TpGroupAssessmentPage> createState() =>
      _KssV3TpGroupAssessmentPageState();
}

class _KssV3TpGroupAssessmentPageState
    extends State<KssV3TpGroupAssessmentPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  static const _success = Color(0xFF2E7D32);
  final Map<String, TextEditingController> _observations = {};
  final _summary = TextEditingController();
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saveStatus;
  Timer? _autosaveTimer;
  int _tpLevel = 1;
  bool _finalized = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    for (final controller in _observations.values) {
      controller.dispose();
    }
    _summary.dispose();
    super.dispose();
  }

  Map<String, String> get _baseBody => {
        'teacher_id': widget.teacherId,
        'assignment_id': widget.assignmentId,
        'student_id': widget.studentId,
        'tp_group_id': widget.tpGroup['id'].toString(),
      };

  Future<Map> _request(Map<String, String> body) async {
    final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_v3_tp_group_assessment.php')),
        body: body);
    final decoded = json.decode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['success'] != true) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Unable to save assessment.').toString()
          : 'Unable to save assessment.');
    }
    return decoded;
  }

  Future<void> _load() async {
    try {
      final decoded = await _request({..._baseBody, 'action': 'load'});
      final data = decoded['data'] as Map? ?? {};
      final groups = (data['observation_groups'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      for (final group in groups) {
        final id = group['id'].toString();
        _observations.putIfAbsent(
            id,
            () => TextEditingController(
                text: group['observation_text']?.toString() ?? ''));
      }
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _tpLevel = int.tryParse(data['tp_level']?.toString() ?? '') ?? 1;
        _finalized = data['tp_level'] != null;
        _summary.text = data['teacher_summary']?.toString() ?? '';
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

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    setState(() => _saveStatus = 'Saving...');
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      _saveObservations(showMessage: false);
    });
  }

  Future<void> _saveObservations(
      {bool showMessage = true, bool rethrowOnError = false}) async {
    setState(() => _saving = true);
    try {
      final items = _groups
          .map((group) => {
                'observation_group_id': group['id'],
                'observation_text':
                    _observations[group['id'].toString()]?.text.trim() ?? '',
              })
          .toList();
      await _request({
        ..._baseBody,
        'action': 'save_observations',
        'observations_json': json.encode(items)
      });
      if (mounted && showMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Observations saved.')));
      }
      if (mounted) setState(() => _saveStatus = 'Saved ✓');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
      if (mounted) setState(() => _saveStatus = 'Save failed');
      if (rethrowOnError) rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finalize() async {
    try {
      await _saveObservations(showMessage: false, rethrowOnError: true);
      if (!mounted) return;
      setState(() => _saving = true);
      await _request({
        ..._baseBody,
        'action': 'finalize',
        'tp_level': _tpLevel.toString(),
        'teacher_summary': _summary.text.trim()
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TP result confirmed.')));
        Navigator.pop(context);
      }
    } catch (_) {
      // Error has already been shown by the request helper.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          title: const Text('Section assessment',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          centerTitle: false,
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBar:
            _loading || _error != null || _finalized ? null : _actionBar(),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Growkids.purpleFlo))
            : _error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center)))
                : LayoutBuilder(builder: (context, constraints) {
                    final horizontal = constraints.maxWidth > 1184
                        ? (constraints.maxWidth - 1120) / 2
                        : constraints.maxWidth < 600
                            ? 20.0
                            : 32.0;
                    final observations = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Observations',
                            style: TextStyle(
                                color: _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                            _finalized
                                ? 'Recorded evidence for this learning area.'
                                : 'Review the learning standards and record what you observe.',
                            style: const TextStyle(
                                color: _muted, fontSize: 12, height: 1.6)),
                        const SizedBox(height: 18),
                        if (_groups.isEmpty)
                          _card(
                              child: const Text(
                                  'No observation sections available.',
                                  style:
                                      TextStyle(color: _muted, height: 1.6))),
                        ..._groups.map(_observationCard),
                      ],
                    );
                    return ListView(
                      padding:
                          EdgeInsets.fromLTRB(horizontal, 28, horizontal, 32),
                      children: [
                        _sectionHeader(),
                        const SizedBox(height: 24),
                        if (_finalized) ...[
                          _finalizedBanner(),
                          const SizedBox(height: 24),
                        ],
                        if (constraints.maxWidth >= 1050)
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: observations),
                                const SizedBox(width: 24),
                                SizedBox(width: 320, child: _resultCard()),
                              ])
                        else ...[
                          observations,
                          const SizedBox(height: 12),
                          _resultCard(),
                        ],
                      ],
                    );
                  }),
      );

  Widget _sectionHeader() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Growkids.purpleFlo,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OBSERVATION & MASTERY',
              style: TextStyle(
                  color: Colors.white, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Text('${widget.tpGroup['code']} ${widget.tpGroup['title']}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.4)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _headerTag(Icons.menu_book_outlined,
                  '${_groups.length} observation sections'),
              _headerTag(
                  _finalized ? Icons.lock_outline_rounded : Icons.edit_outlined,
                  _finalized ? 'Finalized' : 'In progress'),
              if (_finalized) KssV3TpStyle.badge(_tpLevel),
            ],
          ),
        ]),
      );

  Widget _headerTag(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Flexible(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, height: 1.4))),
        ]),
      );

  Widget _observationCard(Map<String, dynamic> group) {
    final criteria = (group['criteria'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final controller = _observations[group['id'].toString()]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: GrowkidsPastel.purple3,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${group['code']}',
                  style: const TextStyle(
                      color: Growkids.purpleFlo,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Text('${group['title']}',
              style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.6)),
          if (criteria.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('LEARNING STANDARDS',
                style:
                    TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            ...criteria.map((criterion) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('${criterion['code']}  ${criterion['title']}',
                      style: const TextStyle(
                          color: _muted, fontSize: 13, height: 1.7)),
                )),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: _border),
          ),
          const Text('Teacher observation',
              style: TextStyle(
                  color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_finalized)
            _recordedText(controller.text, 'No observation recorded.')
          else
            TextField(
              controller: controller,
              onChanged: (_) => _scheduleAutosave(),
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(color: _ink, fontSize: 13, height: 1.6),
              decoration:
                  _inputDecoration('Describe what the student demonstrated...'),
            ),
        ],
      )),
    );
  }

  Widget _resultCard() => _card(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.fact_check_outlined,
                color: Growkids.purpleFlo, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_finalized ? 'Confirmed result' : 'Section result',
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          Text(
              _finalized
                  ? 'The mastery level and summary saved for this section.'
                  : 'Choose the mastery level that reflects the student’s performance.',
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.6)),
          const SizedBox(height: 24),
          const Text('Mastery level',
              style: TextStyle(
                  color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_finalized)
            Align(
                alignment: Alignment.centerLeft,
                child: KssV3TpStyle.badge(_tpLevel))
          else
            DropdownButtonFormField<int>(
              initialValue: _tpLevel,
              isExpanded: true,
              decoration: _inputDecoration(null),
              items: List.generate(
                  6,
                  (index) => DropdownMenuItem(
                        value: index + 1,
                        child: KssV3TpStyle.badge(index + 1),
                      )),
              onChanged: _saving
                  ? null
                  : (level) => setState(() => _tpLevel = level ?? 1),
            ),
          const SizedBox(height: 24),
          Text(_finalized ? 'Teacher summary' : 'Teacher summary · Optional',
              style: const TextStyle(
                  color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_finalized)
            _recordedText(_summary.text, 'No summary recorded.')
          else ...[
            TextField(
              controller: _summary,
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(color: _ink, fontSize: 13, height: 1.6),
              decoration: _inputDecoration('Add context to your assessment...'),
            ),
            const SizedBox(height: 16),
            const Text('Confirm TP saves the result and locks this section.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.6)),
          ],
        ],
      ));

  Widget _recordedText(String text, String emptyLabel) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _canvas,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SelectableText(text.trim().isEmpty ? emptyLabel : text,
            style: TextStyle(
                color: text.trim().isEmpty ? _muted : _ink,
                fontSize: 13,
                height: 1.7)),
      );

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted, fontSize: 12, height: 1.6),
        filled: true,
        fillColor: _canvas,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Growkids.purpleFlo, width: 1.5)),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _finalizedBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4E8),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_outlined, color: _success, size: 21),
          SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Assessment confirmed',
                    style: TextStyle(
                        color: _success,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                    'This section is finalized. Observations and the result are read-only.',
                    style:
                        TextStyle(color: _success, fontSize: 12, height: 1.6)),
              ])),
        ]),
      );

  Widget _actionBar() => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: LayoutBuilder(builder: (context, constraints) {
                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _saveObservations,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Growkids.purpleFlo,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save draft'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _finalize,
                      style: FilledButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Confirm TP'),
                    ),
                  ],
                );
                final status = Text(
                    _saveStatus ?? 'Observations autosave as you type.',
                    style: TextStyle(
                        color: _saveStatus == 'Save failed'
                            ? Colors.red.shade700
                            : _muted,
                        fontSize: 11,
                        height: 1.5));
                if (constraints.maxWidth < 620) {
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [status, const SizedBox(height: 10), actions]);
                }
                return Row(children: [
                  Expanded(child: status),
                  const SizedBox(width: 24),
                  actions,
                ]);
              }),
            ),
          ),
        ),
      );
}
