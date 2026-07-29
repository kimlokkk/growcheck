import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart'; // Ensure this matches
import 'sspsc_result.dart'; // Ensure this matches your file name

bool _useDesktopSspscHistoryLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class SSPSCHistory extends StatefulWidget {
  final String teacherId;

  const SSPSCHistory({
    super.key,
    required this.teacherId,
  });

  @override
  State<SSPSCHistory> createState() => _SSPSCHistoryState();
}

class _SSPSCHistoryState extends State<SSPSCHistory> {
  bool isLoading = true;
  List<dynamic> historyList = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    // Ensure this URL is correct
    final url = Uri.parse(ApiConfig.flutter('sp2_get_history.php'));
    /*final url =
        Uri.parse('http://app-kizzu.test/growkids/flutter/sp2_get_history.php');*/

    try {
      final response =
          await http.post(url, body: {'teacher_id': widget.teacherId});

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          setState(() {
            historyList = jsonResponse['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            historyList = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSspscHistoryLayout(context)) return _buildDesktopPage();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title:
            const Text("SSPSC History", style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : historyList.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: EdgeInsets.all(2.w),
                  itemCount: historyList.length,
                  separatorBuilder: (context, index) => SizedBox(height: 1.5.h),
                  itemBuilder: (context, index) {
                    return _buildHistoryCard(historyList[index]);
                  },
                ),
    );
  }

  Widget _buildDesktopPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'SSPSC History',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _fetchHistory,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1420),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 23),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Growkids.purpleFlo,
                        Growkids.purpleFlo.withValues(alpha: .76),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(21),
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
                          Icons.history_edu_rounded,
                          color: Growkids.purpleFlo,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COMPLETED ASSESSMENTS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'SSPSC Assessment History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Review completed sensory profiles and assessment results.',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '${historyList.length} assessments',
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
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0xFFE4E7EE)),
                    ),
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Growkids.purpleFlo,
                            ),
                          )
                        : historyList.isEmpty
                            ? _buildDesktopEmptyState()
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 112,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: historyList.length,
                                itemBuilder: (_, index) =>
                                    _buildDesktopHistoryCard(
                                  historyList[index],
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHistoryCard(dynamic data) {
    final name = data['student_name'] ?? 'Unknown';
    final date = data['formatted_date'] ?? '-';
    final assessmentId = data['assessment_id'].toString();
    final dateParts = date.toString().split(' ');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SSPSCResult(
            assessmentId: assessmentId,
            studentName: name,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E5EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Growkids.purpleFlo.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateParts.isEmpty ? '-' : dateParts.first,
                    style: const TextStyle(
                      color: Growkids.purpleFlo,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    dateParts.length > 1 ? dateParts[1] : '',
                    style:
                        const TextStyle(color: Color(0xFF878B97), fontSize: 9),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF30323C),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(
                        color: Color(0xFF15945D),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9A9EAA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 58,
            color: Color(0xFFB0B4C0),
          ),
          SizedBox(height: 14),
          Text(
            'No SSPSC assessments found',
            style: TextStyle(
              color: Color(0xFF4B4E59),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Completed assessments will appear here.',
            style: TextStyle(color: Color(0xFF9397A3), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(dynamic data) {
    String name = data['student_name'] ?? "Unknown";
    String date = data['formatted_date'] ?? "-";
    String id = data['assessment_id'].toString();
    // You can use total_items to show progress if you like, e.g., "44/44 Items"

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SSPSCResult(
              assessmentId: id,
              studentName: name,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Calendar Icon Box
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Growkids.purpleFlo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    date.split(' ')[0], // Day
                    style:
                        TextStyle(fontSize: 16.sp, color: Growkids.purpleFlo),
                  ),
                  Text(
                    date.split(' ')[1], // Month
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(width: 4.w),

            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.5.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text("Completed",
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.green,
                        )),
                  ),
                ],
              ),
            ),

            SizedBox(width: 2.w),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.grey[500], size: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu, size: 8.h, color: Colors.grey[300]),
          SizedBox(height: 2.h),
          Text("No History Found",
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              )),
          SizedBox(height: 1.h),
          Text("Assessments you submit will appear here.",
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
