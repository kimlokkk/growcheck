import 'dart:convert';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/pages/home/home_v2.dart';
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
        builder: (context) => const HomeV2(),
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
    final double cardWidth = MediaQuery.of(context).size.width / 3.3;
    final double cardHeight = MediaQuery.of(context).size.height / 5.9;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Score Result',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      // ✅ FIXED bottom button
      bottomNavigationBar: _finishBar(),

      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(2.2.h, 1.6.h, 2.2.h, 0),
          child: Column(
            children: [
              // ✅ Student header (premium)
              _studentHeaderCard(),
              SizedBox(height: 1.4.h),

              // ✅ Only content scrolls
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 2.2.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ Dev Age Grid Card
                      Container(
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 5.h,
                                  width: 5.h,
                                  decoration: BoxDecoration(
                                    color: Growkids.purpleFlo.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.speed_rounded, color: Growkids.purpleFlo, size: 2.6.h),
                                ),
                                SizedBox(width: 2.w),
                                Expanded(
                                  child: Text(
                                    'Developmental Ages',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
                                  decoration: BoxDecoration(
                                    color: Growkids.purpleFlo.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                                  ),
                                  child: Text(
                                    'Actual: ${widget.ageInMonthsINT} mo',
                                    style: TextStyle(fontSize: 13.sp),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 1.4.h),
                            GridView.count(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              childAspectRatio: (cardWidth / cardHeight),
                              crossAxisSpacing: 1.h,
                              mainAxisSpacing: 1.h,
                              crossAxisCount: 2,
                              children: <Widget>[
                                _buildDevelopmentCard('Fine Motor', widget.ageFineMotor, widget.ageInMonthsINT),
                                _buildDevelopmentCard('Gross Motor', widget.ageGrossMotor, widget.ageInMonthsINT),
                                _buildDevelopmentCard('Personal Social', widget.agePersonal, widget.ageInMonthsINT),
                                _buildDevelopmentCard('Language', widget.ageLanguage, widget.ageInMonthsINT),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 1.6.h),

                      Container(
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
                            _sectionTitle(
                              title: 'Fail Components',
                              subtitle: 'Items marked as Fail during screening',
                              icon: Icons.close_rounded,
                              tint: Growkids.purpleFlo,
                            ),
                            SizedBox(height: 1.0.h),
                            _buildFailComponentSection(),
                          ],
                        ),
                      ),
                      // ✅ Fail section

                      SizedBox(height: 1.6.h),
                      Container(
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
                            _sectionTitle(
                              title: 'No Opportunity Components',
                              subtitle: 'Items marked as N.O during screening',
                              icon: Icons.do_not_disturb_on_rounded,
                              tint: Growkids.pink,
                            ),
                            SizedBox(height: 1.0.h),
                            _buildNoOppComponentSection(),
                          ],
                        ),
                      ),
                      // ✅ N.O section

                      SizedBox(height: 1.6.h),

                      Container(
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ✅ Therapist Note section
                            _sectionTitle(
                              title: 'Therapist Note',
                              subtitle: 'Add comment before finishing',
                              icon: Icons.edit_note_rounded,
                              tint: Growkids.pink,
                            ),
                            SizedBox(height: 1.0.h),
                            TextField(
                              controller: suggestionController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: GrowkidsPastel.pink,
                                hintText: 'Enter your note/comment...',
                                hintStyle:
                                    TextStyle(color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Growkids.pink, width: 2),
                                ),
                                contentPadding: EdgeInsets.all(1.4.h),
                              ),
                            ),
                            SizedBox(height: 1.2.h),

                            // Optional: quick submit (tak wajib, sebab kau guna Finish bawah)
                            SizedBox(
                              height: 5.4.h,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Growkids.pink.withOpacity(0.35), width: 1.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: Colors.white,
                                ),
                                onPressed: _submitSuggestion,
                                child: Text(
                                  'Submit Note',
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Growkids.pink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// =======================
  /// Premium helper widgets
  /// =======================

  Widget _studentHeaderCard() {
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
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_rounded, color: Colors.white, size: 3.h),
          ),
          SizedBox(width: 1.6.h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
                Text(
                  'ID: ${widget.studentId} • ${widget.age} • ${widget.ageInMonths}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 5.h,
            width: 5.h,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 2.6.h),
          ),
          SizedBox(width: 1.2.h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.sp)),
                SizedBox(height: 0.2.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finishBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(2.2.h, 1.0.h, 2.2.h, 2.0.h),
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
        child: SizedBox(
          height: 6.h,
          child: ElevatedButton(
            onPressed: () {
              if (suggestionController.text.isEmpty && !suggestionSubmitted) {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Error'),
                      content: const Text('Please enter a suggestion before finishing the screening.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              } else {
                _submitSuggestion();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Finish Screening',
              style: TextStyle(fontSize: 14.sp, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  /// =======================
  /// Replace these 3 builders
  /// =======================

  Widget _buildDevelopmentCard(String title, double developmentalAge, int actualAge) {
    final bool ok = developmentalAge == actualAge.toDouble();
    final Color pillColor = ok ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(1.2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${developmentalAge.toStringAsFixed(0)} mo',
                    style: TextStyle(fontSize: 13.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            SfLinearGauge(
              interval: actualAge / 5,
              minimum: 0,
              maximum: actualAge.toDouble(),
              axisTrackStyle: LinearAxisTrackStyle(
                thickness: 1.h,
                color: Colors.black.withOpacity(0.08),
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
              markerPointers: [
                LinearShapePointer(
                  value: developmentalAge,
                  height: 1.5.h,
                  width: 2.0.h,
                ),
              ],
              barPointers: [
                LinearBarPointer(
                  value: developmentalAge,
                  thickness: 1.h,
                  color: Growkids.purpleFlo,
                ),
              ],
              animationDuration: 1200,
            ),
            SizedBox(height: 0.6.h),
            Text(
              'Age in months',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailComponentSection() {
    if (domainData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(1.6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Text(
          'No fail components 🎉',
          style: TextStyle(fontSize: 12.sp, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: domainData.keys.map((domain) {
        final items = domainData[domain] ?? [];
        return Padding(
          padding: EdgeInsets.only(bottom: 1.2.h),
          child: _domainCard(
            domain: domain,
            tint: Growkids.purpleFlo,
            items: items,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoOppComponentSection() {
    if (noOppDomainData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(1.6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Text(
          'No "No Opportunity" components.',
          style: TextStyle(fontSize: 12.sp, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: noOppDomainData.keys.map((domain) {
        final items = noOppDomainData[domain] ?? [];
        return Padding(
          padding: EdgeInsets.only(bottom: 1.2.h),
          child: _domainCard(
            domain: domain,
            tint: Growkids.pink,
            items: items,
          ),
        );
      }).toList(),
    );
  }

  /// Domain container premium
  Widget _domainCard({
    required String domain,
    required Color tint,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1.4.h, vertical: 1.2.h),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    domain,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 1.1.h, vertical: 0.55.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(1.2.h, 0.6.h, 1.2.h, 1.2.h),
            child: Column(
              children: items.map((m) => _componentTile(m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _componentTile(Map<String, dynamic> component) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 0.8.h),
      padding: EdgeInsets.all(1.2.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (component['component'] ?? '').toString(),
            style: TextStyle(fontSize: 13.sp),
          ),
          SizedBox(height: 0.6.h),
          Text(
            'Recommendation: ${(component['recommendation'] ?? '').toString()}',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
