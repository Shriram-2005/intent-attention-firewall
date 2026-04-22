import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: Center(
        child: Text(
          'Notifications Screen — Mock UI coming soon',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
