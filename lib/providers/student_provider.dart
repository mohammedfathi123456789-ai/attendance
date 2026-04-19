import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student.dart';
import '../services/database_helper.dart';

final studentsProvider = StateNotifierProvider<StudentNotifier, AsyncValue<List<Student>>>((ref) {
  return StudentNotifier();
});

class StudentNotifier extends StateNotifier<AsyncValue<List<Student>>> {
  StudentNotifier() : super(const AsyncValue.loading()) {
    loadStudents();
  }

  Future<void> loadStudents() async {
    try {
      final students = await DatabaseHelper.instance.readAllStudents();
      state = AsyncValue.data(students);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addStudent(String name, {String? studentId, String? halaqa, String? photoPath}) async {
    try {
      final newStudent = Student(name: name.trim(), studentId: studentId, halaqa: halaqa, photoPath: photoPath);
      await DatabaseHelper.instance.createStudent(newStudent);
      await loadStudents(); // Refresh state
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStudent(Student student) async {
    try {
      await DatabaseHelper.instance.updateStudent(student);
      await loadStudents(); // Refresh state
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStudent(int id) async {
    try {
      await DatabaseHelper.instance.deleteStudent(id);
      await loadStudents(); // Refresh state
    } catch (e) {
      rethrow;
    }
  }
}
