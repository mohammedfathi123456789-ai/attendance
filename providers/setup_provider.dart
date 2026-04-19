import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../models/mosque_settings.dart';

final isFirstLaunchProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('is_first_launch') ?? true;
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<MosqueSettings?>>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AsyncValue<MosqueSettings?>> {
  SettingsNotifier() : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveSettings(String name, String logoPath) async {
    state = const AsyncValue.loading();
    try {
      final settings = MosqueSettings(name: name, logoPath: logoPath);
      final savedSettings = await DatabaseHelper.instance.saveSettings(settings);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_launch', false);
      
      state = AsyncValue.data(savedSettings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
