import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class KssV3SubjectReportPdfPage extends StatelessWidget {
  final Map<String, dynamic> report;
  const KssV3SubjectReportPdfPage({super.key, required this.report});

  static final PdfColor _navy = PdfColor.fromHex('#17324D');
  static final PdfColor _blue = PdfColor.fromHex('#2F5D7C');
  static final PdfColor _paleBlue = PdfColor.fromHex('#EAF0F5');

  PdfColor _tpBackground(dynamic value) {
    final level = int.tryParse(value.toString()) ?? 1;
    if (level <= 2) return PdfColor.fromHex('#F4CCCC');
    if (level <= 4) return PdfColor.fromHex('#FFF2CC');
    return PdfColor.fromHex('#D9EAD3');
  }

  Future<Uint8List> _buildPdf(PdfPageFormat _) async {
    final items = (report['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
      base: pw.Font.times(),
      bold: pw.Font.timesBold(),
      italic: pw.Font.timesItalic(),
    ));
    pdf.addPage(pw.MultiPage(
      pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.fromLTRB(36, 32, 36, 42)),
      header: (_) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('KIZZU SPECIAL SCHOOL',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.Text('SUBJECT ASSESSMENT REPORT',
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
        _infoBox(),
        pw.SizedBox(height: 18),
        ...items.map(_item),
        pw.SizedBox(height: 14),
        pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: _paleBlue,
                border: pw.Border.all(color: PdfColor.fromHex('#C6D6E3')),
                borderRadius: pw.BorderRadius.circular(7)),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('OVERALL MASTERY LEVEL',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('TP ${report['final_tp']}',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: _navy)),
                ])),
        pw.SizedBox(height: 20),
        pw.Text('Subject Teacher: ${report['teacher_name'] ?? '-'}',
            style: const pw.TextStyle(fontSize: 9)),
      ],
    ));
    return pdf.save();
  }

  pw.Widget _infoBox() => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: _paleBlue,
            border: pw.Border.all(color: PdfColor.fromHex('#C6D6E3')),
            borderRadius: pw.BorderRadius.circular(7)),
        child: pw.Row(children: [
          pw.Expanded(child: _info('Student', report['student_name'])),
          pw.Expanded(child: _info('Student No.', report['student_no'])),
          pw.Expanded(
              child: _info('Class',
                  'Year ${report['year_level']} ${report['class_name']}')),
          pw.Expanded(child: _info('Subject', report['subject_name'])),
          pw.Expanded(child: _info('Academic Year', report['academic_year'])),
          pw.Expanded(
              child: _info('Assessment',
                  '${report['semester'] == 'SEM2' ? 'Semester 2' : 'Semester 1'} • ${report['cycle_type'] == 'REVISION' ? 'Revision' : 'Initial'} ${report['cycle_no'] ?? 1}')),
        ]),
      );

  pw.Widget _info(String label, dynamic value) => pw.Padding(
        padding: const pw.EdgeInsets.only(right: 7),
        child: pw
            .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label.toUpperCase(),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text((value ?? '-').toString(),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  pw.Widget _item(Map<String, dynamic> item) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#D5E0E8')),
            borderRadius: pw.BorderRadius.circular(6)),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
              width: 42,
              height: 34,
              alignment: pw.Alignment.center,
              color: _tpBackground(item['tp_level']),
              child: pw.Text('TP ${item['tp_level']}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: _navy))),
          pw.SizedBox(width: 9),
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Text(
                    '${item['tp_group_code_snapshot']}  ${item['tp_group_title_snapshot']}',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if ((item['teacher_summary_snapshot'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(item['teacher_summary_snapshot'].toString(),
                      style: const pw.TextStyle(fontSize: 9))
                ],
              ])),
        ]),
      );

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
                'KSS_${safeName}_${report['subject_name']}_${report['semester'] ?? 'SEM1'}_Cycle${report['cycle_no'] ?? 1}_${report['academic_year']}.pdf'));
  }
}
