import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopProfileLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

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
      Uri.parse(ApiConfig.flutter('student_profile.php')),
      /*Uri.parse('http://app-kizzu.test/growkids/flutter/student_profile.php'),*/
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
    if (_useDesktopProfileLayout(context)) {
      return _buildDesktop(context);
    }

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
                    _row(
                        'Date of Birth',
                        DateFormat('d MMM yyyy')
                            .format(DateTime.parse(profileData['stud_dob']))),
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
                    _row('Pregnancy Method',
                        profileData['stud_method_pregnant']),
                    _row('Complication', profileData['stud_complication']),
                    _row('Medical Checkup', profileData['stud_checkup']),
                    _row('Health Issue', profileData['stud_health']),
                    _row('Visual / Audio Issue',
                        profileData['stud_visual_audio']),
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

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      appBar: AppBar(
        title: const Text('Student Profile'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    children: [
                      _desktopProfileSummary(),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: Column(
                              children: [
                                _studentInformationSection(),
                                const SizedBox(height: 18),
                                _healthSection(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 9,
                            child: Column(
                              children: [
                                _concernSection(),
                                const SizedBox(height: 18),
                                _parentSection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopProfileSummary() {
    final initial = widget.studentName.isNotEmpty
        ? widget.studentName[0].toUpperCase()
        : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Growkids.purpleFlo,
                  Growkids.purpleFlo.withValues(alpha: 0.72),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    color: Color(0xFF1F2430),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryChip(Icons.cake_outlined, widget.age),
                    _summaryChip(
                      Icons.calendar_view_month_rounded,
                      widget.ageInMonths,
                    ),
                    _summaryChip(
                      Icons.badge_outlined,
                      'ID ${widget.studentId}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8F1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF27966B),
                  size: 17,
                ),
                SizedBox(width: 7),
                Text(
                  'Profile record',
                  style: TextStyle(
                    color: Color(0xFF207A57),
                    fontSize: 12,
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

  Widget _studentInformationSection() {
    return _desktopSection(
      title: 'Student Information',
      icon: Icons.person_outline_rounded,
      children: [
        _desktopRow(
          'Date of Birth',
          DateFormat('d MMM yyyy').format(
            DateTime.parse(profileData['stud_dob']),
          ),
        ),
        _desktopRow('Age', widget.age),
        _desktopRow('Age (Months)', widget.ageInMonths),
        _desktopRow('Gender', profileData['stud_sex']),
        _desktopRow('Religion', profileData['stud_religion']),
        _desktopRow('Race', profileData['stud_race']),
        _desktopRow('Address', profileData['stud_address']),
        _desktopRow('Email', profileData['stud_email']),
      ],
    );
  }

  Widget _healthSection() {
    return _desktopSection(
      title: 'Health & Development',
      icon: Icons.health_and_safety_outlined,
      children: [
        _desktopRow('Pregnancy Method', profileData['stud_method_pregnant']),
        _desktopRow('Complication', profileData['stud_complication']),
        _desktopRow('Medical Checkup', profileData['stud_checkup']),
        _desktopRow('Health Issue', profileData['stud_health']),
        _desktopRow('Visual / Audio Issue', profileData['stud_visual_audio']),
        _desktopRow('Home Language', profileData['stud_language']),
        _desktopRow('Gadget Usage', profileData['stud_gadget']),
      ],
    );
  }

  Widget _concernSection() {
    return _desktopSection(
      title: 'Concern & Hope',
      icon: Icons.lightbulb_outline_rounded,
      children: [
        _desktopNarrative(
          'Concern',
          profileData['stud_concern'],
          const Color(0xFFFF8A65),
        ),
        const SizedBox(height: 12),
        _desktopNarrative(
          'Hope',
          profileData['stud_hope'],
          const Color(0xFF26A69A),
        ),
      ],
    );
  }

  Widget _parentSection() {
    return _desktopSection(
      title: 'Parent Information',
      icon: Icons.family_restroom_outlined,
      children: [
        _parentBlock(
          'Father',
          profileData['stud_father_name'],
          profileData['stud_father_occu'],
          profileData['stud_father_contact'],
          Icons.man_rounded,
        ),
        const SizedBox(height: 14),
        _parentBlock(
          'Mother',
          profileData['stud_mother_name'],
          profileData['stud_mother_occu'],
          profileData['stud_mother_contact'],
          Icons.woman_rounded,
        ),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F0FF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Growkids.purpleFlo, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF56516B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopNarrative(String label, String? value, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          SelectableText(
            value?.isNotEmpty == true ? value! : '-',
            style: const TextStyle(
              color: Color(0xFF343741),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _parentBlock(
    String relationship,
    String? name,
    String? occupation,
    String? contact,
    IconData icon,
  ) {
    String display(String? value) => value?.isNotEmpty == true ? value! : '-';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.045)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Growkids.purpleFlo, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relationship,
                  style: const TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  display(name),
                  style: const TextStyle(
                    color: Color(0xFF262933),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  display(occupation),
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  display(contact),
                  style: const TextStyle(
                    color: Color(0xFF4D5260),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Growkids.purpleFlo, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _desktopRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.52),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value?.isNotEmpty == true ? value! : '-',
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
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
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white,
            child: Text(
              widget.studentName.isNotEmpty
                  ? widget.studentName[0].toUpperCase()
                  : '?',
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
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14.sp),
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
            color: Colors.black.withValues(alpha: 0.06),
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
              style: TextStyle(
                  fontSize: 14.sp, color: Colors.black.withValues(alpha: 0.6)),
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
