// add_daily_progress.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

class AddDailyProgressPage extends StatefulWidget {
  final String studId;
  final String studentName;
  final String teacherId;

  // If exists -> edit mode (prefill)
  final String? progressId;

  const AddDailyProgressPage({
    super.key,
    required this.studId,
    required this.studentName,
    required this.teacherId,
    this.progressId,
  });

  @override
  State<AddDailyProgressPage> createState() => _AddDailyProgressPageState();
}

class _AddDailyProgressPageState extends State<AddDailyProgressPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _loadingExisting = false;

  // ===== Form fields =====
  DateTime _logDate = DateTime.now();
  final TextEditingController _summaryCtrl = TextEditingController();

  // Mood chips
  String _mood = 'Happy';

  // focus_area as chips
  final List<String> _focusAreas = [];
  final TextEditingController _focusInputCtrl = TextEditingController();

  // status: Draft / Submit
  String _status = 'Draft';

  // ===== ENDPOINTS (use your existing php) =====
  static const String _saveEndpoint = "https://app.kizzukids.com.my/growkids/flutter/teacher_progress_save.php";
  static const String _readEndpoint = "https://app.kizzukids.com.my/growkids/flutter/teacher_progress_read.php";

  // quick focus templates
  final List<String> _focusTemplates = const [
    'Attention',
    'Social Interaction',
    'Communication',
    'Fine Motor',
    'Gross Motor',
    'Behaviour',
    'Sensory Regulation',
    'Following Instructions',
    'Independence',
  ];

  // mood chips
  final List<_MoodItem> _moods = const [
    _MoodItem('Happy', '😊'),
    _MoodItem('Calm', '😌'),
    _MoodItem('Neutral', '😐'),
    _MoodItem('Energetic', '⚡'),
    _MoodItem('Tired', '😴'),
    _MoodItem('Anxious', '😟'),
    _MoodItem('Upset', '😣'),
    _MoodItem('Overstimulated', '🤯'),
  ];

  bool get isEdit => (widget.progressId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (isEdit) _loadExistingProgress();
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _focusInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProgress() async {
    setState(() => _loadingExisting = true);

    try {
      final res = await http.post(
        Uri.parse(_readEndpoint),
        body: {
          'progress_id': widget.progressId!,
          'teacher_id': widget.teacherId,
        },
      );

      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);

      // teacher_progress_read.php returns LIST: [ {...} ]
      if (decoded is! List || decoded.isEmpty) return;

      final data = (decoded.first as Map).cast<String, dynamic>();

      final logDate = DateTime.tryParse((data['log_date'] ?? '').toString());
      final summary = (data['summary'] ?? '').toString();
      final mood = (data['mood'] ?? 'Happy').toString();
      final statusDb = (data['status'] ?? 'Draft').toString(); // Draft/Submit

      // focus_area stored as JSON string
      List<String> focus = [];
      try {
        final faRaw = (data['focus_area'] ?? '[]').toString();
        final fa = jsonDecode(faRaw);
        if (fa is List) focus = fa.map((e) => e.toString()).toList();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        if (logDate != null) _logDate = logDate;
        _summaryCtrl.text = summary;
        _mood = mood;

        _focusAreas
          ..clear()
          ..addAll(focus);

        _status = (statusDb == 'Submit') ? 'Submit' : 'Draft';
      });
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  void _addFocusChip(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    if (_focusAreas.contains(t)) return;
    setState(() {
      _focusAreas.add(t);
      _focusInputCtrl.clear();
    });
  }

  void _toggleFocusChip(String text) {
    setState(() {
      if (_focusAreas.contains(text)) {
        _focusAreas.remove(text);
      } else {
        _focusAreas.add(text);
      }
    });
  }

  void _removeFocusChip(String text) => setState(() => _focusAreas.remove(text));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _logDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _logDate = picked);
  }

  Future<void> _submitWithStatus(String statusToSend) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _status = statusToSend; // Draft / Submit
    });

    try {
      final res = await http.post(
        Uri.parse(_saveEndpoint),
        body: {
          'stud_id': widget.studId,
          'teacher_id': widget.teacherId,
          'log_date': DateFormat('yyyy-MM-dd').format(_logDate),
          'summary': _summaryCtrl.text.trim(),
          'mood': _mood,
          'focus_area': jsonEncode(_focusAreas),
          'status': _status, // Draft / Submit
        },
      );

      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error (${res.statusCode})")),
        );
        return;
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception("Server returned non-JSON:\n${res.body}");
      }

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Saved!")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== UI atoms =====
  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.h, vertical: 0.5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14.sp)),
          if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12.sp, color: Colors.black.withOpacity(.55))),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(_logDate);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            backgroundColor: Growkids.purpleFlo,
            title: const Text("Daily Progress", style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (isEdit) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Cannot change date when editing an existing log.")),
                          );
                          return;
                        }
                        _pickDate();
                      },
                icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                tooltip: "Change date",
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black.withOpacity(.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _submitWithStatus('Draft'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        side: BorderSide(color: Growkids.purpleFlo.withOpacity(.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving && _status == 'Draft'
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Growkids.purpleFlo),
                            )
                          : Text("Save Draft", style: TextStyle(color: Growkids.purpleFlo, fontSize: 14.sp)),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _submitWithStatus('Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving && _status == 'Submit'
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text("Submit Update", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(2.h),
              children: [
                // ===== HERO =====
                Container(
                  padding: EdgeInsets.all(2.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Growkids.purpleFlo,
                        Growkids.purpleFlo.withOpacity(.70),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Growkids.purpleFlo.withOpacity(.25),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 5.h,
                        width: 5.h,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(.25)),
                        ),
                        child: Icon(Icons.school_rounded, color: Growkids.purpleFlo, size: 3.h),
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.studentName,
                                style: TextStyle(color: Colors.white, fontSize: 16.sp),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              "Student ID: ${widget.studId} • $dateLabel",
                              style: TextStyle(
                                color: Colors.white.withOpacity(.9),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 1.h),
                            Row(
                              children: [
                                _pill("Mood: $_mood"),
                                const SizedBox(width: 8),
                                _pill(_status == 'Submit' ? "Completed" : "Draft"),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 2.h),

                // ===== Mood =====
                _sectionTitle("Mood", subtitle: "Quick tap — no dropdown."),
                _card(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _moods.map((m) {
                      final active = _mood == m.value;
                      return InkWell(
                        onTap: () => setState(() => _mood = m.value),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: active ? Growkids.purpleFlo.withOpacity(.12) : const Color(0xFFF9FAFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: active ? Growkids.purpleFlo.withOpacity(.45) : Colors.black.withOpacity(.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(m.emoji, style: TextStyle(fontSize: 2.2.h)),
                              SizedBox(width: 1.w),
                              Text(
                                m.value,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: active ? Growkids.purpleFlo : Colors.black.withOpacity(.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ===== Summary =====
                _sectionTitle("Daily Summary", subtitle: "Short and clear. Focus on what changed today."),
                _card(
                  child: TextFormField(
                    controller: _summaryCtrl,
                    minLines: 5,
                    maxLines: 10,
                    style: TextStyle(fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText:
                          "Example:\n• Followed 2-step instructions during circle time\n• Improved eye contact during turn-taking\n• Needed reminders during transition",
                      filled: true,
                      fillColor: const Color(0xFFF9FAFF),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Growkids.purpleFlo.withOpacity(.7), width: 1.4),
                      ),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return "Summary is required";
                      if (t.length < 10) return "Make it a bit more detailed (min 10 chars)";
                      return null;
                    },
                  ),
                ),

                // ===== Focus Area =====
                _sectionTitle("Focus Area", subtitle: "Tap to select. Add custom if needed."),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _focusTemplates.map((f) {
                          final active = _focusAreas.contains(f);
                          return InkWell(
                            onTap: () => _toggleFocusChip(f),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 1.2.h, vertical: 0.8.h),
                              decoration: BoxDecoration(
                                color: active ? Growkids.purpleFlo : const Color(0xFFF9FAFF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: active ? Growkids.purpleFlo.withOpacity(.35) : Colors.black.withOpacity(.06),
                                ),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: active ? Colors.white : Colors.black.withOpacity(.75),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      if (_focusAreas.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _focusAreas.map((t) {
                            return Chip(
                              label: Text(t, style: TextStyle(fontSize: 13.sp)),
                              deleteIcon: const Icon(Icons.close_rounded, size: 18),
                              onDeleted: () => _removeFocusChip(t),
                            );
                          }).toList(),
                        ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _focusInputCtrl,
                              style: TextStyle(fontSize: 13.sp),
                              decoration: InputDecoration(
                                hintText: "Add custom focus area...",
                                filled: true,
                                fillColor: const Color(0xFFF9FAFF),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                                ),
                              ),
                              onSubmitted: _addFocusChip,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () => _addFocusChip(_focusInputCtrl.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Growkids.purpleFlo,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white),
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
        ),

        // loading overlay for edit prefill
        if (_loadingExisting)
          Container(
            color: Colors.black.withOpacity(0.18),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.25)),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(.95), fontSize: 12.sp)),
    );
  }
}

class _MoodItem {
  final String value;
  final String emoji;
  const _MoodItem(this.value, this.emoji);
}
