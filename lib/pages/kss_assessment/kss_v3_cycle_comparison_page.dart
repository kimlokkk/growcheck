import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_style.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssV3CycleComparisonPage extends StatefulWidget {
  final String teacherId, assignmentId, studentId;
  final List<Map<String, dynamic>> cycles;
  const KssV3CycleComparisonPage(
      {super.key,
      required this.teacherId,
      required this.assignmentId,
      required this.studentId,
      required this.cycles});

  @override
  State<KssV3CycleComparisonPage> createState() =>
      _KssV3CycleComparisonPageState();
}

class _KssV3CycleComparisonPageState extends State<KssV3CycleComparisonPage> {
  static const _ink = Color(0xFF302A3A);
  static const _muted = Color(0xFF5F5B6B);
  static const _border = Color(0xFFDBDBF0);
  static const _canvas = Color(0xFFF8F7FC);
  Map<String, dynamic>? _data;
  late int _fromId;
  late int _toId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _toId = int.parse(widget.cycles.first['cycle_id'].toString());
    _fromId = int.parse(widget.cycles[1]['cycle_id'].toString());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
          Uri.parse(ApiConfig.flutter('kss_v3_cycle_comparison.php')),
          body: {
            'teacher_id': widget.teacherId,
            'assignment_id': widget.assignmentId,
            'student_id': widget.studentId,
            'from_cycle_id': '$_fromId',
            'to_cycle_id': '$_toId',
          });
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to compare cycles.').toString()
            : 'Unable to compare cycles.');
      }
      if (mounted) {
        setState(
            () => _data = Map<String, dynamic>.from(decoded['data'] as Map));
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

  String _label(Map<String, dynamic> cycle) =>
      '${cycle['semester'] == 'SEM2' ? 'Semester 2' : 'Semester 1'} • ${cycle['cycle_type'] == 'REVISION' ? 'Revision' : 'Initial'} ${cycle['cycle_no']}';

  @override
  Widget build(BuildContext context) {
    final from = _data?['from'] as Map?;
    final to = _data?['to'] as Map?;
    final summary = _data?['summary'] as Map? ?? {};
    final items = (_data?['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
            title: const Text('Compare assessments'),
            backgroundColor: Growkids.purpleFlo,
            foregroundColor: Colors.white),
        body: LayoutBuilder(builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 860
              ? (constraints.maxWidth - 760) / 2
              : 20.0;
          return ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 48),
              children: [
                const Text('Assessment comparison',
                    style: TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Select two completed cycles to review progress.',
                    style: TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                    initialValue: _fromId,
                    decoration:
                        const InputDecoration(labelText: 'Compare from'),
                    items: widget.cycles
                        .where(
                            (cycle) => cycle['cycle_id'].toString() != '$_toId')
                        .map((cycle) => DropdownMenuItem<int>(
                            value: int.parse(cycle['cycle_id'].toString()),
                            child: Text(_label(cycle))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _fromId = value);
                      _load();
                    }),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                    initialValue: _toId,
                    decoration: const InputDecoration(labelText: 'Compare to'),
                    items: widget.cycles
                        .where((cycle) =>
                            cycle['cycle_id'].toString() != '$_fromId')
                        .map((cycle) => DropdownMenuItem<int>(
                            value: int.parse(cycle['cycle_id'].toString()),
                            child: Text(_label(cycle))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _toId = value);
                      _load();
                    }),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!)
                else ...[
                  Row(children: [
                    const Text('Overall TP: ',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    KssV3TpStyle.badge(from?['final_tp']),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward)),
                    KssV3TpStyle.badge(to?['final_tp']),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _stat(
                        'Improved', summary['improved'], Colors.green.shade700),
                    _stat('Maintained', summary['maintained'], _muted),
                    _stat('Needs support', summary['dropped'],
                        Colors.red.shade700),
                  ]),
                  const SizedBox(height: 18),
                  ...items.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                          title: Text('${item['code']} ${item['title']}'),
                          subtitle: Text(_itemLabel(item['change'])),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            KssV3TpStyle.badge(item['from_tp']),
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5),
                                child: Icon(Icons.arrow_forward, size: 16)),
                            KssV3TpStyle.badge(item['to_tp']),
                          ])))),
                ],
              ]);
        }));
  }

  Widget _stat(String label, dynamic value, Color color) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text('${value ?? 0} $label',
          style: TextStyle(color: color, fontWeight: FontWeight.w700)));

  String _itemLabel(dynamic value) {
    final change = int.tryParse(value.toString());
    if (change == null) return 'Not available in both cycles';
    if (change > 0) return '↑ Improved by $change TP';
    if (change < 0) return '↓ Dropped by ${change.abs()} TP';
    return '— Maintained';
  }
}
