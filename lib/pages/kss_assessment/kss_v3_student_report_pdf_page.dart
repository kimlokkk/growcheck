import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class KssV3StudentReportPdfPage extends StatelessWidget {
  final Map<String, dynamic> report;
  const KssV3StudentReportPdfPage({super.key, required this.report});

  static final PdfColor _navy = PdfColor.fromHex('#17324D');
  static final PdfColor _blue = PdfColor.fromHex('#2F5D7C');
  static final PdfColor _paleBlue = PdfColor.fromHex('#EAF0F5');
  static final PdfColor _tableHeader = PdfColor.fromHex('#DCE7F0');

  PdfColor _tpBackground(dynamic value) {
    final level = int.tryParse(value.toString()) ?? 1;
    if (level <= 2) return PdfColor.fromHex('#F4CCCC');
    if (level <= 4) return PdfColor.fromHex('#FFF2CC');
    return PdfColor.fromHex('#D9EAD3');
  }

  Future<Uint8List> _buildPdf(PdfPageFormat _) async {
    final subjects = (report['subjects'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
            base: pw.Font.times(),
            bold: pw.Font.timesBold(),
            italic: pw.Font.timesItalic()));
    pdf.addPage(pw.MultiPage(
      pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.fromLTRB(36, 32, 36, 42)),
      header: (_) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('KIZZU SPECIAL SCHOOL',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.Text('CLASSROOM ASSESSMENT REPORT',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
        ]),
        pw.SizedBox(height: 7),
        pw.Divider(color: _blue, thickness: 1.2),
      ]),
      footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8))),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Center(
            child: pw.Column(children: [
          pw.Text('END-OF-SEMESTER CLASSROOM ASSESSMENT REPORT',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.SizedBox(height: 3),
          pw.Text(report['semester'] == 'SEM2' ? 'Semester 2' : 'Semester 1',
              style: const pw.TextStyle(fontSize: 10)),
        ])),
        pw.SizedBox(height: 14),
        pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: _paleBlue,
                border: pw.Border.all(color: PdfColor.fromHex('#C6D6E3')),
                borderRadius: pw.BorderRadius.circular(7)),
            child: pw.Column(children: [
              pw.Row(children: [
                pw.Expanded(child: _info('Student', report['student_name'])),
                pw.Expanded(child: _info('Student No.', report['student_no'])),
                pw.Expanded(
                    child: _info('Year / Class',
                        'Year ${report['year_level']} ${report['class_name']}')),
              ]),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Expanded(
                    child: _info('Homeroom teacher',
                        report['homeroom_teacher_name'] ?? '-')),
                pw.Expanded(
                    child: _info('Academic year', report['academic_year'])),
                pw.Expanded(child: _info('School', 'Kizzu Special School')),
              ]),
            ])),
        pw.SizedBox(height: 20),
        pw.Text('SUBJECT RESULTS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey700),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.7),
            1: pw.FlexColumnWidth(0.8),
            2: pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _navy),
              children: ['Subject', 'Overall TP', 'Assessment result']
                  .map((label) => pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(label,
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center)))
                  .toList(),
            ),
            ...subjects.map((subject) => pw.TableRow(children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(subject['name'].toString(),
                          style: const pw.TextStyle(fontSize: 10))),
                  pw.Container(
                      color: subject['final_tp'] == null
                          ? PdfColors.grey200
                          : _tpBackground(subject['final_tp']),
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                          subject['final_tp'] == null
                              ? '-'
                              : 'TP ${subject['final_tp']}',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(_resultStatus(subject),
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center)),
                ])),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text('DETAILED ASSESSMENT RESULTS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...subjects.expand((subject) => [
              _subjectSection(subject),
              pw.SizedBox(height: 12),
            ]),
        pw.SizedBox(height: 14),
        pw.Text('Homeroom teacher comment:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 32),
        pw.Divider(color: PdfColors.grey600),
        pw.SizedBox(height: 22),
        pw.Row(children: [
          pw.Expanded(
              child:
                  _signature('Prepared by', report['homeroom_teacher_name'])),
          pw.SizedBox(width: 36),
          pw.Expanded(child: _signature('Received by (Parent / Guardian)', '')),
        ]),
      ],
    ));
    return pdf.save();
  }

  pw.Widget _info(String label, dynamic value) => pw.Padding(
      padding: const pw.EdgeInsets.only(right: 8),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label.toUpperCase(),
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text((value ?? '-').toString(),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))
      ]));

  String _resultStatus(Map<String, dynamic> subject) =>
      subject['subject_status']?.toString() == 'COMPLETED'
          ? 'Completed'
          : 'Not completed';

  pw.Widget _subjectSection(Map<String, dynamic> subject) {
    final items = (subject['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(7),
              color: _tableHeader,
              child: pw.Row(children: [
                pw.Expanded(
                    child: pw.Text(subject['name'].toString(),
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold))),
                pw.Text(
                    subject['final_tp'] == null
                        ? 'No result'
                        : 'Overall TP ${subject['final_tp']}',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ])),
          if (items.isEmpty)
            pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400)),
                child: pw.Text('No completed assessment result.',
                    style: const pw.TextStyle(fontSize: 9)))
          else
            pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey500),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.1),
                  1: pw.FlexColumnWidth(.65),
                  2: pw.FlexColumnWidth(2.2),
                },
                children: [
                  pw.TableRow(
                      decoration: pw.BoxDecoration(color: _paleBlue),
                      children: ['Learning area', 'TP', 'Teacher observation']
                          .map((label) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(label,
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.center)))
                          .toList()),
                  ...items.map((item) => pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                                '${item['tp_group_code_snapshot']}  ${item['tp_group_title_snapshot']}',
                                style: const pw.TextStyle(fontSize: 8))),
                        pw.Container(
                            color: _tpBackground(item['tp_level']),
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('TP ${item['tp_level']}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.center)),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                                (item['teacher_summary_snapshot'] ?? '-')
                                    .toString(),
                                style: const pw.TextStyle(fontSize: 8))),
                      ])),
                ]),
        ]);
  }

  pw.Widget _signature(String label, dynamic name) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Divider(color: PdfColors.grey600),
        pw.SizedBox(height: 4),
        pw.Text((name ?? '').toString(),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ]);

  @override
  Widget build(BuildContext context) {
    final safeName = (report['student_name'] ?? 'student')
        .toString()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return Scaffold(
        appBar: AppBar(
            title: const Text('Preview PDF'),
            backgroundColor: Growkids.purpleFlo,
            foregroundColor: Colors.white),
        body: PdfPreview(
            build: _buildPdf,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            pdfFileName:
                'KSS_${safeName}_FINAL_REPORT_${report['semester'] ?? 'SEM1'}_${report['academic_year']}.pdf'));
  }
}
