import 'package:flutter_test/flutter_test.dart';
import 'package:growcheck_app_v2/pages/denver/development_age.dart';

void main() {
  double? age(List<String> answers) => calculateDevelopmentAge([
        for (var i = 0; i < answers.length; i++)
          {'selectedOption': answers[i], 'pass75': 40.5 - i},
      ], 45);

  test('First three passes give actual age despite unanswered later items', () {
    expect(age(['Pass', 'Pass', 'Pass', '', '']), 45);
  });
  test('First three passes give actual age even with later failures', () {
    expect(age(['Pass', 'Pass', 'Pass', 'Fail', 'Fail', 'Fail']), 45);
  });
  test('Three passes after failures use the first pass age', () {
    expect(age(['Fail', 'Fail', 'Fail', 'Pass', 'Pass', 'Pass']), 37.5);
  });
  test('An interrupted sequence restarts the three-pass count', () {
    expect(age(['Pass', 'Fail', 'Pass', 'Pass', 'Pass']), 38.5);
  });
  test('Fewer than three consecutive passes cannot determine age', () {
    expect(age(['Pass', 'Pass', 'Fail']), isNull);
    expect(age([]), isNull);
  });
  test('No opportunity interrupts a pass sequence', () {
    expect(age(['Pass', 'N.O', 'Pass', 'Pass', 'Pass']), 38.5);
  });
}
