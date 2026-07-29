import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';

import 'soap_summary_pdf_preview.dart';

class SoapSummaryViewPage extends StatefulWidget {
  final String therapistId;
  final String reportId;

  const SoapSummaryViewPage(
      {super.key, required this.therapistId, required this.reportId});

  @override
  State<SoapSummaryViewPage> createState() => _SoapSummaryViewPageState();
}

class _SoapSummaryViewPageState extends State<SoapSummaryViewPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  String _errorMessage = '';

  final String _apiUrl = ApiConfig.flutter('soap_get_summary_report.php');

  /*final String _apiUrl =
      "http://app-kizzu.test/growkids/flutter/soap_get_summary_report.php";*/

  @override
  void initState() {
    super.initState();
    _fetchReportDetails();
  }

  Future<void> _fetchReportDetails() async {
    try {
      final res = await http.post(
        Uri.parse(_apiUrl),
        body: {
          'report_id': widget.reportId,
          'therapist_id': widget.therapistId,
        },
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          setState(() {
            _reportData = json['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = json['message'] ?? 'Failed to load report.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _calculateAge(String? dobString, String? reportDateString) {
    if (dobString == null || dobString.isEmpty) return "Unknown";
    try {
      DateTime dob = DateTime.parse(dobString);
      DateTime reportDate = reportDateString != null
          ? DateTime.parse(reportDateString)
          : DateTime.now();

      int years = reportDate.year - dob.year;
      int months = reportDate.month - dob.month;

      if (months < 0) {
        years--;
        months += 12;
      }
      return "$years yrs $months mos";
    } catch (e) {
      return "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE), // Softer, modern background
      appBar: AppBar(
        title: const Text("Official Summary Report",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Preview PDF',
            onPressed: () {
              if (_reportData != null) {
                // Navigate to the interactive PDF Preview page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SoapSummaryPdfPreviewPage(reportData: _reportData!),
                  ),
                );
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: TextStyle(color: Colors.red, fontSize: 12.sp)))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                      top: 2.h, left: 2.h, right: 2.h, bottom: 5.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      SizedBox(height: 2.5.h),
                      _buildSectionCard(
                        title: "Background Information",
                        icon: Icons.history_edu_rounded,
                        iconColor: Colors.blue[600]!,
                        content:
                            _buildSimpleText(_reportData!['background_info']),
                      ),
                      _buildSectionCard(
                        title: "Activities of Daily Living (ADL)",
                        icon: Icons.accessibility_new_rounded,
                        iconColor: Colors.orange[600]!,
                        content: _buildMapContent(_reportData!['adl_data']),
                      ),
                      _buildSectionCard(
                        title: "Developmental Skills",
                        icon: Icons.extension_rounded, // Puzzle icon
                        iconColor: Colors.teal[600]!,
                        content: _buildMapContent(_reportData!['skills_data']),
                      ),
                      _buildSectionCard(
                        title: "Sensory & Behavior",
                        icon: Icons.psychology_rounded,
                        iconColor: Colors.pink[600]!,
                        content: _buildMapContent(
                            _reportData!['sensory_behavior_data']),
                      ),
                      _buildHighlightSection(
                        title: "Summary & Recommendation",
                        icon: Icons.stars_rounded,
                        content: _reportData!['summary_recommendation'],
                      ),
                    ],
                  ),
                ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildProfileHeader() {
    String name = _reportData!['stud_name'] ?? 'Unknown';
    String dob = _reportData!['stud_dob'] ?? 'Unknown';
    String reportDate = _reportData!['date_of_report'] ?? '';
    String sessions = _reportData!['sessions_attended']?.toString() ?? '0';
    String status = _reportData!['status']?.toString().toUpperCase() ?? 'DRAFT';

    String formattedDate = reportDate.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(reportDate))
        : 'Unknown';
    String ageStr = _calculateAge(dob, reportDate);
    bool isFinal = status == 'FINAL';

    return Container(
      padding: EdgeInsets.all(2.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Growkids.purpleFlo.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          // Top Row: Avatar & Name
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
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                      name,
                      style: TextStyle(
                          fontSize: 16.sp, color: Colors.black87, height: 1.2),
                    ),
                    SizedBox(height: 0.5.h),
                    Row(
                      children: [
                        Icon(Icons.event_note_rounded,
                            size: 1.5.h, color: Colors.grey[500]),
                        SizedBox(width: 1.w),
                        Text("Report Date: $formattedDate",
                            style: TextStyle(
                                fontSize: 12.sp, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 2.5.h),
          Divider(color: Colors.grey[100], height: 1, thickness: 1.5),
          SizedBox(height: 2.h),

          // Bottom Row: Stats & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat("Age", ageStr),
              Container(width: 1.5, height: 3.h, color: Colors.grey[200]),
              _buildMiniStat("Sessions", sessions),
              Container(width: 1.5, height: 3.h, color: Colors.grey[200]),
              // Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: isFinal
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isFinal
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isFinal ? Colors.green[800] : Colors.orange[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
        SizedBox(height: 0.3.h),
        Text(value, style: TextStyle(fontSize: 12.sp, color: Colors.black87)),
      ],
    );
  }

  // --- STANDARD SECTION CARD ---
  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      required Color iconColor,
      required Widget content}) {
    // If the content is an empty SizedBox, don't render the card at all
    if (content is SizedBox &&
        content.width == null &&
        content.height == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 3.h),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14.sp, color: iconColor),
                  ),
                ),
              ],
            ),
          ),
          // Card Body
          Padding(
            padding: EdgeInsets.all(2.h),
            child: content,
          ),
        ],
      ),
    );
  }

  // --- HIGHLIGHTED CONCLUSION SECTION ---
  Widget _buildHighlightSection(
      {required String title,
      required IconData icon,
      required String? content}) {
    if (content == null || content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 2.h, top: 1.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo.withValues(alpha: 0.1),
            Growkids.purpleFlo.withValues(alpha: 0.02)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Growkids.purpleFlo.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(2.h, 2.h, 2.h, 0),
            child: Row(
              children: [
                Icon(icon, color: Growkids.purpleFlo, size: 3.h),
                SizedBox(width: 3.w),
                Text(
                  title,
                  style: TextStyle(fontSize: 14.sp, color: Growkids.purpleFlo),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(2.h),
            child: Text(
              content.trim(),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CONTENT BUILDERS ---

  Widget _buildSimpleText(String? text) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      text.trim(),
      style: TextStyle(fontSize: 11.sp, color: Colors.black87, height: 1.5),
    );
  }

  Widget _buildMapContent(dynamic data) {
    if (data == null || data is! Map || data.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty entries
    Map<String, dynamic> validData = {};
    data.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        validData[key] = value.toString().trim();
      }
    });

    if (validData.isEmpty) return const SizedBox.shrink();

    List<Widget> children = [];
    int index = 0;

    validData.forEach((key, value) {
      children.add(
        Padding(
          padding: EdgeInsets.only(
              bottom: index == validData.length - 1 ? 0 : 1.5.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]),
              ),
              SizedBox(height: 0.5.h),
              Text(
                value.toString(),
                style: TextStyle(
                    fontSize: 12.sp, color: Colors.grey[700], height: 1.4),
              ),
              if (index != validData.length - 1) ...[
                SizedBox(height: 1.5.h),
                Divider(color: Colors.grey[100], height: 1),
              ]
            ],
          ),
        ),
      );
      index++;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
