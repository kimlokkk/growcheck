import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growcheck_app_v2/pages/denver/screening.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sizer/sizer.dart';

void main() {
  testWidgets('First three Pass taps display actual age without any Fail',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final questions = [
      for (var i = 0; i < 5; i++)
        {'id': i, 'component': 'Item $i', 'domain': 'Fine Motor',
          'pass75': 40 - i, 'recommendation': '', 'hasMaterial': 0}
    ];
    await http.runWithClient(() async {
      await tester.pumpWidget(Sizer(builder: (context, orientation, device) {
        return const MaterialApp(home: Screening(studentId: 'test',
          studentName: 'Test student', age: '3 yrs', ageInMonths: '45',
          ageInMonthsINT: 45));
      }));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Pass').at(i));
        await tester.pump();
      }
      expect(find.text('Development age 45 mo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async => http.Response(jsonEncode(questions), 200)));
    debugDefaultTargetPlatformOverride = null;
  });
}
