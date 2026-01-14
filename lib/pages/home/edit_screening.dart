import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
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
    List<Widget> tiles = [];
    domainQuestions.forEach((domain, qs) {
      tiles.add(
        Container(
          margin: EdgeInsets.symmetric(vertical: 1.h),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.h),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                15,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                15,
              ),
            ),
            backgroundColor: Colors.white,
            collapsedBackgroundColor: GrowkidsPastel.purple2,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  domain,
                  style: TextStyle(
                    fontSize: 16.sp,
                  ),
                ),
                if (developmentAgeByDomain[domain] != null)
                  Text(
                    'Dev Age: ${developmentAgeByDomain[domain]} Months',
                    style: TextStyle(fontSize: 14.sp, color: Growkids.purple),
                  ),
              ],
            ),
            children: [
              // Table header for the domain questions
              Container(
                color: GrowkidsPastel.purple2,
                padding: EdgeInsets.symmetric(vertical: 1.h),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(
                      children: [
                        Text('Item',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        Text('Pass',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        Text('Fail',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        Text('N.O',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ],
                ),
              ),
              // Table rows for each question
              Container(
                padding: EdgeInsets.all(1.h),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                  },
                  children: qs.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> question = entry.value;
                    return TableRow(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(1.h),
                          child: Text(question['component'], style: TextStyle(fontSize: 14.sp)),
                        ),
                        RadioCell(
                          groupValue: question['selectedOption'],
                          value: 'Pass',
                          onChanged: (val) => updateSelection(domain, index, val!),
                        ),
                        RadioCell(
                          groupValue: question['selectedOption'],
                          value: 'Fail',
                          onChanged: (val) => updateSelection(domain, index, val!),
                        ),
                        RadioCell(
                          groupValue: question['selectedOption'],
                          value: 'N.O',
                          onChanged: (val) => updateSelection(domain, index, val!),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    });
    return tiles;
  }

  // Build a card for therapist suggestion.
  Widget _buildSuggestionTile() {
    return Column(
      children: [
        SizedBox(
          height: 2.h,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Growkids.pink,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            padding: EdgeInsets.all(1.h),
            child: Text(
              'Therapist Note',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(2.h),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: TextFormField(
            initialValue: therapistSuggestion,
            maxLines: 3,
            decoration: const InputDecoration(
              filled: true,
              fillColor: GrowkidsPastel.pink,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Growkids.pink,
                  width: 2,
                ),
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
              ),
              labelText: 'Enter your note/comment',
              labelStyle: TextStyle(
                color: Growkids.pink,
              ),
            ),
            onChanged: (val) {
              setState(() {
                therapistSuggestion = val;
              });
            },
          ),
        ),
      ],
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
                      builder: (context) => const Home(),
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const Home()));
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const Home()));
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Edit Screening'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              height: 100.h,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/bg-home.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Growkids.purple, BlendMode.color),
                ),
              ),
              padding: EdgeInsets.all(2.h),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ..._buildDomainTiles(),
                    _buildSuggestionTile(),
                    SizedBox(height: 2.h),
                    // Two buttons: Update and Submit
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 5.h,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Growkids.purple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 5,
                              ),
                              onPressed: isSubmitting ? null : handleUpdate,
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 3.h,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                      ),
                                    )
                                  : const Text('Update Screening', style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: SizedBox(
                            height: 5.h,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Growkids.pink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 5,
                              ),
                              onPressed: isSubmitting ? null : handleFinalSubmit,
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 3.h,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                      ),
                                    )
                                  : const Text('Submit Screening', style: TextStyle(fontSize: 16, color: Colors.white)),
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
    return Center(
      child: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
      ),
    );
  }
}
