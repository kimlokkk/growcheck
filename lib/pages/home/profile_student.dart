import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

class ProfileStudent extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String age;
  final String ageInMonths;
  final int ageInMonthsINT;

  const ProfileStudent({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.age,
    required this.ageInMonths,
    required this.ageInMonthsINT,
  });

  @override
  State<ProfileStudent> createState() => _ProfileStudentState();
}

class _ProfileStudentState extends State<ProfileStudent> {
  Map<String, dynamic> profileData = {};
  Map<String, dynamic> screeningData = {};
  bool isLoading = false; // Added for loading indicator

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchScreeningData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true; // Set isLoading to true when data fetching starts
    });
    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/student_profile.php'),
      body: {'stud_id': widget.studentId},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        profileData = data.isNotEmpty ? data[0] : {};
        isLoading = false; // Data has been fetched, no longer loading
      });
    }
  }

  Future<void> fetchScreeningData() async {
    setState(() {
      isLoading = true; // Set isLoading to true when data fetching starts
    });
    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/check_screening_data.php'),
      body: {'stud_id': widget.studentId},
    );

    if (response.statusCode == 200) {
      final data2 = jsonDecode(response.body);
      setState(() {
        screeningData = data2.isNotEmpty ? data2[0] : {};
        isLoading = false; // Data has been fetched, no longer loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student\'s Profile'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: profileData['stud_name'] == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Container(
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
                child: Padding(
                  padding: EdgeInsets.all(3.h),
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
                              profileData['stud_name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20.sp,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 2.h,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Growkids.purple,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          padding: EdgeInsets.all(1.h),
                          child: Text(
                            'Student\'s Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        width: double.infinity,
                        padding: EdgeInsets.all(2.h),
                        decoration: const BoxDecoration(
                          color: GrowkidsPastel.purple,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date of Birth',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Growkids.purple,
                              ),
                            ),
                            Text(
                              DateFormat('d MMMM yyyy').format(
                                DateTime.parse(profileData['stud_dob']),
                              ),
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Place of Birth',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_pob'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Age',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              widget.age,
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Age In Months',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Growkids.purple,
                              ),
                            ),
                            Text(
                              widget.ageInMonths,
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Concern',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_concern'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Hope',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_hope'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Gender',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_sex'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Religion',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_religion'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Race',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_race'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Address',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_address'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Email Address',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_email'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Date Register',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              DateFormat('d MMMM yyyy').format(DateTime.parse(profileData['stud_date_register'])),
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 2.h,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Growkids.purple,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          padding: EdgeInsets.all(1.h),
                          child: Text(
                            'Health & Medication Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        width: double.infinity,
                        padding: EdgeInsets.all(2.h),
                        decoration: const BoxDecoration(
                          color: GrowkidsPastel.purple,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Method of Pregnancy',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_method_pregnant'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Complication',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_complication'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Check Up Information',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_checkup'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Health Issue',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_health'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Audio & Visual Issue',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_visual_audio'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Language used at home',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_language'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Usage of Gadget',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_gadget'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 2.h,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Growkids.purple,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          padding: EdgeInsets.all(1.h),
                          child: Text(
                            'Parent Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        width: double.infinity,
                        padding: EdgeInsets.all(2.h),
                        decoration: const BoxDecoration(
                          color: GrowkidsPastel.purple,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Father\'s Name',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_father_name'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Father\'s Occupation',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_father_occu'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Father\'s Contact',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_father_contact'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Mother\'s Name',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_mother_name'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Mother\'s Occupation',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_mother_occu'],
                              style: TextStyle(
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(
                              height: 1.h,
                            ),
                            Text(
                              'Mother\'s Contact',
                              style: TextStyle(
                                color: Growkids.purple,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              profileData['stud_mother_contact'],
                              style: TextStyle(
                                fontSize: 14.sp,
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
}
