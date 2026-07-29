import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/soap/soap_student_page.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

bool _useDesktopActiveStudentsLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class ActiveStudentsPage extends StatefulWidget {
  final String therapistId;

  const ActiveStudentsPage({super.key, required this.therapistId});

  @override
  State<ActiveStudentsPage> createState() => _ActiveStudentsPageState();
}

class _ActiveStudentsPageState extends State<ActiveStudentsPage> {
  bool _isLoading = true;
  List<dynamic> _students = [];

  static final String _apiUrl =
      ApiConfig.flutter('soap_get_active_student.php');
  /*static const _apiUrl =
      "http://app-kizzu.test/growkids/flutter/soap_get_active_student.php";*/

  @override
  void initState() {
    super.initState();
    _fetchActiveStudents();
  }

  Future<void> _fetchActiveStudents() async {
    try {
      final res = await http.post(
        Uri.parse(_apiUrl),
        body: {'therapist_id': widget.therapistId},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          setState(() {
            _students = json['data'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Error fetching active students: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopActiveStudentsLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Active Students',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : _students.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Growkids.purpleFlo,
                  onRefresh: _fetchActiveStudents,
                  child: GridView.builder(
                    padding: EdgeInsets.all(2.h),
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 3.w,
                      mainAxisSpacing: 3.w,
                      childAspectRatio: 2.15,
                    ),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      String sId = student['stud_id'].toString();
                      String sName = student['stud_name'] ?? 'Unknown';
                      String program = student['program'] ?? 'General Program';

                      return _buildCompactCard(sId, sName, program);
                    },
                  ),
                ),
    );
  }

  Widget _buildCompactCard(String sId, String studName, String program) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentSoapProfilePage(
                  therapistId: widget.therapistId,
                  studId: sId, // Make sure you have access to stud_id here
                  studName: studName,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
            child: Row(
              children: [
                // Avatar on the left
                Container(
                  width: 5.h,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    studName.isNotEmpty ? studName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Growkids.purpleFlo,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                SizedBox(width: 2.5.w),

                // Name and Program stacked in a column on the right
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 0.2.h),
                      Text(
                        program,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  Widget _buildDesktopPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text(
          'Active Students',
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
            onPressed: _isLoading ? null : _fetchActiveStudents,
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
                      _desktopHero(),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Student directory',
                                  style: TextStyle(
                                    color: Color(0xFF242631),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Select a student to access their SOAP profile.',
                                  style: TextStyle(
                                    color: Color(0xFF777C8D),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Growkids.purpleFlo.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_students.length} active students',
                              style: const TextStyle(
                                color: Growkids.purpleFlo,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      Expanded(
                        child: _students.isEmpty
                            ? _desktopEmptyState()
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns =
                                      constraints.maxWidth >= 1150 ? 4 : 3;
                                  return GridView.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      mainAxisExtent: 170,
                                    ),
                                    itemCount: _students.length,
                                    itemBuilder: (context, index) {
                                      final student = _students[index];
                                      return _desktopStudentCard(
                                        student['stud_id'].toString(),
                                        student['stud_name'] ?? 'Unknown',
                                        student['program'] ?? 'General Program',
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Growkids.purpleFlo,
              size: 38,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOAP CASELOAD',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Active Students',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage SOAP documentation for students in active programmes.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _students.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Students',
                      style: TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopStudentCard(String id, String name, String program) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openStudent(id, name),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE3E5EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Growkids.purpleFlo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Growkids.purpleFlo,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Growkids.purpleFlo,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF292B35),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                program,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF777C8D),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Student ID $id',
                style: const TextStyle(
                  color: Color(0xFF9A9EAA),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStudent(String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSoapProfilePage(
          therapistId: widget.therapistId,
          studId: id,
          studName: name,
        ),
      ),
    );
  }

  Widget _desktopEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.face_outlined, size: 44, color: Color(0xFF9A9EAA)),
          SizedBox(height: 12),
          Text(
            'No active students found',
            style: TextStyle(
              color: Color(0xFF444752),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_rounded, size: 10.h, color: Colors.grey[300]),
          SizedBox(height: 2.h),
          Text(
            "No active students found.",
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
