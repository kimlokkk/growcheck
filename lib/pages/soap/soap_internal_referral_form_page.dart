import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

// We reuse the dialog you already built in soap_hub!
import 'soap_hub.dart';

bool _useDesktopInternalReferralFormLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class InternalReferralFormPage extends StatefulWidget {
  final String therapistId;

  const InternalReferralFormPage({super.key, required this.therapistId});

  @override
  State<InternalReferralFormPage> createState() =>
      _InternalReferralFormPageState();
}

class _InternalReferralFormPageState extends State<InternalReferralFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Form Data Variables
  Map<String, dynamic>? _selectedStudent;
  DateTime? _observationDate;
  String? _referredByRole;
  String? _referredToRole;

  // Text Controllers
  final TextEditingController _problemCtrl = TextEditingController();
  final TextEditingController _concernCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // Roles exactly as written in the PDF
  final List<String> _roles = [
    "EIP Tutor",
    "Playgroup therapy",
    "Speech Therapist",
    "Occupational Therapist",
    "Clinical Psychologist"
  ];

  final String _submitUrl = ApiConfig.flutter('soap_submit_referral.php');

  /*final String _submitUrl =
      "http://app-kizzu.test/growkids/flutter/soap_submit_referral.php";*/

  @override
  void dispose() {
    _problemCtrl.dispose();
    _concernCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickObservationDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Growkids.purpleFlo, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _observationDate = picked;
      });
    }
  }

  void _showStudentSelection() {
    showDialog(
      context: context,
      builder: (context) =>
          StudentSelectionDialog(therapistId: widget.therapistId),
    ).then((student) {
      if (student != null) {
        setState(() {
          _selectedStudent = student;
        });
      }
    });
  }

  Future<void> _submitForm() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a patient first.')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_observationDate == null ||
        _referredByRole == null ||
        _referredToRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill all required dropdowns and dates.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String sId =
          (_selectedStudent!['stud_id'] ?? _selectedStudent!['id']).toString();
      String sName = _selectedStudent!['stud_name'] ??
          _selectedStudent!['student_name'] ??
          'Unknown';

      final res = await http.post(Uri.parse(_submitUrl), body: {
        'therapist_id': widget.therapistId,
        'stud_id': sId,
        'stud_name': sName,
        'observation_date': DateFormat('yyyy-MM-dd').format(_observationDate!),
        'presenting_problem': _problemCtrl.text,
        'parents_concern': _concernCtrl.text,
        'referred_by_role': _referredByRole!,
        'transfer_to': _referredToRole!,
        'notes': _notesCtrl.text,
      });

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Referral submitted successfully!'),
                backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Go back to the list
        } else {
          _showError(json['message']);
        }
      } else {
        _showError("Server error: ${res.statusCode}");
      }
    } catch (e) {
      _showError("Connection failed. Please try again.");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    String studentName = _selectedStudent != null
        ? (_selectedStudent!['stud_name'] ??
            _selectedStudent!['student_name'] ??
            'Unknown')
        : "Tap to select patient";

    if (_useDesktopInternalReferralFormLayout(context)) {
      return _buildDesktopPage(studentName);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Internal Referral Form',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Patient Selection
              _buildSectionTitle("Patient's Details"),
              InkWell(
                onTap: _showStudentSelection,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(2.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _selectedStudent == null
                            ? Colors.red.shade200
                            : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Growkids.purpleFlo),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          studentName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: _selectedStudent == null
                                ? Colors.grey[600]
                                : Colors.black87,
                            fontWeight: _selectedStudent == null
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.search, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 3.h),

              // 2. Clinical Info
              _buildSectionTitle("Clinical Observation"),

              // Date of Observation
              InkWell(
                onTap: _pickObservationDate,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _observationDate == null
                            ? "Date of Observation *"
                            : DateFormat('dd MMM yyyy')
                                .format(_observationDate!),
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: _observationDate == null
                                ? Colors.grey[600]
                                : Colors.black87),
                      ),
                      const Icon(Icons.calendar_today_rounded,
                          color: Colors.grey),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 2.h),

              // Presenting Problem
              _buildTextField(_problemCtrl, "Presenting Problem *", 3),
              SizedBox(height: 2.h),

              // Parents Concern
              _buildTextField(_concernCtrl, "Parents' main concern *", 3),
              SizedBox(height: 3.h),

              // 3. Referral Details
              _buildSectionTitle("Referral Details"),

              // Referred By
              _buildDropdown("Referred by (Your Role) *", _referredByRole,
                  (val) => setState(() => _referredByRole = val)),
              SizedBox(height: 2.h),

              // Referred To
              _buildDropdown("Referred to (Target Role) *", _referredToRole,
                  (val) => setState(() => _referredToRole = val)),
              SizedBox(height: 2.h),

              // Notes
              _buildTextField(_notesCtrl, "Additional Notes (Optional)", 4,
                  isRequired: false),
              SizedBox(height: 4.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 6.5.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Growkids.purpleFlo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Submit Referral",
                          style:
                              TextStyle(fontSize: 14.sp, color: Colors.white)),
                ),
              ),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPage(String studentName) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text(
          'Internal Referral Form',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _desktopHero(studentName),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _desktopClinicalPanel(studentName),
                        ),
                        const SizedBox(width: 20),
                        Expanded(child: _desktopReferralPanel()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  _desktopActionBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHero(String studentName) {
    final hasStudent = _selectedStudent != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(21),
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
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.sync_alt_rounded,
              color: Color(0xFF0AAE7A),
              size: 35,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEW CARE COORDINATION REQUEST',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Internal Referral',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Document the clinical concern and route the student to the appropriate service.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasStudent
                      ? Icons.check_circle_rounded
                      : Icons.person_search_rounded,
                  color: hasStudent ? const Color(0xFF8EE7BC) : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    hasStudent ? studentName : 'Patient not selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

  Widget _desktopClinicalPanel(String studentName) {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient & clinical details',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select the patient and describe the observed concern.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 10),
          ),
          const SizedBox(height: 19),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _desktopFieldLabel('Patient'),
                  InkWell(
                    onTap: _showStudentSelection,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _selectedStudent == null
                            ? const Color(0xFFFFFAF5)
                            : const Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedStudent == null
                              ? const Color(0xFFF0C99E)
                              : const Color(0xFFE0E3EA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Growkids.purpleFlo.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: _selectedStudent == null
                                ? const Icon(
                                    Icons.person_search_rounded,
                                    color: Growkids.purpleFlo,
                                  )
                                : Text(
                                    studentName.isEmpty
                                        ? '?'
                                        : studentName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Growkids.purpleFlo,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              studentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _selectedStudent == null
                                    ? const Color(0xFF9296A2)
                                    : const Color(0xFF343640),
                                fontSize: 11,
                                fontWeight: _selectedStudent == null
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF9A9EAA),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _desktopFieldLabel('Date of observation'),
                  InkWell(
                    onTap: _pickObservationDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E3EA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Growkids.purpleFlo,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _observationDate == null
                                ? 'Select observation date'
                                : DateFormat('EEEE, d MMMM yyyy')
                                    .format(_observationDate!),
                            style: TextStyle(
                              color: _observationDate == null
                                  ? const Color(0xFF9296A2)
                                  : const Color(0xFF444752),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _desktopFieldLabel('Presenting problem'),
                  SizedBox(
                    height: 105,
                    child: _desktopTextArea(
                      _problemCtrl,
                      'Describe the presenting problem...',
                      expands: true,
                      required: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _desktopFieldLabel("Parents' main concern"),
                  SizedBox(
                    height: 140,
                    child: _desktopTextArea(
                      _concernCtrl,
                      "Describe the parents' concern...",
                      expands: true,
                      required: true,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopReferralPanel() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral routing',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose the referring and target professional roles.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 10),
          ),
          const SizedBox(height: 19),
          _desktopFieldLabel('Referred by'),
          _desktopDropdown(
            'Select your role',
            _referredByRole,
            (value) => setState(() => _referredByRole = value),
          ),
          const SizedBox(height: 16),
          _desktopFieldLabel('Referred to'),
          _desktopDropdown(
            'Select target role',
            _referredToRole,
            (value) => setState(() => _referredToRole = value),
          ),
          const SizedBox(height: 19),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF9F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCDE9DF)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0A8B63),
                  size: 18,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'The target service will receive this referral for review.',
                    style: TextStyle(
                      color: Color(0xFF397264),
                      fontSize: 9,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 19),
          _desktopFieldLabel('Additional notes'),
          Expanded(
            child: _desktopTextArea(
              _notesCtrl,
              'Add optional supporting notes...',
              expands: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3E5EC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF777C8D),
            size: 18,
          ),
          const SizedBox(width: 9),
          const Text(
            'Review all required information before submitting.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 10),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitForm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('Submit Referral'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopTextArea(
    TextEditingController controller,
    String hint, {
    int? maxLines,
    bool expands = false,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: expands ? null : maxLines,
      minLines: expands ? null : 1,
      expands: expands,
      textAlignVertical: TextAlignVertical.top,
      validator: required
          ? (value) => value == null || value.trim().isEmpty
              ? 'This field is required'
              : null
          : null,
      style: const TextStyle(fontSize: 11, height: 1.4),
      decoration: _desktopInputDecoration(hint),
    );
  }

  Widget _desktopDropdown(
    String hint,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        hint,
        style: const TextStyle(color: Color(0xFF9296A2), fontSize: 10),
      ),
      items: _roles
          .map(
            (role) => DropdownMenuItem(
              value: role,
              child: Text(role, style: const TextStyle(fontSize: 11)),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: _desktopInputDecoration(hint),
    );
  }

  InputDecoration _desktopInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9296A2), fontSize: 10),
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Growkids.purpleFlo, width: 1.4),
      ),
    );
  }

  Widget _desktopFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF555966),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
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

  // UI Helpers
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h, left: 1.w),
      child: Text(title,
          style: TextStyle(fontSize: 14.sp, color: Growkids.purpleFlo)),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, int maxLines,
      {bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: isRequired
          ? (value) => value!.isEmpty ? 'This field is required' : null
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Growkids.purpleFlo)),
      ),
    );
  }

  Widget _buildDropdown(
      String hint, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(hint,
          style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
      items: _roles.map((role) {
        return DropdownMenuItem(
            value: role, child: Text(role, style: TextStyle(fontSize: 11.sp)));
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}
