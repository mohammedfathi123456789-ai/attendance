import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/report_service.dart';
import '../providers/teacher_provider.dart';
import '../providers/student_provider.dart';
import '../models/student.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:ui' as ui;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedRangeType = 'daily';
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();
  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  String _selectedReportType = 'attendance'; // 'attendance', 'halaqa', 'all_students', 'specific_halaqa_attendance', 'student_evaluation'
  String? _selectedHalaqa;
  String _selectedStudentEvaluationScope = 'all_students'; // 'all_students', 'specific_halaqa', 'specific_student'
  int? _selectedStudentId;

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedRangeType = 'custom';
      });
    }
  }

  void _updateRangeType(String type) {
    setState(() {
      _selectedRangeType = type;
      final now = DateTime.now();
      if (type == 'daily') {
        _startDate = now;
        _endDate = now;
      } else if (type == 'weekly') {
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _endDate = _startDate!.add(const Duration(days: 6));
      } else if (type == 'monthly') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
      } else if (type == 'yearly') {
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
      }
    });
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد فترة التقرير')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final startDateStr = _dateFormat.format(_startDate!);
      final endDateStr = _dateFormat.format(_endDate!);

      final settings = await DatabaseHelper.instance.getSettings();
      if (settings == null) throw Exception('الإعدادات غير متوفرة');

      final students = await DatabaseHelper.instance.readAllStudents();
      final teachers = await DatabaseHelper.instance.readAllTeachers();
      
      if (_selectedReportType == 'attendance' || _selectedReportType == 'specific_halaqa_attendance') {
        final attendanceRecords = await DatabaseHelper.instance.readAttendanceByDateRange(startDateStr, endDateStr);
        final distinctDates = attendanceRecords.map((a) => a.date).toSet().toList()..sort();

        String generateRangeText() {
          if (_startDate!.isAtSameMomentAs(_endDate!)) {
            return 'اليوم: $startDateStr';
          }
          return 'من: $startDateStr إلى: $endDateStr';
        }

        if (_selectedReportType == 'specific_halaqa_attendance') {
          if (_selectedHalaqa == null) throw Exception('الرجاء تحديث أو إضافة وتحديد حلقة');
          await ReportService.generateHalaqaAttendanceReport(
            settings: settings,
            dateRangeText: generateRangeText(),
            halaqaName: _selectedHalaqa!,
            students: students,
            attendanceRecords: attendanceRecords,
            distinctDates: distinctDates,
          );
        } else {
          await ReportService.generateAttendanceReport(
            settings: settings,
            dateRangeText: generateRangeText(),
            students: students,
            teachers: teachers,
            attendanceRecords: attendanceRecords,
            distinctDates: distinctDates,
          );
        }
      } else if (_selectedReportType == 'halaqa') {
        await ReportService.generateHalaqaReport(
          settings: settings,
          students: students,
          teachers: teachers,
        );
      } else if (_selectedReportType == 'all_students') {
        await ReportService.generateAllStudentsReport(
          settings: settings,
          students: students,
          teachers: teachers,
        );
      } else if (_selectedReportType == 'student_evaluation') {
        final attendanceRecords = await DatabaseHelper.instance.readAttendanceByDateRange(startDateStr, endDateStr);
        String generateRangeText() {
          if (_startDate!.isAtSameMomentAs(_endDate!)) {
            return 'اليوم: $startDateStr';
          }
          return 'من: $startDateStr إلى: $endDateStr';
        }

        List<Student> filteredStudents = students;
        if (_selectedStudentEvaluationScope == 'specific_student') {
          if (_selectedStudentId == null) throw Exception('الرجاء اختيار طالب');
          filteredStudents = students.where((s) => s.id == _selectedStudentId).toList();
        } else if (_selectedStudentEvaluationScope == 'specific_halaqa') {
          if (_selectedHalaqa == null) throw Exception('الرجاء اختيار حلقة');
          filteredStudents = students.where((s) => s.halaqa == _selectedHalaqa).toList();
        }

        await ReportService.generateStudentEvaluationReport(
          settings: settings,
          students: filteredStudents,
          teachers: teachers,
          attendanceRecords: attendanceRecords,
          dateRangeText: generateRangeText(),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء إنتاج التقرير: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إصدار التقارير'),
          centerTitle: true,
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Text(
                      'نوع التقرير',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildReportTypeChip('تقرير الحضور والغياب', 'attendance'),
                        _buildReportTypeChip('تقرير متابعة حلقة محددة', 'specific_halaqa_attendance'),
                        _buildReportTypeChip('تقرير الحلقات الكلي', 'halaqa'),
                        _buildReportTypeChip('تقرير جميع الطلاب', 'all_students'),
                        _buildReportTypeChip('تقرير تقييم الطلاب', 'student_evaluation'),
                      ],
                    ),
                    if (_selectedReportType == 'student_evaluation') ...[
                      const SizedBox(height: 16),
                      Text(
                        'نطاق التقييم',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('طالب محدد'),
                            selected: _selectedStudentEvaluationScope == 'specific_student',
                            onSelected: (val) { if (val) setState(() => _selectedStudentEvaluationScope = 'specific_student'); },
                          ),
                          ChoiceChip(
                            label: const Text('حلقة محددة'),
                            selected: _selectedStudentEvaluationScope == 'specific_halaqa',
                            onSelected: (val) { if (val) setState(() => _selectedStudentEvaluationScope = 'specific_halaqa'); },
                          ),
                          ChoiceChip(
                            label: const Text('جميع الطلاب'),
                            selected: _selectedStudentEvaluationScope == 'all_students',
                            onSelected: (val) { if (val) setState(() => _selectedStudentEvaluationScope = 'all_students'); },
                          ),
                        ],
                      ),
                      if (_selectedStudentEvaluationScope == 'specific_student') ...[
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final studentsState = ref.watch(studentsProvider);
                            if (studentsState is AsyncData) {
                              final studs = studentsState.value!;
                              if (studs.isEmpty) return const Center(child: Text('لا يوجد طلاب مضافين', style: TextStyle(color: Colors.red)));
                              
                              if (_selectedStudentId == null || !studs.any((s) => s.id == _selectedStudentId)) {
                                Future.microtask(() {
                                  if (mounted) setState(() => _selectedStudentId = studs.first.id);
                                });
                              }
                              
                              return DropdownButtonFormField<int>(
                                value: studs.any((s) => s.id == _selectedStudentId) ? _selectedStudentId : studs.first.id,
                                decoration: const InputDecoration(prefixIcon: Icon(Icons.person)),
                                items: studs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedStudentId = val);
                                },
                              );
                            }
                            return const Center(child: CircularProgressIndicator());
                          }
                        ),
                      ],
                    ],
                    if (_selectedReportType == 'specific_halaqa_attendance' || (_selectedReportType == 'student_evaluation' && _selectedStudentEvaluationScope == 'specific_halaqa')) ...[
                      const SizedBox(height: 16),
                      Text(
                        'اختر الحلقة المطلوبة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final teachersState = ref.watch(teachersProvider);
                          List<String> halaqas = [];
                          if (teachersState is AsyncData) {
                            halaqas = teachersState.value!
                                .map((t) => t.halaqa?.trim() ?? '')
                                .where((h) => h.isNotEmpty)
                                .toSet()
                                .toList();
                          }
                          if (halaqas.isEmpty) {
                            return const Center(child: Text('لا توجد حلقات مضافة حالياً', style: TextStyle(color: Colors.red)));
                          }
                          
                          if (_selectedHalaqa == null || !halaqas.contains(_selectedHalaqa)) {
                            // Defer state update to avoid build collisions
                            Future.microtask(() {
                              if (mounted) setState(() => _selectedHalaqa = halaqas.first);
                            });
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: halaqas.contains(_selectedHalaqa) ? _selectedHalaqa : halaqas.first,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.class_)),
                            items: halaqas.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                            onChanged: (val) {
                              setState(() => _selectedHalaqa = val);
                            },
                          );
                        }
                      ),
                    ],
                    if (_selectedReportType == 'attendance' || _selectedReportType == 'specific_halaqa_attendance' || _selectedReportType == 'student_evaluation') ...[
                      const SizedBox(height: 24),
                      Text(
                        'اختر فترة التقرير',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTypeChip('يومي', 'daily'),
                          _buildTypeChip('أسبوعي', 'weekly'),
                          _buildTypeChip('شهري', 'monthly'),
                          _buildTypeChip('سنوي', 'yearly'),
                          _buildTypeChip('مخصص', 'custom'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_selectedRangeType == 'custom')
                        ElevatedButton.icon(
                          onPressed: () => _selectDateRange(context),
                          icon: const Icon(Icons.date_range),
                          label: Text(_startDate != null && _endDate != null
                              ? '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}'
                              : 'تحديد التاريخ المخصص'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor.withOpacity(0.1),
                            foregroundColor: primaryColor,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateReport,
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.picture_as_pdf),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const AutoSizeText('توليد التقرير PDF', style: TextStyle(fontSize: 18), maxLines: 1, minFontSize: 10),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildReportTypeChip(String label, String value) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSelected = _selectedReportType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedReportType = value);
      },
      selectedColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSelected = _selectedRangeType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _updateRangeType(value);
      },
      selectedColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
