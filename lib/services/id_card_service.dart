import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student.dart';
import '../models/mosque_settings.dart';

class IdCardService {
  static Future<pw.Document> _buildDocument(List<Student> students, MosqueSettings settings) async {
    final doc = pw.Document();
    
    // Load Arabic Font
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    // Process logo if exists
    pw.ImageProvider? logoImage;
    if (settings.logoPath.isNotEmpty) {
      final file = File(settings.logoPath);
      if (file.existsSync()) {
        logoImage = pw.MemoryImage(file.readAsBytesSync());
      }
    }

    // A standard ID card is roughly 85.60 mm × 53.98 mm (CR80)
    // We will use CR80 dimensions in points (1 mm = 2.83465 points)
    // width: 85.6 * 2.83465 = 242.6 points
    // height: 53.98 * 2.83465 = 153.0 points
    // But let's build it vertically like a badge: 153 x 242 points (portrait)
    final cardFormat = PdfPageFormat(53.98 * PdfPageFormat.mm, 85.60 * PdfPageFormat.mm);

    for (var student in students) {
      pw.ImageProvider? studentPhoto;
      if (student.photoPath != null && student.photoPath!.isNotEmpty) {
        final file = File(student.photoPath!);
        if (file.existsSync()) {
          studentPhoto = pw.MemoryImage(file.readAsBytesSync());
        }
      }

      doc.addPage(
        pw.Page(
          pageFormat: cardFormat,
          margin: const pw.EdgeInsets.all(0),
          theme: pw.ThemeData.withFont(base: font),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    // Header Block
                    pw.Container(
                      height: 35,
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              height: 20,
                              width: 20,
                              margin: const pw.EdgeInsets.only(left: 4),
                              child: pw.Image(logoImage),
                            ),
                          pw.Container(
                            width: 100,
                            height: 20,
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                settings.name,
                                style: pw.TextStyle(color: PdfColors.white, font: font, fontSize: 10, fontWeight: pw.FontWeight.bold),
                                textDirection: pw.TextDirection.rtl,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.Spacer(),

                    // Photo Block
                    pw.Container(
                      width: 65,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.blue200, width: 2),
                        image: studentPhoto != null
                            ? pw.DecorationImage(image: studentPhoto, fit: pw.BoxFit.contain)
                            : null,
                      ),
                      child: studentPhoto == null
                          ? pw.Center(child: pw.Text('صورة', style: pw.TextStyle(fontSize: 10, font: font)))
                          : null,
                    ),

                    pw.SizedBox(height: 8),

                    // Info Block
                    pw.Container(
                      height: 22,
                      width: 135,
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          student.name,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900, font: font),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    
                    pw.Container(
                      height: 20,
                      width: 120,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          student.halaqa ?? 'بدون حلقة',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.blue900, font: font),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                    ),

                    pw.Spacer(),

                    // Footer Block
                    pw.Container(
                      width: double.infinity,
                      height: 18,
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(6)),
                      ),
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          student.studentId ?? '',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 2, font: font),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return doc;
  }

  static Future<void> generateIDCardsPdf(List<Student> students, MosqueSettings settings) async {
    final doc = await _buildDocument(students, settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'ID_Cards_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> exportIdCardsAsPngs(List<Student> students, MosqueSettings settings, BuildContext context) async {
    try {
      final doc = await _buildDocument(students, settings);
      final bytes = await doc.save();
      
      final outputDir = await getApplicationDocumentsDirectory();
      final targetFolder = Directory('${outputDir.path}\\Attendance_ID_Cards');
      if (!await targetFolder.exists()) {
        await targetFolder.create(recursive: true);
      }

      int index = 0;
      await for (final page in Printing.raster(bytes, dpi: 300)) {
        final imageBytes = await page.toPng();
        final student = students[index];
        final filename = '${student.studentId ?? student.id}_${student.name}.png'.replaceAll(' ', '_');
        final file = File('${targetFolder.path}\\$filename');
        await file.writeAsBytes(imageBytes);
        index++;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تم التصدير بنجاح'),
            content: Text('تم حفظ ${students.length} بطاقة كصور في المجلد:\n${targetFolder.path}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التصدير: $e')));
      }
    }
  }
}
