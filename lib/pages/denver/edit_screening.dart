import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopEditScreeningLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class EditScreening extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age; // Student's age in months
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;
  final String therapist_suggestion;
  final List<Map<String, dynamic>> failData;
  // failData contains the list of components that are not 'Pass'

  const EditScreening({
    super.key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.agePersonal,
    required this.ageLanguage,
    required this.therapist_suggestion,
    required this.failData,
  });

  @override
  State<EditScreening> createState() => _EditScreeningState();
}

class _EditScreeningState extends State<EditScreening> {
  List<Map<String, dynamic>> questions = [];
  Map<String, List<Map<String, dynamic>>> domainQuestions = {};
  bool isLoading = true;
  bool isSubmitting = false;
  String? _desktopSelectedDomain;

  // To store the dynamic development age for each domain.
  Map<String, double?> developmentAgeByDomain = {};

  // Variable to hold the therapist suggestion (editable)
  late String therapistSuggestion;

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return double.tryParse(s);
  }

  @override
  void initState() {
    super.initState();
    therapistSuggestion = widget.therapist_suggestion;
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    // helper normalize skor DB -> label radio
    String normScore(dynamic raw) {
      final s = (raw ?? '').toString().trim().toLowerCase();
      if (s == 'fail' || s == 'f') return 'Fail';
      if (s == 'n.o' ||
          s == 'no opportunity' ||
          s == 'no_opportunity' ||
          s == 'no-opportunity') {
        return 'N.O';
      }
      if (s == 'pass' || s == 'p') return 'Pass';
      return 'Pass';
    }

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.flutter('fetch_components.php')),
        /*Uri.parse(
            'http://app-kizzu.test/growkids/flutter/fetch_components.php'),*/
        body: {"age": widget.age.toInt().toString()},
      );

      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() => isLoading = false);
        throw Exception('Failed to load questions');
      }

      final List<dynamic> fetched = json.decode(res.body);

      // Map cepat: q_id -> rekod non-pass (boleh Fail atau N.O)
      final Map<String, Map<String, dynamic>> nonPassByQid = {
        for (final it in widget.failData) (it['q_id']).toString(): it
      };

      if (!mounted) return;
      setState(() {
        questions = fetched.map<Map<String, dynamic>>((item) {
          final qid = item['id'].toString();

          // default
          String selected = 'Pass';

          // prefill ikut apa yg tersimpan (Fail / N.O / Pass)
          if (nonPassByQid.containsKey(qid)) {
            selected = normScore(nonPassByQid[qid]?['score']);
          }

          // debug trace
          // debugPrint('[PREFILL] qid=$qid -> $selected');

          return {
            'id': item['id'],
            'component': item['component'],
            'domain': (item['domain'] ?? '').toString().trim(),
            'selectedOption': selected, // 'Pass' | 'Fail' | 'N.O'
            'recommendation': item['recommendation'],
            'minAge': item['minAge'],
            'pass75':
                _toDouble(item['pass75']), // guna helper kau yang sedia ada
            'maxAge': item['maxAge'],
          };
        }).toList();

        // build struktur ikut domain & kira dev age
        groupQuestionsByDomain();
        developmentAgeByDomain.clear();
        for (final d in domainQuestions.keys) {
          checkConsecutivePasses(d);
        }

        isLoading = false;
      });
    } catch (e) {
      // debugPrint('Error fetching questions: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void groupQuestionsByDomain() {
    domainQuestions.clear();
    for (var question in questions) {
      String domain = question['domain'];
      domainQuestions.putIfAbsent(domain, () => []).add(question);
    }
  }

  // Update selection for a given question and recalc development age.
  void updateSelection(String domain, int index, String value) {
    setState(() {
      domainQuestions[domain]![index]['selectedOption'] = value;
    });
    checkConsecutivePasses(domain);
  }

  // Calculate dynamic development age:
  // If all questions in a domain are "Pass", set age to student's actual age.
  // Otherwise, check for three consecutive "Pass" responses.
  void checkConsecutivePasses(String domain) {
    List<Map<String, dynamic>> qs = domainQuestions[domain]!;
    bool allPassed = qs.every((q) => q['selectedOption'] == 'Pass');
    if (allPassed) {
      setState(() {
        developmentAgeByDomain[domain] = widget.age;
      });
      return;
    }
    int passCounter = 0;
    double? firstPassAge;
    // If first three questions are "Pass", then set age to student's actual age.
    if (qs.length >= 3 &&
        qs[0]['selectedOption'] == 'Pass' &&
        qs[1]['selectedOption'] == 'Pass' &&
        qs[2]['selectedOption'] == 'Pass') {
      setState(() {
        developmentAgeByDomain[domain] = widget.age;
      });
      return;
    }
    for (var q in qs) {
      if (q['selectedOption'] == 'Pass') {
        passCounter++;
        if (passCounter == 1) {
          firstPassAge = q['pass75'];
        }
        if (passCounter == 3) {
          setState(() {
            developmentAgeByDomain[domain] = firstPassAge;
          });
          return;
        }
      } else {
        passCounter = 0;
        firstPassAge = null;
      }
    }
  }

  // Build a list of ExpansionTiles for each domain.
  List<Widget> _buildDomainTiles() {
    final tiles = <Widget>[];

    domainQuestions.forEach((domain, qs) {
      final devAge = developmentAgeByDomain[domain];

      tiles.add(
        Container(
          margin: EdgeInsets.only(bottom: 1.2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding:
                EdgeInsets.symmetric(vertical: 1.2.h, horizontal: 1.6.h),
            childrenPadding: EdgeInsets.fromLTRB(1.6.h, 0, 1.6.h, 1.6.h),
            collapsedIconColor: Colors.black87,
            iconColor: Colors.black87,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            collapsedShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  height: 5.h,
                  width: 5.h,
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.layers_rounded,
                    color: Growkids.purpleFlo,
                    size: 3.h,
                  ),
                ),
                SizedBox(width: 1.2.h),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain,
                        style: TextStyle(
                          fontSize: 14.sp,
                        ),
                      ),
                      Text(
                        '${qs.length} items',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (devAge != null)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: Growkids.purpleFlo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Dev Age ${devAge.toStringAsFixed(1)} mo',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Growkids.purpleFlo,
                      ),
                    ),
                  ),
              ],
            ),
            children: [
              // Header row
              Container(
                padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 1.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
                  ],
                ),
              ),

              SizedBox(height: 1.h),

              // Rows
              ...qs.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;

                return Container(
                  margin: EdgeInsets.only(bottom: 1.h),
                  padding: EdgeInsets.all(1.5.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Text(
                          (question['component'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioCell(
                                  groupValue: question['selectedOption'],
                                  value: 'Pass',
                                  onChanged: (val) =>
                                      updateSelection(domain, index, val!),
                                ),
                                const SizedBox(width: 4),
                                RadioCell(
                                  groupValue: question['selectedOption'],
                                  value: 'Fail',
                                  onChanged: (val) =>
                                      updateSelection(domain, index, val!),
                                ),
                                const SizedBox(width: 4),
                                RadioCell(
                                  groupValue: question['selectedOption'],
                                  value: 'N.O',
                                  onChanged: (val) =>
                                      updateSelection(domain, index, val!),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });

    return tiles;
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
        style: TextStyle(
          fontSize: 12.sp,
        ),
      ),
    );
  }

  // Build a card for therapist suggestion.
  Widget _buildSuggestionTile() {
    return Container(
      margin: EdgeInsets.only(top: 0.8.h),
      padding: EdgeInsets.all(1.8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 4.2.h,
                width: 4.2.h,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notes_rounded,
                    color: Colors.black87, size: 18.sp),
              ),
              SizedBox(width: 1.2.h),
              Expanded(
                child: Text(
                  'Therapist Note',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          TextFormField(
            initialValue: therapistSuggestion,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter your note/comment…',
              hintStyle: const TextStyle(
                  color: Colors.black45, fontWeight: FontWeight.w600),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.04),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 1.6.h, vertical: 1.4.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: Growkids.purpleFlo.withValues(alpha: 0.60),
                    width: 1.4),
              ),
            ),
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black87,
            ),
            onChanged: (val) {
              setState(() {
                therapistSuggestion = val;
              });
            },
          ),
        ],
      ),
    );
  }

  // API call to update screening (without changing status)
  Future<void> handleUpdate() async {
    if (isSubmitting) return;
    // Recalculate development ages for each domain.
    domainQuestions.forEach((domain, _) => checkConsecutivePasses(domain));
    setState(() {
      isSubmitting = true;
    });
    List<Map<String, dynamic>> failComponents = [];
    domainQuestions.forEach((domain, qs) {
      for (var question in qs) {
        if (question['selectedOption'] != 'Pass') {
          failComponents.add({
            'q_id': question['id'],
            'component': question['component'],
            'stud_id': widget.studentId,
            'stud_name': widget.studentName,
            'recommendation': question['recommendation'],
            'score': question['selectedOption'],
            'domain': question['domain'],
          });
        }
      }
    });
    try {
      String failComponentsJson = json.encode(failComponents);
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('update_screening_data.php')),
        /*Uri.parse(
            'http://app-kizzu.test/growkids/flutter/update_screening_data.php'),*/
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'screening_id': widget.screeningId,
          'fail_components': failComponentsJson,
          'staff_id':
              id, // Ensure 'id' and 'name' are declared in profile_declaration.dart
          'staff_name': name,
          'student_id': widget.studentId,
          'student_name': widget.studentName,
          'age': widget.age.toInt().toString(),
          'age_fine_motor':
              developmentAgeByDomain['Fine Motor']?.toString() ?? '',
          'age_gross_motor':
              developmentAgeByDomain['Gross Motor']?.toString() ?? '',
          'age_personal_social':
              developmentAgeByDomain['Personal Social']?.toString() ?? '',
          'age_language': developmentAgeByDomain['Language']?.toString() ?? '',
          'therapist_suggestion': therapistSuggestion,
        },
      );
      final jsonResponse = json.decode(response.body);
      setState(() {
        isSubmitting = false;
      });
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final pageContext = context;
        showDialog(
          context: pageContext,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Screening has been updated.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (Navigator.of(pageContext).canPop()) {
                    Navigator.of(pageContext).pop(true);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Error'),
            content:
                Text(jsonResponse['message'] ?? 'Failed to update screening.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('An error occurred: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // API call to submit screening (updates status to 'Submit')
  Future<void> handleFinalSubmit() async {
    if (isSubmitting) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text(
            'Are you sure you want to submit the screening? Once submitted, it cannot be changed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (confirm != true) return;
    domainQuestions.forEach((domain, _) => checkConsecutivePasses(domain));
    setState(() {
      isSubmitting = true;
    });
    List<Map<String, dynamic>> failComponents = [];
    domainQuestions.forEach((domain, qs) {
      for (var question in qs) {
        if (question['selectedOption'] != 'Pass') {
          failComponents.add({
            'q_id': question['id'],
            'component': question['component'],
            'stud_id': widget.studentId,
            'stud_name': widget.studentName,
            'recommendation': question['recommendation'],
            'score': question['selectedOption'],
            'domain': question['domain'],
          });
        }
      }
    });
    try {
      String failComponentsJson = json.encode(failComponents);
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('submit_screening_data.php')),

        /*Uri.parse(
            'http://app-kizzu.test/growkids/flutter/submit_screening_data.php'),*/
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'screening_id': widget.screeningId,
          'fail_components': failComponentsJson,
          'staff_id': id,
          'staff_name': name,
          'student_id': widget.studentId,
          'student_name': widget.studentName,
          'age': widget.age.toInt().toString(),
          'age_fine_motor':
              developmentAgeByDomain['Fine Motor']?.toString() ?? '',
          'age_gross_motor':
              developmentAgeByDomain['Gross Motor']?.toString() ?? '',
          'age_personal_social':
              developmentAgeByDomain['Personal Social']?.toString() ?? '',
          'age_language': developmentAgeByDomain['Language']?.toString() ?? '',
          'therapist_suggestion': therapistSuggestion,
          'status': 'Submit', // Update screening status
        },
      );
      final jsonResponse = json.decode(response.body);
      setState(() {
        isSubmitting = false;
      });
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final pageContext = context;
        showDialog(
          context: pageContext,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Screening has been submitted.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (Navigator.of(pageContext).canPop()) {
                    Navigator.of(pageContext).pop(true);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content:
                Text(jsonResponse['message'] ?? 'Failed to submit screening.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('An error occurred: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_useDesktopEditScreeningLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Edit Screening',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(2.2.h, 1.6.h, 2.2.h, 2.2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student card - PURPLE FLO
                    Container(
                      padding: EdgeInsets.all(1.8.h),
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
                            height: 5.2.h,
                            width: 5.2.h,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.edit_note_rounded,
                                color: Colors.white, size: 22.sp),
                          ),
                          SizedBox(width: 1.6.h),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.studentName,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 0.4.h),
                                Text(
                                  'Screening ID: ${widget.screeningId} • Age: ${widget.age.toInt()} months',
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 1.6.h),

                    ..._buildDomainTiles(),

                    _buildSuggestionTile(),

                    SizedBox(height: 1.8.h),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 5.2.h,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Growkids.purpleFlo,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: isSubmitting ? null : handleUpdate,
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 22.w,
                                      height: 3.h,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Update',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(width: 1.2.h),
                        Expanded(
                          child: SizedBox(
                            height: 5.2.h,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: BorderSide(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                backgroundColor: Colors.white,
                              ),
                              onPressed:
                                  isSubmitting ? null : handleFinalSubmit,
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 22.w,
                                      height: 3.h,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDesktopPage() {
    final domains = domainQuestions.keys.toList();
    if (_desktopSelectedDomain == null ||
        !domainQuestions.containsKey(_desktopSelectedDomain)) {
      _desktopSelectedDomain = domains.isEmpty ? null : domains.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Edit Screening',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
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
                            SizedBox(
                              width: 310,
                              child: _desktopDomainSidebar(domains),
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: _desktopScreeningWorkspace()),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 330,
                              child: _desktopNoteAndActions(),
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

  Widget _desktopStudentHeader() {
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Growkids.purpleFlo,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DENVER SCREENING',
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
                Wrap(
                  spacing: 18,
                  children: [
                    _desktopHeaderMeta(
                      Icons.badge_outlined,
                      'ID ${widget.screeningId}',
                    ),
                    _desktopHeaderMeta(
                      Icons.cake_outlined,
                      '${widget.age.toInt()} months',
                    ),
                    _desktopHeaderMeta(
                      Icons.fact_check_outlined,
                      '${questions.length} assessment items',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'Editing draft',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
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
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _desktopDomainSidebar(List<String> domains) {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screening domains',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select a domain to review its items.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 12),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: domains.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final domain = domains[index];
                final qs = domainQuestions[domain] ?? [];
                final selected = domain == _desktopSelectedDomain;
                final answered =
                    qs.where((q) => q['selectedOption'] != null).length;
                final devAge = developmentAgeByDomain[domain];

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _desktopSelectedDomain = domain),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? Growkids.purpleFlo.withValues(alpha: 0.10)
                          : const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? Growkids.purpleFlo.withValues(alpha: 0.45)
                            : const Color(0xFFE5E7EE),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected
                                ? Growkids.purpleFlo
                                : Growkids.purpleFlo.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.layers_rounded,
                            color: selected ? Colors.white : Growkids.purpleFlo,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                domain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF292B35),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$answered / ${qs.length} items  •  ${devAge?.toStringAsFixed(0) ?? '—'} mo',
                                style: const TextStyle(
                                  color: Color(0xFF7C8190),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: selected
                              ? Growkids.purpleFlo
                              : const Color(0xFF9CA0AC),
                        ),
                      ],
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

  Widget _desktopScreeningWorkspace() {
    final domain = _desktopSelectedDomain;
    final qs = domain == null
        ? <Map<String, dynamic>>[]
        : domainQuestions[domain] ?? <Map<String, dynamic>>[];
    final devAge = domain == null ? null : developmentAgeByDomain[domain];

    return _desktopSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 17),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain ?? 'Screening items',
                        style: const TextStyle(
                          color: Color(0xFF242631),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${qs.length} items to review',
                        style: const TextStyle(
                          color: Color(0xFF7C8190),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Development age  ${devAge?.toStringAsFixed(0) ?? '—'} mo',
                    style: const TextStyle(
                      color: Growkids.purpleFlo,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EAF0)),
          Container(
            color: const Color(0xFFF8F9FC),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'ASSESSMENT ITEM',
                    style: TextStyle(
                      color: Color(0xFF858A98),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                SizedBox(
                  width: 270,
                  child: Text(
                    'SCORE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF858A98),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: qs.isEmpty
                ? const Center(child: Text('No screening items available.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: qs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final question = qs[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFFE5E7EE)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (question['component'] ?? '').toString(),
                                style: const TextStyle(
                                  color: Color(0xFF343640),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 270,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _desktopScoreChoice(
                                    groupValue:
                                        question['selectedOption'].toString(),
                                    value: 'Pass',
                                    color: const Color(0xFF16A34A),
                                    onTap: () =>
                                        updateSelection(domain!, index, 'Pass'),
                                  ),
                                  const SizedBox(width: 7),
                                  _desktopScoreChoice(
                                    groupValue:
                                        question['selectedOption'].toString(),
                                    value: 'Fail',
                                    color: const Color(0xFFDC3545),
                                    onTap: () =>
                                        updateSelection(domain!, index, 'Fail'),
                                  ),
                                  const SizedBox(width: 7),
                                  _desktopScoreChoice(
                                    groupValue:
                                        question['selectedOption'].toString(),
                                    value: 'N.O',
                                    color: const Color(0xFF3478F6),
                                    onTap: () =>
                                        updateSelection(domain!, index, 'N.O'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopScoreChoice({
    required String groupValue,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    final selected = groupValue == value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? color : const Color(0xFFD9DCE5),
          ),
        ),
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF656A78),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _desktopNoteAndActions() {
    return Column(
      children: [
        Expanded(
          child: _desktopSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEF4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFFF4F87),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Therapist Note',
                        style: TextStyle(
                          color: Color(0xFF292B35),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Update the clinical note before saving.',
                  style: TextStyle(color: Color(0xFF7C8190), fontSize: 11),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('desktop-therapist-note'),
                    initialValue: therapistSuggestion,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    onChanged: (value) => therapistSuggestion = value,
                    decoration: InputDecoration(
                      hintText: 'Enter your note/comment...',
                      filled: true,
                      fillColor: const Color(0xFFFFF8FA),
                      contentPadding: const EdgeInsets.all(15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Color(0xFFF0DDE4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Color(0xFFF0DDE4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF4F87),
                          width: 1.4,
                        ),
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF444752),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: isSubmitting ? null : handleUpdate,
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
                : const Icon(Icons.save_outlined, size: 19),
            label: const Text(
              'Save changes',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: isSubmitting ? null : handleFinalSubmit,
            style: OutlinedButton.styleFrom(
              foregroundColor: Growkids.purpleFlo,
              side: const BorderSide(color: Growkids.purpleFlo),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.task_alt_rounded, size: 19),
            label: const Text(
              'Submit screening',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
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
    final bool selected = groupValue == value;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 0.8.h, vertical: 0.5.h),
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
              height: 1.5.h,
              width: 1.5.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.white
                    : Colors.black.withValues(alpha: 0.06),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.25),
                  width: 0.1.h,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 1.h, color: Growkids.purpleFlo)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 4),
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
