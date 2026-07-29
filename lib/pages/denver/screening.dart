import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/denver/score.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopScreeningFormLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

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
        Uri.parse(ApiConfig.flutter('fetch_components_v2.php')),
        /*Uri.parse(
            'http://app-kizzu.test/growkids/flutter/fetch_components_v2.php'),*/
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
        throw Exception(
            'Failed to load questions (HTTP ${response.statusCode})');
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
      domainCompletedWithPasses[domain] =
          false; // Initialize domain as incomplete
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
          domainCompletedWithPasses[domain] =
              true; // Tandakan domain sebagai lengkap
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
        Uri.parse(ApiConfig.flutter('submit_result_data_v2.php')),

        /*Uri.parse(
            'http://app-kizzu.test/growkids/flutter/submit_result_data_v2.php'),*/
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'fail_components': failComponentsJson,
          'staff_id': id,
          'staff_name': name,
          'student_id': widget.studentId,
          'student_name': widget.studentName,
          'age': widget.ageInMonthsINT.toString(),
          'age_fine_motor':
              developmentAgeByDomain['Fine Motor']?.toString() ?? '',
          'age_gross_motor':
              developmentAgeByDomain['Gross Motor']?.toString() ?? '',
          'age_personal_social':
              developmentAgeByDomain['Personal Social']?.toString() ?? '',
          'age_language': developmentAgeByDomain['Language']?.toString() ?? '',
        },
      );

      final jsonResponse = json.decode(response.body);

      setState(() {
        isSubmitting = false;
      });

      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final confirmed = await _showSubmissionDialog(
          title: 'Success',
          message:
              jsonResponse['message'] ?? 'Data telah dihantar dengan berjaya!',
          isError: false,
        );
        if (!mounted || !confirmed) return;

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
          result: true,
        );
      } else {
        await _showSubmissionDialog(
          title: 'Error',
          message: jsonResponse['message'] ?? 'Gagal menghantar data.',
          isError: true,
        );
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      await _showSubmissionDialog(
        title: 'Error',
        message: 'An error occurred: $e',
        isError: true,
      );
    }
  }

  Future<void> _openDirectionSheet(
      String componentName, int directionId) async {
    // cache hit?
    Map<String, dynamic>? data = _directionCache[directionId];

    if (data == null) {
      try {
        final res = await http.post(
          Uri.parse(ApiConfig.flutter('fetch_direction.php')),
          /*Uri.parse(
              'http://app-kizzu.test/growkids/flutter/fetch_direction.php'),*/
          body: {'direction_id': directionId.toString()},
        );

        if (res.statusCode != 200) {
          _showSnack('Failed to load direction (HTTP ${res.statusCode})');
          return;
        }

        final decoded = json.decode(res.body);
        if (decoded is! Map || decoded['status'] != 'success') {
          _showSnack(
              decoded['message']?.toString() ?? 'Failed to load direction');
          return;
        }

        data = Map<String, dynamic>.from(decoded['data'] as Map);
        _directionCache[directionId] = data;
      } catch (e) {
        _showSnack('Error: $e');
        return;
      }
    }

    if (!mounted) return;

    final String description = (data['description'] ?? '').toString();
    final int hasImage = (data['hasImage'] ?? 0) as int; // already INT
    final String imgUrl = (data['img'] ?? '').toString();

    if (_useDesktopScreeningFormLayout(context)) {
      await _showDesktopDirectionDialog(
        componentName: componentName,
        description: description,
        hasImage: hasImage == 1,
        imageUrl: imgUrl,
      );
      return;
    }

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
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.h, vertical: 2.h),
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
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.black87,
                              height: 1.5),
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
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 40.h,
                                  child: const Center(
                                      child: CircularProgressIndicator()),
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
                                    style: TextStyle(
                                        fontSize: 11.sp, color: Colors.black54),
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
                              style: TextStyle(
                                  fontSize: 12.sp, color: Colors.black54),
                            ),
                          ),
                        SizedBox(height: 3.h),
                        SizedBox(
                          width: double.infinity,
                          height: 6.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Growkids.purple,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14.sp)),
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

  Future<bool> _showSubmissionDialog({
    required String title,
    required String message,
    required bool isError,
  }) async {
    if (!_useDesktopScreeningFormLayout(context)) {
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
                          tooltip: 'Close',
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
                        border:
                            Border.all(color: color.withValues(alpha: 0.13)),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text(
                            'OK',
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
        ) ??
        false;
  }

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
          Container(
            height: 6.h,
            width: 6.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.assignment_rounded,
                color: Growkids.purpleFlo, size: 22.sp),
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
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 1.h,
                  runSpacing: 1.h,
                  children: [
                    _pill('Step',
                        '${currentStep + 1} / ${domainQuestions.keys.length}'),
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
                color: Colors.white.withValues(alpha: 0.9),
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
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
        color: Growkids.purpleFlo.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.layers_rounded,
                color: Growkids.purpleFlo, size: 3.h),
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
                color: Growkids.purpleFlo.withValues(alpha: 0.15),
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
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
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
                  child: Text('Dir',
                      style: TextStyle(
                          fontSize: 12.sp, fontWeight: FontWeight.w900)),
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
          final selectedUI =
              selectedStored.isEmpty ? '' : uiLabel(selectedStored);

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
              border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
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
                        onChanged: (val) =>
                            updateSelection(domain, index, storeValue(val!)),
                      ),
                      RadioPill(
                        groupValue: selectedUI,
                        value: 'Fail',
                        onChanged: (val) =>
                            updateSelection(domain, index, storeValue(val!)),
                      ),
                      RadioPill(
                        groupValue: selectedUI,
                        value: 'N.O',
                        onChanged: (val) =>
                            updateSelection(domain, index, storeValue(val!)),
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
                      onPressed: canView
                          ? () => _openDirectionSheet(
                              q['component'].toString(), dirId)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        disabledBackgroundColor:
                            Colors.black.withValues(alpha: 0.12),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 1.2.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
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
            // Back
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
    final int step =
        hasDomains ? currentStep.clamp(0, domainKeys.length - 1) : 0;
    final String activeDomain = hasDomains ? domainKeys[step] : '';
    final List<Map<String, dynamic>> qs =
        hasDomains ? (domainQuestions[activeDomain] ?? []) : [];

    final bool isLastStep = hasDomains && step == domainKeys.length - 1;

    if (_useDesktopScreeningFormLayout(context)) {
      return _buildDesktop(
        domainKeys: domainKeys,
        step: step,
        activeDomain: activeDomain,
        questions: qs,
        isLastStep: isLastStep,
      );
    }

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
                            // ===== Progress + Step tabs (FIXED) =====
                            if (hasDomains) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (step + 1) / domainKeys.length,
                                  minHeight: 0.7.h,
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.06),
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
                                  separatorBuilder: (_, __) =>
                                      SizedBox(width: 0.9.h),
                                  itemBuilder: (context, i) {
                                    final bool selected = i == step;
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () =>
                                          setState(() => currentStep = i),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 1.4.h, vertical: 0.9.h),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Growkids.purpleFlo
                                              : Colors.black
                                                  .withValues(alpha: 0.04),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: selected
                                                ? Growkids.purpleFlo
                                                : Colors.black
                                                    .withValues(alpha: 0.10),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            domainKeys[i],
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              color: selected
                                                  ? Colors.white
                                                  : Colors.black87,
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
                              _domainHeader(activeDomain,
                                  developmentAgeByDomain[activeDomain]),
                              SizedBox(height: 1.2.h),
                            ],

                            if (!hasDomains)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'No domains found.',
                                    style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700),
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
                    onBack: step > 0
                        ? () => setState(() => currentStep = step - 1)
                        : null,
                    onNext: (!isLastStep)
                        ? () => setState(() => currentStep = step + 1)
                        : null,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDesktop({
    required List<String> domainKeys,
    required int step,
    required String activeDomain,
    required List<Map<String, dynamic>> questions,
    required bool isLastStep,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: const Text(
          'Denver Screening',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh questions',
            onPressed: isLoading ? null : fetchQuestions,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1500),
                  child: Column(
                    children: [
                      _desktopStudentHeader(domainKeys, step),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 270,
                              child: _desktopDomainNavigation(
                                domainKeys,
                                step,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: _desktopQuestionWorkspace(
                                domainKeys: domainKeys,
                                step: step,
                                activeDomain: activeDomain,
                                questions: questions,
                                isLastStep: isLastStep,
                              ),
                            ),
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

  Widget _desktopStudentHeader(List<String> domainKeys, int step) {
    final initial = widget.studentName.trim().isEmpty
        ? '?'
        : widget.studentName.trim().substring(0, 1).toUpperCase();
    final progress = domainKeys.isEmpty ? 0.0 : (step + 1) / domainKeys.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x253F2A91),
            blurRadius: 26,
            offset: Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Growkids.purple,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
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
          SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  domainKeys.isEmpty
                      ? 'No domains'
                      : 'Domain ${step + 1} of ${domainKeys.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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

  Widget _desktopDomainNavigation(List<String> domainKeys, int step) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screening domains',
            style: TextStyle(
              color: Color(0xFF242735),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select a domain to review its items.',
            style: TextStyle(color: Color(0xFF858A99), fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (domainKeys.isEmpty)
            const Expanded(
              child: Center(child: Text('No domains found.')),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: domainKeys.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final domain = domainKeys[index];
                  final selected = index == step;
                  final completed = domainCompletedWithPasses[domain] == true;
                  final answered = (domainQuestions[domain] ?? [])
                      .where((q) =>
                          (q['selectedOption'] ?? '').toString().isNotEmpty)
                      .length;
                  final total = (domainQuestions[domain] ?? []).length;

                  return Material(
                    color: selected
                        ? Growkids.purple.withValues(alpha: 0.09)
                        : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => setState(() => currentStep = index),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: selected
                                ? Growkids.purple.withValues(alpha: 0.22)
                                : const Color(0xFFE7E9F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: completed
                                    ? const Color(0xFF16A34A)
                                        .withValues(alpha: 0.10)
                                    : Growkids.purple.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                completed
                                    ? Icons.check_rounded
                                    : Icons.layers_outlined,
                                size: 17,
                                color: completed
                                    ? const Color(0xFF16A34A)
                                    : Growkids.purple,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    domain,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? Growkids.purple
                                          : const Color(0xFF3F4350),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$answered / $total answered',
                                    style: const TextStyle(
                                      color: Color(0xFF858A99),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopQuestionWorkspace({
    required List<String> domainKeys,
    required int step,
    required String activeDomain,
    required List<Map<String, dynamic>> questions,
    required bool isLastStep,
  }) {
    final devAge = developmentAgeByDomain[activeDomain];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE7E9F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Growkids.purple.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: Growkids.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeDomain.isEmpty ? 'No domain' : activeDomain,
                        style: const TextStyle(
                          color: Color(0xFF242735),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${questions.length} screening item${questions.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFF858A99),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (devAge != null)
                  _desktopBadge(
                    'Development age ${devAge.toStringAsFixed(0)} mo',
                    const Color(0xFF16A34A),
                  ),
              ],
            ),
          ),
          if (!isSubmissionValid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFFFF0F1),
              child: const Text(
                'Please complete all questions or achieve 3 consecutive passes in each domain.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: questions.isEmpty
                ? const Center(child: Text('No questions found.'))
                : _desktopQuestionList(activeDomain, questions),
          ),
          _desktopBottomActions(
            domainKeys: domainKeys,
            step: step,
            isLastStep: isLastStep,
          ),
        ],
      ),
    );
  }

  Widget _desktopQuestionList(
    String domain,
    List<Map<String, dynamic>> questions,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final question = questions[index];
        final selected = (question['selectedOption'] ?? '').toString().trim();
        final hasMaterial = question['hasMaterial'] is int
            ? question['hasMaterial'] as int
            : int.tryParse(question['hasMaterial']?.toString() ?? '') ?? 0;
        final directionId = question['directionId'] is int
            ? question['directionId'] as int
            : int.tryParse(question['directionId']?.toString() ?? '') ?? 0;
        final canView = hasMaterial == 1 && directionId > 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7E9F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFE2E5ED)),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF777C8B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (question['component'] ?? '').toString(),
                  style: const TextStyle(
                    color: Color(0xFF3F4350),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _desktopChoice(
                'Pass',
                selected == 'Pass',
                const Color(0xFF16A34A),
                () => updateSelection(domain, index, 'Pass'),
              ),
              const SizedBox(width: 7),
              _desktopChoice(
                'Fail',
                selected == 'Fail',
                const Color(0xFFDC3545),
                () => updateSelection(domain, index, 'Fail'),
              ),
              const SizedBox(width: 7),
              _desktopChoice(
                'N.O',
                selected == 'No Opportunity',
                const Color(0xFF3D7AF5),
                () => updateSelection(domain, index, 'No Opportunity'),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  tooltip: canView ? 'View direction' : 'No direction',
                  onPressed: canView
                      ? () => _openDirectionSheet(
                            question['component'].toString(),
                            directionId,
                          )
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: canView
                        ? Growkids.purple.withValues(alpha: 0.09)
                        : const Color(0xFFEDEEF2),
                    foregroundColor: Growkids.purple,
                    disabledForegroundColor: const Color(0xFFB5B8C1),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _desktopChoice(
    String label,
    bool selected,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? color : const Color(0xFFD9DCE4),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF656A78),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopBottomActions({
    required List<String> domainKeys,
    required int step,
    required bool isLastStep,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE7E9F0))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: step > 0
                  ? () => setState(() => currentStep = step - 1)
                  : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Back'),
            ),
          ),
          const Spacer(),
          Text(
            domainKeys.isEmpty
                ? 'No domain'
                : '${step + 1} of ${domainKeys.length}',
            style: const TextStyle(
              color: Color(0xFF858A99),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: isLastStep ? 130 : 110,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: isLastStep
                  ? (isSubmitting ? null : handleSubmitFailComponents)
                  : () => setState(() => currentStep = step + 1),
              icon: isSubmitting && isLastStep
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isLastStep
                          ? Icons.save_outlined
                          : Icons.arrow_forward_rounded,
                      size: 17,
                    ),
              label: Text(isLastStep ? 'Save' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
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

  Future<void> _showDesktopDirectionDialog({
    required String componentName,
    required String description,
    required bool hasImage,
    required String imageUrl,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3D0E1635),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Growkids.purple.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Growkids.purple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ASSESSMENT DIRECTION',
                            style: TextStyle(
                              color: Color(0xFF858A99),
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            componentName,
                            style: const TextStyle(
                              color: Color(0xFF242735),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 28, color: Color(0xFFE7E9F0)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description.isEmpty ? 'No description' : description,
                          style: const TextStyle(
                            color: Color(0xFF555967),
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (hasImage && imageUrl.isNotEmpty)
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              minHeight: 220,
                              maxHeight: 400,
                            ),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E5ED),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Center(
                                            child: CircularProgressIndicator(
                                              color: Growkids.purpleFlo,
                                            ),
                                          ),
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Failed to load image'),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6F9),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Text(
                              'No image for this direction.',
                              style: TextStyle(
                                color: Color(0xFF858A99),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 110,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
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
            color: selected
                ? Growkids.purpleFlo
                : Colors.black.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
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
                color: selected
                    ? Colors.white
                    : Colors.black.withValues(alpha: 0.06),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 1.h, color: Growkids.purpleFlo)
                  : const SizedBox.shrink(),
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
    super.key,
    required this.groupValue,
    required this.value,
    required this.onChanged,
  });

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
