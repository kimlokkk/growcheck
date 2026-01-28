import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

class ViewSuggestion extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age; // months
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;

  const ViewSuggestion({
    Key? key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
  }) : super(key: key);

  @override
  State<ViewSuggestion> createState() => _ViewSuggestionState();
}

class _ViewSuggestionState extends State<ViewSuggestion> {
  bool isLoading = true;
  List<dynamic> suggestions = [];
  List<dynamic> recommendations = [];
  List<dynamic> interventions = [];

  int _tabIndex = 0; // 0 sug, 1 rec, 2 plan
  String? _error;

  Future<void> fetchData() async {
    try {
      final response = await http.post(
        Uri.parse('http://app.kizzukids.com.my/growkids/flutter/fetch_suggestion_submission.php'),
        body: {"studentId": widget.studentId},
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to load data (HTTP ${response.statusCode})");
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception("Unexpected response format");
      }

      setState(() {
        suggestions = decoded["suggestions"] ?? [];
        recommendations = decoded["recommendations"] ?? [];
        interventions = decoded["interventions"] ?? [];
        isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // =========================
  // Premium atoms (StudentHub vibe)
  // =========================

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 2.h, color: Colors.white.withOpacity(0.92)),
          SizedBox(width: 1.w),
          Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _heroHeader() {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white,
            child: Text(
              widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : '?',
              style: TextStyle(
                color: Growkids.purple,
                fontSize: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${widget.age.toInt()} months • Screening #${widget.screeningId}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.88),
                  ),
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 1.h,
                  runSpacing: 8,
                  children: [
                    _chip('Suggestions: ${suggestions.length}', Icons.lightbulb_rounded),
                    _chip('Advice: ${recommendations.length}', Icons.checklist_rounded),
                    _chip('Plans: ${interventions.length}', Icons.route_rounded),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _summaryCard(String label, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Growkids.purple.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Growkids.purple.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              height: 4.h,
              width: 4.h,
              decoration: BoxDecoration(
                color: Growkids.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Growkids.purple,
                size: 2.h,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp, color: Colors.black.withOpacity(0.62)),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentedTabs() {
    Widget tab(String text, IconData icon, int index) {
      final active = _tabIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tabIndex = index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(vertical: 1.h),
            decoration: BoxDecoration(
              color: active ? Growkids.purpleFlo : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
              boxShadow: active
                  ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 8))]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 2.5.h, color: active ? Colors.white : Colors.black.withOpacity(0.65)),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: active ? Colors.white : Colors.black.withOpacity(0.70),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Suggestions', Icons.lightbulb_rounded, 0),
        SizedBox(width: 1.w),
        tab('Advice', Icons.checklist_rounded, 1),
        SizedBox(width: 1.w),
        tab('Plan', Icons.route_rounded, 2),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.black.withOpacity(0.55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.black.withOpacity(0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(List<dynamic> items, String keyName, {required IconData icon}) {
    if (items.isEmpty) {
      return _emptyBox('No data available yet.');
    }

    return Column(
      children: List.generate(items.length, (i) {
        final it = items[i] as Map? ?? {};
        final text = (it[keyName] ?? '').toString().trim();

        return Container(
          margin: EdgeInsets.only(bottom: 1.h),
          padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 5.h,
                width: 5.h,
                decoration: BoxDecoration(
                  color: Growkids.purple.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Growkids.purple, size: 2.5.h),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  text.isEmpty ? '-' : text,
                  style: TextStyle(fontSize: 14.sp, color: Colors.black.withOpacity(0.78)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _interventionList() {
    if (interventions.isEmpty) {
      return _emptyBox('No intervention plan available yet.');
    }

    return Column(
      children: List.generate(interventions.length, (i) {
        final it = interventions[i] as Map? ?? {};
        final title = (it['title'] ?? '').toString().trim();
        final desc = (it['description'] ?? '').toString().trim();
        final ex = (it['example'] ?? '').toString().trim();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 4.h,
                    width: 4.h,
                    decoration: BoxDecoration(
                      color: Growkids.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(color: Growkids.purple, fontSize: 14.sp),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Intervention Plan' : title,
                      style: TextStyle(fontSize: 14.sp, color: Colors.black.withOpacity(0.82)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),

              // Description
              Text('Description', style: TextStyle(fontSize: 12.sp, color: Growkids.pink)),
              SizedBox(height: 0.5.h),
              Text(
                desc.isEmpty ? '-' : desc,
                style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.70)),
              ),

              SizedBox(height: 1.h),

              // Example
              Text('Example', style: TextStyle(fontSize: 12.sp, color: Growkids.pink)),
              SizedBox(height: 0.5.h),
              Text(
                ex.isEmpty ? '-' : ex,
                style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(0.70)),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _contentByTab() {
    switch (_tabIndex) {
      case 0:
        return _bulletList(suggestions, 'suggestion', icon: Icons.lightbulb_rounded);
      case 1:
        return _bulletList(recommendations, 'recommendation', icon: Icons.checklist_rounded);
      case 2:
      default:
        return _interventionList();
    }
  }

  // =========================
  // BUILD (Premium)
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Suggestion & Plan'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      isLoading = true;
                      _error = null;
                    });
                    fetchData();
                  },
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: EdgeInsets.all(2.h),
                  child: _glassCard(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.redAccent.withOpacity(0.9)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                                fontSize: 12.sp, color: Colors.black.withOpacity(0.75), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(2.h, 2.h, 2.h, 2.h),
                    child: Column(
                      children: [
                        _heroHeader(),
                        SizedBox(height: 1.6.h),
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Summary',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                  )),
                              SizedBox(height: 1.2.h),
                              Row(
                                children: [
                                  _summaryCard('Suggestions', suggestions.length, Icons.lightbulb_rounded),
                                  const SizedBox(width: 10),
                                  _summaryCard('Advice', recommendations.length, Icons.checklist_rounded),
                                  const SizedBox(width: 10),
                                  _summaryCard('Plans', interventions.length, Icons.route_rounded),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 1.2.h),
                        _segmentedTabs(),
                        SizedBox(height: 1.2.h),
                        _glassCard(
                          child: _contentByTab(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
