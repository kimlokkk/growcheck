import 'dart:convert';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class ScreeningResult extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age;
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;
  final String therapist_suggestion;

  const ScreeningResult({
    super.key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
    required this.therapist_suggestion,
  });

  @override
  State<ScreeningResult> createState() => _ScreeningResultState();
}

class _ScreeningResultState extends State<ScreeningResult> {
  bool isLoading = true;
  List<Map<String, dynamic>> failData = [];
  Map<String, List<Map<String, dynamic>>> domainData = {};

  Future<void> fetchFailData() async {
    final response =
        await http.post(Uri.parse('http://app.kizzukids.com.my/growkids/flutter/screening_result.php'), body: {
      "stud_id": widget.studentId,
      "screening_id": widget.screeningId,
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        failData = List<Map<String, dynamic>>.from(data);
        _groupDataByDomain(failData); // Initialize filteredData with all data
        isLoading = false;
        print(failData);
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _groupDataByDomain(List<Map<String, dynamic>> data) {
    domainData.clear();
    for (var item in data) {
      if (!domainData.containsKey(item['domain'])) {
        domainData[item['domain']] = [];
      }
      domainData[item['domain']]!.add(item);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchFailData();
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Container(
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
                            '${widget.age.toString()} Months',
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
                          widget.age,
                        ),
                        _buildDevelopmentCard(
                          'Gross Motor Developmental Age',
                          widget.ageGrossMotor,
                          widget.age,
                        ),
                        _buildDevelopmentCard(
                          'Personal Social Developmental Age',
                          widget.agePersonal,
                          widget.age,
                        ),
                        _buildDevelopmentCard(
                          'Language Developmental Age',
                          widget.ageLanguage,
                          widget.age,
                        ),
                      ],
                    ),
                    _buildFailComponentSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDevelopmentCard(String title, double developmentalAge, double actualAge) {
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
}
