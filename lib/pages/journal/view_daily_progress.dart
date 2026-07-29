// view_daily_progress.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

class ViewDailyProgressPage extends StatefulWidget {
  final String progressId;
  final String teacherId;
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
  Map<String, dynamic>? data;

  static final String _readEndpoint =
      ApiConfig.flutter('get_daily_progress.php');
  /*static const String _readEndpoint =
      "http://app-kizzu.test/growkids/flutter/get_daily_progress.php";*/

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

      final decoded = jsonDecode(res.body);

      if (decoded['success'] != true) {
        throw Exception(decoded['message'] ?? 'Failed to load data');
      }

      setState(() {
        data = (decoded['data'] as Map).cast<String, dynamic>();
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: Growkids.purpleFlo,
          foregroundColor: Colors.white,
          title: const Text('Daily Progress'),
        ),
        body: Padding(
          padding: EdgeInsets.all(2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Failed to load data',
                  style:
                      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(error ?? '-', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Growkids.purpleFlo),
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    final studName = widget.studentName ?? 'Student';
    final studId = widget.studId ?? '-';
    final logDate = DateTime.tryParse(data?['log_date'] ?? '');
    final dateLabel =
        logDate == null ? '-' : DateFormat('EEE, d MMM yyyy').format(logDate);

    final title = data?['title'] ?? '-';
    final content = data?['content'] ?? '-';
    final status = data?['status'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Daily Progress'),
      ),
      body: ListView(
        padding: EdgeInsets.all(2.h),
        children: [
          _hero(studName, studId, dateLabel, status),
          SizedBox(height: 2.h),
          _sectionTitle('Title'),
          _card(child: Text(title, style: TextStyle(fontSize: 13.sp))),
          _sectionTitle('Content'),
          _card(
            child:
                Text(content, style: TextStyle(fontSize: 12.sp, height: 1.5)),
          ),
          _sectionTitle('Attachment'),
          _card(
            child: const Row(
              children: [
                Icon(Icons.attach_file_rounded),
                SizedBox(width: 10),
                Text('No attachment'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(String name, String id, String date, String status) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: .25),
            blurRadius: 22,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 3.h,
            backgroundColor: Colors.white,
            child: Icon(Icons.menu_book_rounded,
                color: Growkids.purpleFlo, size: 3.h),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                Text("Student ID: $id • $date",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
                        fontSize: 12.sp)),
                SizedBox(height: 1.h),
                _pill(status),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: EdgeInsets.symmetric(vertical: 0.6.h),
        child: Text(title, style: TextStyle(fontSize: 14.sp)),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: .06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 18,
                offset: const Offset(0, 10)),
          ],
        ),
        child: child,
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .25)),
        ),
        child: Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .95), fontSize: 12.sp)),
      );
}
