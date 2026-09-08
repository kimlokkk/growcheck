import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

class KssReportPreviewPage extends StatelessWidget {
  final Map<String, dynamic> classData;
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> standards;
  final String reportingPeriod;
  final int overallTp;

  const KssReportPreviewPage({
    super.key,
    required this.classData,
    required this.student,
    required this.standards,
    required this.reportingPeriod,
    required this.overallTp,
  });

  String get _semester => reportingPeriod == 'SEM2' ? 'Semester 2' : 'Semester 1';

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final logoBytes = await rootBundle.load('assets/kss-long.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final results = Map<String, dynamic>.from(student['results'] as Map? ?? const {});
    final domains = <String, List<Map<String, dynamic>>>{};
    for (final standard in standards) {
      domains.putIfAbsent(standard['domain_id'].toString(), () => []).add(standard);
    }
    final pdf = pw.Document(
      // Built-in PDF fonts render reliably in browser viewers and avoid an
      // extra font decode/embed step while the report is loading.
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 42),
        ),
        header: (_) => pw.Column(children: [
          pw.Row(children: [
            pw.Image(logo, width: 125, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 14),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('KSS STUDENT ASSESSMENT REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6842FF'))),
              pw.SizedBox(height: 3),
              pw.Text('$_semester - ${classData['academic_year'] ?? ''}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ])),
          ]),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColor.fromHex('#6842FF'), thickness: 1.5),
        ]),
        footer: (context) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Kizzu Special School', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ]),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3F0FF'), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(flex: 4, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _pdfInfo('Student', student['student_name']),
                pw.SizedBox(height: 7),
                _pdfInfo('Student No.', student['student_no']),
              ])),
              pw.Expanded(flex: 3, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _pdfInfo('Class', classData['class_name']),
                pw.SizedBox(height: 7),
                _pdfInfo('Date of Birth', student['student_dob']),
              ])),
              pw.Expanded(flex: 3, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _pdfInfo('Subject', classData['subject_name']),
                pw.SizedBox(height: 7),
                _pdfInfo('Branch', student['student_branch']),
              ])),
              pw.Container(
                width: 64,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(color: _pdfTpBg(overallTp), borderRadius: pw.BorderRadius.circular(7)),
                child: pw.Column(children: [
                  pw.Text('OVERALL TP', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  pw.Text('TP$overallTp', style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: _pdfTpColor(overallTp))),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 16),
          ...domains.values.expand((domainStandards) sync* {
            final first = domainStandards.first;
            // Keep the skill title together with the first SK heading, while
            // still allowing the longer SP list to continue on the next page.
            yield pw.NewPage(freeSpace: 125);
            yield pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: PdfColor.fromHex('#EDE8FF'),
              child: pw.Text('${first['domain_code']}  ${first['domain_title']}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4D2BC5'))),
            );
            yield pw.SizedBox(height: 6);
            for (var index = 0; index < domainStandards.length; index++) {
              final standard = domainStandards[index];
              final resultRaw = results[standard['content_standard_id'].toString()];
              final result = resultRaw is Map ? Map<String, dynamic>.from(resultRaw) : <String, dynamic>{};
              final tp = int.tryParse('${result['tp_level'] ?? ''}');
              final observations = Map<String, dynamic>.from(result['sp_observations'] as Map? ?? const {});
              // Subsequent SK headings need only enough room for their header
              // and first lines, avoiding unnecessarily large blank areas.
              if (index > 0) yield pw.NewPage(freeSpace: 95);
              yield _pdfStandard(standard, result, observations, tp);
              yield pw.SizedBox(height: 7);
            }
            yield pw.SizedBox(height: 7);
          }),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfInfo(String label, dynamic value) => pw.Padding(
        padding: const pw.EdgeInsets.only(right: 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text((value ?? '-').toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  pw.Widget _pdfStandard(Map<String, dynamic> standard, Map<String, dynamic> result,
      Map<String, dynamic> observations, int? tp) {
    final learning = (standard['learning_standards'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            width: 42,
            height: 36,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(color: tp == null ? PdfColors.grey200 : _pdfTpBg(tp), borderRadius: pw.BorderRadius.circular(5)),
            child: pw.Text(tp == null ? '-' : 'TP$tp', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: tp == null ? PdfColors.grey700 : _pdfTpColor(tp))),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('SK ${standard['sk_code']}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6842FF'))),
            pw.Text((standard['sk_statement'] ?? '-').toString(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if ((result['interpretation'] ?? '').toString().trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text('Tafsiran: ${result['interpretation']}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
            ],
          ])),
        ]),
        if (learning.isNotEmpty) ...[
          pw.SizedBox(height: 7),
          ...learning.map((sp) {
            final obsRaw = observations[sp['learning_standard_id'].toString()];
            final obs = obsRaw is Map ? Map<String, dynamic>.from(obsRaw) : null;
            return pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(top: 3),
              padding: const pw.EdgeInsets.all(6),
              color: PdfColor.fromHex('#F8F8FB'),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('SP ${sp['sp_code']}  ${sp['sp_statement']}', style: const pw.TextStyle(fontSize: 8)),
                if (obs != null && (obs['observation_text'] ?? '').toString().trim().isNotEmpty)
                  pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text('Observation: ${obs['observation_text']}', style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800))),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  PdfColor _pdfTpColor(int tp) => tp <= 2
      ? PdfColor.fromHex('#B42318')
      : tp <= 4
          ? PdfColor.fromHex('#9A6700')
          : PdfColor.fromHex('#087A55');

  PdfColor _pdfTpBg(int tp) => tp <= 2
      ? PdfColor.fromHex('#FDE8E7')
      : tp <= 4
          ? PdfColor.fromHex('#FFF1C2')
          : PdfColor.fromHex('#DDF7ED');

  @override
  Widget build(BuildContext context) {
    final name = (student['student_name'] ?? 'Student').toString();
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return Scaffold(
      appBar: AppBar(
        title: Text('$name - $_semester'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: _buildPdf,
        initialPageFormat: PdfPageFormat.a4,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        loadingWidget: const _ReportLoading(),
        pdfFileName: 'KSS_${safeName}_${reportingPeriod}_${classData['academic_year'] ?? ''}.pdf',
      ),
    );
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Growkids.purpleFlo),
            SizedBox(height: 18),
            Text('Preparing assessment report...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 7),
            Text(
              'The screen may appear frozen for a moment while the PDF is rendered. This is normal; please wait and keep this page open.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF777486)),
            ),
          ],
        ),
      ),
    );
  }
}
