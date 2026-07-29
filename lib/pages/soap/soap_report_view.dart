// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'soap_form.dart';

bool _useDesktopSoapReportLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class SoapReportViewPage extends StatefulWidget {
  final String therapistId;
  final String reportId;

  const SoapReportViewPage({
    super.key,
    required this.therapistId,
    required this.reportId,
  });

  @override
  State<SoapReportViewPage> createState() => _SoapReportViewPageState();
}

class _SoapReportViewPageState extends State<SoapReportViewPage> {
  static final String _getApi = ApiConfig.flutter('soap_get_report.php');
  /*static const String _getApi = "http://app-kizzu.test/growkids/flutter/soap_get_report.php";*/

  bool _loading = true;
  String _error = "";
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String _niceDate(String yyyyMmDd) {
    try {
      final dt = DateTime.parse(yyyyMmDd);
      return DateFormat("dd MMM yyyy").format(dt);
    } catch (_) {
      return yyyyMmDd;
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final res = await http.post(
        Uri.parse(_getApi),
        body: {
          "report_id": widget.reportId,
          "therapist_id": widget.therapistId,
        },
      );

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

      final d = (jsonRes["data"] as Map).cast<String, dynamic>();
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Connection error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final status = (d?["status"] ?? "").toString();
    final isDraft = status == "draft";

    if (_useDesktopSoapReportLayout(context)) {
      return _buildDesktop(d, isDraft);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text("SOAP Report",
            style: TextStyle(fontSize: 13.sp, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : _error.isNotEmpty
              ? Center(
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : d == null
                  ? Center(
                      child: Text(
                        "No data.",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : Column(
                      children: [
                        _header(d),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(2.h, 1.5.h, 2.h, 2.h),
                            child: Column(
                              children: [
                                _sectionCard(
                                  title: "Subjective (S)",
                                  children: [
                                    _kv("Caregiver concern",
                                        d["s_caregiver_concern"]),
                                    _kv("Child appearance & mood",
                                        d["s_child_appearance"]),
                                    _kv("Lateness (minutes)", d["s_lateness"]),
                                  ],
                                ),
                                _sectionCard(
                                  title: "Objective (O)",
                                  children: [
                                    _objectiveView(d["o_data"]),
                                  ],
                                ),
                                _sectionCard(
                                  title: "Analysis (A)",
                                  children: [
                                    _kv("Overall analysis", d["a_analysis"]),
                                    _kv("STG", d["a_stg"]),
                                    _kv("LTG", d["a_ltg"]),
                                  ],
                                ),
                                _sectionCard(
                                  title: "Plan (P)",
                                  children: [
                                    _planView(d["p_data"]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isDraft) _bottomDraftBar(d),
                      ],
                    ),
    );
  }

  Widget _buildDesktop(Map<String, dynamic>? data, bool isDraft) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: const Text(
          'SOAP Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : _error.isNotEmpty
              ? _desktopMessage(_error, Icons.error_outline_rounded, Colors.red)
              : data == null
                  ? _desktopMessage(
                      'No data.',
                      Icons.description_outlined,
                      const Color(0xFF9A9EAA),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1380),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _desktopHeader(data, isDraft),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _desktopSection(
                                          title: 'Subjective',
                                          code: 'S',
                                          icon:
                                              Icons.chat_bubble_outline_rounded,
                                          color: const Color(0xFF3D7AF5),
                                          children: [
                                            _desktopKv(
                                              'Caregiver concern',
                                              data['s_caregiver_concern'],
                                            ),
                                            _desktopKv(
                                              'Child appearance & mood',
                                              data['s_child_appearance'],
                                            ),
                                            _desktopKv(
                                              'Lateness (minutes)',
                                              data['s_lateness'],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        _desktopSection(
                                          title: 'Objective',
                                          code: 'O',
                                          icon: Icons.fact_check_outlined,
                                          color: const Color(0xFF12A47A),
                                          children: [
                                            _desktopObjective(data['o_data']),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _desktopSection(
                                          title: 'Analysis',
                                          code: 'A',
                                          icon: Icons.analytics_outlined,
                                          color: const Color(0xFFF59E0B),
                                          children: [
                                            _desktopKv(
                                              'Overall analysis',
                                              data['a_analysis'],
                                            ),
                                            _desktopKv('STG', data['a_stg']),
                                            _desktopKv('LTG', data['a_ltg']),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        _desktopSection(
                                          title: 'Plan',
                                          code: 'P',
                                          icon: Icons.route_outlined,
                                          color: Growkids.purple,
                                          children: [
                                            _desktopPlan(data['p_data']),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isDraft) ...[
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    width: 230,
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Growkids.purpleFlo,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _continueDesktopDraft(data),
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'Continue Editing Draft',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _desktopHeader(Map<String, dynamic> data, bool isDraft) {
    final student = (data['stud_name'] ?? 'Unknown').toString();
    final initial = student.trim().isEmpty
        ? '?'
        : student.trim().substring(0, 1).toUpperCase();
    final date = (data['session_date'] ?? '').toString();
    final time = (data['session_time'] ?? '').toString();
    final session = (data['session_num'] ?? '').toString();
    final statusColor = isDraft ? const Color(0xFFFFC451) : Colors.white;

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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Growkids.purple,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOAP SESSION REPORT',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  student,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 15,
                  runSpacing: 7,
                  children: [
                    _desktopHeaderInfo(
                      Icons.calendar_today_outlined,
                      date.isEmpty ? '-' : _niceDate(date),
                    ),
                    _desktopHeaderInfo(
                      Icons.schedule_rounded,
                      time.isEmpty ? '-' : time,
                    ),
                    _desktopHeaderInfo(
                      Icons.tag_rounded,
                      session.isEmpty ? 'No session number' : session,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDraft ? 0.18 : 0.13),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: statusColor.withValues(alpha: isDraft ? 0.50 : 0.20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDraft
                      ? Icons.edit_note_rounded
                      : Icons.check_circle_outline,
                  color: statusColor,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  isDraft ? 'Draft' : 'Final report',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeaderInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xD9FFFFFF)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _desktopSection({
    required String title,
    required String code,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF242735),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Divider(height: 30, color: Color(0xFFEDEEF3)),
          ...children,
        ],
      ),
    );
  }

  Widget _desktopKv(String label, dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE7E9F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777C8B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF3F4350),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopObjective(dynamic raw) {
    if (raw is! Map || raw.isEmpty) return _desktopNoValue();
    final map = raw.cast<String, dynamic>();
    final categories = <Widget>[];

    for (final category in map.entries) {
      if (category.value is! Map) continue;
      final fields = (category.value as Map).cast<String, dynamic>();
      final nonEmpty = fields.entries
          .where((entry) => (entry.value ?? '').toString().trim().isNotEmpty)
          .toList();
      if (nonEmpty.isEmpty) continue;

      categories.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE7E9F0)),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 15),
            childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
            title: Text(
              category.key,
              style: const TextStyle(
                color: Color(0xFF3F4350),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              '${nonEmpty.length} recorded item${nonEmpty.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Color(0xFF858A99),
                fontSize: 11,
              ),
            ),
            children: nonEmpty
                .map((entry) => _desktopKv(entry.key, entry.value))
                .toList(),
          ),
        ),
      );
    }

    return categories.isEmpty
        ? _desktopNoValue()
        : Column(children: categories);
  }

  Widget _desktopPlan(dynamic raw) {
    if (raw is! Map) return _desktopNoValue();
    final map = raw.cast<String, dynamic>();
    final treatmentRaw = map['tx_given'];
    final treatments = treatmentRaw is List
        ? treatmentRaw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final custom = (map['tx_custom'] ?? '').toString().trim();
    final tca = (map['tca_plan'] ?? '').toString().trim();

    if (treatments.isEmpty && custom.isEmpty && tca.isEmpty) {
      return _desktopNoValue();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (treatments.isNotEmpty) ...[
          const Text(
            'Treatment given',
            style: TextStyle(
              color: Color(0xFF777C8B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          ...treatments.map(
            (treatment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: Growkids.purple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      treatment,
                      style: const TextStyle(
                        color: Color(0xFF3F4350),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (custom.isNotEmpty) _desktopKv('Other / Custom Treatment', custom),
        if (tca.isNotEmpty) _desktopKv('TCA plan', tca),
      ],
    );
  }

  Widget _desktopNoValue() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Text(
        'No information recorded.',
        style: TextStyle(color: Color(0xFF858A99), fontSize: 12),
      ),
    );
  }

  Widget _desktopMessage(String message, IconData icon, Color color) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E5ED)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continueDesktopDraft(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SOAPFormPage(
          therapistId: widget.therapistId,
          studId: (data['stud_id'] ?? '').toString(),
          studentName: (data['stud_name'] ?? 'Unknown').toString(),
          existingReportId: widget.reportId,
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> d) {
    final studName = (d["stud_name"] ?? "Unknown").toString();
    final studId = (d["stud_id"] ?? "").toString();
    final status = (d["status"] ?? "").toString();
    final isDraft = status == "draft";

    final date = (d["session_date"] ?? "").toString();
    final time = (d["session_time"] ?? "").toString();
    final sessionNum = (d["session_num"] ?? "").toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  studName,
                  style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniInfo(Icons.calendar_month_rounded,
                  date.isEmpty ? "-" : _niceDate(date)),
              _miniInfo(Icons.schedule_rounded, time.isEmpty ? "-" : time),
              _miniInfo(Icons.confirmation_number_rounded,
                  sessionNum.isEmpty ? "-" : sessionNum),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 2.h, color: Growkids.purpleFlo),
          SizedBox(width: 2.w),
          Text(text, style: TextStyle(fontSize: 12.sp, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 1.4.h),
      padding: EdgeInsets.all(1.8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 14.sp, color: Growkids.purpleFlo)),
          SizedBox(height: 1.2.h),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String label, dynamic value) {
    final v = (value ?? "").toString().trim();
    if (v.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 1.1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13.sp, color: Colors.black87)),
          SizedBox(height: 0.4.h),
          Text(v, style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _objectiveView(dynamic oData) {
    if (oData is! Map) {
      return Text("-",
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]));
    }

    final map = (oData).cast<String, dynamic>();
    if (map.isEmpty) {
      return Text("-",
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]));
    }

    return Column(
      children: map.entries.map((cat) {
        final fields = cat.value;
        if (fields is! Map) return const SizedBox.shrink();

        final fieldMap = (fields).cast<String, dynamic>();
        final nonEmpty = fieldMap.entries
            .where((e) => (e.value ?? "").toString().trim().isNotEmpty)
            .toList();
        if (nonEmpty.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.only(bottom: 1.h),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ExpansionTile(
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: Text(cat.key,
                style: TextStyle(fontSize: 12.sp, color: Colors.black87)),
            children: nonEmpty.map((e) => _kv(e.key, e.value)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _planView(dynamic pData) {
    if (pData is! Map) {
      return Text("-",
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]));
    }

    final map = (pData).cast<String, dynamic>();
    final tx = map["tx_given"];
    final tca = (map["tca_plan"] ?? "").toString();

    final txCustom = (map["tx_custom"] ?? "").toString();

    final txList = (tx is List)
        ? tx.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (txList.isNotEmpty) ...[
          Text("Treatment given",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
          SizedBox(height: 0.6.h),
          ...txList.map((t) => Padding(
                padding: EdgeInsets.only(bottom: 0.6.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 2.h, color: Growkids.purpleFlo),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12.sp, color: Colors.black87))),
                  ],
                ),
              )),
          SizedBox(height: 1.2.h),
          if (txCustom.isNotEmpty) ...[
            _kv("Other / Custom Treatment", txCustom),
          ],
        ],
        _kv("TCA plan", tca),
      ],
    );
  }

  Widget _bottomDraftBar(Map<String, dynamic> d) {
    final studId = (d["stud_id"] ?? "").toString();
    final studName = (d["stud_name"] ?? "Unknown").toString();

    return Container(
      padding: EdgeInsets.fromLTRB(2.h, 1.h, 2.h, 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 6.5.h,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Growkids.purpleFlo,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SOAPFormPage(
                  therapistId: widget.therapistId,
                  studId: studId,
                  studentName: studName,
                  existingReportId: widget.reportId,
                ),
              ),
            );
          },
          child: Text("Continue Editing Draft",
              style: TextStyle(color: Colors.white, fontSize: 12.sp)),
        ),
      ),
    );
  }
}
