import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/teacher_provider.dart';
import '../models/teacher.dart';
import 'package:auto_size_text/auto_size_text.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  void _showTeacherDialog([Teacher? teacher]) {
    final nameController = TextEditingController(text: teacher?.name ?? '');
    final halaqaController = TextEditingController(text: teacher?.halaqa ?? '');
    final isEditing = teacher != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'تعديل بيانات المعلم' : 'إضافة معلم جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المعلم',
                    prefixIcon: Icon(Icons.school),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: halaqaController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحلقة المخصصة',
                    prefixIcon: Icon(Icons.class_),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final halaqa = halaqaController.text.trim();
                if (name.isEmpty) return;
                
                final notifier = ref.read(teachersProvider.notifier);
                Navigator.pop(context);
                
                try {
                  if (isEditing) {
                    await notifier.updateTeacher(teacher.copyWith(name: name, halaqa: halaqa.isEmpty ? null : halaqa));
                  } else {
                    await notifier.addTeacher(name, halaqa: halaqa.isEmpty ? null : halaqa);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ: $e')),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(Teacher teacher) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف المعلم "${teacher.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                ref.read(teachersProvider.notifier).deleteTeacher(teacher.id!);
                Navigator.pop(context);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final teachersState = ref.watch(teachersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المعلمين'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTeacherDialog(),
        label: const Text('إضافة معلم'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      body: teachersState.when(
        data: (teachers) {
          if (teachers.isEmpty) {
            return const Center(
              child: Text('لا يوجد معلمين مضافين حتى الآن', 
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80, top: 12),
            itemCount: teachers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(Icons.school, color: primaryColor),
                ),
                title: AutoSizeText(teacher.name, 
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1, minFontSize: 10,
                ),
                subtitle: AutoSizeText(
                  '${teacher.teacherId ?? 'بدون معرف'} - ${teacher.halaqa?.isNotEmpty == true ? teacher.halaqa : 'بدون حلقة'}',
                  maxLines: 1, minFontSize: 10,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showTeacherDialog(teacher),
                      tooltip: 'تعديل',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(teacher),
                      tooltip: 'حذف',
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('خطأ: $error')),
      ),
    );
  }
}
