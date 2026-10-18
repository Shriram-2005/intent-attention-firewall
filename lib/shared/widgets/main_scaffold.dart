import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/engine_state.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        navigationShell.goBranch(0);
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceDark,
      body: ValueListenableBuilder<bool>(
        valueListenable: EngineState.isSmartModeActive,
        builder: (context, isActive, child) {
          final isLocked = !isActive && navigationShell.currentIndex != 0;
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity == 0) return;
                  
                  final currentIndex = navigationShell.currentIndex;
                  // Swipe left (negative velocity) -> next tab
                  if (velocity < 0 && currentIndex < 3) {
                    navigationShell.goBranch(currentIndex + 1);
                  } 
                  // Swipe right (positive velocity) -> previous tab
                  else if (velocity > 0 && currentIndex > 0) {
                    navigationShell.goBranch(currentIndex - 1);
                  }
                },
                child: navigationShell,
              ),
              if (isLocked)
                Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: Container(color: AppTheme.surfaceDark.withValues(alpha: 0.97)),
                  ),
                ),
              if (isLocked)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: AppTheme.textSecondary, size: 64),
                          const SizedBox(height: 24),
                          Text(
                            'ENGINE OFFLINE',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'The neural filtering engine is currently suspended. Sub-systems cannot be accessed while the engine is physically disconnected.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 48),
                          GestureDetector(
                            onTap: () {
                              EngineState.setSmartMode(true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: AppTheme.surfaceBorder),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'WAKE ENGINE',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeModeNotifier,
        builder: (context, themeMode, _) {
          final isDark = themeMode == ThemeMode.dark;
          final navBg = AppTheme.surfaceDark;
          final activeIconColor = AppTheme.textPrimary;
          final inactiveIconColor = AppTheme.textMuted;

          return Container(
            color: navBg,
            padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNavItem(0, CupertinoIcons.home, activeIconColor, inactiveIconColor),
                  _buildNavItem(1, CupertinoIcons.chart_bar, activeIconColor, inactiveIconColor),
                  _buildNavItem(2, Icons.bolt_outlined, activeIconColor, inactiveIconColor),
                  _buildNavItem(3, CupertinoIcons.slider_horizontal_3, activeIconColor, inactiveIconColor),
                  _buildThemeToggle(isDark),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, Color activeColor, Color inactiveColor) {
    final bool isActive = navigationShell.currentIndex == index;
    return GestureDetector(
      onTap: () {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? activeColor : inactiveColor,
            size: 24,
          ),
          const SizedBox(height: 6),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? activeColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        AppTheme.toggleTheme();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon_fill,
              key: ValueKey<bool>(isDark),
              color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF5E5CE6),
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
