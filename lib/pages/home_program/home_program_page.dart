import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/home_program/home_program_assign_page.dart';
import 'package:growcheck_app_v2/pages/home_program/home_program_assignments_page.dart';
import 'package:growcheck_app_v2/pages/home_program/home_program_material_library_page.dart';
import 'package:growcheck_app_v2/pages/home_program/home_program_upload_material_page.dart';
import 'package:growcheck_app_v2/pages/student_hub/student_hub.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopHomeProgramLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class HomeProgramPage extends StatefulWidget {
  final String therapistId;
  final String therapistName;
  final UserRoleHub role;

  const HomeProgramPage({
    super.key,
    required this.therapistId,
    required this.therapistName,
    required this.role,
  });

  @override
  State<HomeProgramPage> createState() => _HomeProgramPageState();
}

class _HomeProgramPageState extends State<HomeProgramPage> {
  static final _statsUrl = ApiConfig.flutter('home_program_get_stats.php');

  /*static const _statsUrl =
      'http://app-kizzu.test/growkids/flutter/home_program_get_stats.php';*/

  bool _loadingStats = true;
  String? _statsError;
  int _materials = 0;
  int _assigned = 0;
  int _feedback = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loadingStats = true;
      _statsError = null;
    });

    try {
      final res = await http.post(
        Uri.parse(_statsUrl),
        body: {'therapist_id': widget.therapistId},
      );
      final decoded = jsonDecode(res.body);

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Failed to load stats');
      }

      final stats = decoded['stats'] is Map ? decoded['stats'] as Map : {};
      if (!mounted) return;
      setState(() {
        _materials = _toInt(stats['materials']);
        _assigned = _toInt(stats['assigned']);
        _feedback = _toInt(stats['feedback']);
        _loadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsError = e.toString();
        _loadingStats = false;
      });
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopHomeProgramLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Home Program'),
        actions: [
          IconButton(
            onPressed: _loadingStats ? null : _loadStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 2.h),
          children: [
            _HeaderCard(therapistName: widget.therapistName),
            SizedBox(height: 2.h),
            _StatsRow(
              stats: [
                _ProgramStat(
                  label: 'Materials',
                  value: _loadingStats ? '-' : _materials.toString(),
                  icon: Icons.description_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                _ProgramStat(
                  label: 'Assigned',
                  value: _loadingStats ? '-' : _assigned.toString(),
                  icon: Icons.send_rounded,
                  color: const Color(0xFF14B8A6),
                ),
                _ProgramStat(
                  label: 'Feedback',
                  value: _loadingStats ? '-' : _feedback.toString(),
                  icon: Icons.forum_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
            if (_statsError != null) ...[
              SizedBox(height: 1.h),
              _StatsErrorBar(message: _statsError!, onRetry: _loadStats),
            ],
            SizedBox(height: 2.h),
            const _SectionTitle(
              title: 'Quick Actions',
              subtitle:
                  'Upload documents, assign to official students, and review parent replies.',
            ),
            SizedBox(height: 2.h),
            _ActionGrid(
              children: [
                _ActionCard(
                  title: 'Material Library',
                  subtitle: 'PDF and DOCX resources',
                  icon: Icons.folder_copy_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomeProgramMaterialLibraryPage(),
                      ),
                    );
                  },
                ),
                _ActionCard(
                  title: 'Upload Material',
                  subtitle: 'Add PDF or DOCX',
                  icon: Icons.upload_file_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomeProgramUploadMaterialPage(
                          therapistId: widget.therapistId,
                          therapistName: widget.therapistName,
                        ),
                      ),
                    );
                    if (mounted) _loadStats();
                  },
                ),
                _ActionCard(
                  title: 'Assign Program',
                  subtitle: 'Send to parent',
                  icon: Icons.assignment_ind_rounded,
                  color: const Color(0xFF14B8A6),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomeProgramAssignPage(
                          staffId: widget.therapistId,
                          role: widget.role,
                        ),
                      ),
                    );
                    if (mounted) _loadStats();
                  },
                ),
                _ActionCard(
                  title: 'Assigned Programs',
                  subtitle: 'Track parent progress',
                  icon: Icons.mark_chat_unread_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomeProgramAssignmentsPage(
                          therapistId: widget.therapistId,
                        ),
                      ),
                    );
                    if (mounted) _loadStats();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Home Program',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadingStats ? null : _loadStats,
            tooltip: 'Refresh dashboard',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _desktopHero(),
                  if (_statsError != null) ...[
                    const SizedBox(height: 13),
                    _StatsErrorBar(
                      message: _statsError!,
                      onRetry: _loadStats,
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Workspace',
                    style: TextStyle(
                      color: Color(0xFF292B35),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Manage resources, assign activities, and monitor parent feedback.',
                    style: TextStyle(
                      color: Color(0xFF858A98),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: GridView(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 138,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          children: [
                            _desktopActionCard(
                              title: 'Material Library',
                              subtitle:
                                  'Browse and manage reusable PDF and DOCX resources.',
                              footnote: '$_materials available materials',
                              icon: Icons.folder_copy_rounded,
                              color: const Color(0xFF3978F6),
                              onTap: _openMaterialLibrary,
                            ),
                            _desktopActionCard(
                              title: 'Upload Material',
                              subtitle:
                                  'Add a new therapy resource to the shared library.',
                              footnote: 'PDF and DOCX supported',
                              icon: Icons.upload_file_rounded,
                              color: const Color(0xFF8B5CF6),
                              onTap: _openUploadMaterial,
                            ),
                            _desktopActionCard(
                              title: 'Assign Program',
                              subtitle:
                                  'Choose a student, activity, instructions, and schedule.',
                              footnote: 'Create a new assignment',
                              icon: Icons.assignment_ind_rounded,
                              color: const Color(0xFF14A98C),
                              onTap: _openAssignProgram,
                            ),
                            _desktopActionCard(
                              title: 'Assigned Programs',
                              subtitle:
                                  'Track completion status and review feedback from parents.',
                              footnote:
                                  '$_assigned assigned · $_feedback feedback',
                              icon: Icons.mark_chat_unread_rounded,
                              color: const Color(0xFFF29A18),
                              onTap: _openAssignedPrograms,
                            ),
                          ],
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
    );
  }

  Widget _desktopHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 23),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .76),
          ],
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              Icons.home_work_rounded,
              color: Growkids.purpleFlo,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THERAPY BEYOND THE CENTRE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Home Program',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Welcome, ${widget.therapistName}. Prepare activities and support families at home.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          _desktopMetric(
            icon: Icons.description_rounded,
            value: _loadingStats ? '-' : '$_materials',
            label: 'Materials',
            accent: const Color(0xFFBFD5FF),
          ),
          const SizedBox(width: 11),
          _desktopMetric(
            icon: Icons.send_rounded,
            value: _loadingStats ? '-' : '$_assigned',
            label: 'Assigned',
            accent: const Color(0xFF8EE7BC),
          ),
          const SizedBox(width: 11),
          _desktopMetric(
            icon: Icons.forum_rounded,
            value: _loadingStats ? '-' : '$_feedback',
            label: 'Feedback',
            accent: const Color(0xFFFFD68A),
          ),
        ],
      ),
    );
  }

  Widget _desktopMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 19),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopActionCard({
    required String title,
    required String subtitle,
    required String footnote,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E7EE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF555B6D).withValues(alpha: .06),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF30323C),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7D8290),
                      fontSize: 8,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    footnote,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, color: color, size: 21),
          ],
        ),
      ),
    );
  }

  void _openMaterialLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeProgramMaterialLibraryPage(),
      ),
    );
  }

  Future<void> _openUploadMaterial() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeProgramUploadMaterialPage(
          therapistId: widget.therapistId,
          therapistName: widget.therapistName,
        ),
      ),
    );
    if (mounted) _loadStats();
  }

  Future<void> _openAssignProgram() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeProgramAssignPage(
          staffId: widget.therapistId,
          role: widget.role,
        ),
      ),
    );
    if (mounted) _loadStats();
  }

  Future<void> _openAssignedPrograms() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeProgramAssignmentsPage(
          therapistId: widget.therapistId,
        ),
      ),
    );
    if (mounted) _loadStats();
  }
}

class _HeaderCard extends StatelessWidget {
  final String therapistName;

  const _HeaderCard({required this.therapistName});

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
            Growkids.purpleFlo.withValues(alpha: .70),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.home_work_rounded,
              color: Growkids.purpleFlo,
              size: 4.h,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Home Program',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 17.sp,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_ProgramStat> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: stat == stats.last ? 0 : 1.h,
                ),
                child: _StatCard(stat: stat),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatsErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StatsErrorBar({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_rounded,
            color: Color(0xFFEA580C),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF9A3412)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ProgramStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProgramStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _ProgramStat stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: stat.color, size: 4.h),
          SizedBox(height: 1.h),
          Text(
            stat.value,
            style: TextStyle(fontSize: 17.sp),
          ),
          SizedBox(height: 0.5.h),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.58),
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16.sp),
        ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final List<Widget> children;

  const _ActionGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 3,
      children: children,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(1.5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 6.h,
              height: 6.h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 3.h),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
