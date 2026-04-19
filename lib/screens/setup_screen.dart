import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:go_router/go_router.dart';
import '../providers/setup_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_size_text/auto_size_text.dart';
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _nameController = TextEditingController();
  File? _logoImage;
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveSetup() async {
    if (_formKey.currentState!.validate()) {
      if (_logoImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار شعار للمسجد')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(_logoImage!.path);
        // Ensure path uniqueness
        final newPath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        final savedImage = await _logoImage!.copy(newPath);

        await ref.read(settingsProvider.notifier).saveSettings(
          _nameController.text.trim(),
          savedImage.path,
        );

        if (mounted) {
          context.go('/dashboard');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد المسجد'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  backgroundImage: _logoImage != null ? FileImage(_logoImage!) : null,
                  child: _logoImage == null
                      ? Icon(Icons.add_a_photo, size: 40, color: primaryColor)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('اضغط لاختيار شعار المسجد')),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المسجد',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.mosque),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم المسجد';
                  }
                  return null;
                },
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSetup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const AutoSizeText('حفظ والانتقال للوحة التحكم', style: TextStyle(fontSize: 18), maxLines: 1, minFontSize: 10),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
