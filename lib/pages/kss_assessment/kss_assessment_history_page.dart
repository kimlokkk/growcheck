import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssAssessmentHistoryPage extends StatefulWidget {
  final String teacherId;
  final String classId;
  final String studentId;
  final String initialPeriod;

  const KssAssessmentHistoryPage({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.studentId,
    required this.initialPeriod,
  });

  @override
  State<KssAssessmentHistoryPage> createState() => _KssAssessmentHistoryPageState();
}

class _KssAssessmentHistoryPageState extends State<KssAssessmentHistoryPage> {
  late String _period;
  Map<String, dynamic> _student = {};
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_assessment_history.php')),
        body: {'teacher_id': widget.teacherId, 'class_id': widget.classId, 'student_id': widget.studentId, 'reporting_period': _period},
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? decoded['message'] : 'Unable to load assessment history.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      if (!mounted) return;
      setState(() {
        _student = Map<String, dynamic>.from(data['student'] as Map? ?? const {});
        _batches = (data['batches'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _tpColor(int tp) => tp <= 2 ? const Color(0xFFB42318) : tp <= 4 ? const Color(0xFF9A6700) : const Color(0xFF087A55);
  Color _tpBg(int tp) => tp <= 2 ? const Color(0xFFFDE8E7) : tp <= 4 ? const Color(0xFFFFF1C2) : const Color(0xFFDDF7ED);

  List<Map<String, dynamic>> _results(Map<String, dynamic> batch) =>
      (batch['results'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  int? _overallTp(Map<String, dynamic> batch) {
    final summary = Map<String, dynamic>.from(batch['summary'] as Map? ?? const {});
    return int.tryParse('${summary['confirmed_overall_tp'] ?? summary['recommended_tp'] ?? ''}');
  }

  Map<String, int> _changes(Map<String, dynamic> current, Map<String, dynamic>? previous) {
    if (previous == null) return const {'up': 0, 'same': 0, 'down': 0};
    final old = {for (final row in _results(previous)) row['content_standard_id'].toString(): int.tryParse('${row['tp_level']}') ?? 0};
    var up = 0, same = 0, down = 0;
    for (final row in _results(current)) {
      final before = old[row['content_standard_id'].toString()];
      if (before == null) continue;
      final now = int.tryParse('${row['tp_level']}') ?? 0;
      if (now > before) up++; else if (now < before) down++; else same++;
    }
    return {'up': up, 'same': same, 'down': down};
  }

  Map<String, dynamic>? _previousBatch(int index) => index + 1 < _batches.length ? _batches[index + 1] : null;

  int? _previousLevel(Map<String, dynamic>? batch, String standardId) {
    if (batch == null) return null;
    for (final row in _results(batch)) {
      if (row['content_standard_id'].toString() == standardId) {
        return int.tryParse('${row['tp_level']}');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('Student Performance'), backgroundColor: Growkids.purpleFlo, foregroundColor: Colors.white),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 14 : 24),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Growkids.purpleFlo))
                : _error != null
                    ? Center(child: Text(_error!))
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text((_student['student_name'] ?? '-').toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        const Text('Performance and learning progression', style: TextStyle(color: Color(0xFF777486))),
                        const SizedBox(height: 12),
                        _semesterSelector(),
                        const SizedBox(height: 18),
                        Expanded(child: _batches.isEmpty
                            ? const Center(child: Text('No assessment history for this semester.'))
                            : ListView(
                                children: [
                                  _progressOverview(),
                                  const SizedBox(height: 18),
                                  _performanceChart(),
                                  const SizedBox(height: 18),
                                  const Text('Assessment Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  const Text('Open an assessment to see how every learning skill changed.', style: TextStyle(color: Color(0xFF777486), fontSize: 12)),
                                  const SizedBox(height: 10),
                                  ...List.generate(_batches.length, (index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _batchCard(_batches[index], _previousBatch(index), index == 0),
                                  )),
                                ],
                              )),
                      ]),
          ),
        ),
      ),
    );
  }

  Widget _semesterSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDECF3),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0DEE8)),
      ),
      child: Row(children: [
        Expanded(child: _semesterTab('SEM1', 'Semester 1', Icons.looks_one_rounded)),
        const SizedBox(width: 5),
        Expanded(child: _semesterTab('SEM2', 'Semester 2', Icons.looks_two_rounded)),
      ]),
    );
  }

  Widget _semesterTab(String value, String label, IconData icon) {
    final selected = _period == value;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: selected
            ? null
            : () async {
                setState(() => _period = value);
                await _load();
              },
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFF6842FF), Color(0xFF7D59FF)])
                : null,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x336C43FF), blurRadius: 10, offset: Offset(0, 3))]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: selected ? Colors.white : const Color(0xFF777486)),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : const Color(0xFF5F5B6B), fontWeight: FontWeight.w900))),
            if (selected) ...[
              const SizedBox(width: 7),
              const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _progressOverview() {
    final published = _batches.where((batch) => batch['status'] == 'PUBLISHED').toList();
    final current = published.isNotEmpty ? published.first : _batches.first;
    final previous = published.length > 1 ? published[1] : null;
    final changes = _changes(current, previous);
    final up = changes['up'] ?? 0;
    final same = changes['same'] ?? 0;
    final down = changes['down'] ?? 0;
    final baseline = previous == null;
    final mixed = !baseline && up > 0 && down > 0;
    final improving = !baseline && up > 0 && down == 0;
    final reviewing = !baseline && down > 0 && up == 0;
    final overall = _overallTp(current);
    final title = baseline
        ? 'Baseline established'
        : mixed
            ? 'Mixed progress'
            : improving
                ? 'Improving'
                : reviewing
                    ? 'Skills need review'
                    : 'Stable progress';
    final description = previous == null
        ? "Complete another revision to see the student's learning trend."
        : 'Overall ${overall == null ? 'TP is pending' : 'TP$overall'}: $up improved, $same stable and $down decreased.';
    final color = improving
        ? const Color(0xFF087A55)
        : reviewing
            ? const Color(0xFFB42318)
            : mixed
                ? const Color(0xFF9A6700)
                : const Color(0xFF6552D9);
    final background = improving
        ? const Color(0xFFDDF7ED)
        : reviewing
            ? const Color(0xFFFDE8E7)
            : mixed
                ? const Color(0xFFFFF1C2)
                : const Color(0xFFEDE8FF);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E1E8))),
      child: LayoutBuilder(builder: (context, constraints) {
        final trend = Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15)), child: Icon(improving ? Icons.trending_up_rounded : reviewing ? Icons.trending_down_rounded : mixed ? Icons.swap_horiz_rounded : Icons.trending_flat_rounded, color: color, size: 30)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('LEARNING TREND', style: TextStyle(fontSize: 11, color: Color(0xFF777486), fontWeight: FontWeight.w800, letterSpacing: .6)),
            Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(description, style: const TextStyle(color: Color(0xFF5F5B6B))),
          ])),
        ]);
        final stats = Wrap(spacing: 8, runSpacing: 8, children: [
          _stat('Overall', overall == null ? 'Pending' : 'TP$overall', overall == null ? const Color(0xFF777486) : _tpColor(overall), overall == null ? const Color(0xFFF3F2F7) : _tpBg(overall)),
          _stat('Improved', '${changes['up']}', const Color(0xFF087A55), const Color(0xFFDDF7ED)),
          _stat('Stable', '${changes['same']}', const Color(0xFF6552D9), const Color(0xFFEDE8FF)),
          _stat('Decreased', '$down', const Color(0xFFB42318), const Color(0xFFFDE8E7)),
        ]);
        final main = constraints.maxWidth < 700
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [trend, const SizedBox(height: 16), stats])
            : Row(children: [Expanded(child: trend), const SizedBox(width: 20), stats]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          main,
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF6552D9)),
            SizedBox(width: 7),
            Expanded(child: Text('Overall TP summarises the student’s overall achievement. Individual SK may still improve, remain stable or decrease.', style: TextStyle(fontSize: 11, color: Color(0xFF5F5B6B)))),
          ]),
        ]);
      }),
    );
  }

  Widget _stat(String label, String value, Color color, Color background) => Container(
    width: 92, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF5F5B6B), fontWeight: FontWeight.w700)), Text(value, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w900))]),
  );

  Widget _performanceChart() {
    final published = _batches
        .where((batch) => batch['status'] == 'PUBLISHED')
        .toList()
        .reversed;
    final points = <_PerformancePoint>[];
    for (final batch in published) {
      final tp = _overallTp(batch);
      if (tp == null) continue;
      final label = batch['assessment_type'] == 'REVISION'
          ? 'Revision ${batch['revision_no']}'
          : 'Initial';
      points.add(_PerformancePoint(label, tp));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E1E8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.show_chart_rounded, color: Growkids.purpleFlo),
          SizedBox(width: 8),
          Text('Overall TP Progression', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 3),
        const Text(
          'Published results from the initial assessment through each revision.',
          style: TextStyle(fontSize: 12, color: Color(0xFF777486)),
        ),
        const SizedBox(height: 12),
        if (points.isEmpty)
          const SizedBox(height: 150, child: Center(child: Text('No published TP available yet.')))
        else
          SizedBox(
            height: MediaQuery.sizeOf(context).width < 600 ? 220 : 260,
            width: double.infinity,
            child: CustomPaint(painter: _PerformanceChartPainter(points)),
          ),
      ]),
    );
  }

  Widget _batchCard(Map<String, dynamic> batch, Map<String, dynamic>? previous, bool latest) {
    final results = (batch['results'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final revision = batch['assessment_type'] == 'REVISION';
    final active = batch['status'] == 'IN_PROGRESS';
    final tp = _overallTp(batch);
    final changes = _changes(batch, previous);
    final up = changes['up'] ?? 0;
    final down = changes['down'] ?? 0;
    final movement = previous == null
        ? ''
        : up > 0 && down > 0
            ? ' - $up improved, $down decreased'
            : up > 0
                ? ' - $up SK improved'
                : down > 0
                    ? ' - $down SK decreased'
                    : ' - all comparable SK stable';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E1E8))),
      child: ExpansionTile(
        initiallyExpanded: latest,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: active ? const Color(0xFFFFF1C2) : const Color(0xFFEDE8FF),
          child: Icon(active ? Icons.pending_actions_rounded : Icons.history_rounded, color: active ? const Color(0xFF9A6700) : Growkids.purpleFlo),
        ),
        title: Text(revision ? 'Revision ${batch['revision_no']}' : 'Initial Assessment', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(active ? '${results.length} SK completed - not published' : 'Published ${batch['published_at'] ?? ''}$movement', style: const TextStyle(fontSize: 12)),
        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: tp == null ? const Color(0xFFF3F2F7) : _tpBg(tp), borderRadius: BorderRadius.circular(10)), child: Text(tp == null ? 'Pending' : 'TP$tp', style: TextStyle(fontSize: 12, color: tp == null ? const Color(0xFF777486) : _tpColor(tp), fontWeight: FontWeight.w900))),
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth >= 700 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: results.map((result) {
                final level = int.tryParse('${result['tp_level']}') ?? 1;
                final oldLevel = _previousLevel(previous, result['content_standard_id'].toString());
                final change = oldLevel == null ? null : level - oldLevel;
                return SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFAFAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9E8EF))),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _tpBg(level), borderRadius: BorderRadius.circular(10)), child: Text('TP$level', style: TextStyle(color: _tpColor(level), fontWeight: FontWeight.w900))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SK ${result['sk_code']}', style: const TextStyle(color: Growkids.purpleFlo, fontWeight: FontWeight.w900)), Text((result['sk_statement'] ?? '-').toString(), maxLines: 2, overflow: TextOverflow.ellipsis)])),
                      if (change != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: change > 0 ? const Color(0xFFDDF7ED) : change < 0 ? const Color(0xFFFDE8E7) : const Color(0xFFF3F2F7), borderRadius: BorderRadius.circular(9)), child: Text(change > 0 ? '+$change' : change < 0 ? '$change' : 'Same', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: change > 0 ? const Color(0xFF087A55) : change < 0 ? const Color(0xFFB42318) : const Color(0xFF777486)))),
                    ]),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _PerformancePoint {
  final String label;
  final int tp;

  const _PerformancePoint(this.label, this.tp);
}

class _PerformanceChartPainter extends CustomPainter {
  final List<_PerformancePoint> points;

  const _PerformanceChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 20.0;
    const top = 25.0;
    const bottom = 44.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE9E8EF)
      ..strokeWidth = 1;
    for (var tp = 1; tp <= 6; tp++) {
      final y = top + chartHeight * (6 - tp) / 5;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      _text(canvas, 'TP$tp', Offset(4, y - 7), const Color(0xFF777486), 10, FontWeight.w700);
    }

    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (points.length - 1);
      final y = top + chartHeight * (6 - points[index].tp) / 5;
      offsets.add(Offset(x, y));
    }

    if (offsets.length > 1) {
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final point in offsets.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = const Color(0xFF6C43FF)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    for (var index = 0; index < offsets.length; index++) {
      final point = offsets[index];
      canvas.drawCircle(point, 8, Paint()..color = Colors.white);
      canvas.drawCircle(point, 6, Paint()..color = const Color(0xFF6C43FF));
      _centeredText(canvas, 'TP${points[index].tp}', Offset(point.dx, point.dy - 25), const Color(0xFF302A3A), 11, FontWeight.w900);
      _centeredText(canvas, points[index].label, Offset(point.dx, size.height - 22), const Color(0xFF5F5B6B), 10, FontWeight.w700);
    }
  }

  void _text(Canvas canvas, String value, Offset offset, Color color, double size, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _centeredText(Canvas canvas, String value, Offset center, Color color, double size, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 90);
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PerformanceChartPainter oldDelegate) => oldDelegate.points != points;
}
