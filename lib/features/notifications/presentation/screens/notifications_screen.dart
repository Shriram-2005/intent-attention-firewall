import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off_outlined, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'No new alerts',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
