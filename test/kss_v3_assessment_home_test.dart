import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_assessment_home.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _response(String endpoint,
    {bool empty = false, int students = 3}) {
  final assignment = {
    'assignment_id': 1,
    'subject_name': 'Pendidikan Sains Sosial dan Alam Sekitar',
    'class_name': '4 Amanah',
    'year_level': 4,
    'student_count': students,
    'total_students': students,
    'completed_students': 0,
    'continue_student_id': students == 0 ? null : 1,
    'continue_student_name': 'A student with a longer display name',
    'completed_sections': 3,
    'total_sections': 6,
  };
  final dynamic data;
  if (endpoint.endsWith('teacher_dashboard.php')) {
    data = {
      'summary': {
        'in_progress': empty || students == 0 ? 0 : 1,
        'not_completed': empty ? 0 : students
      },
      'assignments': empty ? [] : [assignment],
    };
  } else if (endpoint.endsWith('my_teaching.php')) {
    data = empty ? [] : [assignment];
  } else {
    data = empty
        ? []
        : [
            {
              'class_name': '4 Amanah',
              'year_level': 4,
              'academic_year': 2026,
              'student_count': students,
              'subject_count': 1,
              'homeroom_teacher_name': 'Teacher with a longer display name',
            }
          ];
  }
  return {'success': true, 'data': data};
}

Future<void> _pumpHome(WidgetTester tester, {double scale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Renogare'),
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const KssV3AssessmentHome(teacherId: 'test'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('Workspace fits width $width with long names and enlarged text',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await _pumpHome(tester, scale: width == 320 ? 1.5 : 1);
        expect(find.text('Create class'), findsOneWidget);
        final font =
            DefaultTextStyle.of(tester.element(find.text('TEACHER WORKSPACE')))
                .style
                .fontFamily;
        expect(font, 'Renogare');
        await tester.scrollUntilVisible(find.text('Continue assessment'), 240);
        expect(find.text('3 of 6 sections completed'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('My Teaching Classes'), 240);
        expect(find.text('3 pending'), findsOneWidget);
        final teachingPosition =
            tester.getTopLeft(find.text('My Teaching Classes'));
        final classesPosition = tester.getTopLeft(find.text('My Classes'));
        if (width >= 1000) {
          expect(classesPosition.dy, teachingPosition.dy);
          expect(classesPosition.dx, greaterThan(teachingPosition.dx));
        } else {
          expect(classesPosition.dy, greaterThan(teachingPosition.dy));
        }
        await tester.scrollUntilVisible(
            find.text('Homeroom teacher: Teacher with a longer display name'),
            240);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async =>
              http.Response(jsonEncode(_response(request.url.path)), 200)));
    });
  }

  testWidgets('Empty workspace does not claim assessments are complete',
      (tester) async {
    await http.runWithClient(() async {
      await _pumpHome(tester);
      expect(find.text('Your workspace is ready'), findsOneWidget);
      expect(find.text('You’re all caught up'), findsNothing);
      expect(find.text('Create class'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('No homeroom classes yet'), 200);
      expect(find.text('No teaching assignments yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async => http.Response(
            jsonEncode(_response(request.url.path, empty: true)), 200)));
  });

  testWidgets('Assignment without students is not marked completed',
      (tester) async {
    await http.runWithClient(() async {
      await _pumpHome(tester);
      await tester.scrollUntilVisible(find.text('No students'), 200);
      expect(find.text('Completed'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async => http.Response(
            jsonEncode(_response(request.url.path, students: 0)), 200)));
  });

  testWidgets('Failed workspace can be retried', (tester) async {
    var fail = true;
    await http.runWithClient(() async {
      await _pumpHome(tester);
      expect(find.text('Unable to load assessment workspace'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load assessment workspace'), findsNothing);
      expect(find.text('NEXT ASSESSMENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async => http.Response(
            jsonEncode(fail
                ? {'success': false, 'message': 'Try again later.'}
                : _response(request.url.path)),
            fail ? 500 : 200)));
  });
}
