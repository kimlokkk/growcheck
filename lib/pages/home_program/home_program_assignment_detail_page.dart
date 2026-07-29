import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopProgramFeedbackLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class HomeProgramAssignmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String therapistId;

  const HomeProgramAssignmentDetailPage({
    super.key,
    required this.assignment,
    required this.therapistId,
  });

  @override
  State<HomeProgramAssignmentDetailPage> createState() =>
      _HomeProgramAssignmentDetailPageState();
}

class _HomeProgramAssignmentDetailPageState
    extends State<HomeProgramAssignmentDetailPage> {
  static final _getFeedbackUrl =
      ApiConfig.flutter('home_program_get_feedback.php');
  static final _addFeedbackUrl =
      ApiConfig.flutter('home_program_add_feedback.php');

  final _message = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _feedback = [];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String get _assignmentId =>
      (widget.assignment['assignment_id'] ?? '').toString();

  Future<void> _loadFeedback() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(_getFeedbackUrl),
        body: {'assignment_id': _assignmentId},
      );
      final decoded = jsonDecode(res.body);
      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Failed to load feedback');
      }

      final data = decoded['feedback'];
      if (!mounted) return;
      setState(() {
        _feedback = data is List
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

  Future<void> _sendFeedback() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse(_addFeedbackUrl),
        body: {
          'assignment_id': _assignmentId,
          'sender_type': 'therapist',
          'sender_id': widget.therapistId,
          'message': text,
        },
      );
      final decoded = jsonDecode(res.body);
      if (decoded['status'] == 'success') {
        _message.clear();
        await _loadFeedback();
      } else {
        _snack(decoded['message'] ?? 'Failed to send feedback.');
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopProgramFeedbackLayout(context)) {
      return _buildDesktop();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Program Feedback'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadFeedback,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFeedback,
              child: ListView(
                padding: EdgeInsets.all(2.h),
                children: [
                  _AssignmentSummary(assignment: widget.assignment),
                  SizedBox(height: 2.h),
                  _ThreadSection(
                    title: 'Feedback Thread',
                    icon: Icons.forum_rounded,
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Growkids.purpleFlo,
                              ),
                            ),
                          )
                        : _error != null
                            ? _MessageCard(text: _error!, isError: true)
                            : _feedback.isEmpty
                                ? const _MessageCard(text: 'No feedback yet.')
                                : _FeedbackThread(items: _feedback),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.all(2.h),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  IconButton.filled(
                    padding: EdgeInsets.all(1.5.h),
                    onPressed: _sending ? null : _sendFeedback,
                    style: IconButton.styleFrom(
                      backgroundColor: Growkids.purpleFlo,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? SizedBox(
                            height: 2.h,
                            width: 2.h,
                            child:
                                const CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: const Text(
          'Program Feedback',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh feedback',
            onPressed: _loading ? null : _loadFeedback,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1380),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 360, child: _desktopAssignmentPanel()),
                const SizedBox(width: 20),
                Expanded(child: _desktopConversationPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopAssignmentPanel() {
    final assignment = widget.assignment;
    final title =
        (assignment['material_title'] ?? 'Untitled material').toString();
    final category = (assignment['material_category'] ?? 'General').toString();
    final student = (assignment['stud_name'] ?? 'Unnamed student').toString();
    final note = (assignment['therapist_note'] ?? '').toString().trim();
    final fileCount = (assignment['file_count'] ?? '1').toString();
    final status = (assignment['status'] ?? 'new').toString();
    final statusConfig = _desktopStatusConfig(status);
    final assignedAt = _formatFriendlyDateTime(
      (assignment['assigned_at'] ?? '').toString(),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Growkids.purpleFlo,
                  Growkids.purpleFlo.withValues(alpha: 0.74),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x223F2A91),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: Growkids.purple,
                  ),
                ),
                const SizedBox(height: 17),
                const Text(
                  'ASSIGNED PROGRAM',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 13),
                _desktopStatusChip(statusConfig.$2, statusConfig.$1),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _desktopSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Program details',
                  style: TextStyle(
                    color: Color(0xFF242735),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 17),
                _desktopDetailRow(
                    Icons.person_outline_rounded, 'Student', student),
                const SizedBox(height: 14),
                _desktopDetailRow(
                    Icons.category_outlined, 'Category', category),
                const SizedBox(height: 14),
                _desktopDetailRow(
                  Icons.attach_file_rounded,
                  'Materials',
                  '$fileCount file${fileCount == '1' ? '' : 's'}',
                ),
                if (assignedAt.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _desktopDetailRow(
                    Icons.schedule_rounded,
                    'Assigned',
                    assignedAt,
                  ),
                ],
              ],
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 16),
            _desktopSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        color: Growkids.purple,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Therapist note',
                        style: TextStyle(
                          color: Color(0xFF242735),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xFF666B79),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopConversationPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE7E9F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Growkids.purple.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    color: Growkids.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Feedback thread',
                    style: TextStyle(
                      color: Color(0xFF242735),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Growkids.purple.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${_feedback.length} messages',
                    style: const TextStyle(
                      color: Growkids.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _desktopThreadBody()),
          _desktopComposer(),
        ],
      ),
    );
  }

  Widget _desktopThreadBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Growkids.purpleFlo),
      );
    }
    if (_error != null) {
      return _desktopConversationMessage(
        _error!,
        Icons.error_outline_rounded,
        Colors.red,
      );
    }
    if (_feedback.isEmpty) {
      return _desktopConversationMessage(
        'No feedback yet. Start the conversation below.',
        Icons.chat_bubble_outline_rounded,
        const Color(0xFF9A9EAA),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _feedback.length,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (context, index) => _desktopFeedbackBubble(_feedback[index]),
    );
  }

  Widget _desktopFeedbackBubble(Map<String, dynamic> item) {
    final isTherapist = (item['sender_type'] ?? '').toString() == 'therapist';
    final message = (item['message'] ?? '').toString();
    final createdAt = _formatFriendlyDateTime(
      (item['created_at'] ?? '').toString(),
    );

    return Align(
      alignment: isTherapist ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: isTherapist
                ? Growkids.purple.withValues(alpha: 0.10)
                : const Color(0xFFF3F4F7),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isTherapist ? 16 : 4),
              bottomRight: Radius.circular(isTherapist ? 4 : 16),
            ),
            border: Border.all(
              color: isTherapist
                  ? Growkids.purple.withValues(alpha: 0.13)
                  : const Color(0xFFE7E9F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isTherapist ? 'Therapist' : 'Parent',
                    style: TextStyle(
                      color: isTherapist
                          ? Growkids.purple
                          : const Color(0xFF656A78),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      createdAt,
                      style: const TextStyle(
                        color: Color(0xFF9296A3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF3F4350),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE7E9F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _message,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: const TextStyle(color: Color(0xFF9A9EAA)),
                filled: true,
                fillColor: const Color(0xFFF5F6F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            height: 46,
            child: IconButton.filled(
              tooltip: 'Send feedback',
              onPressed: _sending ? null : _sendFeedback,
              style: IconButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white,
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopConversationMessage(
    String message,
    IconData icon,
    Color color,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F2F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF717685)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9296A3),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF424654),
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _desktopStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AssignmentSummary extends StatelessWidget {
  final Map<String, dynamic> assignment;

  const _AssignmentSummary({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final title =
        (assignment['material_title'] ?? 'Untitled material').toString();
    final category = (assignment['material_category'] ?? 'General').toString();
    final student = (assignment['stud_name'] ?? 'Unnamed student').toString();
    final note = (assignment['therapist_note'] ?? '').toString().trim();
    final fileCount = (assignment['file_count'] ?? '1').toString();

    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 1.h,
            runSpacing: 1.h,
            children: [
              _MetaChip(icon: Icons.category_rounded, text: category),
              _MetaChip(icon: Icons.person_rounded, text: student),
              _MetaChip(
                icon: Icons.attach_file_rounded,
                text: '$fileCount file${fileCount == '1' ? '' : 's'}',
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              'Therapist Note',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.72),
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThreadSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ThreadSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(1.8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Growkids.purpleFlo, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.4.h),
          child,
        ],
      ),
    );
  }
}

class _FeedbackThread extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _FeedbackThread({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (index) {
        return _FeedbackThreadItem(
          item: items[index],
          isLast: index == items.length - 1,
        );
      }),
    );
  }
}

class _FeedbackThreadItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;

  const _FeedbackThreadItem({
    required this.item,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final senderType = (item['sender_type'] ?? '').toString();
    final isTherapist = senderType == 'therapist';
    final message = (item['message'] ?? '').toString();
    final createdAt = _formatFriendlyDateTime(
      (item['created_at'] ?? '').toString(),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: isTherapist
                      ? Growkids.purpleFlo
                      : Colors.black.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 1.4.h),
              padding: EdgeInsets.all(1.4.h),
              decoration: BoxDecoration(
                color: isTherapist
                    ? Growkids.purpleFlo.withValues(alpha: 0.10)
                    : const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTherapist ? 'Therapist' : 'Parent',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: isTherapist
                                ? Growkids.purpleFlo
                                : Colors.black.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                      if (createdAt.isNotEmpty)
                        Expanded(
                          flex: 2,
                          child: Text(
                            createdAt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.black.withValues(alpha: 0.86),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            constraints: BoxConstraints(maxWidth: 64.w),
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
      ),
      child: Text(text),
    );
  }
}
