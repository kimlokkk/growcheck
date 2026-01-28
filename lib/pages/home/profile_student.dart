import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

class ProfileStudent extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String age;
  final String ageInMonths;
  final int ageInMonthsINT;

  const ProfileStudent({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.age,
    required this.ageInMonths,
    required this.ageInMonthsINT,
  });

  @override
  State<ProfileStudent> createState() => _ProfileStudentState();
}

class _ProfileStudentState extends State<ProfileStudent> {
  Map<String, dynamic> profileData = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final res = await http.post(
      Uri.parse('https://app.kizzukids.com.my/growkids/flutter/student_profile.php'),
      body: {'stud_id': widget.studentId},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        profileData = data.isNotEmpty ? data[0] : {};
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Student Profile'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(2.h),
              children: [
                _profileHeader(),
                SizedBox(height: 2.h),
                _section(
                  title: 'Student Information',
                  icon: Icons.person_outline_rounded,
                  children: [
                    _row('Date of Birth', DateFormat('d MMM yyyy').format(DateTime.parse(profileData['stud_dob']))),
                    _row('Age', widget.age),
                    _row('Age (Months)', widget.ageInMonths),
                    _row('Gender', profileData['stud_sex']),
                    _row('Religion', profileData['stud_religion']),
                    _row('Race', profileData['stud_race']),
                    _row('Address', profileData['stud_address']),
                    _row('Email', profileData['stud_email']),
                  ],
                ),
                SizedBox(height: 2.h),
                _section(
                  title: 'Student Concern & Hope',
                  icon: Icons.priority_high,
                  children: [
                    _row('Concern', profileData['stud_concern']),
                    _row('Hope', profileData['stud_hope']),
                  ],
                ),
                SizedBox(height: 2.h),
                _section(
                  title: 'Health & Development',
                  icon: Icons.health_and_safety_outlined,
                  children: [
                    _row('Pregnancy Method', profileData['stud_method_pregnant']),
                    _row('Complication', profileData['stud_complication']),
                    _row('Medical Checkup', profileData['stud_checkup']),
                    _row('Health Issue', profileData['stud_health']),
                    _row('Visual / Audio Issue', profileData['stud_visual_audio']),
                    _row('Home Language', profileData['stud_language']),
                    _row('Gadget Usage', profileData['stud_gadget']),
                  ],
                ),
                SizedBox(height: 2.h),
                _section(
                  title: 'Parent Information',
                  icon: Icons.family_restroom_outlined,
                  children: [
                    _row('Father Name', profileData['stud_father_name']),
                    _row('Father Occupation', profileData['stud_father_occu']),
                    _row('Father Contact', profileData['stud_father_contact']),
                    const Divider(height: 24),
                    _row('Mother Name', profileData['stud_mother_name']),
                    _row('Mother Occupation', profileData['stud_mother_occu']),
                    _row('Mother Contact', profileData['stud_mother_contact']),
                  ],
                ),
              ],
            ),
    );
  }

  // =========================
  // UI COMPONENTS
  // =========================

  Widget _profileHeader() {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white,
            child: Text(
              widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : '?',
              style: TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                  ),
                ),
                Text(
                  '${widget.age} • ${widget.ageInMonths}',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Growkids.purpleFlo,
                size: 3.h,
              ),
              SizedBox(width: 1.w),
              Text(title,
                  style: TextStyle(
                    fontSize: 16.sp,
                  )),
            ],
          ),
          SizedBox(height: 2.h),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(fontSize: 14.sp, color: Colors.black.withOpacity(0.6)),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value?.isNotEmpty == true ? value! : '-',
              style: TextStyle(
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
