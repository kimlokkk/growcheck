// ignore_for_file: use_build_context_synchronously
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateChecker.check(
        context,
        appKey: 'growcheck_therapist',
      );
    });

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

  Future<void> signin() async {
    if (staffNoController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill in all fields"),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('login.php')),
        //Uri.parse('http://app-kizzu.test/growkids/flutter/login.php'),
        body: {
          "staff_no": staffNoController.text.trim(),
          "password": passwordController.text,
        },
      );

      final data = json.decode(response.body);

      if (!mounted) return;

      if (data == "Error 1") {
        setState(() {
          isLoading = false;
        });

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      if (data == "Error 2") {
        setState(() {
          isLoading = false;
        });

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      if (data is! List || data.isEmpty) {
        throw Exception("Invalid login response");
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

      if (fetchedStaffNo.isEmpty || fetchedId.isEmpty || fetchedName.isEmpty) {
        throw Exception("Incomplete user data");
      }

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

      final prefs = await SharedPreferences.getInstance();

      if (isSwitched == true) {
        await prefs.setString('staffNo', fetchedStaffNo);
      } else {
        await prefs.remove('staffNo');
      }

      setState(() {
        isLoading = false;
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

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

            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection error. ${e.toString()}"),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!useDesktopOnboardingLayout(context)) {
      return _buildLegacy(context);
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF471AFF),
              Color(0xFF6C48FF),
              Color(0xFF9980FF),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _decorativeCircle(
              top: -100,
              right: -80,
              size: 300,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            _decorativeCircle(
              bottom: -130,
              left: -100,
              size: 340,
              color: Growkids.pink.withValues(alpha: 0.10),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48 : 24,
                      vertical: isDesktop ? 32 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - (isDesktop ? 64 : 48),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: isDesktop ? _desktopLayout() : _mobileLayout(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 72),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _desktopBranding(),
            ),
          ),
        ),
        SizedBox(
          width: 460,
          child: _animated(child: _loginCard(desktop: true)),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: _logo(size: 100, padding: 22),
          ),
          const SizedBox(height: 30),
          _animated(child: _loginCard(desktop: false)),
          const SizedBox(height: 24),
          _termsText(),
        ],
      ),
    );
  }

  Widget _desktopBranding() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _logo(size: 130, padding: 28),
        const SizedBox(height: 34),
        const Text(
          'Welcome back to\nGrowCheck',
          style: TextStyle(
            color: Colors.white,
            fontSize: 44,
            height: 1.12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Sign in to manage assessments, monitor child development, '
          'and keep every progress update in one place.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: 16,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 30),
        _desktopFeature(Icons.shield_outlined, 'Secure staff access'),
        const SizedBox(height: 14),
        _desktopFeature(
          Icons.sync_rounded,
          'Connected to your GrowCheck workspace',
        ),
      ],
    );
  }

  Widget _desktopFeature(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 13),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _loginCard({required bool desktop}) {
    return Container(
      padding: EdgeInsets.all(desktop ? 38 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GrowCheck App',
              style: TextStyle(
                color: Growkids.purple,
                fontSize: desktop ? 28 : 25,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in with your staff account to continue.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            _fieldLabel('Staff Number'),
            const SizedBox(height: 9),
            _inputContainer(
              child: TextField(
                controller: staffNoController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: _inputDecoration(
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter your staff number',
                ),
              ),
            ),
            const SizedBox(height: 21),
            _fieldLabel('Password'),
            const SizedBox(height: 9),
            _inputContainer(
              child: TextField(
                controller: passwordController,
                obscureText: _obscureText,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!isLoading) signin();
                },
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: _inputDecoration(
                  icon: Icons.lock_outline_rounded,
                  hint: 'Enter your password',
                  suffixIcon: IconButton(
                    tooltip: _obscureText ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Growkids.purple,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      isSwitched = !isSwitched;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
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
                        const SizedBox(width: 9),
                        Text(
                          'Remember Me',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Forgot password logic
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Growkids.pink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _loginButton(),
            if (desktop) ...[
              const SizedBox(height: 22),
              _termsText(dark: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Growkids.purple,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _inputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: GrowkidsPastel.purple3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GrowkidsPastel.purple2.withValues(alpha: 0.30),
        ),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Growkids.purple, size: 22),
      suffixIcon: suffixIcon,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
    );
  }

  Widget _loginButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF538F), Color(0xFFFF6BA0)],
        ),
        boxShadow: [
          BoxShadow(
            color: Growkids.pink.withValues(alpha: 0.40),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : signin,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 23,
                      width: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'LOGIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo({required double size, required double padding}) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Growkids.pink.withValues(alpha: 0.30),
            blurRadius: 25,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/Growcheck-logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _termsText({bool dark = false}) {
    return Text(
      'By signing in, you agree to our Terms and Services',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color:
            dark ? Colors.grey.shade500 : Colors.white.withValues(alpha: 0.80),
        height: 1.4,
      ),
    );
  }

  Widget _animated({required Widget child}) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: child),
    );
  }

  static Widget _decorativeCircle({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildLegacy(BuildContext context) {
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
                  color: Colors.white.withValues(alpha: 0.05),
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
                  color: Growkids.pink.withValues(alpha: 0.1),
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
                                  color: Growkids.pink.withValues(alpha: 0.3),
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
                                    color: Colors.black.withValues(alpha: 0.1),
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
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 1.h),
                                      decoration: BoxDecoration(
                                        color: GrowkidsPastel.purple3,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: GrowkidsPastel.purple2
                                              .withValues(alpha: 0.3),
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
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 1.h),
                                      decoration: BoxDecoration(
                                        color: GrowkidsPastel.purple3,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: GrowkidsPastel.purple2
                                              .withValues(alpha: 0.3),
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
                                              _obscureText
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                            color: Growkids.pink
                                                .withValues(alpha: 0.4),
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
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Center(
                                            child: isLoading
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    'LOGIN',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                color: Colors.white.withValues(alpha: 0.8),
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
