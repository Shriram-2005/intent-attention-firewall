import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intent_app/core/state/engine_state.dart';
import 'package:intent_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EngineState Tests', () {
    test('SmartMode toggle updates listeners and persists', () async {
      await EngineState.init();
      expect(EngineState.isSmartModeActive.value, true);

      await EngineState.setSmartMode(false);
      expect(EngineState.isSmartModeActive.value, false);

      await EngineState.setSmartMode(true);
      expect(EngineState.isSmartModeActive.value, true);
    });

    test('Database tick notifier increments properly', () {
      final initial = EngineState.databaseUpdateTick.value;
      EngineState.notifyDatabaseUpdated();
      expect(EngineState.databaseUpdateTick.value, initial + 1);
    });
  });

  group('AppTheme Global Toggle Tests', () {
    test('Default theme starts in dark mode', () async {
      await AppTheme.initTheme();
      expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);
    });

    test('toggleTheme alternates between dark and light mode and flips all surface and text tokens', () async {
      await AppTheme.initTheme();
      expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);
      expect(AppTheme.isLight, false);
      expect(AppTheme.surfaceDark, const Color(0xFF000000));
      expect(AppTheme.textPrimary, const Color(0xFFFFFFFF));

      await AppTheme.toggleTheme();
      expect(AppTheme.themeModeNotifier.value, ThemeMode.light);
      expect(AppTheme.isLight, true);
      expect(AppTheme.surfaceDark, const Color(0xFFF6F6F9));
      expect(AppTheme.textPrimary, const Color(0xFF111111));
      expect(AppTheme.surfaceCard, const Color(0xFFFFFFFF));

      await AppTheme.toggleTheme();
      expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);
      expect(AppTheme.isLight, false);
      expect(AppTheme.surfaceDark, const Color(0xFF000000));
      expect(AppTheme.textPrimary, const Color(0xFFFFFFFF));
    });
  });
}
