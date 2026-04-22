import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/database_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isExporting = false;
  bool _isDbTransfer = false;

  Future<void> _exportToCsv() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black, // Pure OLED
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
              secondary: Colors.white,
              onSecondary: Colors.black,
              secondaryContainer: Colors.white12,
              primaryContainer: Colors.white12,
              onPrimaryContainer: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              iconTheme: IconThemeData(color: Colors.white),
            ),
            dividerTheme: const DividerThemeData(color: Colors.white12),
          ),
          child: child!,
        );
      },
    );

    if (range == null) return;

    setState(() { _isExporting = true; });

    try {
      final history = await DatabaseService().getHistoryBetween(
        range.start.millisecondsSinceEpoch,
        range.end.add(const Duration(days: 1)).millisecondsSinceEpoch - 1,
      );
      
      if (history.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No data available to export.', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
            backgroundColor: AppTheme.surfaceElevated,
          ),
        );
        setState(() { _isExporting = false; });
        return;
      }

      // Generate CSV string
      StringBuffer csvData = StringBuffer();
      csvData.write('\uFEFF'); // UTF-8 BOM for Microsoft Excel compatibility   
      csvData.writeln('Timestamp,Package Name,Category,Title,Content');

      for (var item in history) {
        // Escape quotes and commas for safe CSV formatting
        String timestamp = DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0).toIso8601String();
        String pkg = _escapeCsv(item['packageName'] ?? '');
        int cat = item['category'] ?? 0;
        String categoryString = cat == 0 ? 'Urgent' : (cat == 1 ? 'Buffer' : 'Spam');
        String title = _escapeCsv(item['title'] ?? '');
        String text = _escapeCsv(item['content'] ?? '');

        csvData.writeln('$timestamp,$pkg,$categoryString,$title,$text');
      }

      // Write to temp file
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/intent_audit_log.csv';
      final file = File(path);
      await file.writeAsString(csvData.toString());

      // Share via native intent
      await Share.shareXFiles([XFile(path)], text: 'Intent Notification Audit Log');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14)),
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );
    } finally {
      if (mounted) setState(() { _isExporting = false; });
    }
  }

  Future<void> _exportDb() async {
    setState(() { _isDbTransfer = true; });
    try {
      final path = await DatabaseService().exportDatabase();
      if (path != null && path.isNotEmpty) {
        await Share.shareXFiles([XFile(path)], text: 'Intent Database Backup');
      } else {
        throw Exception("Failed to generate backup.");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e', style: GoogleFonts.inter(color: Colors.redAccent))),
      );
    } finally {
      if (mounted) setState(() { _isDbTransfer = false; });
    }
  }

  Future<void> _importDb() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        setState(() { _isDbTransfer = true; });
        String filePath = result.files.single.path!;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importing Database. App will restart shortly...', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AppTheme.urgentAccent,
            duration: const Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 1500));
        await DatabaseService().importDatabase(filePath);
        // The Android side will forcefully execute System.exit(0) upon success to safely load the new Room DB.
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e', style: GoogleFonts.inter(color: Colors.redAccent))),
      );
      setState(() { _isDbTransfer = false; });
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity != 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'DATA MANAGEMENT',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                      CupertinoIcons.cloud_download,
                      color: Colors.white24,
                      size: 80,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Local Backup',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Export your notification analytics and history to a secure CSV file. No data ever leaves this device without your permission.',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 64),
                    
                    // Export to CSV Button
                    GestureDetector(
                      onTap: _isExporting || _isDbTransfer ? null : _exportToCsv,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        decoration: BoxDecoration(
                          color: _isExporting ? Colors.white10 : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        alignment: Alignment.center,
                        child: _isExporting
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : Text(
                                'Export to CSV',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 24),
                    Text(
                      'Cross-Device Migration',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Moving to a new phone? Backup your raw database and restore it to carry over your AI heuristic weights.',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _isExporting || _isDbTransfer ? null : _exportDb,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blueAccent, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: _isDbTransfer
                                  ? const CupertinoActivityIndicator(color: Colors.blueAccent)
                                  : Text(
                                      'Backup DB',
                                      style: GoogleFonts.inter(
                                        color: Colors.blueAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isExporting || _isDbTransfer ? null : _importDb,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              decoration: BoxDecoration(
                                color: AppTheme.urgentAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.urgentAccent, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Restore DB',
                                style: GoogleFonts.inter(
                                  color: AppTheme.urgentAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
