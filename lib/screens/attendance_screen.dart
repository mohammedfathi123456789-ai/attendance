import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../providers/attendance_provider.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);

    Future<void> _pickDate() async {
      final initialDate = DateTime.parse(state.date);
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        notifier.loadDataForDate(picked);
      }
    }

    Future<void> _saveData() async {
      try {
        await notifier.saveAttendance();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ الحضور والانصراف بنجاح')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
          );
        }
      }
    }

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasNoData = state.students.isEmpty && state.teachers.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الحضور'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
            tooltip: 'تغيير التاريخ',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تاريخ التحضير:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  state.date,
                  style: TextStyle(fontSize: 18, color: primaryColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: hasNoData
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'تنبيه: لا يوجد طلاب أو معلمين مضافين في النظام. الرجاء إضافتهم أولاً.',
                        style: TextStyle(fontSize: 18, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      if (state.teachers.isNotEmpty) ...[
                        _buildSectionHeader('المعلمين', Icons.school, primaryColor),
                        ...state.teachers.map((t) => _buildAttendanceRow(
                              name: t.name,
                              personId: t.id!,
                              type: 'teacher',
                              status: state.attendanceMap['teacher_${t.id}'] ?? '',
                              onChanged: (newStatus) {
                                notifier.updateStatus('teacher', t.id!, newStatus);
                              },
                            )),
                      ],
                      if (state.students.isNotEmpty) ...[
                        _buildSectionHeader('الطلاب', Icons.people_alt, primaryColor),
                        ...state.students.map((s) => _buildAttendanceRow(
                              name: s.name,
                              personId: s.id!,
                              type: 'student',
                              status: state.attendanceMap['student_${s.id}'] ?? '',
                              onChanged: (newStatus) {
                                notifier.updateStatus('student', s.id!, newStatus);
                              },
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: hasNoData
          ? null
          : FloatingActionButton.extended(
              onPressed: _saveData,
              label: const Text('حفظ السجل'),
              icon: const Icon(Icons.save),
              backgroundColor: primaryColor,
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade200,
      child: Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRow({
    required String name,
    required int personId,
    required String type,
    required String status,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRadioOption('حاضر', 'present', Colors.green, status, onChanged),
              _buildRadioOption('غائب', 'absent', Colors.red, status, onChanged),
              _buildRadioOption('مستأذن', 'excused', Colors.orange, status, onChanged),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildRadioOption(
      String label, String value, Color color, String currentStatus, ValueChanged<String> onChanged) {
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: currentStatus,
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
              activeColor: color,
            ),
            Expanded(
              child: AutoSizeText(
                label,
                style: TextStyle(
                  color: currentStatus == value ? color : Colors.black87,
                  fontWeight: currentStatus == value ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                minFontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
