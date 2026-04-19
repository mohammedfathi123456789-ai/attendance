import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/mosque_settings.dart';
import '../models/evaluation.dart';
import '../services/database_helper.dart';

class ReportService {
  static Future<void> generateAttendanceReport({
    required MosqueSettings settings,
    required String dateRangeText,
    required List<Student> students,
    required List<Teacher> teachers,
    required List<Attendance> attendanceRecords,
    required List<String> distinctDates,
  }) async {
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

    // Prepare persons list (combine students and teachers, or handle them separately)
    // For simplicity, let's treat everyone as a "Person" and group them loosely.
    final List<Map<String, dynamic>> persons = [];
    for (var t in teachers) {
      persons.add({'id': t.id, 'recordId': t.teacherId, 'name': t.name, 'type': 'teacher'});
    }
    for (var s in students) {
      persons.add({'id': s.id, 'recordId': s.studentId, 'name': s.name, 'type': 'student'});
    }

    // Setup map for quick attendance lookup
    // Key: type_personId_date, Value: status
    final attMap = <String, String>{};
    for (var a in attendanceRecords) {
      attMap['${a.type}_${a.personId}_${a.date}'] = a.status;
    }

    String getSymbol(String? status) {
      if (status == 'present') return 'ح';
      if (status == 'absent') return 'غ';
      if (status == 'excused') return '-';
      return '-';
    }

    String getDayOnly(String dateStr) {
      try {
        final dt = DateTime.parse(dateStr);
        return dt.day.toString();
      } catch (e) {
        return dateStr;
      }
    }

    if (persons.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Center(
                child: pw.Text(
                  'لا توجد بيانات',
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      final maxPersonsPerPage = 11;
      final totalPages = (persons.length / maxPersonsPerPage).ceil();

      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final startIndex = pageIndex * maxPersonsPerPage;
        final endIndex = (startIndex + maxPersonsPerPage < persons.length)
            ? startIndex + maxPersonsPerPage
            : persons.length;
        final pagePersons = persons.sublist(startIndex, endIndex);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            theme: pw.ThemeData.withFont(base: font),
            textDirection: pw.TextDirection.rtl,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  children: [
                    // Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(
                            height: 60,
                            width: 60,
                            child: pw.Image(logoImage),
                          ),
                          pw.SizedBox(width: 16),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              settings.name,
                              textDirection: pw.TextDirection.rtl,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'تقرير الحضور والغياب | $dateRangeText',
                              textDirection: pw.TextDirection.rtl,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: font, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 12),

                    // Table
                    pw.Expanded(
                      child: pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.grey300),
                          tableWidth: pw.TableWidth.max,
                          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                          columnWidths: {
                            0: const pw.IntrinsicColumnWidth(), // الغياب (Left)
                            for (int i = 0; i < distinctDates.length; i++)
                              i + 1: const pw.IntrinsicColumnWidth(), // Days
                            distinctDates.length + 1: const pw.FlexColumnWidth(), // الاسم (Name)
                            distinctDates.length + 2: const pw.IntrinsicColumnWidth(), // ID
                            distinctDates.length + 3: const pw.IntrinsicColumnWidth(), // م (Num, Right)
                          },
                          children: [
                            // Table Header
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.grey200,
                              ),
                              children: [
                                _buildCell('الغياب', font, isHeader: true, align: pw.TextAlign.center),
                                ...distinctDates.reversed.map((d) => _buildCell(getDayOnly(d), font, isHeader: true)).toList(),
                                _buildCell('الاسم', font, isHeader: true),
                                _buildCell('المعرف', font, isHeader: true, align: pw.TextAlign.center),
                                _buildCell('م', font, isHeader: true, align: pw.TextAlign.center),
                              ],
                            ),
                            // Table Rows
                            for (int i = 0; i < pagePersons.length; i++)
                              pw.TableRow(
                                children: [
                                  _buildCell(
                                    '${distinctDates.where((d) => attMap['${pagePersons[i]['type']}_${pagePersons[i]['id']}_$d'] == 'absent').length}',
                                    font,
                                    align: pw.TextAlign.center,
                                  ),
                                  ...distinctDates.reversed.map((d) {
                                    final status = attMap['${pagePersons[i]['type']}_${pagePersons[i]['id']}_$d'];
                                    return _buildCell(getSymbol(status), font, align: pw.TextAlign.center);
                                  }).toList(),
                                  _buildCell(pagePersons[i]['name'], font),
                                  _buildCell(pagePersons[i]['recordId'] ?? '-', font, align: pw.TextAlign.center),
                                  _buildCell('${startIndex + i + 1}', font, align: pw.TextAlign.center),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'ملاحظة: "-" تعني لم يتم التحضير',
                          textDirection: pw.TextDirection.rtl,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: font, fontSize: 12),
                        ),
                        pw.Text(
                          'صفحة ${pageIndex + 1} من $totalPages',
                          textDirection: pw.TextDirection.rtl,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: font, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Attendance_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  static Future<void> generateHalaqaAttendanceReport({
    required MosqueSettings settings,
    required String dateRangeText,
    required String halaqaName,
    required List<Student> students,
    required List<Attendance> attendanceRecords,
    required List<String> distinctDates,
  }) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    pw.ImageProvider? logoImage;
    if (settings.logoPath.isNotEmpty) {
      final file = File(settings.logoPath);
      if (file.existsSync()) logoImage = pw.MemoryImage(file.readAsBytesSync());
    }

    final halaqaStudents = students.where((s) => s.halaqa == halaqaName).toList();
    halaqaStudents.sort((a, b) => a.name.compareTo(b.name));

    final attMap = <String, String>{};
    for (var a in attendanceRecords) {
      attMap['student_${a.personId}_${a.date}'] = a.status;
    }

    String getSymbol(String? status) {
      if (status == 'present') return 'ح';
      if (status == 'absent') return 'غ';
      if (status == 'excused') return 'ع';
      return '-';
    }

    String getDayOnly(String dateStr) {
      try { return DateTime.parse(dateStr).day.toString(); } catch (e) { return dateStr; }
    }

    if (halaqaStudents.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font),
          build: (pw.Context context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(child: pw.Text('لا توجد بيانات لهذه الحلقة', style: pw.TextStyle(font: font, fontSize: 24))),
          ),
        ),
      );
    } else {
      final maxPersonsPerPage = 11;
      final totalPages = (halaqaStudents.length / maxPersonsPerPage).ceil() == 0 ? 1 : (halaqaStudents.length / maxPersonsPerPage).ceil();

      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final startIndex = pageIndex * maxPersonsPerPage;
        final endIndex = (startIndex + maxPersonsPerPage < halaqaStudents.length)
            ? startIndex + maxPersonsPerPage : halaqaStudents.length;
        final pageStudents = halaqaStudents.sublist(startIndex, endIndex);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            theme: pw.ThemeData.withFont(base: font),
            textDirection: pw.TextDirection.rtl,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(height: 60, width: 60, child: pw.Image(logoImage)),
                          pw.SizedBox(width: 16),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(settings.name, style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 8),
                            pw.Text('تقرير حضور حلقة $halaqaName | $dateRangeText', style: pw.TextStyle(font: font, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 12),

                    pw.Expanded(
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                        columnWidths: {
                          for (int i = 0; i < distinctDates.length; i++)
                            i: const pw.IntrinsicColumnWidth(),
                          distinctDates.length: const pw.FlexColumnWidth(),
                          distinctDates.length + 1: const pw.IntrinsicColumnWidth(),
                          distinctDates.length + 2: const pw.IntrinsicColumnWidth(),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              ...distinctDates.reversed.map((d) => _buildCell(getDayOnly(d), font, isHeader: true)).toList(),
                              _buildCell('الاسم', font, isHeader: true),
                              _buildCell('المعرف', font, isHeader: true, align: pw.TextAlign.center),
                              _buildCell('م', font, isHeader: true, align: pw.TextAlign.center),
                            ],
                          ),
                          for (int i = 0; i < pageStudents.length; i++)
                            pw.TableRow(
                              children: [
                                ...distinctDates.reversed.map((d) {
                                  final status = attMap['student_${pageStudents[i].id}_$d'];
                                  return _buildCell(getSymbol(status), font, align: pw.TextAlign.center);
                                }).toList(),
                                _buildCell(pageStudents[i].name, font),
                                _buildCell(pageStudents[i].studentId ?? '-', font, align: pw.TextAlign.center),
                                _buildCell('${startIndex + i + 1}', font, align: pw.TextAlign.center),
                              ],
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('ملاحظة: "ح" حاضر، "غ" غائب، "ع" بعذر', style: pw.TextStyle(font: font, fontSize: 12)),
                        pw.Text('صفحة ${pageIndex + 1} من $totalPages', style: pw.TextStyle(font: font, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Halaqa_Attendance_${DateTime.now().millisecondsSinceEpoch}.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  static Future<void> generateHalaqaReport({
    required MosqueSettings settings,
    required List<Student> students,
    required List<Teacher> teachers,
  }) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    pw.ImageProvider? logoImage;
    if (settings.logoPath.isNotEmpty) {
      final file = File(settings.logoPath);
      if (file.existsSync()) logoImage = pw.MemoryImage(file.readAsBytesSync());
    }

    final Map<String, List<Student>> halaqas = {};
    for (var student in students) {
      final h = (student.halaqa?.trim() ?? '').isEmpty ? 'بدون حلقة' : student.halaqa!.trim();
      halaqas.putIfAbsent(h, () => []).add(student);
    }

    if (halaqas.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font),
          build: (pw.Context context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(child: pw.Text('لا توجد بيانات', style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold))),
          ),
        ),
      );
    } else {
      for (var entry in halaqas.entries) {
        final halaqaName = entry.key;
        final halaqaStudents = entry.value;

        String teacherName = 'غير محدد';
        for (var t in teachers) {
          if (t.halaqa != null && t.halaqa!.trim() == halaqaName) {
            teacherName = t.name;
            break;
          }
        }

        final maxPersonsPerPage = 22;
        final totalPages = (halaqaStudents.length / maxPersonsPerPage).ceil() == 0 ? 1 : (halaqaStudents.length / maxPersonsPerPage).ceil();

        for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
          final startIndex = pageIndex * maxPersonsPerPage;
          final endIndex = (startIndex + maxPersonsPerPage < halaqaStudents.length)
              ? startIndex + maxPersonsPerPage
              : halaqaStudents.length;
          final pageStudents = halaqaStudents.sublist(startIndex, endIndex);

          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(32),
              theme: pw.ThemeData.withFont(base: font),
              textDirection: pw.TextDirection.rtl,
              build: (pw.Context context) {
                return pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          if (logoImage != null) ...[
                            pw.Container(height: 60, width: 60, child: pw.Image(logoImage)),
                            pw.SizedBox(width: 16),
                          ],
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(settings.name, style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 4),
                              pw.Text('تقرير طلاب الحلقة', style: pw.TextStyle(font: font, fontSize: 18)),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 16),
                      pw.Divider(thickness: 2),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('الحلقة: $halaqaName', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.Text('المعلم: $teacherName', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      if (pageStudents.isEmpty)
                        pw.Expanded(child: pw.Center(child: pw.Text('لا يوجد طلاب', style: pw.TextStyle(font: font, fontSize: 16))))
                      else
                        pw.Expanded(
                          child: pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.grey300),
                            columnWidths: {
                              0: const pw.FlexColumnWidth(), // Name
                              1: const pw.IntrinsicColumnWidth(), // ID
                              2: const pw.IntrinsicColumnWidth(), // Num
                            },
                            children: [
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                children: [
                                  _buildCell('اسم الطالب', font, isHeader: true),
                                  _buildCell('المعرف', font, isHeader: true, align: pw.TextAlign.center),
                                  _buildCell('م', font, isHeader: true, align: pw.TextAlign.center),
                                ],
                              ),
                              for (int i = 0; i < pageStudents.length; i++)
                                pw.TableRow(
                                  children: [
                                    _buildCell(pageStudents[i].name, font),
                                    _buildCell(pageStudents[i].studentId?.isNotEmpty == true ? pageStudents[i].studentId! : '-', font, align: pw.TextAlign.center),
                                    _buildCell('${startIndex + i + 1}', font, align: pw.TextAlign.center),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('تاريخ الإصدار: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text('صفحة ${pageIndex + 1} من $totalPages', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Halaqa_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generateAllStudentsReport({
    required MosqueSettings settings,
    required List<Student> students,
    required List<Teacher> teachers,
  }) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    pw.ImageProvider? logoImage;
    if (settings.logoPath.isNotEmpty) {
      final file = File(settings.logoPath);
      if (file.existsSync()) logoImage = pw.MemoryImage(file.readAsBytesSync());
    }

    final List<Map<String, String>> persons = [];
    
    final sortedTeachers = List<Teacher>.from(teachers)..sort((a, b) => a.name.compareTo(b.name));
    for (var t in sortedTeachers) {
      persons.add({
        'name': '${t.name} (معلم)',
        'type': 'teacher',
        'id': t.teacherId ?? '-',
        'halaqa': (t.halaqa?.trim().isNotEmpty ?? false) ? t.halaqa!.trim() : 'بدون حلقة',
      });
    }

    final sortedStudents = List<Student>.from(students)..sort((a, b) => a.name.compareTo(b.name));
    for (var s in sortedStudents) {
      persons.add({
        'name': s.name,
        'type': 'student',
        'id': s.studentId ?? '-',
        'halaqa': (s.halaqa?.trim().isNotEmpty ?? false) ? s.halaqa!.trim() : 'بدون حلقة',
      });
    }

    if (persons.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font),
          build: (pw.Context context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(child: pw.Text('لا توجد بيانات', style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold))),
          ),
        ),
      );
    } else {
      final maxPersonsPerPage = 25;
      final totalPages = (persons.length / maxPersonsPerPage).ceil() == 0 ? 1 : (persons.length / maxPersonsPerPage).ceil();

      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final startIndex = pageIndex * maxPersonsPerPage;
        final endIndex = (startIndex + maxPersonsPerPage < persons.length) ? startIndex + maxPersonsPerPage : persons.length;
        final pagePersons = persons.sublist(startIndex, endIndex);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: font),
            textDirection: pw.TextDirection.rtl,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(height: 60, width: 60, child: pw.Image(logoImage)),
                          pw.SizedBox(width: 16),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(settings.name, style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text('سجل جميع منسوبي المسجد', style: pw.TextStyle(font: font, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 12),
                    pw.Expanded(
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        columnWidths: {
                          0: const pw.IntrinsicColumnWidth(), // Halaqa
                          1: const pw.FlexColumnWidth(), // Name
                          2: const pw.IntrinsicColumnWidth(), // ID
                          3: const pw.IntrinsicColumnWidth(), // Num
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _buildCell('الحلقة / الصف', font, isHeader: true, align: pw.TextAlign.center),
                              _buildCell('الاسم', font, isHeader: true),
                              _buildCell('المعرف', font, isHeader: true, align: pw.TextAlign.center),
                              _buildCell('م', font, isHeader: true, align: pw.TextAlign.center),
                            ],
                          ),
                          for (int i = 0; i < pagePersons.length; i++)
                            pw.TableRow(
                              children: [
                                _buildCell(pagePersons[i]['halaqa']!, font, align: pw.TextAlign.center),
                                _buildCell(pagePersons[i]['name']!, font),
                                _buildCell(pagePersons[i]['id']!, font, align: pw.TextAlign.center),
                                _buildCell('${startIndex + i + 1}', font, align: pw.TextAlign.center),
                              ],
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('تاريخ الإصدار: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('صفحة ${pageIndex + 1} من $totalPages', style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'All_Students_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generateStudentEvaluationReport({
    required MosqueSettings settings,
    required List<Student> students,
    required List<Teacher> teachers,
    required List<Attendance> attendanceRecords,
    required String dateRangeText,
  }) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    pw.ImageProvider? logoImage;
    if (settings.logoPath.isNotEmpty) {
      final file = File(settings.logoPath);
      if (file.existsSync()) logoImage = pw.MemoryImage(file.readAsBytesSync());
    }

    if (students.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font),
          build: (pw.Context context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Text('لا توجد بيانات',
                  style: pw.TextStyle(
                      font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
          ),
        ),
      );
    } else {
      for (var student in students) {
        // Calculate attendance
        int presentCount = 0;
        int absentCount = 0;
        int excusedCount = 0;

        for (var a in attendanceRecords) {
          if (a.type == 'student' && a.personId == student.id) {
            if (a.status == 'present') {
              presentCount++;
            } else if (a.status == 'absent') {
              absentCount++;
            } else if (a.status == 'excused') {
              excusedCount++;
            }
          }
        }

        // Fetch evaluation
        final evaluation = await DatabaseHelper.instance.getEvaluationByStudent(student.id!);

        // Find Teacher
        String teacherName = 'غير محدد';
        if (student.halaqa != null && student.halaqa!.trim().isNotEmpty) {
          for (var t in teachers) {
            if (t.halaqa == student.halaqa) {
              teacherName = t.name;
              break;
            }
          }
        }

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: font),
            textDirection: pw.TextDirection.rtl,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(
                              height: 60, width: 60, child: pw.Image(logoImage)),
                          pw.SizedBox(width: 16),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(settings.name,
                                style: pw.TextStyle(
                                    font: font,
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text('تقرير تقييم الطالب',
                                style: pw.TextStyle(
                                    font: font,
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.blue800)),
                            if (dateRangeText.isNotEmpty)
                              pw.Text(dateRangeText,
                                  style: pw.TextStyle(
                                      font: font,
                                      fontSize: 12,
                                      color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 24),
                    pw.Divider(thickness: 2, color: PdfColors.blue900),
                    pw.SizedBox(height: 16),

                    // Student Info
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border:
                            pw.Border.all(color: PdfColors.blue200, width: 1),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('اسم الطالب: ${student.name}',
                                  style: pw.TextStyle(
                                      font: font,
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text('المعرف: ${student.studentId ?? '-'}',
                                  style: pw.TextStyle(
                                      font: font,
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.SizedBox(height: 12),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                  'اسم الحلقة: ${student.halaqa ?? 'غير محدد'}',
                                  style: pw.TextStyle(
                                      font: font,
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text('اسم المعلم: $teacherName',
                                  style: pw.TextStyle(
                                      font: font,
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 24),

                    // Attendance Summary
                    pw.Text('سجل الحضور:',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800)),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAttendanceCard(
                            'حضور', presentCount, PdfColors.green700, font),
                        _buildAttendanceCard(
                            'غياب', absentCount, PdfColors.red700, font),
                        _buildAttendanceCard(
                            'بعذر', excusedCount, PdfColors.orange700, font),
                      ],
                    ),
                    pw.SizedBox(height: 32),

                    // Evaluation
                    pw.Text('التقييم المستمر:',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800)),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(1),
                        3: const pw.FlexColumnWidth(1),
                        4: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _buildTableCell('المعيار', font,
                                isHeader: true, center: false),
                            _buildTableCell('ممتاز', font,
                                isHeader: true, center: true),
                            _buildTableCell('جيد جداً', font,
                                isHeader: true, center: true),
                            _buildTableCell('جيد', font,
                                isHeader: true, center: true),
                            _buildTableCell('ضعيف', font,
                                isHeader: true, center: true),
                          ],
                        ),
                        _buildEvaluationRow('الحفظ', font, evaluation?.memorization),
                        _buildEvaluationRow('التلاوة', font, evaluation?.recitation),
                        _buildEvaluationRow('الالتزام', font, evaluation?.commitment),
                      ],
                    ),
                    pw.SizedBox(height: 32),

                    // Notes Section
                    pw.Text('ملاحظات المعلم:',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800)),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      constraints: const pw.BoxConstraints(minHeight: 100),
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      padding: const pw.EdgeInsets.all(8),
                      // Print blank lines for the teacher to write notes or print stored notes
                      child: evaluation != null && evaluation.notes != null && evaluation.notes!.isNotEmpty
                          ? pw.Text(
                              evaluation.notes!,
                              style: pw.TextStyle(font: font, fontSize: 14),
                              textDirection: pw.TextDirection.rtl,
                            )
                          : pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                              children: [
                                pw.Divider(color: PdfColors.grey300),
                                pw.Divider(color: PdfColors.grey300),
                                pw.Divider(color: PdfColors.grey300),
                              ]),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Student_Evaluation_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildAttendanceCard(
      String label, int value, PdfColor color, pw.Font font) {
    return pw.Container(
        width: 100,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: color, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: font,
                  fontSize: 14,
                  color: color,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('$value',
              style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  color: color,
                  fontWeight: pw.FontWeight.bold)),
        ]));
  }

  static pw.TableRow _buildEvaluationRow(String criteria, pw.Font font, String? value) {
    pw.Widget _checkbox(String targetValue) {
      return pw.Center(
        child: pw.Container(
          margin: const pw.EdgeInsets.all(8),
          width: 14,
          height: 14,
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600)),
          child: value == targetValue
              ? pw.Center(
                  child: pw.Text('X',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black)))
              : null,
        ),
      );
    }
    
    return pw.TableRow(
      children: [
        _buildTableCell(criteria, font, isHeader: true, center: false),
        _checkbox('ممتاز'),
        _checkbox('جيد جدًا'),
        _checkbox('جيد'),
        _checkbox('ضعيف'),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font font,
      {bool isHeader = false, bool center = false}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(text,
            textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            )));
  }

  static pw.Widget _buildCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    return pw.Container(
      alignment: align == pw.TextAlign.center 
          ? pw.Alignment.center 
          : (align == pw.TextAlign.left ? pw.Alignment.centerLeft : pw.Alignment.centerRight),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        textDirection: pw.TextDirection.rtl,
        softWrap: false,
        maxLines: 1,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
