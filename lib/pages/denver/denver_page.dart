import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/denver/edit_screening.dart';
import 'package:growcheck_app_v2/pages/denver/screening_result.dart';
import 'package:growcheck_app_v2/pages/denver/therapist_suggestion.dart';
import 'package:growcheck_app_v2/pages/denver/screening.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopDenverPageLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

// ===== ROUTES (EDIT ikut project kau) =====
const String kRouteDenverScreeningForm = '/denver/screening';
const String kRouteDenverSuggestion = '/denver/suggestion';
const String kRouteDenverHistory = '/denver/history';

enum _WorkState { todo, draft, done }

class DenverPage extends StatefulWidget {
  final String therapistId;

  const DenverPage({
    super.key,
    required this.therapistId,
  });

  @override
  State<DenverPage> createState() => _DenverPageState();
}

class _DenverPageState extends State<DenverPage> {
  // Therapist student list
  /*static const String _childrenUrl =
      'http://app-kizzu.test/growkids/flutter/children_v2.php';

  static const String _bulkStatusUrl =
      'http://app-kizzu.test/growkids/flutter/check_student_status_bulk.php';

  static const String _checkScreeningUrl =
      'http://app-kizzu.test/growkids/flutter/check_screening_data.php';

  static const String _draftListUrl =
      'http://app-kizzu.test/growkids/flutter/children_draft_list.php';

  static const String _submitListUrl =
      'http://app-kizzu.test/growkids/flutter/children_history_list.php';*/

  // Bulk status (screening/suggestion/etc.)

  static final String _childrenUrl = ApiConfig.flutter('children_v2.php');
  static final String _bulkStatusUrl =
      ApiConfig.flutter('check_student_status_bulk.php');

  static final String _checkScreeningUrl =
      ApiConfig.flutter('check_screening_data.php');

  static final String _draftListUrl =
      ApiConfig.flutter('children_draft_list.php');

  static final String _submitListUrl =
      ApiConfig.flutter('children_history_list.php');

  bool _loading = true;
  String? _error;

  // counts for mini overview
  int _countDraft = 0;
  int _countNeedPlan = 0;
  int _countDone = 0; // screening submitted/done, regardless of suggestion

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = await _fetchBulkStatusMap();

      int draftC = 0;
      int needPlanC = 0;
      int doneC = 0;

      for (final f in status.values) {
        if (f.screening == _WorkState.draft) draftC++;

        final needPlan = (f.screening == _WorkState.done) &&
            (f.suggestion != _WorkState.done);
        if (needPlan) needPlanC++;

        if (f.screening == _WorkState.done) doneC++;
      }

      if (!mounted) return;
      setState(() {
        _countDraft = draftC;
        _countNeedPlan = needPlanC;
        _countDone = doneC;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // =========================
  // Actions
  // =========================

  Future<String?> _fetchLatestScreeningIdForStudent(String studId) async {
    final res = await http.post(
      Uri.parse(_checkScreeningUrl),
      body: {'stud_id': studId},
    );

    if (res.statusCode != 200) {
      throw Exception(
          'check_screening_data.php failed (HTTP ${res.statusCode})');
    }

    final decoded = json.decode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final row = decoded.first;
    if (row is! Map) return null;

    final screeningId =
        (row['screening_id'] ?? row['screeningId'] ?? row['id'] ?? '')
            .toString();
    if (screeningId.trim().isEmpty) return null;

    return screeningId;
  }

  static final String _screeningResultUrl =
      ApiConfig.flutter('screening_result.php');
  /*static const String _screeningResultUrl =
      'https://app-kizzu.test/growkids/flutter/screening_result.php';*/

  Future<Map<String, dynamic>> _fetchScreeningResult({
    required String studId,
    required String screeningId,
  }) async {
    final res = await http.post(
      Uri.parse(_screeningResultUrl),
      body: {
        'stud_id': studId,
        'screening_id': screeningId,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('screening_result.php failed (HTTP ${res.statusCode})');
    }

    final decoded = json.decode(res.body);

    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List && decoded.isNotEmpty) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }

    throw Exception('screening_result.php returned empty/unknown format');
  }

  Future<void> _openPicker(_PickerMode mode) async {
    if (widget.therapistId.trim().isEmpty) {
      _snack('Missing therapistId');
      return;
    }

    _DenverStudentPickerSheet picker() => _DenverStudentPickerSheet(
          therapistId: widget.therapistId,
          childrenUrl: _childrenUrl,
          bulkStatusUrl: _bulkStatusUrl,
          draftListUrl: _draftListUrl,
          checkScreeningUrl: _submitListUrl,
          mode: mode,
        );

    final _PickStudent? picked;
    if (_useDesktopDenverPageLayout(context)) {
      picked = await showDialog<_PickStudent>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => picker(),
      );
    } else {
      picked = await showModalBottomSheet<_PickStudent>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFFF6F7FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        builder: (_) => picker(),
      );
    }

    if (picked == null) return;
    if (!mounted) return;
    final selected = picked;

    switch (mode) {
      case _PickerMode.newScreening:
        final ageMonthsInt = int.tryParse(
                RegExp(r'(\d+)').firstMatch(selected.ageMonthsOnly)?.group(1) ??
                    '0') ??
            0;

        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => Screening(
              studentId: selected.studId,
              studentName: selected.name,
              age: selected.ageYearsOnly,
              ageInMonths: selected.ageMonthsOnly,
              ageInMonthsINT: ageMonthsInt,
            ),
          ),
        );
        if (changed == true) await _loadCounts();
        break;

      case _PickerMode.continueDraft:
        await _goToEditDraft(selected);
        break;

      case _PickerMode.needPlan:
        await _goToTherapistSuggestion(selected);
        break;

      case _PickerMode.history:
        await _goToHistoryResult(selected);
        break;
    }
  }

  Future<void> _goToHistoryResult(_PickStudent picked) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreeningResult(
          screeningDate: picked.screeningDateRaw,
          studentId: picked.studId,
          screeningId: picked.screeningId,
          age: picked.resultAge,
          studentName: picked.name,
          ageFineMotor: picked.ageFineMotor,
          ageGrossMotor: picked.ageGrossMotor,
          ageLanguage: picked.ageLanguage,
          agePersonal: picked.agePersonal,
          therapist_suggestion: picked.therapistSuggestion,
        ),
      ),
    );
  }

  Future<void> _goToTherapistSuggestion(_PickStudent picked) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final screeningId =
          await _fetchLatestScreeningIdForStudent(picked.studId);
      if (screeningId == null) {
        throw Exception('No screening found for this student.');
      }

      final data = await _fetchScreeningResult(
        studId: picked.studId,
        screeningId: screeningId,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      double d(dynamic v) => (v is num)
          ? v.toDouble()
          : double.tryParse((v ?? '').toString()) ?? 0.0;

      final ageFineMotor = d(data['ageFineMotor'] ?? data['age_fine_motor']);
      final ageGrossMotor = d(data['ageGrossMotor'] ?? data['age_gross_motor']);
      final ageLanguage = d(data['ageLanguage'] ?? data['age_language']);
      final agePersonal = d(data['agePersonal'] ?? data['age_personal']);

      final ageMonths = double.tryParse(picked.ageMonthsOnly) ?? 0.0;

      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TherapistSuggestion(
            studentId: picked.studId,
            screeningId: screeningId,
            studentName: picked.name,
            age: ageMonths,
            ageFineMotor: ageFineMotor,
            ageGrossMotor: ageGrossMotor,
            ageLanguage: ageLanguage,
            agePersonal: agePersonal,
          ),
        ),
      );
      if (changed == true) await _loadCounts();
    } catch (e) {
      if (!mounted) return;

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      _snack(e.toString());
    }
  }

  Future<void> _goToEditDraft(_PickStudent picked) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final screeningId =
          await _fetchLatestScreeningIdForStudent(picked.studId);
      if (screeningId == null) {
        throw Exception('No screening found for this student.');
      }

      final data = await _fetchScreeningResult(
        studId: picked.studId,
        screeningId: screeningId,
      );

      if (!mounted) return;

      // ✅ CLOSE LOADING DIALOG (important!)
      Navigator.of(context, rootNavigator: true).pop();

      double d(dynamic v) => (v is num)
          ? v.toDouble()
          : double.tryParse((v ?? '').toString()) ?? 0.0;

      final ageFineMotor = d(data['ageFineMotor'] ?? data['age_fine_motor']);
      final ageGrossMotor = d(data['ageGrossMotor'] ?? data['age_gross_motor']);
      final agePersonal = d(data['agePersonal'] ?? data['age_personal']);
      final ageLanguage = d(data['ageLanguage'] ?? data['age_language']);

      final therapistSuggestion =
          (data['therapist_suggestion'] ?? data['suggestion'] ?? '').toString();

      List<Map<String, dynamic>> failData = [];
      final rawFail =
          data['failData'] ?? data['fail_data'] ?? data['fail'] ?? [];
      if (rawFail is List) {
        failData =
            rawFail.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      // ✅ ageMonthsOnly sekarang dah numeric string (kau return '$months')
      final ageMonths = double.tryParse(picked.ageMonthsOnly) ?? 0.0;

      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => EditScreening(
            studentId: picked.studId,
            screeningId: screeningId,
            studentName: picked.name,
            age: ageMonths,
            ageFineMotor: ageFineMotor,
            ageGrossMotor: ageGrossMotor,
            agePersonal: agePersonal,
            ageLanguage: ageLanguage,
            therapist_suggestion: therapistSuggestion,
            failData: failData,
          ),
        ),
      );
      if (changed == true) await _loadCounts();
    } catch (e) {
      if (!mounted) return;

      // ✅ make sure dialog closed if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      _snack(e.toString());
    }
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    if (_useDesktopDenverPageLayout(context)) {
      return _buildDesktop();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Denver Screening'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadCounts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCounts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 14),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        _ErrorBanner(text: _error!),
                        const SizedBox(height: 10),
                      ],
                      _DenverHeader(),
                      SizedBox(height: 1.h),
                      _MiniOverviewStripPretty(
                        loading: _loading,
                        countDraft: _countDraft,
                        countNeedPlan: _countNeedPlan,
                        countDone: _countDone,
                      ),
                      SizedBox(height: 1.h),
                      _ResponsiveGrid(
                        forcedCount: 2,
                        minTileWidth: 12,
                        children: [
                          _ActionTileV2(
                            title: 'New Screening',
                            icon: Icons.playlist_add_check_rounded,
                            accent: const Color(0xFF3B82F6),
                            onTap: () => _openPicker(_PickerMode.newScreening),
                          ),
                          _ActionTileV2(
                            title: 'Continue Draft',
                            icon: Icons.edit_note_rounded,
                            accent: const Color(0xFFF59E0B),
                            onTap: () => _openPicker(_PickerMode.continueDraft),
                          ),
                          _ActionTileV2(
                            title: 'Suggestion / Plan',
                            icon: Icons.assignment_rounded,
                            accent: const Color(0xFF0AAE7A),
                            onTap: () => _openPicker(_PickerMode.needPlan),
                          ),
                          _ActionTileV2(
                            title: 'Screening History',
                            icon: Icons.history_rounded,
                            accent: const Color(0xFF8B5CF6),
                            onTap: () => _openPicker(_PickerMode.history),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: const Text(
          'Denver Screening',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh overview',
            onPressed: _loading ? null : _loadCounts,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  _desktopError(_error!),
                  const SizedBox(height: 16),
                ],
                _desktopHeader(),
                const SizedBox(height: 22),
                const Text(
                  'Screening workflow',
                  style: TextStyle(
                    color: Color(0xFF242735),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Select an action to start or continue a Denver assessment.',
                  style: TextStyle(color: Color(0xFF777C8B), fontSize: 13),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 16.0;
                    final width = (constraints.maxWidth - spacing) / 2;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: width,
                          child: _desktopActionCard(
                            title: 'New Screening',
                            description:
                                'Begin a new Denver screening for a student.',
                            icon: Icons.playlist_add_check_rounded,
                            color: const Color(0xFF3D7AF5),
                            badge: 'Start',
                            onTap: () => _openPicker(_PickerMode.newScreening),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _desktopActionCard(
                            title: 'Continue Draft',
                            description:
                                'Resume an assessment saved before submission.',
                            icon: Icons.edit_note_rounded,
                            color: const Color(0xFFF59E0B),
                            badge: _loading ? '—' : '$_countDraft draft',
                            onTap: () => _openPicker(_PickerMode.continueDraft),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _desktopActionCard(
                            title: 'Suggestion / Plan',
                            description:
                                'Complete therapist suggestions and intervention plans.',
                            icon: Icons.assignment_outlined,
                            color: const Color(0xFF12A47A),
                            badge: _loading ? '—' : '$_countNeedPlan pending',
                            onTap: () => _openPicker(_PickerMode.needPlan),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _desktopActionCard(
                            title: 'Screening History',
                            description:
                                'Review completed screenings and student results.',
                            icon: Icons.history_rounded,
                            color: const Color(0xFF8B5CF6),
                            badge: _loading ? '—' : '$_countDone completed',
                            onTap: () => _openPicker(_PickerMode.history),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x253F2A91),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: Growkids.purple,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEVELOPMENTAL ASSESSMENT',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Denver Screening',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage screenings, care plans, and completed results.',
                  style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
          _desktopMetric(
            'Draft',
            _countDraft,
            Icons.edit_note_rounded,
            const Color(0xFFFFCB6B),
          ),
          const SizedBox(width: 10),
          _desktopMetric(
            'Need Plan',
            _countNeedPlan,
            Icons.assignment_outlined,
            const Color(0xFF6EE7C1),
          ),
          const SizedBox(width: 10),
          _desktopMetric(
            'Done',
            _countDone,
            Icons.check_circle_outline_rounded,
            const Color(0xFFB8A9FF),
          ),
        ],
      ),
    );
  }

  Widget _desktopMetric(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Text(
                _loading ? '—' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _desktopActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E5ED)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0E1635),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF292C39),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF717685),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F2F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF858A99),
                      size: 17,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopError(String message) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =========================
  // Data (bulk status)
  // =========================

  Future<Map<String, _DenverFlags>> _fetchBulkStatusMap() async {
    final res = await http.post(
      Uri.parse(_bulkStatusUrl),
      body: {'staff_id': widget.therapistId},
    );

    if (res.statusCode != 200) {
      throw Exception('Bulk status failed (HTTP ${res.statusCode})');
    }

    final decoded = json.decode(res.body);
    if (decoded is! List) return {};

    _WorkState parse(dynamic v) {
      final s = (v ?? '').toString().toLowerCase();
      if (s == 'done' || s == 'submit' || s == 'submitted') {
        return _WorkState.done;
      }
      if (s == 'draft') return _WorkState.draft;
      return _WorkState.todo;
    }

    final map = <String, _DenverFlags>{};
    for (final row in decoded) {
      if (row is! Map) continue;

      final sid = (row['stud_id'] ?? row['student_id'] ?? '').toString();
      if (sid.isEmpty) continue;

      map[sid] = _DenverFlags(
        screening: parse(row['screening']),
        suggestion: parse(row['suggestion']),
      );
    }

    return map;
  }
}

// =========================
// Picker Sheet (generic by mode)
// =========================

enum _PickerMode { newScreening, continueDraft, needPlan, history }

class _DenverFlags {
  final _WorkState screening;
  final _WorkState suggestion;

  const _DenverFlags({
    required this.screening,
    required this.suggestion,
  });
}

class _PickStudent {
  final String studId;
  final String name;

  final String ageYearsOnly;
  final String ageMonthsOnly;
  final String agePretty;

  final String screeningId;
  final String screeningDate;
  final String screeningDateRaw;
  final DateTime? screeningDateObj;

  final double resultAge;
  final double ageFineMotor;
  final double ageGrossMotor;
  final double ageLanguage;
  final double agePersonal;
  final String therapistSuggestion;

  const _PickStudent({
    required this.studId,
    required this.name,
    required this.ageYearsOnly,
    required this.ageMonthsOnly,
    required this.agePretty,
    required this.screeningId,
    required this.screeningDate,
    required this.screeningDateRaw,
    required this.screeningDateObj,
    required this.resultAge,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.ageLanguage,
    required this.agePersonal,
    required this.therapistSuggestion,
  });
}

class _DenverStudentPickerSheet extends StatefulWidget {
  final String therapistId;
  final String childrenUrl;
  final String bulkStatusUrl;
  final String draftListUrl;
  final String checkScreeningUrl;
  final _PickerMode mode;

  const _DenverStudentPickerSheet({
    required this.therapistId,
    required this.childrenUrl,
    required this.bulkStatusUrl,
    required this.draftListUrl,
    required this.checkScreeningUrl,
    required this.mode,
  });

  @override
  State<_DenverStudentPickerSheet> createState() =>
      _DenverStudentPickerSheetState();
}

class _DenverStudentPickerSheetState extends State<_DenverStudentPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  List<_PickStudent> _all = [];
  List<_PickStudent> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.mode) {
      case _PickerMode.newScreening:
        return 'New Denver Screening';
      case _PickerMode.continueDraft:
        return 'Continue Draft';
      case _PickerMode.needPlan:
        return 'Suggestion / Plan';
      case _PickerMode.history:
        return 'Screening History';
    }
  }

  IconData get _heroIcon {
    switch (widget.mode) {
      case _PickerMode.newScreening:
        return Icons.playlist_add_check_rounded;
      case _PickerMode.continueDraft:
        return Icons.edit_note_rounded;
      case _PickerMode.needPlan:
        return Icons.assignment_rounded;
      case _PickerMode.history:
        return Icons.history_rounded;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.mode == _PickerMode.continueDraft) {
        final raw = await _fetchDraftStudentList();

        final list = <_PickStudent>[];
        for (final s in raw) {
          final sid = (s['stud_id'] ?? s['student_id'] ?? '').toString();
          if (sid.isEmpty) continue;

          final name =
              (s['stud_name'] ?? s['student'] ?? s['name'] ?? '-').toString();
          final dob = (s['stud_dob'] ?? s['dob'] ?? '').toString();
          final screeningDateRaw =
              (s['screening_date'] ?? s['created_at'] ?? s['date'] ?? '')
                  .toString();

          final parsedDate = _parseDate(screeningDateRaw);

          list.add(
            _PickStudent(
              studId: sid,
              name: name,
              ageYearsOnly: _ageYears(dob),
              ageMonthsOnly: _ageMonths(dob),
              agePretty: _agePretty(dob),
              screeningId: (s['screening_id'] ?? '').toString(),
              screeningDate: _formatDisplayDate(parsedDate),
              screeningDateRaw: screeningDateRaw,
              screeningDateObj: parsedDate,
              resultAge: 0.0,
              ageFineMotor: 0.0,
              ageGrossMotor: 0.0,
              ageLanguage: 0.0,
              agePersonal: 0.0,
              therapistSuggestion: '',
            ),
          );
        }

        list.sort((a, b) {
          final ad = a.screeningDateObj;
          final bd = b.screeningDateObj;

          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });

        if (!mounted) return;
        setState(() {
          _all = list;
          _filtered = List.from(list);
        });

        return;
      }

      if (widget.mode == _PickerMode.history) {
        final raw = await _fetchHistoryStudentList();

        final list = <_PickStudent>[];
        for (final s in raw) {
          final sid = (s['student_id'] ?? s['stud_id'] ?? '').toString();
          if (sid.isEmpty) continue;

          final screeningId = (s['screening_id'] ?? '').toString();
          if (screeningId.isEmpty) continue;

          final name =
              (s['stud_name'] ?? s['student'] ?? s['name'] ?? '-').toString();
          final screeningDateRaw = (s['screening_date'] ?? '').toString();
          final parsedDate = _parseDate(screeningDateRaw);

          final age = _toDouble(s['age']);
          final ageFineMotor = _toDouble(s['age_fine_motor']);
          final ageGrossMotor = _toDouble(s['age_gross_motor']);
          final ageLanguage = _toDouble(s['age_language']);
          final agePersonal =
              _toDouble(s['age_personal_social'] ?? s['age_personal']);
          final therapistSuggestion =
              (s['therapist_suggestion'] ?? '').toString();

          list.add(
            _PickStudent(
              studId: sid,
              name: name,
              ageYearsOnly: '',
              ageMonthsOnly: age.toString(),
              agePretty: _prettyAgeFromMonths(age),
              screeningId: screeningId,
              screeningDate: _formatDisplayDate(parsedDate),
              screeningDateRaw: screeningDateRaw,
              screeningDateObj: parsedDate,
              resultAge: age,
              ageFineMotor: ageFineMotor,
              ageGrossMotor: ageGrossMotor,
              ageLanguage: ageLanguage,
              agePersonal: agePersonal,
              therapistSuggestion: therapistSuggestion,
            ),
          );
        }

        list.sort((a, b) {
          final ad = a.screeningDateObj;
          final bd = b.screeningDateObj;

          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });

        if (!mounted) return;
        setState(() {
          _all = list;
          _filtered = List.from(list);
        });

        return;
      }

      final raw = await _fetchStudentList();
      final flags = await _fetchBulkFlags();

      bool eligible(String sid) {
        final f = flags[sid] ??
            const _DenverFlags(
              screening: _WorkState.todo,
              suggestion: _WorkState.todo,
            );

        switch (widget.mode) {
          case _PickerMode.newScreening:
            return f.screening == _WorkState.todo;
          case _PickerMode.continueDraft:
            return f.screening == _WorkState.draft;
          case _PickerMode.needPlan:
            return (f.screening == _WorkState.done) &&
                (f.suggestion != _WorkState.done);
          case _PickerMode.history:
            return false;
        }
      }

      final list = <_PickStudent>[];
      for (final s in raw) {
        final sid = (s['stud_id'] ?? s['student_id'] ?? '').toString();
        if (sid.isEmpty) continue;
        if (!eligible(sid)) continue;

        final name =
            (s['stud_name'] ?? s['student'] ?? s['name'] ?? '-').toString();
        final dob = (s['stud_dob'] ?? s['dob'] ?? '').toString();

        list.add(
          _PickStudent(
            studId: sid,
            name: name,
            ageYearsOnly: _ageYears(dob),
            ageMonthsOnly: _ageMonths(dob),
            agePretty: _agePretty(dob),
            screeningId: '',
            screeningDate: '',
            screeningDateRaw: '',
            screeningDateObj: null,
            resultAge: 0.0,
            ageFineMotor: 0.0,
            ageGrossMotor: 0.0,
            ageLanguage: 0.0,
            agePersonal: 0.0,
            therapistSuggestion: '',
          ),
        );
      }

      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = List.from(list);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentList() async {
    final res = await http.post(
      Uri.parse(widget.childrenUrl),
      body: {'therapist_id': widget.therapistId},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load students (HTTP ${res.statusCode})');
    }

    final decoded = json.decode(res.body);
    if (decoded is! List) return [];
    return List<Map<String, dynamic>>.from(decoded);
  }

  Future<Map<String, _DenverFlags>> _fetchBulkFlags() async {
    final res = await http.post(
      Uri.parse(widget.bulkStatusUrl),
      body: {'staff_id': widget.therapistId},
    );

    if (res.statusCode != 200) return {};

    final decoded = json.decode(res.body);
    if (decoded is! List) return {};

    _WorkState parse(dynamic v) {
      final s = (v ?? '').toString().toLowerCase();
      if (s == 'done' || s == 'submit' || s == 'submitted') {
        return _WorkState.done;
      }
      if (s == 'draft') return _WorkState.draft;
      return _WorkState.todo;
    }

    final map = <String, _DenverFlags>{};
    for (final row in decoded) {
      if (row is! Map) continue;
      final sid = (row['stud_id'] ?? row['student_id'] ?? '').toString();
      if (sid.isEmpty) continue;

      map[sid] = _DenverFlags(
        screening: parse(row['screening']),
        suggestion: parse(row['suggestion']),
      );
    }

    return map;
  }

  Future<List<Map<String, dynamic>>> _fetchDraftStudentList() async {
    final res = await http.post(
      Uri.parse(widget.draftListUrl),
      body: {'therapist_id': widget.therapistId},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load draft students (HTTP ${res.statusCode})');
    }

    final decoded = json.decode(res.body);
    if (decoded is! List) return [];
    return List<Map<String, dynamic>>.from(decoded);
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;

    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return '-';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _prettyAgeFromMonths(double monthsValue) {
    final totalMonths = monthsValue.round();
    if (totalMonths < 0) return '-';

    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;

    return '$years yrs $months mo';
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = List.from(_all));
      return;
    }

    setState(() {
      _filtered =
          _all.where((s) => s.name.toLowerCase().contains(query)).toList();
    });
  }

  // ===== age helpers =====
  static String _ageYears(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        years--;
      }
      if (years < 0) years = 0;
      return '$years yrs';
    } catch (_) {
      return '-';
    }
  }

  static String _ageMonths(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int months = (now.year - dob.year) * 12 + (now.month - dob.month);
      if (now.day < dob.day) months--;
      if (months < 0) months = 0;
      return '$months';
    } catch (_) {
      return '-';
    }
  }

  static String _agePretty(String dobString) {
    if (dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int totalMonths = (now.year - dob.year) * 12 + (now.month - dob.month);
      if (now.day < dob.day) totalMonths--;
      if (totalMonths < 0) totalMonths = 0;

      final years = totalMonths ~/ 12;
      final months = totalMonths % 12;
      return '$years yrs $months mo';
    } catch (_) {
      return '-';
    }
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> _fetchHistoryStudentList() async {
    final res = await http.post(
      Uri.parse(widget.checkScreeningUrl),
      body: {'therapist_id': widget.therapistId},
    );

    if (res.statusCode != 200) {
      throw Exception(
          'Failed to load screening history (HTTP ${res.statusCode})');
    }

    final decoded = json.decode(res.body);
    if (decoded is! List) return [];
    return List<Map<String, dynamic>>.from(decoded);
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopDenverPageLayout(context)) {
      return _buildDesktopPicker();
    }

    final h = MediaQuery.of(context).size.height;

    return SizedBox(
      height: h * 0.88,
      child: Column(
        children: [
          // HERO
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Growkids.purpleFlo,
                  Growkids.purpleFlo.withValues(alpha: .70)
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 2.h,
                  backgroundColor: Colors.white,
                  child: Icon(
                    _heroIcon,
                    color: Growkids.purpleFlo,
                    size: 2.h,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: TextStyle(fontSize: 14.sp, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // BODY
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (_error != null) ...[
                    _ErrorBanner(text: _error!),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Growkids.purpleFlo.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : (_filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No students found.',
                                  style: TextStyle(
                                      fontSize: 12.sp,
                                      color:
                                          Colors.black.withValues(alpha: 0.6)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final s = _filtered[i];
                                  return InkWell(
                                    onTap: () => Navigator.pop(context, s),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: EdgeInsets.all(1.5.h),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.black
                                                .withValues(alpha: 0.06)),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 2.h,
                                            backgroundColor: Growkids.purple
                                                .withValues(alpha: 0.12),
                                            child: Text(
                                              s.name.isNotEmpty
                                                  ? s.name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Growkids.purple),
                                            ),
                                          ),
                                          SizedBox(width: 2.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 14.sp),
                                                ),
                                                Text(
                                                  s.agePretty,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                if ((widget.mode ==
                                                            _PickerMode
                                                                .continueDraft ||
                                                        widget.mode ==
                                                            _PickerMode
                                                                .history) &&
                                                    s.screeningDate.isNotEmpty)
                                                  Text(
                                                    widget.mode ==
                                                            _PickerMode.history
                                                        ? 'Screening date: ${s.screeningDate}'
                                                        : 'Draft date: ${s.screeningDate}',
                                                    style: TextStyle(
                                                      fontSize: 11.5.sp,
                                                      color: Growkids.purpleFlo,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right_rounded,
                                              color: Colors.black
                                                  .withValues(alpha: 0.35)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPicker() {
    final accent = switch (widget.mode) {
      _PickerMode.newScreening => const Color(0xFF3D7AF5),
      _PickerMode.continueDraft => const Color(0xFFF59E0B),
      _PickerMode.needPlan => const Color(0xFF12A47A),
      _PickerMode.history => const Color(0xFF8B5CF6),
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D0E1635),
                blurRadius: 38,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 82,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Growkids.purpleFlo,
                      Growkids.purpleFlo.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(_heroIcon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _desktopPickerSubtitle(),
                            style: const TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _filter,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search student...',
                          hintStyle: const TextStyle(color: Color(0xFF9A9EAA)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF858A99),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E5ED)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E5ED)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: Growkids.purpleFlo,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        _loading
                            ? 'Loading...'
                            : '${_filtered.length} student${_filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _desktopPickerError(_error!),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Growkids.purpleFlo,
                        ),
                      )
                    : _filtered.isEmpty
                        ? _desktopPickerEmpty()
                        : Scrollbar(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 9),
                              itemBuilder: (context, index) =>
                                  _desktopStudentTile(
                                _filtered[index],
                                accent,
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _desktopPickerSubtitle() {
    return switch (widget.mode) {
      _PickerMode.newScreening => 'Choose a student to begin a new assessment.',
      _PickerMode.continueDraft =>
        'Choose a student with an unfinished screening.',
      _PickerMode.needPlan =>
        'Choose a student who requires a suggestion or plan.',
      _PickerMode.history =>
        'Choose a student to review a completed screening.',
    };
  }

  Widget _desktopStudentTile(_PickStudent student, Color accent) {
    final showDate = (widget.mode == _PickerMode.continueDraft ||
            widget.mode == _PickerMode.history) &&
        student.screeningDate.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.pop(context, student),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE2E5ED)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  student.name.isEmpty
                      ? '?'
                      : student.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF292C39),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      children: [
                        _desktopStudentMeta(
                          Icons.cake_outlined,
                          student.agePretty,
                        ),
                        if (showDate)
                          _desktopStudentMeta(
                            Icons.calendar_today_outlined,
                            widget.mode == _PickerMode.history
                                ? 'Screened ${student.screeningDate}'
                                : 'Draft ${student.screeningDate}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: Color(0xFF858A99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopStudentMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF858A99)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF717685),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _desktopPickerError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopPickerEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 48,
            color: Color(0xFFC6C9D2),
          ),
          SizedBox(height: 12),
          Text(
            'No students found.',
            style: TextStyle(
              color: Color(0xFF777C8B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// UI atoms (HomeV3-inspired)
// =========================

class _DenverHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .70)
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 3.h,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.assignment_turned_in_rounded,
              color: Growkids.purpleFlo,
              size: 3.h,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Denver Screening',
                    style: TextStyle(fontSize: 16.sp, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniOverviewStripPretty extends StatelessWidget {
  final bool loading;
  final int countDraft;
  final int countNeedPlan;
  final int countDone;

  const _MiniOverviewStripPretty({
    required this.loading,
    required this.countDraft,
    required this.countNeedPlan,
    required this.countDone,
  });

  @override
  Widget build(BuildContext context) {
    String v(int x) => loading ? '—' : x.toString();

    return Row(
      children: [
        _MiniStatCard(
            label: 'Draft',
            value: v(countDraft),
            color: const Color(0xFFF59E0B),
            icon: Icons.edit_note_rounded),
        const SizedBox(width: 10),
        _MiniStatCard(
            label: 'Need Plan',
            value: v(countNeedPlan),
            color: const Color(0xFF0AAE7A),
            icon: Icons.assignment_rounded),
        const SizedBox(width: 10),
        _MiniStatCard(
            label: 'Done',
            value: v(countDone),
            color: Growkids.purpleFlo,
            icon: Icons.check_circle_rounded),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              height: 5.h,
              width: 5.h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 3.h),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.black.withValues(alpha: 0.85))),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black.withValues(alpha: .6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final double minTileWidth;
  final List<Widget> children;
  final int? forcedCount;

  const _ResponsiveGrid({
    required this.minTileWidth,
    required this.children,
    this.forcedCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final autoCount = (w / minTileWidth).floor().clamp(1, 4);
      final count = forcedCount != null ? forcedCount!.clamp(1, 4) : autoCount;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: count,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3,
        children: children,
      );
    });
  }
}

class _ActionTileV2 extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final String? badgeText;

  const _ActionTileV2({
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
  }) : badgeText = null;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(1.5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 5.h,
              width: 7.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 3.h),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontSize: 14.sp),
              ),
            ),
            if (badgeText != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.black.withValues(alpha: 0.75)),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: Colors.black.withValues(alpha: 0.35), size: 3.h),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.red.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12.sp, color: Colors.black.withValues(alpha: 0.75)),
            ),
          ),
        ],
      ),
    );
  }
}
