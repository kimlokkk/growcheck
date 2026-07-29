import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';

import 'soap_hub.dart'; // To use your StudentSelectionDialog

bool _useDesktopSoapSummaryFormLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  final desktopPlatform = platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class SoapSummaryFormPage extends StatefulWidget {
  final String therapistId;
  final String? existingReportId;

  const SoapSummaryFormPage(
      {super.key, required this.therapistId, this.existingReportId});

  @override
  State<SoapSummaryFormPage> createState() => _SoapSummaryFormPageState();
}

class _SoapSummaryFormPageState extends State<SoapSummaryFormPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isLoading = false;
  bool _isSaving = false;
  String? _currentReportId;

  // Student Info
  Map<String, dynamic>? _selectedStudent;

  // Header Controllers
  DateTime _reportDate = DateTime.now();
  final TextEditingController _sessionsAttendedCtrl = TextEditingController();

  // Background & Summary Controllers
  final TextEditingController _backgroundCtrl = TextEditingController();
  final TextEditingController _recommendationCtrl = TextEditingController();

  // Data Maps for JSON storage (Matching PDF structure)
  final Map<String, TextEditingController> _adlControllers = {
    "Feeding": TextEditingController(),
    "Bowel/Bladder Management (Toileting)": TextEditingController(),
    "Dressing / Undressing": TextEditingController(),
    "Grooming / Hygiene": TextEditingController(),
    "Sleep": TextEditingController(),
  };

  final Map<String, TextEditingController> _skillsControllers = {
    "Play Skills": TextEditingController(),
    "Social & Pre-verbal Skills": TextEditingController(),
    "Motor Skills (Gross & Fine)": TextEditingController(),
    "Cognitive Skills": TextEditingController(),
  };

  final Map<String, TextEditingController> _sensoryBehaviorControllers = {
    "Behavior & Emotional": TextEditingController(),
    "Sensory Function": TextEditingController(),
  };

  final String _saveApi = ApiConfig.flutter('soap_save_summary_report.php');
  /*final String _saveApi =
      "http://app-kizzu.test/growkids/flutter/soap_save_summary_report.php";*/

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentReportId = widget.existingReportId;

    if (_currentReportId != null) {
      // TODO: Add fetch logic if editing an existing draft
    } else {
      // Open student selection immediately if it's a new report
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showStudentSelection());
    }
  }

  void _showStudentSelection() {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to pick or go back
      builder: (context) => StudentSelectionDialog(
        therapistId: widget.therapistId,
        desktopTitle: 'New SOAP Summary Report',
        desktopSubtitle:
            'Select a student to prepare their official progress summary.',
        desktopIcon: Icons.summarize_rounded,
      ),
    ).then((student) {
      if (student != null) {
        setState(() => _selectedStudent = student);
      } else if (_selectedStudent == null) {
        Navigator.pop(context); // Exit page if they cancel without picking
      }
    });
  }

  Future<bool> _saveData(String status) async {
    if (_selectedStudent == null) return false;

    setState(() => _isSaving = true);
    try {
      // Convert Maps to JSON Strings
      Map<String, String> adlData = {};
      _adlControllers.forEach((k, v) => adlData[k] = v.text);

      Map<String, String> skillsData = {};
      _skillsControllers.forEach((k, v) => skillsData[k] = v.text);

      Map<String, String> sbData = {};
      _sensoryBehaviorControllers.forEach((k, v) => sbData[k] = v.text);

      String sId =
          (_selectedStudent!['stud_id'] ?? _selectedStudent!['id']).toString();

      final payload = {
        'report_id': _currentReportId ?? '',
        'stud_id': sId,
        'therapist_id': widget.therapistId,
        'sessions_attended': _sessionsAttendedCtrl.text.isEmpty
            ? '0'
            : _sessionsAttendedCtrl.text,
        'date_of_report': DateFormat('yyyy-MM-dd').format(_reportDate),
        'background_info': _backgroundCtrl.text,
        'adl_data': jsonEncode(adlData),
        'skills_data': jsonEncode(skillsData),
        'sensory_behavior_data': jsonEncode(sbData),
        'summary_recommendation': _recommendationCtrl.text,
        'status': status,
      };

      final res = await http.post(Uri.parse(_saveApi), body: payload);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          _currentReportId = json['report_id'].toString();
          return true;
        }
      }
    } catch (e) {
      print("Save Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    return false;
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _reportDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    String studentName = _selectedStudent != null
        ? (_selectedStudent!['stud_name'] ??
            _selectedStudent!['student_name'] ??
            'Unknown')
        : "Select Student";

    if (_useDesktopSoapSummaryFormLayout(context)) {
      return _buildDesktopPage(studentName);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text("Summary: $studentName",
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Background"),
            Tab(text: "ADL & Play"),
            Tab(text: "Skills & Behavior"),
            Tab(text: "Summary"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : Column(
              children: [
                // Header Details
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(2.h),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Report Date',
                                border: OutlineInputBorder(),
                                isDense: true),
                            child: Text(
                                DateFormat('dd MMM yyyy').format(_reportDate),
                                style: TextStyle(fontSize: 12.sp)),
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _sessionsAttendedCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Sessions',
                              border: OutlineInputBorder(),
                              isDense: true),
                          style: TextStyle(fontSize: 12.sp),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBackgroundTab(),
                      _buildAdlTab(),
                      _buildSkillsTab(),
                      _buildSummaryTab(),
                    ],
                  ),
                ),

                // Save Buttons
                Container(
                  padding: EdgeInsets.all(2.h),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  bool success = await _saveData('draft');
                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Draft saved!"),
                                            backgroundColor: Colors.green));
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            side: const BorderSide(color: Growkids.purpleFlo),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            "Save Draft",
                            style: TextStyle(
                              color: Growkids.purpleFlo,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  bool success = await _saveData('final');
                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Report Finalized!"),
                                            backgroundColor: Colors.green));
                                    Navigator.pop(context, true);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Growkids.purpleFlo,
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ))
                              : Text(
                                  "Finalize",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopPage(String studentName) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.existingReportId == null
              ? 'New SOAP Summary Report'
              : 'Edit SOAP Summary Report',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1520),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                    child: Column(
                      children: [
                        _desktopSummaryHero(studentName),
                        const SizedBox(height: 18),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _tabController,
                            builder: (context, _) => Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 270,
                                  child: _desktopSectionNavigation(),
                                ),
                                const SizedBox(width: 18),
                                Expanded(child: _desktopActiveSection()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _desktopActionBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopSummaryHero(String studentName) {
    final hasStudent = _selectedStudent != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              hasStudent && studentName.isNotEmpty
                  ? studentName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OFFICIAL PROGRESS SUMMARY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Document progress across daily living, development, sensory, and behavioural areas.',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          _desktopHeroControl(
            icon: Icons.calendar_month_rounded,
            label: 'Report date',
            value: DateFormat('dd MMM yyyy').format(_reportDate),
            onTap: _selectDate,
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 150,
            child: TextField(
              controller: _sessionsAttendedCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                labelText: 'Sessions attended',
                labelStyle: const TextStyle(color: Colors.white70, fontSize: 9),
                prefixIcon: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          OutlinedButton.icon(
            onPressed: _showStudentSelection,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Change student'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeroControl({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 170,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 8),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopSectionNavigation() {
    const items = [
      (
        Icons.history_edu_rounded,
        'Background',
        'History and presenting context'
      ),
      (
        Icons.accessibility_new_rounded,
        'ADL & Play',
        'Daily living performance'
      ),
      (
        Icons.extension_rounded,
        'Skills & Behavior',
        'Development and regulation'
      ),
      (Icons.auto_awesome_rounded, 'Summary', 'Overall recommendations'),
    ];

    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report sections',
            style: TextStyle(
              color: Color(0xFF292B35),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Complete each section before finalising.',
            style: TextStyle(color: Color(0xFF858A98), fontSize: 9),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < items.length; index++) ...[
            _desktopNavigationItem(
              index,
              items[index].$1,
              items[index].$2,
              items[index].$3,
            ),
            if (index != items.length - 1) const SizedBox(height: 9),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Growkids.purpleFlo,
                  size: 18,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'The information entered here will be used in the official PDF report.',
                    style: TextStyle(
                      color: Color(0xFF68627E),
                      fontSize: 8,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopNavigationItem(
    int index,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = _tabController.index == index;
    return InkWell(
      onTap: () => _tabController.animateTo(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Growkids.purpleFlo.withValues(alpha: 0.10)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Growkids.purpleFlo.withValues(alpha: 0.30)
                : const Color(0xFFE5E7EE),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Growkids.purpleFlo : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF777C8D),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? Growkids.purpleFlo
                          : const Color(0xFF3E414C),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Color(0xFF969AA6),
                      fontSize: 7,
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

  Widget _desktopActiveSection() {
    switch (_tabController.index) {
      case 1:
        return _desktopAdlSection();
      case 2:
        return _desktopSkillsSection();
      case 3:
        return _desktopSummarySection();
      default:
        return _desktopBackgroundSection();
    }
  }

  Widget _desktopBackgroundSection() {
    return _desktopFormSection(
      icon: Icons.history_edu_rounded,
      title: 'Patient Background & History',
      subtitle:
          'Summarise the referral context, chief concerns, relevant history, and therapy journey.',
      child: _desktopTextArea(
        'Background information',
        'Write the introduction, chief complaints, relevant history, and context...',
        _backgroundCtrl,
        minHeight: 300,
      ),
    );
  }

  Widget _desktopAdlSection() {
    return _desktopFormSection(
      icon: Icons.accessibility_new_rounded,
      title: 'Activities of Daily Living (ADL)',
      subtitle:
          'Document current performance, assistance required, and meaningful progress.',
      child: _desktopFieldGrid(_adlControllers),
    );
  }

  Widget _desktopSkillsSection() {
    return _desktopFormSection(
      icon: Icons.extension_rounded,
      title: 'Developmental Skills & Behavior',
      subtitle:
          'Record functional development, sensory responses, and emotional regulation.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopSubsectionTitle('Developmental Skills'),
          _desktopFieldGrid(_skillsControllers),
          const SizedBox(height: 20),
          _desktopSubsectionTitle('Sensory & Behavior'),
          _desktopFieldGrid(_sensoryBehaviorControllers),
        ],
      ),
    );
  }

  Widget _desktopSummarySection() {
    return _desktopFormSection(
      icon: Icons.auto_awesome_rounded,
      title: 'Summary & Recommendations',
      subtitle:
          'Provide a concise progress overview and clear recommendations for the next care period.',
      child: _desktopTextArea(
        'Overall progress and future recommendations',
        'Summarise progress, ongoing concerns, goals, and recommendations...',
        _recommendationCtrl,
        minHeight: 300,
      ),
    );
  }

  Widget _desktopFormSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return _desktopSurface(
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
                  color: Growkids.purpleFlo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Growkids.purpleFlo, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF292B35),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF858A98),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_tabController.index + 1} of 4',
                style: const TextStyle(
                  color: Growkids.purpleFlo,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE7E9EF)),
          const SizedBox(height: 18),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }

  Widget _desktopFieldGrid(
    Map<String, TextEditingController> controllers,
  ) {
    final fields = controllers.entries.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final field in fields)
              SizedBox(
                width: fieldWidth,
                child: _desktopTextArea(
                  field.key,
                  'Describe ${field.key.toLowerCase()}...',
                  field.value,
                  minHeight: 132,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _desktopTextArea(
    String label,
    String hint,
    TextEditingController controller, {
    required double minHeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF494C58),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: TextField(
            controller: controller,
            minLines: minHeight >= 250 ? 12 : 5,
            maxLines: null,
            style: const TextStyle(
              color: Color(0xFF464955),
              fontSize: 11,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFFA1A5B0), fontSize: 10),
              filled: true,
              fillColor: const Color(0xFFF8F9FC),
              contentPadding: const EdgeInsets.all(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Growkids.purpleFlo, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopSubsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Text(
        title,
        style: const TextStyle(
          color: Growkids.purpleFlo,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7ED)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D6170).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _desktopActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E6EC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF8B909E),
            size: 19,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Review all report sections before finalising the official summary.',
              style: TextStyle(color: Color(0xFF777C89), fontSize: 9),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _saveDesktopReport('draft'),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Growkids.purpleFlo,
              side: const BorderSide(color: Growkids.purpleFlo),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
          const SizedBox(width: 11),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : () => _saveDesktopReport('final'),
            icon: _isSaving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.task_alt_rounded, size: 18),
            label: const Text('Finalize Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDesktopReport(String status) async {
    final success = await _saveData(status);
    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            status == 'final' ? 'Report finalized!' : 'Summary draft saved!'),
        backgroundColor: Colors.green,
      ),
    );
    if (status == 'final') Navigator.pop(context, true);
  }

  // --- TAB 1: Background ---
  Widget _buildBackgroundTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Patient Background & History"),
          _customTextField(
              "Write the introduction, chief complaints, and history here...",
              _backgroundCtrl,
              maxLines: 15),
        ],
      ),
    );
  }

  // --- TAB 2: ADL & Play ---
  Widget _buildAdlTab() {
    return ListView(
      padding: EdgeInsets.all(2.h),
      children: [
        _sectionTitle("Activities of Daily Living (ADL)"),
        ..._adlControllers.keys.map(
            (key) => _customTextField(key, _adlControllers[key]!, maxLines: 3)),
      ],
    );
  }

  // --- TAB 3: Skills & Behavior ---
  Widget _buildSkillsTab() {
    return ListView(
      padding: EdgeInsets.all(2.h),
      children: [
        _sectionTitle("Developmental Skills"),
        ..._skillsControllers.keys.map((key) =>
            _customTextField(key, _skillsControllers[key]!, maxLines: 4)),
        SizedBox(height: 2.h),
        _sectionTitle("Sensory & Behavior"),
        ..._sensoryBehaviorControllers.keys.map((key) => _customTextField(
            key, _sensoryBehaviorControllers[key]!,
            maxLines: 4)),
      ],
    );
  }

  // --- TAB 4: Summary ---
  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Summary & Recommendations"),
          Text("This section will appear at the very end of the PDF report.",
              style: TextStyle(color: Colors.grey[600], fontSize: 10.sp)),
          SizedBox(height: 1.5.h),
          _customTextField(
              "Provide the overall progress summary and future recommendations here...",
              _recommendationCtrl,
              maxLines: 15),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h, top: 1.h),
      child: Text(title,
          style: TextStyle(fontSize: 14.sp, color: Growkids.purpleFlo)),
    );
  }

  Widget _customTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          alignLabelWithHint: true,
          labelText: label,
          labelStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Growkids.purpleFlo, width: 1.5)),
        ),
      ),
    );
  }
}
