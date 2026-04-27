import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/theme/app_theme.dart';

class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  List<File> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final files = docDir.listSync();
      _reports = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.pdf'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _deleteReport(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        _loadReports();
      }
    } catch (_) {}
  }

  Future<void> _shareReport(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Focus Analytics AI Report');
    } catch (_) {}
  }

  Future<void> _renameFile(File file) async {
    TextEditingController controller = TextEditingController(text: file.path.split('/').last.replaceAll('.pdf', ''));
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: Text('Rename Report', style: GoogleFonts.inter(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new name',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Rename', style: TextStyle(color: Colors.orangeAccent)),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.trim().isNotEmpty) {
      try {
        final newPath = file.path.replaceFirst(file.path.split(Platform.pathSeparator).last, '${newName.trim()}.pdf');
        await file.rename(newPath);
        _loadReports();
      } catch (_) {}
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            'No saved reports yet',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a report from the Analytics tab',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: Text('Saved Reports', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white10, height: 1.0),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _reports.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _reports.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    final fileName = report.path.split(Platform.pathSeparator).last;
                    final size = (report.lengthSync() / 1024).toStringAsFixed(1);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.orangeAccent, size: 32),
                      title: Text(fileName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                      subtitle: Text('${report.lastModifiedSync().toString().split('.')[0]} • $size KB', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: AppTheme.surfaceElevated,
                        onSelected: (value) {
                          if (value == 'share') _shareReport(report);
                          if (value == 'rename') _renameFile(report);
                          if (value == 'delete') _deleteReport(report);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(children: [Icon(Icons.share, color: Colors.white, size: 18), SizedBox(width: 8), Text('Share', style: TextStyle(color: Colors.white))]),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(children: [Icon(Icons.edit, color: Colors.white, size: 18), SizedBox(width: 8), Text('Rename', style: TextStyle(color: Colors.white))]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))]),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final result = await OpenFilex.open(report.path);
                        if (result.type != ResultType.done && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open file: ${result.message}'),
                              backgroundColor: AppTheme.urgentAccent,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}
