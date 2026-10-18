import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/state/engine_state.dart';
import 'core/services/local_notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Force portrait orientation for Android
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize SharedPreferences Memory, Core Engine State, and Global Theme
  await EngineState.init();
  await AppTheme.initTheme();

  // Edge-to-edge display
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: AppTheme.isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceDark,
      systemNavigationBarIconBrightness: AppTheme.isLight ? Brightness.dark : Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  await LocalNotificationService().init(AppRouter.rootNavigatorKey);

  runApp(
    IntentApp(hasSeenOnboarding: hasSeenOnboarding),
  );
}

class IntentApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const IntentApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, child) {
        return MaterialApp.router(
          title: 'Intent',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: AppRouter.getRouter(hasSeenOnboarding),
        );
      },
    );
  }
}
