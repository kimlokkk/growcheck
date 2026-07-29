import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart' show ApiConfig;
import 'package:growcheck_app_v2/pages/home_program/home_program_assignment_detail_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopHomeProgramAssignmentsLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class HomeProgramAssignmentsPage extends StatefulWidget {
  final String therapistId;

  const HomeProgramAssignmentsPage({
    super.key,
    required this.therapistId,
  });

  @override
  State<HomeProgramAssignmentsPage> createState() =>
      _HomeProgramAssignmentsPageState();
}

class _HomeProgramAssignmentsPageState
    extends State<HomeProgramAssignmentsPage> {
  static final _url = ApiConfig.flutter('home_program_get_assignments.php');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(_url),
        body: {'therapist_id': widget.therapistId},
      );
      final decoded = jsonDecode(res.body);

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Failed to load assignments');
      }

      final data = decoded['assignments'];
      if (!mounted) return;
      setState(() {
        _assignments = data is List
            ? data.map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopHomeProgramAssignmentsLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Assigned Programs'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Growkids.purpleFlo),
              )
            : ListView(
                padding: EdgeInsets.all(2.h),
                children: [
                  _Header(assignments: _assignments),
                  SizedBox(height: 1.5.h),
                  if (_error != null)
                    _MessageCard(text: _error!, isError: true)
                  else if (_assignments.isEmpty)
                    const _MessageCard(text: 'No programs assigned yet.')
                  else
                    ..._assignments.map(
                      (assignment) => _AssignmentCard(
                        assignment: assignment,
                        therapistId: widget.therapistId,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final completed = _assignments.where((item) {
      return (item['status'] ?? '').toString().toLowerCase() == 'completed';
    }).length;
    final pending = _assignments.length - completed;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Assigned Programs',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 27, vertical: 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Growkids.purpleFlo,
                        Growkids.purpleFlo.withValues(alpha: .76),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.assignment_turned_in_rounded,
                          color: Growkids.purpleFlo,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOME PROGRAM TRACKING',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Assigned Programs',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Monitor progress and review feedback from families.',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      _desktopAssignmentMetric(
                        'Sent',
                        _assignments.length,
                        Icons.send_rounded,
                      ),
                      const SizedBox(width: 10),
                      _desktopAssignmentMetric(
                        'Pending',
                        pending,
                        Icons.pending_actions_rounded,
                      ),
                      const SizedBox(width: 10),
                      _desktopAssignmentMetric(
                        'Completed',
                        completed,
                        Icons.task_alt_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Growkids.purpleFlo,
                          ),
                        )
                      : _error != null
                          ? _MessageCard(text: _error!, isError: true)
                          : _assignments.isEmpty
                              ? const _MessageCard(
                                  text: 'No programs assigned yet.',
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisExtent: 190,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                                  itemCount: _assignments.length,
                                  itemBuilder: (_, index) =>
                                      _DesktopAssignmentCard(
                                    assignment: _assignments[index],
                                    therapistId: widget.therapistId,
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopAssignmentMetric(
    String label,
    int value,
    IconData icon,
  ) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 17),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopAssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final String therapistId;

  const _DesktopAssignmentCard({
    required this.assignment,
    required this.therapistId,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        (assignment['material_title'] ?? 'Untitled material').toString();
    final category = (assignment['material_category'] ?? 'General').toString();
    final student = (assignment['stud_name'] ?? 'Unnamed student').toString();
    final status = (assignment['status'] ?? 'new').toString();
    final fileCount = (assignment['file_count'] ?? '1').toString();
    final assignedAt =
        _formatFriendlyDateTime((assignment['assigned_at'] ?? '').toString());

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomeProgramAssignmentDetailPage(
            assignment: assignment,
            therapistId: therapistId,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E6EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_shared_rounded,
                    color: Growkids.purpleFlo,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF30323C),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category,
                        style: const TextStyle(
                          color: Color(0xFF8A8F9C),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                _DesktopStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _DesktopMetaChip(icon: Icons.person_rounded, text: student),
                _DesktopMetaChip(
                  icon: Icons.attach_file_rounded,
                  text: '$fileCount file${fileCount == '1' ? '' : 's'}',
                ),
                if (assignedAt.isNotEmpty)
                  _DesktopMetaChip(
                    icon: Icons.schedule_rounded,
                    text: assignedAt,
                  ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Open feedback',
                  style: TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Growkids.purpleFlo,
                  size: 17,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopStatusChip extends StatelessWidget {
  final String status;
  const _DesktopStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final config = switch (normalized) {
      'completed' => (const Color(0xFF16A34A), 'Completed'),
      'viewed' => (const Color(0xFF2563EB), 'Viewed'),
      'in_progress' => (const Color(0xFFF59E0B), 'In Progress'),
      _ => (const Color(0xFF64748B), 'New'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: config.$1.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config.$2,
        style: TextStyle(
          color: config.$1,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DesktopMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DesktopMetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7C818E)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF6F7481), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final List<Map<String, dynamic>> assignments;

  const _Header({required this.assignments});

  @override
  Widget build(BuildContext context) {
    final completed = assignments.where((item) {
      return (item['status'] ?? '').toString().toLowerCase() == 'completed';
    }).length;

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
              Icons.assignment_turned_in_rounded,
              color: Growkids.purpleFlo,
              size: 4.h,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Programs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.sp,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${assignments.length} sent • $completed completed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13.sp,
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

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final String therapistId;

  const _AssignmentCard({
    required this.assignment,
    required this.therapistId,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        (assignment['material_title'] ?? 'Untitled material').toString();
    final category = (assignment['material_category'] ?? 'General').toString();
    final student = (assignment['stud_name'] ?? 'Unnamed student').toString();
    final branch = (assignment['stud_branch'] ?? '').toString();
    final note = (assignment['therapist_note'] ?? '').toString().trim();
    final fileCount = (assignment['file_count'] ?? '1').toString();
    final assignedAt = _formatFriendlyDateTime(
      (assignment['assigned_at'] ?? '').toString(),
    );
    final status = (assignment['status'] ?? 'new').toString();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HomeProgramAssignmentDetailPage(
              assignment: assignment,
              therapistId: therapistId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 3.h,
                  backgroundColor: Growkids.purpleFlo.withValues(alpha: 0.10),
                  child: Icon(
                    Icons.folder_shared_rounded,
                    color: Growkids.purpleFlo,
                    size: 3.h,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        category,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.56),
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            SizedBox(height: 2.h),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(icon: Icons.person_rounded, text: student),
                if (branch.isNotEmpty)
                  _MetaChip(icon: Icons.location_on_rounded, text: branch),
                _MetaChip(
                  icon: Icons.attach_file_rounded,
                  text: '$fileCount file${fileCount == '1' ? '' : 's'}',
                ),
                if (assignedAt.isNotEmpty)
                  _MetaChip(icon: Icons.schedule_rounded, text: assignedAt),
              ],
            ),
            if (note.isNotEmpty) ...[
              SizedBox(height: 3.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  note,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.72),
                    fontSize: 13.sp,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1.2.h, vertical: 1.h),
              decoration: BoxDecoration(
                color: Growkids.purpleFlo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Open feedback',
                    style: TextStyle(
                      color: Growkids.purpleFlo,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 1.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Growkids.purpleFlo,
                    size: 2.5.h,
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

String _formatFriendlyDateTime(String raw) {
  if (raw.trim().isEmpty) return '';
  final normalized = raw.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return raw;

  final now = DateTime.now();
  final isToday = parsed.year == now.year &&
      parsed.month == now.month &&
      parsed.day == now.day;

  final time = DateFormat('h:mm a').format(parsed);
  if (isToday) return 'Today, $time';

  return '${DateFormat('d MMM yyyy').format(parsed)}, $time';
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final config = switch (normalized) {
      'completed' => (const Color(0xFF16A34A), 'Completed'),
      'viewed' => (const Color(0xFF2563EB), 'Viewed'),
      'in_progress' => (const Color(0xFFF59E0B), 'In Progress'),
      _ => (const Color(0xFF64748B), 'New'),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: config.$1.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        config.$2,
        style: TextStyle(
          color: config.$1,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 2.h, color: Colors.black.withValues(alpha: 0.55)),
          SizedBox(width: 1.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 50.w),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.62),
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _MessageCard({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text),
    );
  }
}
