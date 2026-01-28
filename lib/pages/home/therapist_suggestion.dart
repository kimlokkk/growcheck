import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/pages/home/home_v2.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

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
  List<String> get stepLabels => const ['Suggestions', 'Recommendations', 'Interventions'];

  Future<void> fetchSuggestionData() async {
    final response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_suggestion.php'));

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
    final response =
        await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_recommendation.php'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      recommendationData = List<Map<String, dynamic>>.from(data);
      for (var r in recommendationData) {
        selectedRecommendations[r['id']] = selectedRecommendations[r['id']] ?? false;
      }
    } else {
      throw Exception('Failed to load recommendation data');
    }
  }

  Future<void> fetchInterventionPlan() async {
    final response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_intervention.php'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      interventionPlan = List<Map<String, dynamic>>.from(data);
      for (var p in interventionPlan) {
        selectedInterventions[p['id']] = selectedInterventions[p['id']] ?? false;
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
        .map((item) => {'id': item['id'], 'recommendation': item['recommendation']})
        .toList();

    List selectedInterventionsList = interventionPlan
        .where((item) => selectedInterventions[item['id']] == true)
        .map((item) => {'id': item['id'], 'title': item['title']})
        .toList();

    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/submit_suggestion.php'),
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

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      message = jsonResponse['message'] ?? "Data submitted successfully";
      title = "Submission Status";
    } else {
      message = "Submission failed";
      title = "Submission Error";
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeV2()));
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

  int _countSelected(Map<dynamic, bool> map) => map.values.where((v) => v == true).length;

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
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white.withOpacity(0.95),
            child: Text(
              widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : '?',
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
                    color: Colors.white.withOpacity(0.85),
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
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.refresh_rounded, size: 3.h, color: Growkids.purpleFlo),
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
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 12.sp, color: Growkids.purpleFlo, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _stepHeaderCard() {
    final accent = _stepAccent(currentStep);

    return Container(
      padding: EdgeInsets.all(1.8.h),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.18),
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
              color: accent.withOpacity(0.18),
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
                color: selected ? accent : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? accent : Colors.black.withOpacity(0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done) ...[
                    Icon(Icons.check_circle_rounded, size: 1.8.h, color: selected ? Colors.white : accent),
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
      separatorBuilder: (_, __) => Divider(height: 1.h, color: Colors.black.withOpacity(0.06)),
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
              border: Border.all(color: Colors.black.withOpacity(0.10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 0.12.h,
                  child: Checkbox(
                    value: checked,
                    activeColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onChanged: (v) => setState(() => selectedMap[id] = v ?? false),
                  ),
                ),
                SizedBox(width: 1.w),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.black.withOpacity(0.78),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 1.1.h, vertical: 0.55.h),
                  decoration: BoxDecoration(
                    color: checked ? accent : accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: checked ? accent : accent.withOpacity(0.18)),
                  ),
                  child: Text(
                    checked ? 'Picked' : 'Pick',
                    style: TextStyle(fontSize: 13.sp, color: checked ? Colors.white : accent),
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
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                  side: BorderSide(color: Colors.black.withOpacity(0.18), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.symmetric(vertical: 1.55.h),
                  elevation: 0,
                ),
                onPressed: isSubmitting ? null : (isLast ? submitAllData : onNext), // ✅ last step = submit
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Therapist Suggestion', style: TextStyle(color: Colors.white)),
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
                        border: Border.all(color: Colors.black.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
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
                              backgroundColor: Colors.black.withOpacity(0.06),
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
}
