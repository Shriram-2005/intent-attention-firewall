import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/engine_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/database_service.dart';
import 'vip_manager_screen.dart';
import 'history_screen.dart';
import 'saved_reports_screen.dart';
import 'export_screen.dart';
import 'training_screen.dart';
import 'telemetry_screen.dart';
import 'support_bottom_sheet.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _bufferInterval = 24;
  int _historyRetentionDays = 0;
  int _bufferSummaryCount = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bufferInterval = prefs.getInt('buffer_interval') ?? 24;
      _historyRetentionDays = prefs.getInt('flutter.history_retention_days') ?? 0;
      _bufferSummaryCount = prefs.getInt('buffer_max_lines') ?? 5;
    });
  }

  Future<void> _updateInterval(int hours) async {
    setState(() {
      _bufferInterval = hours;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('buffer_interval', hours);
    await DatabaseService().updateSummaryInterval(hours);
  }

  Future<void> _updateRetention(int days) async {
    setState(() {
      _historyRetentionDays = days;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('flutter.history_retention_days', days);
  }

  Future<void> _updateBufferCount(int count) async {
    setState(() {
      _bufferSummaryCount = count;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('buffer_max_lines', count);
  }

  Future<void> _showPurgeDataModal(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          title: Text('CRUCIAL WARNING', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          content: Text(
            'Warning: Purging data permanently removes ALL intercepted data and log history from the local database. You will not be able to recover or export these logs.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseService().deleteAllHistory();
                final prefs = await SharedPreferences.getInstance();
                // We keep some prefs, but we can clean out VIP or others if requested. 
                // Mostly the user just wants the "database" flushed for factory reset.
                // We'll trust deleteAllHistory() handles the db. 
                EngineState.notifyDatabaseUpdated();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('All Data Purged Successfully.', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: Colors.redAccent),
                );
              },
              child: Text('PURGE EVERYTHING', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 32.0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 56),
            Expanded(
              child: RawScrollbar(
                thumbVisibility: true,
                thickness: 4.0,
                radius: const Radius.circular(10),
                thumbColor: Colors.white.withOpacity(0.5),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 32.0),
                  children: [
                    _buildSectionHeader('AI DIRECTIVES'),
                    const SizedBox(height: 16),
                    _buildSettingsRow(
                      title: 'Engine Rules',
                      subtitle: "Manage VIP bypasses and ML heuristic keywords.",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const VipManagerScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      title: 'Notification History',
                      subtitle: 'View a secure log of all intercepted and muted distractions.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HistoryScreen()),
                        );
                      },
                    ),                      _buildDivider(),
                      _buildSettingsRow(
                        title: 'End of Day Report Time',
                        subtitle: 'Configure when the background worker fires the evening notification.',
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final h = prefs.getInt('eod_hour') ?? 21;
                          final m = prefs.getInt('eod_minute') ?? 0;
                          final time = await showTimePicker(
  context: context,
  initialTime: TimeOfDay(hour: h, minute: m),
  builder: (context, child) {
    return Theme(
      data: Theme.of(context).copyWith(
        timePickerTheme: TimePickerThemeData(
          dialHandColor: Colors.orangeAccent,
          hourMinuteColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.orangeAccent.withValues(alpha: 0.3) : AppTheme.surfaceElevated),
          hourMinuteTextColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.orangeAccent : Colors.white),
          dayPeriodColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.orangeAccent.withValues(alpha: 0.3) : AppTheme.surfaceDark),
          dayPeriodTextColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.orangeAccent : Colors.white),
          dialBackgroundColor: AppTheme.surfaceElevated,
          dialTextColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.black : Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.orangeAccent,
          onPrimary: Colors.black,
          surface: AppTheme.surfaceDark,
          onSurface: Colors.white,
          surfaceContainer: AppTheme.surfaceDark,
          surfaceContainerHighest: AppTheme.surfaceElevated,
          surfaceContainerHigh: AppTheme.surfaceElevated,
        ),
      ),
      child: child!,
    );
  },
);
                          if (time != null) {
                            await prefs.setInt('eod_hour', time.hour);
                            await prefs.setInt('eod_minute', time.minute);
                            await DatabaseService().updateEndOfDayTime(time.hour, time.minute);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Saved: EOD Report will fire at ${time.format(context)}')),
                              );
                            }
                          }
                        }
                      ),                    const SizedBox(height: 48),
                    _buildSectionHeader('HARDWARE TELEMETRY'),
                    const SizedBox(height: 16),
                    _buildSettingsRow(
                      title: 'Live Sensor Stream',
                      subtitle: 'View raw GPS and Compass data powering the Do-or-Die driving safety matrix.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TelemetryScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 48),
                    _buildSectionHeader('BUFFER CONFIGURATION'),
                    const SizedBox(height: 16),
                    Text('Delivery Interval', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    _buildDropdownSetting(),
                    const SizedBox(height: 24),
                    Text('Grouped Messages Limit', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    Text('Maximum number of buffered messages shown on the lock screen.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w300, height: 1.4)),
                    const SizedBox(height: 16),
                    _buildBufferCountDropdown(),
                    const SizedBox(height: 48),
                    _buildSectionHeader('DATA & MEMORY'),
                    const SizedBox(height: 16),
                    _buildSettingsRow(                        title: 'Saved Reports',
                        subtitle: 'View, rename, share, or delete your generated AI diagnostic PDFs.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SavedReportsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsRow(                      title: 'Backup & Export',
                      subtitle: 'Export your local notification analytics and history to CSV.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ExportScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Auto-Delete History', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    Text('Automatically purge history logs exceeding the selected retention timeframe.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w300, height: 1.4)),
                    const SizedBox(height: 16),
                    _buildRetentionDropdown(),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => _showPurgeDataModal(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent, width: 1),
                        ),
                        child: Center(
                          child: Text('PURGE DATA', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildSectionHeader('SYSTEM WARM-UP'),
                    const SizedBox(height: 16),
                    _buildSettingsRow(
                      title: 'Review Concept',
                      subtitle: 'Re-launch the initial visual introduction to the Sanctuary engine.',
                      onTap: () {
                        context.push('/onboarding');
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      title: 'How to Train Intent',
                      subtitle: 'Re-learn how to dynamically teach the engine using your Notification History.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TrainingScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 48),
                    _buildSectionHeader('SUPPORT INTENT LABS'),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _showSupportBottomSheet(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Support the Developer',
                              style: GoogleFonts.inter(
                                color: Colors.orangeAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Help keep Intent free and independent forever.',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'PREFERENCES',
      style: GoogleFonts.inter(
        color: AppTheme.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w300,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white38,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(
        color: Colors.white12,
        thickness: 1,
      ),
    );
  }

  Widget _buildSettingsRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSetting() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white24, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _bufferInterval,
          dropdownColor: Colors.black87,
          icon: const Icon(CupertinoIcons.chevron_down, color: Colors.white54, size: 16),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              _updateInterval(newValue);
            }
          },
          items: const [
            DropdownMenuItem(value: 1, child: Text('Micro-Buffer (15 mins)')),
            DropdownMenuItem(value: 4, child: Text('Every 4 Hours')),
            DropdownMenuItem(value: 8, child: Text('Every 8 Hours')),
            DropdownMenuItem(value: 12, child: Text('Twice a Day (12 Hours)')),
            DropdownMenuItem(value: 24, child: Text('Daily Summary (24 Hours)')),
          ],
        ),
      ),
    );
  }

  Widget _buildBufferCountDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white24, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _bufferSummaryCount,
          dropdownColor: Colors.black87,
          icon: const Icon(CupertinoIcons.chevron_down, color: Colors.white54, size: 16),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              _updateBufferCount(newValue);
            }
          },
          items: const [
            DropdownMenuItem(value: 3, child: Text('3 Messages')),
            DropdownMenuItem(value: 5, child: Text('5 Messages (Optimal)')),
            DropdownMenuItem(value: 10, child: Text('10 Messages')),
            DropdownMenuItem(value: 15, child: Text('15 Messages')),
          ],
        ),
      ),
    );
  }





  void _showSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SupportBottomSheet(),
    );
  }

  Widget _buildRetentionDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white24, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _historyRetentionDays,
          dropdownColor: Colors.black87,
          icon: const Icon(CupertinoIcons.chevron_down, color: Colors.white54, size: 16),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              _updateRetention(newValue);
            }
          },
          items: const [
            DropdownMenuItem(value: 0, child: Text('Never Auto-Delete')),
            DropdownMenuItem(value: 1, child: Text('Delete after 24 Hours')),
            DropdownMenuItem(value: 7, child: Text('Delete after 7 Days')),
            DropdownMenuItem(value: 30, child: Text('Delete after 30 Days')),
            DropdownMenuItem(value: 365, child: Text('Delete after 1 Year')),
          ],
        ),
      ),
    );
  }
}



