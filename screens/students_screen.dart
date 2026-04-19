import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../providers/student_provider.dart';
import '../providers/teacher_provider.dart';
import '../models/student.dart';
import 'student_evaluation_screen.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  void _showStudentDialog([Student? student]) {
    final nameController = TextEditingController(text: student?.name ?? '');
    String? selectedHalaqa = student?.halaqa;
    String? photoPath = student?.photoPath;
    final isEditing = student != null;

    final teachersState = ref.read(teachersProvider);
    List<String> distinctHalaqas = [];
    if (teachersState is AsyncData) {
      distinctHalaqas = teachersState.value!
          .map((t) => t.halaqa?.trim() ?? '')
          .where((h) => h.isNotEmpty)
          .toSet()
          .toList();
    }
    
    if (selectedHalaqa != null && selectedHalaqa!.isNotEmpty && !distinctHalaqas.contains(selectedHalaqa)) {
      distinctHalaqas.add(selectedHalaqa!);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'تعديل بيانات الطالب' : 'إضافة طالب جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        
                        final source = await showModalBottomSheet<ImageSource>(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('التقاط صورة'),
                                  onTap: () => Navigator.pop(context, ImageSource.camera),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('اختيار من المعرض'),
                                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                                ),
                              ],
                            ),
                          ),
                        );
                        
                        if (source != null) {
                          final XFile? image = await picker.pickImage(source: source);
                          if (image != null) {
                            setState(() { photoPath = image.path; });
                          }
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: photoPath != null ? FileImage(File(photoPath!)) : null,
                        child: photoPath == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey) : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'اسم الطالب', prefixIcon: Icon(Icons.person)),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 8),
                    if (distinctHalaqas.isEmpty)
                      const Text('يرجى إضافة معلمين وتخصيص حلقات لهم أولاً', style: TextStyle(color: Colors.red, fontSize: 12))
                    else
                      DropdownButtonFormField<String>(
                        value: selectedHalaqa,
                        decoration: const InputDecoration(labelText: 'الحلقة / الصف', prefixIcon: Icon(Icons.class_)),
                        items: distinctHalaqas.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (val) {
                          setState(() { selectedHalaqa = val; });
                        },
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
                    if (name.isEmpty) return;
                    
                    final notifier = ref.read(studentsProvider.notifier);
                    Navigator.pop(context);
                    
                    try {
                      if (isEditing) {
                        await notifier.updateStudent(student.copyWith(
                          name: name,
                          halaqa: selectedHalaqa,
                          photoPath: photoPath,
                        ));
                      } else {
                        await notifier.addStudent(
                          name,
                          halaqa: selectedHalaqa,
                          photoPath: photoPath,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                      }
                    }
                  },
                  child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _confirmDelete(Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف الطالب "${student.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                ref.read(studentsProvider.notifier).deleteStudent(student.id!);
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
    final studentsState = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلاب'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentDialog(),
        label: const Text('إضافة طالب'),
        icon: const Icon(Icons.person_add),
      ),
      body: studentsState.when(
        data: (students) {
          if (students.isEmpty) {
            return const Center(
              child: Text('لا يوجد طلاب مضافين حتى الآن', 
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80, top: 12),
            itemCount: students.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  backgroundImage: student.photoPath != null ? FileImage(File(student.photoPath!)) : null,
                  child: student.photoPath == null ? Text(
                    '${index + 1}',
                    style: TextStyle(color: primaryColor),
                  ) : null,
                ),
                title: AutoSizeText(student.name, 
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1, minFontSize: 10,
                ),
                subtitle: AutoSizeText('${student.studentId ?? 'بدون معرف'} - ${student.halaqa ?? 'بدون حلقة'}',
                  maxLines: 1, minFontSize: 10,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.assignment, color: Colors.green),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => StudentEvaluationScreen(student: student)),
                        );
                      },
                      tooltip: 'تقييم',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showStudentDialog(student),
                      tooltip: 'تعديل',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(student),
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
