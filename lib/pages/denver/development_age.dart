/// Uses the displayed question order (highest pass75 first).
double? calculateDevelopmentAge(
  List<Map<String, dynamic>> questions,
  double actualAge,
) {
  var consecutivePasses = 0;
  var encounteredNonPass = false;
  double? firstPassAge;
  for (final question in questions) {
    if (question['selectedOption'] == 'Pass') {
      consecutivePasses++;
      if (consecutivePasses == 1) {
        firstPassAge = double.tryParse('${question['pass75']}');
      }
      if (consecutivePasses == 3) {
        return encounteredNonPass ? firstPassAge : actualAge;
      }
    } else {
      encounteredNonPass = true;
      consecutivePasses = 0;
      firstPassAge = null;
    }
  }
  return null;
}
