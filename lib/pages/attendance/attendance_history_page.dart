import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/student_hub/student_hub.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

bool _useDesktopStaffAttendanceHistoryLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class AttendanceHistoryPage extends StatefulWidget {
  final String staffId;
  final UserRoleHub role;

  const AttendanceHistoryPage(
      {super.key, required this.staffId, required this.role});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  bool _isLoading = true;
  List<dynamic> _historyList = [];
  String? _selectedMonthYear;
  Map<String, dynamic>? _desktopSelectedDay;
  Future<List<dynamic>>? _desktopDetailsFuture;

  final String _historyUrl = ApiConfig.flutter('attendance_get_history.php');
  //final String _historyUrl = "http://app-kizzu.test/growkids/flutter/attendance_get_history.php";
  final String _detailUrl = ApiConfig.flutter('attendance_get_list.php');
  //final String _detailUrl = "http://app-kizzu.test/growkids/flutter/attendance_get_list.php";

  Map<String, List<Map<String, dynamic>>> _groupHistoryByMonthYear() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    // Group attendance days by month/year to avoid one very long flat list.
    for (final rawItem in _historyList) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      final date = DateTime.tryParse((item['attn_date'] ?? '').toString()) ??
          DateTime.now();
      final key = DateFormat('MMMM yyyy').format(date);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped;
  }

  List<String> _availableMonthYears() {
    final months = _groupHistoryByMonthYear().keys.toList();
    return months;
  }

  List<Map<String, dynamic>> _filteredHistoryForSelectedMonth() {
    final grouped = _groupHistoryByMonthYear();
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
      final res = await http.post(Uri.parse(_historyUrl), body: {
        'staff_id': widget.staffId,
      });

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          setState(() {
            _historyList = json['data'];
            _syncSelectedMonthYear();
            final visibleItems = _filteredHistoryForSelectedMonth();
            _desktopSelectedDay =
                visibleItems.isEmpty ? null : visibleItems.first;
            _desktopDetailsFuture = _desktopSelectedDay == null
                ? null
                : _fetchDetailsForDate(
                    (_desktopSelectedDay!['attn_date'] ?? '').toString(),
                  );
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

  Future<List<dynamic>> _fetchDetailsForDate(String date) async {
    try {
      final res = await http.post(Uri.parse(_detailUrl), body: {
        'staff_id': widget.staffId,
        'role': widget.role == UserRoleHub.teacher ? 'teacher' : 'therapist',
        'attn_date': date,
      });

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          return json['data'];
        }
      }
    } catch (e) {
      print(e);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopStaffAttendanceHistoryLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB), // Background kelabu cair
      appBar: AppBar(
        title: const Text('Attendance History',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : _historyList.isEmpty
              ? const Center(
                  child: Text("No history found.",
                      style: TextStyle(color: Colors.grey)))
              : Padding(
                  padding: EdgeInsets.all(2.h),
                  child: Column(
                    children: [
                      // Month/year selector keeps the page short and focused on one period at a time.
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: 1.6.h, vertical: 0.6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMonthYear,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: _availableMonthYears().map((monthYear) {
                              return DropdownMenuItem<String>(
                                value: monthYear,
                                child: Text(monthYear),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedMonthYear = value);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 1.6.h),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final visibleItems =
                                _filteredHistoryForSelectedMonth();

                            if (visibleItems.isEmpty) {
                              return Center(
                                child: Text(
                                  "No history found for this month.",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12.sp),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: visibleItems.length,
                              itemBuilder: (ctx, i) =>
                                  _buildExpandableCard(visibleItems[i]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDesktopPage() {
    final visibleItems = _filteredHistoryForSelectedMonth();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Attendance History',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _fetchHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
                  child: Column(
                    children: [
                      _desktopHistoryHero(),
                      const SizedBox(height: 17),
                      Expanded(
                        child: _historyList.isEmpty
                            ? const Center(
                                child: Text('No attendance history found.'),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 350,
                                    child: _desktopAttendanceDays(visibleItems),
                                  ),
                                  const SizedBox(width: 17),
                                  Expanded(child: _desktopDayDetails()),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopHistoryHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 19),
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
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.history_rounded,
              color: Growkids.purpleFlo,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTENDANCE RECORDS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Daily Attendance History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Select a date to review student attendance and remarks.',
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
          Container(
            width: 210,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMonthYear,
                dropdownColor: Growkids.purpleFlo,
                iconEnabledColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                isExpanded: true,
                items: _availableMonthYears()
                    .map(
                      (month) => DropdownMenuItem(
                        value: month,
                        child: Text(month),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedMonthYear = value;
                    final items = _filteredHistoryForSelectedMonth();
                    _desktopSelectedDay = items.isEmpty ? null : items.first;
                    _desktopDetailsFuture = _desktopSelectedDay == null
                        ? null
                        : _fetchDetailsForDate(
                            (_desktopSelectedDay!['attn_date'] ?? '')
                                .toString(),
                          );
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopAttendanceDays(List<Map<String, dynamic>> items) {
    return _desktopHistorySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance dates',
            style: TextStyle(
              color: Color(0xFF30323C),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${items.length} record${items.length == 1 ? '' : 's'} in this month',
            style: const TextStyle(color: Color(0xFF8B8F9C), fontSize: 8),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No records for this month.'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final date = DateTime.parse(item['attn_date'].toString());
                      final selected = identical(item, _desktopSelectedDay) ||
                          item['attn_date'] ==
                              _desktopSelectedDay?['attn_date'];
                      return InkWell(
                        onTap: () => setState(() {
                          _desktopSelectedDay = item;
                          _desktopDetailsFuture =
                              _fetchDetailsForDate(item['attn_date']);
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Growkids.purpleFlo.withValues(alpha: .09)
                                : const Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? Growkids.purpleFlo.withValues(alpha: .28)
                                  : const Color(0xFFE3E6EC),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 43,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('dd').format(date),
                                      style: TextStyle(
                                        color: Growkids.purpleFlo,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM').format(date),
                                      style: const TextStyle(
                                        color: Color(0xFF8A8E9A),
                                        fontSize: 7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE').format(date),
                                      style: const TextStyle(
                                        color: Color(0xFF40434E),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item['total_marked'] ?? 0} students marked',
                                      style: const TextStyle(
                                        color: Color(0xFF8B8F9C),
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF999DA8),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopDayDetails() {
    final selected = _desktopSelectedDay;
    if (selected == null || _desktopDetailsFuture == null) {
      return _desktopHistorySurface(
        child: const Center(child: Text('Select an attendance date.')),
      );
    }

    final date = DateTime.parse(selected['attn_date'].toString());
    return _desktopHistorySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(date),
                      style: const TextStyle(
                        color: Color(0xFF30323C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${selected['total_marked'] ?? 0} students checked',
                      style: const TextStyle(
                        color: Color(0xFF8B8F9C),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              _desktopSummaryChip(
                'Present',
                selected['total_present'],
                const Color(0xFF16A34A),
              ),
              _desktopSummaryChip(
                'Absent',
                selected['total_absent'],
                const Color(0xFFEF4444),
              ),
              _desktopSummaryChip(
                'Late',
                selected['total_late'],
                const Color(0xFFF59E0B),
              ),
              _desktopSummaryChip(
                'N/A',
                selected['total_na'],
                const Color(0xFF3B82F6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7ED)),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('Student', style: _DesktopHistoryText.header),
              ),
              Expanded(
                flex: 2,
                child: Text('Status', style: _DesktopHistoryText.header),
              ),
              Expanded(
                flex: 4,
                child: Text('Remark', style: _DesktopHistoryText.header),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _desktopDetailsFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Growkids.purpleFlo,
                    ),
                  );
                }
                final students = (snapshot.data ?? [])
                    .where((student) => student['status'] != null)
                    .toList();
                if (students.isEmpty) {
                  return const Center(child: Text('No details available.'));
                }
                return ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFEEF0F4)),
                  itemBuilder: (_, index) =>
                      _desktopHistoryStudentRow(students[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHistoryStudentRow(dynamic student) {
    final status = (student['status'] ?? '').toString().toLowerCase();
    final config = switch (status) {
      'present' => (const Color(0xFF16A34A), 'Present'),
      'absent' => (const Color(0xFFEF4444), 'Absent'),
      'late' => (const Color(0xFFF59E0B), 'Late'),
      'not applicable' || 'notapplicable' => (const Color(0xFF3B82F6), 'N/A'),
      'excused' => (const Color(0xFF0D9488), 'Excused'),
      _ => (const Color(0xFF777C89), '-'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              (student['name'] ?? 'Unknown').toString(),
              style: const TextStyle(
                color: Color(0xFF41444F),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
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
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              (student['remark'] ?? '').toString().trim().isEmpty
                  ? '—'
                  : student['remark'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF7E838F), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSummaryChip(String label, dynamic value, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '${value ?? 0} $label',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _desktopHistorySurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6EC)),
      ),
      child: child,
    );
  }

  // --- CARD UTAMA (FLOATING WHITE TILE) ---
  Widget _buildExpandableCard(Map<String, dynamic> item) {
    DateTime date = DateTime.parse(item['attn_date']);
    String day = DateFormat('dd').format(date);
    String month = DateFormat('MMM').format(date);

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ Putih
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // ✅ Floating Shadow Effect
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.all(1.5.h),
          childrenPadding:
              EdgeInsets.only(left: 1.5.h, right: 1.5.h, bottom: 2.h),

          // HEADER (Summary Tarikh & Count)
          title: Row(
            children: [
              // Date Box
              Container(
                width: 10.w,
                padding: EdgeInsets.all(1.h),
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(day,
                        style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Growkids.purpleFlo)),
                    Text(month,
                        style: TextStyle(
                            fontSize: 12.sp, color: Growkids.purpleFlo)),
                  ],
                ),
              ),
              SizedBox(width: 3.w),

              // Stats Badge Row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Student checked - ${item['total_marked']}",
                        style:
                            TextStyle(fontSize: 14.sp, color: Colors.black87)),
                    SizedBox(height: 0.8.h),
                    // Baris Badge
                    Wrap(
                      spacing: 6, // Jarak antara badge mendatar
                      runSpacing: 6, // Jarak jika turun baris
                      children: [
                        _statBadge(item['total_present'], Colors.green, "P"),
                        SizedBox(width: 0.5.w),
                        _statBadge(item['total_absent'], Colors.redAccent, "A"),
                        SizedBox(width: 0.5.w),
                        _statBadge(item['total_late'], Colors.orange, "L"),
                        SizedBox(width: 0.5.w),
                        _statBadge(item['total_na'], Colors.blueAccent,
                            "NA"), // ✅ Tambah NA
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),

          // BODY (Detail List Student)
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              child: FutureBuilder<List<dynamic>>(
                future: _fetchDetailsForDate(item['attn_date']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: EdgeInsets.all(2.h),
                      child: Center(
                          child: SizedBox(
                              width: 2.w,
                              height: 2.h,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Growkids.purpleFlo))),
                    );
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.all(2.h),
                      child: const Text("No details available.",
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final students = snapshot.data!;
                  final markedStudents =
                      students.where((s) => s['status'] != null).toList();

                  if (markedStudents.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.all(2.h),
                      child: const Text("No records found.",
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return Column(
                    children: markedStudents
                        .map((student) => _buildStudentRow(student))
                        .toList(),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- ROW DETAIL PELAJAR ---
  Widget _buildStudentRow(Map<String, dynamic> student) {
    String status = (student['status'] ?? '').toString().toLowerCase();
    String name = student['name'] ?? 'Unknown';
    String remark = (student['remark'] ?? '').toString().trim();

    Color statusColor;
    String statusLabel;

    switch (status) {
      case 'present':
        statusColor = Colors.green;
        statusLabel = "Present";
        break;
      case 'absent':
        statusColor = Colors.redAccent;
        statusLabel = "Absent";
        break;
      case 'late':
        statusColor = Colors.orange;
        statusLabel = "Late";
        break;
      case 'not applicable': // ✅ Handle status baru
      case 'notapplicable':
        statusColor = Colors.blueAccent;
        statusLabel = "N/A";
        break;
      case 'excused':
        statusColor = Colors.teal;
        statusLabel = "Excused";
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = "-";
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 2.h,
            backgroundColor: Growkids.purpleFlo.withValues(alpha: 0.08),
            child: Icon(Icons.person, size: 2.h, color: Growkids.purpleFlo),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500)),
                if (remark.isNotEmpty) ...[
                  SizedBox(height: 0.5.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 1.8.h,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          remark,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: Colors.grey[600],
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              // border: Border.all(color: statusColor.withOpacity(0.3)), // Optional border
            ),
            child: Text(
              statusLabel,
              style: TextStyle(fontSize: 12.sp, color: statusColor),
            ),
          )
        ],
      ),
    );
  }

  // --- STAT BADGE KECIL ---
  Widget _statBadge(String? countStr, Color color, String label) {
    int count = int.tryParse(countStr ?? '0') ?? 0;

    // Kalau 0, kita pudarkan supaya tak semak mata
    bool isZero = count == 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: isZero ? Colors.grey[100] : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1.w,
            height: 1.h,
            decoration: BoxDecoration(
                color: isZero ? Colors.grey[400] : color,
                shape: BoxShape.circle),
          ),
          SizedBox(width: 1.w),
          Text("$count",
              style: TextStyle(
                  fontSize: 12.sp,
                  color: isZero ? Colors.grey[500] : Colors.black87)),
        ],
      ),
    );
  }
}

abstract final class _DesktopHistoryText {
  static const header = TextStyle(
    color: Color(0xFF777C89),
    fontSize: 9,
    fontWeight: FontWeight.w800,
  );
}
