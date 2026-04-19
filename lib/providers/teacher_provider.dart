import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/teacher.dart';
import '../services/database_helper.dart';

final teachersProvider = StateNotifierProvider<TeacherNotifier, AsyncValue<List<Teacher>>>((ref) {
  return TeacherNotifier();
});

class TeacherNotifier extends StateNotifier<AsyncValue<List<Teacher>>> {
  TeacherNotifier() : super(const AsyncValue.loading()) {
    loadTeachers();
  }

  Future<void> loadTeachers() async {
    try {
      final teachers = await DatabaseHelper.instance.readAllTeachers();
      state = AsyncValue.data(teachers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTeacher(String name, {String? halaqa}) async {
    try {
      final newTeacher = Teacher(name: name.trim(), halaqa: halaqa?.trim());
      await DatabaseHelper.instance.createTeacher(newTeacher);
      await loadTeachers(); // Refresh state
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTeacher(Teacher teacher) async {
    try {
      await DatabaseHelper.instance.updateTeacher(teacher);
      await loadTeachers(); // Refresh state
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTeacher(int id) async {
    try {
      await DatabaseHelper.instance.deleteTeacher(id);
      await loadTeachers(); // Refresh state
    } catch (e) {
      rethrow;
    }
  }
}
