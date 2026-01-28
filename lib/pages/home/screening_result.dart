import 'dart:convert';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class ScreeningResult extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final double age; // months
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;
  final String therapist_suggestion;
  final String screeningDate;

  const ScreeningResult({
    super.key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
    required this.therapist_suggestion,
    required this.screeningDate,
  });

  @override
  State<ScreeningResult> createState() => _ScreeningResultState();
}

class _ScreeningResultState extends State<ScreeningResult> {
  bool isLoading = true;
  List<Map<String, dynamic>> failData = [];
  Map<String, List<Map<String, dynamic>>> domainData = {};

  Future<void> fetchFailData() async {
    final response = await http.post(
      Uri.parse('http://app.kizzukids.com.my/growkids/flutter/screening_result.php'),
      body: {
        "stud_id": widget.studentId,
        "screening_id": widget.screeningId,
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        failData = List<Map<String, dynamic>>.from(data);
        _groupDataByDomain(failData);
        isLoading = false;
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _groupDataByDomain(List<Map<String, dynamic>> data) {
    domainData.clear();
    for (final item in data) {
      final domain = (item['domain'] ?? '').toString();
      domainData.putIfAbsent(domain, () => []).add(item);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchFailData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Screening Result'),
        centerTitle: true,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(2.h),
              children: [
                _heroHeader(),
                SizedBox(height: 2.h),
                _developmentGrid(),
                SizedBox(height: 1.h),
                _failComponentsCard(),
              ],
            ),
    );
  }

  // =========================
  // THEME BLOCKS (Premium)
  // =========================

  Widget _heroHeader() {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
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
                color: Growkids.purpleFlo,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
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
                    fontSize: 18.sp,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${widget.age.toStringAsFixed(0)} months',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    SizedBox(
                      width: 1.w,
                    ),
                    Text(
                      '*Age on the day of screening',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white.withOpacity(0.85),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 1.h,
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Colors.white.withOpacity(0.9),
                        size: 2.h,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEE, d MMM yyyy').format(DateTime.parse(widget.screeningDate)),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _developmentGrid() {
    final cardWidth = MediaQuery.of(context).size.width / 3;
    final cardHeight = MediaQuery.of(context).size.height / 6;

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: (cardWidth / cardHeight),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      crossAxisCount: 2,
      children: <Widget>[
        _buildDevelopmentCard('Fine Motor', widget.ageFineMotor, widget.age),
        _buildDevelopmentCard('Gross Motor', widget.ageGrossMotor, widget.age),
        _buildDevelopmentCard('Personal Social', widget.agePersonal, widget.age),
        _buildDevelopmentCard('Language', widget.ageLanguage, widget.age),
      ],
    );
  }

  Widget _buildDevelopmentCard(String title, double developmentalAge, double actualAge) {
    // kalau lebih/kurang dari actual, consider "needs attention"
    final ok = developmentalAge >= actualAge;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(height: 1.h),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (ok ? Colors.green : Colors.red).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (ok ? Colors.green : Colors.red).withOpacity(0.25)),
              ),
              child: Text(
                '${developmentalAge.toStringAsFixed(0)} months',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: ok ? Colors.green : Colors.red,
                ),
              ),
            ),
            SizedBox(height: 2.h),
            SfLinearGauge(
              minimum: 0,
              maximum: actualAge <= 0 ? 1 : actualAge,
              interval: (actualAge <= 0) ? 1 : (actualAge / 5),
              axisTrackStyle: LinearAxisTrackStyle(
                thickness: 1.h,
                color: Colors.black.withOpacity(0.08),
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
              markerPointers: [
                LinearShapePointer(
                  value: developmentalAge,
                  color: ok ? Colors.green : Colors.red,
                  height: 1.5.h,
                  width: 2.w,
                ),
              ],
              barPointers: [
                LinearBarPointer(
                  value: developmentalAge,
                  color: ok ? Colors.green : Colors.red,
                  thickness: 1.h,
                  edgeStyle: LinearEdgeStyle.bothCurve,
                ),
              ],
              animationDuration: 800,
            ),
            SizedBox(height: 1.h),
            Text(
              'Age in months',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failComponentsCard() {
    final totalFail = failData.length;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Fail/No Opportunity Components',
                style: TextStyle(
                  fontSize: 16.sp,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Growkids.purple.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalFail',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Growkids.purple,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Grouped by domain for faster review.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
          SizedBox(height: 1.2.h),
          if (domainData.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Text(
                'No failed components recorded.',
                style: TextStyle(fontSize: 14.sp, color: Colors.black54),
              ),
            )
          else
            ...domainData.entries.map((entry) {
              final domain = entry.key;
              final items = entry.value;

              return Container(
                margin: EdgeInsets.only(bottom: 1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  title: Text(
                    domain,
                    style: TextStyle(
                      fontSize: 14.sp,
                    ),
                  ),
                  subtitle: Text(
                    '${items.length} items',
                    style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                  ),
                  children: items.map((component) {
                    final comp = (component['component'] ?? '').toString();
                    final rec = (component['recommendation'] ?? '').toString();
                    final score = (component['score'] ?? '').toString();

                    return Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 1.h),
                      padding: EdgeInsets.all(1.5.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comp,
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                              ),
                              _scoreBadge(score),
                            ],
                          ),
                          if (rec.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Recommendation: $rec',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black.withOpacity(0.60),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _scoreBadge(String score) {
    final isFail = score == 'Fail';

    final color = isFail ? Colors.red : const Color(0xFFF59E0B); // amber for N.O

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 1.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        score == 'N.O' ? 'No Opportunity' : score,
        style: TextStyle(
          fontSize: 13.sp,
          color: color,
        ),
      ),
    );
  }
}
