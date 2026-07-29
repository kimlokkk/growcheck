import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/student_hub/student_hub.dart';
import 'package:growcheck_app_v2/pages/schedule/teacher_schedule.dart';
import 'package:growcheck_app_v2/pages/attendance/attendance_page.dart';
import 'package:growcheck_app_v2/pages/home/change_password_page.dart';
import 'package:growcheck_app_v2/pages/denver/denver_page.dart';
import 'package:growcheck_app_v2/pages/journal/journal_page.dart';
import 'package:growcheck_app_v2/pages/home_program/home_program_page.dart';
import 'package:growcheck_app_v2/pages/soap/soap_hub.dart';
import 'package:growcheck_app_v2/pages/ssp/ssp_page.dart';
import 'package:growcheck_app_v2/pages/sspsc/sspsc.dart';
import 'package:growcheck_app_v2/pages/login/login.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../schedule/therapist_schedule.dart';

bool _useDesktopHomeLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

/// HomeV3
/// - One home for therapist + teacher (no rail, no navIndex)
/// - Keeps the premium header card
/// - Adds a slim "Today at a glance" strip
/// - Main grid menu: Student Hub, Screening, Assessment, Daily Progress, SOAP, Suggestions
///
/// NOTE: Navigation destinations are placeholders for testing.
/// Replace the `_goToX()` methods with your real pages/routes.
class HomeV3 extends StatefulWidget {
  final String staffNo;
  final String id;
  final String name;
  final String nickname;
  final String ic;
  final String password;
  final String email;
  final String designation;
  final String image;
  final String program;
  final String branch;
  final String totalScreenings;
  final String currentMonthScreenings;
  final String previousMonthScreenings;
  final String studentsToScreenToday;

  const HomeV3({
    super.key,
    required this.staffNo,
    required this.id,
    required this.name,
    required this.nickname,
    required this.ic,
    required this.password,
    required this.email,
    required this.designation,
    required this.image,
    required this.program,
    required this.branch,
    required this.totalScreenings,
    required this.currentMonthScreenings,
    required this.previousMonthScreenings,
    required this.studentsToScreenToday,
  });

  @override
  State<HomeV3> createState() => _HomeV3State();
}

enum UserRole { therapist, teacher, unknown }

class _HomeV3State extends State<HomeV3> {
  // ====== Profile / Role ======
  String staffNo = '';
  String staffName = '';
  String staffId = '';
  UserRole role = UserRole.unknown;

  List<Map<String, dynamic>> studentData = [];
  int studentCount = 0;

  static final _childrenUrl = ApiConfig.flutter('children_v2.php');
  static final _kssStudentUrl = ApiConfig.flutter('kss_teacher_students.php');

  // ====== Endpoints (if you want them) ======
  static final _profileUrl = ApiConfig.flutter('profile.php');

  /*static const _childrenUrl =
      'http://app-kizzu.test/growkids/flutter/children_v2.php';
  static const _kssStudentUrl =
      'http://app-kizzu.test/growkids/flutter/kss_teacher_students.php';

  // ====== Endpoints (if you want them) ======
  static const _profileUrl =
      'http://app-kizzu.test/growkids/flutter/profile.php';*/

  @override
  void initState() {
    super.initState();

    staffNo = widget.staffNo;
    staffId = widget.id;
    staffName = widget.name;

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadStaffNoFromPrefs();
    await _fetchProfile(); // fills staffName, staffId, maybe staffNo
    _inferRoleFromStaffNo();
    _fetchStudents();

    // Optional: if you still want at-a-glance counts, you can fetch here.
    // For now, keep it simple & safe:
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadStaffNoFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final possible = [
      prefs.getString('staff_no'),
      prefs.getString('staffNo'),
      prefs.getString('username'),
    ]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (!mounted) return;
    setState(() {
      // Preserve the staff number provided by the current login session
      // when "Remember Me" is off and nothing is stored in preferences.
      staffNo = possible.isNotEmpty ? possible.first : widget.staffNo.trim();
    });
  }

  Future<void> _fetchProfile() async {
    if (staffNo.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_profileUrl),
        body: {"staff_no": staffNo},
      );
      if (response.statusCode != 200) return;

      final decoded = json.decode(response.body);
      if (decoded is List && decoded.isNotEmpty) {
        final p = Map<String, dynamic>.from(decoded.first as Map);
        if (!mounted) return;
        setState(() {
          staffNo = (p['staff_no'] ?? staffNo).toString();
          staffId = (p['staff_id'] ?? '').toString();
          staffName = (p['staff_name'] ?? p['name'] ?? '').toString();
        });
      }
    } catch (_) {
      // keep UI rendering
    }
  }

  void _inferRoleFromStaffNo() {
    final sn = staffNo.toUpperCase().trim();
    if (!mounted) return;
    setState(() {
      if (sn.startsWith('KIZZU')) {
        role = UserRole.therapist;
      } else if (sn.startsWith('KSS')) {
        role = UserRole.teacher;
      } else {
        role = UserRole.unknown;
      }
    });
  }

  String get _roleLabel {
    switch (role) {
      case UserRole.therapist:
        return 'Occupational Therapist';
      case UserRole.teacher:
        return 'Teacher';
      default:
        return 'Staff';
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ====== Actions ======
  Future<void> _refresh() async {
    await _fetchProfile();
    _inferRoleFromStaffNo();
    await _fetchStudents();
    if (!mounted) return;
    setState(() {});
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  Future<void> _fetchStudents() async {
    if (staffId.isEmpty) return;

    try {
      final isTeacher = role == UserRole.teacher;
      final response = await http.post(
        Uri.parse(isTeacher ? _kssStudentUrl : _childrenUrl),
        body: isTeacher ? {"teacher_id": staffId} : {"therapist_id": staffId},
      );

      if (response.statusCode != 200) return;

      final decoded = json.decode(response.body);

      // Teacher home currently receives a count payload instead of a full list.
      if (isTeacher && decoded is Map<String, dynamic>) {
        final total =
            int.tryParse((decoded['total_students'] ?? '0').toString()) ?? 0;

        if (!mounted) return;
        setState(() {
          studentData = [];
          studentCount = total;
        });
        return;
      }

      final List<dynamic> data = decoded is List ? decoded : [];
      final list = List<Map<String, dynamic>>.from(data);

      for (final s in list) {
        final dob = (s['stud_dob'] ?? '').toString();
        s['age'] = _calculateAge(dob);
        s['ageMonths'] = _calculateAgeInMonths(dob);
      }

      setState(() {
        studentData = list;
        studentCount = list.length;
      });
    } catch (_) {}
  }

  String _calculateAge(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        years--;
      }
      return '$years yrs';
    } catch (_) {
      return '-';
    }
  }

  String _calculateAgeInMonths(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int months = (now.year - dob.year) * 12 + (now.month - dob.month);
      if (now.day < dob.day) months--;
      if (months < 0) months = 0;
      return '$months mo';
    } catch (_) {
      return '-';
    }
  }

  void _showQuickMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            type: MaterialType.transparency,
            child: Wrap(
              runSpacing: 8,
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Refresh'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _refresh();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded,
                      color: Growkids.purpleBright),
                  title: const Text('Change Password'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangePasswordPage(
                          staffId: staffId,
                          staffNo: staffNo,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout_rounded,
                      color: Colors.red.withValues(alpha: 0.8)),
                  title: const Text('Logout'),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====== Placeholder navigations (replace with real pages) ======
  void _goToStudentHub() {
    // Map your local 'role' variable to the 'UserRoleHub' enum required by StudentHubPage
    UserRoleHub hubRole;

    if (role == UserRole.teacher) {
      hubRole = UserRoleHub.teacher;
    } else {
      // Default to therapist if it's therapist or unknown
      hubRole = UserRoleHub.therapist;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentHubPage(
          staffId: staffId,
          role: hubRole, // Pass the mapped enum value here
        ),
      ),
    );
  }

  void _goToScreening() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DenverPage(
          therapistId: staffId,
        ),
      ),
    );
  }

  void _goToAssessment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SspPage(
          therapistId: staffId,
        ),
      ),
    );
  }

  void _goToDailyProgress() {
    // 1. Tentukan hubRole berdasarkan role pengguna semasa
    UserRoleHub hubRole;
    if (role == UserRole.teacher) {
      hubRole = UserRoleHub.teacher;
    } else {
      hubRole = UserRoleHub.therapist;
    }

    // 2. Navigasi ke JournalPage dengan membawa staffId dan hubRole
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalPage(
          teacherId: staffId, // staffId yang didapat dari profile
          role: hubRole, // Role yang telah dipetakan
        ),
      ),
    );
  }

  void _goToSoap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SOAPHubPage(
          therapistId: staffId,
        ),
      ),
    );
  }

  void _goToHomeProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeProgramPage(
          therapistId: staffId,
          therapistName: staffName.isEmpty ? widget.name : staffName,
          role: role == UserRole.teacher
              ? UserRoleHub.teacher
              : UserRoleHub.therapist,
        ),
      ),
    );
  }

  void _goToSSPSC() {
    UserRoleHub hubRole;
    if (role == UserRole.teacher) {
      hubRole = UserRoleHub.teacher;
    } else {
      hubRole = UserRoleHub.therapist;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SSPSCPage(
          userId: staffId,
          userRole: hubRole,
        ),
      ),
    );
  }

  void _goToAttendance() {
    // 1. Tentukan hubRole berdasarkan role pengguna semasa
    UserRoleHub hubRole;
    if (role == UserRole.teacher) {
      hubRole = UserRoleHub.teacher;
    } else {
      hubRole = UserRoleHub.therapist;
    }

    // 2. Navigasi ke JournalPage dengan membawa staffId dan hubRole
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkAttendancePage(
          staffId: staffId, // staffId yang didapat dari profile
          role: hubRole, // Role yang telah dipetakan
        ),
      ),
    );
  }

  void _goToSchedule() {
    if (role == UserRole.teacher) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TeacherSchedulePage(
            teacherId: staffId, // Role yang telah dipetakan
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TherapistSchedulePage(
            therapistId: staffId, // Role yang telah dipetakan
          ),
        ),
      );
    }
  }

  // ====== BUILD ======
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = _useDesktopHomeLayout(context);

              if (isDesktop) {
                return Row(
                  children: [
                    _buildDesktopSidebar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: _buildDashboard(desktop: true),
                      ),
                    ),
                  ],
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: _buildLegacyDashboard(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegacyDashboard() {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 2.h,
                vertical: isWide ? 18 : 14,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PremiumHeader(
                        greeting: _greeting,
                        name: staffName.isEmpty ? 'Staff' : staffName,
                        roleLabel: _roleLabel,
                        onProfileTap: () {
                          _snack('Profile page not linked yet.');
                        },
                        onMoreTap: _showQuickMenu,
                      ),
                      const SizedBox(height: 12),
                      _MiniTodayStrip(
                        dateText: DateFormat('EEE, d MMM yyyy')
                            .format(DateTime.now()),
                        leftLabel: 'Students',
                        leftValue: studentCount.toString(),
                      ),
                      SizedBox(height: 1.h),
                      _ResponsiveGrid(
                        forcedCount: 2,
                        minTileWidth: 12,
                        children: _dashboardActions(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopSidebar() {
    final displayName = staffName.isEmpty ? 'Staff' : staffName;

    return Container(
      width: 270,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset('assets/Growcheck-logo.png'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'GrowCheck',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _sidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            selected: true,
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onTap: _refresh,
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            icon: Icons.lock_reset_rounded,
            label: 'Change Password',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordPage(
                    staffId: staffId,
                    staffNo: staffNo,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Growkids.purpleFlo,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _sidebarItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            onTap: _logout,
            destructive: true,
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    bool selected = false,
    bool destructive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color:
          selected ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                color: destructive ? const Color(0xFFFFC7C7) : Colors.white,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: destructive ? const Color(0xFFFFD1D1) : Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard({required bool desktop}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 32 : 16,
            vertical: desktop ? 24 : 14,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (desktop ? 48 : 28),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      Text(
                        'Dashboard',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Growkids.purple,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a workspace to get started.',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    _PremiumHeader(
                      greeting: _greeting,
                      name: staffName.isEmpty ? 'Staff' : staffName,
                      roleLabel: _roleLabel,
                      compact: desktop,
                      onProfileTap: () {
                        _snack('Profile page not linked yet.');
                      },
                      onMoreTap: _showQuickMenu,
                    ),
                    const SizedBox(height: 12),
                    _MiniTodayStrip(
                      dateText:
                          DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                      leftLabel: 'Students',
                      leftValue: studentCount.toString(),
                    ),
                    SizedBox(height: desktop ? 22 : 14),
                    Text(
                      'Workspace',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Growkids.purple,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _ResponsiveGrid(
                      minTileWidth: desktop ? 250 : 165,
                      children: _dashboardActions(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _dashboardActions() {
    return [
      _ActionTileV2(
        title: 'Student Hub',
        icon: Icons.school_rounded,
        accent: Growkids.purpleFlo,
        onTap: _goToStudentHub,
      ),
      if (role != UserRole.teacher)
        _ActionTileV2(
          title: 'Denver Screening',
          icon: Icons.fact_check_rounded,
          accent: const Color(0xFF0AAE7A),
          onTap: _goToScreening,
        ),
      if (role != UserRole.teacher)
        _ActionTileV2(
          title: 'Short Sensory Profile',
          icon: Icons.assignment_turned_in_rounded,
          accent: const Color(0xFF3B82F6),
          onTap: _goToAssessment,
        ),
      _ActionTileV2(
        title: 'Journal',
        icon: Icons.edit_note_rounded,
        accent: Growkids.purpleFlo,
        onTap: _goToDailyProgress,
      ),
      if (role != UserRole.teacher)
        _ActionTileV2(
          title: 'SOAP',
          icon: Icons.description_rounded,
          accent: Colors.amber,
          onTap: _goToSoap,
        ),
      _ActionTileV2(
        title: 'Home Program',
        icon: Icons.folder_shared_rounded,
        accent: const Color(0xFF14B8A6),
        onTap: _goToHomeProgram,
      ),
      _ActionTileV2(
        title: 'SSPSC',
        icon: Icons.description_rounded,
        accent: Colors.pink,
        onTap: _goToSSPSC,
      ),
      _ActionTileV2(
        title: 'Attendance',
        icon: Icons.co_present_rounded,
        accent: Colors.teal,
        onTap: _goToAttendance,
      ),
      if (role != UserRole.teacher)
        _ActionTileV2(
          title: 'Schedule',
          icon: Icons.calendar_month_rounded,
          accent: Colors.cyan,
          onTap: _goToSchedule,
        ),
    ];
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ==========================
// UI COMPONENTS (Premium) — reused + extended
// ==========================

class _PremiumHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String roleLabel;
  final VoidCallback onProfileTap;
  final VoidCallback onMoreTap;
  final bool compact;

  const _PremiumHeader({
    required this.greeting,
    required this.name,
    required this.roleLabel,
    required this.onProfileTap,
    required this.onMoreTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = _useDesktopHomeLayout(context);
    return _MainCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: desktop ? (compact ? 32 : 36) : 40,
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Growkids.purpleFlo,
                  fontSize: desktop ? 18 : 16.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: desktop ? 16 : 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: desktop ? 14 : 14.sp,
                      ),
                ),
                SizedBox(height: desktop ? 4 : 0.5.h),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: desktop ? (compact ? 21 : 19) : 16.sp,
                        color: Colors.white,
                      ),
                ),
                SizedBox(height: desktop ? 9 : 1.h),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: roleLabel, icon: Icons.verified_user_rounded),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMoreTap,
            iconSize: desktop ? 27 : 5.h,
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  final Widget child;
  const _MainCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final desktop = _useDesktopHomeLayout(context);
    return Container(
      padding: EdgeInsets.all(desktop ? 20 : 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .70),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final desktop = _useDesktopHomeLayout(context);
    return Container(
      padding: EdgeInsets.all(desktop ? 18 : 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Pill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final desktop = _useDesktopHomeLayout(context);
    return Container(
      padding: desktop
          ? const EdgeInsets.symmetric(horizontal: 11, vertical: 6)
          : EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: desktop ? 17 : 2.h, color: Growkids.purpleFlo),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: desktop ? 12 : 12.sp,
              color: Colors.black.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTodayStrip extends StatelessWidget {
  final String dateText;
  final String leftLabel;
  final String leftValue;
  final String? tip;

  const _MiniTodayStrip({
    required this.dateText,
    required this.leftLabel,
    required this.leftValue,
  }) : tip = null;

  @override
  Widget build(BuildContext context) {
    final desktop = _useDesktopHomeLayout(context);
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row
          Row(
            children: [
              Icon(
                Icons.today_rounded,
                color: Growkids.purple,
                size: desktop ? 21 : 2.2.h,
              ),
              const SizedBox(width: 8),
              Text(
                dateText,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: desktop ? 14 : 13.sp,
                    ),
              ),
              const Spacer(),
              _MiniStatPill(label: leftLabel, value: leftValue),
            ],
          ),
          if (tip != null) ...[
            const SizedBox(height: 10),
            Text(
              tip!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withValues(alpha: 0.65),
                    fontSize: desktop ? 12 : 12.sp,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final desktop = _useDesktopHomeLayout(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: desktop ? 13 : 12.sp,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: desktop ? 12 : 11.sp,
              color: Colors.black.withValues(alpha: 0.60),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final double minTileWidth;
  final List<Widget> children;
  final int? forcedCount;

  const _ResponsiveGrid({
    required this.minTileWidth,
    required this.children,
    this.forcedCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final autoCount = (w / minTileWidth).floor().clamp(1, 4);
      final count = forcedCount?.clamp(1, 4) ?? autoCount;
      final desktop = _useDesktopHomeLayout(context);

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: count,
        crossAxisSpacing: desktop ? 14 : 10,
        mainAxisSpacing: desktop ? 14 : 10,
        childAspectRatio: desktop ? (w >= 900 ? 2.65 : 2.25) : 3,
        children: children,
      );
    });
  }
}

class _ActionTileV2 extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool disabled;

  const _ActionTileV2({
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
  }) : disabled = false;

  @override
  Widget build(BuildContext context) {
    final opacity = disabled ? 0.45 : 1.0;
    final desktop = _useDesktopHomeLayout(context);

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(desktop ? 14 : 1.5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                height: desktop ? 48 : 5.h,
                width: desktop ? 48 : 7.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: desktop ? 24 : 3.h,
                ),
              ),
              SizedBox(width: desktop ? 13 : 2.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize: desktop ? 14 : 14.sp,
                                ),
                          ),
                        ),
                        //const SizedBox(width: 8),
                        //if (tagText != null && tagStyle != null) _TagPill(text: tagText!, style: tagStyle!),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.black.withValues(alpha: 0.35),
                size: desktop ? 23 : 3.h,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
