import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sizer/sizer.dart';

class ResultPdf extends StatefulWidget {
  final String studentId;
  final String screeningId;
  final String studentName;
  final String ageString;
  final double age; // Student's age in months
  final double ageFineMotor;
  final double ageGrossMotor;
  final double agePersonal;
  final double ageLanguage;
  final String therapist_suggestion;
  final String screeningDate;
  final List<Map<String, dynamic>> failData;

  const ResultPdf({
    Key? key,
    required this.studentId,
    required this.screeningId,
    required this.studentName,
    required this.ageString,
    required this.age,
    required this.ageFineMotor,
    required this.ageGrossMotor,
    required this.agePersonal,
    required this.ageLanguage,
    required this.therapist_suggestion,
    required this.screeningDate,
    required this.failData,
  }) : super(key: key);

  @override
  State<ResultPdf> createState() => _ResultPdfState();
}

class _ResultPdfState extends State<ResultPdf> {
  bool isLoading = true;
  List<dynamic> suggestions = [];
  List<dynamic> recommendations = [];
  List<dynamic> interventions = [];

  Future<void> fetchData() async {
    final response = await http.post(
      Uri.parse('http://app.kizzukids.com.my/growkids/flutter/fetch_suggestion_submission.php'),
      body: {"studentId": widget.studentId},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        suggestions = data["suggestions"] ?? [];
        recommendations = data["recommendations"] ?? [];
        interventions = data["interventions"] ?? [];
        isLoading = false;
      });
    } else {
      throw Exception("Failed to load data");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // =========================
  // PDF Generator (UNCHANGED LOGIC)
  // =========================
  Future<Uint8List> makePdf() async {
    final customFont = pw.Font.ttf(await rootBundle.load('fonts/Roboto-Regular.ttf'));
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: customFont,
        bold: customFont,
      ),
    );

    final ByteData logoBytes = await rootBundle.load('assets/Growcheck-logo.png');
    final Uint8List logoData = logoBytes.buffer.asUint8List();

    String scoreDisplay(dynamic raw) {
      final s = (raw ?? '').toString().trim().toLowerCase();
      if (s == 'pass' || s == 'tercapai') return 'Pass';
      if (s == 'n.o' || s == 'no opportunity' || s == 'no_opportunity' || s == 'no-opportunity' || s == 'no') {
        return 'No Opportunity';
      }
      return 'Fail';
    }

    final List<Map<String, dynamic>> notPassItems = [
      ...widget.failData,
    ];

    Map<String, List<Map<String, dynamic>>> groupedFailData = {};
    for (final it in notPassItems) {
      final dom = (it['domain'] ?? '').toString();
      final disp = scoreDisplay(it['score']);
      groupedFailData.putIfAbsent(dom, () => []);
      groupedFailData[dom]!.add({
        ...it,
        'score_for_pdf': disp,
      });
    }

    bool hasNoOpportunityForDomain(String domainKey) {
      final items = groupedFailData[domainKey] ?? [];
      for (final item in items) {
        final disp = (item['score_for_pdf'] ?? scoreDisplay(item['score'])).toString();
        if (disp == 'No Opportunity') return true;
      }
      return false;
    }

    String statusForDomain(String domainKey, double devAge) {
      final hasNoOpp = hasNoOpportunityForDomain(domainKey);

      if (devAge < widget.age) {
        if (hasNoOpp) return 'Further observations';
        return 'Suspected delay';
      }
      return 'Normal';
    }

    PdfColor colorForStatus(String status) {
      switch (status) {
        case 'Normal':
          return PdfColors.green;
        case 'Further observations':
          return PdfColors.orange;
        case 'Suspected delay':
        default:
          return PdfColors.red;
      }
    }

    final fineStatus = statusForDomain('Fine Motor', widget.ageFineMotor);
    final grossStatus = statusForDomain('Gross Motor', widget.ageGrossMotor);
    final languageStatus = statusForDomain('Language', widget.ageLanguage);
    final personalStatus = statusForDomain('Personal Social', widget.agePersonal);

    pw.Widget header(pw.Context context) {
      return pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(
          'Official Student Report',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    pw.Widget footer(pw.Context context) {
      return pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        header: header,
        footer: footer,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(pw.MemoryImage(logoData), height: 50, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 10),
                pw.Text(
                  'Official Student Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Student info
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.blue800, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Student Information', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(3),
                    },
                    border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Field', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Detail', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Student Name')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.studentName)),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Age')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.ageString)),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Assessment Date')),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(DateFormat('dd MMMM yyyy').format(DateTime.parse(widget.screeningDate))),
                        ),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Therapist')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(name)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Dev ages
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.blue800, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Developmental Ages', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                    },
                    border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Domain', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Dev Age (Months)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Fine Motor')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.ageFineMotor.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(fineStatus, style: pw.TextStyle(color: colorForStatus(fineStatus))),
                        ),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Gross Motor')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.ageGrossMotor.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(grossStatus, style: pw.TextStyle(color: colorForStatus(grossStatus))),
                        ),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Language')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.ageLanguage.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(languageStatus, style: pw.TextStyle(color: colorForStatus(languageStatus))),
                        ),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Personal Social')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.agePersonal.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(personalStatus, style: pw.TextStyle(color: colorForStatus(personalStatus))),
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Fail components
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.blue800, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Fail Components', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  if (groupedFailData.isEmpty)
                    pw.Text("No fail components.", style: const pw.TextStyle(fontSize: 14))
                  else
                    for (final domain in groupedFailData.keys) ...[
                      pw.Text('Domain: $domain', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      groupedFailData[domain]!.length > 15
                          ? pw.Text(
                              "A significant number of items (Total: ${groupedFailData[domain]!.length}) in this domain did not meet the required standards. Please refer to the detailed analysis for further insights.",
                              style: pw.TextStyle(fontSize: 14, color: PdfColors.red),
                            )
                          : pw.Table(
                              columnWidths: {
                                0: const pw.FlexColumnWidth(3),
                                1: const pw.FlexColumnWidth(1),
                              },
                              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                              children: [
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                                  children: [
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(8),
                                      child: pw.Text('Component', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(8),
                                      child: pw.Text('Score', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                for (final fail in groupedFailData[domain]!)
                                  pw.TableRow(
                                    children: [
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(8),
                                        child: pw.Text((fail['component'] ?? '').toString()),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(8),
                                        child: pw.Text(
                                          (fail['score_for_pdf'] ?? scoreDisplay(fail['score'])).toString(),
                                          style: pw.TextStyle(
                                            color: (() {
                                              final d =
                                                  (fail['score_for_pdf'] ?? scoreDisplay(fail['score'])).toString();
                                              return d == 'Fail'
                                                  ? PdfColors.red
                                                  : (d == 'No Opportunity' ? PdfColors.orange : PdfColors.green600);
                                            })(),
                                          ),
                                          textAlign: pw.TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                      pw.SizedBox(height: 15),
                    ],
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Suggestions / Recommendations / Intervention Plan
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.blue800, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Suggestions', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  if (suggestions.isEmpty)
                    pw.Text("No suggestions available.", style: const pw.TextStyle(fontSize: 14))
                  else
                    ...suggestions.map((sug) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Text("• ${sug['suggestion']}", style: const pw.TextStyle(fontSize: 14)),
                        )),
                  pw.SizedBox(height: 20),
                  pw.Text('Recommendations', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  if (recommendations.isEmpty)
                    pw.Text("No recommendations available.", style: const pw.TextStyle(fontSize: 14))
                  else
                    ...recommendations.map((rec) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Text("• ${rec['recommendation']}", style: const pw.TextStyle(fontSize: 14)),
                        )),
                  pw.SizedBox(height: 20),
                  pw.Text('Intervention Plan', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  if (interventions.isEmpty)
                    pw.Text("No intervention plan available.", style: const pw.TextStyle(fontSize: 14))
                  else
                    ...List.generate(interventions.length, (i) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "${i + 1}. ${interventions[i]['title']}",
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text("Description",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue)),
                          pw.Text(
                            (interventions[i]['description'] ?? "No description available.").toString(),
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text("Example",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue)),
                          pw.Text(
                            (interventions[i]['example'] ?? "No example available.").toString(),
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                          pw.SizedBox(height: 10),
                        ],
                      );
                    }),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Therapist Note / References
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.blue800, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Therapist Note/Comment', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text(widget.therapist_suggestion, style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 20),
                  pw.Text('Rujukan:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Bullet(
                      text: 'Garis panduan oleh Kementerian Pendidikan Malaysia',
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.Bullet(
                      text: 'Case-Smith\'s Occupational Therapy Practice Framework',
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.Bullet(
                      text: 'Disemak mengikut piawaian perkembangan global', style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // =========================
  // PREMIUM UI (THEME StudentHub)
  // =========================

  String _formatDateSafe(String raw) {
    try {
      return DateFormat('d MMMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Widget _heroHeader() {
    final dateText = _formatDateSafe(widget.screeningDate);

    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.h,
            backgroundColor: Colors.white,
            child: Text(
              widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : '?',
              style: TextStyle(color: Growkids.purple, fontSize: 18.sp, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
                SizedBox(height: 0.4.h),
                Text(
                  '${widget.ageString} • $dateText',
                  style: TextStyle(fontSize: 14.sp, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge('Therapist: $name', Icons.medical_services_rounded),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _badge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget _summaryRow(String label, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Growkids.purple.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Growkids.purple.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              height: 4.h,
              width: 4.h,
              decoration: BoxDecoration(
                color: Growkids.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Growkids.purple,
                size: 2.h,
              ),
            ),
            SizedBox(width: 1.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.65))),
                  const SizedBox(height: 3),
                  Text('$count', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // BUILD (Premium UI)
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Full Result PDF', style: TextStyle(color: Colors.white)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(2.h, 2.h, 2.h, 1.h),
                  child: Column(
                    children: [
                      _heroHeader(),
                      SizedBox(height: 1.6.h),
                      _glassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Summary', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
                            SizedBox(height: 1.2.h),
                            Row(
                              children: [
                                _summaryRow('Suggestion', suggestions.length, Icons.lightbulb_rounded),
                                const SizedBox(width: 10),
                                _summaryRow('Advice', recommendations.length, Icons.checklist_rounded),
                                const SizedBox(width: 10),
                                _summaryRow('Interventions', interventions.length, Icons.route_rounded),
                                const SizedBox(width: 10),
                                _summaryRow('Fail Items', widget.failData.length, Icons.error_outline_rounded),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // PDF Preview area (full height)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(2.h, 0, 2.h, 2.h),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.black.withOpacity(0.06)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: PdfPreview(
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          canDebug: false,
                          actionBarTheme: const PdfActionBarTheme(
                            backgroundColor: Growkids.purpleFlo,
                            iconColor: Colors.white,
                          ),
                          build: (context) => makePdf(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
