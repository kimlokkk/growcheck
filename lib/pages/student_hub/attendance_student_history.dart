import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

bool _useDesktopAttendanceHistoryLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class StudentAttendanceHistoryPage extends StatefulWidget {
  final String studId;
  final String studentName;

  const StudentAttendanceHistoryPage({
    super.key,
    required this.studId,
    required this.studentName,
  });

  @override
  State<StudentAttendanceHistoryPage> createState() =>
      _StudentAttendanceHistoryPageState();
}

class _StudentAttendanceHistoryPageState
    extends State<StudentAttendanceHistoryPage> {
  bool _isLoading = true;
  List<dynamic> _attendanceList = [];
  String? _selectedMonthYear;

  // Stats
  int _totalPresent = 0;
  int _totalAbsent = 0;
  int _totalLate = 0;
  int _totalNA = 0;

  final String _url = ApiConfig.flutter('attendance_get_student_history.php');
  /*final String _url =
      "http://app-kizzu.test/growkids/flutter/attendance_get_student_history.php";*/

  Map<String, List<Map<String, dynamic>>> _groupAttendanceByMonthYear() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    // Group records by "MMMM yyyy" so long histories are easier to scan.
    for (final rawItem in _attendanceList) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      final date = DateTime.tryParse((item['attn_date'] ?? '').toString()) ??
          DateTime.now();
      final key = DateFormat('MMMM yyyy').format(date);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped;
  }

  List<String> _availableMonthYears() {
    final months = _groupAttendanceByMonthYear().keys.toList();
    return months;
  }

  List<Map<String, dynamic>> _filteredAttendanceForSelectedMonth() {
    final grouped = _groupAttendanceByMonthYear();
    if (_selectedMonthYear == null) return [];
    return grouped[_selectedMonthYear] ?? [];
  }

  void _syncSelectedMonthYear() {
    final availableMonths = _availableMonthYears();
    if (availableMonths.isEmpty) {
      _selectedMonthYear = null;
      return;
    }

    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    // Default to current month when available; otherwise fall back to the latest month from API.
    _selectedMonthYear = availableMonths.contains(currentMonth)
        ? currentMonth
        : availableMonths.first;
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final res =
          await http.post(Uri.parse(_url), body: {'stud_id': widget.studId});

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          final List data = json['data'];

          int p = 0, a = 0, l = 0, na = 0;
          for (var item in data) {
            String s = (item['status'] ?? '').toString().toLowerCase();
            if (s == 'present') {
              p++;
            } else if (s == 'absent')
              a++;
            else if (s == 'late')
              l++;
            else if (s.contains('not')) na++;
          }

          setState(() {
            _attendanceList = data;
            _totalPresent = p;
            _totalAbsent = a;
            _totalLate = l;
            _totalNA = na;
            _syncSelectedMonthYear();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopAttendanceHistoryLayout(context)) {
      return _buildDesktop();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Attendance History',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : Padding(
              padding: EdgeInsets.all(2.h),
              child: Column(
                children: [
                  // 1. Redesigned Header with Icons
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(2.h), // Added bottom padding
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Growkids.purpleFlo,
                          Growkids.purpleFlo.withValues(alpha: .70),
                        ],
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Growkids.purpleFlo.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Student Name
                        Text(
                          widget.studentName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 2.h),

                        // Summary Stats Row with Icons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                                "Present",
                                _totalPresent,
                                Colors.greenAccent,
                                Icons.check_circle_outline_rounded),
                            _buildStatItem("Absent", _totalAbsent,
                                Colors.redAccent, Icons.cancel_outlined),
                            _buildStatItem("Late", _totalLate,
                                Colors.orangeAccent, Icons.access_time_rounded),
                            _buildStatItem(
                                "N/A",
                                _totalNA,
                                Colors.lightBlueAccent,
                                Icons.do_not_disturb_on_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: 2.h,
                  ),

                  // 2. Timeline List
                  Expanded(
                    child: _attendanceList.isEmpty
                        ? Center(
                            child: Text("No records yet.",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12.sp)),
                          )
                        : Column(
                            children: [
                              // Month/year selector keeps the student timeline compact
                              // while still allowing the user to switch periods quickly.
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 1.6.h, vertical: 0.6.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedMonthYear,
                                    isExpanded: true,
                                    icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded),
                                    items:
                                        _availableMonthYears().map((monthYear) {
                                      return DropdownMenuItem<String>(
                                        value: monthYear,
                                        child: Text(monthYear),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(
                                          () => _selectedMonthYear = value);
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: 1.6.h),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final visibleItems =
                                        _filteredAttendanceForSelectedMonth();

                                    if (visibleItems.isEmpty) {
                                      return Center(
                                        child: Text(
                                          "No records found for this month.",
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12.sp),
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      itemCount: visibleItems.length,
                                      itemBuilder: (context, index) {
                                        final isLast =
                                            index == visibleItems.length - 1;
                                        return _buildTimelineItem(
                                            visibleItems[index], isLast);
                                      },
                                    );
                                  },
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

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        title: const Text(
          'Attendance History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh attendance',
            onPressed: _isLoading ? null : _fetchHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
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
                      _desktopHeader(),
                      const SizedBox(height: 20),
                      if (_attendanceList.isEmpty)
                        _desktopEmpty('No attendance records yet.')
                      else ...[
                        _desktopMonthToolbar(),
                        const SizedBox(height: 20),
                        _desktopAttendancePanel(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopHeader() {
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
                  'STUDENT ATTENDANCE',
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
                Text(
                  '${_attendanceList.length} attendance record${_attendanceList.length == 1 ? '' : 's'}',
                  style:
                      const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
          _desktopStat(
            'Present',
            _totalPresent,
            Icons.check_circle_outline_rounded,
            const Color(0xFF6EE7A3),
          ),
          const SizedBox(width: 10),
          _desktopStat(
            'Absent',
            _totalAbsent,
            Icons.cancel_outlined,
            const Color(0xFFFF8C9B),
          ),
          const SizedBox(width: 10),
          _desktopStat(
            'Late',
            _totalLate,
            Icons.access_time_rounded,
            const Color(0xFFFFCB6B),
          ),
          const SizedBox(width: 10),
          _desktopStat(
            'N/A',
            _totalNA,
            Icons.do_not_disturb_on_outlined,
            const Color(0xFF7DD3FC),
          ),
        ],
      ),
    );
  }

  Widget _desktopStat(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
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
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Text(
                '$count',
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
            style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _desktopMonthToolbar() {
    final selectedCount = _filteredAttendanceForSelectedMonth().length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
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
              Icons.calendar_month_outlined,
              color: Growkids.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Attendance period',
            style: TextStyle(
              color: Color(0xFF303341),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedMonthYear,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F6F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _availableMonthYears()
                  .map(
                    (monthYear) => DropdownMenuItem<String>(
                      value: monthYear,
                      child: Text(
                        monthYear,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedMonthYear = value);
              },
            ),
          ),
          const Spacer(),
          Text(
            '$selectedCount record${selectedCount == 1 ? '' : 's'} in this period',
            style: const TextStyle(
              color: Color(0xFF777C8B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopAttendancePanel() {
    final items = _filteredAttendanceForSelectedMonth();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Date',
                  style: _DesktopAttendanceStyles.tableHeader,
                ),
              ),
              Expanded(
                child: Text(
                  'Day',
                  style: _DesktopAttendanceStyles.tableHeader,
                ),
              ),
              Expanded(
                child: Text(
                  'Status',
                  style: _DesktopAttendanceStyles.tableHeader,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Remark',
                  style: _DesktopAttendanceStyles.tableHeader,
                ),
              ),
            ],
          ),
          const Divider(height: 26, color: Color(0xFFE7E9F0)),
          if (items.isEmpty)
            _desktopEmpty('No records found for this month.')
          else
            ...List.generate(
              items.length,
              (index) => _desktopAttendanceRow(
                items[index],
                showDivider: index != items.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopAttendanceRow(
    Map<String, dynamic> item, {
    required bool showDivider,
  }) {
    final date = DateTime.tryParse((item['attn_date'] ?? '').toString());
    final status = (item['status'] ?? '').toString();
    final remark = (item['remark'] ?? '').toString().trim();
    final config = _desktopStatusConfig(status);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  date == null
                      ? (item['attn_date'] ?? '-').toString()
                      : DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    color: Color(0xFF303341),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  date == null ? '-' : DateFormat('EEE').format(date),
                  style: const TextStyle(
                    color: Color(0xFF717685),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(child: _desktopStatusBadge(config)),
              Expanded(
                flex: 3,
                child: Text(
                  remark.isEmpty ? '—' : remark,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: remark.isEmpty
                        ? const Color(0xFFB0B3BD)
                        : const Color(0xFF656A78),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFEDEEF3)),
      ],
    );
  }

  (Color, IconData, String) _desktopStatusConfig(String rawStatus) {
    return switch (rawStatus.toLowerCase().replaceAll(' ', '')) {
      'present' => (
          const Color(0xFF16A34A),
          Icons.check_circle_outline_rounded,
          'Present'
        ),
      'absent' => (const Color(0xFFDC3545), Icons.cancel_outlined, 'Absent'),
      'late' => (const Color(0xFFF59E0B), Icons.access_time_rounded, 'Late'),
      'notapplicable' => (
          const Color(0xFF3D7AF5),
          Icons.do_not_disturb_on_outlined,
          'Not Applicable'
        ),
      _ => (const Color(0xFF858A99), Icons.help_outline_rounded, 'Unknown'),
    };
  }

  Widget _desktopStatusBadge((Color, IconData, String) config) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: config.$1.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: config.$1.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.$2, size: 14, color: config.$1),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                config.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: config.$1,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopEmpty(String message) {
    return Container(
      height: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: Color(0xFFC6C9D2),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF777C8B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- STAT HEADER ITEM (With Icon) ---
  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        // Icon Bubble
        Container(
          padding: EdgeInsets.all(1.2.h),
          decoration: BoxDecoration(
            color:
                Colors.white.withValues(alpha: 0.15), // Semi-transparent bubble
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 3.h),
        ),
        SizedBox(height: 1.h),

        // Count
        Text(
          "$count",
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),

        // Label
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12.sp),
        ),
      ],
    );
  }

  // --- TIMELINE ROW ---
  Widget _buildTimelineItem(Map<String, dynamic> item, bool isLast) {
    String dateStr = item['attn_date'] ?? '';
    String status = (item['status'] ?? '').toString().toLowerCase();
    String remark = item['remark'] ?? '';

    // Determine Style based on Status
    Color themeColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'present':
        themeColor = Colors.green;
        statusIcon = Icons.check_circle_outline_rounded;
        statusText = "Present";
        break;
      case 'absent':
        themeColor = Colors.redAccent;
        statusIcon = Icons.cancel_outlined;
        statusText = "Absent";
        break;
      case 'late':
        themeColor = Colors.orange;
        statusIcon = Icons.access_time_rounded;
        statusText = "Late";
        break;
      case 'not applicable':
      case 'notapplicable':
        themeColor = Colors.blueAccent;
        statusIcon = Icons.do_not_disturb_on_outlined;
        statusText = "Not Applicable";
        break;
      default:
        themeColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = "Unknown";
    }

    // Date Parsing
    DateTime date = DateTime.tryParse(dateStr) ?? DateTime.now();
    String day = DateFormat('dd').format(date);
    String month = DateFormat('MMM').format(date).toUpperCase();
    String weekday = DateFormat('EEEE').format(date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. LEFT: DATE COLUMN
          SizedBox(
            width: 12.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: TextStyle(
                      fontSize: 16.sp, color: Colors.black87, height: 1.0),
                ),
                Text(
                  month,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                ),
                Text(
                  weekday.substring(0, 3).toUpperCase(),
                  style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey[500],
                      letterSpacing: 1),
                ),
              ],
            ),
          ),

          // 2. MIDDLE: TIMELINE LINE
          Column(
            children: [
              // The Dot
              Container(
                margin: EdgeInsets.only(top: 0.5.h),
                width: 1.h,
                height: 1.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor, width: 2),
                ),
              ),
              // The Line
              Expanded(
                child: isLast
                    ? Container()
                    : Container(
                        width: 1,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
              ),
            ],
          ),

          SizedBox(width: 4.w),

          // 3. RIGHT: CONTENT CARD
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 2.5.h),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                          left: BorderSide(
                              color: themeColor.withValues(alpha: 0.5),
                              width: 3)),
                    ),
                    padding: EdgeInsets.all(1.5.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Row
                        Row(
                          children: [
                            Icon(statusIcon, color: themeColor, size: 3.h),
                            SizedBox(width: 2.w),
                            Text(
                              statusText,
                              style: TextStyle(
                                  fontSize: 13.sp, color: Colors.black87),
                            ),
                          ],
                        ),

                        // Remark Section
                        if (remark.isNotEmpty) ...[
                          SizedBox(height: 1.h),
                          Text(
                            remark,
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[600],
                                height: 1.3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class _DesktopAttendanceStyles {
  static const tableHeader = TextStyle(
    color: Color(0xFF858A99),
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );
}
