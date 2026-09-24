import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_v3_tp_group_assessment_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _data(bool finalized) => {
      'tp_level': finalized ? 4 : null,
      'teacher_summary':
          finalized ? 'Consistent progress with spoken instructions.' : '',
      'observation_groups': [
        {
          'id': 11,
          'code': '1.1',
          'title':
              'Pupils will be able to listen and respond appropriately for a variety of purposes',
          'observation_text':
              finalized ? 'Responds to familiar sounds independently.' : '',
          'criteria': [
            {
              'code': '1.1.1',
              'title':
                  'Listen and respond to stimulus given: body percussion, voice sounds, environmental sounds and instrumental sounds.'
            },
          ],
        },
        {
          'id': 12,
          'code': '1.2',
          'title': 'Pupils will be able to say words and speak confidently',
          'observation_text': '',
          'criteria': [],
        },
      ],
    };

Future<void> _openPage(WidgetTester tester, {double scale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Renogare'),
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const Scaffold(body: SizedBox()),
  ));
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(MaterialPageRoute<void>(
      builder: (_) => const KssV3TpGroupAssessmentPage(
            teacherId: '1',
            assignmentId: '2',
            studentId: '3',
            tpGroup: {
              'id': 4,
              'code': '1.0',
              'title': 'LISTENING DAN SPEAKING'
            },
          )));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Renogare')
      ..addFont(rootBundle.load('fonts/Renogare-Regular.otf'));
    await loader.load();
  });

  for (final width in [320.0, 1440.0]) {
    for (final finalized in [false, true]) {
      testWidgets(
          'Section at $width, finalized=$finalized fits and preserves editability',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await http.runWithClient(() async {
          await _openPage(tester, scale: width == 320 ? 1.3 : 1);
          final pageScroll = find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first;
          expect(find.text('1.0 LISTENING DAN SPEAKING'), findsOneWidget);
          if (finalized) {
            expect(find.byType(TextField), findsNothing);
            expect(find.byType(DropdownButtonFormField<int>), findsNothing);
            expect(find.text('Confirm TP'), findsNothing);
            expect(find.text('Assessment confirmed'), findsOneWidget);
            await tester.scrollUntilVisible(
                find.text('No observation recorded.'), 200,
                scrollable: pageScroll);
          } else {
            expect(find.text('Confirm TP'), findsOneWidget);
            final footer = tester
                .widget<Scaffold>(find.byType(Scaffold).last)
                .bottomNavigationBar!;
            final footerSize = tester.getSize(find.byWidget(footer));
            expect(footerSize.height, lessThan(300));
          }
          await tester.scrollUntilVisible(
              find.text(
                  finalized ? 'Teacher summary' : 'Teacher summary · Optional'),
              200,
              scrollable: pageScroll);
          expect(tester.takeException(), isNull);
        },
            () => MockClient((request) async => http.Response(
                jsonEncode({'success': true, 'data': _data(finalized)}), 200)));
      });
    }
  }

  testWidgets(
      'Draft autosaves observations and confirmation sends selected TP and summary',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Map<String, String>>[];
    await http.runWithClient(() async {
      await _openPage(tester);
      await tester.enterText(find.byType(TextField).first, 'New evidence.');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved =
          requests.lastWhere((r) => r['action'] == 'save_observations');
      expect(jsonDecode(saved['observations_json']!).first['observation_text'],
          'New evidence.');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TP 5').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'A teacher summary.');
      await tester.tap(find.text('Confirm TP'));
      await tester.pumpAndSettle();
      final confirmed = requests.lastWhere((r) => r['action'] == 'finalize');
      expect(confirmed['tp_level'], '5');
      expect(confirmed['teacher_summary'], 'A teacher summary.');
      expect(confirmed['tp_group_id'], '4');
      expect(find.byType(KssV3TpGroupAssessmentPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests.add(request.bodyFields);
              return http.Response(
                  jsonEncode({'success': true, 'data': _data(false)}), 200);
            }));
  });
}
