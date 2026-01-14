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
  int currentStep = 0;
  bool isLoading = true;
  bool isSubmitting = false;

  // To store the development age for each domain
  Map<String, double?> developmentAgeByDomain = {};
  Map<String, bool> domainCompletedWithPasses = {};

  // Variable to hold the therapist suggestion (editable in the extra step)
  late String therapistSuggestion;

  @override
  void initState() {
    super.initState();
    therapistSuggestion = widget.therapist_suggestion;
    fetchQuestions();
  }

  // Fetch questions from API
  Future<void> fetchQuestions() async {
    try {
      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_components.php'),
        body: {"age": widget.age.toInt().toString()},
      );
      if (response.statusCode == 200) {
        List<dynamic> fetchedData = json.decode(response.body);
        setState(() {
          // Build the list of questions with pre-populated answers.
          questions = fetchedData.map((item) {
            // Default to "Pass"
            String selectedOption = "Pass";
            // If there is a record in failData for this question, take its 'score'
            for (var failItem in widget.failData) {
              if (failItem['q_id'].toString() == item['id'].toString()) {
                selectedOption = failItem['score'];
                break;
              }
            }
            return {
              'component': item['component'],
              'domain': item['domain'],
              'selectedOption': selectedOption,
              'recommendation': item['recommendation'],
              'minAge': item['minAge'],
              'pass75': double.tryParse(item['pass75'].toString()),
              'maxAge': item['maxAge'],
              'id': item['id'],
            };
          }).toList();
          groupQuestionsByDomain();
          // Update development age based on the pre-populated answers.
          for (var domain in domainQuestions.keys) {
            checkConsecutivePasses(domain);
          }
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        throw Exception('Failed to load questions');
      }
    } catch (e) {
      print('Error fetching questions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Group questions by domain
  void groupQuestionsByDomain() {
    domainQuestions.clear();
    domainCompletedWithPasses.clear();
    for (var question in questions) {
      String domain = question['domain'];
      if (domainQuestions.containsKey(domain)) {
        domainQuestions[domain]!.add(question);
      } else {
        domainQuestions[domain] = [question];
      }
      domainCompletedWithPasses[domain] = false;
    }
  }

  // Update the radio selection for a question and recalculate development age.
  void updateSelection(String domain, int questionIndex, String value) {
    setState(() {
      domainQuestions[domain]![questionIndex]['selectedOption'] = value;
    });
    checkConsecutivePasses(domain);
  }

  // Check for three consecutive "Pass" in a domain.
  // If all questions in the domain are passed, update the development age to the student's actual age.
  void checkConsecutivePasses(String domain) {
    List<Map<String, dynamic>> questionsInDomain = domainQuestions[domain]!;

    // If all questions in the domain are marked as "Pass", set development age to widget.age.
    bool allPassed = questionsInDomain.every((question) => question['selectedOption'] == 'Pass');
    if (allPassed) {
      setState(() {
        developmentAgeByDomain[domain] = widget.age;
        domainCompletedWithPasses[domain] = true;
      });
      return;
    }

    // Otherwise, check for three consecutive "Pass"
    int passCounter = 0;
    double? firstPassComponentAge;

    // If the first three questions are "Pass"
    if (questionsInDomain.length >= 3) {
      if (questionsInDomain[0]['selectedOption'] == 'Pass' &&
          questionsInDomain[1]['selectedOption'] == 'Pass' &&
          questionsInDomain[2]['selectedOption'] == 'Pass') {
        setState(() {
          developmentAgeByDomain[domain] = widget.age;
          domainCompletedWithPasses[domain] = true;
        });
        return;
      }
    }

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

  // Build the list of steps for the Stepper.
  List<Step> _buildSteps() {
    List<Step> steps = [];
    // Create steps for each domain.
    domainQuestions.forEach((domain, questionsList) {
      steps.add(
        Step(
          label: Text(domain, style: TextStyle(fontSize: 14.sp)),
          title: const SizedBox.shrink(),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (developmentAgeByDomain.containsKey(domain) && developmentAgeByDomain[domain] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Development Age: ${developmentAgeByDomain[domain]} months',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              Card(
                elevation: 10,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  padding: EdgeInsets.all(1.h),
                  child: Table(
                    border: const TableBorder.symmetric(
                      inside: BorderSide(width: 0.5),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(1.h),
                            child: Text(
                              'Item',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(1.h),
                            child: Text(
                              'Pass',
                              style: TextStyle(fontSize: 14.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(1.h),
                            child: Text(
                              'Fail',
                              style: TextStyle(fontSize: 14.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(1.h),
                            child: Text(
                              'N.O',
                              style: TextStyle(fontSize: 14.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      ...questionsList.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> question = entry.value;
                        return TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(1.h),
                              child: Text(
                                question['component'],
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                            RadioCell(
                              groupValue: question['selectedOption'],
                              value: 'Pass',
                              onChanged: (val) {
                                updateSelection(domain, index, val!);
                              },
                            ),
                            RadioCell(
                              groupValue: question['selectedOption'],
                              value: 'Fail',
                              onChanged: (val) {
                                updateSelection(domain, index, val!);
                              },
                            ),
                            RadioCell(
                              groupValue: question['selectedOption'],
                              value: 'No Opportunity',
                              onChanged: (val) {
                                updateSelection(domain, index, val!);
                              },
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          isActive: currentStep >= steps.length,
        ),
      );
    });
    // Add an extra step for therapist suggestion editing.
    steps.add(
      Step(
        label: Text("Therapist Suggestion", style: TextStyle(fontSize: 14.sp)),
        title: const SizedBox.shrink(),
        content: Container(
          padding: EdgeInsets.all(1.h),
          child: TextFormField(
            initialValue: therapistSuggestion,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Therapist Suggestion",
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              setState(() {
                therapistSuggestion = val;
              });
            },
          ),
        ),
        isActive: currentStep >= steps.length,
      ),
    );
    return steps;
  }

  // Update Screening without changing status.
  Future<void> handleUpdate() async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
    });
    List<Map<String, dynamic>> failComponents = [];
    // Gather questions that are not 'Pass'
    domainQuestions.forEach((domain, questionsList) {
      for (var question in questionsList) {
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
                      builder: (BuildContext context) => const Home(),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) => const Home(),
                    ),
                  );
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

  // Submit Screening: update status from 'Draft' to 'Submit'
  Future<void> handleFinalSubmit() async {
    if (isSubmitting) return;

    // Show confirmation dialog before submitting.
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text('Are you sure you want to submit the screening? Once submitted, it cannot be changed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isSubmitting = true;
    });
    List<Map<String, dynamic>> failComponents = [];
    // Gather questions that are not 'Pass'
    domainQuestions.forEach((domain, questionsList) {
      for (var question in questionsList) {
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
      // Include an extra parameter 'status' = 'Submit' to update the screening status.
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
          'status': 'Submit', // This will update the screening status in the backend
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) => const Home(),
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
    List<Step> steps = _buildSteps();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Edit Screening'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/bg-home.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Growkids.purple,
                    BlendMode.color,
                  ),
                ),
              ),
              padding: EdgeInsets.all(2.h),
              child: Column(
                children: [
                  Expanded(
                    child: Stepper(
                      connectorThickness: 0.3.h,
                      type: StepperType.horizontal,
                      currentStep: currentStep,
                      onStepTapped: (int step) {
                        setState(() {
                          currentStep = step;
                        });
                      },
                      onStepContinue: () {
                        if (currentStep < steps.length - 1) {
                          setState(() {
                            currentStep++;
                          });
                        }
                      },
                      onStepCancel: () {
                        if (currentStep > 0) {
                          setState(() {
                            currentStep--;
                          });
                        }
                      },
                      steps: steps,
                      controlsBuilder: (BuildContext context, ControlsDetails details) {
                        final isLastStep = currentStep == steps.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(top: 1.h),
                          child: Row(
                            children: [
                              if (currentStep > 0)
                                SizedBox(
                                  height: 5.h,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: GrowkidsPastel.purple2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 5,
                                    ),
                                    onPressed: details.onStepCancel,
                                    child: Text(
                                      'Back',
                                      style: TextStyle(fontSize: 14.sp),
                                    ),
                                  ),
                                ),
                              SizedBox(width: 2.w),
                              if (!isLastStep)
                                SizedBox(
                                  height: 5.h,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Growkids.purple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 5,
                                    ),
                                    onPressed: details.onStepContinue,
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
                          ),
                        );
                      },
                    ),
                  ),
                  if (currentStep == steps.length - 1) SizedBox(height: 1.h),
                  // Two buttons: one to update screening and one to submit screening.
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 5.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Growkids.purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                            onPressed: isSubmitting ? null : handleUpdate,
                            child: isSubmitting
                                ? SizedBox(
                                    width: 20.w,
                                    height: 3.h,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Update Screening',
                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                  ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                            onPressed: isSubmitting ? null : handleFinalSubmit,
                            child: isSubmitting
                                ? SizedBox(
                                    width: 20.w,
                                    height: 3.h,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Submit Screening',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
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
