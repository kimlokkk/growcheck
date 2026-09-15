import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growcheck_app_v2/pages/denver/score.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sizer/sizer.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('Score result renders an unknown domain on $platform',
        (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(1500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await http.runWithClient(() async {
        await tester.pumpWidget(Sizer(builder: (context, orientation, device) {
          return const MaterialApp(
            home: ScoreResult(
              screeningId: 'test',
              studentId: 'test',
              studentName: 'Test student',
              age: '3 yrs',
              ageInMonths: '45',
              ageInMonthsINT: 45,
              ageFineMotor: null,
              ageGrossMotor: 45,
              agePersonal: 45,
              ageLanguage: 45,
            ),
          );
        }));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Belum dapat ditentukan'), findsOneWidget);
        expect(find.text('Finish Screening'), findsOneWidget);
      }, () => MockClient((request) async => http.Response('[]', 200)));
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
