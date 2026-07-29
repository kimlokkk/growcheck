import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/student_hub/student_hub.dart';
import 'package:growcheck_app_v2/pages/attendance/attendance_history_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

bool _useDesktopBulkAttendanceLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

// --- MODEL ---
class AttendanceItem {
  final String studId;
  final String name;
  String? status; // 'present', 'absent', 'late', 'excused' or null
  String remark;

  AttendanceItem(
      {required this.studId,
      required this.name,
      this.status,
      this.remark = ''});

  factory AttendanceItem.fromJson(Map<String, dynamic> json) {
    return AttendanceItem(
      studId: (json['stud_id'] ?? '').toString(),
      name: json['name'] ?? 'Unknown',
      status: json['status'], // Boleh jadi null kalau belum tanda
      remark: json['remark'] ?? '',
    );
  }
}

class BulkAttendancePage extends StatefulWidget {
  final String staffId;
  final UserRoleHub role; // 'teacher' or 'therapist'
  final DateTime? initialDate;

  const BulkAttendancePage(
      {super.key, required this.staffId, required this.role, this.initialDate});

  @override
  State<BulkAttendancePage> createState() => _BulkAttendancePageState();
}

class _BulkAttendancePageState extends State<BulkAttendancePage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  List<AttendanceItem> _students = [];

  // URLs
  final String _getUrl = ApiConfig.flutter('attendance_get_list.php');

  final String _saveUrl = ApiConfig.flutter('attendance_save_bulk.php');
  /*final String _saveUrl =
      "http://app-kizzu.test/growkids/flutter/attendance_save_bulk.php";

  final String _getUrl =
      "http://app-kizzu.test/growkids/flutter/attendance_get_list.php";*/

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  // 1. Fetch Student List + Status for selected date
  Future<void> _fetchList() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(Uri.parse(_getUrl), body: {
        'staff_id': widget.staffId,
        'role': widget.role.toString(),
        'attn_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });
      print(
          '${widget.staffId}, ${widget.role.toString()}, ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          final List data = json['data'];
          setState(() {
            _students = data.map((e) => AttendanceItem.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. Save All Changes
  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      // Prepare JSON Data
      List<Map<String, dynamic>> payload = [];
      for (var s in _students) {
        if (s.status != null) {
          // Hanya hantar yang dah bertanda
          payload.add({
            'stud_id': s.studId,
            'staff_id': widget.staffId,
            'attn_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'status': s.status,
            'remark': s.remark,
          });
        }
      }

      if (payload.isEmpty) {
        _snack("No attendance marked to save.", Colors.orange);
        setState(() => _isSaving = false);
        return;
      }

      final res = await http.post(
        Uri.parse(_saveUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        _snack("Attendance saved successfully!", Colors.green);
        Navigator.pop(context);
      } else {
        _snack("Failed to save.", Colors.red);
      }
    } catch (e) {
      _snack("Error: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
            data: ThemeData.light().copyWith(
                colorScheme:
                    const ColorScheme.light(primary: Growkids.purpleFlo)),
            child: child!);
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchList(); // Refresh list bila tukar tarikh
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    if (_useDesktopBulkAttendanceLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Check Attendance',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        actions: [
          // 5. Add History Button Here
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Attendance History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendanceHistoryPage(
                    staffId: widget.staffId,
                    role: widget.role,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // HEADER DATE PICKER
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.h),
            child: InkWell(
              onTap: _pickDate,
              child: Container(
                padding: EdgeInsets.all(1.2.h),
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Growkids.purpleFlo.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: Growkids.purpleFlo),
                    SizedBox(width: 2.w),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                      style:
                          TextStyle(fontSize: 12.sp, color: Growkids.purpleFlo),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: Growkids.purpleFlo),
                  ],
                ),
              ),
            ),
          ),

          // LIST STUDENT
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Growkids.purpleFlo))
                : _students.isEmpty
                    ? const Center(
                        child: Text("No students found.",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: EdgeInsets.all(1.5.h),
                        itemCount: _students.length,
                        itemBuilder: (ctx, i) {
                          return _buildStudentRow(_students[i]);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(2.h),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? SizedBox(
                    height: 2.h,
                    width: 2.w,
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    "Save Attendance",
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final marked = _students.where((student) => student.status != null).length;
    final present =
        _students.where((student) => student.status == 'present').length;
    final absent =
        _students.where((student) => student.status == 'absent').length;
    final late = _students.where((student) => student.status == 'late').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Check Attendance',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Attendance History',
            onPressed: _openAttendanceHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              children: [
                _desktopAttendanceHero(
                  marked: marked,
                  present: present,
                  absent: absent,
                  late: late,
                ),
                const SizedBox(height: 17),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE3E6EC)),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Growkids.purpleFlo,
                            ),
                          )
                        : _students.isEmpty
                            ? const Center(
                                child: Text('No students found.'),
                              )
                            : Column(
                                children: [
                                  _desktopTableHeader(),
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFE5E7ED),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _students.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                        height: 1,
                                        color: Color(0xFFEEF0F4),
                                      ),
                                      itemBuilder: (_, index) =>
                                          _desktopStudentRow(
                                        _students[index],
                                        index,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 14),
                _desktopAttendanceActionBar(marked),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAttendanceHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceHistoryPage(
          staffId: widget.staffId,
          role: widget.role,
        ),
      ),
    );
  }

  Widget _desktopAttendanceHero({
    required int marked,
    required int present,
    required int absent,
    required int late,
  }) {
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
              Icons.how_to_reg_rounded,
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
                  'DAILY STUDENT RECORD',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Mark Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 11),
          _desktopMetric('Marked', marked, Colors.white),
          const SizedBox(width: 8),
          _desktopMetric('Present', present, const Color(0xFF8EE7BC)),
          const SizedBox(width: 8),
          _desktopMetric('Absent', absent, const Color(0xFFFFAEB4)),
          const SizedBox(width: 8),
          _desktopMetric('Late', late, const Color(0xFFFFD68A)),
        ],
      ),
    );
  }

  Widget _desktopMetric(String label, int value, Color accent) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: accent,
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
    );
  }

  Widget _desktopTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 42,
            child: Text('#', style: _DesktopAttendanceText.header),
          ),
          Expanded(
            flex: 3,
            child: Text('Student', style: _DesktopAttendanceText.header),
          ),
          Expanded(
            flex: 4,
            child:
                Text('Attendance status', style: _DesktopAttendanceText.header),
          ),
          Expanded(
            flex: 3,
            child: Text('Remarks', style: _DesktopAttendanceText.header),
          ),
        ],
      ),
    );
  }

  Widget _desktopStudentRow(AttendanceItem student, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Color(0xFF9195A1), fontSize: 9),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Growkids.purpleFlo.withValues(alpha: .09),
                  child: Text(
                    student.name.isEmpty ? '?' : student.name[0].toUpperCase(),
                    style: TextStyle(
                      color: Growkids.purpleFlo,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3E414C),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _desktopStatusButton(
                  student,
                  'Present',
                  'present',
                  const Color(0xFF16A34A),
                ),
                _desktopStatusButton(
                  student,
                  'Absent',
                  'absent',
                  const Color(0xFFEF4444),
                ),
                _desktopStatusButton(
                  student,
                  'Late',
                  'late',
                  const Color(0xFFF59E0B),
                ),
                _desktopStatusButton(
                  student,
                  'N/A',
                  'not applicable',
                  const Color(0xFF3B82F6),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextFormField(
                initialValue: student.remark,
                onChanged: (value) => student.remark = value,
                style: const TextStyle(fontSize: 9),
                decoration: InputDecoration(
                  hintText: 'Optional remark...',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FB),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopStatusButton(
    AttendanceItem student,
    String label,
    String value,
    Color color,
  ) {
    final selected = student.status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => student.status = selected ? null : value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 68,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : const Color(0xFFF3F4F7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : const Color(0xFFE1E4EA),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF737783),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopAttendanceActionBar(int marked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3E6EC)),
      ),
      child: Row(
        children: [
          Text(
            '$marked of ${_students.length} students marked',
            style: const TextStyle(color: Color(0xFF7C818E), fontSize: 9),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAll,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Save Attendance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(AttendanceItem s) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.2.h),
      padding: EdgeInsets.all(1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Name
          Text(s.name,
              style: TextStyle(
                fontSize: 14.sp,
              )),
          SizedBox(height: 1.h),

          // Attendance Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _attBtn(s, "Present", "present",
                  Colors.green), // Shortened label for better fit
              _attBtn(s, "Absent", "absent", Colors.redAccent),
              _attBtn(s, "Late", "late", Colors.orange),
              _attBtn(s, "N/A", "not applicable", Colors.blueAccent),
            ],
          ),

          SizedBox(height: 1.5.h),

          // Remarks Field
          TextField(
            onChanged: (value) {
              s.remark = value; // Update the model directly
            },
            controller: TextEditingController(
                text: s.remark), // Initialize with existing remark
            decoration: InputDecoration(
              hintText: "Add remarks (optional)...",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11.sp),
              prefixIcon: Icon(Icons.edit_note_rounded,
                  color: Colors.grey[400], size: 20),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            style: TextStyle(fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  // Butang Pilihan (Choice Chip style)
  Widget _attBtn(AttendanceItem s, String label, String value, Color color) {
    bool isSelected = s.status == value;
    return InkWell(
      onTap: () {
        setState(() {
          // Toggle: Kalau tekan balik benda sama, jadi null (unselected)
          s.status = isSelected ? null : value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 18.w,
        padding: EdgeInsets.symmetric(vertical: 1.h),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label, // P, A, L, E
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontSize: 12.sp,
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _DesktopAttendanceText {
  static const header = TextStyle(
    color: Color(0xFF737886),
    fontSize: 9,
    fontWeight: FontWeight.w800,
  );
}
