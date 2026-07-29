import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/home_program/home_program_assignment_detail_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopStudentHomeProgramLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class StudentHomeProgramPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String therapistId;

  const StudentHomeProgramPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.therapistId,
  });

  @override
  State<StudentHomeProgramPage> createState() => _StudentHomeProgramPageState();
}

class _StudentHomeProgramPageState extends State<StudentHomeProgramPage> {
  static final _url =
      ApiConfig.parentsFlutter('home_program_get_parent_assignments.php');

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
        body: {'student_id': widget.studentId},
      );
      final decoded = jsonDecode(res.body);

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Failed to load home programs');
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
    final completed = _assignments.where((item) {
      return (item['status'] ?? '').toString().toLowerCase() == 'completed';
    }).length;

    if (_useDesktopStudentHomeProgramLayout(context)) {
      return _buildDesktop(completed);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Student Home Program'),
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
                  _Header(
                    studentName: widget.studentName,
                    total: _assignments.length,
                    completed: completed,
                  ),
                  SizedBox(height: 1.5.h),
                  if (_error != null)
                    _MessageCard(text: _error!, isError: true)
                  else if (_assignments.isEmpty)
                    const _MessageCard(
                      text: 'No home program assigned for this student yet.',
                    )
                  else
                    ..._assignments.map(
                      (assignment) => _AssignmentCard(
                        assignment: assignment,
                        therapistId: widget.therapistId,
                        onReturned: _load,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktop(int completed) {
    final pending = _assignments.length - completed;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: const Text(
          'Student Home Program',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh programs',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _desktopHeader(completed, pending),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Assigned programs',
                              style: TextStyle(
                                color: Color(0xFF242735),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${_assignments.length} program${_assignments.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Color(0xFF777C8B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_error != null)
                        _desktopMessage(_error!, isError: true)
                      else if (_assignments.isEmpty)
                        _desktopMessage(
                          'No home program assigned for this student yet.',
                        )
                      else
                        _desktopAssignmentGrid(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopHeader(int completed, int pending) {
    final initial = widget.studentName.trim().isEmpty
        ? '?'
        : widget.studentName.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x253F2A91),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Growkids.purple,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HOME PROGRAM',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Track assigned activities and completion progress.',
                  style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
          _desktopStat(
            'Assigned',
            _assignments.length,
            Icons.assignment_outlined,
          ),
          const SizedBox(width: 10),
          _desktopStat('Done', completed, Icons.check_circle_outline_rounded),
          const SizedBox(width: 10),
          _desktopStat('Pending', pending, Icons.pending_actions_rounded),
        ],
      ),
    );
  }

  Widget _desktopStat(String label, int value, IconData icon) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopAssignmentGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final width = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _assignments
              .map(
                (assignment) => SizedBox(
                  width: width,
                  child: _desktopAssignmentCard(assignment),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _desktopAssignmentCard(Map<String, dynamic> assignment) {
    final title =
        (assignment['material_title'] ?? 'Untitled material').toString();
    final category = (assignment['material_category'] ?? 'General').toString();
    final note = (assignment['therapist_note'] ?? '').toString().trim();
    final fileCount = (assignment['file_count'] ?? '1').toString();
    final assignedAt = _formatFriendlyDateTime(
      (assignment['assigned_at'] ?? '').toString(),
    );
    final status = (assignment['status'] ?? 'new').toString();
    final statusConfig = _desktopStatusConfig(status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openAssignment(assignment),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E5ED)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0E1635),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Growkids.purple.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: Growkids.purple,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF292C39),
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _desktopChip(
                    statusConfig.$2,
                    statusConfig.$1,
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6D7280),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _desktopMeta(Icons.category_outlined, category),
                  _desktopMeta(
                    Icons.attach_file_rounded,
                    '$fileCount file${fileCount == '1' ? '' : 's'}',
                  ),
                  if (assignedAt.isNotEmpty)
                    _desktopMeta(Icons.schedule_rounded, assignedAt),
                ],
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View program',
                    style: TextStyle(
                      color: Growkids.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: Growkids.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, String) _desktopStatusConfig(String status) {
    return switch (status.toLowerCase()) {
      'completed' => (const Color(0xFF16A34A), 'Completed'),
      'viewed' => (const Color(0xFF2563EB), 'Viewed'),
      'in_progress' => (const Color(0xFFF59E0B), 'In Progress'),
      _ => (const Color(0xFF64748B), 'New'),
    };
  }

  Widget _desktopChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _desktopMeta(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF717685)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF656A78),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopMessage(String message, {bool isError = false}) {
    return Container(
      height: 260,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.home_work_outlined,
            size: 50,
            color: isError ? Colors.red : const Color(0xFFC6C9D2),
          ),
          const SizedBox(height: 13),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isError ? Colors.red : const Color(0xFF777C8B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAssignment(Map<String, dynamic> assignment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeProgramAssignmentDetailPage(
          assignment: assignment,
          therapistId: widget.therapistId,
        ),
      ),
    );
    await _load();
  }
}

class _Header extends StatelessWidget {
  final String studentName;
  final int total;
  final int completed;

  const _Header({
    required this.studentName,
    required this.total,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final pending = total - completed;

    return Column(
      children: [
        Container(
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
              SizedBox(width: 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Home Program',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.2.h),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Assigned',
                  value: total.toString(),
                  icon: Icons.assignment_rounded,
                  color: Growkids.purpleFlo,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatItem(
                  label: 'Done',
                  value: completed.toString(),
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF16A34A),
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatItem(
                  label: 'Pending',
                  value: pending.toString(),
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 16.sp),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: Colors.black.withValues(alpha: 0.06),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final String therapistId;
  final Future<void> Function() onReturned;

  const _AssignmentCard({
    required this.assignment,
    required this.therapistId,
    required this.onReturned,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        (assignment['material_title'] ?? 'Untitled material').toString();
    final category = (assignment['material_category'] ?? 'General').toString();
    final note = (assignment['therapist_note'] ?? '').toString().trim();
    final fileCount = (assignment['file_count'] ?? '1').toString();
    final assignedAt = _formatFriendlyDateTime(
      (assignment['assigned_at'] ?? '').toString(),
    );
    final status = (assignment['status'] ?? 'new').toString();

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HomeProgramAssignmentDetailPage(
              assignment: assignment,
              therapistId: therapistId,
            ),
          ),
        );
        await onReturned();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
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
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: Growkids.purpleFlo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
              ],
            ),
            if (note.isNotEmpty) ...[
              SizedBox(height: 1.h),
              Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.72),
                  fontSize: 12.sp,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: 1.2.h),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaChip(icon: Icons.category_rounded, text: category),
                      _MetaChip(
                        icon: Icons.attach_file_rounded,
                        text: '$fileCount file${fileCount == '1' ? '' : 's'}',
                      ),
                      if (assignedAt.isNotEmpty)
                        _MetaChip(
                          icon: Icons.schedule_rounded,
                          text: assignedAt,
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Growkids.purpleFlo,
                ),
              ],
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
          fontSize: 12.sp,
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
          Icon(icon, size: 14, color: Colors.black.withValues(alpha: 0.55)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 58.w),
            child: Text(
              text,
              maxLines: 1,
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Text(text),
    );
  }
}
