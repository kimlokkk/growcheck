import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sizer/sizer.dart';

class ViewSuggestion extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age;
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;

  const ViewSuggestion({
    Key? key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
  }) : super(key: key);

  @override
  State<ViewSuggestion> createState() => _ViewSuggestionState();
}

class _ViewSuggestionState extends State<ViewSuggestion> {
  bool isLoading = true;
  List<dynamic> suggestions = [];
  List<dynamic> recommendations = [];
  List<dynamic> interventions = [];

  Future<void> fetchData() async {
    final response = await http.post(
      Uri.parse('http://app.kizzukids.com.my/growkids/flutter/fetch_suggestion_submission.php'),
      body: {"studentId": widget.studentId},
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        suggestions = data["suggestions"] ?? [];
        recommendations = data["recommendations"] ?? [];
        interventions = data["interventions"] ?? [];
        isLoading = false;
      });
    } else {
      throw Exception("Failed to load data");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // Build a bullet list for suggestions or recommendations.
  Widget buildBulletList(List<dynamic> items, String emptyMessage, String keyName) {
    if (items.isEmpty) {
      return Text(emptyMessage, style: TextStyle(fontSize: 14.sp));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map<Widget>((item) {
        return Padding(
          padding: EdgeInsets.only(bottom: 0.5.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• ", style: TextStyle(fontSize: 14.sp, color: Colors.black)),
              Expanded(child: Text(item[keyName] ?? "", style: TextStyle(fontSize: 14.sp))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Build the intervention plan as a numbered list.
  // Each intervention already comes as an object with title, description, and example.
  Widget buildInterventionList() {
    if (interventions.isEmpty) {
      return Text("No intervention plan available.", style: TextStyle(fontSize: 14.sp));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: interventions.asMap().entries.map((entry) {
        int index = entry.key;
        var item = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: 1.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${index + 1}. ${item['title']}",
                style: TextStyle(fontSize: 15.sp, color: Growkids.purple),
              ),
              SizedBox(height: 1.h),
              Text(
                "Description",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Growkids.pink,
                ),
              ),
              Text(
                item['description'] ?? "",
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(height: 1.h),
              Text(
                "Example",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Growkids.pink,
                ),
              ),
              Text(
                item['example'] ?? "",
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(
                height: 2.h,
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("View Suggestion"),
        centerTitle: true,
      ),
      body: isLoading
          ? Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/bg-home.jpg"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Growkids.purple, BlendMode.color),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(2.h),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/bg-home.jpg"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Growkids.purple, BlendMode.color),
                  ),
                ),
                child: Column(
                  children: [
                    // Student Information Header
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
                              widget.studentName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 20.sp,
                                color: Growkids.purple,
                              ),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(widget.studentName, style: TextStyle(fontSize: 18.sp, color: Colors.white)),
                          Text("${widget.age} Months", style: TextStyle(fontSize: 16.sp, color: Colors.white70)),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 1.h,
                    ),
                    // Suggestions Card
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
                          'Suggestions',
                          style: TextStyle(color: Colors.white, fontSize: 18.sp),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(2.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Growkids.purple),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                      ),
                      child: buildBulletList(suggestions, "No suggestions available.", "suggestion"),
                    ),
                    SizedBox(
                      height: 1.h,
                    ),
                    // Recommendations Card
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
                          'Recommendations',
                          style: TextStyle(color: Colors.white, fontSize: 18.sp),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(2.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Growkids.purple),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                      ),
                      child: buildBulletList(recommendations, "No recommendations available.", "recommendation"),
                    ),
                    SizedBox(
                      height: 1.h,
                    ),
                    // Intervention Plan Card
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
                          'Intervention Plan',
                          style: TextStyle(color: Colors.white, fontSize: 18.sp),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(2.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Growkids.purple),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                      ),
                      child: buildInterventionList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
