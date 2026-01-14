import 'dart:convert';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class TherapistSuggestion extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age;
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;

  const TherapistSuggestion({
    super.key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
  });

  @override
  State<TherapistSuggestion> createState() => _TherapistSuggestionState();
}

class _TherapistSuggestionState extends State<TherapistSuggestion> {
  List<Map<String, dynamic>> suggestionData = [];
  List<Map<String, dynamic>> recommendationData = [];
  List<Map<String, dynamic>> interventionPlan = [];
  bool isLoading = true;

  // Peta untuk menjejak status checkbox bagi setiap kategori
  Map<dynamic, bool> selectedSuggestions = {};
  Map<dynamic, bool> selectedRecommendations = {};
  Map<dynamic, bool> selectedInterventions = {};

  Future<void> fetchSuggestionData() async {
    final response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_suggestion.php'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        isLoading = false;
        suggestionData = List<Map<String, dynamic>>.from(data);
        // Inisialisasi peta untuk suggestion
        for (var suggestion in suggestionData) {
          selectedSuggestions[suggestion['id']] = false;
        }
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load suggestion data');
    }
  }

  Future<void> fetchRecommendationData() async {
    final response =
        await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_recommendation.php'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        recommendationData = List<Map<String, dynamic>>.from(data);
        // Inisialisasi peta untuk recommendation
        for (var recommendation in recommendationData) {
          selectedRecommendations[recommendation['id']] = false;
        }
      });
    } else {
      throw Exception('Failed to load recommendation data');
    }
  }

  Future<void> fetchInterventionPlan() async {
    final response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/fetch_intervention.php'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        interventionPlan = List<Map<String, dynamic>>.from(data);
        // Inisialisasi peta untuk intervention plan
        for (var plan in interventionPlan) {
          selectedInterventions[plan['id']] = false;
        }
      });
    } else {
      throw Exception('Failed to load intervention plan');
    }
  }

  // Fungsi untuk mengumpul dan menghantar semua data yang dipilih ke server
  Future<void> submitAllData() async {
    // Kumpul data suggestion
    List selectedSuggestionsList = suggestionData
        .where((item) => selectedSuggestions[item['id']] == true)
        .map((item) => {
              'id': item['id'],
              'suggestion': item['suggestion'],
            })
        .toList();

    // Kumpul data recommendation
    List selectedRecommendationsList = recommendationData
        .where((item) => selectedRecommendations[item['id']] == true)
        .map((item) => {
              'id': item['id'],
              'recommendation': item['recommendation'],
            })
        .toList();

    // Kumpul data intervention plan (hanya tajuk sahaja)
    List selectedInterventionsList = interventionPlan
        .where((item) => selectedInterventions[item['id']] == true)
        .map((item) => {
              'id': item['id'],
              'title': item['title'],
            })
        .toList();

    final response = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/submit_suggestion.php'),
      body: {
        'studentId': widget.studentId,
        'screeningId': widget.screeningId,
        'selectedSuggestions': json.encode(selectedSuggestionsList),
        'selectedRecommendations': json.encode(selectedRecommendationsList),
        'selectedInterventions': json.encode(selectedInterventionsList),
      },
    );

    String message = "";
    String title = "";

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      message = jsonResponse['message'] ?? "Data submitted successfully";
      title = "Submission Status";
    } else {
      message = "Submission failed";
      title = "Submission Error";
    }

    // Display an AlertDialog with the message from PHP
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Home(),
                  ),
                );
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    fetchSuggestionData();
    fetchRecommendationData();
    fetchInterventionPlan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Suggestion'),
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // Agar kandungan boleh discroll
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(2.h),
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
                child: Column(
                  children: [
                    // Paparan maklumat pelajar
                    Container(
                      width: double.infinity,
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
                          ),
                          Text(
                            "${widget.age} Months",
                            style: TextStyle(fontSize: 16.sp, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 2.h),
                    // Paparan grid untuk kemahiran
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2.h,
                      crossAxisSpacing: 2.w,
                      childAspectRatio: (1 / 1),
                      children: [
                        _buildCard(
                          title: "Fine Motor",
                          devAge: widget.ageFineMotor,
                        ),
                        _buildCard(
                          title: "Gross Motor",
                          devAge: widget.ageGrossMotor,
                        ),
                        _buildCard(
                          title: "Language",
                          devAge: widget.ageLanguage,
                        ),
                        _buildCard(
                          title: "Personal Social",
                          devAge: widget.agePersonal,
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    // Bahagian checkbox untuk suggestionData
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Growkids.purple,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(15),
                                topRight: Radius.circular(15),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.h),
                            child: Text(
                              'Select suggestions:',
                              style: TextStyle(color: Colors.white, fontSize: 18.sp),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: suggestionData.length,
                            itemBuilder: (context, index) {
                              final suggestion = suggestionData[index];
                              return CheckboxListTile(
                                title: Text(suggestion['suggestion']),
                                value: selectedSuggestions[suggestion['id']] ?? false,
                                onChanged: (bool? value) {
                                  setState(() {
                                    selectedSuggestions[suggestion['id']] = value ?? false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    // Bahagian checkbox untuk recommendationData
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Growkids.purple,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(15),
                                topRight: Radius.circular(15),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.h),
                            child: Text(
                              'Select recommendations:',
                              style: TextStyle(color: Colors.white, fontSize: 18.sp),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recommendationData.length,
                            itemBuilder: (context, index) {
                              final recommendation = recommendationData[index];
                              return CheckboxListTile(
                                title: Text(recommendation['recommendation']),
                                value: selectedRecommendations[recommendation['id']] ?? false,
                                onChanged: (bool? value) {
                                  setState(() {
                                    selectedRecommendations[recommendation['id']] = value ?? false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    // Bahagian checkbox untuk interventionPlan (hanya tajuk yang dipaparkan)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Growkids.purple,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(15),
                                topRight: Radius.circular(15),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.h),
                            child: Text(
                              'Select intervention plans:',
                              style: TextStyle(color: Colors.white, fontSize: 18.sp),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: interventionPlan.length,
                            itemBuilder: (context, index) {
                              final plan = interventionPlan[index];
                              return CheckboxListTile(
                                title: Text(plan['title']),
                                value: selectedInterventions[plan['id']] ?? false,
                                onChanged: (bool? value) {
                                  setState(() {
                                    selectedInterventions[plan['id']] = value ?? false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    // Butang "Submit All" yang mengumpul dan menghantar semua data
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Growkids.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15), // <-- Radius
                          ),
                        ),
                        onPressed: submitAllData,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
                          child: Text(
                            "Submit All",
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required double devAge,
  }) {
    return Card(
      color: GrowkidsPastel.purple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(1.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: devAge == widget.age ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              child: Text(
                "${devAge} Mo.",
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              title,
              style: TextStyle(fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 0.5.h),
          ],
        ),
      ),
    );
  }
}
