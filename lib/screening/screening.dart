import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/screening/score.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

class Screening extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String age;
  final String ageInMonths;
  final int ageInMonthsINT;

  const Screening({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.age,
    required this.ageInMonths,
    required this.ageInMonthsINT,
  });

  @override
  State<Screening> createState() => _ScreeningState();
}

class _ScreeningState extends State<Screening> {
  List<Map<String, dynamic>> questions = [];
  Map<String, List<Map<String, dynamic>>> domainQuestions = {};
  int currentStep = 0; // Tracks the current step in the stepper
  bool isLoading = true;
  bool isSubmissionValid = true; // Track if the form is valid
  bool isSubmitting = false; // Track if submission is in progress

  // Track the development age for each domain (double for pass75)
  Map<String, double?> developmentAgeByDomain = {};

  // Track if each domain has 3 consecutive passes
  Map<String, bool> domainCompletedWithPasses = {};

  // Dalam _ScreeningState
  final Map<int, Map<String, dynamic>> _directionCache = {};

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    try {
      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_components_v2.php'),
        body: {
          "age": widget.ageInMonthsINT.toString(),
        },
      );

      if (response.statusCode == 200) {
        final fetchedData = json.decode(response.body);

        if (fetchedData is List) {
          setState(() {
            questions = fetchedData.map<Map<String, dynamic>>((item) {
              return {
                'component': item['component'],
                'domain': item['domain'],
                'selectedOption': '',
                'recommendation': item['recommendation'],
                'minAge': item['minAge'],
                'pass75': double.tryParse(item['pass75'].toString()),
                'maxAge': item['maxAge'],
                'id': item['id'],
                // ✅ hasMaterial memang int
                'hasMaterial': item['hasMaterial'] ?? 0,
                'directionId': item['direction_id'],
              };
            }).toList();

            groupQuestionsByDomain();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
          throw Exception('Invalid data format (not a list)');
        }
      } else {
        setState(() => isLoading = false);
        throw Exception('Failed to load questions (HTTP ${response.statusCode})');
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error fetching data: $e');
    }
  }

  void groupQuestionsByDomain() {
    for (var question in questions) {
      String domain = question['domain'];
      if (domainQuestions.containsKey(domain)) {
        domainQuestions[domain]!.add(question);
      } else {
        domainQuestions[domain] = [question];
      }
      domainCompletedWithPasses[domain] = false; // Initialize domain as incomplete
    }
  }

  // Update the selection of a particular question in a domain and check for 3 consecutive Pass
  void updateSelection(String domain, int questionIndex, String value) {
    setState(() {
      domainQuestions[domain]![questionIndex]['selectedOption'] = value;
    });

    // Check for 3 consecutive passes
    checkConsecutivePasses(domain);
  }

  // Check for 3 consecutive "Pass" selections in a domain
  void checkConsecutivePasses(String domain) {
    List<Map<String, dynamic>> questionsInDomain = domainQuestions[domain]!;
    int passCounter = 0;
    double? firstPassComponentAge;

    // Check if the first three components are all "Pass"
    if (questionsInDomain.length >= 3) {
      if (questionsInDomain[0]['selectedOption'] == 'Pass' &&
          questionsInDomain[1]['selectedOption'] == 'Pass' &&
          questionsInDomain[2]['selectedOption'] == 'Pass') {
        // Jika 3 pertama adalah Pass, tetapkan development age kepada umur sebenar pelajar
        setState(() {
          developmentAgeByDomain[domain] = widget.ageInMonthsINT.toDouble();
          domainCompletedWithPasses[domain] = true; // Tandakan domain sebagai lengkap
        });
        return;
      }
    }

    // Semak 3 kali Pass berturut-turut
    for (var question in questionsInDomain) {
      if (question['selectedOption'] == 'Pass') {
        passCounter++;
        if (passCounter == 1) {
          firstPassComponentAge = question['pass75'];
        }
        if (passCounter == 3) {
          setState(() {
            developmentAgeByDomain[domain] = firstPassComponentAge;
            domainCompletedWithPasses[domain] = true;
          });
          return;
        }
      } else {
        passCounter = 0;
        firstPassComponentAge = null;
      }
    }
  }

  Future<void> handleSubmitFailComponents() async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    List<Map<String, dynamic>> failComponents = [];

    for (var domain in domainQuestions.keys) {
      for (var q in domainQuestions[domain]!) {
        final sel = (q['selectedOption'] ?? '').toString();
        if (sel != 'Pass' && sel.isNotEmpty) {
          final score = (sel == 'No Opportunity') ? 'N.O' : sel; // normalize
          failComponents.add({
            'q_id': q['id'],
            'component': q['component'],
            'stud_id': widget.studentId,
            'stud_name': widget.studentName,
            'recommendation': q['recommendation'],
            'score': score, // 'Fail' atau 'N.O'
            'domain': q['domain'],
          });
        }
      }
    }

    try {
      // Tukar kepada JSON string
      String failComponentsJson = json.encode(failComponents);

      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/submit_result_data_v2.php'),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'fail_components': failComponentsJson,
          'staff_id': id,
          'staff_name': name,
          'student_id': widget.studentId,
          'student_name': widget.studentName,
          'age': widget.ageInMonthsINT.toString(),
          'age_fine_motor': developmentAgeByDomain['Fine Motor']?.toString() ?? '',
          'age_gross_motor': developmentAgeByDomain['Gross Motor']?.toString() ?? '',
          'age_personal_social': developmentAgeByDomain['Personal Social']?.toString() ?? '',
          'age_language': developmentAgeByDomain['Language']?.toString() ?? '',
        },
      );

      final jsonResponse = json.decode(response.body);

      setState(() {
        isSubmitting = false;
      });

      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Success'),
              content: Text(jsonResponse['message'] ?? 'Data telah dihantar dengan berjaya!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScoreResult(
                          studentId: widget.studentId,
                          age: widget.age,
                          ageInMonths: widget.ageInMonths,
                          ageInMonthsINT: widget.ageInMonthsINT,
                          studentName: widget.studentName,
                          ageFineMotor: developmentAgeByDomain['Fine Motor']!,
                          ageGrossMotor: developmentAgeByDomain['Gross Motor']!,
                          agePersonal: developmentAgeByDomain['Personal Social']!,
                          ageLanguage: developmentAgeByDomain['Language']!,
                        ),
                      ),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text(jsonResponse['message'] ?? 'Gagal menghantar data.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _openDirectionSheet(String componentName, int directionId) async {
    // cache hit?
    Map<String, dynamic>? data = _directionCache[directionId];

    if (data == null) {
      try {
        final res = await http.post(
          Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_direction.php'),
          body: {'direction_id': directionId.toString()},
        );

        if (res.statusCode != 200) {
          _showSnack('Failed to load direction (HTTP ${res.statusCode})');
          return;
        }

        final decoded = json.decode(res.body);
        if (decoded is! Map || decoded['status'] != 'success') {
          _showSnack(decoded['message']?.toString() ?? 'Failed to load direction');
          return;
        }

        data = Map<String, dynamic>.from(decoded['data'] as Map);
        _directionCache[directionId] = data!;
      } catch (e) {
        _showSnack('Error: $e');
        return;
      }
    }

    if (!mounted) return;

    final String description = (data!['description'] ?? '').toString();
    final int hasImage = (data['hasImage'] ?? 0) as int; // already INT
    final String imgUrl = (data['img'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // to show rounded corners nicely
      builder: (ctx) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 0.9, // 🔧 adjust width (0.8 ~ 1.0)
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.8, // tinggi mula (besar)
                minChildSize: 0.6,
                maxChildSize: 0.8,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 3.h, vertical: 2.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // handle bar
                        Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            margin: EdgeInsets.only(bottom: 1.5.h),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // 🔹 Header = component name
                        Text(
                          componentName,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Growkids.purple,
                          ),
                        ),
                        SizedBox(height: 1.5.h),
                        Text(
                          description.isEmpty ? 'No description' : description,
                          style: TextStyle(fontSize: 13.sp, color: Colors.black87, height: 1.5),
                        ),
                        SizedBox(height: 2.h),
                        if (hasImage == 1 && imgUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.contain,
                              height: 30.h, // gambar besar & jelas
                              width: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 40.h,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 20.h,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Failed to load image',
                                    style: TextStyle(fontSize: 11.sp, color: Colors.black54),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 1.h),
                            child: Text(
                              'No image for this direction.',
                              style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                            ),
                          ),
                        SizedBox(height: 3.h),
                        SizedBox(
                          width: double.infinity,
                          height: 6.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Growkids.purple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
          Container(
            height: 6.h,
            width: 6.h,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.assignment_rounded, color: Growkids.purpleFlo, size: 22.sp),
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
                SizedBox(height: 0.4.h),
                Text(
                  'ID: ${widget.studentId} • ${widget.age} • ${widget.ageInMonths}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 1.h,
                  runSpacing: 1.h,
                  children: [
                    _pill('Step', '${currentStep + 1} / ${domainQuestions.keys.length}'),
                    _pill('Age (mo)', widget.ageInMonthsINT.toString()),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: isLoading ? null : fetchQuestions,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.all(1.5.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
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
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12.sp,
          color: Growkids.purpleFlo,
        ),
      ),
    );
  }

  Widget _domainHeader(String domain, double? devAge) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.layers_rounded, color: Growkids.purpleFlo, size: 3.h),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(domain, style: TextStyle(fontSize: 14.sp)),
                Text(
                  '${(domainQuestions[domain] ?? []).length} items',
                  style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (devAge != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 0.9.h),
              decoration: BoxDecoration(
                color: Growkids.purpleFlo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Dev Age ${devAge.toStringAsFixed(0)} mo',
                style: TextStyle(fontSize: 12.sp, color: Growkids.purpleFlo),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerPill(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.sp),
      ),
    );
  }

  Widget _scrollingQuestionList(String domain, List<Map<String, dynamic>> qs) {
    String uiLabel(String v) => (v == 'No Opportunity') ? 'N.O' : v;
    String storeValue(String v) => (v == 'N.O') ? 'No Opportunity' : v;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // header row (fixed inside scroll area? ok sebab dia part list)
        Container(
          padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 1.h),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Text(
                  'Item',
                  style: TextStyle(
                    fontSize: 14.sp,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _headerPill('Pass'),
                    SizedBox(width: 2.w),
                    _headerPill('Fail'),
                    SizedBox(width: 2.w),
                    _headerPill('N.O'),
                  ],
                ),
              ),
              SizedBox(width: 1.0.h),
              SizedBox(
                width: 8.5.h,
                child: Align(
                  alignment: Alignment.center,
                  child: Text('Dir', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.h),

        ...qs.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;

          final selectedStored = (q['selectedOption'] ?? '').toString().trim();
          final selectedUI = selectedStored.isEmpty ? '' : uiLabel(selectedStored);

          final int hasMat = (q['hasMaterial'] is int)
              ? q['hasMaterial'] as int
              : int.tryParse(q['hasMaterial']?.toString() ?? '') ?? 0;

          final int dirId = (q['directionId'] is int)
              ? q['directionId'] as int
              : int.tryParse(q['directionId']?.toString() ?? '') ?? 0;

          final bool canView = hasMat == 1 && dirId > 0;

          return Container(
            margin: EdgeInsets.only(bottom: 1.h),
            padding: EdgeInsets.all(1.5.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Text(
                    (q['component'] ?? '').toString(),
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),

                Expanded(
                  flex: 4,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 0.8.h,
                    runSpacing: 0.8.h,
                    children: [
                      RadioPill(
                        groupValue: selectedUI,
                        value: 'Pass',
                        onChanged: (val) => updateSelection(domain, index, storeValue(val!)),
                      ),
                      RadioPill(
                        groupValue: selectedUI,
                        value: 'Fail',
                        onChanged: (val) => updateSelection(domain, index, storeValue(val!)),
                      ),
                      RadioPill(
                        groupValue: selectedUI,
                        value: 'N.O',
                        onChanged: (val) => updateSelection(domain, index, storeValue(val!)),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 1.0.h),

                // Direction button
                SizedBox(
                  width: 8.5.h,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: ElevatedButton(
                      onPressed: canView ? () => _openDirectionSheet(q['component'].toString(), dirId) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        disabledBackgroundColor: Colors.black.withOpacity(0.12),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 1.2.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                      ),
                      child: Text(
                        'View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _bottomActionBar({
    required List<String> domainKeys,
    required bool isLastStep,
    required VoidCallback? onBack,
    required VoidCallback? onNext,
  }) {
    if (domainKeys.isEmpty) return const SizedBox.shrink();

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
            // Back
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
                  style: TextStyle(fontSize: 14.sp),
                ),
              ),
            ),

            // Kalau bukan last step, show Next
            if (!isLastStep) ...[
              SizedBox(width: 1.2.h),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Growkids.purpleFlo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.symmetric(vertical: 1.55.h),
                    elevation: 0,
                  ),
                  onPressed: onNext,
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],

            // Kalau last step, show Save saja (tiada "Last step")
            if (isLastStep) ...[
              SizedBox(width: 1.2.h),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Growkids.purpleFlo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.symmetric(vertical: 1.55.h),
                    elevation: 0,
                  ),
                  onPressed: isSubmitting ? null : handleSubmitFailComponents,
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
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final domainKeys = domainQuestions.keys.toList();
    final bool hasDomains = domainKeys.isNotEmpty;

    // safety clamp
    final int step = hasDomains ? currentStep.clamp(0, domainKeys.length - 1) : 0;
    final String activeDomain = hasDomains ? domainKeys[step] : '';
    final List<Map<String, dynamic>> qs = hasDomains ? (domainQuestions[activeDomain] ?? []) : [];

    final bool isLastStep = hasDomains && step == domainKeys.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Screening',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // ===== Header student (FIXED) =====
                  Padding(
                    padding: EdgeInsets.fromLTRB(2.2.h, 1.6.h, 2.2.h, 1.2.h),
                    child: _premiumHeader(),
                  ),

                  // ===== Main white card =====
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
                            // ===== Progress + Step tabs (FIXED) =====
                            if (hasDomains) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (step + 1) / domainKeys.length,
                                  minHeight: 0.7.h,
                                  backgroundColor: Colors.black.withOpacity(0.06),
                                  color: Growkids.purpleFlo,
                                ),
                              ),
                              SizedBox(height: 1.2.h),

                              // step tabs ala "stepper" (fixed)
                              SizedBox(
                                height: 4.5.h,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: domainKeys.length,
                                  separatorBuilder: (_, __) => SizedBox(width: 0.9.h),
                                  itemBuilder: (context, i) {
                                    final bool selected = i == step;
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () => setState(() => currentStep = i),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        padding: EdgeInsets.symmetric(horizontal: 1.4.h, vertical: 0.9.h),
                                        decoration: BoxDecoration(
                                          color: selected ? Growkids.purpleFlo : Colors.black.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: selected ? Growkids.purpleFlo : Colors.black.withOpacity(0.10),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            domainKeys[i],
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              color: selected ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 1.2.h),

                              // ===== Domain header (FIXED) =====
                              _domainHeader(activeDomain, developmentAgeByDomain[activeDomain]),
                              SizedBox(height: 1.2.h),
                            ],

                            if (!hasDomains)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'No domains found.',
                                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              )
                            else ...[
                              if (!isSubmissionValid)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 1.h),
                                  child: Text(
                                    'Please complete all questions or achieve 3 consecutive passes in each domain.',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),

                              // ===== ONLY THIS PART SCROLLS =====
                              Expanded(
                                child: _scrollingQuestionList(activeDomain, qs),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== Bottom action bar (FIXED) =====
                  _bottomActionBar(
                    domainKeys: domainKeys,
                    isLastStep: isLastStep,
                    onBack: step > 0 ? () => setState(() => currentStep = step - 1) : null,
                    onNext: (!isLastStep) ? () => setState(() => currentStep = step + 1) : null,
                  ),
                ],
              ),
            ),
    );
  }
}

class RadioPill extends StatelessWidget {
  final String groupValue;
  final String value;
  final ValueChanged<String?> onChanged;

  const RadioPill({
    super.key,
    required this.groupValue,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = groupValue == value;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.55.h),
        decoration: BoxDecoration(
          color: selected ? Growkids.purpleFlo : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Growkids.purpleFlo : Colors.black.withOpacity(0.18),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 1.45.h,
              width: 1.45.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : Colors.black.withOpacity(0.06),
                border: Border.all(
                  color: selected ? Colors.white : Colors.black.withOpacity(0.25),
                  width: 1.0,
                ),
              ),
              child: selected ? Icon(Icons.check, size: 1.h, color: Growkids.purpleFlo) : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadioCell extends StatelessWidget {
  final String groupValue;
  final String value;
  final ValueChanged<String?> onChanged;

  const RadioCell({
    Key? key,
    required this.groupValue,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
      ),
    );
  }
}
