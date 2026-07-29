import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class PdfExport {
  static Future<Uint8List> generatePdfBytes(Map<String, dynamic> reportData) async {
    // 1. Fetch fonts that support bullet points and dashes
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    // 2. Apply the fonts globally to the entire PDF document
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
      ),
    );

    // 3. Load the Logo from Assets
    final ByteData imageBdata = await rootBundle.load('assets/logo-header-2.png');
    final Uint8List imageUint8List = imageBdata.buffer.asUint8List();
    final logoImage = pw.MemoryImage(imageUint8List);

    // Calculate Age
    String ageStr = "Unknown";
    if (reportData['stud_dob'] != null) {
      try {
        DateTime dob = DateTime.parse(reportData['stud_dob']);
        DateTime reportDate =
            reportData['date_of_report'] != null ? DateTime.parse(reportData['date_of_report']) : DateTime.now();
        int years = reportDate.year - dob.year;
        int months = reportDate.month - dob.month;
        if (months < 0) {
          years--;
          months += 12;
        }
        ageStr = "$years years $months months old";
      } catch (_) {}
    }

    String formattedDate = reportData['date_of_report'] != null
        ? DateFormat('dd MMMM yyyy').format(DateTime.parse(reportData['date_of_report']))
        : 'Unknown Date';

    // Build the 3-Column Table Rows
    List<pw.TableRow> buildTableRows() {
      List<pw.TableRow> rows = [];

      void addSection(String sectionTitle, dynamic data) {
        if (data == null || data is! Map || data.isEmpty) return;
        bool isFirstRow = true;

        data.forEach((key, value) {
          if (value == null || value.toString().trim().isEmpty) return;

          rows.add(
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    isFirstRow ? sectionTitle : "",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    key.toString(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    value.toString(),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          );
          isFirstRow = false;
        });
      }

      addSection("Activities of Daily\nLiving (ADL)", reportData['adl_data']);
      addSection("Developmental Skills", reportData['skills_data']);
      addSection("Sensory & Behavior", reportData['sensory_behavior_data']);

      return rows;
    }

    // 2. Define the Official Page Theme (With Background Bubbles)
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.only(left: 40, right: 40, top: 40, bottom: 60),
      buildBackground: (pw.Context context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.CustomPaint(
            // FIX 1: Removed 'const' because PdfPageFormat.a4.width is dynamic
            size: PdfPoint(PdfPageFormat.a4.width, PdfPageFormat.a4.height),
            // FIX 2: Removed 'pw.' prefix from PdfGraphics and PdfPoint
            painter: (PdfGraphics canvas, PdfPoint size) {
              // Draw Top-Left Bubble (Light Purple/Blue blend)
              canvas.setFillColor(PdfColor.fromHex('#F2EFFF'));
              canvas.moveTo(0, size.y);
              canvas.lineTo(0, size.y - 180);
              canvas.curveTo(120, size.y - 150, 180, size.y - 60, 250, size.y);
              canvas.lineTo(0, size.y);
              canvas.fillPath();

              // Draw Top-Left Inner Accent Bubble (Slightly darker)
              canvas.setFillColor(PdfColor.fromHex('#E5DEFF'));
              canvas.moveTo(0, size.y);
              canvas.lineTo(0, size.y - 100);
              canvas.curveTo(60, size.y - 80, 100, size.y - 40, 140, size.y);
              canvas.lineTo(0, size.y);
              canvas.fillPath();

              // Draw Bottom-Right Bubble (Light Blue)
              canvas.setFillColor(PdfColor.fromHex('#F0F4FF'));
              canvas.moveTo(size.x, 0);
              canvas.lineTo(size.x, 150);
              canvas.curveTo(size.x - 120, 120, size.x - 180, 50, size.x - 220, 0);
              canvas.lineTo(size.x, 0);
              canvas.fillPath();
            },
          ),
        );
      },
    ); // FIX 3: Moved footer out of PageTheme

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        // FIX 3: Footer correctly placed inside MultiPage
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 5),
              pw.Text(
                "Address: 1A-3-1, Jalan Pegaga E U12/E, Desa Alam, 40170 Shah Alam, Selangor",
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                "Tel: +6011 3738 2172   Web: http://kizzukids.com.my   Email: admin@kizzukids.com.my",
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // --- HEADER SECTION (With Logo) ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logoImage, width: 180, height: 180),
                pw.SizedBox(width: 15),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("KIZZU KIDS U12 SHAH ALAM BRANCH",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text("KIZZU HOLDINGS SDN BHD (1368894-D)",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text("1A-3-1, JALAN PEGAGA E U12/E, DESA ALAM", style: const pw.TextStyle(fontSize: 9)),
                      pw.Text("40170 SHAH ALAM, SELANGOR", style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )
              ],
            ),
            pw.SizedBox(height: 30),

            // --- TITLE ---
            pw.Center(
              child: pw.Text(
                "OCCUPATIONAL THERAPY SUMMARY REPORT",
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, decoration: pw.TextDecoration.underline),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                "This report is strictly confidential. Copies may not be made or distributed without client or parental consent.",
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
            ),
            pw.SizedBox(height: 25),

            // --- PATIENT DETAILS ---
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Full name: ${reportData['stud_name'] ?? 'Unknown'}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 5),
                pw.Text("Date of birth: ${reportData['stud_dob'] ?? 'Unknown'}",
                    style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 5),
                pw.Text("Age: $ageStr", style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 5),
                pw.Text("Session attended: ${reportData['sessions_attended'] ?? '0'} sessions",
                    style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 5),
                pw.Text("Date of report: $formattedDate", style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 5),
                pw.Text("Report done by: Occupational Therapist", style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
            pw.SizedBox(height: 20),

            // --- BACKGROUND INFO ---
            if (reportData['background_info'] != null &&
                reportData['background_info'].toString().trim().isNotEmpty) ...[
              pw.Text(
                reportData['background_info'].toString(),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),
            ],

            // --- DATA TABLE ---
            if (buildTableRows().isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(4.0),
                },
                children: buildTableRows(),
              ),
              pw.SizedBox(height: 20),
            ],

            // --- SUMMARY & RECOMMENDATION ---
            if (reportData['summary_recommendation'] != null &&
                reportData['summary_recommendation'].toString().trim().isNotEmpty) ...[
              pw.Text("Summary & Recommendation", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Text(
                reportData['summary_recommendation'].toString(),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 50),
            ],

            // --- SIGN OFF ---
            pw.Text("Prepared by,", style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 60),
            pw.Text("_______________________", style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 5),
            pw.Text("Occupational Therapist,", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.Text("Kizzu Kids Therapy Center, Shah Alam", style: const pw.TextStyle(fontSize: 11)),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
