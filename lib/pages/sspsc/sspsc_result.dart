import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:growcheck_app_v2/ui/colour.dart'; // Ensure this matches your project structure

bool _useDesktopSspscResultLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class SSPSCResult extends StatefulWidget {
  final String assessmentId;
  final String studentName;

  const SSPSCResult({
    super.key,
    required this.assessmentId,
    required this.studentName,
  });

  @override
  State<SSPSCResult> createState() => _SSPSCResultState();
}

class _SSPSCResultState extends State<SSPSCResult> {
  bool isLoading = true;
  List<dynamic> sections = [];
  List<dynamic> quadrants = [];
  List<dynamic> factors = [];
  List<dynamic> details = [];

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    // UPDATED URL to match your filename
    final url = Uri.parse(ApiConfig.flutter('sp2_get_assessment_result.php'));
    /*final url = Uri.parse(
        'http://app-kizzu.test/growkids/flutter/sp2_get_assessment_result.php');*/

    try {
      final response =
          await http.post(url, body: {'assessment_id': widget.assessmentId});

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          setState(() {
            sections = jsonResponse['sections'] ?? [];
            quadrants = jsonResponse['quadrants'] ?? [];
            factors = jsonResponse['factors'] ?? [];
            details = jsonResponse['details'] ?? [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching results: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopSspscResultLayout(context)) {
      return _buildDesktop();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: const Text("Assessment Results",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : SingleChildScrollView(
              padding: EdgeInsets.all(2.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentHeader(),
                  SizedBox(height: 3.h),

                  // --- 1. SENSORY SECTIONS ---
                  _buildSectionHeader("Sensory Sections", Icons.person_outline),
                  ...sections.map((s) => _buildListCard(s)),
                  SizedBox(height: 3.h),

                  // --- 2. SENSORY PATTERNS ---
                  _buildSectionHeader(
                      "Sensory Patterns", Icons.grid_view_rounded),
                  _buildGridSection(quadrants, type: 'quadrant'),
                  SizedBox(height: 3.h),

                  // --- 3. SCHOOL FACTORS ---
                  _buildSectionHeader("School Factors", Icons.school_outlined),
                  _buildGridSection(factors, type: 'factor'),
                  SizedBox(height: 3.h),

                  // --- 4. FULL ITEM LOG (UPDATED) ---
                  _buildDetailedLog(),
                  SizedBox(
                    height: 3.h,
                  ),

                  // --- 5. NEW BUTTON (BUTANG BARU) ---
                  _buildDoneButton(),

                  SizedBox(height: 5.h), // Bottom padding
                ],
              ),
            ),
    );
  }

  // --- WIDGETS (KEPT EXACTLY AS YOURS) ---

  Widget _buildStudentHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .70)
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(widget.studentName,
              style: TextStyle(fontSize: 16.sp, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Row(
        children: [
          Icon(icon, size: 3.h, color: Growkids.purpleFlo),
          SizedBox(width: 2.w),
          Text(title, style: TextStyle(fontSize: 14.sp, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildListCard(dynamic data) {
    String name = data['name'];
    String score = data['score'].toString();
    String classification = data['classification'];
    String comment = data['comment'] ?? "";
    Color color = _getStatusColor(classification); // Fixed Logic applied here

    return GestureDetector(
      onTap: () => _showExplanationDialog(
          name, score, classification, color, 'section', name,
          comment: comment),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 7.h,
              height: 7.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.3), width: 2),
              ),
              child: Text(score,
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: TextStyle(fontSize: 14.sp)),
                      if (comment.isNotEmpty) ...[
                        SizedBox(width: 2.w),
                        Icon(Icons.comment, size: 2.h, color: Colors.blueGrey),
                      ]
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(classification,
                      style: TextStyle(fontSize: 13.sp, color: color)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 2.h, color: Colors.grey[500])
          ],
        ),
      ),
    );
  }

  Widget _buildGridSection(List<dynamic> items, {required String type}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 3.w,
        mainAxisSpacing: 1.5.h,
        childAspectRatio: 3.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildGridCard(items[index], type);
      },
    );
  }

  Widget _buildGridCard(dynamic data, String type) {
    String name = data['name'];
    String code = data['code'] ?? name;
    String score = data['score'].toString();
    String classification = data['classification'];
    Color color = _getStatusColor(classification); // Fixed Logic applied here
    String displayName = name.replaceAll("School Factor", "Factor");

    return GestureDetector(
      onTap: () => _showExplanationDialog(
          name, score, classification, color, type, code),
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 3))
          ],
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 6.h,
              height: 6.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.3), width: 2),
              ),
              child: Text(score,
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    classification,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[
                            600]), // Slightly smaller font for classification fit
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- UPDATED: DETAILED LOG (ADDED TAGS) ---
  Widget _buildDetailedLog() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
          leading:
              Icon(Icons.list_alt_rounded, color: Colors.blueGrey, size: 3.h),
          title: Text("Full Response Log", style: TextStyle(fontSize: 14.sp)),
          subtitle: Text("${details.length} Items Recorded",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          children: [
            Divider(height: 1, color: Colors.grey[200]),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: details.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey[100]),
              itemBuilder: (context, index) {
                var item = details[index];
                int score = int.parse(item['score_value']);

                // Get details (make sure PHP returns these now)
                String section = item['section_name'] ?? "";
                String quadrant = item['quadrant_code'] ?? "";
                String factor = item['school_factor'] ?? "";

                return Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8.w,
                        alignment: Alignment.center,
                        child: Text(item['item_number'],
                            style: TextStyle(
                                fontSize: 14.sp, color: Colors.grey[500])),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question Text
                            Text(item['question_text'],
                                style: TextStyle(
                                    fontSize: 14.sp, color: Colors.black87)),
                            SizedBox(height: 0.8.h),

                            // NEW: TAGS (Section | Quadrant | Factor)
                            Wrap(
                              spacing: 2.w,
                              runSpacing: 1.h,
                              children: [
                                _buildMiniTag(
                                    section.toUpperCase(), Colors.blueGrey),
                                if (quadrant.isNotEmpty)
                                  _buildMiniTag(
                                      _getQuadrantName(quadrant).toUpperCase(),
                                      _getQuadrantColor(quadrant)),
                                if (factor.isNotEmpty)
                                  _buildMiniTag(
                                      "FACTOR $factor", Growkids.purpleFlo),
                              ],
                            )
                          ],
                        ),
                      ),

                      // Score
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.5.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: _getScoreColor(score).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text("$score",
                            style: TextStyle(
                                fontSize: 14.sp, color: _getScoreColor(score))),
                      )
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  // --- HELPER FOR TAGS ---
  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13.sp, color: color),
      ),
    );
  }

  // --- DIALOG EXPLANATION ---
  void _showExplanationDialog(String name, String score, String classification,
      Color color, String type, String code,
      {String comment = ""}) {
    String definition = "";
    String impact = "";

    if (type == 'section') {
      definition = _getSectionDefinition(name);
      impact = _getSectionImpact(name, classification);
    } else if (type == 'quadrant') {
      definition = _getQuadrantDefinition(code);
      impact = _getQuadrantImpact(code, classification);
    } else if (type == 'factor') {
      definition = _getFactorDefinition(code);
      impact = _getFactorImpact(code);
    }

    if (_useDesktopSspscResultLayout(context)) {
      _showDesktopExplanationDialog(
        name: name,
        score: score,
        classification: classification,
        color: color,
        definition: definition,
        impact: impact,
        comment: comment,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: 4.w),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        radius: 16,
                        child: Icon(Icons.analytics, color: color, size: 3.h)),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(name, style: TextStyle(fontSize: 14.sp)),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text("Score: $score",
                          style:
                              TextStyle(color: Colors.white, fontSize: 14.sp)),
                    ),
                  ],
                ),
                Divider(height: 3.h),

                // Teacher Observations
                if (comment.isNotEmpty) ...[
                  Text("Teacher Observations",
                      style:
                          TextStyle(fontSize: 12.sp, color: Colors.blueGrey)),
                  SizedBox(height: 1.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                        color: Colors.blueGrey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade100)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded,
                            color: Colors.blueGrey, size: 3.h),
                        SizedBox(width: 2.w),
                        Expanded(
                            child: Text(comment,
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic))),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.5.h),
                ],

                // Definition
                Text("Definition", style: TextStyle(fontSize: 12.sp)),
                SizedBox(height: 0.5.h),
                Text(definition,
                    style: TextStyle(
                        fontSize: 12.sp, color: Colors.grey[700], height: 1.4)),
                SizedBox(height: 2.5.h),

                // Result Analysis
                Text("Result Analysis", style: TextStyle(fontSize: 12.sp)),
                SizedBox(height: 0.5.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(classification,
                          style: TextStyle(color: color, fontSize: 12.sp)),
                      SizedBox(height: 0.5.h),
                      Text(impact,
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black87,
                              height: 1.4)),
                    ],
                  ),
                ),
                SizedBox(height: 3.h),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(vertical: 1.2.h)),
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close",
                        style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UPDATED LOGIC (BELL CURVE 5 SCALES) ---
  Color _getStatusColor(String? classification) {
    if (classification == null) return Colors.grey;

    // RED: Much Less OR Much More (Ends of Bell Curve)
    if (classification.contains("Much")) return Colors.red;

    // YELLOW: Less OR More (Warning Zones)
    if (classification.contains("More") || classification.contains("Less")) {
      return Colors.amber;
    }

    // GREEN: Majority (Center of Bell Curve)
    return Colors.green;
  }

  Color _getScoreColor(int score) {
    if (score == 5) return Colors.red;
    if (score == 4) return Colors.orange;
    if (score == 3) return Colors.amber;
    if (score == 0) return Colors.grey;
    return Colors.green; // 1 & 2 are usually good
  }

  // --- DICTIONARIES (Helper for Tags) ---
  String _getQuadrantName(String code) {
    if (code == 'SK') return "Seeking";
    if (code == 'AV') return "Avoiding";
    if (code == 'SN') return "Sensitivity";
    if (code == 'RG') return "Registration";
    return code;
  }

  Color _getQuadrantColor(String code) {
    if (code == 'SK') return Colors.orange;
    if (code == 'AV') return Colors.red;
    if (code == 'SN') return Colors.blue;
    if (code == 'RG') return Colors.green;
    return Colors.grey;
  }

  // --- CONTENT STRINGS ---
  String _getSectionDefinition(String name) {
    if (name == 'Auditory') {
      return "Processing sounds, verbal instructions, and background noise.";
    }
    if (name == 'Visual') {
      return "Processing sights, lights, classroom clutter, and visual materials.";
    }
    if (name == 'Touch') {
      return "Processing physical contact, textures, and messy play.";
    }
    if (name == 'Movement') {
      return "Processing balance, physical activity, and sitting tolerance.";
    }
    if (name == 'Behavioral') {
      return "Emotional and behavioral reactions related to sensory needs.";
    }
    return "Measurement of sensory processing in this domain.";
  }

  String _getSectionImpact(String name, String cls) =>
      cls == "Just Like Majority"
          ? "Typical performance."
          : "Student may face challenges with $name inputs.";

  String _getQuadrantDefinition(String code) {
    if (code == 'SK') return "High Threshold, Active Regulation (Seeking).";
    if (code == 'AV') return "Low Threshold, Active Regulation (Avoiding).";
    if (code == 'SN') return "Low Threshold, Passive Regulation (Sensitivity).";
    if (code == 'RG') {
      return "High Threshold, Passive Regulation (Registration).";
    }
    return "";
  }

  String _getQuadrantImpact(String code, String cls) =>
      cls == "Just Like Majority"
          ? "Typical regulation."
          : "Score indicates deviation from typical peer group.";

  String _getFactorDefinition(String code) {
    if (code.contains("1")) return "Student's Need for External Supports.";
    if (code.contains("2")) return "Awareness and Attention.";
    if (code.contains("3")) return "Tolerance for Sensory Input.";
    if (code.contains("4")) return "Availability for Learning.";
    return "";
  }

  String _getFactorImpact(String code) =>
      "High scores indicate specific challenges in this school factor.";

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Growkids.purpleFlo,
          padding: EdgeInsets.symmetric(vertical: 1.8.h),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        onPressed: () {
          // --- PILIHAN 1 (Paling Selamat jika Home adalah page utama) ---
          // Ini akan "tutup" semua page (Result & Form) sehingga sampai ke page pertama (Home/Dashboard).
          Navigator.of(context).popUntil((route) => route.isFirst);

          // --- PILIHAN 2 (Jika Home bukan page pertama / root) ---
          // Kalau Home awak bukan page pertama (contohnya ada Login -> Dashboard -> SSPSC Home),
          // Awak kena import fail SSPSCHome dan guna code ini:
          /*
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SSPSCHome()), // Pastikan nama class betul
          (Route<dynamic> route) => route.isFirst // Simpan root (contoh: Dashboard utama/Login)
        );
        */
        },
        child: Text(
          "Proceed Home",
          style: TextStyle(fontSize: 14.sp, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        leading: const BackButton(color: Colors.white),
        titleSpacing: 8,
        title: const Text(
          'SSPSC Assessment Result',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _desktopHeader(),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _desktopSectionsPanel(),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _desktopResultGrid(
                                  title: 'Sensory Patterns',
                                  icon: Icons.grid_view_rounded,
                                  items: quadrants,
                                  type: 'quadrant',
                                ),
                                const SizedBox(height: 20),
                                _desktopResultGrid(
                                  title: 'School Factors',
                                  icon: Icons.school_outlined,
                                  items: factors,
                                  type: 'factor',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _desktopResponseLog(),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 190,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Growkids.purpleFlo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.of(context)
                                .popUntil((route) => route.isFirst),
                            icon: const Icon(Icons.home_outlined, size: 19),
                            label: const Text(
                              'Proceed Home',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _desktopHeader() {
    final initial = widget.studentName.trim().isEmpty
        ? '?'
        : widget.studentName.trim().substring(0, 1).toUpperCase();

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
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Growkids.purple,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SENSORY PROCESSING ASSESSMENT',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _desktopCount('Sections', sections.length),
          const SizedBox(width: 10),
          _desktopCount('Patterns', quadrants.length),
          const SizedBox(width: 10),
          _desktopCount('Factors', factors.length),
          const SizedBox(width: 10),
          _desktopCount('Responses', details.length),
        ],
      ),
    );
  }

  Widget _desktopCount(String label, int count) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSectionsPanel() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopPanelTitle(
            'Sensory Sections',
            Icons.person_outline_rounded,
            sections.length,
          ),
          const SizedBox(height: 16),
          if (sections.isEmpty)
            _desktopEmpty('No sensory section result is available.')
          else
            ...sections.map((data) {
              final name = (data['name'] ?? '-').toString();
              final score = (data['score'] ?? '0').toString();
              final classification = (data['classification'] ?? '-').toString();
              final comment = (data['comment'] ?? '').toString();
              final color = _getStatusColor(classification);

              return _desktopResultTile(
                name: name,
                score: score,
                classification: classification,
                color: color,
                hasComment: comment.isNotEmpty,
                onTap: () => _showExplanationDialog(
                  name,
                  score,
                  classification,
                  color,
                  'section',
                  name,
                  comment: comment,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _desktopResultGrid({
    required String title,
    required IconData icon,
    required List<dynamic> items,
    required String type,
  }) {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopPanelTitle(title, icon, items.length),
          const SizedBox(height: 16),
          if (items.isEmpty)
            _desktopEmpty('No result is available.')
          else
            ...items.map((data) {
              final name = (data['name'] ?? '-').toString();
              final code = (data['code'] ?? name).toString();
              final score = (data['score'] ?? '0').toString();
              final classification = (data['classification'] ?? '-').toString();
              final color = _getStatusColor(classification);

              return _desktopResultTile(
                name: name.replaceAll('School Factor', 'Factor'),
                score: score,
                classification: classification,
                color: color,
                onTap: () => _showExplanationDialog(
                  name,
                  score,
                  classification,
                  color,
                  type,
                  code,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _desktopResultTile({
    required String name,
    required String score,
    required String classification,
    required Color color,
    required VoidCallback onTap,
    bool hasComment = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7E9F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.20)),
                  ),
                  child: Text(
                    score,
                    style: TextStyle(
                      color: color,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFF303341),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (hasComment) ...[
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.blueGrey,
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        classification,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9A9EAA),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopResponseLog() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _desktopPanelTitle(
            'Full Response Log',
            Icons.list_alt_rounded,
            details.length,
          ),
          const SizedBox(height: 16),
          if (details.isEmpty)
            _desktopEmpty('No response has been recorded.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7E9F0)),
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                title: const Text(
                  'View all recorded responses',
                  style: TextStyle(
                    color: Color(0xFF303341),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${details.length} items recorded',
                  style: const TextStyle(
                    color: Color(0xFF858A99),
                    fontSize: 12,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                children: details.map((item) {
                  final score =
                      int.tryParse((item['score_value'] ?? '0').toString()) ??
                          0;
                  final section = (item['section_name'] ?? '').toString();
                  final quadrant = (item['quadrant_code'] ?? '').toString();
                  final factor = (item['school_factor'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7E9F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            (item['item_number'] ?? '-').toString(),
                            style: const TextStyle(
                              color: Color(0xFF858A99),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (item['question_text'] ?? '-').toString(),
                                style: const TextStyle(
                                  color: Color(0xFF3B3E4C),
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  if (section.isNotEmpty)
                                    _desktopTag(section, Colors.blueGrey),
                                  if (quadrant.isNotEmpty)
                                    _desktopTag(
                                      _getQuadrantName(quadrant),
                                      _getQuadrantColor(quadrant),
                                    ),
                                  if (factor.isNotEmpty)
                                    _desktopTag(
                                      'Factor $factor',
                                      Growkids.purpleFlo,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _desktopTag('$score', _getScoreColor(score)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopPanelTitle(String title, IconData icon, int count) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Growkids.purple.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Growkids.purple, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF202331),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _desktopTag('$count', Growkids.purple),
      ],
    );
  }

  Widget _desktopTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _desktopEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF777C8B), fontSize: 13),
      ),
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1635),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _showDesktopExplanationDialog({
    required String name,
    required String score,
    required String classification,
    required Color color,
    required String definition,
    required String impact,
    required String comment,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260E1635),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.analytics_outlined, color: color),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF202331),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _desktopTag('Score $score', color),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _desktopDialogSection(
                      'Teacher observations',
                      comment,
                      Colors.blueGrey,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _desktopDialogSection(
                    'Definition',
                    definition,
                    const Color(0xFF5D6372),
                  ),
                  const SizedBox(height: 16),
                  _desktopDialogSection(
                    classification,
                    impact,
                    color,
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 110,
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Growkids.purpleFlo,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopDialogSection(String title, String body, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF4A4E5C),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
