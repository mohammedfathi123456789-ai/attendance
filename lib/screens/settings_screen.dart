import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';
import '../providers/setup_provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:auto_size_text/auto_size_text.dart';
import '../services/notification_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final colors = [
      Colors.teal,
      Colors.green,
      Colors.indigo,
      Colors.deepPurple,
      Colors.orange,
      Colors.blueGrey,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
        centerTitle: true,
        elevation: 0,
      ),
      body: settingsAsync.when(
        data: (settings) {
          final primaryColor = Color(settings.seedColorValue);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.05,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                            ),
                            itemBuilder: (context, index) => const Icon(Icons.star_border, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.settings, size: 70, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بيانات المسجد',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Consumer(builder: (context, ref, child) {
                        final mosqueSettings = ref.watch(settingsProvider);
                        return _SettingsCard(
                          child: mosqueSettings.when(
                            data: (settings) {
                              if (settings == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        final picker = ImagePicker();
                                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                                        if (pickedFile != null) {
                                          final appDir = await getApplicationDocumentsDirectory();
                                          final fileName = path.basename(pickedFile.path);
                                          final newPath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
                                          final file = File(pickedFile.path);
                                          final savedImage = await file.copy(newPath);
                                          await ref.read(settingsProvider.notifier).saveSettings(
                                            settings.name,
                                            savedImage.path,
                                          );
                                        }
                                      },
                                      child: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 40,
                                            backgroundImage: settings.logoPath.isNotEmpty ? FileImage(File(settings.logoPath)) as ImageProvider : null,
                                            backgroundColor: primaryColor.withOpacity(0.1),
                                            child: settings.logoPath.isEmpty ? Icon(Icons.mosque, size: 40, color: primaryColor) : null,
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      title: const Text('اسم الحلقة / المسجد', style: TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(settings.name),
                                      trailing: const Icon(Icons.edit),
                                      onTap: () {
                                        final controller = TextEditingController(text: settings.name);
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text('تغيير اسم المسجد'),
                                              content: TextField(
                                                controller: controller,
                                                decoration: const InputDecoration(labelText: 'اسم الحلقة / المسجد'),
                                                autofocus: true,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    final name = controller.text.trim();
                                                    if (name.isNotEmpty) {
                                                      await ref.read(settingsProvider.notifier).saveSettings(
                                                        name,
                                                        settings.logoPath,
                                                      );
                                                      if (context.mounted) {
                                                        Navigator.pop(context);
                                                      }
                                                    }
                                                  },
                                                  child: const Text('حفظ'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
                            error: (e, st) => const SizedBox.shrink(),
                          ),
                        );
                      }),
                      const SizedBox(height: 32),
                      const Text(
                        'المظهر العام',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _SettingsCard(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.dark_mode_outlined),
                              title: const Text('مظهر التطبيق'),
                              trailing: DropdownButton<ThemeMode>(
                                value: settings.themeMode,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: ThemeMode.light, child: Text('فاتح (Light)')),
                                  DropdownMenuItem(value: ThemeMode.dark, child: Text('داكن (Dark)')),
                                  DropdownMenuItem(value: ThemeMode.system, child: Text('تلقائي (System)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    ref.read(appSettingsProvider.notifier).updateThemeMode(val);
                                  }
                                },
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.language),
                              title: const Text('لغة التطبيق'),
                              trailing: DropdownButton<String>(
                                value: settings.languageCode,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                                  DropdownMenuItem(value: 'en', child: Text('English')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    ref.read(appSettingsProvider.notifier).updateLanguage(val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'الإشعارات اليومية',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _SettingsCard(
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('تفعيل التذكير اليومي'),
                              subtitle: const Text('تذكير يومي بتسجيل الحضور (باستثناء الخميس والجمعة)'),
                              value: settings.notificationsEnabled,
                              onChanged: (val) async {
                                if (val) {
                                  await NotificationService().requestPermissions();
                                }
                                ref.read(appSettingsProvider.notifier).updateNotificationSettings(val, settings.notificationTime);
                                await NotificationService().scheduleAttendanceReminder(time: settings.notificationTime, isEnabled: val);
                              },
                              activeColor: primaryColor,
                              secondary: const Icon(Icons.notifications_active_outlined),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.access_time),
                              title: const Text('وقت التذكير'),
                              subtitle: Text(settings.notificationTime.format(context)),
                              enabled: settings.notificationsEnabled,
                              trailing: const Icon(Icons.edit),
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: settings.notificationTime,
                                );
                                if (time != null) {
                                  ref.read(appSettingsProvider.notifier).updateNotificationSettings(settings.notificationsEnabled, time);
                                  await NotificationService().scheduleAttendanceReminder(time: time, isEnabled: settings.notificationsEnabled);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await NotificationService().showTestNotification();
                          },
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Test Notification (تجربة الإشعارات)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).cardColor,
                            foregroundColor: primaryColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'لون التطبيق الأساسي',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: colors.map((c) {
                            final isSelected = settings.seedColorValue == c.value;
                            return InkWell(
                              onTap: () {
                                ref.read(appSettingsProvider.notifier).updateSeedColor(c);
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: isSelected ? Border.all(color: isDark ? Colors.white : Colors.black87, width: 3) : null,
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(color: c.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)
                                  ],
                                ),
                                child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.go('/login');
                          },
                          icon: const Icon(Icons.logout),
                          label: const AutoSizeText('تسجيل الخروج من الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, minFontSize: 10),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade900,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('حدث خطأ أثناء تحميل الإعدادات: $error')),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
