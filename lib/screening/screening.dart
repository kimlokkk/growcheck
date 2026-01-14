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

  @override
  Widget build(BuildContext context) {
    final domainKeys = domainQuestions.keys.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Screening Questions'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
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
                        if (currentStep < domainKeys.length - 1) {
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
                      steps: domainKeys.map((domain) {
                        List<Map<String, dynamic>> questionsInDomain = domainQuestions[domain] ?? [];
                        return Step(
                          label: Text(
                            domain,
                            style: TextStyle(
                              fontSize: 14.sp,
                            ),
                          ),
                          title: const SizedBox.shrink(),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (developmentAgeByDomain.containsKey(domain) && developmentAgeByDomain[domain] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Text(
                                    'Development Age: ${developmentAgeByDomain[domain]} months',
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              if (!isSubmissionValid)
                                const Text(
                                  'Please complete all questions or achieve 3 consecutive passes in each domain.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
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
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(1.h),
                                            child: Text(
                                              'Pass',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(1.h),
                                            child: Text(
                                              'Fail',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(1.h),
                                            child: Text(
                                              'N.O',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(1.h),
                                            child: Text(
                                              'Direction',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                      ...questionsInDomain.asMap().entries.map((entry) {
                                        int index = entry.key;
                                        Map<String, dynamic> question = entry.value;

                                        return TableRow(
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.all(1.h),
                                              child: Text(
                                                question['component'],
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                ),
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
                                            Center(
                                              child: ElevatedButton(
                                                onPressed: (question['hasMaterial'] == '1' &&
                                                        question['directionId'] != null)
                                                    ? () {
                                                        final dirId = question['directionId'] is int
                                                            ? question['directionId'] as int
                                                            : int.tryParse(question['directionId'].toString()) ?? 0;
                                                        if (dirId > 0) {
                                                          _openDirectionSheet(question['component'].toString(), dirId);
                                                        } else {
                                                          _showSnack('Invalid direction id');
                                                        }
                                                      }
                                                    : null,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      question['hasMaterial'] == '1' ? Growkids.purple : Colors.grey,
                                                  minimumSize: Size(10.w, 2.5.h),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'View',
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                              ),
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
                          isActive: currentStep >= domainKeys.indexOf(domain),
                        );
                      }).toList(),
                      controlsBuilder: (BuildContext context, ControlsDetails details) {
                        final isLastStep = currentStep == domainKeys.length - 1;
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
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              SizedBox(
                                width: 2.w,
                              ),
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
                  if (currentStep == domainKeys.length - 1)
                    SizedBox(
                      height: 1.h,
                    ),
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
                      onPressed: isSubmitting ? null : handleSubmitFailComponents,
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
                          : Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.white,
                              ),
                            ),
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
