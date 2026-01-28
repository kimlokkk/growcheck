import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/activity_therapist.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/pages/home/profile_page.dart';
import 'package:growcheck_app_v2/pages/home/profile_student.dart';
import 'package:growcheck_app_v2/pages/home/screening_list.dart';
import 'package:growcheck_app_v2/pages/home/screening_today_list.dart';
import 'package:growcheck_app_v2/pages/home/student_hub_dummy.dart';
import 'package:growcheck_app_v2/pages/home/teacher_activity_page.dart';
import 'package:growcheck_app_v2/pages/home/teacher_schedule.dart';
import 'package:growcheck_app_v2/pages/home/therapist_schedule.dart';
import 'package:growcheck_app_v2/pages/login/login.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

enum UserRole { therapist, teacher }

class HomeV2 extends StatefulWidget {
  const HomeV2({super.key});

  @override
  State<HomeV2> createState() => _HomeV2State();
}

class _HomeV2State extends State<HomeV2> {
  String? hubInitialStudId;
  ActTab? therapistActivityInitialTab; // null = default behaviour
  // ====== Data ======
  List<Map<String, dynamic>> todayScreeningData = [];
  List<Map<String, dynamic>> studentData = [];
  List<Map<String, dynamic>> studentKSSData = [];
  List<Map<String, dynamic>> filteredData = [];
  List<Map<String, dynamic>> filteredKSSData = [];
  List<Map<String, dynamic>> todayTeacherProgressData = [];

  // ====== Profile ======
  String staffNo = '';
  String staffName = '';
  String staffId = ''; // used as therapist_id
  UserRole role = UserRole.therapist;

  // ====== UI state ======
  final TextEditingController searchCtrl = TextEditingController();
  int navIndex = 0; // 0: Home, 1: Schedule, 2: Activity, 3: Profile
  final GlobalKey<TherapistSchedulePageState> _scheduleKey = GlobalKey<TherapistSchedulePageState>();

  // ====== Endpoints (existing) ======
  static const _profileUrl = 'https://app.kizzukids.com.my/growkids/flutter/profile.php';
  static const _childrenUrl = 'https://app.kizzukids.com.my/growkids/flutter/children_v2.php';
  static const _kssStudentUrl = 'https://app.kizzukids.com.my/growkids/flutter/student_school.php';
  static const _todayScreeningUrl = 'https://app.kizzukids.com.my/growkids/flutter/screening_today_list.php';
  static const _teacherTodayProgressUrl = 'https://app.kizzukids.com.my/growkids/flutter/teacher_progress_today.php';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadStaffNoFromPrefs();
    await _fetchProfile();
    await _loadRoleFromStaffNo();
    await Future.wait([
      _fetchStudents(),
      _fetchKSSStudents(),
      _fetchTodayScreeningsIfTherapist(),
      _fetchTodayTeacherProgressIfTeacher(),
    ]);
  }

  Future<void> _loadStaffNoFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // keep it defensive: try multiple likely keys
    final possible = [
      prefs.getString('staff_no'),
      prefs.getString('staffNo'),
      prefs.getString('username'),
      staffNo, // ✅ if your ProfileDeclaration stores it
      staffNo,
    ].whereType<String>().toList();

    setState(() {
      staffNo = possible.isNotEmpty ? possible.first : '';
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

      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        final p = data[0] as Map<String, dynamic>;
        setState(() {
          staffNo = (p['staff_no'] ?? staffNo).toString();
          staffId = (p['staff_id'] ?? '').toString();
          staffName = (p['staff_name'] ?? p['name'] ?? '').toString();
        });
      }
    } catch (_) {
      // ignore - UI will still render
    }
  }

  Future<void> _loadRoleFromStaffNo() async {
    final sn = staffNo.toUpperCase().trim();
    setState(() {
      if (sn.startsWith('KIZZU')) {
        role = UserRole.therapist;
      } else if (sn.startsWith('KSS')) {
        role = UserRole.teacher;
      } else {
        role = UserRole.therapist; // safe fallback
      }
    });
  }

  Future<void> _fetchStudents() async {
    if (staffId.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_childrenUrl),
        body: {"therapist_id": staffId}, // backend OK guna staff_id
      );

      if (response.statusCode != 200) return;

      final List<dynamic> data = json.decode(response.body);
      final list = List<Map<String, dynamic>>.from(data);

      for (final s in list) {
        final dob = (s['stud_dob'] ?? '').toString();
        s['age'] = _calculateAge(dob);
        s['ageMonths'] = _calculateAgeInMonths(dob);
      }

      setState(() {
        studentData = list;
        filteredData = list;
      });
    } catch (_) {}
  }

  Future<void> _fetchKSSStudents() async {
    if (staffId.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_kssStudentUrl),
        body: {"teacher_id": staffId}, // backend OK guna staff_id
      );

      if (response.statusCode != 200) return;

      final List<dynamic> data = json.decode(response.body);
      final list = List<Map<String, dynamic>>.from(data);

      for (final s in list) {
        final dob = (s['stud_dob'] ?? '').toString();
        s['age'] = _calculateAge(dob);
        s['ageMonths'] = _calculateAgeInMonths(dob);
      }

      setState(() {
        studentKSSData = list;
        filteredKSSData = list;
      });
    } catch (_) {}
  }

  Future<void> _fetchTodayScreeningsIfTherapist() async {
    if (role != UserRole.therapist || staffId.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_todayScreeningUrl),
        body: {"therapist_id": staffId},
      );

      if (response.statusCode != 200) return;

      final List<dynamic> data = json.decode(response.body);
      setState(() {
        todayScreeningData = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _fetchTodayTeacherProgressIfTeacher() async {
    if (role != UserRole.teacher || staffId.isEmpty) return;

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await http.post(
        Uri.parse(_teacherTodayProgressUrl),
        body: {
          "teacher_id": staffId,
          "log_date": todayStr,
        },
      );

      if (response.statusCode != 200) return;

      final decoded = json.decode(response.body);
      final List data = decoded is List ? decoded : [];

      if (!mounted) return;
      setState(() {
        todayTeacherProgressData = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refresh() async {
    await _fetchProfile();
    await _loadRoleFromStaffNo();
    await Future.wait([
      _fetchStudents(),
      _fetchKSSStudents(),
      _fetchTodayScreeningsIfTherapist(),
      _fetchTodayTeacherProgressIfTeacher(),
    ]);
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => filteredData = studentData);
      return;
    }

    setState(() {
      filteredData = studentData.where((s) {
        final name = (s['stud_name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  void _filterKSS(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => filteredKSSData = studentKSSData);
      return;
    }

    setState(() {
      filteredKSSData = studentKSSData.where((s) {
        final name = (s['stud_name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _openScheduleListToday() async {
    // 1) pergi schedule dulu (rail kekal sebab navIndex)
    setState(() => navIndex = 1);

    // 2) tunggu schedule page betul-betul build & mount
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 10));

    // 3) sekarang baru command schedule state
    _scheduleKey.currentState?.jumpToListToday();

    // 4) kalau masih tak jalan (rare), retry sekali lepas frame seterusnya
    if (_scheduleKey.currentState == null) {
      await WidgetsBinding.instance.endOfFrame;
      _scheduleKey.currentState?.jumpToListToday();
    }
  }

  // ====== UI helpers ======

  bool get _isWide {
    final w = MediaQuery.of(context).size.width;
    return w >= 900; // iPad landscape + bigger tablets
  }

  int get _teacherSubmittedTodayCount {
    int c = 0;
    for (final r in todayTeacherProgressData) {
      final st = (r['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'submit' || st == 'submitted') c++;
    }
    return c;
  }

  String get _roleLabel => role == UserRole.therapist ? 'Therapist' : 'Teacher';

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _calculateAge(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
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

  // ====== NAV target ======
  Widget _buildCurrentBody() {
    switch (navIndex) {
      case 0:
        return _buildHomeDashboard();
      case 1:
        return role == UserRole.therapist
            ? TherapistSchedulePage(therapistId: staffId)
            : TeacherSchedulePage(teacherId: staffId);

      case 2:
        return role == UserRole.therapist ? _buildTherapistActivity() : _buildTeacherActivity();
      case 3:
        return StudentHubPage(
          staffId: staffId,
          role: role == UserRole.therapist ? UserRoleHub.therapist : UserRoleHub.teacher,

          // ✅ NEW: deep link
          initialStudId: hubInitialStudId,
          onConsumedInitial: () {
            if (mounted) setState(() => hubInitialStudId = null);
          },
        );

      default:
        return _buildHomeDashboard();
    }
  }

  // ====== MAIN BUILD ======
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // ANDROID: icon hitam
        statusBarBrightness: Brightness.light, // iOS: text hitam
      ),
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (_isWide) _buildRail(theme),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildCurrentBody(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _isWide ? null : _buildBottomNav(),
      ),
    );
  }

  // ====== NavigationRail (iPad / Wide) ======
  Widget _buildRail(ThemeData theme) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            height: 4.h,
            width: 6.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.school_rounded,
              size: 2.5.h,
              color: Growkids.purpleFlo,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'KIZZU',
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.sp, color: Colors.white),
          ),
          SizedBox(height: 2.h),
          Expanded(
            child: NavigationRailTheme(
              data: NavigationRailThemeData(
                minWidth: 88, // 👈 bigger tap area (kotak)
                minExtendedWidth: 88,
                indicatorColor: Colors.white,
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                selectedIconTheme: IconThemeData(
                  size: 2.h, // ✅ BIG ICON
                  color: Growkids.purpleFlo,
                ),
                unselectedIconTheme: IconThemeData(
                  size: 2.h, // ✅ BIG ICON
                  color: Colors.white,
                ),
                selectedLabelTextStyle: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Growkids.purple,
                ),
                unselectedLabelTextStyle: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              child: NavigationRail(
                selectedIndex: navIndex,
                onDestinationSelected: (i) => setState(() => navIndex = i),
                backgroundColor: Growkids.purpleFlo,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(
                      Icons.home_rounded,
                    ),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_rounded),
                    label: Text('Schedule'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.grid_view_rounded),
                    label: Text('Activity'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_rounded),
                    label: Text('Profile'),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 3.h,
            ),
            tooltip: 'Logout',
          ),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  // ====== Bottom Nav (Phone / Narrow) ======
  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: navIndex,
      onDestinationSelected: (i) => setState(() => navIndex = i),
      indicatorColor: Growkids.purple.withOpacity(0.14),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Activity'),
        NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  // ====== HOME DASHBOARD (Role-aware) ======
  // ✅ CHANGED: iPad uses ONE centered column (no side panel)
  Widget _buildHomeDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight, // screen height minimum
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: _isWide ? 18 : 14,
              ),
              child: Align(
                alignment: Alignment.topCenter, // ✅ stay at top, still horizontally centered
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: _buildMainColumn(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainColumn() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PremiumHeader(
          greeting: _greeting,
          name: staffName.isEmpty ? 'Staff' : staffName,
          roleLabel: _roleLabel,
          staffNo: staffNo.isEmpty ? '-' : staffNo,
          onProfileTap: () => setState(() => navIndex = 3),
          onMoreTap: () => _showQuickMenu(),
        ),

        // ✅ NEW: Today at a glance UNDER the header
        const SizedBox(height: 12),
        _buildAtAGlanceCard(),
        const SizedBox(height: 18),

        Text(
          'Quick actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14.sp,
              ),
        ),
        const SizedBox(height: 10),
        _buildQuickActions(),

        const SizedBox(height: 18),

        if (role == UserRole.therapist) ...[
          _buildStudentListSection(),
        ] else ...[
          _buildStudentKSSListSection(),
        ],

        const SizedBox(height: 18),
      ],
    );
  }

  // ✅ NEW: Today-at-a-glance card (moved from side column)
  Widget _buildAtAGlanceCard() {
    final isTherapist = role == UserRole.therapist;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Today at a glance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.sp,
                    ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEE, d MMM').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black.withOpacity(0.55),
                      fontSize: 14.sp,
                    ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3, // adjust height (bigger = flatter)
            children: [
              _StatChip(
                label: isTherapist ? 'Students' : 'Students',
                value: isTherapist ? studentData.length.toString() : studentKSSData.length.toString(),
                icon: Icons.groups_rounded,
              ),
              _StatChip(
                label: isTherapist ? 'Screenings today' : 'Updates today',
                value: isTherapist ? todayScreeningData.length.toString() : _teacherSubmittedTodayCount.toString(),
                icon: isTherapist ? Icons.fact_check_rounded : Icons.edit_note_rounded,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Tip',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.sp,
                  color: Colors.black.withOpacity(0.60),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            isTherapist
                ? 'Tap “Screenings Today” to jump straight into the list.'
                : 'Keep daily updates short, consistent, and parent-friendly.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black.withOpacity(0.65),
                  height: 1.3,
                  fontSize: 12.sp,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    if (role == UserRole.therapist) {
      return _ResponsiveGrid(
        minTileWidth: _isWide ? 10.0 : 12.0,
        forcedCount: _isWide ? 2 : null, // ✅ forces 2 columns on iPad/wide
        children: [
          _ActionTile(
            title: 'Screenings Today',
            subtitle: '${todayScreeningData.length} scheduled',
            icon: Icons.fact_check_rounded,
            accent: const Color(0xFF0AAE7A),
            onTap: () async {
              await _openScheduleListToday();
            },
          ),
          _ActionTile(
            title: 'All Screenings',
            subtitle: 'View history & progress',
            icon: Icons.list_alt_rounded,
            accent: const Color(0xFF3B82F6),
            onTap: () {
              setState(() {
                therapistActivityInitialTab = ActTab.recent; // ✅ buka recent
                navIndex = 2; // ✅ pergi Activity
              });
            },
          ),
        ],
      );
    }

    return _ResponsiveGrid(
      minTileWidth: _isWide ? 10.0 : 12.0,
      forcedCount: _isWide ? 2 : null, // ✅ forces 2 columns on
      children: [
        _ActionTile(
          title: 'Daily Progress',
          subtitle: 'Update today’s progress',
          icon: Icons.edit_note_rounded,
          accent: Growkids.purple,
          onTap: () {
            setState(() => navIndex = 2); // ✅ Activity tab
          },
        ),

        /*_ActionTile(
          title: 'Parent Updates',
          subtitle: 'Messages & notes',
          icon: Icons.forum_rounded,
          accent: const Color(0xFF0AAE7A),
          onTap: () {
            _snack('Parent Updates page not linked yet.');
          },
        ),*/
        _ActionTile(
          title: 'Attendance',
          subtitle: 'Coming soon',
          icon: Icons.how_to_reg_rounded,
          accent: const Color(0xFF3B82F6),
          onTap: () {
            _snack('Attendance is planned for future release.');
          },
          disabled: true,
        ),
      ],
    );
  }

  Widget _buildStudentListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'My students',
          trailing: _buildSearchBar(),
        ),
        const SizedBox(height: 10),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (filteredData.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'No students found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black.withOpacity(0.6),
                          ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredData.length > 8 ? 8 : filteredData.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 16,
                    color: Colors.black.withOpacity(0.06),
                  ),
                  itemBuilder: (context, i) {
                    final s = filteredData[i];
                    final name = (s['stud_name'] ?? '-').toString();
                    final age = (s['age'] ?? '-').toString();
                    final months = (s['ageMonths'] ?? '-').toString();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 2.h,
                        backgroundColor: Growkids.purple.withOpacity(0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Growkids.purple,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14.sp,
                        ),
                      ),
                      subtitle: Text(
                        '$age • $months',
                        style: TextStyle(
                          fontSize: 12.sp,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black.withOpacity(0.35),
                        size: 3.h,
                      ),
                      onTap: () {
                        setState(() {
                          hubInitialStudId = s['stud_id'].toString(); // ✅ student to open
                          navIndex = 3; // ✅ go StudentHub tab
                        });
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentKSSListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'My students',
          trailing: _buildSearchBar(),
        ),
        const SizedBox(height: 10),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (filteredKSSData.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'No students found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black.withOpacity(0.6),
                          ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredKSSData.length > 8 ? 8 : filteredKSSData.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 16,
                    color: Colors.black.withOpacity(0.06),
                  ),
                  itemBuilder: (context, i) {
                    final s = filteredKSSData[i];
                    final name = (s['stud_name'] ?? '-').toString();
                    final age = (s['age'] ?? '-').toString();
                    final months = (s['ageMonths'] ?? '-').toString();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 2.h,
                        backgroundColor: Growkids.purple.withOpacity(0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Growkids.purple,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14.sp,
                        ),
                      ),
                      subtitle: Text(
                        '$age • $months',
                        style: TextStyle(
                          fontSize: 12.sp,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black.withOpacity(0.35),
                        size: 3.h,
                      ),
                      onTap: () {
                        setState(() {
                          hubInitialStudId = s['stud_id'].toString(); // ✅ student to open
                          navIndex = 3; // ✅ go StudentHub tab
                        });
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      width: _isWide ? 360 : 220,
      child: TextField(
        controller: searchCtrl,
        onChanged: role == UserRole.therapist ? _filter : _filterKSS,
        decoration: InputDecoration(
          hintText: 'Search student...',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Growkids.purpleFlo.withOpacity(0.2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Growkids.purple.withOpacity(0.6)),
          ),
        ),
      ),
    );
  }

  // ====== Activity pages ======
  Widget _buildTherapistActivity() {
    return TherapistActivityPage(
      therapistId: staffId,
      initialTab: therapistActivityInitialTab ?? ActTab.today,
      onConsumedInitialTab: () {
        // ✅ reset after used once
        if (mounted) setState(() => therapistActivityInitialTab = null);
      },
    );
  }

  Widget _buildTeacherActivity() {
    return TeacherActivityPage(teacherId: staffId);
  }

  // ====== menus / snack ======
  void _showQuickMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            runSpacing: 8,
            children: [
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => navIndex = 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Refresh'),
                onTap: () async {
                  Navigator.pop(context);
                  await _refresh();
                },
              ),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: Colors.red.withOpacity(0.8)),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

// ==========================
// UI COMPONENTS (Premium)
// ==========================

class _PremiumHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String roleLabel;
  final String staffNo;
  final VoidCallback onProfileTap;
  final VoidCallback onMoreTap;

  const _PremiumHeader({
    required this.greeting,
    required this.name,
    required this.roleLabel,
    required this.staffNo,
    required this.onProfileTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MainCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Growkids.purpleFlo,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 14.sp,
                      ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 16.sp,
                        color: Colors.white,
                      ),
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 8,
                  children: [
                    _Pill(text: roleLabel, icon: Icons.verified_user_rounded),
                    _Pill(text: staffNo, icon: Icons.badge_rounded),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMoreTap,
            iconSize: 5.h,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Colors.white,
            ),
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
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withOpacity(.70),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 2.h, color: Growkids.purpleFlo),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;
  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14.sp,
                ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final double minTileWidth;
  final List<Widget> children;

  /// If set, grid will use this count instead of auto-calculating.
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
      final count = forcedCount != null ? forcedCount!.clamp(1, 4) : autoCount;

      // ✅ When only 2 columns, make cards a bit "wider" (higher ratio -> less height)
      final ratio = (count == 2) ? 3.35 : 2.55;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: count,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: ratio,
        children: children,
      );
    });
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool disabled;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = disabled ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(1.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 4.h,
                width: 5.w,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent),
              ),
              SizedBox(width: 1.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14.sp,
                          ),
                    ),
                    SizedBox(height: 0.1.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black.withOpacity(0.60),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.sp,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.black.withOpacity(0.35),
                size: 3.h,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.5.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(icon, size: 3.h, color: Growkids.purpleFlo),
          ),
          SizedBox(width: 2.w),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 18.sp),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
