import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../services/database_helper.dart';

class AttendanceState {
  final String date;
  final bool isLoading;
  final List<Student> students;
  final List<Teacher> teachers;
  final Map<String, String> attendanceMap;

  AttendanceState({
    required this.date,
    this.isLoading = false,
    this.students = const [],
    this.teachers = const [],
    this.attendanceMap = const {},
  });

  AttendanceState copyWith({
    String? date,
    bool? isLoading,
    List<Student>? students,
    List<Teacher>? teachers,
    Map<String, String>? attendanceMap,
  }) {
    return AttendanceState(
      date: date ?? this.date,
      isLoading: isLoading ?? this.isLoading,
      students: students ?? this.students,
      teachers: teachers ?? this.teachers,
      attendanceMap: attendanceMap ?? this.attendanceMap,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  AttendanceNotifier() : super(AttendanceState(date: _formatDate(DateTime.now()))) {
    loadDataForDate(DateTime.now());
  }

  static String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> loadDataForDate(DateTime date) async {
    final dateStr = _formatDate(date);
    state = state.copyWith(isLoading: true, date: dateStr);

    try {
      final students = await DatabaseHelper.instance.readAllStudents();
      final teachers = await DatabaseHelper.instance.readAllTeachers();
      final attendances = await DatabaseHelper.instance.readAttendanceByDate(dateStr);

      final Map<String, String> attMap = {};

      // Only preload variables if attendance already exists in DB for this date
      for (var a in attendances) {
        attMap['${a.type}_${a.personId}'] = a.status;
      }

      for (var a in attendances) {
        attMap['${a.type}_${a.personId}'] = a.status;
      }

      state = state.copyWith(
        isLoading: false,
        students: students,
        teachers: teachers,
        attendanceMap: attMap,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void updateStatus(String type, int personId, String status) {
    final key = '${type}_$personId';
    final newMap = Map<String, String>.from(state.attendanceMap);
    newMap[key] = status;
    state = state.copyWith(attendanceMap: newMap);
  }

  Future<void> saveAttendance() async {
    // Validate before saving: No empty status allowed
    final totalExpected = state.students.length + state.teachers.length;
    if (state.attendanceMap.length < totalExpected) {
      throw Exception('الرجاء التأكد من تسجيل الحضور والغياب لجميع الأفراد بلا استثناء.');
    }

    state = state.copyWith(isLoading: true);
    try {
      List<Attendance> recordsToSave = [];
      
      state.attendanceMap.forEach((key, status) {
        final parts = key.split('_');
        final type = parts[0];
        final id = int.parse(parts[1]);
        
        recordsToSave.add(Attendance(
          personId: id,
          type: type,
          date: state.date,
          status: status,
        ));
      });

      await DatabaseHelper.instance.saveDailyAttendance(recordsToSave);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier();
});
