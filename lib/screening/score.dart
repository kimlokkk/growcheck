import 'dart:convert';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class ScoreResult extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String age;
  final String ageInMonths;
  final int ageInMonthsINT;
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;

  const ScoreResult({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.age,
    required this.ageInMonths,
    required this.ageInMonthsINT,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
  });

  @override
  State<ScoreResult> createState() => _ScoreResultState();
}

class _ScoreResultState extends State<ScoreResult> {
  bool isLoading = false;
  List<Map<String, dynamic>> failData = [];
  List<Map<String, dynamic>> noOppData = [];
  Map<String, List<Map<String, dynamic>>> noOppDomainData = {};
  Map<String, List<Map<String, dynamic>>> domainData = {};
  final TextEditingController suggestionController = TextEditingController();
  bool suggestionSubmitted = false;

  Future<void> fetchData() async {
    final response = await http.post(
      Uri.parse('http://app.kizzukids.com.my/growkids/flutter/score_result.php'),
      body: {"stud_id": widget.studentId},
    );

    if (response.statusCode == 200) {
      final List<dynamic> raw = json.decode(response.body);
      final all = List<Map<String, dynamic>>.from(raw);

      // Terus tapis ikut nilai tepat
      failData = all.where((m) => (m['score']?.toString() == 'Fail')).toList();
      noOppData = all.where((m) => (m['score']?.toString() == 'N.O')).toList();

      _groupDataByDomainInto(failData, domainData);
      _groupDataByDomainInto(noOppData, noOppDomainData);

      setState(() {});
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _groupDataByDomainInto(
    List<Map<String, dynamic>> data,
    Map<String, List<Map<String, dynamic>>> target,
  ) {
    target.clear();
    for (final item in data) {
      final domain = (item['domain'] ?? '').toString();
      target.putIfAbsent(domain, () => []).add(item);
    }
  }

  Future profile() async {
    var response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/profile.php'), body: {
      "staff_no": staff_no,
    });
    var data = json.decode(response.body);
    setState(() {
      staff_no = data[0]['staff_no'];
      id = data[0]['staff_id'];
      name = data[0]['staff_name'];
      nickname = data[0]['staff_nickname'];
      ic = data[0]['staff_ic'];
      password = data[0]['staff_pass'];
      email = data[0]['staff_email'];
      designation = data[0]['staff_designation'];
      image = data[0]['staff_img'];
      program = data[0]['staff_program'];
      branch = data[0]['staff_branch'];
      total_screenings = data[0]['total_screenings'].toString();
      current_month_screenings = data[0]['current_month_screenings'].toString();
      previous_month_screenings = data[0]['previous_month_screenings'].toString();
      students_to_screen_today = data[0]['students_to_screen_today'].toString();
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const Home(),
      ),
    );
    print(data);
    return data;
  }

  Future<void> _submitSuggestion() async {
    String suggestion = suggestionController.text;

    if (suggestion.isEmpty) {
      // Show an alert if no suggestion is entered
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please enter a suggestion.'),
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
      return;
    }

    try {
      // Send suggestion to the server
      final response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/suggestion_v2.php'),
        body: {
          "suggestion": suggestion,
          "stud_id": widget.studentId,
        },
      );

      if (response.statusCode == 200) {
        // Show success message
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Success'),
              content: const Text('Suggestion submitted successfully!'),
              actions: [
                TextButton(
                  onPressed: () {
                    profile();
                    setState(() {
                      suggestionController.clear(); // Clear the text field
                      suggestionSubmitted = true; // Mark suggestion as submitted
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception('Failed to submit suggestion');
      }
    } catch (e) {
      // Handle submission error
      showDialog(
        context: context,
        builder: (context) {
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

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    double cardWidth = MediaQuery.of(context).size.width / 3.3;
    double cardHeight = MediaQuery.of(context).size.height / 5.9;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Score Result'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: Container(
        height: double.infinity,
        padding: EdgeInsets.all(2.h),
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg-home.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Growkids.purple, // The color and opacity to apply to the image
              BlendMode.color, // The blending mode to apply the color filter
            ),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(3.h),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Growkids.purple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.studentName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.ageInMonths,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 2.h,
              ),
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                childAspectRatio: (cardWidth / cardHeight),
                crossAxisSpacing: 1.h,
                mainAxisSpacing: 1.h,
                crossAxisCount: 2,
                children: <Widget>[
                  _buildDevelopmentCard(
                    'Fine Motor Developmental Age',
                    widget.ageFineMotor,
                    widget.ageInMonthsINT,
                  ),
                  _buildDevelopmentCard(
                    'Gross Motor Developmental Age',
                    widget.ageGrossMotor,
                    widget.ageInMonthsINT,
                  ),
                  _buildDevelopmentCard(
                    'Personal Social Developmental Age',
                    widget.agePersonal,
                    widget.ageInMonthsINT,
                  ),
                  _buildDevelopmentCard(
                    'Language Developmental Age',
                    widget.ageLanguage,
                    widget.ageInMonthsINT,
                  ),
                ],
              ),
              SizedBox(
                height: 1.h,
              ),
              Container(
                padding: EdgeInsets.all(1.5.h),
                width: double.infinity,
                child: Text(
                  'List of fail components',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                  ),
                ),
              ),
              _buildFailComponentSection(),
              SizedBox(
                height: 1.h,
              ),
              Container(
                padding: EdgeInsets.all(1.5.h),
                width: double.infinity,
                child: Text(
                  'List of no opportunity components',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                  ),
                ),
              ),
              _buildNoOppComponentSection(),
              Container(
                padding: EdgeInsets.all(1.5.h),
                width: double.infinity,
                child: Text(
                  'Therapist\'s Section',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    child: Column(
                      children: [
                        TextField(
                          controller: suggestionController,
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
                          maxLines: 3,
                        ), /*
                        SizedBox(
                          height: 1.h,
                        ),
                        Container(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: _submitSuggestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Growkids.pink,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(15),
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(1.h),
                              child: Text(
                                'Submit Suggestion',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      */
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 2.h,
              ),
              SizedBox(
                height: 6.h,
                child: ElevatedButton(
                  onPressed: () {
                    if (suggestionController.text.isEmpty && !suggestionSubmitted) {
                      // Show an alert if no suggestion is entered
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Error'),
                            content: const Text('Please enter a suggestion before finishing the screening.'),
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
                    } else {
                      // Proceed with finishing the screening if suggestion is not empty
                      _submitSuggestion();
                      // Add any additional logic for finishing the screening here
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Growkids.purple,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(15),
                      ),
                    ),
                  ),
                  child: Text(
                    'Finish Screening',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ), // Add the fail components section here
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevelopmentCard(String title, double developmentalAge, int actualAge) {
    return Card(
      elevation: 5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Growkids.purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              padding: EdgeInsets.all(1.5.h),
              child: Text(
                title,
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
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.h,
                    vertical: 1.h,
                  ),
                  decoration: BoxDecoration(
                    color: developmentalAge == actualAge ? Colors.green : Colors.red,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    '$developmentalAge Months',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 1.h,
                ),
                SfLinearGauge(
                  interval: actualAge / 5,
                  minimum: 0,
                  maximum: actualAge.toDouble(),
                  axisTrackStyle: LinearAxisTrackStyle(
                    thickness: 1.h,
                    color: Colors.grey,
                  ),
                  markerPointers: [
                    LinearShapePointer(
                      value: developmentalAge,
                      color: developmentalAge == actualAge ? Colors.green : Colors.red,
                      height: 2.h,
                      width: 2.h,
                    )
                  ],
                  barPointers: [
                    LinearBarPointer(
                      value: developmentalAge,
                      color: developmentalAge == actualAge ? Colors.green : Colors.red,
                      thickness: 1.h,
                    ),
                  ],
                  animationDuration: 3000,
                ),
                const Text('Age in months'),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Widget to show the list of failed components grouped by domain
  Widget _buildFailComponentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: domainData.keys.map((domain) {
        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Growkids.purple,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                padding: EdgeInsets.all(1.h),
                child: Text(
                  domain,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: domainData[domain]!.map((component) {
                  return ListTile(
                    title: Text(
                      component['component'],
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      'Recommendation: ${component['recommendation']}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(
              height: 2.h,
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNoOppComponentSection() {
    if (noOppDomainData.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        child: Text(
          'No "No Opportunity" components.',
          style: TextStyle(fontSize: 12.sp, color: Colors.black54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: noOppDomainData.keys.map((domain) {
        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Growkids.pink,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                ),
                padding: EdgeInsets.all(1.h),
                child:
                    Text(domain, style: TextStyle(color: Colors.white, fontSize: 14.sp), textAlign: TextAlign.center),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Column(
                children: noOppDomainData[domain]!.map((c) {
                  return ListTile(
                    title: Text(c['component'], style: TextStyle(fontSize: 14.sp)),
                    subtitle: Text('Recommendation: ${c['recommendation']}',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                    trailing: const Icon(Icons.info_outline, color: Colors.orange),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 2.h),
          ],
        );
      }).toList(),
    );
  }
}
