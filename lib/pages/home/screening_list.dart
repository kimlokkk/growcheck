import 'dart:convert';
import 'package:growcheck_app_v2/pages/home/screening_result.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:sizer/sizer.dart';

class ScreeningList extends StatefulWidget {
  const ScreeningList({super.key});

  @override
  State<ScreeningList> createState() => _ScreeningListState();
}

class _ScreeningListState extends State<ScreeningList> {
  List<Map<String, dynamic>> studentData = [];
  List<Map<String, dynamic>> filteredData = [];
  List<Map<String, dynamic>> displayedData = [];
  bool isLoading = true;

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final response =
        await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/screening_list_v2.php'), body: {
      "staff_id": id,
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        studentData = List<Map<String, dynamic>>.from(data);
        filteredData = studentData;
        limitDisplayedData(); // Initialize filteredData with all data
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load data');
    }
  }

  void filterData(String query) {
    List<Map<String, dynamic>> tempList = [];
    if (query.isNotEmpty) {
      for (var student in studentData) {
        if (student['student'].toLowerCase().contains(query.toLowerCase())) {
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
        return student;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening List'),
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
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      filterData(value);
                    },
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(2.h),
                      prefixIcon: const Icon(Icons.search),
                      prefixIconColor: Growkids.purple,
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Growkids.purple,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      ),
                      labelText: 'Carian Nama',
                      labelStyle: const TextStyle(
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
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (BuildContext context) => ScreeningResult(
                                          screeningDate: displayedData[index]['screening_date'],
                                          studentId: displayedData[index]['student_id'],
                                          screeningId: displayedData[index]['screening_id'],
                                          age: double.parse(displayedData[index]['age']),
                                          studentName: displayedData[index]['stud_name'],
                                          ageFineMotor: double.parse(displayedData[index]['age_fine_motor']),
                                          ageGrossMotor: double.parse(displayedData[index]['age_gross_motor']),
                                          ageLanguage: double.parse(displayedData[index]['age_language']),
                                          agePersonal: double.parse(displayedData[index]['age_personal_social']),
                                          therapist_suggestion: displayedData[index]['therapist_suggestion'],
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
                                          displayedData[index]['stud_name'],
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${displayedData[index]['age']} Months',
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
