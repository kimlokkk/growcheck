import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

bool _useDesktopScoreResultLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class ScoreResult extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String age;
  final String ageInMonths;
  final int ageInMonthsINT;
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;

  const ScoreResult({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.age,
    required this.ageInMonths,
    required this.ageInMonthsINT,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
  });

  @override
  State<ScoreResult> createState() => _ScoreResultState();
}

class _ScoreResultState extends State<ScoreResult> {
  bool isLoading = false;
  List<Map<String, dynamic>> failData = [];
  List<Map<String, dynamic>> noOppData = [];
  Map<String, List<Map<String, dynamic>>> noOppDomainData = {};
  Map<String, List<Map<String, dynamic>>> domainData = {};
  final TextEditingController suggestionController = TextEditingController();
  bool suggestionSubmitted = false;

  Future<void> fetchData() async {
    final response = await http.post(
      Uri.parse(ApiConfig.flutter('score_result.php')),
      /*Uri.parse('http://app-kizzu.test/growkids/flutter/score_result.php'),*/
      body: {"stud_id": widget.studentId},
    );

    if (response.statusCode == 200) {
      final List<dynamic> raw = json.decode(response.body);
      final all = List<Map<String, dynamic>>.from(raw);

      // Terus tapis ikut nilai tepat
      failData = all.where((m) => (m['score']?.toString() == 'Fail')).toList();
      noOppData = all.where((m) => (m['score']?.toString() == 'N.O')).toList();

      _groupDataByDomainInto(failData, domainData);
      _groupDataByDomainInto(noOppData, noOppDomainData);

      setState(() {});
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _groupDataByDomainInto(
    List<Map<String, dynamic>> data,
    Map<String, List<Map<String, dynamic>>> target,
  ) {
    target.clear();
    for (final item in data) {
      final domain = (item['domain'] ?? '').toString();
      target.putIfAbsent(domain, () => []).add(item);
    }
  }

  Future<void> _submitSuggestion() async {
    if (suggestionSubmitted) return;

    String suggestion = suggestionController.text.trim();

    if (suggestion.isEmpty) {
      await _showScoreDialog(
        title: 'Error',
        message: 'Please enter a suggestion.',
        isError: true,
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('suggestion_v2.php')),
        //Uri.parse('http://app-kizzu.test/growkids/flutter/suggestion_v2.php'),
        body: {
          "suggestion": suggestion,
          "stud_id": widget.studentId,
        },
      );

      if (response.statusCode == 200) {
        final confirmed = await _showScoreDialog(
          title: 'Success',
          message: 'Suggestion submitted successfully!',
          isError: false,
        );
        if (mounted && confirmed) {
          setState(() => suggestionSubmitted = true);
        }
      } else {
        throw Exception('Failed to submit suggestion');
      }
    } catch (e) {
      await _showScoreDialog(
        title: 'Error',
        message: 'An error occurred: $e',
        isError: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopScoreResultLayout(context)) {
      return _buildDesktop();
    }

    final double cardWidth = MediaQuery.of(context).size.width / 3.3;
    final double cardHeight = MediaQuery.of(context).size.height / 5.9;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Score Result',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      // ✅ FIXED bottom button
      bottomNavigationBar: _finishBar(),

      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(2.2.h, 1.6.h, 2.2.h, 0),
          child: Column(
            children: [
              // ✅ Student header (premium)
              _studentHeaderCard(),
              SizedBox(height: 1.4.h),

              // ✅ Only content scrolls
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 2.2.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ Dev Age Grid Card
                      Container(
                        padding: EdgeInsets.all(1.6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 5.h,
                                  width: 5.h,
                                  decoration: BoxDecoration(
                                    color: Growkids.purpleFlo
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.speed_rounded,
                                      color: Growkids.purpleFlo, size: 2.6.h),
                                ),
                                SizedBox(width: 2.w),
                                Expanded(
                                  child: Text(
                                    'Developmental Ages',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 1.h, vertical: 0.5.h),
                                  decoration: BoxDecoration(
                                    color: Growkids.purpleFlo
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: Colors.black
                                            .withValues(alpha: 0.08)),
                                  ),
                                  child: Text(
                                    'Actual: ${widget.ageInMonthsINT} mo',
                                    style: TextStyle(fontSize: 13.sp),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 1.4.h),
                            GridView.count(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              childAspectRatio: (cardWidth / cardHeight),
                              crossAxisSpacing: 1.h,
                              mainAxisSpacing: 1.h,
                              crossAxisCount: 2,
                              children: <Widget>[
                                _buildDevelopmentCard('Fine Motor',
                                    widget.ageFineMotor, widget.ageInMonthsINT),
                                _buildDevelopmentCard(
                                    'Gross Motor',
                                    widget.ageGrossMotor,
                                    widget.ageInMonthsINT),
                                _buildDevelopmentCard('Personal Social',
                                    widget.agePersonal, widget.ageInMonthsINT),
                                _buildDevelopmentCard('Language',
                                    widget.ageLanguage, widget.ageInMonthsINT),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 1.6.h),

                      Container(
                        padding: EdgeInsets.all(1.6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _sectionTitle(
                              title: 'Fail Components',
                              subtitle: 'Items marked as Fail during screening',
                              icon: Icons.close_rounded,
                              tint: Growkids.purpleFlo,
                            ),
                            SizedBox(height: 1.0.h),
                            _buildFailComponentSection(),
                          ],
                        ),
                      ),
                      // ✅ Fail section

                      SizedBox(height: 1.6.h),
                      Container(
                        padding: EdgeInsets.all(1.6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _sectionTitle(
                              title: 'No Opportunity Components',
                              subtitle: 'Items marked as N.O during screening',
                              icon: Icons.do_not_disturb_on_rounded,
                              tint: Growkids.pink,
                            ),
                            SizedBox(height: 1.0.h),
                            _buildNoOppComponentSection(),
                          ],
                        ),
                      ),
                      // ✅ N.O section

                      SizedBox(height: 1.6.h),

                      Container(
                        padding: EdgeInsets.all(1.6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ✅ Therapist Note section
                            _sectionTitle(
                              title: 'Therapist Note',
                              subtitle: 'Add comment before finishing',
                              icon: Icons.edit_note_rounded,
                              tint: Growkids.pink,
                            ),
                            SizedBox(height: 1.0.h),
                            TextField(
                              controller: suggestionController,
                              maxLines: 4,
                              readOnly: suggestionSubmitted,
                              enabled: !suggestionSubmitted,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: suggestionSubmitted
                                    ? Colors.grey.shade200
                                    : GrowkidsPastel.pink,
                                hintText: 'Enter your note/comment...',
                                hintStyle: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w600,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Growkids.pink, width: 2),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.all(1.4.h),
                              ),
                            ),
                            SizedBox(height: 1.2.h),

                            // Optional: quick submit (tak wajib, sebab kau guna Finish bawah)
                            SizedBox(
                              height: 5.4.h,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color:
                                          Growkids.pink.withValues(alpha: 0.35),
                                      width: 1.4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: suggestionSubmitted
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                ),
                                onPressed: suggestionSubmitted
                                    ? null
                                    : _submitSuggestion,
                                child: Text(
                                  suggestionSubmitted
                                      ? 'Note Submitted'
                                      : 'Submit Note',
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w900,
                                    color: suggestionSubmitted
                                        ? Colors.grey
                                        : Growkids.pink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// =======================
  /// Premium helper widgets
  /// =======================

  Widget _studentHeaderCard() {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_rounded, color: Colors.white, size: 3.h),
          ),
          SizedBox(width: 1.6.h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
                Text(
                  '${widget.age} • ${widget.ageInMonths} Months',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 2.6.h),
          ),
          SizedBox(width: 1.2.h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.sp)),
                SizedBox(height: 0.2.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finishBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(2.2.h, 1.0.h, 2.2.h, 2.0.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 6.h,
          child: ElevatedButton(
            onPressed: _handleFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Finish Screening',
              style: TextStyle(fontSize: 14.sp, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: const Text(
          'Score Result',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _desktopHeader(),
                const SizedBox(height: 20),
                _desktopDevelopmentOverview(),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _desktopComponentsPanel(
                            title: 'Fail Components',
                            subtitle: 'Items marked as Fail during screening',
                            icon: Icons.close_rounded,
                            color: const Color(0xFFDC3545),
                            groups: domainData,
                            emptyText: 'No fail components.',
                          ),
                          const SizedBox(height: 20),
                          _desktopComponentsPanel(
                            title: 'No Opportunity Components',
                            subtitle: 'Items marked as N.O during screening',
                            icon: Icons.do_not_disturb_on_outlined,
                            color: const Color(0xFF3D7AF5),
                            groups: noOppDomainData,
                            emptyText: 'No "No Opportunity" components.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _desktopTherapistNote(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 190,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handleFinish,
                      icon: const Icon(Icons.check_rounded, size: 19),
                      label: const Text(
                        'Finish Screening',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    final initial = widget.studentName.trim().isEmpty
        ? '?'
        : widget.studentName.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x253F2A91),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Growkids.purple,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DENVER SCREENING SCORE',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _desktopHeaderMeta(Icons.badge_outlined, widget.studentId),
                    _desktopHeaderMeta(Icons.cake_outlined, widget.age),
                    _desktopHeaderMeta(
                      Icons.calendar_view_month_outlined,
                      '${widget.ageInMonthsINT} months',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _desktopHeaderCount(
            'Failed',
            failData.length,
            Icons.close_rounded,
            const Color(0xFFFF8C9B),
          ),
          const SizedBox(width: 10),
          _desktopHeaderCount(
            'N.O',
            noOppData.length,
            Icons.do_not_disturb_on_outlined,
            const Color(0xFF7DD3FC),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeaderMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xD9FFFFFF)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _desktopHeaderCount(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 102,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _desktopDevelopmentOverview() {
    final items = [
      ('Fine Motor', widget.ageFineMotor, const Color(0xFF3D7AF5)),
      ('Gross Motor', widget.ageGrossMotor, const Color(0xFF12A47A)),
      ('Personal Social', widget.agePersonal, const Color(0xFF8B5CF6)),
      ('Language', widget.ageLanguage, const Color(0xFFF59E0B)),
    ];

    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Developmental Ages',
                  style: TextStyle(
                    color: Color(0xFF242735),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _desktopChip(
                'Actual age ${widget.ageInMonthsINT} mo',
                Growkids.purple,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: item == items.last ? 0 : 12,
                      ),
                      child: _desktopDevelopmentCard(
                        item.$1,
                        item.$2,
                        item.$3,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _desktopDevelopmentCard(
    String title,
    double developmentAge,
    Color color,
  ) {
    final actualAge = widget.ageInMonthsINT.toDouble();
    final progress =
        actualAge <= 0 ? 0.0 : (developmentAge / actualAge).clamp(0.0, 1.0);
    final passed = developmentAge == actualAge;
    final statusColor =
        passed ? const Color(0xFF16A34A) : const Color(0xFFDC3545);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A4E5C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      passed
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: statusColor,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      passed ? 'Pass' : 'Needs attention',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                developmentAge.toStringAsFixed(0),
                style: TextStyle(
                  color: color,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 3, left: 4),
                child: Text(
                  'months',
                  style: TextStyle(color: Color(0xFF858A99), fontSize: 10),
                ),
              ),
              const Spacer(),
              Icon(
                passed
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                color: statusColor,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: passed ? const Color(0xFF16A34A) : color,
              backgroundColor: statusColor.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopComponentsPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Map<String, List<Map<String, dynamic>>> groups,
    required String emptyText,
  }) {
    final count =
        groups.values.fold<int>(0, (sum, items) => sum + items.length);

    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF242735),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF858A99),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _desktopChip('$count items', color),
            ],
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            _desktopEmpty(emptyText)
          else
            ...groups.entries.map(
              (entry) => _desktopDomainGroup(
                entry.key,
                entry.value,
                color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopDomainGroup(
    String domain,
    List<Map<String, dynamic>> items,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E9F0)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 15),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
        title: Text(
          domain,
          style: const TextStyle(
            color: Color(0xFF3F4350),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${items.length} item${items.length == 1 ? '' : 's'}',
          style: const TextStyle(color: Color(0xFF858A99), fontSize: 10),
        ),
        children: items
            .map(
              (item) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFE7E9F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['component'] ?? '').toString(),
                      style: const TextStyle(
                        color: Color(0xFF3F4350),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (item['recommendation'] ?? '').toString(),
                      style: const TextStyle(
                        color: Color(0xFF717685),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _desktopTherapistNote() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Growkids.pink.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Growkids.pink,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Therapist Note',
                      style: TextStyle(
                        color: Color(0xFF242735),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Required before finishing',
                      style: TextStyle(
                        color: Color(0xFF858A99),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (suggestionSubmitted)
                _desktopChip('Submitted', const Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: suggestionController,
            minLines: 7,
            maxLines: 12,
            readOnly: suggestionSubmitted,
            enabled: !suggestionSubmitted,
            style: const TextStyle(fontSize: 13, height: 1.45),
            decoration: InputDecoration(
              hintText: 'Enter your note/comment...',
              hintStyle: const TextStyle(color: Color(0xFF9A9EAA)),
              filled: true,
              fillColor: suggestionSubmitted
                  ? const Color(0xFFF0F1F4)
                  : const Color(0xFFFFF7FA),
              contentPadding: const EdgeInsets.all(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFFE2E5ED)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFFE2E5ED)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Growkids.pink),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 43,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Growkids.pink,
                side: BorderSide(
                  color: Growkids.pink.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: suggestionSubmitted ? null : _submitSuggestion,
              icon: Icon(
                suggestionSubmitted ? Icons.check_rounded : Icons.send_outlined,
                size: 17,
              ),
              label: Text(
                suggestionSubmitted ? 'Note Submitted' : 'Submit Note',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _desktopChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _desktopEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF777C8B), fontSize: 12),
      ),
    );
  }

  Future<void> _handleFinish() async {
    if (suggestionController.text.trim().isEmpty && !suggestionSubmitted) {
      await _showScoreDialog(
        title: 'Error',
        message: 'Please enter a suggestion before finishing the screening.',
        isError: true,
      );
      return;
    }

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _showScoreDialog({
    required String title,
    required String message,
    required bool isError,
  }) async {
    if (!_useDesktopScoreResultLayout(context)) {
      return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('OK'),
                ),
              ],
            ),
          ) ??
          false;
    }

    final color = isError ? const Color(0xFFDC3545) : const Color(0xFF16A34A);
    final icon =
        isError ? Icons.error_outline_rounded : Icons.check_circle_outline;

    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.55),
          builder: (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3D0E1635),
                      blurRadius: 34,
                      offset: Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF242735),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: color.withValues(alpha: 0.13),
                        ),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF555967),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 100,
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('OK'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  /// =======================
  /// Replace these 3 builders
  /// =======================

  Widget _buildDevelopmentCard(
      String title, double developmentalAge, int actualAge) {
    final bool ok = developmentalAge == actualAge.toDouble();
    final Color pillColor = ok ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(1.2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${developmentalAge.toStringAsFixed(0)} mo',
                    style: TextStyle(fontSize: 13.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            SfLinearGauge(
              interval: actualAge / 5,
              minimum: 0,
              maximum: actualAge.toDouble(),
              axisTrackStyle: LinearAxisTrackStyle(
                thickness: 1.h,
                color: Colors.black.withValues(alpha: 0.08),
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
              markerPointers: [
                LinearShapePointer(
                  value: developmentalAge,
                  height: 1.5.h,
                  width: 2.0.h,
                ),
              ],
              barPointers: [
                LinearBarPointer(
                  value: developmentalAge,
                  thickness: 1.h,
                  color: Growkids.purpleFlo,
                ),
              ],
              animationDuration: 1200,
            ),
            SizedBox(height: 0.6.h),
            Text(
              'Age in months',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailComponentSection() {
    if (domainData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(1.6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Text(
          'No fail components 🎉',
          style: TextStyle(fontSize: 12.sp, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: domainData.keys.map((domain) {
        final items = domainData[domain] ?? [];
        return Padding(
          padding: EdgeInsets.only(bottom: 1.2.h),
          child: _domainCard(
            domain: domain,
            tint: Growkids.purpleFlo,
            items: items,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoOppComponentSection() {
    if (noOppDomainData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(1.6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Text(
          'No "No Opportunity" components.',
          style: TextStyle(fontSize: 12.sp, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: noOppDomainData.keys.map((domain) {
        final items = noOppDomainData[domain] ?? [];
        return Padding(
          padding: EdgeInsets.only(bottom: 1.2.h),
          child: _domainCard(
            domain: domain,
            tint: Growkids.pink,
            items: items,
          ),
        );
      }).toList(),
    );
  }

  /// Domain container premium
  Widget _domainCard({
    required String domain,
    required Color tint,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1.4.h, vertical: 1.2.h),
            decoration: BoxDecoration(
              color: tint,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    domain,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 1.1.h, vertical: 0.55.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(1.2.h, 0.6.h, 1.2.h, 1.2.h),
            child: Column(
              children: items.map((m) => _componentTile(m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _componentTile(Map<String, dynamic> component) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 0.8.h),
      padding: EdgeInsets.all(1.2.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (component['component'] ?? '').toString(),
            style: TextStyle(fontSize: 13.sp),
          ),
          SizedBox(height: 0.6.h),
          Text(
            'Recommendation: ${(component['recommendation'] ?? '').toString()}',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
