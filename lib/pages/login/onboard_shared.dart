// ignore_for_file: use_build_context_synchronously
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/pages/login/onboard_layout.dart';
import 'package:growcheck_app_v2/services/app_update_checker.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class OnboardShared extends StatefulWidget {
  const OnboardShared({super.key});

  @override
  State<OnboardShared> createState() => _OnboardSharedState();
}

class _OnboardSharedState extends State<OnboardShared>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _isStarting = false;
  String? _startError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateChecker.check(
        context,
        appKey: 'growcheck_therapist',
      );
    });

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

  Future<void> profile() async {
    if (_isStarting) return;

    setState(() {
      _isStarting = true;
      _startError = null;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      final staffNo = preferences.getString('staffNo');

      if (staffNo == null || staffNo.trim().isEmpty) {
        throw Exception('Staff number not found. Please login again.');
      }

      final response = await http.post(
        Uri.parse(ApiConfig.flutter('profile.php')),
        //Uri.parse('http://app-kizzu.test/growkids/flutter/profile.php'),
        body: {
          "staff_no": staffNo,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Request failed with status ${response.statusCode}.');
      }

      final data = jsonDecode(response.body);

      if (data is! List || data.isEmpty) {
        throw Exception('Invalid profile response from server.');
      }

      final user = data[0];

      final fetchedStaffNo = user['staff_no']?.toString() ?? '';
      final fetchedId = user['staff_id']?.toString() ?? '';
      final fetchedName = user['staff_name']?.toString() ?? '';
      final fetchedNickname = user['staff_nickname']?.toString() ?? '';
      final fetchedIc = user['staff_ic']?.toString() ?? '';
      final fetchedPassword = user['staff_pass']?.toString() ?? '';
      final fetchedEmail = user['staff_email']?.toString() ?? '';
      final fetchedDesignation = user['staff_designation']?.toString() ?? '';
      final fetchedImage = user['staff_img']?.toString() ?? '';
      final fetchedProgram = user['staff_program']?.toString() ?? '';
      final fetchedBranch = user['staff_branch']?.toString() ?? '';
      final fetchedTotalScreenings =
          user['total_screenings']?.toString() ?? '0';
      final fetchedCurrentMonthScreenings =
          user['current_month_screenings']?.toString() ?? '0';
      final fetchedPreviousMonthScreenings =
          user['previous_month_screenings']?.toString() ?? '0';
      final fetchedStudentsToScreenToday =
          user['students_to_screen_today']?.toString() ?? '0';

      // validate field penting
      if (fetchedStaffNo.isEmpty || fetchedId.isEmpty || fetchedName.isEmpty) {
        throw Exception('Incomplete profile data received.');
      }

      if (!mounted) return;

      // Update semua sekali gus
      setState(() {
        staff_no = fetchedStaffNo;
        id = fetchedId;
        name = fetchedName;
        nickname = fetchedNickname;
        ic = fetchedIc;
        password = fetchedPassword;
        email = fetchedEmail;
        designation = fetchedDesignation;
        image = fetchedImage;
        program = fetchedProgram;
        branch = fetchedBranch;
        total_screenings = fetchedTotalScreenings;
        current_month_screenings = fetchedCurrentMonthScreenings;
        previous_month_screenings = fetchedPreviousMonthScreenings;
        students_to_screen_today = fetchedStudentsToScreenToday;
      });

      // Tunggu satu frame supaya state betul-betul applied
      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;

      // Double check lagi kalau nak pastikan state dah masuk
      if (staff_no.isEmpty || id.isEmpty || name.isEmpty) {
        throw Exception('Profile data is not ready yet. Please try again.');
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => HomeV3(
            staffNo: fetchedStaffNo,
            id: fetchedId,
            name: fetchedName,
            nickname: fetchedNickname,
            ic: fetchedIc,
            password: fetchedPassword,
            email: fetchedEmail,
            designation: fetchedDesignation,
            image: fetchedImage,
            program: fetchedProgram,
            branch: fetchedBranch,
            totalScreenings: fetchedTotalScreenings,
            currentMonthScreenings: fetchedCurrentMonthScreenings,
            previousMonthScreenings: fetchedPreviousMonthScreenings,
            studentsToScreenToday: fetchedStudentsToScreenToday,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _startError =
            'Connection timeout. Please check your internet and try again.';
      });
      _showStartErrorDialog(
        title: 'Connection Timeout',
        message:
            'The request took too long. Please check your internet connection and retry again.',
      );
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _startError = 'No internet connection. Please check your network.';
      });
      _showStartErrorDialog(
        title: 'No Internet Connection',
        message:
            'Unable to connect to the server. Please check your internet connection and retry again.',
      );
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _startError = 'Invalid response from server.';
      });
      _showStartErrorDialog(
        title: 'Invalid Response',
        message:
            'The server returned an unexpected response. Please try again later.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _startError = e.toString().replaceFirst('Exception: ', '');
      });
      _showStartErrorDialog(
        title: 'Unable to Continue',
        message: _startError ?? 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  void _showStartErrorDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                profile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGetStarted() async {
    profile();
    //final prefs = await SharedPreferences.getInstance();
    //await prefs.clear();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!useDesktopOnboardingLayout(context)) {
      return _buildLegacy(context);
    }

    return ResponsiveOnboardLayout(
      fadeAnimation: _fadeAnimation,
      slideAnimation: _slideAnimation,
      scaleAnimation: _scaleAnimation,
      onGetStarted: _handleGetStarted,
      isStarting: _isStarting,
      errorMessage: _startError,
    );
  }

  Widget _buildLegacy(BuildContext context) {
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
                  color: Colors.white.withValues(alpha: 0.05),
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
                  color: Colors.white.withValues(alpha: 0.05),
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
                  color: Growkids.pink.withValues(alpha: 0.1),
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
                                    color: Growkids.pink.withValues(alpha: 0.3),
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
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
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
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Professional Child Development Assessment',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.95),
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
                                    color: Growkids.pink.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _handleGetStarted,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(1.h),
            decoration: BoxDecoration(
              color: Growkids.pink.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.9),
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
