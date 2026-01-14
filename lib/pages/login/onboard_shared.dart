// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardShared extends StatefulWidget {
  const OnboardShared({super.key});

  @override
  State<OnboardShared> createState() => _OnboardSharedState();
}

class _OnboardSharedState extends State<OnboardShared> {
  Future profile() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var staffNo = preferences.getString('staffNo');
    var response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/profile.php'), body: {
      "staff_no": staffNo,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg-colour.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Growkids.purple, // The color and opacity to apply to the image
              BlendMode.color, // The blending mode to apply the color filter
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              child: Image.asset(
                'assets/Growcheck-logo.png',
                scale: 4,
              ),
            ),
            SizedBox(
              height: 3.h,
            ),
            SizedBox(
              height: 5.h,
              width: 40.w,
              child: ElevatedButton(
                onPressed: () {
                  profile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfffc638f),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // <-- Radius
                  ),
                ),
                child: Text(
                  'Get Start !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
