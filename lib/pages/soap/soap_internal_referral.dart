import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

import 'soap_internal_referral_form_page.dart';

bool _useDesktopInternalReferralLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

// Import the form page here once we build it
// import 'internal_referral_form_page.dart';

class InternalReferralPage extends StatefulWidget {
  final String therapistId;

  const InternalReferralPage({super.key, required this.therapistId});

  @override
  State<InternalReferralPage> createState() => _InternalReferralPageState();
}

class _InternalReferralPageState extends State<InternalReferralPage> {
  bool _isLoading = true;
  List<dynamic> _referrals = [];

  final String _apiUrl = ApiConfig.flutter('soap_get_referrals.php');
  /*final String _apiUrl =
      "http://app-kizzu.test/growkids/flutter/soap_get_referrals.php";*/

  @override
  void initState() {
    super.initState();
    _fetchReferrals();
  }

  Future<void> _fetchReferrals() async {
    try {
      final res = await http.post(
        Uri.parse(_apiUrl),
        body: {'therapist_id': widget.therapistId},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          // Check if the widget is still on screen before updating
          if (mounted) {
            setState(() {
              // Ensure we accept the data, or an empty list if data is null
              _referrals = json['data'] ?? [];
            });
          }
        }
      } else {
        print("Server error: ${res.statusCode}");
      }
    } catch (e) {
      // This catches JSON parsing errors or network failures
      print("Error fetching referrals: $e");
    } finally {
      // The 'finally' block ALWAYS runs.
      // This guarantees the loading spinner will stop and show the empty state if there's no data.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopInternalReferralLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Internal Referrals',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // The Floating Button to Create a New Referral
      floatingActionButton: FloatingActionButton.extended(
        extendedPadding: EdgeInsets.all(2.h),
        onPressed: () {
          // TODO: Navigate to the Referral Form Page
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening Referral Form...')),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InternalReferralFormPage(therapistId: id),
            ),
          ).then((_) => _fetchReferrals()); // Refresh list when returning
        },
        backgroundColor: Growkids.purpleFlo,
        icon: const Icon(Icons.add_reaction_rounded, color: Colors.white),
        label: Text(
          "New Referral",
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : _referrals.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Growkids.purpleFlo,
                  onRefresh: _fetchReferrals,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                        top: 2.h,
                        left: 2.h,
                        right: 2.h,
                        bottom: 10.h), // Extra bottom padding for FAB
                    itemCount: _referrals.length,
                    itemBuilder: (context, index) {
                      return _buildReferralCard(_referrals[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> referral) {
    String studName = referral['stud_name'] ?? 'Unknown Student';
    String type = referral['transfer_type'] ?? 'General Transfer';
    String target = referral['transfer_to'] ?? 'Unknown Target';
    String status = referral['status'] ?? 'Pending';

    // Format the date safely
    String dateStr = "Unknown Date";
    if (referral['date_requested'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(referral['date_requested']);
        dateStr = DateFormat('dd MMM yyyy').format(parsedDate);
      } catch (e) {
        // Fallback if date is not parsable
      }
    }

    // Determine Status Badge Colors
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;

    if (status.toLowerCase() == 'approved') {
      statusBgColor = Colors.green.withValues(alpha: 0.15);
      statusTextColor = Colors.green[800]!;
      statusIcon = Icons.check_circle_rounded;
    } else if (status.toLowerCase() == 'rejected') {
      statusBgColor = Colors.red.withValues(alpha: 0.15);
      statusTextColor = Colors.red[800]!;
      statusIcon = Icons.cancel_rounded;
    } else {
      // Default to Pending
      statusBgColor = Colors.orange.withValues(alpha: 0.15);
      statusTextColor = Colors.orange[800]!;
      statusIcon = Icons.hourglass_top_rounded;
    }

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
      child: Padding(
        padding: EdgeInsets.all(2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.6.h),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusTextColor, size: 1.8.h),
                      SizedBox(width: 1.5.w),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: statusTextColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.5.h),
            Divider(color: Colors.grey[100], height: 1),
            SizedBox(height: 1.5.h),

            // Student Info
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(1.2.h),
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded,
                      color: Growkids.purpleFlo, size: 2.5.h),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    studName,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.5.h),

            // Transfer Details Box
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(1.5.h),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Request Type: $type",
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    "Target: $target",
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final pending = _referrals
        .where((item) =>
            (item['status'] ?? 'pending').toString().toLowerCase() == 'pending')
        .length;
    final approved = _referrals
        .where((item) =>
            (item['status'] ?? '').toString().toLowerCase() == 'approved')
        .length;
    final rejected = _referrals
        .where((item) =>
            (item['status'] ?? '').toString().toLowerCase() == 'rejected')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text(
          'Internal Referrals',
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
            onPressed: _isLoading ? null : _fetchReferrals,
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
                      _desktopHero(pending, approved, rejected),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Referral requests',
                                  style: TextStyle(
                                    color: Color(0xFF242631),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Track internal student transfers and their status.',
                                  style: TextStyle(
                                    color: Color(0xFF777C8D),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _openNewReferral,
                            icon: const Icon(
                              Icons.add_reaction_rounded,
                              size: 19,
                            ),
                            label: const Text('New Referral'),
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
                        child: _referrals.isEmpty
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
                                      mainAxisExtent: 230,
                                    ),
                                    itemCount: _referrals.length,
                                    itemBuilder: (context, index) =>
                                        _desktopReferralCard(
                                      Map<String, dynamic>.from(
                                        _referrals[index],
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

  Widget _desktopHero(int pending, int approved, int rejected) {
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
              Icons.sync_alt_rounded,
              color: Color(0xFF0AAE7A),
              size: 37,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STUDENT CARE COORDINATION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Internal Referrals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Coordinate transfers and referrals between programmes.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _desktopMetric(
            Icons.hourglass_top_rounded,
            pending,
            'Pending',
            const Color(0xFFFFD68A),
          ),
          const SizedBox(width: 11),
          _desktopMetric(
            Icons.check_circle_rounded,
            approved,
            'Approved',
            const Color(0xFF8EE7BC),
          ),
          const SizedBox(width: 11),
          _desktopMetric(
            Icons.cancel_rounded,
            rejected,
            'Rejected',
            const Color(0xFFFFA7AF),
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
      width: 116,
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

  Widget _desktopReferralCard(Map<String, dynamic> referral) {
    final name = (referral['stud_name'] ?? 'Unknown Student').toString();
    final type = (referral['transfer_type'] ?? 'General Transfer').toString();
    final target = (referral['transfer_to'] ?? 'Unknown Target').toString();
    final status = (referral['status'] ?? 'Pending').toString();
    final statusLower = status.toLowerCase();
    final color = statusLower == 'approved'
        ? const Color(0xFF15945D)
        : statusLower == 'rejected'
            ? const Color(0xFFCF3948)
            : const Color(0xFFC47708);
    final icon = statusLower == 'approved'
        ? Icons.check_circle_rounded
        : statusLower == 'rejected'
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded;
    final parsedDate =
        DateTime.tryParse(referral['date_requested']?.toString() ?? '');
    final date = parsedDate == null
        ? 'Unknown date'
        : DateFormat('d MMM yyyy').format(parsedDate);

    return Container(
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
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF30323C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE5E7EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REQUEST TYPE',
                  style: TextStyle(
                    color: Color(0xFF9296A2),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF555966),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'TRANSFER TO',
                  style: TextStyle(
                    color: Color(0xFF9296A2),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF343640),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF9296A2),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                date,
                style: const TextStyle(
                  color: Color(0xFF858A98),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openNewReferral() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternalReferralFormPage(therapistId: id),
      ),
    ).then((_) => _fetchReferrals());
  }

  Widget _desktopEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sync_alt_rounded,
            color: Color(0xFF9A9EAA),
            size: 44,
          ),
          const SizedBox(height: 12),
          const Text(
            'No referrals yet',
            style: TextStyle(
              color: Color(0xFF444752),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          ElevatedButton.icon(
            onPressed: _openNewReferral,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create referral'),
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
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sync_alt_rounded,
                size: 10.h, color: Colors.blue[300]),
          ),
          SizedBox(height: 3.h),
          Text(
            "No Referrals Yet",
            style: TextStyle(fontSize: 16.sp, color: Colors.black87),
          ),
          SizedBox(height: 1.h),
          Text(
            "You haven't made any internal\nstudent transfers recently.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.sp, color: Colors.grey[500], height: 1.5),
          ),
        ],
      ),
    );
  }
}
