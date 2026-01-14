import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

class ScreeningDetails extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String age;
  final String ageInMonths;
  final int ageInMonthsINT;
  final String date;
  final String time;
  final String studBranch;
  final String therapistSuggestion;

  const ScreeningDetails({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.age,
    required this.ageInMonths,
    required this.ageInMonthsINT,
    required this.date,
    required this.studBranch,
    required this.therapistSuggestion,
    required this.time,
  });

  @override
  State<ScreeningDetails> createState() => _ScreeningDetailsState();
}

class _ScreeningDetailsState extends State<ScreeningDetails> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Screening Details",
          style: TextStyle(color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
        backgroundColor: Growkids.purple,
      ),
      body: Container(
        height: 100.h,
        padding: EdgeInsets.all(2.h),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg-home.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Growkids.purple,
              BlendMode.color,
            ),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 100.w,
              padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 2.h),
              decoration: BoxDecoration(
                color: Growkids.purple.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 4.h,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.studentName.substring(0, 1),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Growkids.purple,
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    widget.studentName,
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.ageInMonths,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2.h,
            ),
            Text(
              'Screening details',
              style: TextStyle(
                fontSize: 18.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: 1.h,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              margin: EdgeInsets.only(bottom: 1.h),
              decoration: BoxDecoration(
                color: GrowkidsPastel.purple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 3.h,
                    color: Growkids.purple,
                  ),
                  SizedBox(width: 5.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Date",
                        style: TextStyle(
                          fontSize: 16.sp,
                        ),
                      ),
                      Text(
                        DateFormat('d MMMM y').format(DateTime.parse(widget.date)),
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              margin: EdgeInsets.only(bottom: 1.h),
              decoration: BoxDecoration(
                color: GrowkidsPastel.purple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 3.h,
                    color: Growkids.purple,
                  ),
                  SizedBox(width: 5.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Time",
                        style: TextStyle(
                          fontSize: 16.sp,
                        ),
                      ),
                      Text(
                        widget.time,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              margin: EdgeInsets.only(bottom: 1.h),
              decoration: BoxDecoration(
                color: GrowkidsPastel.purple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.school,
                    size: 3.h,
                    color: Growkids.purple,
                  ),
                  SizedBox(width: 5.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Therapist",
                          style: TextStyle(
                            fontSize: 16.sp,
                          ),
                        ),
                        Text(
                          name,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              margin: EdgeInsets.only(bottom: 1.h),
              decoration: BoxDecoration(
                color: GrowkidsPastel.purple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place,
                    size: 3.h,
                    color: Growkids.purple,
                  ),
                  SizedBox(width: 5.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Branch",
                        style: TextStyle(
                          fontSize: 16.sp,
                        ),
                      ),
                      Text(
                        widget.studBranch,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
