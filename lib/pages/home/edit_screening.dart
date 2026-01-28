import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/pages/home/home_v2.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

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
    String _normScore(dynamic raw) {
      final s = (raw ?? '').toString().trim().toLowerCase();
      if (s == 'fail' || s == 'f') return 'Fail';
      if (s == 'n.o' || s == 'no opportunity' || s == 'no_opportunity' || s == 'no-opportunity') return 'N.O';
      if (s == 'pass' || s == 'p') return 'Pass';
      return 'Pass';
    }

    try {
      final res = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_components.php'),
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
            selected = _normScore(nonPassByQid[qid]?['score']);
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
            'pass75': _toDouble(item['pass75']), // guna helper kau yang sedia ada
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
            border: Border.all(color: Colors.black.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(vertical: 1.2.h, horizontal: 1.6.h),
            childrenPadding: EdgeInsets.fromLTRB(1.6.h, 0, 1.6.h, 1.6.h),
            collapsedIconColor: Colors.black87,
            iconColor: Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  height: 5.h,
                  width: 5.h,
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withOpacity(0.15),
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
                    padding: EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: Growkids.purpleFlo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Dev Age ${devAge.toStringAsFixed(0)} mo',
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
                    border: Border.all(color: Colors.black.withOpacity(0.10)),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            RadioCell(
                              groupValue: question['selectedOption'],
                              value: 'Pass',
                              onChanged: (val) => updateSelection(domain, index, val!),
                            ),
                            SizedBox(width: 0.8.h),
                            RadioCell(
                              groupValue: question['selectedOption'],
                              value: 'Fail',
                              onChanged: (val) => updateSelection(domain, index, val!),
                            ),
                            SizedBox(width: 0.8.h),
                            RadioCell(
                              groupValue: question['selectedOption'],
                              value: 'N.O',
                              onChanged: (val) => updateSelection(domain, index, val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
        border: Border.all(color: Colors.black.withOpacity(0.12)),
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
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notes_rounded, color: Colors.black87, size: 18.sp),
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
              hintStyle: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
              filled: true,
              fillColor: Colors.black.withOpacity(0.04),
              contentPadding: EdgeInsets.symmetric(horizontal: 1.6.h, vertical: 1.4.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Growkids.purpleFlo.withOpacity(0.60), width: 1.4),
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
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/update_screening_data.php'),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'screening_id': widget.screeningId,
          'fail_components': failComponentsJson,
          'staff_id': id, // Ensure 'id' and 'name' are declared in profile_declaration.dart
          'staff_name': name,
          'student_id': widget.studentId,
          'student_name': widget.studentName,
          'age': widget.age.toInt().toString(),
          'age_fine_motor': developmentAgeByDomain['Fine Motor']?.toString() ?? '',
          'age_gross_motor': developmentAgeByDomain['Gross Motor']?.toString() ?? '',
          'age_personal_social': developmentAgeByDomain['Personal Social']?.toString() ?? '',
          'age_language': developmentAgeByDomain['Language']?.toString() ?? '',
          'therapist_suggestion': therapistSuggestion,
        },
      );
      final jsonResponse = json.decode(response.body);
      setState(() {
        isSubmitting = false;
      });
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Screening has been updated.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeV2(),
                    ),
                  );
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
            content: Text(jsonResponse['message'] ?? 'Failed to update screening.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeV2()));
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
        content: const Text('Are you sure you want to submit the screening? Once submitted, it cannot be changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
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
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/submit_screening_data.php'),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'screening_id': widget.screeningId,
          'fail_components': failComponentsJson,
          'staff_id': id,
          'staff_name': name,
          'student_id': widget.studentId,
          'student_name': widget.studentName,
          'age': widget.age.toInt().toString(),
          'age_fine_motor': developmentAgeByDomain['Fine Motor']?.toString() ?? '',
          'age_gross_motor': developmentAgeByDomain['Gross Motor']?.toString() ?? '',
          'age_personal_social': developmentAgeByDomain['Personal Social']?.toString() ?? '',
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Screening has been submitted.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeV2()));
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
            content: Text(jsonResponse['message'] ?? 'Failed to submit screening.'),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
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
                            color: Colors.black.withOpacity(0.10),
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
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.edit_note_rounded, color: Colors.white, size: 22.sp),
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
                                    color: Colors.white.withOpacity(0.85),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: isSubmitting ? null : handleUpdate,
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 22.w,
                                      height: 3.h,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                                side: BorderSide(color: Colors.black.withOpacity(0.18), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: Colors.white,
                              ),
                              onPressed: isSubmitting ? null : handleFinalSubmit,
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
    final bool selected = groupValue == value;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
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
              height: 1.5.h,
              width: 1.5.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : Colors.black.withOpacity(0.06),
                border: Border.all(
                  color: selected ? Colors.white : Colors.black.withOpacity(0.25),
                  width: 0.1.h,
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
