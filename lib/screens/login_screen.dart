import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../providers/setup_provider.dart';
import '../providers/student_provider.dart';
import '../providers/teacher_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/attendance_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoginMode = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('accounts_map') ?? '{}';
    Map<String, dynamic> users = jsonDecode(usersJson);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (_isLoginMode) {
      bool valid = false;
      if (users.containsKey(username) && users[username] == password) {
        valid = true;
      }

      // Fallback for old accounts
      if (!valid && username == (prefs.getString('admin_username') ?? 'aaa') && password == (prefs.getString('admin_password') ?? '123')) {
        valid = true;
        users[username] = password;
        await prefs.setString('accounts_map', jsonEncode(users));
      }

      if (valid) {
        DatabaseHelper.setDatabaseName(username);
        _invalidateProviders();

        if (mounted) {
          final settings = await DatabaseHelper.instance.getSettings();
          if (settings == null) {
            context.go('/setup');
          } else {
            context.go('/dashboard');
          }
        }
      } else {
        setState(() => _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة');
      }
    } else {
      // Register Mode
      if (users.containsKey(username) || username == (prefs.getString('admin_username') ?? 'aaa')) {
        setState(() => _errorMessage = 'اسم المستخدم موجود مسبقاً');
      } else {
        users[username] = password;
        await prefs.setString('accounts_map', jsonEncode(users));
        DatabaseHelper.setDatabaseName(username);
        _invalidateProviders();

        if (mounted) context.go('/setup');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _invalidateProviders() {
    ref.invalidate(settingsProvider);
    ref.invalidate(studentsProvider);
    ref.invalidate(teachersProvider);
    ref.invalidate(attendanceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [theme.colorScheme.surface, theme.scaffoldBackgroundColor] 
              : [primaryGreen.withOpacity(0.05), primaryGreen.withOpacity(0.12)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: primaryGreen.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mosque, size: 70, color: primaryGreen),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد', 
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryGreen),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم',
                        prefixIcon: Icon(Icons.person_outline, color: primaryGreen),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'مطلوب إدخال اسم المستخدم' : null,
                    ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock_outline, color: primaryGreen),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'مطلوب إدخال كلمة المرور' : null,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen, 
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: primaryGreen.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                        : Text(_isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isLoginMode ? 'ليس لديك حساب؟ إنشاء حساب جديد' : 'لديك حساب مسجل؟ تسجيل الدخول',
                      style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
