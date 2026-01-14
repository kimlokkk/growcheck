import 'dart:convert';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/profile_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class ScreeningTodayList extends StatefulWidget {
  const ScreeningTodayList({super.key});

  @override
  State<ScreeningTodayList> createState() => _ScreeningTodayListState();
}

class _ScreeningTodayListState extends State<ScreeningTodayList> {
  List<Map<String, dynamic>> studentData = [];
  bool isLoading = true;

  Future<void> fetchData() async {
    final response =
        await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/screening_today_list.php'), body: {
      "therapist_id": id,
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        isLoading = false;
        studentData = List<Map<String, dynamic>>.from(data); // Initialize filteredData with all data
        for (var i = 0; i < studentData.length; i++) {
          studentData[i]['age'] = calculateAge(studentData[i]['stud_dob']);
          studentData[i]['ageMonths'] = calculateAgeInMonths(studentData[i]['stud_dob']);
          studentData[i]['ageMonthsInt'] = calculateAgeInMonthsINT(studentData[i]['stud_dob']);
        }
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load data');
    }
  }

  String calculateAge(String dobString) {
    // Parse the date of birth string and convert it to a DateTime object
    DateTime dob = DateTime.parse(dobString);

    // Calculate the current date
    DateTime now = DateTime.now();

    // Calculate the age in years
    int years = now.year - dob.year;
    // Adjust if the birthday hasn't occurred yet this year
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }

    // Calculate the age in months
    int months = now.month - dob.month;
    // Adjust if the birthday hasn't occurred yet this month
    if (now.day < dob.day) {
      months--;
    }
    // Adjust if months are negative
    if (months < 0) {
      months += 12;
    }

    // Return the age in "years months" format
    return '$years Years $months Months';
  }

  String calculateAgeInMonths(String monthsAge) {
    // Parse the date of birth string and convert it to a DateTime object
    DateTime dob = DateTime.parse(monthsAge);

    // Calculate the current date
    DateTime now = DateTime.now();

    int years = now.year - dob.year;
    int months = now.month - dob.month;

    // If the current month is before the birth month, reduce the years by 1 and adjust the months
    if (months < 0) {
      years--;
      months += 12;
    }

    int ageMonth = years * 12 + months;

    return '$ageMonth Bulan';
  }

  int calculateAgeInMonthsINT(String monthsAge) {
    // Parse the date of birth string and convert it to a DateTime object
    DateTime dob = DateTime.parse(monthsAge);

    // Calculate the current date
    DateTime now = DateTime.now();

    int years = now.year - dob.year;
    int months = now.month - dob.month;

    // If the current month is before the birth month, reduce the years by 1 and adjust the months
    if (months < 0) {
      years--;
      months += 12;
    }
    return years * 12 + months;
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List of Today\'s Screening'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Container(
              height: MediaQuery.of(context).size.height,
              width: double.infinity,
              padding: EdgeInsets.all(2.h),
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
              child: Column(
                children: [
                  Flexible(
                    child: studentData.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 8.h,
                              ),
                              Center(
                                child: Icon(
                                  Icons.no_accounts,
                                  size: 10.h,
                                  color: Growkids.purple,
                                ),
                              ),
                              Center(
                                child: Text(
                                  'No student data',
                                  style: TextStyle(
                                    color: Growkids.purple,
                                    fontSize: 18.sp,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : MediaQuery.removePadding(
                            removeTop: true,
                            context: context,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: studentData.length,
                              itemBuilder: (context, index) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (BuildContext context) => StudentMainDashboard(
                                          studentId: studentData[index]['stud_id'],
                                          studentName: studentData[index]['stud_name'],
                                          age: studentData[index]['age'],
                                          ageInMonths: studentData[index]['ageMonths'],
                                          ageInMonthsINT: studentData[index]['ageMonthsInt'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    shadowColor: Colors.white,
                                    elevation: 5,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(1.h),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(1.h),
                                      child: ListTile(
                                        title: Text(
                                          studentData[index]['stud_name'],
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${studentData[index]['age']}',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.arrow_forward_ios,
                                          color: Growkids.purple,
                                          size: 2.h,
                                        ),
                                        // Add more fields as needed
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
