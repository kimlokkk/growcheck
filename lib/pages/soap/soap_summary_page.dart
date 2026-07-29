import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/soap/soap_summary_view.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

import 'soap_summary_form_page.dart';

bool _useDesktopSoapSummaryLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

// We will import the form page here once it's built
// import 'soap_summary_form_page.dart';

class SoapSummaryPage extends StatefulWidget {
  final String therapistId;

  const SoapSummaryPage({super.key, required this.therapistId});

  @override
  State<SoapSummaryPage> createState() => _SoapSummaryPageState();
}

class _SoapSummaryPageState extends State<SoapSummaryPage> {
  bool _isLoading = true;
  List<dynamic> _summaryReports = [];

  final String _apiUrl = ApiConfig.flutter('soap_get_summary_reports.php');
  /*final String _apiUrl =
      "http://app-kizzu.test/growkids/flutter/soap_get_summary_reports.php";*/

  @override
  void initState() {
    super.initState();
    _fetchSummaryReports();
  }

  Future<void> _fetchSummaryReports() async {
    try {
      final res = await http.post(
        Uri.parse(_apiUrl),
        body: {'therapist_id': widget.therapistId},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          if (mounted) {
            setState(() {
              _summaryReports = json['data'] ?? [];
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching summary reports: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSoapSummaryLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Summary Reports',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SoapSummaryFormPage(therapistId: widget.therapistId),
            ),
          ).then((_) => _fetchSummaryReports());
        },
        backgroundColor: Growkids.purpleFlo,
        icon: const Icon(Icons.post_add_rounded, color: Colors.white),
        label: const Text("New Summary",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : _summaryReports.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Growkids.purpleFlo,
                  onRefresh: _fetchSummaryReports,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                        top: 2.h, left: 2.h, right: 2.h, bottom: 10.h),
                    itemCount: _summaryReports.length,
                    itemBuilder: (context, index) {
                      return _buildSummaryCard(_summaryReports[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> report) {
    String studName = report['stud_name'] ?? 'Unknown Student';
    String sessions = report['sessions_attended']?.toString() ?? '0';
    String status = report['status'] ?? 'Draft';

    String dateStr = "Unknown Date";
    if (report['date_of_report'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(report['date_of_report']);
        dateStr = DateFormat('dd MMM yyyy').format(parsedDate);
      } catch (e) {
        // Fallback
      }
    }

    bool isFinal = status.toLowerCase() == 'final';

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isFinal) {
              // 1. Open the Read-Only Viewer if it is 'FINAL'
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SoapSummaryViewPage(
                    therapistId: widget.therapistId,
                    reportId: report['id'].toString(),
                  ),
                ),
              );
            } else {
              // 2. Open the Form Editor if it is still a 'DRAFT'
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SoapSummaryFormPage(
                    therapistId: widget.therapistId,
                    existingReportId: report['id'].toString(),
                  ),
                ),
              ).then((_) =>
                  _fetchSummaryReports()); // Refresh the list when returning
            }
          },
          child: Padding(
            padding: EdgeInsets.all(2.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  padding: EdgeInsets.all(1.5.h),
                  decoration: BoxDecoration(
                    color: isFinal
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isFinal
                        ? Icons.check_circle_outline_rounded
                        : Icons.edit_document,
                    color: isFinal ? Colors.green[700] : Colors.orange[800],
                    size: 3.h,
                  ),
                ),
                SizedBox(width: 3.w),

                // Report Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studName,
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        "Generated: $dateStr",
                        style:
                            TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 1.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2.w, vertical: 0.5.h),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$sessions Sessions",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2.w, vertical: 0.5.h),
                            decoration: BoxDecoration(
                              color: isFinal
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isFinal
                                    ? Colors.green[800]
                                    : Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.grey[400], size: 2.h),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final finalCount = _summaryReports
        .where((report) =>
            (report['status'] ?? '').toString().toLowerCase() == 'final')
        .length;
    final draftCount = _summaryReports.length - finalCount;
    final sessionCount = _summaryReports.fold<int>(
      0,
      (total, report) =>
          total +
          (int.tryParse(report['sessions_attended']?.toString() ?? '') ?? 0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text(
          'SOAP Reports',
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
            onPressed: _isLoading ? null : _fetchSummaryReports,
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
                      _desktopHero(draftCount, finalCount, sessionCount),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Summary reports',
                                  style: TextStyle(
                                    color: Color(0xFF242631),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Create, continue or review official SOAP summaries.',
                                  style: TextStyle(
                                    color: Color(0xFF777C8D),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _openNewSummary,
                            icon: const Icon(Icons.post_add_rounded, size: 19),
                            label: const Text('New Summary'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Growkids.purpleFlo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      Expanded(
                        child: _summaryReports.isEmpty
                            ? _desktopEmptyState()
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns =
                                      constraints.maxWidth >= 1100 ? 3 : 2;
                                  return GridView.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      mainAxisExtent: 210,
                                    ),
                                    itemCount: _summaryReports.length,
                                    itemBuilder: (context, index) =>
                                        _desktopSummaryCard(
                                      Map<String, dynamic>.from(
                                        _summaryReports[index],
                                      ),
                                    ),
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

  Widget _desktopHero(int drafts, int finals, int sessions) {
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
              Icons.summarize_rounded,
              color: Growkids.purpleFlo,
              size: 37,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOAP DOCUMENTATION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Summary Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Prepare official progress summaries for students and parents.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _desktopMetric(
            Icons.edit_document,
            drafts,
            'Drafts',
            const Color(0xFFFFD68A),
          ),
          const SizedBox(width: 11),
          _desktopMetric(
            Icons.check_circle_rounded,
            finals,
            'Final',
            const Color(0xFF8EE7BC),
          ),
          const SizedBox(width: 11),
          _desktopMetric(
            Icons.event_note_outlined,
            sessions,
            'Sessions',
            const Color(0xFFBFD5FF),
          ),
        ],
      ),
    );
  }

  Widget _desktopMetric(
    IconData icon,
    int count,
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
                count.toString(),
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

  Widget _desktopSummaryCard(Map<String, dynamic> report) {
    final name = (report['stud_name'] ?? 'Unknown Student').toString();
    final sessions = (report['sessions_attended'] ?? 0).toString();
    final status = (report['status'] ?? 'Draft').toString();
    final isFinal = status.toLowerCase() == 'final';
    final color = isFinal ? const Color(0xFF15945D) : const Color(0xFFC47708);
    final parsedDate =
        DateTime.tryParse(report['date_of_report']?.toString() ?? '');
    final date = parsedDate == null
        ? 'Unknown date'
        : DateFormat('d MMM yyyy').format(parsedDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSummary(report),
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
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isFinal
                          ? Icons.check_circle_outline_rounded
                          : Icons.edit_document,
                      color: color,
                      size: 25,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF292B35),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Generated $date',
                style: const TextStyle(
                  color: Color(0xFF858A98),
                  fontSize: 9,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note_outlined,
                      color: Color(0xFF6C7280),
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$sessions sessions',
                      style: const TextStyle(
                        color: Color(0xFF555966),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isFinal ? 'View report' : 'Continue draft',
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: color,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSummary(Map<String, dynamic> report) {
    final isFinal =
        (report['status'] ?? '').toString().toLowerCase() == 'final';
    if (isFinal) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SoapSummaryViewPage(
            therapistId: widget.therapistId,
            reportId: report['id'].toString(),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SoapSummaryFormPage(
            therapistId: widget.therapistId,
            existingReportId: report['id'].toString(),
          ),
        ),
      ).then((_) => _fetchSummaryReports());
    }
  }

  void _openNewSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoapSummaryFormPage(therapistId: widget.therapistId),
      ),
    ).then((_) => _fetchSummaryReports());
  }

  Widget _desktopEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open_rounded,
            color: Color(0xFF9A9EAA),
            size: 44,
          ),
          const SizedBox(height: 12),
          const Text(
            'No summary reports',
            style: TextStyle(
              color: Color(0xFF444752),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          ElevatedButton.icon(
            onPressed: _openNewSummary,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create summary'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
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
          Container(
            padding: EdgeInsets.all(3.h),
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_rounded,
                size: 10.h, color: Growkids.purpleFlo.withValues(alpha: 0.5)),
          ),
          SizedBox(height: 3.h),
          Text(
            "No Summary Reports",
            style: TextStyle(fontSize: 16.sp, color: Colors.black87),
          ),
          SizedBox(height: 1.h),
          Text(
            "You haven't generated any official\nsummary reports for parents yet.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.sp, color: Colors.grey[500], height: 1.5),
          ),
        ],
      ),
    );
  }
}
