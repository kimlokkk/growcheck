import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/soap/soap_active_student_page.dart';
import 'package:growcheck_app_v2/pages/soap/soap_discharge_student_page.dart';
import 'package:growcheck_app_v2/pages/soap/soap_internal_referral.dart';
import 'package:growcheck_app_v2/pages/soap/soap_report_view.dart';
import 'package:growcheck_app_v2/pages/soap/soap_summary_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'soap_form.dart';

bool _useDesktopSoapDashboardLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class SOAPHubPage extends StatefulWidget {
  final String therapistId;

  const SOAPHubPage({
    super.key,
    required this.therapistId,
  });

  @override
  State<SOAPHubPage> createState() => _SOAPHubPageState();
}

class _SOAPHubPageState extends State<SOAPHubPage> {
  bool _isLoading = true;

  Map<String, dynamic> _stats = {'count_draft': 0, 'count_final': 0};
  Map<String, dynamic>? _latestDraft;
  List<dynamic> _recentHistory = [];

  // API URL
  final String _apiUrl = ApiConfig.flutter('soap_get_hub_data.php');
  /*final String _apiUrl =
      "http://app-kizzu.test/growkids/flutter/soap_get_hub_data.php";*/

  @override
  void initState() {
    super.initState();
    _fetchHubData();
  }

  Future<void> _fetchHubData() async {
    try {
      final res = await http
          .post(Uri.parse(_apiUrl), body: {'therapist_id': widget.therapistId});

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          setState(() {
            _stats = json['stats'] ?? {'count_draft': 0, 'count_final': 0};
            _latestDraft = json['latest_draft'];
            _recentHistory = json['recent_history'] ?? [];
            _isLoading = false;
          });
        }
        print(json);
        print(widget.therapistId);
      }
    } catch (e) {
      print("Error fetching hub data: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSoapDashboardLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title:
            const Text('SOAP Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : RefreshIndicator(
              onRefresh: _fetchHubData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. WELCOME & STATS
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                "Pending Drafts",
                                _stats['count_draft'].toString(),
                                Colors.orange,
                                Icons.edit_note)),
                        SizedBox(width: 2.w),
                        Expanded(
                            child: _statCard(
                                "Completed",
                                _stats['count_final'].toString(),
                                Colors.green,
                                Icons.check_circle_outline)),
                      ],
                    ),
                    SizedBox(height: 3.h),

                    // 2. RESUME DRAFT
                    if (_latestDraft != null) ...[
                      _sectionHeader("Continue Working"),
                      InkWell(
                        onTap: () {
                          // Buka draft yang sedia ada
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SOAPFormPage(
                                therapistId: widget.therapistId,
                                studId: _latestDraft!['stud_id'].toString(),
                                studentName:
                                    _latestDraft!['stud_name'] ?? 'Unknown',
                                existingReportId: _latestDraft!['id']
                                    .toString(), // Hantar ID Draft
                              ),
                            ),
                          ).then((_) =>
                              _fetchHubData()); // Refresh bila patah balik
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(2.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade50, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(1.2.h),
                                decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    shape: BoxShape.circle),
                                child: Icon(Icons.history_edu,
                                    color: Colors.orange[800], size: 20.sp),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        _latestDraft!['stud_name'] ?? 'Unknown',
                                        style: TextStyle(
                                            fontSize: 14.sp,
                                            color: Colors.black87)),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                        "Session Date: ${_latestDraft!['session_date']}",
                                        style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey[700])),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      "Tap to finish report",
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.orange[300], size: 14.sp),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 3.h),
                    ],

                    // 3. MAIN ACTIONS (SLEEKER GRID)
                    _sectionHeader("Quick Actions"),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 3.w,
                      mainAxisSpacing: 3.w,
                      childAspectRatio:
                          3, // Changed from 1.05 to make them shorter rectangles
                      children: [
                        _gridButton("Active Student", Icons.groups_rounded,
                            Colors.blue[600]!, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActiveStudentsPage(
                                  therapistId: widget.therapistId),
                            ),
                          );
                        }),
                        _gridButton("Discharged Student",
                            Icons.person_off_rounded, Colors.red[400]!, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DischargeStudentPage(
                                  therapistId: widget.therapistId),
                            ),
                          );
                        }),
                        _gridButton("Internal Referral", Icons.sync_alt_rounded,
                            Colors.teal[500]!, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InternalReferralPage(
                                  therapistId: widget.therapistId),
                            ),
                          );
                        }),
                        _gridButton("SOAP Report", Icons.note_add_rounded,
                            Growkids.purpleFlo, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SoapSummaryPage(
                                  therapistId: widget.therapistId),
                            ),
                          );
                        }),
                      ],
                    ),
                    SizedBox(height: 3.h),

                    // 4. RECENT HISTORY
                    _sectionHeader("Recent Reports"),
                    if (_recentHistory.isEmpty)
                      Container(
                        padding: EdgeInsets.all(3.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Text("No completed reports yet.",
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentHistory.length,
                        itemBuilder: (ctx, i) {
                          final item = _recentHistory[i];
                          return _historyTile(item);
                        },
                      ),
                    SizedBox(height: 5.h),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGETS ---
  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child:
          Text(title, style: TextStyle(fontSize: 14.sp, color: Colors.black87)),
    );
  }

  Widget _statCard(String label, String count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(1.h),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 3.h),
              ),
              Text(count,
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(label,
              style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDesktopPage() {
    final draftCount = int.tryParse(_stats['count_draft'].toString()) ?? 0;
    final finalCount = int.tryParse(_stats['count_final'].toString()) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text(
          'SOAP Dashboard',
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
            onPressed: _isLoading ? null : _fetchHubData,
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
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                  child: Column(
                    children: [
                      _desktopHero(draftCount, finalCount),
                      const SizedBox(height: 22),
                      _desktopQuickActions(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 390,
                              child: _desktopDraftPanel(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: _desktopRecentPanel()),
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

  Widget _desktopHero(int draftCount, int finalCount) {
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
              Icons.description_rounded,
              color: Growkids.purpleFlo,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLINICAL DOCUMENTATION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'SOAP Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage session notes, referrals and student progress.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _desktopHeroMetric(
            Icons.edit_note_rounded,
            draftCount.toString(),
            'Pending drafts',
            const Color(0xFFFFD68A),
          ),
          const SizedBox(width: 12),
          _desktopHeroMetric(
            Icons.check_circle_outline_rounded,
            finalCount.toString(),
            'Completed',
            const Color(0xFF8EE7BC),
          ),
          const SizedBox(width: 12),
          _desktopHeroMetric(
            Icons.history_rounded,
            _recentHistory.length.toString(),
            'Recent reports',
            const Color(0xFFBFD5FF),
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
      width: 145,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _desktopActionCard(
            'Active Students',
            'View students currently receiving therapy.',
            Icons.groups_rounded,
            const Color(0xFF3478F6),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ActiveStudentsPage(therapistId: widget.therapistId),
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: _desktopActionCard(
            'Discharged Students',
            'Review completed and discharged cases.',
            Icons.person_off_rounded,
            const Color(0xFFE65A68),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DischargeStudentPage(therapistId: widget.therapistId),
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: _desktopActionCard(
            'Internal Referral',
            'Manage student referrals between services.',
            Icons.sync_alt_rounded,
            const Color(0xFF0AAE7A),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    InternalReferralPage(therapistId: widget.therapistId),
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: _desktopActionCard(
            'SOAP Reports',
            'Open report summaries and documentation.',
            Icons.note_add_rounded,
            Growkids.purpleFlo,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SoapSummaryPage(therapistId: widget.therapistId),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E5EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF30323C),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF858A98),
                        fontSize: 9,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopDraftPanel() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue working',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Resume your latest pending SOAP report.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 11),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _latestDraft == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          color: Color(0xFF72B893),
                          size: 39,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No pending draft',
                          style: TextStyle(
                            color: Color(0xFF4F5460),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All caught up.',
                          style:
                              TextStyle(color: Color(0xFF9296A2), fontSize: 9),
                        ),
                      ],
                    ),
                  )
                : _desktopDraftCard(_latestDraft!),
          ),
        ],
      ),
    );
  }

  Widget _desktopDraftCard(Map<String, dynamic> draft) {
    final studentName = (draft['stud_name'] ?? 'Unknown').toString();
    final sessionDate = (draft['session_date'] ?? '—').toString();
    return InkWell(
      onTap: () => _openDraft(draft),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF6E6), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFF2D59F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7BB),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFFC47708),
                size: 26,
              ),
            ),
            const Spacer(),
            const Text(
              'LATEST DRAFT',
              style: TextStyle(
                color: Color(0xFFC47708),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              studentName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF343640),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Session date: $sessionDate',
              style: const TextStyle(
                color: Color(0xFF747987),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text(
                  'Resume report',
                  style: TextStyle(
                    color: Color(0xFFC47708),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC47708),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopRecentPanel() {
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
                        'Recent reports',
                        style: TextStyle(
                          color: Color(0xFF242631),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Recently completed SOAP session reports.',
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
                    '${_recentHistory.length} reports',
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
          Container(
            color: const Color(0xFFF8F9FC),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'STUDENT',
                    style: TextStyle(
                      color: Color(0xFF858A98),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'SESSION DATE',
                    style: TextStyle(
                      color: Color(0xFF858A98),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 70),
              ],
            ),
          ),
          Expanded(
            child: _recentHistory.isEmpty
                ? const Center(
                    child: Text(
                      'No completed reports yet.',
                      style: TextStyle(color: Color(0xFF858A98), fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    itemCount: _recentHistory.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF0F4)),
                    itemBuilder: (context, index) =>
                        _desktopHistoryRow(_recentHistory[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHistoryRow(Map<String, dynamic> item) {
    final studentName = (item['stud_name'] ?? 'Unknown').toString();
    final rawDate = (item['session_date'] ?? '').toString();
    final parsedDate = DateTime.tryParse(rawDate);
    final dateLabel = parsedDate == null
        ? rawDate
        : DateFormat('d MMM yyyy').format(parsedDate);

    return InkWell(
      onTap: () => _openReport(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF3478F6),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF343640),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Report #${item['id']}',
                    style: const TextStyle(
                      color: Color(0xFF9296A2),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                dateLabel,
                style: const TextStyle(
                  color: Color(0xFF666B78),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(
              width: 70,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9A9EAA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDraft(Map<String, dynamic> draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SOAPFormPage(
          therapistId: widget.therapistId,
          studId: draft['stud_id'].toString(),
          studentName: draft['stud_name'] ?? 'Unknown',
          existingReportId: draft['id'].toString(),
        ),
      ),
    ).then((_) => _fetchHubData());
  }

  void _openReport(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoapReportViewPage(
          therapistId: widget.therapistId,
          reportId: item['id'],
        ),
      ),
    );
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

  // NEW: Grid Tile Widget
  // NEW: Sleeker, easier-on-the-eyes Grid Tile Widget
  Widget _gridButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: Colors.white, // Soft white background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withValues(alpha: 0.2)), // Subtle colored border
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            // Colored Icon Box
            Container(
              padding: EdgeInsets.all(1.2.h),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 3.h),
            ),
            SizedBox(width: 2.5.w),
            // Text Column
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> item) {
    String name = item['stud_name'] ?? 'Unknown';
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding:
              EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.5.h),
          leading: CircleAvatar(
            backgroundColor: Colors.blue[50],
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.blue[800],
              ),
            ),
          ),
          title: Text(name, style: TextStyle(fontSize: 14.sp)),
          subtitle: Text(
              "Session: ${DateFormat.yMMMd().format(DateTime.parse(item['session_date']))}",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.grey[600],
            size: 3.h,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SoapReportViewPage(
                  therapistId: widget.therapistId,
                  reportId: item['id'],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET DIALOG PILIH PELAJAR (STUDENT SELECTION DIALOG)
// ============================================================================

class StudentSelectionDialog extends StatefulWidget {
  final String therapistId;
  final String desktopTitle;
  final String desktopSubtitle;
  final IconData desktopIcon;

  const StudentSelectionDialog({
    super.key,
    required this.therapistId,
    this.desktopTitle = 'Quick Peek',
    this.desktopSubtitle =
        'Select a student to view their previous SOAP report.',
    this.desktopIcon = Icons.manage_search_rounded,
  });

  @override
  State<StudentSelectionDialog> createState() => _StudentSelectionDialogState();
}

class _StudentSelectionDialogState extends State<StudentSelectionDialog> {
  bool _isLoading = true;
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  final TextEditingController _searchCtrl = TextEditingController();

  final String _childrenApiUrl = ApiConfig.flutter('soap_get_student.php');
  /*final String _childrenApiUrl =
      "http://app-kizzu.test/growkids/flutter/soap_get_student.php";*/

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      final res = await http.post(Uri.parse(_childrenApiUrl), body: {
        'therapist_id': widget.therapistId,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Handle format JSON berbeza (sama ada List terus, atau objek 'data')
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('data')) {
          list = data['data'];
        } else if (data is Map && data.containsKey('children')) {
          list = data['children'];
        }

        setState(() {
          _allStudents = list;
          _filteredStudents = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching students: $e");
      setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    if (query.isEmpty) {
      setState(() => _filteredStudents = _allStudents);
      return;
    }
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        // Semak fallback key
        String name = (student['stud_name'] ??
                student['student_name'] ??
                student['name'] ??
                '')
            .toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSoapDashboardLayout(context)) {
      return _buildDesktopDialog();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 60.h, // Ketinggian tetap supaya paparan konsisten
        padding: EdgeInsets.all(2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header Dialog
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Select Student",
                    style:
                        TextStyle(fontSize: 14.sp, color: Growkids.purpleFlo)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              onChanged: _filterSearch,
              decoration: InputDecoration(
                hintText: "Search name...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // List Student
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Growkids.purpleFlo))
                  : _filteredStudents.isEmpty
                      ? const Center(child: Text("No student found."))
                      : ListView.builder(
                          itemCount: _filteredStudents.length,
                          itemBuilder: (ctx, i) {
                            final student = _filteredStudents[i];
                            String name = student['stud_name'] ??
                                student['student_name'] ??
                                student['name'] ??
                                'Unknown';

                            return Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Growkids.purpleFlo.withValues(alpha: 0.1),
                                  child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Growkids.purpleFlo,
                                          fontWeight: FontWeight.bold)),
                                ),
                                title: Text(name,
                                    style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.chevron_right,
                                    color: Colors.grey),
                                onTap: () {
                                  // Return data student yang dipilih ke fungsi pemanggil
                                  Navigator.pop(context, student);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Growkids.purpleFlo,
                      Growkids.purpleFlo.withValues(alpha: 0.78),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        widget.desktopIcon,
                        color: Growkids.purpleFlo,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.desktopTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.desktopSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filterSearch,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search student name...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: Colors.white,
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
                        borderSide: const BorderSide(
                          color: Growkids.purpleFlo,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Growkids.purpleFlo,
                        ),
                      )
                    : _filteredStudents.isEmpty
                        ? const Center(
                            child: Text(
                              'No student found.',
                              style: TextStyle(color: Color(0xFF858A98)),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 88,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              final name = (student['stud_name'] ??
                                      student['student_name'] ??
                                      student['name'] ??
                                      'Unknown')
                                  .toString();
                              final id =
                                  (student['stud_id'] ?? student['id'] ?? '—')
                                      .toString();

                              return InkWell(
                                onTap: () => Navigator.pop(context, student),
                                borderRadius: BorderRadius.circular(13),
                                child: Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: const Color(0xFFE3E5EC),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 43,
                                        height: 43,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Growkids.purpleFlo
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                        ),
                                        child: Text(
                                          name.isEmpty
                                              ? '?'
                                              : name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Growkids.purpleFlo,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF343640),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Student ID $id',
                                              style: const TextStyle(
                                                color: Color(0xFF9296A2),
                                                fontSize: 9,
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
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
