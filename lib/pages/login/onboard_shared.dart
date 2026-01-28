// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home_v2.dart';
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

class _OnboardSharedState extends State<OnboardShared> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  Future profile() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    var staffNo = preferences.getString('staffNo');
    final response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/profile.php'), body: {
      "staff_no": staffNo,
    });
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    final data = jsonDecode(response.body);
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF471aff),
              Color(0xFF6c48ff),
              Color(0xFF9980ff),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              top: 40.h,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Growkids.pink.withOpacity(0.1),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 8.h),

                        // Logo with animation
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              padding: EdgeInsets.all(3.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Growkids.pink.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/Growcheck-logo.png',
                                height: 10.h,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 2.h),

                        // Welcome text
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                Text(
                                  'GrowCheck App',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.2),
                                        offset: const Offset(0, 2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 1.5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Professional Child Development Assessment',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 8.h),

                        // Get Started Button
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Growkids.pink.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    profile();
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    width: double.infinity,
                                    height: 6.5.h,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFff538f),
                                          Color(0xFFff6ba0),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Get Started',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        SizedBox(width: 2.w),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 20.sp,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 4.h),

                        // Features list
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                _buildFeatureItem(
                                  Icons.assessment_outlined,
                                  'Comprehensive Assessments',
                                ),
                                SizedBox(height: 1.5.h),
                                _buildFeatureItem(
                                  Icons.analytics_outlined,
                                  'Detailed Progress Tracking',
                                ),
                                SizedBox(height: 1.5.h),
                                _buildFeatureItem(
                                  Icons.medical_services_outlined,
                                  'Professional Recommendations',
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(1.h),
            decoration: BoxDecoration(
              color: Growkids.pink.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
