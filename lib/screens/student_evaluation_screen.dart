import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student.dart';
import '../models/evaluation.dart';
import '../services/database_helper.dart';
import '../providers/teacher_provider.dart';
import 'dart:ui' as ui;

class StudentEvaluationScreen extends ConsumerStatefulWidget {
  final Student student;

  const StudentEvaluationScreen({super.key, required this.student});

  @override
  ConsumerState<StudentEvaluationScreen> createState() => _StudentEvaluationScreenState();
}

class _StudentEvaluationScreenState extends ConsumerState<StudentEvaluationScreen> {
  String _memorization = 'ممتاز';
  String _recitation = 'ممتاز';
  String _commitment = 'ممتاز';
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = true;
  int? _existingEvaluationId;

  final List<String> _evaluationOptions = ['ممتاز', 'جيد جدًا', 'جيد', 'ضعيف'];

  @override
  void initState() {
    super.initState();
    _loadEvaluation();
  }

  Future<void> _loadEvaluation() async {
    try {
      final evaluation = await DatabaseHelper.instance.getEvaluationByStudent(widget.student.id!);
      if (evaluation != null) {
        setState(() {
          _existingEvaluationId = evaluation.id;
          _memorization = _evaluationOptions.contains(evaluation.memorization) ? evaluation.memorization : 'ممتاز';
          _recitation = _evaluationOptions.contains(evaluation.recitation) ? evaluation.recitation : 'ممتاز';
          _commitment = _evaluationOptions.contains(evaluation.commitment) ? evaluation.commitment : 'ممتاز';
          _notesController.text = evaluation.notes ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading evaluation: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveEvaluation() async {
    setState(() => _isLoading = true);
    try {
      final evaluation = Evaluation(
        id: _existingEvaluationId,
        studentId: widget.student.id!,
        memorization: _memorization,
        recitation: _recitation,
        commitment: _commitment,
        notes: _notesController.text.trim(),
      );
      
      await DatabaseHelper.instance.saveEvaluation(evaluation);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التقييم بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // Find teacher name
    String teacherName = 'غير محدد';
    final teachersState = ref.watch(teachersProvider);
    if (teachersState is AsyncData && widget.student.halaqa != null && widget.student.halaqa!.trim().isNotEmpty) {
      for (var t in teachersState.value!) {
        if (t.halaqa == widget.student.halaqa) {
          teacherName = t.name;
          break;
        }
      }
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقييم الطالب'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student Info Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('الاسم: ${widget.student.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                Text('المعرف: ${widget.student.studentId ?? '-'}', style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('الحلقة: ${widget.student.halaqa ?? 'غير محدد'}', style: const TextStyle(fontSize: 16))),
                                Text('المعلم: $teacherName', style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text('التقييم المستمر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 16),
                    
                    _buildDropdownRow('الحفظ', _memorization, (val) => setState(() => _memorization = val!)),
                    const SizedBox(height: 12),
                    _buildDropdownRow('التلاوة', _recitation, (val) => setState(() => _recitation = val!)),
                    const SizedBox(height: 12),
                    _buildDropdownRow('الالتزام', _commitment, (val) => setState(() => _commitment = val!)),
                    
                    const SizedBox(height: 24),
                    Text('ملاحظات المعلم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'اكتب ملاحظاتك هنا...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveEvaluation,
                icon: const Icon(Icons.save),
                label: const Text('حفظ التقييم', style: TextStyle(fontSize: 18)),
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

  Widget _buildDropdownRow(String label, String value, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _evaluationOptions.map((opt) {
              return DropdownMenuItem(value: opt, child: Text(opt));
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
