import 'dart:convert';
import 'package:growcheck_app_v2/pages/home/profile_page.dart';
import 'package:growcheck_app_v2/pages/home/screening_list.dart';
import 'package:growcheck_app_v2/pages/home/screening_today_list.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/login/login.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> todayScreeningData = [];
  List<Map<String, dynamic>> studentData = [];
  List<Map<String, dynamic>> filteredData = [];
  List<Map<String, dynamic>> displayedData = [];

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchTodayScreeningData();
  }

  Future<void> fetchTodayScreeningData() async {
    final response =
        await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/screening_today_list.php'), body: {
      "therapist_id": id,
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        todayScreeningData = List<Map<String, dynamic>>.from(data); // Initialize filteredData with all data
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<void> fetchData() async {
    final response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/children_v2.php'), body: {
      "therapist_id": id,
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        studentData = List<Map<String, dynamic>>.from(data);
        // Calculate age for each dependant
        for (var i = 0; i < studentData.length; i++) {
          studentData[i]['age'] = calculateAge(studentData[i]['stud_dob']);
          studentData[i]['ageMonths'] = calculateAgeInMonths(studentData[i]['stud_dob']);
          studentData[i]['ageMonthsInt'] = calculateAgeInMonthsINT(studentData[i]['stud_dob']);
        }
        filteredData = studentData;
        limitDisplayedData(); // Initialize filteredData with all data
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  void filterData(String query) {
    List<Map<String, dynamic>> tempList = [];
    if (query.isNotEmpty) {
      for (var student in studentData) {
        if (student['stud_name'].toLowerCase().contains(query.toLowerCase())) {
          tempList.add(student);
        }
      }
    } else {
      tempList = List.from(studentData);
    }
    setState(() {
      filteredData = tempList;
      limitDisplayedData();
    });
  }

  void limitDisplayedData() {
    setState(() {
      displayedData = filteredData.map((student) {
        // Include age calculations for each student in displayedData
        student['age'] = calculateAge(student['stud_dob']);
        student['ageMonths'] = calculateAgeInMonths(student['stud_dob']);
        student['ageMonthsInt'] = calculateAgeInMonthsINT(student['stud_dob']);
        return student;
      }).toList();
    });
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

    return '$ageMonth Months';
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
    print(data);
    return data;
  }

  Future<void> refreshData() async {
    await fetchData();
    limitDisplayedData();
    profile();
  }

  @override
  Widget build(BuildContext context) {
    // Get the current date and subtract one month
    return WillPopScope(
      onWillPop: () => Future.value(false),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: refreshData,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Container(
              height: MediaQuery.of(context).size.height,
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
                padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 5.h),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Growcheck',
                          style: TextStyle(
                            fontSize: 18.sp,
                            color: Growkids.purple,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (BuildContext context) => const Login(),
                              ),
                            );
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            prefs.remove('staffNo');
                          },
                          child: const Icon(
                            Icons.exit_to_app,
                            size: 40,
                            color: Growkids.purple,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 1.h,
                    ),
                    Container(
                      padding: EdgeInsets.all(2.h),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Growkids.purple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Welcome,',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18.sp,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 1.h,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 46.w,
                          child: Material(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            color: GrowkidsPastel.purple2,
                            child: InkWell(
                              splashColor: GrowkidsPastel.pink,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) => const ScreeningList(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 2.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 30.w,
                                          child: Text(
                                            'Total Screening',
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              color: Growkids.purple,
                                            ),
                                          ),
                                        ),
                                        const Text(
                                          'Click for info >',
                                          style: TextStyle(
                                            color: Growkids.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      total_screenings,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        color: Growkids.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: GrowkidsPastel.purple2,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: EdgeInsets.all(2.h),
                          width: 46.w,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 30.w,
                                child: Text(
                                  '${DateFormat.MMMM().format(DateTime.now())}\'s Screening',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Growkids.purple,
                                  ),
                                ),
                              ),
                              Text(
                                current_month_screenings,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  color: Growkids.purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    /*MediaQuery.removePadding(
                      removeTop: true,
                      context: context,
                      child: GridView.count(
                        shrinkWrap: true,
                        childAspectRatio: (cardHeight / cardWidth),
                        crossAxisSpacing: 1.h,
                        crossAxisCount: 2,
                        children: <Widget>[
                          Material(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            color: GrowkidsPastel.purple2,
                            child: InkWell(
                              splashColor: GrowkidsPastel.pink,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) => const ScreeningTodayList(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 30.w,
                                          child: Text(
                                            'Total Screening',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              color: Growkids.purple,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Click for info >',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Growkids.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      total_screenings,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26.sp,
                                        color: Growkids.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: GrowkidsPastel.purple2,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: EdgeInsets.all(1.5.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 30.w,
                                      child: Text(
                                        '${DateFormat.MMMM().format(DateTime.now())}\'s Screening',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Growkids.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  current_month_screenings,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 26.sp,
                                    color: Growkids.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /*Container(
                            decoration: BoxDecoration(
                              color: GrowkidsPastel.purple2,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: EdgeInsets.all(1.5.h),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${DateFormat.MMMM().format(DateTime.now())}\'s Screening',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Growkids.purple,
                                  ),
                                ),
                                Text(
                                  current_month_screenings,
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    color: Growkids.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: GrowkidsPastel.purple2,
                            child: InkWell(
                              splashColor: Colors.white,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) => const ScreeningList(),
                                  ),
                                );
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Total Number of Screening',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Growkids.purple,
                                    ),
                                  ),
                                  Text(
                                    total_screenings,
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      color: Growkids.purple,
                                    ),
                                  ),
                                  const Text(
                                    'Click for info',
                                    style: TextStyle(
                                      color: Growkids.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: GrowkidsPastel.purple2,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: EdgeInsets.all(1.5.h),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${DateFormat.MMMM().format(lastMonth)}\'s Screening',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Growkids.purple,
                                  ),
                                ),
                                Text(
                                  previous_month_screenings,
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    color: Growkids.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        */
                        ],
                      ),
                    ),*/
                    SizedBox(
                      height: 1.h,
                    ),
                    students_to_screen_today == '0'
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 3.h, vertical: 2.h),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Growkids.pink,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.no_accounts,
                                  size: 6.h,
                                  color: Colors.white,
                                ),
                                Text(
                                  'No Screening Today',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Material(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: Growkids.pink,
                            child: InkWell(
                              splashColor: GrowkidsPastel.pink,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) => const ScreeningTodayList(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3.h, vertical: 2.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 30.w,
                                          child: Text(
                                            'Screening Pending Today',
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const Text(
                                          'Click for info >',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      students_to_screen_today,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    SizedBox(
                      height: 4.h,
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'List of Students',
                        style: TextStyle(
                          color: Growkids.purple,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 1.h,
                    ),
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        filterData(value);
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        prefixIconColor: Growkids.purple,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Growkids.purple,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        ),
                        labelText: 'Carian Nama',
                        labelStyle: TextStyle(
                          color: Growkids.purple,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 1.h,
                    ),
                    Flexible(
                      child: displayedData.isEmpty
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
                                itemCount: displayedData.length,
                                itemBuilder: (context, index) {
                                  return InkWell(
                                    onTap: () {
                                      /*Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (BuildContext context) => ProfileStudent(
                                            studentId: displayedData[index]['stud_id'],
                                            studentName: displayedData[index]['stud_name'],
                                            age: displayedData[index]['age'],
                                            ageInMonths: displayedData[index]['ageMonths'],
                                            ageInMonthsINT: displayedData[index]['ageMonthsInt'],
                                          ),
                                        ),
                                      );*/
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (BuildContext context) => StudentMainDashboard(
                                            studentId: displayedData[index]['stud_id'],
                                            studentName: displayedData[index]['stud_name'],
                                            age: displayedData[index]['age'],
                                            ageInMonths: displayedData[index]['ageMonths'],
                                            ageInMonthsINT: displayedData[index]['ageMonthsInt'],
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
                                      child: ListTile(
                                        contentPadding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.h),
                                        title: Text(
                                          displayedData[index]['stud_name'],
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        subtitle: Text(
                                          displayedData[index]['age'],
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.arrow_forward_ios,
                                          color: Growkids.purple,
                                          size: 3.h,
                                        ),
                                        // Add more fields as needed
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
            ),
          ),
        ),
      ),
    );
  }
}
