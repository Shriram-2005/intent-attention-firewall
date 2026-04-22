import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/saved_reports_screen.dart';
import '../../features/engine/presentation/screens/engine_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  static const String home = '/';
  static const String analytics = '/analytics';
  static const String notifications = '/notifications';
  static const String engine = '/engine';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';

  static GoRouter getRouter(bool hasSeenOnboarding) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: hasSeenOnboarding ? home : onboarding,
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: onboarding,
          name: 'onboarding',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OnboardingScreen(),
          ),
        ),
        StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: home,
                name: 'home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: analytics,
                name: 'analytics',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AnalyticsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: engine,
                name: 'engine',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: EngineScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: settings,
                name: 'settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'saved-reports',
                    name: 'saved_reports',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const SavedReportsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  }
}
