// ignore_for_file: unused_local_variable, unused_element

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

// Import your existing pages
import 'soap_form.dart';
import 'package:growcheck_app_v2/pages/soap/soap_report_view.dart';

bool _useDesktopSoapStudentLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class StudentSoapProfilePage extends StatefulWidget {
  final String therapistId;
  final String studId;
  final String studName;

  const StudentSoapProfilePage({
    super.key,
    required this.therapistId,
    required this.studId,
    required this.studName,
  });

  @override
  State<StudentSoapProfilePage> createState() => _StudentSoapProfilePageState();
}

class _StudentSoapProfilePageState extends State<StudentSoapProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _studentData;
  List<dynamic> _historyList = [];

  final String _apiUrl = ApiConfig.flutter('soap_student_report.php');
  /*final String _apiUrl =
      "http://app-kizzu.test/growkids/flutter/soap_student_report.php";*/

  @override
  void initState() {
    super.initState();
    _fetchStudentProfile();
  }

  Future<void> _fetchStudentProfile() async {
    try {
      final res = await http.post(
        Uri.parse(_apiUrl),
        body: {
          'therapist_id': widget.therapistId,
          'stud_id': widget.studId,
        },
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          setState(() {
            _studentData = json['student'];
            _historyList = json['history'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Error fetching profile: $e");
      setState(() => _isLoading = false);
    }
  }

  // Calculate age from DOB
  String _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) return "N/A";
    try {
      DateTime dob = DateTime.parse(dobString);
      DateTime today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return "$age yrs";
    } catch (e) {
      return "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSoapStudentLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('SOAP Student Page',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : RefreshIndicator(
              color: Growkids.purpleFlo,
              onRefresh: _fetchStudentProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. STUDENT INFO CARD
                    _buildStudentInfoCard(),
                    SizedBox(height: 3.h),

                    // 2. NEW REPORT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 6.5.h,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to your existing SOAP Form Page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SOAPFormPage(
                                therapistId: widget.therapistId,
                                studId: widget.studId,
                                studentName: widget.studName,
                              ),
                            ),
                          ).then((_) =>
                              _fetchStudentProfile()); // Refresh history on return
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Growkids.purpleFlo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor:
                              Growkids.purpleFlo.withValues(alpha: 0.4),
                        ),
                        icon: const Icon(Icons.add_task_rounded),
                        label: Text(
                          "Create New SOAP Report",
                          style: TextStyle(
                              fontSize: 13.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),

                    // 3. HISTORY SECTION
                    Text(
                      "SOAP History",
                      style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    ),
                    SizedBox(height: 1.5.h),

                    _historyList.isEmpty
                        ? _buildEmptyHistory()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _historyList.length,
                            itemBuilder: (context, index) {
                              return _buildHistoryCard(_historyList[index]);
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStudentInfoCard() {
    String program = _studentData?['program'] ?? 'General Program';
    String dob = _studentData?['stud_dob'] ?? 'N/A';
    String oku = _studentData?['stud_oku'] != null &&
            _studentData!['stud_oku'].toString().isNotEmpty
        ? _studentData!['stud_oku']
        : 'None';
    String contact = _studentData?['stud_father_contact'] ??
        _studentData?['stud_mother_contact'] ??
        'N/A';
    String age = _calculateAge(dob);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(2.5.h),
        child: Column(
          children: [
            // Header: Avatar & Name
            Row(
              children: [
                Container(
                  width: 7.h,
                  height: 7.h,
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.studName.isNotEmpty
                        ? widget.studName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: Growkids.purpleFlo,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.sp),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studName,
                        style:
                            TextStyle(fontSize: 16.sp, color: Colors.black87),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        program,
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final draftCount = _historyList
        .where(
            (report) => report['status']?.toString().toLowerCase() == 'draft')
        .length;
    final completedCount = _historyList.length - draftCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text(
          'SOAP Student Page',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _fetchStudentProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                  child: Column(
                    children: [
                      _desktopStudentHero(draftCount, completedCount),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 350,
                              child: _desktopProfilePanel(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: _desktopHistoryPanel()),
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

  Widget _desktopStudentHero(int draftCount, int completedCount) {
    final program = (_studentData?['program'] ?? 'General Program').toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 23),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.18),
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              widget.studName.isEmpty ? '?' : widget.studName[0].toUpperCase(),
              style: const TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOAP STUDENT PROFILE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.studName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$program  •  Student ID ${widget.studId}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          _desktopHeroMetric(
            Icons.edit_note_rounded,
            draftCount.toString(),
            'Drafts',
            const Color(0xFFFFD68A),
          ),
          const SizedBox(width: 12),
          _desktopHeroMetric(
            Icons.check_circle_outline_rounded,
            completedCount.toString(),
            'Completed',
            const Color(0xFF8EE7BC),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _openNewReport,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('New SOAP Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Growkids.purpleFlo,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeroMetric(
    IconData icon,
    String value,
    String label,
    Color accent,
  ) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 19),
          const SizedBox(width: 8),
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

  Widget _desktopProfilePanel() {
    final program = (_studentData?['program'] ?? 'General Program').toString();
    final dob = (_studentData?['stud_dob'] ?? '').toString();
    final oku = _studentData?['stud_oku'] != null &&
            _studentData!['stud_oku'].toString().isNotEmpty
        ? _studentData!['stud_oku'].toString()
        : 'None';
    final contact = (_studentData?['stud_father_contact'] ??
            _studentData?['stud_mother_contact'] ??
            'N/A')
        .toString();

    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Student information',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Current programme and profile details.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 10),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(right: 3),
              children: [
                _desktopInfoRow(
                  Icons.badge_outlined,
                  'Student ID',
                  widget.studId,
                ),
                _desktopInfoRow(
                  Icons.school_outlined,
                  'Programme',
                  program,
                ),
                _desktopInfoRow(
                  Icons.cake_outlined,
                  'Age',
                  _calculateAge(dob),
                ),
                _desktopInfoRow(
                  Icons.accessibility_new_rounded,
                  'OKU status',
                  oku,
                ),
                _desktopInfoRow(
                  Icons.phone_outlined,
                  'Contact',
                  contact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openNewReport,
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text('Create SOAP report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE5E7EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Growkids.purpleFlo, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9296A2),
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF444752),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHistoryPanel() {
    return _desktopSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 19, 21, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOAP history',
                        style: TextStyle(
                          color: Color(0xFF242631),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Draft and completed session reports.',
                        style:
                            TextStyle(color: Color(0xFF777C8D), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${_historyList.length} reports',
                    style: const TextStyle(
                      color: Growkids.purpleFlo,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EAF0)),
          Expanded(
            child: _historyList.isEmpty
                ? _desktopEmptyHistory()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historyList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) =>
                        _desktopHistoryRow(_historyList[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHistoryRow(Map<String, dynamic> report) {
    final date = DateTime.tryParse(report['session_date']?.toString() ?? '');
    final dateLabel = date == null
        ? 'Unknown date'
        : DateFormat('EEEE, d MMM yyyy').format(date);
    final isDraft = report['status']?.toString().toLowerCase() == 'draft';
    final color = isDraft ? const Color(0xFFC47708) : const Color(0xFF15945D);

    return InkWell(
      onTap: () => _openHistoryReport(report),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: isDraft ? const Color(0xFFFFFAF0) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isDraft ? const Color(0xFFF0D7A8) : const Color(0xFFE3E5EC),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDraft ? Icons.edit_document : Icons.check_circle_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      color: Color(0xFF343640),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Report #${report['id']}',
                    style: const TextStyle(
                      color: Color(0xFF9296A2),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDraft ? 'Draft' : 'Completed',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9A9EAA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopEmptyHistory() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, color: Color(0xFF9A9EAA), size: 42),
          SizedBox(height: 11),
          Text(
            'No reports yet',
            style: TextStyle(
              color: Color(0xFF444752),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Create a new SOAP report to begin.',
            style: TextStyle(color: Color(0xFF9296A2), fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _openNewReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SOAPFormPage(
          therapistId: widget.therapistId,
          studId: widget.studId,
          studentName: widget.studName,
        ),
      ),
    ).then((_) => _fetchStudentProfile());
  }

  void _openHistoryReport(Map<String, dynamic> report) {
    final isDraft = report['status']?.toString().toLowerCase() == 'draft';
    if (isDraft) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SOAPFormPage(
            therapistId: widget.therapistId,
            studId: widget.studId,
            studentName: widget.studName,
            existingReportId: report['id'].toString(),
          ),
        ),
      ).then((_) => _fetchStudentProfile());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SoapReportViewPage(
            therapistId: widget.therapistId,
            reportId: report['id'],
          ),
        ),
      );
    }
  }

  Widget _desktopSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoItem(IconData icon, String label, String value, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor.withValues(alpha: 0.7), size: 2.5.h),
        SizedBox(height: 1.h),
        Text(
          label,
          style: TextStyle(fontSize: 9.sp, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 0.3.h),
        Text(
          value,
          style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> report) {
    DateTime? sessionDate;
    try {
      sessionDate = DateTime.parse(report['session_date']);
    } catch (e) {
      sessionDate = null;
    }

    String formattedDate = sessionDate != null
        ? DateFormat('EEEE, dd MMM yyyy').format(sessionDate)
        : 'Unknown Date';
    bool isDraft = report['status']?.toString().toLowerCase() == 'draft';

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDraft
                ? Colors.orange.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 2.h),
          leading: Container(
            height: 7.h,
            width: 7.w,
            decoration: BoxDecoration(
              color: isDraft
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDraft ? Icons.edit_document : Icons.check_circle_rounded,
              color: isDraft ? Colors.orange[800] : Colors.blue[700],
              size: 2.5.h,
            ),
          ),
          title: Text(
            formattedDate,
            style: TextStyle(fontSize: 14.sp, color: Colors.black87),
          ),
          subtitle: Text(
            isDraft ? "Status: Draft" : "Status: Completed",
            style: TextStyle(
              fontSize: 12.sp,
              color: isDraft ? Colors.orange[800] : Colors.green[700],
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.grey[400], size: 2.h),
          onTap: () {
            if (isDraft) {
              // Open Draft to edit
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SOAPFormPage(
                    therapistId: widget.therapistId,
                    studId: widget.studId,
                    studentName: widget.studName,
                    existingReportId: report['id'].toString(),
                  ),
                ),
              ).then((_) => _fetchStudentProfile());
            } else {
              // Open Completed Report View
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SoapReportViewPage(
                    therapistId: widget.therapistId,
                    reportId: report['id'],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 8.h, color: Colors.grey[300]),
          SizedBox(height: 2.h),
          Text(
            "No reports yet",
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[800]),
          ),
          SizedBox(height: 0.5.h),
          Text(
            "Create a new SOAP report to start tracking progress.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
