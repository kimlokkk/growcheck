// view_daily_progress.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import 'add_daily_progress.dart';

class ViewDailyProgressPage extends StatefulWidget {
  final String progressId;
  final String teacherId;

  // optional (kalau kau nak prefill header cepat — tapi kita tetap fetch dari server)
  final String? studentName;
  final String? studId;

  const ViewDailyProgressPage({
    super.key,
    required this.progressId,
    required this.teacherId,
    this.studentName,
    this.studId,
  });

  @override
  State<ViewDailyProgressPage> createState() => _ViewDailyProgressPageState();
}

class _ViewDailyProgressPageState extends State<ViewDailyProgressPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? data; // single progress row

  // ===== ENDPOINTS (existing php) =====
  static const String _readEndpoint = "https://app.kizzukids.com.my/growkids/flutter/teacher_progress_read.php";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(_readEndpoint),
        body: {
          'progress_id': widget.progressId,
          'teacher_id': widget.teacherId,
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Server error: ${res.statusCode}");
      }

      final decoded = jsonDecode(res.body);

      // teacher_progress_read.php returns LIST: [ {...} ]
      if (decoded is! List || decoded.isEmpty) {
        throw Exception("No data found for progress_id=${widget.progressId}");
      }

      final row = (decoded.first as Map).cast<String, dynamic>();

      setState(() {
        data = row;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  // --- helpers ---
  DateTime? _parseDate(String? s) => s == null ? null : DateTime.tryParse(s);
  String _safe(String? s) => (s ?? '').toString();

  List<String> _parseFocusArea(dynamic raw) {
    if (raw == null) return [];
    try {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      final txt = raw.toString();
      final decoded = jsonDecode(txt);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  bool get _isDraft {
    final s = _safe(data?['status']);
    return s.toLowerCase() == 'draft';
  }

  @override
  Widget build(BuildContext context) {
    final studName =
        _safe(data?['stud_name']).isNotEmpty ? _safe(data?['stud_name']) : (widget.studentName ?? 'Student');

    final studId = _safe(data?['stud_id']).isNotEmpty ? _safe(data?['stud_id']) : (widget.studId ?? '-');

    final logDate = _parseDate(_safe(data?['log_date']));
    final dateLabel = logDate == null ? '-' : DateFormat('EEE, d MMM yyyy').format(logDate);

    final mood = _safe(data?['mood']).isEmpty ? '-' : _safe(data?['mood']);
    final summary = _safe(data?['summary']).trim();
    final updatedAt = _parseDate(_safe(data?['updated_at']));
    final updatedLabel = updatedAt == null ? null : DateFormat('d MMM yyyy, h:mm a').format(updatedAt);

    final focusAreas = _parseFocusArea(data?['focus_area']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Growkids.purpleFlo,
        surfaceTintColor: Growkids.purpleFlo,
        leading: const BackButton(color: Colors.white),
        title: const Text("Daily Progress", style: TextStyle(color: Colors.white)),
        actions: [
          if (!loading && error == null && data != null && _isDraft)
            IconButton(
              tooltip: "Edit draft",
              onPressed: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddDailyProgressPage(
                      studId: studId,
                      studentName: studName,
                      teacherId: widget.teacherId,
                      progressId: widget.progressId,
                    ),
                  ),
                );
                if (changed == true) _load();
              },
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
            ),
          IconButton(
            tooltip: "Refresh",
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? _errorState()
              : _content(
                  studName: studName,
                  studId: studId,
                  dateLabel: dateLabel,
                  mood: mood,
                  summary: summary,
                  focusAreas: focusAreas,
                  updatedLabel: updatedLabel,
                ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Failed to load progress", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(error ?? "Unknown error", style: TextStyle(color: Colors.black.withOpacity(.65))),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: Growkids.purpleFlo),
            child: const Text("Try again", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _content({
    required String studName,
    required String studId,
    required String dateLabel,
    required String mood,
    required String summary,
    required List<String> focusAreas,
    required String? updatedLabel,
  }) {
    return ListView(
      padding: EdgeInsets.all(2.h),
      children: [
        // ===== HERO =====
        Container(
          padding: EdgeInsets.all(2.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Growkids.purpleFlo,
                Growkids.purpleFlo.withOpacity(.70),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Growkids.purpleFlo.withOpacity(.25),
                blurRadius: 22,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 5.h,
                width: 5.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.25)),
                ),
                child: Icon(Icons.school_rounded, color: Growkids.purpleFlo, size: 3.h),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studName,
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Student ID: $studId • $dateLabel",
                      style: TextStyle(
                        color: Colors.white.withOpacity(.9),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        _pill("Mood: $mood"),
                        const SizedBox(width: 8),
                        _pill(_isDraft ? "Draft" : "Completed"),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 2.h),

        // ===== DETAILS =====
        _sectionTitle("Summary"),
        _card(
          child: Text(
            summary.isEmpty ? "-" : summary,
            style: TextStyle(fontSize: 12.sp, height: 1.4),
          ),
        ),

        _sectionTitle("Focus Area"),
        _card(
          child: focusAreas.isEmpty
              ? Text("-", style: TextStyle(color: Colors.black.withOpacity(.55)))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: focusAreas.map((f) => _chip(f)).toList(),
                ),
        ),

        _sectionTitle("Status"),
        _card(
          child: Row(
            children: [
              Icon(
                _isDraft ? Icons.edit_note_rounded : Icons.verified_rounded,
                color: _isDraft ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isDraft ? "Draft (not submitted yet)" : "Completed (submitted)",
                  style: TextStyle(fontSize: 12.sp),
                ),
              ),
            ],
          ),
        ),

        if (updatedLabel != null) ...[
          _sectionTitle("Last Updated"),
          _card(
            child: Row(
              children: [
                Icon(Icons.update_rounded, color: Colors.black.withOpacity(.6)),
                const SizedBox(width: 10),
                Text(updatedLabel, style: TextStyle(fontSize: 12.sp)),
              ],
            ),
          ),
        ],

        SizedBox(height: 2.h),

        // ===== bottom action =====
        if (_isDraft)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddDailyProgressPage(
                      studId: studId,
                      studentName: studName,
                      teacherId: widget.teacherId,
                      progressId: widget.progressId,
                    ),
                  ),
                );
                if (changed == true) _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              label: const Text(
                "Edit Draft",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.6.h),
      child: Text(title, style: TextStyle(fontSize: 14.sp)),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.2.h, vertical: 0.9.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Growkids.purpleFlo.withOpacity(.22)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.sp, color: Growkids.purpleFlo)),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.25)),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(.95), fontSize: 12.sp)),
    );
  }
}
