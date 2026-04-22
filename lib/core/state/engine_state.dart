import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineState {
  static final ValueNotifier<bool> isSmartModeActive = ValueNotifier<bool>(true);
  static final ValueNotifier<int> databaseUpdateTick = ValueNotifier<int>(0);

  static void notifyDatabaseUpdated() {
    databaseUpdateTick.value++;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isSmartModeActive.value = prefs.getBool('smart_mode_active') ?? true;
  }

  static Future<void> setSmartMode(bool value) async {
    isSmartModeActive.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_mode_active', value);
  }
}
