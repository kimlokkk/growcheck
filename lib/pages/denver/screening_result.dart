import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/denver/result_pdf.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

bool _useDesktopScreeningResultLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class ScreeningResult extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age; // months
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;
  // ignore: non_constant_identifier_names
  final String therapist_suggestion;
  final String screeningDate;

  const ScreeningResult({
    super.key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
    // ignore: non_constant_identifier_names
    required this.therapist_suggestion,
    required this.screeningDate,
  });

  @override
  State<ScreeningResult> createState() => _ScreeningResultState();
}

class _ScreeningResultState extends State<ScreeningResult> {
  bool isLoading = true;
  List<Map<String, dynamic>> failData = [];
  Map<String, List<Map<String, dynamic>>> domainData = {};

  List<dynamic> suggestions = [];
  List<dynamic> recommendations = [];
  List<dynamic> interventions = [];
  int _tabIndex = 0;
  String? _error;

  Future<void> fetchFailData() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('screening_result.php')),
        /*Uri.parse(
            'http://app-kizzu.test/growkids/flutter/screening_result.php'),*/
        body: {
          "stud_id": widget.studentId,
          "screening_id": widget.screeningId,
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load screening result (HTTP ${response.statusCode})');
      }

      final decoded = json.decode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid screening result format');
      }

      if (decoded['status'] == 'error') {
        throw Exception(
            decoded['message'] ?? 'Failed to load screening result');
      }

      final rawFailData = decoded['failData'];

      failData = rawFailData is List
          ? List<Map<String, dynamic>>.from(rawFailData)
          : [];

      _groupDataByDomain(failData);

      await fetchSuggestionData();

      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _groupDataByDomain(List<Map<String, dynamic>> data) {
    domainData.clear();
    for (final item in data) {
      final domain = (item['domain'] ?? '').toString();
      domainData.putIfAbsent(domain, () => []).add(item);
    }
  }

  Future<void> fetchSuggestionData() async {
    final response = await http.post(
      /*Uri.parse(
          'http://app-kizzu.test/growkids/flutter/fetch_suggestion_submission.php'),*/
      Uri.parse(ApiConfig.flutter('fetch_suggestion_submission.php')),
      body: {
        "studentId": widget.studentId,
        "screeningId": widget.screeningId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load suggestion data (HTTP ${response.statusCode})');
    }

    final decoded = json.decode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected suggestion response format');
    }

    suggestions = decoded["suggestions"] ?? [];
    recommendations = decoded["recommendations"] ?? [];
    interventions = decoded["interventions"] ?? [];
  }

  bool _hasAnySuggestionData() {
    return suggestions.isNotEmpty ||
        recommendations.isNotEmpty ||
        interventions.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    fetchFailData();
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopScreeningResultLayout(context)) {
      return _buildDesktop(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Screening Result'),
        centerTitle: true,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'PDF Result',
            onPressed: isLoading || _error != null ? null : _openPdfResult,
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(2.h),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.redAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.all(2.h),
                  children: [
                    _heroHeader(),
                    SizedBox(height: 2.h),
                    _developmentGrid(),
                    SizedBox(height: 1.2.h),
                    _failComponentsCard(),
                    SizedBox(height: 1.2.h),
                    _suggestionSummaryCard(),
                    SizedBox(height: 1.2.h),
                    _segmentedTabs(),
                    SizedBox(height: 1.2.h),
                    _suggestionContentCard(),
                    SizedBox(height: 1.2.h),
                    if (!_hasAnySuggestionData() &&
                        widget.therapist_suggestion.trim().isNotEmpty) ...[
                      _therapistSuggestionOnlyCard(),
                      SizedBox(height: 1.2.h),
                    ],
                  ],
                ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      appBar: AppBar(
        title: const Text('Screening Result'),
        centerTitle: false,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'PDF Result',
            onPressed: isLoading || _error != null ? null : _openPdfResult,
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(30, 26, 30, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        children: [
                          _desktopHeader(),
                          const SizedBox(height: 18),
                          _desktopDevelopmentOverview(),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 10,
                                child: _desktopFailurePanel(),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 11,
                                child: _desktopPlanPanel(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _desktopHeader() {
    final initial = widget.studentName.isNotEmpty
        ? widget.studentName[0].toUpperCase()
        : '?';
    final formattedDate = DateFormat('EEE, d MMM yyyy')
        .format(DateTime.parse(widget.screeningDate));

    return _desktopSurface(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Growkids.purpleFlo,
                  Growkids.purpleFlo.withValues(alpha: 0.72),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    color: Color(0xFF20232D),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _desktopChip(
                      Icons.cake_outlined,
                      '${widget.age.toStringAsFixed(0)} months',
                    ),
                    _desktopChip(Icons.event_outlined, formattedDate),
                    _desktopChip(
                        Icons.receipt_long_outlined, 'Screening result'),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _openPdfResult,
            style: FilledButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }

  Widget _desktopChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F0FF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Growkids.purpleFlo, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF57526A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopDevelopmentOverview() {
    final metrics = [
      ('Fine Motor', widget.ageFineMotor, Icons.pan_tool_alt_outlined),
      ('Gross Motor', widget.ageGrossMotor, Icons.directions_run_rounded),
      ('Personal Social', widget.agePersonal, Icons.groups_2_outlined),
      ('Language', widget.ageLanguage, Icons.record_voice_over_outlined),
    ];

    return Row(
      children: List.generate(metrics.length, (index) {
        final metric = metrics[index];
        final ok = metric.$2 >= widget.age;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 12),
            child: _desktopSurface(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: (ok ? Colors.green : Colors.red)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          metric.$3,
                          color: ok ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        ok ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: ok ? Colors.green : Colors.red,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    metric.$1,
                    style: const TextStyle(
                      color: Color(0xFF4A4D57),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${metric.$2.toStringAsFixed(0)} months',
                    style: const TextStyle(
                      color: Color(0xFF20232D),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 11),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: widget.age <= 0
                          ? 0
                          : (metric.$2 / widget.age).clamp(0.0, 1.0),
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      color: ok ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _desktopFailurePanel() {
    return _desktopSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopSectionTitle(
            'Review items',
            'Fail / No Opportunity components',
            Icons.fact_check_outlined,
            count: failData.length,
          ),
          const SizedBox(height: 16),
          if (domainData.isEmpty)
            _desktopEmpty('No failed components recorded.')
          else
            ...domainData.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8FC),
                  borderRadius: BorderRadius.circular(13),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: ExpansionTile(
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  title: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.value.length} items',
                    style: const TextStyle(fontSize: 11),
                  ),
                  children: entry.value.map((component) {
                    final name = (component['component'] ?? '').toString();
                    final recommendation =
                        (component['recommendation'] ?? '').toString();
                    final score = (component['score'] ?? '').toString();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              _desktopScoreBadge(score),
                            ],
                          ),
                          if (recommendation.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              recommendation,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.58),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _desktopPlanPanel() {
    return _desktopSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopSectionTitle(
            'Suggestion & plan',
            'Submitted clinical guidance',
            Icons.lightbulb_outline_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _desktopTab('Suggestions', suggestions.length, 0),
              const SizedBox(width: 8),
              _desktopTab('Advice', recommendations.length, 1),
              const SizedBox(width: 8),
              _desktopTab('Plan', interventions.length, 2),
            ],
          ),
          const SizedBox(height: 15),
          _desktopTabContent(),
          if (!_hasAnySuggestionData() &&
              widget.therapist_suggestion.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _desktopNarrative(
              'Therapist suggestion',
              widget.therapist_suggestion,
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopTab(String label, int count, int index) {
    final active = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Growkids.purpleFlo : const Color(0xFFF5F4FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$label  $count',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF595C66),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopTabContent() {
    if (_tabIndex == 2) {
      if (interventions.isEmpty) return _desktopEmpty('No plan available yet.');
      return Column(
        children: List.generate(interventions.length, (index) {
          final item = interventions[index] as Map? ?? {};
          return _desktopNarrative(
            (item['title'] ?? 'Plan ${index + 1}').toString(),
            [item['description'], item['example']]
                .where((value) => (value ?? '').toString().trim().isNotEmpty)
                .join('\n\n'),
          );
        }),
      );
    }

    final items = _tabIndex == 0 ? suggestions : recommendations;
    final key = _tabIndex == 0 ? 'suggestion' : 'recommendation';
    if (items.isEmpty) return _desktopEmpty('No data available yet.');
    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index] as Map? ?? {};
        return _desktopNarrative(
          '${index + 1}'.padLeft(2, '0'),
          (item[key] ?? '').toString(),
        );
      }),
    );
  }

  Widget _desktopNarrative(String label, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.black.withValues(alpha: 0.045)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              label,
              style: const TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              text.trim().isEmpty ? '-' : text,
              style: const TextStyle(
                color: Color(0xFF42454F),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSectionTitle(
    String title,
    String subtitle,
    IconData icon, {
    int? count,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Growkids.purpleFlo.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Growkids.purpleFlo, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.48),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Growkids.purpleFlo,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _desktopScoreBadge(String score) {
    final color = score == 'Fail' ? Colors.red : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        score == 'N.O' ? 'No Opportunity' : score,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _desktopEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: Colors.black.withValues(alpha: 0.55), fontSize: 12),
      ),
    );
  }

  Widget _desktopSurface({
    required Widget child,
    required EdgeInsetsGeometry padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  void _openPdfResult() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPdf(
          studentId: widget.studentId,
          screeningId: widget.screeningId,
          age: widget.age,
          studentName: widget.studentName,
          ageString: '${widget.age.toStringAsFixed(0)} months',
          ageFineMotor: widget.ageFineMotor,
          ageGrossMotor: widget.ageGrossMotor,
          ageLanguage: widget.ageLanguage,
          agePersonal: widget.agePersonal,
          therapist_suggestion: widget.therapist_suggestion,
          screeningDate: widget.screeningDate,
          failData: failData,
        ),
      ),
    );
  }

  // =========================
  // THEME BLOCKS (Premium)
  // =========================

  Widget _heroHeader() {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white,
            child: Text(
              widget.studentName.isNotEmpty
                  ? widget.studentName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${widget.age.toStringAsFixed(0)} months',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    SizedBox(
                      width: 1.w,
                    ),
                    Text(
                      '*Age on the day of screening',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 1.h,
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 2.h,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEE, d MMM yyyy')
                            .format(DateTime.parse(widget.screeningDate)),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _developmentGrid() {
    final cardWidth = MediaQuery.of(context).size.width / 3;
    final cardHeight = MediaQuery.of(context).size.height / 6;

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: (cardWidth / cardHeight),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      crossAxisCount: 2,
      children: <Widget>[
        _buildDevelopmentCard('Fine Motor', widget.ageFineMotor, widget.age),
        _buildDevelopmentCard('Gross Motor', widget.ageGrossMotor, widget.age),
        _buildDevelopmentCard(
            'Personal Social', widget.agePersonal, widget.age),
        _buildDevelopmentCard('Language', widget.ageLanguage, widget.age),
      ],
    );
  }

  Widget _buildDevelopmentCard(
      String title, double developmentalAge, double actualAge) {
    // kalau lebih/kurang dari actual, consider "needs attention"
    final ok = developmentalAge >= actualAge;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(height: 1.h),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (ok ? Colors.green : Colors.red)
                        .withValues(alpha: 0.25)),
              ),
              child: Text(
                '${developmentalAge.toStringAsFixed(0)} months',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: ok ? Colors.green : Colors.red,
                ),
              ),
            ),
            SizedBox(height: 2.h),
            SfLinearGauge(
              minimum: 0,
              maximum: actualAge <= 0 ? 1 : actualAge,
              interval: (actualAge <= 0) ? 1 : (actualAge / 5),
              axisTrackStyle: LinearAxisTrackStyle(
                thickness: 1.h,
                color: Colors.black.withValues(alpha: 0.08),
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
              markerPointers: [
                LinearShapePointer(
                  value: developmentalAge,
                  color: ok ? Colors.green : Colors.red,
                  height: 1.5.h,
                  width: 2.w,
                ),
              ],
              barPointers: [
                LinearBarPointer(
                  value: developmentalAge,
                  color: ok ? Colors.green : Colors.red,
                  thickness: 1.h,
                  edgeStyle: LinearEdgeStyle.bothCurve,
                ),
              ],
              animationDuration: 800,
            ),
            SizedBox(height: 1.h),
            Text(
              'Age in months',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failComponentsCard() {
    final totalFail = failData.length;

    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Fail/No Opportunity Components',
                style: TextStyle(
                  fontSize: 16.sp,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Growkids.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalFail',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Growkids.purple,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Grouped by domain for faster review.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 1.2.h),
          if (domainData.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Text(
                'No failed components recorded.',
                style: TextStyle(fontSize: 14.sp, color: Colors.black54),
              ),
            )
          else
            ...domainData.entries.map((entry) {
              final domain = entry.key;
              final items = entry.value;

              return Container(
                margin: EdgeInsets.only(bottom: 1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  title: Text(
                    domain,
                    style: TextStyle(
                      fontSize: 14.sp,
                    ),
                  ),
                  subtitle: Text(
                    '${items.length} items',
                    style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                  ),
                  children: items.map((component) {
                    final comp = (component['component'] ?? '').toString();
                    final rec = (component['recommendation'] ?? '').toString();
                    final score = (component['score'] ?? '').toString();

                    return Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 1.h),
                      padding: EdgeInsets.all(1.5.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comp,
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                              ),
                              _scoreBadge(score),
                            ],
                          ),
                          if (rec.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Recommendation: $rec',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black.withValues(alpha: 0.60),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _scoreBadge(String score) {
    final isFail = score == 'Fail';

    final color =
        isFail ? Colors.red : const Color(0xFFF59E0B); // amber for N.O

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 1.h,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        score == 'N.O' ? 'No Opportunity' : score,
        style: TextStyle(
          fontSize: 13.sp,
          color: color,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _therapistSuggestionCard() {
    final suggestion = widget.therapist_suggestion.trim();

    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 5.h,
                width: 5.h,
                decoration: BoxDecoration(
                  color: Growkids.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: Growkids.purple,
                  size: 2.4.h,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Therapist Suggestion',
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'Recommendation or note added after screening.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 1.4.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(1.6.h),
            decoration: BoxDecoration(
              color: Growkids.purple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Growkids.purple.withValues(alpha: 0.10),
              ),
            ),
            child: Text(
              suggestion,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _summaryCard(String label, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Growkids.purple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Growkids.purple.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              height: 4.h,
              width: 4.h,
              decoration: BoxDecoration(
                color: Growkids.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Growkids.purple,
                size: 2.h,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.black.withValues(alpha: 0.62),
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 15.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionSummaryCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestion & Plan',
            style: TextStyle(fontSize: 15.sp),
          ),
          SizedBox(height: 0.6.h),
          Text(
            'Review submitted suggestions, advice, and intervention plans.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 1.2.h),
          Row(
            children: [
              _summaryCard(
                  'Suggestions', suggestions.length, Icons.lightbulb_rounded),
              const SizedBox(width: 10),
              _summaryCard(
                  'Advice', recommendations.length, Icons.checklist_rounded),
              const SizedBox(width: 10),
              _summaryCard('Plans', interventions.length, Icons.route_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmentedTabs() {
    Widget tab(String text, IconData icon, int index) {
      final active = _tabIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tabIndex = index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(vertical: 1.h),
            decoration: BoxDecoration(
              color: active ? Growkids.purpleFlo : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 2.2.h,
                  color: active
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: active
                        ? Colors.white
                        : Colors.black.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Suggestions', Icons.lightbulb_rounded, 0),
        SizedBox(width: 1.w),
        tab('Advice', Icons.checklist_rounded, 1),
        SizedBox(width: 1.w),
        tab('Plan', Icons.route_rounded, 2),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.black.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interventionList() {
    if (interventions.isEmpty) {
      return _emptyBox('No intervention plan available yet.');
    }

    return Column(
      children: List.generate(interventions.length, (i) {
        final it = interventions[i] as Map? ?? {};
        final title = (it['title'] ?? '').toString().trim();
        final desc = (it['description'] ?? '').toString().trim();
        final ex = (it['example'] ?? '').toString().trim();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 4.h,
                    width: 4.h,
                    decoration: BoxDecoration(
                      color: Growkids.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style:
                            TextStyle(color: Growkids.purple, fontSize: 13.sp),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Intervention Plan' : title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.black.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                'Description',
                style: TextStyle(fontSize: 12.sp, color: Growkids.pink),
              ),
              SizedBox(height: 0.5.h),
              Text(
                desc.isEmpty ? '-' : desc,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.black.withValues(alpha: 0.70),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Example',
                style: TextStyle(fontSize: 12.sp, color: Growkids.pink),
              ),
              SizedBox(height: 0.5.h),
              Text(
                ex.isEmpty ? '-' : ex,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.black.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _contentByTab() {
    switch (_tabIndex) {
      case 0:
        return _bulletList(suggestions, 'suggestion',
            icon: Icons.lightbulb_rounded);
      case 1:
        return _bulletList(recommendations, 'recommendation',
            icon: Icons.checklist_rounded);
      case 2:
      default:
        return _interventionList();
    }
  }

  Widget _bulletList(List<dynamic> items, String keyName,
      {required IconData icon}) {
    if (items.isEmpty) {
      return _emptyBox('No data available yet.');
    }

    return Column(
      children: List.generate(items.length, (i) {
        final it = items[i] as Map? ?? {};
        final text = (it[keyName] ?? '').toString().trim();

        return Container(
          margin: EdgeInsets.only(bottom: 1.h),
          padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 5.h,
                width: 5.h,
                decoration: BoxDecoration(
                  color: Growkids.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Growkids.purple, size: 2.5.h),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  text.isEmpty ? '-' : text,
                  style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.black.withValues(alpha: 0.78)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _suggestionContentCard() {
    return _glassCard(
      child: _contentByTab(),
    );
  }

  Widget _therapistSuggestionOnlyCard() {
    final suggestion = widget.therapist_suggestion.trim();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 5.h,
                width: 5.h,
                decoration: BoxDecoration(
                  color: Growkids.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: Growkids.purple,
                  size: 2.4.h,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Therapist Suggestion',
                  style: TextStyle(fontSize: 15.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(1.6.h),
            decoration: BoxDecoration(
              color: Growkids.purple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Growkids.purple.withValues(alpha: 0.10)),
            ),
            child: Text(
              suggestion,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.black.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
