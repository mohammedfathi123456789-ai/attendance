import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class AppSettings {
  final String languageCode; // 'ar' or 'en'
  final ThemeMode themeMode;
  final int seedColorValue;
  final bool notificationsEnabled;
  final TimeOfDay notificationTime;

  const AppSettings({
    required this.languageCode,
    required this.themeMode,
    required this.seedColorValue,
    required this.notificationsEnabled,
    required this.notificationTime,
  });

  AppSettings copyWith({
    String? languageCode,
    ThemeMode? themeMode,
    int? seedColorValue,
    bool? notificationsEnabled,
    TimeOfDay? notificationTime,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  AppSettingsNotifier() : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_lang') ?? 'ar';
      final themeStr = prefs.getString('app_theme') ?? 'light';
      final colorVal = prefs.getInt('app_color') ?? Colors.teal.value;
      final notifEnabled = prefs.getBool('app_notif_enabled') ?? false;
      final notifHour = prefs.getInt('app_notif_hour') ?? 16;
      final notifMinute = prefs.getInt('app_notif_minute') ?? 0;

      ThemeMode mode;
      switch (themeStr) {
        case 'light': mode = ThemeMode.light; break;
        case 'dark': mode = ThemeMode.dark; break;
        case 'system': mode = ThemeMode.system; break;
        default: mode = ThemeMode.system; break;
      }

      state = AsyncValue.data(AppSettings(
        languageCode: lang,
        themeMode: mode,
        seedColorValue: colorVal,
        notificationsEnabled: notifEnabled,
        notificationTime: TimeOfDay(hour: notifHour, minute: notifMinute),
      ));

      if (notifEnabled) {
        // We import notification service at the top and call it here.
        // It's safe to do this here because we want to make sure
        // alarms are re-scheduled if they were lost due to app update or force stop.
        NotificationService().requestPermissions();
        NotificationService().scheduleAttendanceReminder(
          time: TimeOfDay(hour: notifHour, minute: notifMinute),
          isEnabled: notifEnabled,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', code);
    if (state is AsyncData) {
      state = AsyncValue.data(state.value!.copyWith(languageCode: code));
    } else {
      await _loadSettings();
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', mode.name);
    if (state is AsyncData) {
      state = AsyncValue.data(state.value!.copyWith(themeMode: mode));
    } else {
      await _loadSettings();
    }
  }

  Future<void> updateSeedColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_color', color.value);
    if (state is AsyncData) {
      state = AsyncValue.data(state.value!.copyWith(seedColorValue: color.value));
    } else {
      await _loadSettings();
    }
  }

  Future<void> updateNotificationSettings(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_notif_enabled', enabled);
    await prefs.setInt('app_notif_hour', time.hour);
    await prefs.setInt('app_notif_minute', time.minute);
    
    if (state is AsyncData) {
      state = AsyncValue.data(state.value!.copyWith(
        notificationsEnabled: enabled,
        notificationTime: time,
      ));
    } else {
      await _loadSettings();
    }
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return AppSettingsNotifier();
});
