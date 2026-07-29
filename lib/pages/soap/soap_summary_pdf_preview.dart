import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'pdf_export.dart';

class SoapSummaryPdfPreviewPage extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const SoapSummaryPdfPreviewPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    String studentName = reportData['stud_name'] ?? 'Report';

    return Scaffold(
      appBar: AppBar(
        title: Text("Preview: $studentName",
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PdfPreview(
        // This calls our generator function and displays the result
        build: (format) => PdfExport.generatePdfBytes(reportData),
        // Allows the user to share the PDF to WhatsApp, Email, etc.
        allowSharing: true,
        // Allows printing directly to a printer
        allowPrinting: true,
        // Change default page format to A4
        initialPageFormat: PdfPageFormat.a4,
        // Styling the PDF Preview background
        pdfFileName: "${studentName}_Summary_Report.pdf",
      ),
    );
  }
}
