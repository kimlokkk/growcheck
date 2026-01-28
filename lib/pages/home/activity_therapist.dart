import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/pages/home/edit_screening.dart';
import 'package:growcheck_app_v2/pages/home/profile_page.dart';
import 'package:growcheck_app_v2/pages/home/screening_result.dart';
import 'package:growcheck_app_v2/pages/home/therapist_suggestion.dart';
import 'package:growcheck_app_v2/screening/screening.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

enum ActTab { today, needAction, recent }

enum _WorkAction { openDashboard, editDraftScreening, addSuggestion }

class TherapistActivityPage extends StatefulWidget {
  final String therapistId;
  final ActTab initialTab;
  final VoidCallback? onConsumedInitialTab;

  const TherapistActivityPage({
    super.key,
    required this.therapistId,
    this.initialTab = ActTab.today, // ✅ default
    this.onConsumedInitialTab,
  });

  @override
  State<TherapistActivityPage> createState() => _TherapistActivityPageState();
}

class _TherapistActivityPageState extends State<TherapistActivityPage> {
  // ===== Endpoints (pakai yang kau dah guna) =====
  static const _childrenUrl = 'https://app.kizzukids.com.my/growkids/flutter/children_v2.php';
  static const _scheduleUrl = 'https://app.kizzukids.com.my/growkids/flutter/screening_schedule.php';

  static const _checkScreeningUrl = 'https://app.kizzukids.com.my/growkids/flutter/check_screening_data.php';
  static const _checkSuggestionUrl = 'https://app.kizzukids.com.my/growkids/flutter/check_suggestion_data.php';

  // ===== State =====
  bool loading = true;
  late ActTab tab;

  // raw lists
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> todaySchedule = [];

  // derived work queues
  List<_WorkItem> drafts = [];
  List<_WorkItem> suggestionPending = [];
  List<_WorkItem> recent = [];
  List<Map<String, dynamic>> allSchedule = [];
  List<_WorkItem> overdue = [];
  List<_WorkItem> screeningTodo = []; // ✅ NEW

  final Map<String, Map<String, dynamic>> screeningDataByStudId = {};
  final Map<String, String?> screeningStatusByStudId = {};

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;

    // ✅ mark as consumed (reset in HomeV2) – run after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onConsumedInitialTab?.call();
    });

    _loadAll();
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadAll() async {
    setState(() => loading = true);

    try {
      // 1) fetch students + today schedule (parallel)
      await Future.wait([
        _fetchStudents(),
        _fetchTodaySchedule(),
      ]);

      // 2) build status queues
      await _buildQueues();

      if (!mounted) return;
      setState(() => loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _fetchStudents() async {
    if (widget.therapistId.isEmpty) return;

    final res = await http.post(
      Uri.parse(_childrenUrl),
      body: {"therapist_id": widget.therapistId},
    );

    if (res.statusCode != 200) return;

    final decoded = json.decode(res.body);
    final List data = decoded is List ? decoded : [];

    final list = List<Map<String, dynamic>>.from(data);

    // enrich age + months (same logic macam kau buat)
    for (final s in list) {
      final dob = (s['stud_dob'] ?? '').toString();
      s['age'] = _calculateAge(dob);
      s['ageMonths'] = _calculateAgeInMonths(dob);
      s['ageMonthsInt'] = _calculateAgeInMonthsInt(dob);
    }

    students = list;
  }

  Future<void> _fetchTodaySchedule() async {
    if (widget.therapistId.isEmpty) return;

    final res = await http.post(
      Uri.parse(_scheduleUrl),
      body: {"therapist_id": widget.therapistId},
    );

    if (res.statusCode != 200) return;

    final decoded = json.decode(res.body);
    final List data = decoded is List ? decoded : [];

    final listAll = List<Map<String, dynamic>>.from(data);

    // simpan semua schedule (untuk overdue detect)
    allSchedule = listAll;

    // filter schedule hari ini untuk tab Today
    final today = _day(DateTime.now());
    final listToday = listAll.where((s) {
      final d = DateTime.tryParse((s['date'] ?? '').toString());
      if (d == null) return false;
      return _day(d) == today;
    }).toList();

    listToday.sort((a, b) {
      final ta = (a['time'] ?? '').toString();
      final tb = (b['time'] ?? '').toString();
      return ta.compareTo(tb);
    });

    todaySchedule = listToday;
  }

  Future<List<Map<String, dynamic>>> _fetchFailData({
    required String studId,
    required String screeningId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://app.kizzukids.com.my/growkids/flutter/screening_result.php'),
        body: {
          "stud_id": studId,
          "screening_id": screeningId,
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ======================
  // Build queues
  // ======================

  Future<void> _buildQueues() async {
    screeningStatusByStudId.clear();
    screeningDataByStudId.clear();
    overdue = [];
    drafts = [];
    suggestionPending = [];
    recent = [];
    screeningTodo = []; // ✅ NEW

    if (students.isEmpty) return;

    // concurrency limit supaya tak bom endpoint
    const int concurrency = 8;
    int idx = 0;

    final today = _day(DateTime.now());

    // Map: studId -> latest overdue schedule date
    final Map<String, DateTime> overdueByStudId = {};

    // cari schedule yang dah lepas (strictly < today)
    for (final s in allSchedule) {
      final studId = (s['stud_id'] ?? '').toString();
      final dateStr = (s['date'] ?? '').toString();
      final d = DateTime.tryParse(dateStr);
      if (studId.isEmpty || d == null) continue;

      if (_day(d).isBefore(today)) {
        // simpan yang paling latest (paling dekat dengan hari ni)
        final prev = overdueByStudId[studId];
        if (prev == null || d.isAfter(prev)) {
          overdueByStudId[studId] = d;
        }
      }
    }

    Future<void> worker() async {
      while (idx < students.length) {
        final i = idx++;
        final s = students[i];

        final studId = (s['stud_id'] ?? '').toString();
        final name = (s['stud_name'] ?? '-').toString();

        if (studId.isEmpty) continue;

        try {
          final screening = await _checkScreening(studId);
          final hasScreening = screening.isNotEmpty && screening['status'] != null;
          final status = screening['status']?.toString();
          screeningStatusByStudId[studId] = status;
          screeningDataByStudId[studId] = screening;

          // Overdue: ada schedule lepas, tapi screening belum wujud / status kosong
          final od = overdueByStudId[studId];
          final noScreeningYet = screening.isEmpty || status == null || status.isEmpty;

          if (od != null && noScreeningYet) {
            overdue.add(_WorkItem(
              studId: studId,
              studName: name,
              age: (s['age'] ?? '-').toString(),
              ageMonths: (s['ageMonths'] ?? '-').toString(),
              ageMonthsInt: int.tryParse((s['ageMonthsInt'] ?? '0').toString()) ?? 0,
              subtitle: 'Overdue screening — scheduled ${DateFormat('d MMM yyyy').format(od)}',
              icon: Icons.warning_rounded,
              accent: const Color(0xFFF59E0B), // amber/orange (UI je)
              dateText: DateFormat('yyyy-MM-dd').format(od),
              action: _WorkAction.openDashboard,
            ));
          }

          // 1) Draft screening
          if (hasScreening && (screening['status']?.toString() == 'Draft')) {
            drafts.add(_WorkItem(
              studId: studId,
              studName: name,
              age: (s['age'] ?? '-').toString(),
              ageMonths: (s['ageMonths'] ?? '-').toString(),
              ageMonthsInt: int.tryParse((s['ageMonthsInt'] ?? '0').toString()) ?? 0,
              subtitle: 'Draft screening — needs submit',
              icon: Icons.edit_rounded,
              accent: const Color(0xFF3B82F6),
              dateText: _safeDate(screening['screening_date']),
              action: _WorkAction.editDraftScreening,

              // ✅ INI YANG PENTING
              screeningId: screening['screening_id']?.toString(),
              ageYears: _safeParseDouble(screening['age']),
              ageFineMotor: _safeParseDouble(screening['age_fine_motor']),
              ageGrossMotor: _safeParseDouble(screening['age_gross_motor']),
              ageLanguage: _safeParseDouble(screening['age_language']),
              agePersonal: _safeParseDouble(screening['age_personal_social']),
              therapistSuggestion: screening['therapist_suggestion']?.toString(),
            ));
          }

          // 2) Suggestion pending = screening submit + suggestion kosong
          if (hasScreening && (screening['status']?.toString() == 'Submit')) {
            final suggestion = await _checkSuggestion(studId);

            if (suggestion.isEmpty) {
              suggestionPending.add(_WorkItem(
                studId: studId,
                studName: name,
                age: (s['age'] ?? '-').toString(),
                ageMonths: (s['ageMonths'] ?? '-').toString(),
                ageMonthsInt: int.tryParse((s['ageMonthsInt'] ?? '0').toString()) ?? 0,
                subtitle: 'Screening submitted — suggestion needed',
                icon: Icons.checklist_rounded,
                accent: const Color(0xFF0AAE7A),
                dateText: _safeDate(screening['screening_date']),
                action: _WorkAction.addSuggestion,

                // ✅ WAJIB
                screeningId: screening['screening_id']?.toString(),
                ageYears: _safeParseDouble(screening['age']),
                ageFineMotor: _safeParseDouble(screening['age_fine_motor']),
                ageGrossMotor: _safeParseDouble(screening['age_gross_motor']),
                ageLanguage: _safeParseDouble(screening['age_language']),
                agePersonal: _safeParseDouble(screening['age_personal_social']),
              ));
            }
          }

          // 3) Recent = last submitted screenings (limit 10 overall later)
          if (hasScreening && (screening['status']?.toString() == 'Submit')) {
            recent.add(_WorkItem(
              studId: studId,
              studName: name,
              age: (s['age'] ?? '-').toString(),
              ageMonths: (s['ageMonths'] ?? '-').toString(),
              ageMonthsInt: int.tryParse((s['ageMonthsInt'] ?? '0').toString()) ?? 0,
              subtitle: 'Screening submitted',
              icon: Icons.verified_rounded,
              accent: Growkids.purpleFlo,
              dateText: _safeDate(screening['screening_date']),
              action: _WorkAction.openDashboard,
            ));
          }
        } catch (_) {
          // ignore per student
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));

    // =====================
    // Build Screening TODO (scheduled today / overdue but not done)
    // =====================

    // map latest schedule date for each student for date <= today
    final Map<String, DateTime> latestDueByStudId = {};

    for (final sc in allSchedule) {
      final studId = (sc['stud_id'] ?? '').toString();
      final d = DateTime.tryParse((sc['date'] ?? '').toString());
      if (studId.isEmpty || d == null) continue;

      final day = _day(d);

      // “belum buat lagi” -> yang due hari ini atau dah lepas
      if (day.isAfter(today)) continue;

      final prev = latestDueByStudId[studId];
      if (prev == null || d.isAfter(prev)) {
        latestDueByStudId[studId] = d;
      }
    }

// Build list items
    screeningTodo = [];

    latestDueByStudId.forEach((studId, dueDate) {
      final status = screeningStatusByStudId[studId];

      final noScreeningYet = status == null || status.isEmpty;
      if (!noScreeningYet) return;

      // cari student info
      final st = students.firstWhere(
        (x) => (x['stud_id'] ?? '').toString() == studId,
        orElse: () => {},
      );

      final name = (st['stud_name'] ?? '-').toString();

      final isOverdue = _day(dueDate).isBefore(today);

      screeningTodo.add(_WorkItem(
        studId: studId,
        studName: name,
        age: (st['age'] ?? '-').toString(),
        ageMonths: (st['ageMonths'] ?? '-').toString(),
        ageMonthsInt: int.tryParse((st['ageMonthsInt'] ?? '0').toString()) ?? 0,
        subtitle: isOverdue
            ? 'Overdue screening — scheduled ${DateFormat('d MMM yyyy').format(dueDate)}'
            : 'Screening due today',
        icon: isOverdue ? Icons.warning_rounded : Icons.fact_check_rounded,
        accent: isOverdue ? const Color(0xFFF59E0B) : Growkids.purpleFlo,
        dateText: DateFormat('yyyy-MM-dd').format(dueDate),
        action: _WorkAction.openDashboard,
      ));
    });

// optional: sort (overdue first, latest first)
    int pr(_WorkItem w) => w.icon == Icons.warning_rounded ? 0 : 1;
    screeningTodo.sort((a, b) {
      final pa = pr(a), pb = pr(b);
      if (pa != pb) return pa.compareTo(pb);
      return (b.dateText).compareTo(a.dateText);
    });

    // sort queues
    drafts.sort((a, b) => (a.dateText ?? '').compareTo(b.dateText ?? ''));
    suggestionPending.sort((a, b) => (a.dateText ?? '').compareTo(b.dateText ?? ''));

    // recent sort desc by date
    recent.sort((a, b) => (b.dateText ?? '').compareTo(a.dateText ?? ''));
    if (recent.length > 10) {
      recent = recent.take(10).toList();
    }
  }

  // ======================
  // API helpers (copy logic from your page)
  // ======================

  Future<List<Map<String, dynamic>>> _fetchFailDataForEdit({
    required String studId,
    required String screeningId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('http://app.kizzukids.com.my/growkids/flutter/screening_result.php'),
        body: {
          "stud_id": studId,
          "screening_id": screeningId,
        },
      );

      if (res.statusCode != 200) return [];

      final decoded = json.decode(res.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _checkScreening(String studId) async {
    final res = await http.post(
      Uri.parse(_checkScreeningUrl),
      body: {'stud_id': studId},
    );

    if (res.statusCode != 200) return {};

    final decoded = jsonDecode(res.body);
    if (decoded is List && decoded.isNotEmpty) {
      return Map<String, dynamic>.from(decoded[0]);
    }
    return {};
  }

  Future<Map<String, dynamic>> _checkSuggestion(String studId) async {
    final res = await http.post(
      Uri.parse(_checkSuggestionUrl),
      body: {'studentId': studId},
    );

    if (res.statusCode != 200) return {};

    final decoded = jsonDecode(res.body);
    if (decoded is List && decoded.isNotEmpty) {
      return Map<String, dynamic>.from(decoded[0]);
    }
    return {};
  }

  String _safeDate(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  double _safeParseDouble(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(v.toString()) ?? 0;
  }

  String _calculateAge(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
      return '$years yrs';
    } catch (_) {
      return '-';
    }
  }

  String _calculateAgeInMonths(String dobString) {
    final m = _calculateAgeInMonthsInt(dobString);
    if (m < 0) return '-';
    return '$m mo';
  }

  int _calculateAgeInMonthsInt(String dobString) {
    if (dobString.isEmpty) return 0;
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int months = (now.year - dob.year) * 12 + (now.month - dob.month);
      if (now.day < dob.day) months--;
      return months < 0 ? 0 : months;
    } catch (_) {
      return 0;
    }
  }

  void _handleStudentTap({
    required String studId,
    required String studName,
    required String age,
    required String ageMonths,
    required int ageMonthsInt,
  }) async {
    final screening = screeningDataByStudId[studId] ?? {};

    final status = (screening['status'] ?? '').toString().trim(); // ✅ ambil terus dari cache
    final sid = (screening['screening_id'] ?? '').toString().trim();

    // 1) No screening yet
    if (status.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Screening(
            studentId: studId,
            studentName: studName,
            age: age,
            ageInMonths: ageMonths,
            ageInMonthsINT: ageMonthsInt,
          ),
        ),
      );
      return;
    }

    // 2) Draft
    if (status == 'Draft') {
      if (sid.isEmpty) return;

      final failData = await _fetchFailData(
        studId: studId,
        screeningId: sid,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditScreening(
            studentId: studId,
            screeningId: sid,
            studentName: studName,
            age: _safeParseDouble(screening['age']),
            ageFineMotor: _safeParseDouble(screening['age_fine_motor']),
            ageGrossMotor: _safeParseDouble(screening['age_gross_motor']),
            ageLanguage: _safeParseDouble(screening['age_language']),
            agePersonal: _safeParseDouble(screening['age_personal_social']),
            therapist_suggestion: screening['therapist_suggestion']?.toString() ?? '',
            failData: failData, // ✅ REAL DATA
          ),
        ),
      );
      return;
    }

    // 3) Submit
    if (status == 'Submit') {
      if (sid.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScreeningResult(
            studentId: studId,
            screeningId: sid,
            studentName: studName,
            age: _safeParseDouble(screening['age']),
            ageFineMotor: _safeParseDouble(screening['age_fine_motor']),
            ageGrossMotor: _safeParseDouble(screening['age_gross_motor']),
            agePersonal: _safeParseDouble(screening['age_personal_social']),
            ageLanguage: _safeParseDouble(screening['age_language']),
            therapist_suggestion: screening['therapist_suggestion']?.toString() ?? '',
            screeningDate: (screening['screening_date'] ?? '').toString(),
          ),
        ),
      );
      return;
    }

    // fallback (kalau status pelik)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Screening(
          studentId: studId,
          studentName: studName,
          age: age,
          ageInMonths: ageMonths,
          ageInMonthsINT: ageMonthsInt,
        ),
      ),
    );
  }

  // ======================
  // UI
  // ======================

  @override
  Widget build(BuildContext context) {
    final todayCount = todaySchedule.length;
    final draftCount = drafts.length;
    final pendingCount = suggestionPending.length;
    final screeningCount = screeningTodo.length; // ✅ NEW

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Text(
                    'Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16.sp,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadAll,
                    icon: Icon(Icons.refresh_rounded, size: 3.h),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Your work queue (tap to open student dashboard)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withOpacity(0.6),
                      fontSize: 12.sp,
                    ),
              ),
              SizedBox(height: 2.h),

              // summary chips
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, // ✅ from 3 -> 2
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3.2, // ✅ adjust supaya tak sempit
                children: [
                  _MiniStat(
                    label: 'Today',
                    value: '$todayCount',
                    icon: Icons.today_rounded,
                    accent: Growkids.purpleFlo,
                  ),
                  _MiniStat(
                    label: 'Screening',
                    value: '$screeningCount',
                    icon: Icons.fact_check_rounded,
                    accent: const Color(0xFFF59E0B), // pending screening vibe
                  ),
                  _MiniStat(
                    label: 'Drafts',
                    value: '$draftCount',
                    icon: Icons.edit_rounded,
                    accent: const Color(0xFF3B82F6),
                  ),
                  _MiniStat(
                    label: 'Suggestion',
                    value: '$pendingCount',
                    icon: Icons.checklist_rounded,
                    accent: const Color(0xFF0AAE7A),
                  ),
                ],
              ),

              SizedBox(height: 2.h),
              _Tabs(
                tab: tab,
                onChanged: (t) => setState(() => tab = t),
              ),
              const SizedBox(height: 14),

              if (loading) ...[
                const SizedBox(height: 60),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 60),
              ] else ...[
                if (tab == ActTab.today) _buildToday(),
                if (tab == ActTab.needAction) _buildNeedAction(),
                if (tab == ActTab.recent) _buildRecent(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToday() {
    if (todaySchedule.isEmpty) {
      return _EmptyState(text: 'No screenings scheduled for today.');
    }

    return Column(
      children: todaySchedule.map((s) {
        // find student info from students list
        final sid = (s['stud_id'] ?? '').toString();
        final match = students.where((x) => (x['stud_id'] ?? '').toString() == sid).toList();
        final st = match.isNotEmpty ? match.first : {};

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WorkTile(
            title: (s['stud_name'] ?? '-').toString(),
            subtitle: 'Screening today • ${(s['time'] ?? '-').toString()} • ${(s['stud_branch'] ?? '').toString()}',
            icon: Icons.fact_check_rounded,
            accent: Growkids.purpleFlo,
            rightText: 'Today',
            onTap: () => _handleStudentTap(
              studId: sid,
              studName: (s['stud_name'] ?? '-').toString(),
              age: (st['age'] ?? '-').toString(),
              ageMonths: (st['ageMonths'] ?? '-').toString(),
              ageMonthsInt: int.tryParse((st['ageMonthsInt'] ?? '0').toString()) ?? 0,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNeedAction() {
    final combined = <_WorkItem>[
      ...overdue,
      ...drafts,
      ...suggestionPending,
    ];

    if (combined.isEmpty) {
      return _EmptyState(text: 'No pending work. Nice 👍');
    }

    // sort: suggestion first then draft (optional)
    combined.sort((a, b) => a.subtitle.compareTo(b.subtitle));

    return Column(
      children: combined.map((w) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WorkTile(
            title: w.studName,
            subtitle: w.subtitle + (w.dateText.isNotEmpty ? ' • ${_prettyDate(w.dateText)}' : ''),
            icon: w.icon,
            accent: w.accent,
            rightText: w.dateText.isEmpty ? '' : _prettyDateShort(w.dateText),
            onTap: () => _handleWorkTap(w),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecent() {
    if (recent.isEmpty) return _EmptyState(text: 'No recent activity yet.');

    return Column(
      children: recent.map((w) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WorkTile(
            title: w.studName,
            subtitle: w.subtitle + (w.dateText.isNotEmpty ? ' • ${_prettyDate(w.dateText)}' : ''),
            icon: w.icon,
            accent: w.accent,
            rightText: w.dateText.isEmpty ? '' : _prettyDateShort(w.dateText),
            onTap: () => _handleWorkTap(w),
          ),
        );
      }).toList(),
    );
  }

  String _prettyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('EEE, d MMM yyyy').format(d);
  }

  String _prettyDateShort(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return DateFormat('d MMM').format(d);
  }

  void _openStudentDashboard({
    required String studId,
    required String studName,
    required String age,
    required String ageMonths,
    required int ageMonthsInt,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentMainDashboard(
          studentId: studId,
          studentName: studName,
          age: age,
          ageInMonths: ageMonths,
          ageInMonthsINT: ageMonthsInt,
        ),
      ),
    );
  }

  void _handleWorkTap(_WorkItem w) async {
    // For items that should just open correct screen based on status
    if (w.action == _WorkAction.openDashboard) {
      return _handleStudentTap(
        studId: w.studId,
        studName: w.studName,
        age: w.age,
        ageMonths: w.ageMonths,
        ageMonthsInt: w.ageMonthsInt,
      );
    }

    // fallback kalau data payload tak lengkap
    void openDashboardFallback() {
      _openStudentDashboard(
        studId: w.studId,
        studName: w.studName,
        age: w.age,
        ageMonths: w.ageMonths,
        ageMonthsInt: w.ageMonthsInt,
      );
    }

    if (w.action == _WorkAction.editDraftScreening) {
      final failData = await _fetchFailData(
        studId: w.studId,
        screeningId: w.screeningId!,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditScreening(
            studentId: w.studId,
            screeningId: w.screeningId!,
            age: w.ageYears ?? 0,
            studentName: w.studName,
            ageFineMotor: w.ageFineMotor ?? 0,
            ageGrossMotor: w.ageGrossMotor ?? 0,
            ageLanguage: w.ageLanguage ?? 0,
            agePersonal: w.agePersonal ?? 0,
            therapist_suggestion: w.therapistSuggestion ?? '',
            failData: failData, // ✅ real
          ),
        ),
      );
      return;
    }

    if (w.action == _WorkAction.addSuggestion) {
      final sid = w.screeningId;
      if (sid == null || sid.isEmpty) return openDashboardFallback();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TherapistSuggestion(
            studentId: w.studId,
            screeningId: sid,
            studentName: w.studName,
            age: w.ageYears ?? 0,
            ageFineMotor: w.ageFineMotor ?? 0,
            ageGrossMotor: w.ageGrossMotor ?? 0,
            ageLanguage: w.ageLanguage ?? 0,
            agePersonal: w.agePersonal ?? 0,
          ),
        ),
      );
      return;
    }

    // default
    openDashboardFallback();
  }
}

// ======================
// Models + UI components
// ======================

class _WorkItem {
  final String studId;
  final String studName;
  final String age;
  final String ageMonths;
  final int ageMonthsInt;

  final String subtitle;
  final IconData icon;
  final Color accent;
  final String dateText;

  // ✅ new
  final _WorkAction action;

  // ✅ optional payload untuk direct route
  final String? screeningId;
  final double? ageYears;
  final double? ageFineMotor;
  final double? ageGrossMotor;
  final double? ageLanguage;
  final double? agePersonal;
  final String? therapistSuggestion; // from screeningData if any

  const _WorkItem({
    required this.studId,
    required this.studName,
    required this.age,
    required this.ageMonths,
    required this.ageMonthsInt,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.dateText,
    required this.action,
    this.screeningId,
    this.ageYears,
    this.ageFineMotor,
    this.ageGrossMotor,
    this.ageLanguage,
    this.agePersonal,
    this.therapistSuggestion,
  });
}

class _Tabs extends StatelessWidget {
  final ActTab tab;
  final ValueChanged<ActTab> onChanged;

  const _Tabs({
    required this.tab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          _TabBtn(
            label: 'Today',
            active: tab == ActTab.today,
            onTap: () => onChanged(ActTab.today),
          ),
          const SizedBox(width: 6),
          _TabBtn(
            label: 'Need action',
            active: tab == ActTab.needAction,
            onTap: () => onChanged(ActTab.needAction),
          ),
          const SizedBox(width: 6),
          _TabBtn(
            label: 'Recent',
            active: tab == ActTab.recent,
            onTap: () => onChanged(ActTab.recent),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          decoration: BoxDecoration(
            color: active ? Growkids.purpleFlo.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: active ? Growkids.purpleFlo : Colors.black.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(1.4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 3.h,
            backgroundColor: accent.withOpacity(0.12),
            child: Icon(icon, color: accent, size: 3.h),
          ),
          SizedBox(width: 1.2.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String rightText;
  final VoidCallback onTap;

  const _WorkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.rightText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 2.6.h,
              backgroundColor: accent.withOpacity(0.12),
              child: Icon(icon, color: accent, size: 2.6.h),
            ),
            SizedBox(width: 1.2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.sp,
                        ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12.sp,
                          color: Colors.black.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
            if (rightText.isNotEmpty) ...[
              SizedBox(width: 1.w),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  rightText,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.sp,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
              ),
            ],
            SizedBox(width: 0.6.w),
            Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.35), size: 3.h),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black.withOpacity(0.55),
              fontSize: 14.sp,
            ),
      ),
    );
  }
}
