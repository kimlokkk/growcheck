import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

import 'sspsc_result.dart';

bool _useDesktopSspscFormLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class SSPSCForm extends StatefulWidget {
  final String studentId;
  final String teacherId;
  final String studentName;

  const SSPSCForm({
    super.key,
    required this.studentId,
    required this.teacherId,
    required this.studentName,
  });

  @override
  State<SSPSCForm> createState() => _SSPSCFormState();
}

class _SSPSCFormState extends State<SSPSCForm> {
  // --- CONFIGURATION ---
  static final String _getQuestionsUrl =
      ApiConfig.flutter('sp2_get_questions.php');
  static final String _submitUrl =
      ApiConfig.flutter('sp2_submit_assessment.php');

  /*static const String _getQuestionsUrl =
      'http://app-kizzu.test/growkids/flutter/sp2_get_questions.php';
  static const String _submitUrl =
      'http://app-kizzu.test/growkids/flutter/sp2_submit_assessment.php';*/

  // --- STATE ---
  bool isLoading = true;
  bool isSubmitting = false;

  List<Question> allQuestions = [];
  Map<String, List<Question>> groupedQuestions = {};
  List<String> sectionNames = [];
  Map<int, int> responses = {};
  Map<String, TextEditingController> commentControllers = {};

  final PageController _pageController = PageController();
  int _currentSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  // --- LOGIC ---
  Future<void> _fetchQuestions() async {
    try {
      final response = await http.get(Uri.parse(_getQuestionsUrl));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          List<dynamic> data = jsonResponse['data'];
          setState(() {
            allQuestions = data.map((item) => Question.fromJson(item)).toList();
            for (var q in allQuestions) {
              if (!groupedQuestions.containsKey(q.sectionName)) {
                groupedQuestions[q.sectionName] = [];
                sectionNames.add(q.sectionName);
                commentControllers[q.sectionName] = TextEditingController();
              }
              groupedQuestions[q.sectionName]!.add(q);
            }
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitAssessment() async {
    setState(() => isSubmitting = true);
    if (responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please answer the questions before submitting.")));
      setState(() => isSubmitting = false);
      return;
    }

    final payload = {
      "student_id": widget.studentId,
      "teacher_id": widget.teacherId,
      "assessment_date": DateTime.now().toIso8601String().split('T')[0],
      "responses": responses.entries
          .map((e) => {"question_id": e.key, "score_value": e.value})
          .toList(),
      "comment_auditory": commentControllers['Auditory']?.text ?? "",
      "comment_visual": commentControllers['Visual']?.text ?? "",
      "comment_touch": commentControllers['Touch']?.text ?? "",
      "comment_movement": commentControllers['Movement']?.text ?? "",
      "comment_behavioral": commentControllers['Behavioral']?.text ?? "",
    };

    try {
      final response = await http.post(Uri.parse(_submitUrl),
          body: json.encode(payload),
          headers: {"Content-Type": "application/json"});
      final result = json.decode(response.body);

      if (result['status'] == 'success') {
        Navigator.pop(context); // Close form
        // Open Result Page
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SSPSCResult(
                      assessmentId: result['assessment_id']
                          .toString(), // PHP must return this ID
                      studentName:
                          widget.studentName, // Pass this from the start
                    )));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result['message'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Connection Error")));
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Growkids.purpleFlo,
          ),
        ),
      );
    }

    if (_useDesktopSspscFormLayout(context)) return _buildDesktopPage();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "SSPSC",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sectionNames.length,
              onPageChanged: (index) =>
                  setState(() => _currentSectionIndex = index),
              itemBuilder: (context, index) {
                return _buildQuestionList(sectionNames[index],
                    groupedQuestions[sectionNames[index]]!);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildDesktopPage() {
    final section = sectionNames[_currentSectionIndex];
    final questions = groupedQuestions[section]!;
    final answered = questions.where((q) => responses[q.id] != null).length;
    final totalAnswered = responses.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          'SSPSC Assessment',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1540),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              children: [
                _desktopAssessmentHero(totalAnswered),
                const SizedBox(height: 18),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 285, child: _desktopSectionList()),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _desktopQuestionPanel(
                          section,
                          questions,
                          answered,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                _desktopBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopAssessmentHero(int answered) {
    final total = allQuestions.length;
    final progress = total == 0 ? 0.0 : answered / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .76),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: .18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              widget.studentName.isEmpty
                  ? '?'
                  : widget.studentName[0].toUpperCase(),
              style: const TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SCHOOL COMPANION SENSORY PROFILE 2',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$answered of $total items answered',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 270,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(progress * 100).round()}% complete',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSectionList() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assessment sections',
            style: TextStyle(
              color: Color(0xFF292B35),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select a section to review its items.',
            style: TextStyle(color: Color(0xFF858A98), fontSize: 9),
          ),
          const SizedBox(height: 17),
          Expanded(
            child: ListView.separated(
              itemCount: sectionNames.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final name = sectionNames[index];
                final questions = groupedQuestions[name]!;
                final answered =
                    questions.where((q) => responses[q.id] != null).length;
                final selected = index == _currentSectionIndex;
                return InkWell(
                  onTap: () => setState(() => _currentSectionIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? Growkids.purpleFlo.withValues(alpha: .10)
                          : const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? Growkids.purpleFlo.withValues(alpha: .30)
                            : const Color(0xFFE4E7ED),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? Growkids.purpleFlo : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF777C8D),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? Growkids.purpleFlo
                                      : const Color(0xFF3E414C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$answered / ${questions.length} answered',
                                style: const TextStyle(
                                  color: Color(0xFF9599A6),
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopQuestionPanel(
    String section,
    List<Question> questions,
    int answered,
  ) {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section,
                      style: const TextStyle(
                        color: Color(0xFF292B35),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$answered of ${questions.length} items answered in this section',
                      style: const TextStyle(
                        color: Color(0xFF858A98),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              _desktopScaleLegend(),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: Color(0xFFE6E8EE)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: questions.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                if (index == questions.length) {
                  return _desktopCommentBox(section);
                }
                return _desktopQuestionRow(questions[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopScaleLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E4EA)),
      ),
      child: const Text(
        '5 Almost Always  ·  4 Frequently  ·  3 Half  ·  2 Occasionally  ·  1 Almost Never  ·  NA',
        style: TextStyle(color: Color(0xFF747986), fontSize: 8),
      ),
    );
  }

  Widget _desktopQuestionRow(Question question) {
    final currentValue = responses[question.id];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: currentValue == null
              ? const Color(0xFFE3E5EB)
              : Growkids.purpleFlo.withValues(alpha: .28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${question.itemNumber}',
              style: const TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question.text,
              style: const TextStyle(
                color: Color(0xFF41444F),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildDesktopTag(question.quadrant),
          const SizedBox(width: 12),
          SizedBox(
            width: 330,
            child: Row(
              children: [
                for (final value in [5, 4, 3, 2, 1, 0])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => responses[question.id] = value);
                        },
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: currentValue == value
                                ? Growkids.purpleFlo
                                : const Color(0xFFF4F5F8),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            value == 0 ? 'NA' : '$value',
                            style: TextStyle(
                              color: currentValue == value
                                  ? Colors.white
                                  : const Color(0xFF696D79),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTag(String code) {
    Color color = Colors.grey;
    if (code == 'SK') color = Colors.orange;
    if (code == 'AV') color = Colors.red;
    if (code == 'SN') color = Colors.blue;
    if (code == 'RG') color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _desktopCommentBox(String section) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE1E4EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clinical Observations ($section)',
            style: const TextStyle(
              color: Color(0xFF444752),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentControllers[section],
            maxLines: 4,
            style: const TextStyle(fontSize: 10),
            decoration: InputDecoration(
              hintText: 'Add specific observations for this section...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7ED)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF555B6D).withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _desktopBottomBar() {
    final isLast = _currentSectionIndex == sectionNames.length - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EC)),
      ),
      child: Row(
        children: [
          Text(
            'Section ${_currentSectionIndex + 1} of ${sectionNames.length}',
            style: const TextStyle(color: Color(0xFF7C818E), fontSize: 9),
          ),
          const Spacer(),
          if (_currentSectionIndex > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentSectionIndex--),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Growkids.purpleFlo,
                side: const BorderSide(color: Growkids.purpleFlo),
              ),
            ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: isSubmitting
                ? null
                : () {
                    if (isLast) {
                      _submitAssessment();
                    } else {
                      setState(() => _currentSectionIndex++);
                    }
                  },
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    isLast
                        ? Icons.task_alt_rounded
                        : Icons.arrow_forward_rounded,
                    size: 17,
                  ),
            label: Text(isLast ? 'Submit Assessment' : 'Next Section'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    double progress = (_currentSectionIndex + 1) / sectionNames.length;
    return Container(
      color: Growkids.purpleFlo,
      padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              widget.studentName,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 0.5.h,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionNames[_currentSectionIndex].toUpperCase(),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              Text(
                "Step ${(_currentSectionIndex + 1)} of ${sectionNames.length}",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color.fromARGB(255, 54, 27, 160),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList(String section, List<Question> questions) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      itemCount: questions.length + 2, // Legend + Questions + CommentBox
      itemBuilder: (context, index) {
        if (index == 0) return _buildSegmentedLegend();
        if (index == questions.length + 1) return _buildCommentBox(section);
        return _buildQuestionCard(questions[index - 1]);
      },
    );
  }

  Widget _buildSegmentedLegend() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2.h),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Very subtle background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _segmentItem("1", "Almost Never"),
          _divider(), // Vertical line separator
          _segmentItem("2", "Occasionally"),
          _divider(),
          _segmentItem("3", "Half the Time"),
          _divider(),
          _segmentItem("4", "Frequently"),
          _divider(),
          _segmentItem("5", "Almost Always"),
        ],
      ),
    );
  }

  Widget _segmentItem(String number, String label) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              number,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp, // Small, crisp text
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 3.h,
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildQuestionCard(Question q) {
    int? currentVal = responses[q.id];
    bool isAnswered = currentVal != null;

    return Container(
      margin: EdgeInsets.only(bottom: 1.2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAnswered
              ? Growkids.purpleFlo.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${q.itemNumber}.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      color: Growkids.purpleFlo)),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  q.text,
                  style: TextStyle(
                      fontSize: 13.sp, color: Colors.black87, height: 1.35),
                ),
              ),
              SizedBox(width: 2.w),
              _buildSmallTag(q.quadrant),
            ],
          ),
          SizedBox(height: 1.5.h),
          _buildLikertStrip(q.id, currentVal),
        ],
      ),
    );
  }

  Widget _buildLikertStrip(int qId, int? currentVal) {
    return Container(
      height: 4.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(6, (index) {
          int val = 5 - index; // 5, 4, 3, 2, 1, 0 (NA)
          bool isSelected = currentVal == val;
          String label = val == 0 ? "NA" : val.toString();

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => responses[qId] = val);
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Growkids.purpleFlo : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: Growkids.purpleFlo.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCommentBox(String section) {
    return Container(
      padding: EdgeInsets.all(4.w),
      margin: EdgeInsets.symmetric(vertical: 2.h),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Clinical Observations ($section)",
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 1.h),
          TextField(
            controller: commentControllers[section],
            maxLines: 3,
            style: TextStyle(fontSize: 11.sp),
            decoration: InputDecoration(
              hintText: "Add specific notes here...",
              filled: true,
              fillColor: const Color(0xFFF5F6F9),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    bool isLast = _currentSectionIndex == sectionNames.length - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(5.w, 1.5.h, 5.w, 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentSectionIndex > 0)
            TextButton(
              onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease),
              child: Text("BACK",
                  style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
            )
          else
            const SizedBox(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: isSubmitting
                ? null
                : () {
                    if (isLast) {
                      _submitAssessment();
                    } else {
                      _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease);
                    }
                  },
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(isLast ? "FINISH" : "NEXT SECTION",
                    style: TextStyle(color: Colors.white, fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTag(String code) {
    Color color = Colors.grey;
    if (code == 'SK') color = Colors.orange;
    if (code == 'AV') color = Colors.red;
    if (code == 'SN') color = Colors.blue;
    if (code == 'RG') color = Colors.green;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 1.h),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(code,
          style: TextStyle(
            color: color,
            fontSize: 12.sp,
          )),
    );
  }
}

class Question {
  final int id;
  final int itemNumber;
  final String sectionName;
  final String text;
  final String quadrant;

  Question(
      {required this.id,
      required this.itemNumber,
      required this.sectionName,
      required this.text,
      required this.quadrant});

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: int.parse(json['id'].toString()),
      itemNumber: int.parse(json['item_number'].toString()),
      sectionName: json['section_name'],
      text: json['question_text'],
      quadrant: json['quadrant_code'] ?? 'N/A',
    );
  }
}
