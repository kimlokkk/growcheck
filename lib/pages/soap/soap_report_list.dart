import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'soap_report_view.dart';

bool _useDesktopSoapHistoryLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class SoapReportItem {
  final String id;
  final String studId;
  final String studName;
  final String status;
  final String sessionDate;
  final String sessionTime;
  final String sessionNum;
  final String updatedAt;

  SoapReportItem({
    required this.id,
    required this.studId,
    required this.studName,
    required this.status,
    required this.sessionDate,
    required this.sessionTime,
    required this.sessionNum,
    required this.updatedAt,
  });

  factory SoapReportItem.fromJson(Map<String, dynamic> j) => SoapReportItem(
        id: j['id'].toString(),
        studId: j['stud_id'].toString(),
        studName: (j['stud_name'] ?? 'Unknown').toString(),
        status: (j['status'] ?? 'final').toString(),
        sessionDate: (j['session_date'] ?? '').toString(),
        sessionTime: (j['session_time'] ?? '').toString(),
        sessionNum: (j['session_num'] ?? '').toString(),
        updatedAt: (j['updated_at'] ?? '').toString(),
      );
}

class SoapReportListPage extends StatefulWidget {
  final String therapistId;
  final String? studId; // optional: kalau nak list by student
  final String title;

  const SoapReportListPage({
    super.key,
    required this.therapistId,
    this.studId,
    this.title = "SOAP Reports",
  });

  @override
  State<SoapReportListPage> createState() => _SoapReportListPageState();
}

class _SoapReportListPageState extends State<SoapReportListPage> {
  static final String _listApi = ApiConfig.flutter('soap_list_reports.php');
  /*static const String _listApi =
      "http://app-kizzu.test/growkids/flutter/soap_list_reports.php";*/

  final TextEditingController _searchCtrl = TextEditingController();
  String _status = "final"; // final|draft|all
  bool _loading = true;
  String _error = "";
  List<SoapReportItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(() {
      // debounce simple
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _fetch();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final body = {
        "therapist_id": widget.therapistId,
        "status": _status,
        "q": _searchCtrl.text.trim(),
        "limit": "50",
        "offset": "0",
      };

      if (widget.studId != null && widget.studId!.isNotEmpty) {
        body["stud_id"] = widget.studId!;
      }

      final res = await http.post(Uri.parse(_listApi), body: body);

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = "Server error (${res.statusCode})";
        });
        return;
      }

      final jsonRes = jsonDecode(res.body);
      if (jsonRes["status"] != "success") {
        setState(() {
          _loading = false;
          _error = (jsonRes["message"] ?? "Failed to load").toString();
        });
        return;
      }

      final list = (jsonRes["data"] as List).cast<dynamic>();
      final items = list
          .map((e) =>
              SoapReportItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Connection error";
      });
    }
  }

  String _niceDate(String yyyyMmDd) {
    try {
      final dt = DateTime.parse(yyyyMmDd);
      return DateFormat("dd MMM yyyy").format(dt);
    } catch (_) {
      return yyyyMmDd;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSoapHistoryLayout(context)) {
      return _buildDesktop();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            style: TextStyle(fontSize: 13.sp, color: Colors.white)),
      ),
      body: Column(
        children: [
          _topPanel(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Growkids.purpleFlo))
                : _error.isNotEmpty
                    ? Center(
                        child: Text(_error,
                            style: TextStyle(color: Colors.grey[600])))
                    : _items.isEmpty
                        ? Center(
                            child: Text("No reports found.",
                                style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(2.h, 1.h, 2.h, 2.h),
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              return _reportCard(item);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _desktopHeader(),
                const SizedBox(height: 20),
                _desktopToolbar(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Report history',
                        style: TextStyle(
                          color: Color(0xFF242735),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!_loading && _error.isEmpty)
                      Text(
                        '${_items.length} report${_items.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFF777C8B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _desktopContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    final finalCount = _items.where((item) => item.status != 'draft').length;
    final draftCount = _items.where((item) => item.status == 'draft').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x253F2A91),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Growkids.purple,
              size: 29,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOAP REPORTS',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Student SOAP History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Review completed reports and saved drafts.',
                  style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
          _desktopMetric('Visible', _items.length, Icons.list_alt_rounded),
          const SizedBox(width: 10),
          _desktopMetric('Final', finalCount, Icons.check_circle_outline),
          const SizedBox(width: 10),
          _desktopMetric('Draft', draftCount, Icons.edit_note_rounded),
        ],
      ),
    );
  }

  Widget _desktopMetric(String label, int count, IconData icon) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _desktopToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search student name or session...',
                hintStyle: const TextStyle(color: Color(0xFF9A9EAA)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF858A99),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F6F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _desktopFilter('Final', 'final'),
          const SizedBox(width: 8),
          _desktopFilter('Draft', 'draft'),
          const SizedBox(width: 8),
          _desktopFilter('All', 'all'),
        ],
      ),
    );
  }

  Widget _desktopFilter(String label, String value) {
    final selected = _status == value;
    return Material(
      color: selected
          ? Growkids.purple.withValues(alpha: 0.10)
          : const Color(0xFFF3F4F7),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () {
          setState(() => _status = value);
          _fetch();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? Growkids.purple.withValues(alpha: 0.24)
                  : const Color(0xFFE5E7ED),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Growkids.purple : const Color(0xFF656A78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopContent() {
    if (_loading) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(color: Growkids.purpleFlo),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return _desktopMessage(_error, Icons.error_outline_rounded, Colors.red);
    }
    if (_items.isEmpty) {
      return _desktopMessage(
        'No reports found.',
        Icons.description_outlined,
        const Color(0xFF9A9EAA),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _desktopReportCard(item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _desktopReportCard(SoapReportItem item) {
    final isDraft = item.status == 'draft';
    final color = isDraft ? const Color(0xFFF59E0B) : const Color(0xFF16A34A);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDesktopReport(item),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E5ED)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0E1635),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDraft
                      ? Icons.edit_note_rounded
                      : Icons.description_outlined,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.studName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF292C39),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _desktopStatus(isDraft ? 'Draft' : 'Final', color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _desktopMeta(
                          Icons.calendar_today_outlined,
                          _niceDate(item.sessionDate),
                        ),
                        _desktopMeta(
                          Icons.tag_rounded,
                          item.sessionNum.isEmpty
                              ? 'No session number'
                              : item.sessionNum,
                        ),
                        if (item.sessionTime.isNotEmpty)
                          _desktopMeta(
                            Icons.schedule_rounded,
                            item.sessionTime,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF858A99),
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopStatus(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _desktopMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF858A99)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF717685),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _desktopMessage(String message, IconData icon, Color color) {
    return Container(
      height: 260,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: color),
          const SizedBox(height: 13),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openDesktopReport(SoapReportItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoapReportViewPage(
          therapistId: widget.therapistId,
          reportId: item.id,
        ),
      ),
    );
  }

  Widget _topPanel() {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          TextField(
            style: TextStyle(
              fontSize: 12.sp,
            ),
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: "Search student name or session...",
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          SizedBox(height: 1.4.h),
          Row(
            children: [
              _chip("Final", "final"),
              SizedBox(width: 1.w),
              _chip("Draft", "draft"),
              SizedBox(width: 1.w),
              _chip("All", "all"),
              const Spacer(),
              IconButton(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, color: Growkids.purpleFlo),
                tooltip: "Refresh",
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _status == value;
    return InkWell(
      onTap: () {
        setState(() => _status = value);
        _fetch();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Growkids.purpleFlo.withValues(alpha: 0.12)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? Growkids.purpleFlo.withValues(alpha: 0.35)
                  : Colors.grey[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: selected ? Growkids.purpleFlo : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _reportCard(SoapReportItem item) {
    final isDraft = item.status == "draft";
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SoapReportViewPage(
              therapistId: widget.therapistId,
              reportId: item.id,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 1.4.h),
        padding: EdgeInsets.all(1.8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 5.h,
              height: 5.h,
              decoration: BoxDecoration(
                color: isDraft
                    ? Colors.orange.withValues(alpha: 0.12)
                    : Growkids.purpleFlo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                size: 3.h,
                isDraft ? Icons.edit_note_rounded : Icons.description_rounded,
                color: isDraft ? Colors.orange[800] : Growkids.purpleFlo,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.studName,
                          style:
                              TextStyle(fontSize: 14.sp, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.6.h),
                  Text(
                    "${_niceDate(item.sessionDate)} • ${item.sessionNum.isEmpty ? 'No session num' : item.sessionNum}",
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[600],
              size: 3.h,
            ),
          ],
        ),
      ),
    );
  }
}
