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
  // failData contains the list of components that did not 'Pass'

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
      // Expected JSON structure with keys: suggestions, recommendations, interventions
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

  Future<Uint8List> makePdf() async {
    // Load custom Roboto font
    final customFont = pw.Font.ttf(await rootBundle.load('fonts/Roboto-Regular.ttf'));
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: customFont,
        bold: customFont,
      ),
    );

    // Load logo image
    final ByteData logoBytes = await rootBundle.load('assets/Growcheck-logo.png');
    final Uint8List logoData = logoBytes.buffer.asUint8List();

    // Helper: normalise skor untuk paparan dalam PDF
    String scoreDisplay(dynamic raw) {
      final s = (raw ?? '').toString().trim().toLowerCase();
      if (s == 'pass' || s == 'tercapai') return 'Pass';
      if (s == 'n.o' || s == 'no opportunity' || s == 'no_opportunity' || s == 'no-opportunity' || s == 'no') {
        return 'No Opportunity';
      }
      // default lain-lain dianggap Fail (tidak tercapai)
      return 'Fail';
    }

// Gabungkan semua item tidak-pass: Fail + N.O
    final List<Map<String, dynamic>> notPassItems = [
      ...widget.failData,
    ];

// Group ikut domain, tapi kita simpan juga skor yang sudah dinormalize untuk PDF
    Map<String, List<Map<String, dynamic>>> groupedFailData = {};
    for (final it in notPassItems) {
      final dom = (it['domain'] ?? '').toString();
      final disp = scoreDisplay(it['score']);
      groupedFailData.putIfAbsent(dom, () => []);
      groupedFailData[dom]!.add({
        ...it,
        'score_for_pdf': disp, // 'Fail' | 'No Opportunity' | (jarang) 'Pass'
      });
    }

    // Check if a domain contains any "No Opportunity" item
    bool hasNoOpportunityForDomain(String domainKey) {
      final items = groupedFailData[domainKey] ?? [];
      for (final item in items) {
        final disp = (item['score_for_pdf'] ?? scoreDisplay(item['score'])).toString();
        if (disp == 'No Opportunity') {
          return true;
        }
      }
      return false;
    }

// Decide status text based on dev age, actual age, and NO items
    String statusForDomain(String domainKey, double devAge) {
      final hasNoOpp = hasNoOpportunityForDomain(domainKey);

      if (devAge < widget.age) {
        // kalau ada NO → Further observations
        if (hasNoOpp) return 'Further observations';
        // tak ada NO → confirm Suspected delay
        return 'Suspected delay';
      }

      // devAge >= actual age
      return 'Normal';
    }

// Color for each status
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

    // Header and footer functions for consistency
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
            // Header Section: Logo and PDF Title
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(
                  pw.MemoryImage(logoData),
                  height: 50,
                  fit: pw.BoxFit.contain,
                ),
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
            // Student Information Section
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
                              child: pw.Text('Field', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Detail', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
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
            // Developmental Ages Section
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
                              child: pw.Text('Domain', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Dev Age (Months)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Fine Motor')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.ageFineMotor.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            fineStatus,
                            style: pw.TextStyle(color: colorForStatus(fineStatus)),
                          ),
                        ),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Gross Motor')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.ageGrossMotor.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            grossStatus,
                            style: pw.TextStyle(color: colorForStatus(grossStatus)),
                          ),
                        ),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Language')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.ageLanguage.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            languageStatus,
                            style: pw.TextStyle(color: colorForStatus(languageStatus)),
                          ),
                        ),
                      ]),
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Personal Social')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(widget.agePersonal.toString())),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            personalStatus,
                            style: pw.TextStyle(color: colorForStatus(personalStatus)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Fail Components Section with Summary if Too Many Items
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
                    for (var domain in groupedFailData.keys) ...[
                      pw.Text('Domain: $domain', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      // If there are more than 10 fail items, show a summary
                      groupedFailData[domain]!.length > 10
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
                                        child:
                                            pw.Text('Component', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(8),
                                        child: pw.Text('Score', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  ],
                                ),
                                for (var fail in groupedFailData[domain]!)
                                  pw.TableRow(
                                    children: [
                                      pw.Padding(
                                          padding: const pw.EdgeInsets.all(8), child: pw.Text(fail['component'])),
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
            // Suggestions, Recommendations & Intervention Plan Section
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
                  // Suggestions
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
                  // Recommendations
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
                  // Intervention Plan
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
                          pw.Text("${i + 1}. ${interventions[i]['title']}",
                              style:
                                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                          pw.SizedBox(height: 5),
                          pw.Text("Description",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue)),
                          pw.Text(interventions[i]['description'] ?? "No description available.",
                              style: const pw.TextStyle(fontSize: 14)),
                          pw.SizedBox(height: 5),
                          pw.Text("Example",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue)),
                          pw.Text(interventions[i]['example'] ?? "No example available.",
                              style: const pw.TextStyle(fontSize: 14)),
                          pw.SizedBox(height: 10),
                        ],
                      );
                    }),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Therapist Note & References Section
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Growkids.purple,
        leading: const BackButton(color: Colors.white),
        title: const Text('Full Result PDF', style: TextStyle(color: Colors.white)),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        actionBarTheme: const PdfActionBarTheme(
          backgroundColor: Growkids.purple,
          iconColor: Colors.white,
        ),
        build: (context) => makePdf(),
      ),
    );
  }
}
