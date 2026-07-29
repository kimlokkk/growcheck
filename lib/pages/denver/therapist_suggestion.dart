import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopSuggestionLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class TherapistSuggestion extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age;
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;

  const TherapistSuggestion({
    super.key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
  });

  @override
  State<TherapistSuggestion> createState() => _TherapistSuggestionState();
}

class _TherapistSuggestionState extends State<TherapistSuggestion> {
  List<Map<String, dynamic>> suggestionData = [];
  List<Map<String, dynamic>> recommendationData = [];
  List<Map<String, dynamic>> interventionPlan = [];
  bool isLoading = true;
  bool isSubmitting = false;

  // Track checkbox status
  Map<dynamic, bool> selectedSuggestions = {};
  Map<dynamic, bool> selectedRecommendations = {};
  Map<dynamic, bool> selectedInterventions = {};

  // Stepper style macam Screening
  int currentStep = 0;

  // 0=Suggestions, 1=Recommendations, 2=Interventions
  List<String> get stepLabels =>
      const ['Suggestions', 'Recommendations', 'Interventions'];

  Future<void> fetchSuggestionData() async {
    final response =
        await http.post(Uri.parse(ApiConfig.flutter('fetch_suggestion.php')));
    /*final response = await http.post(Uri.parse(
        'http://app-kizzu.test/growkids/flutter/fetch_suggestion.php'));*/

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      suggestionData = List<Map<String, dynamic>>.from(data);
      for (var s in suggestionData) {
        selectedSuggestions[s['id']] = selectedSuggestions[s['id']] ?? false;
      }
    } else {
      throw Exception('Failed to load suggestion data');
    }
  }

  Future<void> fetchRecommendationData() async {
    final response = await http
        .post(Uri.parse(ApiConfig.flutter('fetch_recommendation.php')));
    /*await http.post(Uri.parse(
            'http://app-kizzu.test/growkids/flutter/fetch_recommendation.php'));*/

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      recommendationData = List<Map<String, dynamic>>.from(data);
      for (var r in recommendationData) {
        selectedRecommendations[r['id']] =
            selectedRecommendations[r['id']] ?? false;
      }
    } else {
      throw Exception('Failed to load recommendation data');
    }
  }

  Future<void> fetchInterventionPlan() async {
    final response =
        await http.post(Uri.parse(ApiConfig.flutter('fetch_intervention.php')));
    /*final response = await http.post(Uri.parse(
        'http://app-kizzu.test/growkids/flutter/fetch_intervention.php'));*/

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      interventionPlan = List<Map<String, dynamic>>.from(data);
      for (var p in interventionPlan) {
        selectedInterventions[p['id']] =
            selectedInterventions[p['id']] ?? false;
      }
    } else {
      throw Exception('Failed to load intervention plan');
    }
  }

  // Submit all data (kekal logic kau)
  Future<void> submitAllData() async {
    if (isSubmitting) return;

    setState(() => isSubmitting = true);

    List selectedSuggestionsList = suggestionData
        .where((item) => selectedSuggestions[item['id']] == true)
        .map((item) => {'id': item['id'], 'suggestion': item['suggestion']})
        .toList();

    List selectedRecommendationsList = recommendationData
        .where((item) => selectedRecommendations[item['id']] == true)
        .map((item) =>
            {'id': item['id'], 'recommendation': item['recommendation']})
        .toList();

    List selectedInterventionsList = interventionPlan
        .where((item) => selectedInterventions[item['id']] == true)
        .map((item) => {'id': item['id'], 'title': item['title']})
        .toList();

    final response = await http.post(
      Uri.parse(ApiConfig.flutter('submit_suggestion.php')),
      /*Uri.parse('http://app-kizzu.test/growkids/flutter/submit_suggestion.php'),*/
      body: {
        'studentId': widget.studentId,
        'screeningId': widget.screeningId,
        'selectedSuggestions': json.encode(selectedSuggestionsList),
        'selectedRecommendations': json.encode(selectedRecommendationsList),
        'selectedInterventions': json.encode(selectedInterventionsList),
      },
    );

    setState(() => isSubmitting = false);

    String message = "";
    String title = "";

    final didSubmit = response.statusCode == 200;

    if (didSubmit) {
      var jsonResponse = json.decode(response.body);
      message = jsonResponse['message'] ?? "Data submitted successfully";
      title = "Submission Status";
    } else {
      message = "Submission failed";
      title = "Submission Error";
    }

    final pageContext = context;
    showDialog(
      context: pageContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (didSubmit && Navigator.of(pageContext).canPop()) {
                  Navigator.of(pageContext).pop(true);
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        fetchSuggestionData(),
        fetchRecommendationData(),
        fetchInterventionPlan(),
      ]);
    } catch (_) {
      // ignore for now
    }
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  // ======================
  // Helpers
  // ======================

  int _countSelected(Map<dynamic, bool> map) =>
      map.values.where((v) => v == true).length;

  int get sugCount => _countSelected(selectedSuggestions);
  int get recCount => _countSelected(selectedRecommendations);
  int get intCount => _countSelected(selectedInterventions);

  bool get isLastStep => currentStep == stepLabels.length - 1;

  void _goBack() {
    if (currentStep > 0) setState(() => currentStep--);
  }

  void _goNext() {
    if (!isLastStep) setState(() => currentStep++);
  }

  Color _stepAccent(int step) {
    if (step == 0) return Growkids.purpleFlo;
    if (step == 1) return Growkids.pink;
    return const Color(0xFF0AAE7A);
  }

  String _stepSubtitle(int step) {
    if (step == 0) return 'Pick therapist notes for the report';
    if (step == 1) return 'Choose recommended next actions';
    return 'Choose intervention plan titles';
  }

  int _activeSelectedCount() {
    if (currentStep == 0) return sugCount;
    if (currentStep == 1) return recCount;
    return intCount;
  }

  // ======================
  // UI blocks (ikut Screening style)
  // ======================

  Widget _premiumHeader() {
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
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            child: Text(
              widget.studentName.isNotEmpty
                  ? widget.studentName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 18.sp,
                color: Growkids.purpleFlo,
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
                    fontSize: 16.sp,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'ID: ${widget.studentId} • Age: ${widget.age.toStringAsFixed(0)} mo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 1.h,
                  runSpacing: 1.h,
                  children: [
                    _pill('Step', '${currentStep + 1} / ${stepLabels.length}'),
                    _pill('Selected', '${sugCount + recCount + intCount}'),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: isLoading ? null : _loadAll,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.all(1.5.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.refresh_rounded,
                  size: 3.h, color: Growkids.purpleFlo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.2.h, vertical: 0.65.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
            fontSize: 12.sp,
            color: Growkids.purpleFlo,
            fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _stepHeaderCard() {
    final accent = _stepAccent(currentStep);

    return Container(
      padding: EdgeInsets.all(1.8.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.layers_rounded, color: accent, size: 3.h),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stepLabels[currentStep],
                    style: TextStyle(
                      fontSize: 14.sp,
                    )),
                SizedBox(height: 0.3.h),
                Text(
                  _stepSubtitle(currentStep),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 0.9.h),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_activeSelectedCount()} selected',
              style: TextStyle(
                fontSize: 14.sp,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTabs() {
    return SizedBox(
      height: 4.5.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stepLabels.length,
        separatorBuilder: (_, __) => SizedBox(width: 0.9.h),
        itemBuilder: (context, i) {
          final bool selected = i == currentStep;
          final accent = _stepAccent(i);

          // complete state (optional): kalau ada selection, mark “complete”
          final int c = (i == 0)
              ? sugCount
              : (i == 1)
                  ? recCount
                  : intCount;
          final bool done = c > 0;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => currentStep = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 1.4.h),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color:
                      selected ? accent : Colors.black.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done) ...[
                    Icon(Icons.check_circle_rounded,
                        size: 1.8.h, color: selected ? Colors.white : accent),
                    SizedBox(width: 0.6.h),
                  ],
                  Text(
                    stepLabels[i],
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _scrollingChecklist() {
    // Decide data based on step
    List<Map<String, dynamic>> items;
    Map<dynamic, bool> selectedMap;
    String labelKey;

    if (currentStep == 0) {
      items = suggestionData;
      selectedMap = selectedSuggestions;
      labelKey = 'suggestion';
    } else if (currentStep == 1) {
      items = recommendationData;
      selectedMap = selectedRecommendations;
      labelKey = 'recommendation';
    } else {
      items = interventionPlan;
      selectedMap = selectedInterventions;
      labelKey = 'title';
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No items found.',
          style: TextStyle(
            fontSize: 14.sp,
          ),
        ),
      );
    }

    final accent = _stepAccent(currentStep);

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1.h, color: Colors.black.withValues(alpha: 0.06)),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['id'];
        final label = (item[labelKey] ?? '').toString();
        final checked = selectedMap[id] ?? false;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => selectedMap[id] = !checked),
          child: Container(
            padding: EdgeInsets.all(1.2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 0.12.h,
                  child: Checkbox(
                    value: checked,
                    activeColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    onChanged: (v) =>
                        setState(() => selectedMap[id] = v ?? false),
                  ),
                ),
                SizedBox(width: 1.w),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.black.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 1.1.h, vertical: 0.55.h),
                  decoration: BoxDecoration(
                    color: checked ? accent : accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color:
                            checked ? accent : accent.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    checked ? 'Picked' : 'Pick',
                    style: TextStyle(
                        fontSize: 13.sp,
                        color: checked ? Colors.white : accent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomActionBar({
    required bool isLast,
    required VoidCallback? onBack,
    required VoidCallback? onNext,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(2.2.h, 1.2.h, 2.2.h, 2.0.h),
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(
                      color: Colors.black.withValues(alpha: 0.18), width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.symmetric(vertical: 1.55.h),
                ),
                onPressed: onBack,
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            SizedBox(width: 1.2.h),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Growkids.purpleFlo,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.symmetric(vertical: 1.55.h),
                  elevation: 0,
                ),
                onPressed: isSubmitting
                    ? null
                    : (isLast ? submitAllData : onNext), // ✅ last step = submit
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isLast ? 'Submit' : 'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================
  // Build
  // ======================

  @override
  Widget build(BuildContext context) {
    final bool isLast = isLastStep;

    if (_useDesktopSuggestionLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Therapist Suggestion',
            style: TextStyle(color: Colors.white)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header student fixed
                Padding(
                  padding: EdgeInsets.fromLTRB(2.2.h, 1.6.h, 2.2.h, 1.2.h),
                  child: _premiumHeader(),
                ),

                // Main card
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2.2.h),
                    child: Container(
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
                          // Progress
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: (currentStep + 1) / stepLabels.length,
                              minHeight: 0.7.h,
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.06),
                              color: Growkids.purpleFlo,
                            ),
                          ),
                          SizedBox(height: 1.2.h),

                          // Tabs
                          _stepTabs(),
                          SizedBox(height: 1.2.h),

                          // Step header card
                          _stepHeaderCard(),
                          SizedBox(height: 1.2.h),

                          // ONLY this scrolls
                          Expanded(child: _scrollingChecklist()),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom action bar fixed
                _bottomActionBar(
                  isLast: isLast,
                  onBack: currentStep > 0 ? _goBack : null,
                  onNext: !isLast ? _goNext : null,
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Suggestion & Plan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
                  child: Column(
                    children: [
                      _desktopStudentHeader(),
                      const SizedBox(height: 22),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 300, child: _desktopStepPanel()),
                            const SizedBox(width: 20),
                            Expanded(child: _desktopChecklistPanel()),
                            const SizedBox(width: 20),
                            SizedBox(width: 290, child: _desktopSummaryPanel()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopStudentHeader() {
    final totalSelected = sugCount + recCount + intCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              widget.studentName.isEmpty
                  ? '?'
                  : widget.studentName[0].toUpperCase(),
              style: const TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THERAPIST CARE PLAN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Student ID ${widget.studentId}  •  ${widget.age.toStringAsFixed(0)} months  •  Screening ${widget.screeningId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _desktopHeaderMetric(
            Icons.checklist_rounded,
            totalSelected.toString(),
            'Selected',
          ),
          const SizedBox(width: 12),
          _desktopHeaderMetric(
            Icons.view_week_outlined,
            '${currentStep + 1}/3',
            'Section',
          ),
        ],
      ),
    );
  }

  Widget _desktopHeaderMetric(IconData icon, String value, String label) {
    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopStepPanel() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan sections',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Complete each section of the care plan.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 12),
          ),
          const SizedBox(height: 20),
          ...List.generate(stepLabels.length, (index) {
            final selected = currentStep == index;
            final accent = _stepAccent(index);
            final count = index == 0
                ? sugCount
                : index == 1
                    ? recCount
                    : intCount;
            final icons = [
              Icons.chat_bubble_outline_rounded,
              Icons.lightbulb_outline_rounded,
              Icons.assignment_outlined,
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => currentStep = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.10)
                        : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.45)
                          : const Color(0xFFE5E7EE),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected
                              ? accent
                              : accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          icons[index],
                          color: selected ? Colors.white : accent,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stepLabels[index],
                              style: const TextStyle(
                                color: Color(0xFF30323C),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count selected',
                              style: TextStyle(
                                color: count > 0
                                    ? accent
                                    : const Color(0xFF858A98),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        count > 0
                            ? Icons.check_circle_rounded
                            : Icons.chevron_right_rounded,
                        color: count > 0 ? accent : const Color(0xFF9CA0AC),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / stepLabels.length,
              minHeight: 7,
              backgroundColor: const Color(0xFFE9EAF0),
              color: Growkids.purpleFlo,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Section ${currentStep + 1} of ${stepLabels.length}',
            style: const TextStyle(
              color: Color(0xFF777C8D),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopChecklistPanel() {
    List<Map<String, dynamic>> items;
    Map<dynamic, bool> selectedMap;
    String labelKey;
    if (currentStep == 0) {
      items = suggestionData;
      selectedMap = selectedSuggestions;
      labelKey = 'suggestion';
    } else if (currentStep == 1) {
      items = recommendationData;
      selectedMap = selectedRecommendations;
      labelKey = 'recommendation';
    } else {
      items = interventionPlan;
      selectedMap = selectedInterventions;
      labelKey = 'title';
    }
    final accent = _stepAccent(currentStep);

    return _desktopSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.layers_rounded, color: accent),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stepLabels[currentStep],
                        style: const TextStyle(
                          color: Color(0xFF242631),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _stepSubtitle(currentStep),
                        style: const TextStyle(
                          color: Color(0xFF777C8D),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_activeSelectedCount()} selected',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EAF0)),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No items found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = item['id'];
                      final label = (item[labelKey] ?? '').toString();
                      final checked = selectedMap[itemId] ?? false;

                      return InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => setState(
                          () => selectedMap[itemId] = !checked,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: checked
                                ? accent.withValues(alpha: 0.065)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: checked
                                  ? accent.withValues(alpha: 0.42)
                                  : const Color(0xFFE3E5EC),
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: checked ? accent : Colors.white,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: checked
                                        ? accent
                                        : const Color(0xFFC8CBD4),
                                  ),
                                ),
                                child: checked
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 17,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Color(0xFF3C3F49),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                checked ? 'Selected' : 'Select',
                                style: TextStyle(
                                  color: checked
                                      ? accent
                                      : const Color(0xFF8A8E9A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8EAF0))),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: currentStep > 0 ? _goBack : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
                const Spacer(),
                if (!isLastStep)
                  ElevatedButton.icon(
                    onPressed: _goNext,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Next section'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Growkids.purpleFlo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSummaryPanel() {
    return Column(
      children: [
        Expanded(
          child: _desktopSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plan summary',
                  style: TextStyle(
                    color: Color(0xFF242631),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review your selections before submitting.',
                  style: TextStyle(color: Color(0xFF777C8D), fontSize: 11),
                ),
                const SizedBox(height: 20),
                _desktopSummaryRow(
                  'Suggestions',
                  sugCount,
                  Growkids.purpleFlo,
                ),
                _desktopSummaryRow(
                  'Recommendations',
                  recCount,
                  Growkids.pink,
                ),
                _desktopSummaryRow(
                  'Interventions',
                  intCount,
                  const Color(0xFF0AAE7A),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFE5E7EE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF687083),
                        size: 18,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Selections will be attached to this screening report.',
                          style: TextStyle(
                            color: Color(0xFF687083),
                            fontSize: 10,
                            height: 1.4,
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
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isSubmitting ? null : submitAllData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isSubmitting
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              'Submit plan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopSummaryRow(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF424550),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E6ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
