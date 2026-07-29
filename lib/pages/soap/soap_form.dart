import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:intl/intl.dart';

import 'soap_hub.dart';

bool _useDesktopSoapFormLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class SOAPFormPage extends StatefulWidget {
  final String therapistId;
  final String studId;
  final String studentName;
  final String? existingReportId;

  const SOAPFormPage({
    super.key,
    required this.therapistId,
    required this.studId,
    required this.studentName,
    this.existingReportId,
  });

  @override
  State<SOAPFormPage> createState() => _SOAPFormPageState();
}

class _SOAPFormPageState extends State<SOAPFormPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _currentReportId;

  // --- NEW: Track selected category for the 'O' Tab ---
  String _selectedOCategory = "Sensory Function";

  // --- CONTROLLERS: HEADER ---
  DateTime _sessionDate = DateTime.now();
  final TextEditingController _timeCtrl = TextEditingController();
  final TextEditingController _sessionNumCtrl = TextEditingController();

  // --- CONTROLLERS: S & A ---
  final TextEditingController _sCaregiverCtrl = TextEditingController();
  final TextEditingController _sAppearanceCtrl = TextEditingController();
  final TextEditingController _sLatenessCtrl = TextEditingController();
  final TextEditingController _aAnalysisCtrl = TextEditingController();
  final TextEditingController _aStgCtrl = TextEditingController();
  final TextEditingController _aLtgCtrl = TextEditingController();
  final TextEditingController _pTcaCtrl = TextEditingController();
  final TextEditingController _pTxCustomCtrl = TextEditingController();

  // --- DATA MAPS: O & P (Stored as JSON) ---
  Map<String, dynamic> _oData = {};
  List<String> _pTxGiven = [];

  final String _getReportApi = ApiConfig.flutter('soap_get_latest_report.php');

  final String _saveApi = ApiConfig.flutter('soap_save_report.php');

  /*final String _getReportApi =
      "http://app-kizzu.test/growkids/flutter/soap_get_latest_report.php";

  final String _saveApi =
      "http://app-kizzu.test/growkids/flutter/soap_save_report.php";*/

  final List<String> _txOptions = [
    "Preparatory activity",
    "Circle time / social skill training",
    "Sensory-based activity / sensory diet / circuit / gross motor training",
    "Floor activity / table task activity / fine motor activity",
    "Cognitive training",
    "Education activity / school readiness activity",
    "Pre-writing / writing training",
    "ADL Training / environment modification / adaptation",
    "Behavior modification",
    "Parental coaching / home-based program / advocate"
  ];

  final bool _skipAutosaveOnPop = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _currentReportId = widget.existingReportId;

    _initODataStructure();

    if (_currentReportId != null) {
      _loadExistingReport(_currentReportId!);
    } else {
      _loadPrefillData();
    }
  }

  void _handleTabChange() {
    if (mounted && !_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _timeCtrl.dispose();
    _sessionNumCtrl.dispose();
    _sCaregiverCtrl.dispose();
    _sAppearanceCtrl.dispose();
    _sLatenessCtrl.dispose();
    _aAnalysisCtrl.dispose();
    _aStgCtrl.dispose();
    _aLtgCtrl.dispose();
    _pTcaCtrl.dispose();
    _pTxCustomCtrl.dispose();
    super.dispose();
  }

  void _initODataStructure() {
    _oData = {
      "Sensory Function": {
        "Auditory": "",
        "Tactile": "",
        "Vestibular": "",
        "Proprioception": "",
        "Visual": "",
        "Olfactory": "",
        "Oral": "",
        "Gustatory": "",
        "Interoception": ""
      },
      "Reflex Function": {"Postural reflex": "", "Primitive reflex": ""},
      "Behavior & Emotional": {
        "Self-stimulatory": "",
        "Behavior (purpose)": "",
        "Emotional expression": "",
        "Aggressiveness / Passive": "",
        "Frustration tolerance": "",
        "Emotional regulation": "",
        "Self-regulate / co-regulate": ""
      },
      "Cognitive Function": {
        "Arousal / alertness": "",
        "Awareness": "",
        "Task participation": "",
        "Attention Span": "",
        "Listening skills / auditory attention": "",
        "Understand and following instruction": "",
        "Basic Concept": ""
      },
      "Social Skills / Preverbal": {
        "Eye contact (People/Object)": "",
        "Sitting tolerance": "",
        "Joint attention": "",
        "Waiting skill": "",
        "Imitation (Action/Verbal)": "",
        "Taking turn": "",
        "Sharing": ""
      },
      "Communication & Interaction": {
        "Greeting (Bye2, Shake hands, Hi-5)": "",
        "Initiate conversation": "",
        "Requesting": "",
        "Comment": "",
        "Ask permission": "",
        "Explain / Storytelling": ""
      },
      "Motor Skills & Praxis": {
        "Gross Motor (GM)": "",
        "Fine Motor (FM)": "",
        "Pre-writing / Handwriting": ""
      },
      "ADL": {
        "Toileting": "",
        "Dressing (donning/doffing)": "",
        "Personal hygiene": "",
        "Brush teeth": ""
      },
      "Play Skills": {"Types of play": "", "Social stages of play": ""},
      "School / Grouping": {
        "Classroom routine": "",
        "Initiate": "",
        "Participate": "",
        "Maintain": "",
        "Terminate": ""
      },
    };
  }

  Future<void> _loadPrefillData() async {
    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse(_getReportApi),
        body: {'stud_id': widget.studId},
      );

      if (res.statusCode != 200) {
        setState(() => _isLoading = false);
        return;
      }

      final json = jsonDecode(res.body);
      if (json['status'] != 'success') {
        setState(() => _isLoading = false);
        return;
      }

      final data = json['data'] as Map<String, dynamic>;

      _sCaregiverCtrl.text = (data['s_caregiver_concern'] ?? '').toString();
      _sAppearanceCtrl.text = (data['s_child_appearance'] ?? '').toString();
      _sLatenessCtrl.text = (data['s_lateness'] ?? '').toString();

      final o = data['o_data'];
      if (o is Map<String, dynamic>) {
        _oData = o;
      } else {
        try {
          _oData = jsonDecode(o.toString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      _aAnalysisCtrl.text = (data['a_analysis'] ?? '').toString();
      _aStgCtrl.text = (data['a_stg'] ?? '').toString();
      _aLtgCtrl.text = (data['a_ltg'] ?? '').toString();

      final p = data['p_data'];
      Map<String, dynamic> pMap = {};
      if (p is Map<String, dynamic>) {
        pMap = p;
      } else {
        try {
          pMap = jsonDecode(p.toString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      final tx = pMap['tx_given'];
      if (tx is List) {
        _pTxGiven = tx.map((e) => e.toString()).toList();
      } else {
        _pTxGiven = [];
      }
      _pTcaCtrl.text = (pMap['tca_plan'] ?? '').toString();
      _pTxCustomCtrl.text =
          (pMap['tx_custom'] ?? '').toString(); // <-- ADD THIS

      final lastSessionStr = (data['session_num'] ?? '').toString();
      int? lastSession = int.tryParse(lastSessionStr);
      if (lastSession != null) {
        _sessionNumCtrl.text = (lastSession + 1).toString();
      } else {
        _sessionNumCtrl.text = '';
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form pre-filled with data from previous session.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExistingReport(String reportId) async {
    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse(_getReportApi),
        body: {
          'report_id': reportId,
          'therapist_id': widget.therapistId,
        },
      );

      if (res.statusCode != 200) {
        setState(() => _isLoading = false);
        return;
      }

      final json = jsonDecode(res.body);
      if (json['status'] != 'success') {
        setState(() => _isLoading = false);
        return;
      }

      final data = json['data'] as Map<String, dynamic>;

      final dateStr = (data['session_date'] ?? '').toString();
      if (dateStr.isNotEmpty) {
        _sessionDate = DateTime.tryParse(dateStr) ?? _sessionDate;
      }
      _timeCtrl.text = (data['session_time'] ?? '').toString();
      _sessionNumCtrl.text = (data['session_num'] ?? '').toString();

      _sCaregiverCtrl.text = (data['s_caregiver_concern'] ?? '').toString();
      _sAppearanceCtrl.text = (data['s_child_appearance'] ?? '').toString();
      _sLatenessCtrl.text = (data['s_lateness'] ?? '').toString();

      final o = data['o_data'];
      if (o is Map<String, dynamic>) {
        _oData = o;
      } else {
        try {
          _oData = jsonDecode(o.toString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      _aAnalysisCtrl.text = (data['a_analysis'] ?? '').toString();
      _aStgCtrl.text = (data['a_stg'] ?? '').toString();
      _aLtgCtrl.text = (data['a_ltg'] ?? '').toString();

      final p = data['p_data'];
      Map<String, dynamic> pMap = {};
      if (p is Map<String, dynamic>) {
        pMap = p;
      } else {
        try {
          pMap = jsonDecode(p.toString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      final tx = pMap['tx_given'];
      if (tx is List) {
        _pTxGiven = tx.map((e) => e.toString()).toList();
      } else {
        _pTxGiven = [];
      }
      _pTcaCtrl.text = (pMap['tca_plan'] ?? '').toString();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _saveData(String status) async {
    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> pDataMap = {
        "tx_given": _pTxGiven,
        "tx_custom": _pTxCustomCtrl.text,
        "tca_plan": _pTcaCtrl.text,
      };

      final payload = {
        'report_id': _currentReportId,
        'stud_id': widget.studId,
        'therapist_id': widget.therapistId,
        'session_date': DateFormat('yyyy-MM-dd').format(_sessionDate),
        'session_time': _timeCtrl.text,
        'session_num': _sessionNumCtrl.text,
        's_caregiver_concern': _sCaregiverCtrl.text,
        's_child_appearance': _sAppearanceCtrl.text,
        's_lateness': _sLatenessCtrl.text,
        'o_data': jsonEncode(_oData),
        'p_data': jsonEncode(pDataMap),
        'a_analysis': _aAnalysisCtrl.text,
        'a_stg': _aStgCtrl.text,
        'a_ltg': _aLtgCtrl.text,
        'status': status,
      };

      final res = await http.post(Uri.parse(_saveApi),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          _currentReportId = json['report_id'].toString();
          return true;
        }
      }
    } catch (e) {
      print("Save Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    return false;
  }

  void _openQuickPeekDialog() async {
    bool keepSelecting = true;

    while (keepSelecting) {
      final selectedStudent = await showDialog(
        context: context,
        builder: (context) =>
            StudentSelectionDialog(therapistId: widget.therapistId),
      );

      if (selectedStudent != null) {
        String sId =
            (selectedStudent['stud_id'] ?? selectedStudent['id']).toString();
        String sName = selectedStudent['stud_name'] ??
            selectedStudent['student_name'] ??
            selectedStudent['name'] ??
            'Unknown';

        await showDialog(
          context: context,
          builder: (context) =>
              QuickPeekViewer(studId: sId, studentName: sName),
        );
      } else {
        keepSelecting = false;
      }
    }
  }

  bool _hasAnyContent() {
    if (_timeCtrl.text.trim().isNotEmpty) return true;
    if (_sessionNumCtrl.text.trim().isNotEmpty) return true;
    if (_sCaregiverCtrl.text.trim().isNotEmpty) return true;
    if (_sAppearanceCtrl.text.trim().isNotEmpty) return true;
    if (_sLatenessCtrl.text.trim().isNotEmpty) return true;
    if (_aAnalysisCtrl.text.trim().isNotEmpty) return true;
    if (_aStgCtrl.text.trim().isNotEmpty) return true;
    if (_aLtgCtrl.text.trim().isNotEmpty) return true;
    if (_pTcaCtrl.text.trim().isNotEmpty) return true;
    if (_pTxCustomCtrl.text.trim().isNotEmpty) return true;
    if (_pTxGiven.isNotEmpty) return true;

    for (final cat in _oData.values) {
      if (cat is Map) {
        for (final v in cat.values) {
          if (v != null && v.toString().trim().isNotEmpty) return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Jika tiada kandungan, terus keluar tanpa amaran
        if (_currentReportId == null && !_hasAnyContent()) {
          if (mounted) Navigator.pop(context);
          return;
        }

        if (_skipAutosaveOnPop) {
          if (mounted) Navigator.pop(context);
          return;
        }

        // Tunjukkan dialog pilihan
        final userChoice = await _showUnsavedChangesDialog();

        // Tindakan berdasarkan pilihan pengguna
        if (userChoice == 'discard') {
          if (mounted) Navigator.pop(context);
        } else if (userChoice == 'save') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Saving draft...")),
          );
          await _saveData('draft');
          if (mounted) Navigator.pop(context);
        }
        // Jika 'cancel' atau pengguna tekan luar kotak, dialog tertutup dan kekal di paparan form
      },
      child: _useDesktopSoapFormLayout(context)
          ? _buildDesktopPage()
          : Scaffold(
              backgroundColor: const Color(0xFFF6F7FB),
              appBar: AppBar(
                title: Text("SOAP: ${widget.studentName}",
                    style: const TextStyle(color: Colors.white)),
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white,
                elevation: 0,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: "S"),
                    Tab(text: "O"),
                    Tab(text: "A"),
                    Tab(text: "P"),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.manage_search_rounded,
                        color: Colors.white),
                    tooltip: 'Quick Peek Next Student',
                    onPressed: _openQuickPeekDialog,
                  ),
                ],
              ),
              body: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Growkids.purpleFlo))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabSubjective(),
                        _buildTabObjective(),
                        _buildTabAnalysis(),
                        _buildTabPlan(),
                      ],
                    ),
            ),
    );
  }

  Future<String?> _showUnsavedChangesDialog() {
    if (!_useDesktopSoapFormLayout(context)) {
      return showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Unsaved Changes"),
          content: const Text(
            "You have unsaved progress. What would you like to do?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text("Keep Editing"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text(
                "Discard",
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
              ),
              child: const Text(
                "Save Draft",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2DA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFFC47708),
                  size: 28,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Unsaved changes',
                style: TextStyle(
                  color: Color(0xFF292B35),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'You have unsaved SOAP progress. Save it as a draft before leaving?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF747987),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'discard'),
                    child: const Text(
                      'Discard',
                      style: TextStyle(color: Color(0xFFDC3545)),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: const Text('Keep editing'),
                  ),
                  const SizedBox(width: 9),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'save'),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save draft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Growkids.purpleFlo,
                      foregroundColor: Colors.white,
                      elevation: 0,
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

  Widget _buildDesktopPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: Text(
          _currentReportId == null ? 'New SOAP Report' : 'Edit SOAP Report',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Quick Peek',
            onPressed: _openQuickPeekDialog,
            icon: const Icon(Icons.manage_search_rounded),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 25, 28, 28),
                  child: Column(
                    children: [
                      _desktopStudentHeader(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 270, child: _desktopStepPanel()),
                            const SizedBox(width: 18),
                            Expanded(child: _desktopActiveForm()),
                            const SizedBox(width: 18),
                            SizedBox(width: 280, child: _desktopActionPanel()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopStudentHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.77),
          ],
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
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
                Text(
                  _currentReportId == null
                      ? 'NEW SOAP SESSION'
                      : 'EDIT SOAP SESSION',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
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
                  'Student ID ${widget.studId}  •  Session ${_sessionNumCtrl.text.isEmpty ? '—' : _sessionNumCtrl.text}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          _desktopHeaderMetric(
            Icons.calendar_today_outlined,
            DateFormat('d MMM yyyy').format(_sessionDate),
            'Session date',
          ),
          const SizedBox(width: 11),
          _desktopHeaderMetric(
            Icons.description_outlined,
            _currentReportId == null ? 'New' : '#$_currentReportId',
            'Report',
          ),
        ],
      ),
    );
  }

  Widget _desktopHeaderMetric(IconData icon, String value, String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopStepPanel() {
    const labels = ['Subjective', 'Objective', 'Assessment', 'Plan'];
    const letters = ['S', 'O', 'A', 'P'];
    const descriptions = [
      'Session details and concerns',
      'Observed functional performance',
      'Analysis and therapy goals',
      'Treatment and next plan',
    ];

    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SOAP sections',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Complete each section of the report.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 10),
          ),
          const SizedBox(height: 18),
          ...List.generate(4, (index) {
            final selected = _tabController.index == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () {
                  _tabController.animateTo(index);
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? Growkids.purpleFlo.withValues(alpha: 0.10)
                        : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected
                          ? Growkids.purpleFlo.withValues(alpha: 0.45)
                          : const Color(0xFFE4E6ED),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? Growkids.purpleFlo
                              : Growkids.purpleFlo.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          letters[index],
                          style: TextStyle(
                            color: selected ? Colors.white : Growkids.purpleFlo,
                            fontSize: 15,
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
                              labels[index],
                              style: const TextStyle(
                                color: Color(0xFF343640),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              descriptions[index],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9296A2),
                                fontSize: 8,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (_tabController.index + 1) / 4,
              minHeight: 7,
              backgroundColor: const Color(0xFFE8EAF0),
              color: Growkids.purpleFlo,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Section ${_tabController.index + 1} of 4',
            style: const TextStyle(
              color: Color(0xFF858A98),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopActiveForm() {
    return _desktopSurface(
      padding: EdgeInsets.zero,
      child: IndexedStack(
        index: _tabController.index,
        children: [
          _desktopSubjectiveForm(),
          _desktopObjectiveForm(),
          _desktopAssessmentForm(),
          _desktopPlanForm(),
        ],
      ),
    );
  }

  Widget _desktopFormShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 19, 22, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF242631),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF777C8D),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  ['S', 'O', 'A', 'P'][_tabController.index],
                  style: const TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8EAF0)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _desktopSubjectiveForm() {
    return _desktopFormShell(
      title: 'Subjective',
      subtitle: 'Session details, caregiver concerns and child presentation.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopSectionLabel('Session details'),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDesktopSessionDate,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFE0E3EA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Growkids.purpleFlo,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEEE, d MMM yyyy').format(_sessionDate),
                          style: const TextStyle(
                            color: Color(0xFF484B57),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _desktopTextField(
                  'Time (e.g. 10 AM)',
                  _timeCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _desktopTextField(
                  'Session number',
                  _sessionNumCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _desktopSectionLabel('Subjective notes'),
          _desktopTextField(
            'Caregiver complaint or concern',
            _sCaregiverCtrl,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _desktopTextField(
            "Child's appearance and mood",
            _sAppearanceCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _desktopTextField(
            'Late attendance (minutes)',
            _sLatenessCtrl,
          ),
        ],
      ),
    );
  }

  Widget _desktopObjectiveForm() {
    final categories = _oData.keys.toList();
    final fields =
        (_oData[_selectedOCategory] as Map?)?.keys.toList() ?? <dynamic>[];
    return _desktopFormShell(
      title: 'Objective',
      subtitle: 'Record observed performance across functional categories.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Column(
              children: categories.map((category) {
                final selected = category == _selectedOCategory;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedOCategory = category),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Growkids.purpleFlo
                            : const Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? Growkids.purpleFlo
                              : const Color(0xFFE2E4EB),
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : const Color(0xFF555966),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _desktopSectionLabel(_selectedOCategory),
                ...fields.map((field) {
                  final fieldName = field.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: TextFormField(
                      key: ValueKey('desktop-$_selectedOCategory-$fieldName'),
                      initialValue:
                          _oData[_selectedOCategory][fieldName]?.toString(),
                      onChanged: (value) =>
                          _oData[_selectedOCategory][fieldName] = value,
                      style: const TextStyle(fontSize: 11),
                      decoration: _desktopInputDecoration(fieldName),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopAssessmentForm() {
    return _desktopFormShell(
      title: 'Assessment',
      subtitle: 'Summarise clinical analysis and define therapy goals.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopSectionLabel('Clinical analysis / improvement'),
          _desktopTextField(
            'Write your overall analysis here...',
            _aAnalysisCtrl,
            maxLines: 7,
          ),
          const SizedBox(height: 18),
          _desktopSectionLabel('Goals'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _desktopTextField(
                  'STG (Short Term Goal)',
                  _aStgCtrl,
                  maxLines: 5,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _desktopTextField(
                  'LTG (Long Term Goal)',
                  _aLtgCtrl,
                  maxLines: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopPlanForm() {
    return _desktopFormShell(
      title: 'Plan',
      subtitle: 'Select treatment delivered and document the next plan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopSectionLabel('Treatment given'),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _txOptions.map((option) {
              final selected = _pTxGiven.contains(option);
              return FilterChip(
                selected: selected,
                showCheckmark: true,
                selectedColor: Growkids.purpleFlo.withValues(alpha: 0.14),
                checkmarkColor: Growkids.purpleFlo,
                side: BorderSide(
                  color: selected
                      ? Growkids.purpleFlo.withValues(alpha: 0.50)
                      : const Color(0xFFDDE0E7),
                ),
                label: Text(
                  option,
                  style: TextStyle(
                    color:
                        selected ? Growkids.purpleFlo : const Color(0xFF555966),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onSelected: (value) {
                  setState(() {
                    value ? _pTxGiven.add(option) : _pTxGiven.remove(option);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _desktopTextField(
            'Other / Custom Treatment',
            _pTxCustomCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          _desktopSectionLabel('TCA Plan'),
          _desktopTextField(
            'To come again plan...',
            _pTcaCtrl,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _desktopActionPanel() {
    const labels = ['Subjective', 'Objective', 'Assessment', 'Plan'];
    return Column(
      children: [
        Expanded(
          child: _desktopSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report actions',
                  style: TextStyle(
                    color: Color(0xFF242631),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Save progress or finalise the report.',
                  style: TextStyle(color: Color(0xFF777C8D), fontSize: 10),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E6ED)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Growkids.purpleFlo.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          ['S', 'O', 'A', 'P'][_tabController.index],
                          style: const TextStyle(
                            color: Growkids.purpleFlo,
                            fontSize: 15,
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
                              labels[_tabController.index],
                              style: const TextStyle(
                                color: Color(0xFF444752),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_tabController.index + 1} of 4',
                              style: const TextStyle(
                                color: Color(0xFF9296A2),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _desktopActionHint(
                  Icons.save_outlined,
                  'Save Draft',
                  'Keep the report editable.',
                  const Color(0xFFC47708),
                ),
                const SizedBox(height: 9),
                _desktopActionHint(
                  Icons.task_alt_rounded,
                  'Submit Final',
                  'Finalise the completed SOAP report.',
                  const Color(0xFF15945D),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _openQuickPeekDialog,
                  icon: const Icon(Icons.manage_search_rounded, size: 18),
                  label: const Text('Quick Peek'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    foregroundColor: Growkids.purpleFlo,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _saveData('draft'),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Growkids.purpleFlo,
              side: const BorderSide(color: Growkids.purpleFlo),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ),
        if (_tabController.index == 3) ...[
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submitDesktopFinal,
              icon: const Icon(Icons.task_alt_rounded, size: 18),
              label: const Text('Submit Final Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _desktopActionHint(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF4A4E5B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9296A2),
                  fontSize: 8,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDesktopSessionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _sessionDate = picked);
  }

  Future<void> _submitDesktopFinal() async {
    final success = await _saveData('final');
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report finalized successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _desktopTextField(
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 11, height: 1.4),
      decoration: _desktopInputDecoration(hint),
    );
  }

  InputDecoration _desktopInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9A9EAA), fontSize: 10),
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Growkids.purpleFlo, width: 1.4),
      ),
    );
  }

  Widget _desktopSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF555966),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _desktopSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(19),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // =========================================================================
  // TAB S: SUBJECTIVE
  // =========================================================================
  Widget _buildTabSubjective() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Session Details"),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _sessionDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (picked != null) setState(() => _sessionDate = picked);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 1.5.h, vertical: 1.5.h),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!)),
                    child: Row(children: [
                      Icon(Icons.calendar_month,
                          color: Colors.grey[400], size: 16.sp),
                      SizedBox(width: 2.w),
                      Text(DateFormat('dd MMM yyyy').format(_sessionDate),
                          style: TextStyle(fontSize: 12.sp))
                    ]),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(child: _customTextField("Time (e.g. 10 AM)", _timeCtrl)),
            ],
          ),
          _customTextField("Session Number (e.g. Session 5)", _sessionNumCtrl),
          SizedBox(height: 2.h),
          _sectionTitle("Subjective (S)"),
          _customTextField("Caregiver complain, concern", _sCaregiverCtrl,
              maxLines: 3),
          _customTextField(
              "Child's appearance & mood (eg: bruises)", _sAppearanceCtrl,
              maxLines: 2),
          _customTextField("Late attend to class (minutes)", _sLatenessCtrl),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB O: OBJECTIVE (HORIZONTAL CHIPS)
  // =========================================================================
  Widget _buildTabObjective() {
    return Column(
      children: [
        // 1. Horizontal Category Selector
        Container(
          height: 6.h,
          margin: EdgeInsets.symmetric(vertical: 1.5.h),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 2.h),
            itemCount: _oData.keys.length,
            itemBuilder: (context, index) {
              String category = _oData.keys.elementAt(index);
              bool isSelected = _selectedOCategory == category;
              return Padding(
                padding: EdgeInsets.only(right: 2.w),
                child: ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  selectedColor: Growkids.purpleFlo,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color:
                          isSelected ? Growkids.purpleFlo : Colors.grey[300]!),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _selectedOCategory = category;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),

        // 2. Text Fields for the Selected Category
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 2.h),
            children: [
              Container(
                padding: EdgeInsets.all(2.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 2.h),
                      child: Text(
                        _selectedOCategory,
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Growkids.purpleFlo),
                      ),
                    ),
                    ..._oData[_selectedOCategory].keys.map<Widget>((fieldName) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 2.h),
                        child: TextFormField(
                          key: ValueKey("$_selectedOCategory-$fieldName"),
                          initialValue: _oData[_selectedOCategory][fieldName],
                          onChanged: (val) {
                            _oData[_selectedOCategory][fieldName] = val;
                          },
                          decoration: InputDecoration(
                            labelText: fieldName,
                            labelStyle: TextStyle(
                                fontSize: 12.sp, color: Colors.grey[600]),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Growkids.purpleFlo)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB A: ANALYSIS
  // =========================================================================
  Widget _buildTabAnalysis() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Analysis / Improvement"),
          _customTextField(
              "Write your overall analysis here...", _aAnalysisCtrl,
              maxLines: 5),
          SizedBox(height: 1.h),
          _sectionTitle("Goals"),
          _customTextField("STG (Short Term Goal)", _aStgCtrl, maxLines: 3),
          _customTextField("LTG (Long Term Goal)", _aLtgCtrl, maxLines: 3),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB P: PLAN
  // =========================================================================
  Widget _buildTabPlan() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Treatment Given"),
          Text("Choose only related to the tx given of that date",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          SizedBox(height: 1.h),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!)),
            child: Column(
              children: _txOptions.map((option) {
                bool isSelected = _pTxGiven.contains(option);
                return Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(option, style: TextStyle(fontSize: 12.sp)),
                    value: isSelected,
                    activeColor: Growkids.purpleFlo,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    onChanged: (bool? val) {
                      setState(() {
                        if (val == true) {
                          _pTxGiven.add(option);
                        } else {
                          _pTxGiven.remove(option);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 1.5.h),
          _customTextField(
              "Other / Custom Treatment (Type here...)", _pTxCustomCtrl,
              maxLines: 2),
          SizedBox(height: 3.h),
          _sectionTitle("TCA Plan"),
          _customTextField("To come again plan...", _pTcaCtrl, maxLines: 3),
          SizedBox(height: 5.h),
          SizedBox(
            width: double.infinity,
            height: 7.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: () async {
                bool success = await _saveData('final');
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Report Finalized successfully!"),
                    backgroundColor: Colors.green,
                  ));
                  Navigator.pop(context);
                }
              },
              child: Text("Submit Final Report",
                  style: TextStyle(color: Colors.white, fontSize: 14.sp)),
            ),
          ),
          SizedBox(height: 5.h),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h, top: 1.h),
      child:
          Text(title, style: TextStyle(fontSize: 14.sp, color: Colors.black87)),
    );
  }

  Widget _customTextField(String hint, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Growkids.purpleFlo, width: 1.5)),
          contentPadding: EdgeInsets.all(1.5.h),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET QUICK PEEK VIEWER (BACA REPORT TANPA KELUAR FORM)
// ============================================================================
class QuickPeekViewer extends StatefulWidget {
  final String studId;
  final String studentName;

  const QuickPeekViewer(
      {super.key, required this.studId, required this.studentName});

  @override
  State<QuickPeekViewer> createState() => _QuickPeekViewerState();
}

class _QuickPeekViewerState extends State<QuickPeekViewer> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchLatestReport();
  }

  Future<void> _fetchLatestReport() async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.flutter('soap_get_latest_report.php')),
        /*Uri.parse(
            "http://app-kizzu.test/growkids/flutter/soap_get_latest_report.php"),*/
        body: {'stud_id': widget.studId},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') {
          setState(() {
            _reportData = json['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = json['message'] ?? "No SOAP report found.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSoapFormLayout(context)) {
      return _buildDesktopQuickPeek();
    }

    return _buildCompactQuickPeek();
  }

  Widget _buildCompactQuickPeek() {
    final screenSize = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: screenSize.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Growkids.purpleFlo,
                      Growkids.purpleFlo.withValues(alpha: 0.80),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.studentName.isEmpty
                            ? '?'
                            : widget.studentName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Growkids.purpleFlo,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUICK PEEK · PAST SOAP REPORT',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Growkids.purpleFlo,
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? _desktopQuickPeekError()
                        : _compactQuickPeekContent(),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border(top: BorderSide(color: Color(0xFFE3E5EC))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Growkids.purpleFlo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text('Close preview'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactQuickPeekContent() {
    final report = _reportData ?? <String, dynamic>{};
    final pData = _quickPeekMap(report['p_data']);
    final oData = _quickPeekMap(report['o_data']);
    final objectiveFields = <(String, String?)>[];
    for (final category in oData.entries) {
      final fields = _quickPeekMap(category.value);
      final values = fields.entries
          .where((entry) => entry.value.toString().trim().isNotEmpty)
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
      if (values.isNotEmpty) objectiveFields.add((category.key, values));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactMetaBadge(
                Icons.calendar_today_outlined,
                'Date',
                report['session_date']?.toString() ?? '—',
              ),
              _compactMetaBadge(
                Icons.numbers_rounded,
                'Session',
                report['session_num']?.toString() ?? '—',
              ),
              _compactMetaBadge(
                Icons.schedule_rounded,
                'Time',
                report['session_time']?.toString() ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _compactSoapSection('S', 'Subjective', [
            ('Caregiver concern', report['s_caregiver_concern']?.toString()),
            ('Appearance / Mood', report['s_child_appearance']?.toString()),
            ('Lateness', report['s_lateness']?.toString()),
          ]),
          const SizedBox(height: 10),
          _compactSoapSection(
            'O',
            'Objective',
            objectiveFields.isEmpty
                ? [('Observation', 'No objective notes recorded.')]
                : objectiveFields,
          ),
          const SizedBox(height: 10),
          _compactSoapSection('A', 'Assessment', [
            ('Overall analysis', report['a_analysis']?.toString()),
            ('Short-term goal', report['a_stg']?.toString()),
            ('Long-term goal', report['a_ltg']?.toString()),
          ]),
          const SizedBox(height: 10),
          _compactSoapSection('P', 'Plan', [
            (
              'Treatment given',
              pData['tx_given'] is List
                  ? (pData['tx_given'] as List).join(', ')
                  : pData['tx_given']?.toString()
            ),
            ('Custom treatment', pData['tx_custom']?.toString()),
            ('TCA plan', pData['tca_plan']?.toString()),
          ]),
        ],
      ),
    );
  }

  Widget _compactMetaBadge(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E4EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Growkids.purpleFlo, size: 14),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFF9296A2), fontSize: 8),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4A4E5B),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactSoapSection(
    String letter,
    String title,
    List<(String, String?)> fields,
  ) {
    final visible = fields
        .where((field) => field.$2 != null && field.$2!.trim().isNotEmpty)
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E4EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF30323C),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (visible.isEmpty)
            const Text(
              'No information recorded.',
              style: TextStyle(color: Color(0xFF9296A2), fontSize: 9),
            )
          else
            ...visible.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.$1,
                      style: const TextStyle(
                        color: Color(0xFF9296A2),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      field.$2!,
                      style: const TextStyle(
                        color: Color(0xFF555966),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopQuickPeek() {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 800),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Growkids.purpleFlo,
                      Growkids.purpleFlo.withValues(alpha: 0.78),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        widget.studentName.isEmpty
                            ? '?'
                            : widget.studentName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Growkids.purpleFlo,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUICK PEEK · PAST SOAP REPORT',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Growkids.purpleFlo,
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? _desktopQuickPeekError()
                        : _desktopQuickPeekContent(),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border(top: BorderSide(color: Color(0xFFE3E5EC))),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      color: Color(0xFF858A98),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Read-only preview of the latest report.',
                      style: TextStyle(
                        color: Color(0xFF858A98),
                        fontSize: 9,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 13,
                        ),
                      ),
                      child: const Text('Close preview'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopQuickPeekError() {
    return Center(
      child: Container(
        width: 390,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E5EC)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              color: Color(0xFF9A9EAA),
              size: 40,
            ),
            const SizedBox(height: 11),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666B78),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopQuickPeekContent() {
    final report = _reportData ?? <String, dynamic>{};
    final pData = _quickPeekMap(report['p_data']);
    final oData = _quickPeekMap(report['o_data']);
    final objectiveLines = <String>[];
    for (final category in oData.entries) {
      final fields = _quickPeekMap(category.value);
      final completed = fields.entries
          .where((entry) => entry.value.toString().trim().isNotEmpty);
      if (completed.isNotEmpty) {
        objectiveLines.add(
          '${category.key}: ${completed.map((entry) => '${entry.key} – ${entry.value}').join('; ')}',
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _desktopQuickPeekMeta(
                  Icons.calendar_today_outlined,
                  'Session date',
                  report['session_date']?.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _desktopQuickPeekMeta(
                  Icons.numbers_rounded,
                  'Session number',
                  report['session_num']?.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _desktopQuickPeekMeta(
                  Icons.schedule_rounded,
                  'Session time',
                  report['session_time']?.toString() ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _desktopQuickPeekSection(
                  'S',
                  'Subjective',
                  [
                    (
                      'Caregiver concern',
                      report['s_caregiver_concern']?.toString()
                    ),
                    (
                      'Appearance / Mood',
                      report['s_child_appearance']?.toString()
                    ),
                    ('Lateness', report['s_lateness']?.toString()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _desktopQuickPeekSection(
                  'A',
                  'Assessment',
                  [
                    ('Overall analysis', report['a_analysis']?.toString()),
                    ('Short-term goal', report['a_stg']?.toString()),
                    ('Long-term goal', report['a_ltg']?.toString()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _desktopQuickPeekSection(
                  'O',
                  'Objective',
                  objectiveLines.isEmpty
                      ? [('Observation', 'No objective notes recorded.')]
                      : objectiveLines
                          .map<(String, String?)>(
                            (line) => ('Observation', line),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _desktopQuickPeekSection(
                  'P',
                  'Plan',
                  [
                    (
                      'Treatment given',
                      (pData['tx_given'] is List)
                          ? (pData['tx_given'] as List).join(', ')
                          : pData['tx_given']?.toString()
                    ),
                    ('Custom treatment', pData['tx_custom']?.toString()),
                    ('TCA plan', pData['tca_plan']?.toString()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _quickPeekMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  Widget _desktopQuickPeekMeta(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Growkids.purpleFlo, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9296A2),
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF444752),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopQuickPeekSection(
    String letter,
    String title,
    List<(String, String?)> fields,
  ) {
    final visible = fields
        .where((field) => field.$2 != null && field.$2!.trim().isNotEmpty)
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF30323C),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Text(
              'No information recorded.',
              style: TextStyle(color: Color(0xFF9296A2), fontSize: 9),
            )
          else
            ...visible.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.$1,
                      style: const TextStyle(
                        color: Color(0xFF9296A2),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      field.$2!,
                      style: const TextStyle(
                        color: Color(0xFF555966),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
