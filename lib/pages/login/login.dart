// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/pages/home/home_v2.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  TextEditingController staffNoController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscureText = true;
  bool isSwitched = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    staffNoController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future signin() async {
    if (staffNoController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill in all fields"),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      var response = await http.post(
        Uri.parse('https://app.kizzukids.com.my/growkids/flutter/login.php'),
        body: {
          "staff_no": staffNoController.text,
          "password": passwordController.text,
        },
      );

      var data = json.decode(response.body);

      setState(() {
        isLoading = false;
      });

      if (data == "Error 1") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text("Invalid Password")),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        print(data);
      } else if (data == "Error 2") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.person_off_outlined, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text("User Not Found")),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        print(data);
      } else {
        if (isSwitched == true) {
          SharedPreferences preferences = await SharedPreferences.getInstance();
          preferences.setString('staffNo', staffNoController.text);
        }

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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text("Login Success!")),
              ],
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeV2(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );

        print(data);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Connection error. Please try again."),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
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
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: EdgeInsets.all(2.5.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Growkids.pink.withOpacity(0.3),
                                  blurRadius: 25,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/Growcheck-logo.png',
                              height: 10.h,
                            ),
                          ),
                        ),

                        SizedBox(height: 4.h),

                        // Login Card
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 30,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(3.5.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Welcome text
                                    Center(
                                      child: Column(
                                        children: [
                                          Text(
                                            'GrowCheck App',
                                            style: TextStyle(
                                              color: Growkids.purple,
                                              fontSize: 22.sp,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          SizedBox(height: 0.5.h),
                                          Text(
                                            'Sign in to continue',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 3.h),

                                    // Staff Number Field
                                    Text(
                                      'Staff Number',
                                      style: TextStyle(
                                        color: Growkids.purple,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 1.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 1.h),
                                      decoration: BoxDecoration(
                                        color: GrowkidsPastel.purple3,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: GrowkidsPastel.purple2.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: staffNoController,
                                        keyboardType: TextInputType.text,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(
                                            Icons.person_outline_rounded,
                                            color: Growkids.purple,
                                            size: 3.h,
                                          ),
                                          hintText: 'Enter your staff number',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12.sp,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 2.h,
                                            vertical: 1.8.h,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 2.h),

                                    // Password Field
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        color: Growkids.purple,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 1.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 1.h),
                                      decoration: BoxDecoration(
                                        color: GrowkidsPastel.purple3,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: GrowkidsPastel.purple2.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: passwordController,
                                        obscureText: _obscureText,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(
                                            Icons.lock_outline_rounded,
                                            color: Growkids.purple,
                                            size: 3.h,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                              color: Growkids.purple,
                                              size: 3.h,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscureText = !_obscureText;
                                              });
                                            },
                                          ),
                                          hintText: 'Enter your password',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12.sp,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 2.h,
                                            vertical: 1.8.h,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 2.h),

                                    // Remember Me & Forgot Password
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: Checkbox(
                                                value: isSwitched,
                                                onChanged: (value) {
                                                  setState(() {
                                                    isSwitched = value ?? false;
                                                  });
                                                },
                                                activeColor: Growkids.pink,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 1.w),
                                            Text(
                                              'Remember Me',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        InkWell(
                                          onTap: () {
                                            // Forgot password logic
                                          },
                                          child: Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              color: Growkids.pink,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 3.h),

                                    // Login Button
                                    Container(
                                      width: double.infinity,
                                      height: 6.h,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFff538f),
                                            Color(0xFFff6ba0),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Growkids.pink.withOpacity(0.4),
                                            blurRadius: 15,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: isLoading ? null : signin,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Center(
                                            child: isLoading
                                                ? SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    'LOGIN',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14.sp,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 3.h),

                        // Terms and conditions
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              'By signing in, you agree to our Terms and Services',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white.withOpacity(0.8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 2.h),
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
}
