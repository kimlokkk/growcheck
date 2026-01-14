import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/pages/home/edit_screening.dart';
import 'package:growcheck_app_v2/pages/home/profile_student.dart';
import 'package:growcheck_app_v2/pages/home/result_pdf.dart';
import 'package:growcheck_app_v2/pages/home/screening_details.dart';
import 'package:growcheck_app_v2/pages/home/screening_result.dart';
import 'package:growcheck_app_v2/pages/home/sensory_profile_result.dart';
import 'package:growcheck_app_v2/pages/home/sensory_profile_result_2.dart';
import 'package:growcheck_app_v2/pages/home/therapist_suggestion.dart';
import 'package:growcheck_app_v2/pages/home/view_suggestion.dart';
import 'package:growcheck_app_v2/screening/screening.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StudentMainDashboard extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String age;
  final String ageInMonths;
  final int ageInMonthsINT;

  const StudentMainDashboard({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.age,
    required this.ageInMonths,
    required this.ageInMonthsINT,
  });

  @override
  State<StudentMainDashboard> createState() => _StudentMainDashboardState();
}

class _StudentMainDashboardState extends State<StudentMainDashboard> {
  Map<String, dynamic> screeningData = {};
  Map<String, dynamic> screeningDetails = {};
  Map<String, dynamic> suggestionData = {};
  Map<String, dynamic> sensoryData = {};
  List<Map<String, dynamic>> failData = [];
  bool isLoading = false; // For loading indicator

  @override
  void initState() {
    super.initState();
    fetchScreeningData();
    fetchScreeningDetails();
    checkSuggestionData();
    checkSensoryResult();
  }

  Future<void> fetchScreeningData() async {
    setState(() {
      isLoading = true; // Start loading
    });
    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/check_screening_data.php'),
      body: {'stud_id': widget.studentId},
    );

    if (response.statusCode == 200) {
      final data2 = jsonDecode(response.body);
      setState(() {
        screeningData = data2.isNotEmpty ? data2[0] : {};
        fetchFailData();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchScreeningDetails() async {
    setState(() {
      isLoading = true; // Start loading
    });
    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/check_screening_details.php'),
      body: {'stud_id': widget.studentId},
    );

    if (response.statusCode == 200) {
      final data2 = jsonDecode(response.body);
      setState(() {
        screeningDetails = data2.isNotEmpty ? data2[0] : {};
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchFailData() async {
    // Ensure screening_id exists before fetching fail data
    if (screeningData.isNotEmpty && screeningData['screening_id'] != null) {
      final response = await http.post(
        Uri.parse('http://app.kizzukids.com.my/growkids/flutter/screening_result.php'),
        body: {
          "stud_id": widget.studentId,
          "screening_id": screeningData['screening_id'],
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          failData = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        throw Exception('Failed to load data');
      }
    }
  }

  Future<void> checkSuggestionData() async {
    setState(() {
      isLoading = true; // Start loading
    });
    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/check_suggestion_data.php'),
      body: {'studentId': widget.studentId},
    );

    if (response.statusCode == 200) {
      final data2 = jsonDecode(response.body);
      setState(() {
        suggestionData = data2.isNotEmpty ? data2[0] : {};
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> checkSensoryResult() async {
    setState(() {
      isLoading = true; // Start loading
    });
    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/check_sensory_status.php'),
      body: {'studentId': widget.studentId},
    );

    if (response.statusCode == 200) {
      final data2 = jsonDecode(response.body);
      setState(() {
        sensoryData = data2.isNotEmpty ? data2[0] : {};
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  // -------- Helpers --------
  double _safeParseDouble(dynamic v) => v == null ? 0 : (double.tryParse(v.toString()) ?? 0);

  int _ageInMonthsFromSensoryOrWidget() {
    // Prefer explicit months from sensoryData if provided
    final dynamic aim = sensoryData['age_in_months'];
    if (aim != null) {
      final parsed = int.tryParse(aim.toString());
      if (parsed != null) return parsed;
    }
    // Fallback: convert years to months if 'age' exists
    final double years = _safeParseDouble(sensoryData['age']);
    if (years > 0) return (years * 12).round();
    // Final fallback: widget value
    return widget.ageInMonthsINT;
  }

  @override
  Widget build(BuildContext context) {
    // Define variables for the Therapist Suggestion card based on screeningData and suggestionData.
    String draftTitle;
    String draftDescription;
    IconData draftIcon;
    VoidCallback? draftOnTap;
    String therapistSuggestionDescription;
    VoidCallback? therapistSuggestionOnTap;

    bool screeningDone = screeningData.isNotEmpty && screeningData['status'] != null;
    bool suggestionDone = suggestionData.isNotEmpty;

    if (!screeningDone) {
      // Condition 1: Screening not done.
      therapistSuggestionDescription = "Screening not done";
      therapistSuggestionOnTap = null;
    } else if (screeningDone && !suggestionDone) {
      // Condition 2: Screening done but no suggestion.
      therapistSuggestionDescription = "No suggestion yet, add suggestion";
      therapistSuggestionOnTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TherapistSuggestion(
              studentId: screeningData['student_id'],
              screeningId: screeningData['screening_id'],
              studentName: screeningData['student'],
              age: _safeParseDouble(screeningData['age']),
              ageFineMotor: _safeParseDouble(screeningData['age_fine_motor']),
              ageGrossMotor: _safeParseDouble(screeningData['age_gross_motor']),
              ageLanguage: _safeParseDouble(screeningData['age_language']),
              agePersonal: _safeParseDouble(screeningData['age_personal_social']),
            ),
          ),
        );
      };
    } else {
      // Condition 3: Screening done and suggestion exists.
      therapistSuggestionDescription = "View suggestion";
      therapistSuggestionOnTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewSuggestion(
              studentId: screeningData['student_id'],
              screeningId: screeningData['screening_id'],
              studentName: screeningData['student'],
              age: _safeParseDouble(screeningData['age']),
              ageFineMotor: _safeParseDouble(screeningData['age_fine_motor']),
              ageGrossMotor: _safeParseDouble(screeningData['age_gross_motor']),
              ageLanguage: _safeParseDouble(screeningData['age_language']),
              agePersonal: _safeParseDouble(screeningData['age_personal_social']),
            ),
          ),
        );
      };
    }

    // Define variables for screening draft card.
    if (screeningData.isEmpty || screeningData['status'] == null) {
      draftTitle = "Start Screening";
      draftDescription = "Begin your screening now";
      draftIcon = Icons.play_circle_filled;
      draftOnTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Screening(
              studentId: widget.studentId,
              age: widget.age,
              ageInMonths: widget.ageInMonths,
              ageInMonthsINT: widget.ageInMonthsINT,
              studentName: widget.studentName,
            ),
          ),
        );
      };
    } else if (screeningData['status'] == 'Draft') {
      draftTitle = "Edit & Submit Screening";
      draftDescription = "Update your draft screening";
      draftIcon = Icons.edit;
      draftOnTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => EditScreening(
              studentId: screeningData['student_id'],
              screeningId: screeningData['screening_id'],
              age: _safeParseDouble(screeningData['age']),
              studentName: screeningData['student'],
              ageFineMotor: _safeParseDouble(screeningData['age_fine_motor']),
              ageGrossMotor: _safeParseDouble(screeningData['age_gross_motor']),
              ageLanguage: _safeParseDouble(screeningData['age_language']),
              agePersonal: _safeParseDouble(screeningData['age_personal_social']),
              therapist_suggestion: screeningData['therapist_suggestion'],
              failData: failData,
            ),
          ),
        );
      };
    } else if (screeningData['status'] == 'Submit') {
      draftTitle = "Screening Confirmed";
      draftDescription = "Screening has been confirmed";
      draftIcon = Icons.check_circle;
      draftOnTap = null;
    } else {
      draftTitle = "No Screening";
      draftDescription = "No screening available";
      draftIcon = Icons.block;
      draftOnTap = null;
    }

    // Sensory card readiness (view-only; no start assessment)
    final bool sensoryReady = sensoryData.isNotEmpty && sensoryData['assessment_id'] != null;
    final int ageInMonths = _ageInMonthsFromSensoryOrWidget();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Student Dashboard",
          style: TextStyle(color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
        backgroundColor: Growkids.purple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              padding: EdgeInsets.all(2.h),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/bg-home.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Growkids.purple, BlendMode.color),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with student information
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 2.h),
                      decoration: BoxDecoration(
                        color: Growkids.purple.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 4.h,
                            backgroundColor: Colors.white,
                            child: Text(
                              widget.studentName.substring(0, 1),
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Growkids.purple,
                              ),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            widget.studentName,
                            style: TextStyle(fontSize: 18.sp, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            "${widget.age} (${widget.ageInMonths})",
                            style: TextStyle(fontSize: 16.sp, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 2.h),
                    // Grid for navigation to other pages
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2.h,
                      crossAxisSpacing: 2.w,
                      childAspectRatio: (1 / 1),
                      children: [
                        _buildCard(
                          title: "Profile",
                          icon: Icons.person,
                          description: "View profile information",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (BuildContext context) => ProfileStudent(
                                  studentId: widget.studentId,
                                  studentName: widget.studentName,
                                  age: widget.age,
                                  ageInMonths: widget.ageInMonths,
                                  ageInMonthsINT: widget.ageInMonthsINT,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildCard(
                          title: "Screening Details",
                          icon: Icons.list_alt,
                          description: "View screening details",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (BuildContext context) => ScreeningDetails(
                                  studentId: widget.studentId,
                                  studentName: widget.studentName,
                                  age: widget.age,
                                  ageInMonths: widget.ageInMonths,
                                  ageInMonthsINT: widget.ageInMonthsINT,
                                  date: screeningDetails['date'],
                                  studBranch: screeningDetails['stud_branch'],
                                  therapistSuggestion: screeningDetails['therapist_suggestion'],
                                  time: screeningDetails['time'],
                                ),
                              ),
                            );
                          },
                        ),
                        _buildCard(
                          title: "Screening Result",
                          icon: Icons.assessment,
                          description: screeningData.isNotEmpty ? "View screening result" : "No screening result",
                          onTap: screeningData.isNotEmpty
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ScreeningResult(
                                        studentId: screeningData['student_id'],
                                        screeningId: screeningData['screening_id'],
                                        age: _safeParseDouble(screeningData['age']),
                                        studentName: screeningData['student'],
                                        ageFineMotor: _safeParseDouble(screeningData['age_fine_motor']),
                                        ageGrossMotor: _safeParseDouble(screeningData['age_gross_motor']),
                                        ageLanguage: _safeParseDouble(screeningData['age_language']),
                                        agePersonal: _safeParseDouble(screeningData['age_personal_social']),
                                        therapist_suggestion: screeningData['therapist_suggestion'],
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        _buildCard(
                          title: draftTitle,
                          icon: draftIcon,
                          description: draftDescription,
                          onTap: draftOnTap,
                        ),
                        _buildCard(
                          title: "Therapist Suggestion",
                          icon: Icons.checklist,
                          description: therapistSuggestionDescription,
                          onTap: therapistSuggestionOnTap,
                        ),
                        _buildCard(
                          title: "Print Result",
                          icon: Icons.print,
                          description: 'Print all the result and suggestion to pdf',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResultPdf(
                                  studentId: screeningData['student_id'],
                                  screeningId: screeningData['screening_id'],
                                  age: _safeParseDouble(screeningData['age']),
                                  studentName: screeningData['student'],
                                  ageString: widget.age,
                                  ageFineMotor: _safeParseDouble(screeningData['age_fine_motor']),
                                  ageGrossMotor: _safeParseDouble(screeningData['age_gross_motor']),
                                  ageLanguage: _safeParseDouble(screeningData['age_language']),
                                  agePersonal: _safeParseDouble(screeningData['age_personal_social']),
                                  therapist_suggestion: screeningData['therapist_suggestion'],
                                  screeningDate: screeningData['screening_date'],
                                  failData: failData,
                                ),
                              ),
                            );
                          },
                        ),
                        // ==== Sensory Profile Result (view-only) ====
                        _buildCard(
                          title: "Sensory Profile Result",
                          icon: sensoryReady ? Icons.score : Icons.close,
                          description: sensoryReady ? 'View sensory profile result' : 'No sensory profile results',
                          onTap: sensoryReady
                              ? () {
                                  // Route based on age in months
                                  if (widget.ageInMonthsINT >= 37) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SensoryProfileResult2(
                                          assessmentId: int.parse(sensoryData['assessment_id']),
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SensoryProfileResult(
                                          assessmentId: int.parse(sensoryData['assessment_id']),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null, // disabled when no result
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Function to build a navigation card
  Widget _buildCard({
    required String title,
    required IconData icon,
    required String description,
    VoidCallback? onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 6,
      child: InkWell(
        onTap: onTap, // null = disabled
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: EdgeInsets.all(1.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 4.h,
                backgroundColor: Growkids.purple,
                child: Icon(
                  icon,
                  size: 5.h,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 0.5.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
