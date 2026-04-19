import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/student_provider.dart';
import '../providers/setup_provider.dart';
import '../models/student.dart';
import '../services/id_card_service.dart';
import 'package:auto_size_text/auto_size_text.dart';

class IdCardScreen extends ConsumerStatefulWidget {
  const IdCardScreen({super.key});

  @override
  ConsumerState<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends ConsumerState<IdCardScreen> {
  String _selectedHalaqa = 'الكل';
  bool _selectAll = false;
  final Set<int> _selectedStudentIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final studentsState = ref.watch(studentsProvider);
    final settingsState = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بطاقات الطلاب (ID Cards)'),
        centerTitle: true,
      ),
      body: studentsState.when(
        data: (students) {
          // Extract halaqas
          final halaqas = {'الكل'};
          for (var s in students) {
            if (s.halaqa != null && s.halaqa!.isNotEmpty) {
              halaqas.add(s.halaqa!);
            }
          }

          // Filter students
          var filteredStudents = students.where((s) {
            final matchesHalaqa = _selectedHalaqa == 'الكل' || s.halaqa == _selectedHalaqa;
            final matchesSearch = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                  (s.studentId != null && s.studentId!.toLowerCase().contains(_searchQuery.toLowerCase()));
            return matchesHalaqa && matchesSearch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'بحث بالاسم او المعرف',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedHalaqa,
                        decoration: const InputDecoration(
                          labelText: 'الحلقة / الصف',
                          border: OutlineInputBorder(),
                        ),
                        items: halaqas.map((h) => DropdownMenuItem(value: h, child: AutoSizeText(h, maxLines: 1, minFontSize: 10, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedHalaqa = val;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selectAll,
                      onChanged: (val) {
                        setState(() {
                          _selectAll = val ?? false;
                          if (_selectAll) {
                            _selectedStudentIds.addAll(filteredStudents.map((s) => s.id!));
                          } else {
                            _selectedStudentIds.clear();
                          }
                        });
                      },
                    ),
                    const Text('تحديد الكل'),
                    const Spacer(),
                    Expanded(
                      child: Text('${_selectedStudentIds.length} طالب محدد', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: filteredStudents.isEmpty
                    ? const Center(child: Text('لا توجد بيانات مطابقة'))
                    : ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final isSelected = _selectedStudentIds.contains(student.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedStudentIds.add(student.id!);
                                } else {
                                  _selectedStudentIds.remove(student.id!);
                                  _selectAll = false;
                                }
                              });
                            },
                            title: AutoSizeText(student.name, maxLines: 1, minFontSize: 10),
                            subtitle: AutoSizeText('${student.studentId ?? 'بدون معرف'} - ${student.halaqa ?? 'بدون حلقة'}', maxLines: 1, minFontSize: 10),
                            secondary: student.photoPath != null && student.photoPath!.isNotEmpty
                                ? CircleAvatar(backgroundImage: FileImage(File(student.photoPath!)))
                                : const CircleAvatar(child: Icon(Icons.person)),
                          );
                        },
                      ),
              ),
              if (_selectedStudentIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const AutoSizeText('تصدير PDF (ملف)', maxLines: 1, minFontSize: 10),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                          onPressed: () {
                            if (settingsState.value == null) return;
                            final selected = students.where((s) => _selectedStudentIds.contains(s.id)).toList();
                            IdCardService.generateIDCardsPdf(selected, settingsState.value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.image),
                          label: const AutoSizeText('تصدير صور (PNG)', maxLines: 1, minFontSize: 10),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () {
                            if (settingsState.value == null) return;
                            final selected = students.where((s) => _selectedStudentIds.contains(s.id)).toList();
                            IdCardService.exportIdCardsAsPngs(selected, settingsState.value!, context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
