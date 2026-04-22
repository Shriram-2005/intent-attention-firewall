import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/state/engine_state.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  final int? initialCategoryFilter;
  
  const HistoryScreen({super.key, this.initialCategoryFilter});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _historyData = [];
  int? _selectedCategoryFilter;
  String? _selectedPackageFilter;
  DateTimeRange? _selectedDateRange;
  bool _isLoading = true;

  String _getAppName(String? packageName) {
    if (packageName == null) return "System";
    final pkg = packageName.toLowerCase();
    if (pkg.contains("whatsapp")) return "WhatsApp";
    if (pkg.contains("telegram")) return "Telegram";
    if (pkg.contains("gm") || pkg.contains("mail")) return "Gmail";
    if (pkg.contains("messaging") || pkg.contains("mms") || pkg.contains("sms")) return "Messages";
    if (pkg.contains("instagram")) return "Instagram";
    if (pkg.contains("discord")) return "Discord";
    if (pkg.contains("twitter") || pkg.contains("x")) return "X (Twitter)";
    
    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      final name = parts.last;
      return name[0].toUpperCase() + name.substring(1).toLowerCase();
    }
    return packageName;
  }

  // Computed getter to dynamically filter available packages
  List<String> get _currentPackages {
    final Set<String> packages = {};
    for (var item in _historyData) {
      bool categoryMatch = _selectedCategoryFilter == null;
      if (!categoryMatch) {
        if (_selectedCategoryFilter == 3) {
          final content = ((item['title'] ?? '') + ' ' + (item['text'] ?? '')).toLowerCase();
          categoryMatch = content.contains('otp') || content.contains('code') || 
                          content.contains('verification') || content.contains('password') || 
                          content.contains('security') || content.contains('login') || 
                          content.contains('alert') || content.contains('reset');
        } else {
          categoryMatch = item['category'] == _selectedCategoryFilter;
        }
      }
      
      if (categoryMatch) {
        if (item['packageName'] != null) {
          packages.add(item['packageName']);
        }
      }
    }
    return packages.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryFilter = widget.initialCategoryFilter;
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day));
WidgetsBinding.instance.addObserver(this);
    EngineState.databaseUpdateTick.addListener(_pollHistory);
    _pollHistory();
  }

  @override
  void dispose() {
    EngineState.databaseUpdateTick.removeListener(_pollHistory);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollHistory();
    }
  }

  Future<void> _pollHistory() async {
    List<Map<String, dynamic>> data;
    if (_selectedDateRange == null) {
      data = await DatabaseService().getHistory();
    } else {
      data = await DatabaseService().getHistoryBetween(
        _selectedDateRange!.start.millisecondsSinceEpoch,
        _selectedDateRange!.end.add(const Duration(days: 1)).millisecondsSinceEpoch - 1,
      );
    }

    if (!mounted) return;

    setState(() {
      _historyData = data;
      _isLoading = false;
    });
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final initialDateRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

    final newRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
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

    if (newRange != null) {
      setState(() {
        _selectedDateRange = newRange;
        _isLoading = true;
      });
      _pollHistory();
    }
  }

  void _clearDateRange() {
    setState(() {
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day));
      _isLoading = true;
    });
    _pollHistory();
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onHorizontalDragUpdate: (details) {}, // Consumes the drag instantly so the root Shell doesn't process it!
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity != 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUDIT LOG',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDateRange == null 
                            ? 'Recent interceptions by the Intent Engine.'
                            : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                          style: GoogleFonts.inter(
                            color: _selectedDateRange == null ? Colors.white38 : AppTheme.urgentAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedDateRange != null) 
                    GestureDetector(
                      onTap: _clearDateRange,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(CupertinoIcons.clear_circled, color: Colors.white54, size: 24),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _pickDateRange(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(CupertinoIcons.calendar, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Dynamic OLED Category Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  _buildCategoryChip('All', null),
                  _buildCategoryChip('Urgent', 0),
                  _buildCategoryChip('Buffer', 1),
                  _buildCategoryChip('Blocked', 2),
                  _buildCategoryChip('OTP & Securityity', 3),
                ],
              ),
            ),

            // Dynamic Sub-Category Filtering (App Packages)
            if (_currentPackages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: _currentPackages.length + 1,
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final pkg = isAll ? 'All Apps' : _currentPackages[index - 1];
                    return _buildPackageChip(pkg, isAll ? null : pkg);
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),
            
            // List View
            Expanded(
              child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(color: Colors.white54))
                : _historyData.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Your sanctuary is clear.',
                                style: GoogleFonts.inter(
                                  color: Colors.white24,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'When notifications are intercepted, they appear here. Tap any message to dynamically teach the engine.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white24,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.white,
                        backgroundColor: Colors.black,
                        onRefresh: _pollHistory,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: _historyData.where((item) {
                            bool categoryMatch = _selectedCategoryFilter == null;
                            if (!categoryMatch) {
                              if (_selectedCategoryFilter == 3) {
                                final content = ((item['title'] ?? '') + ' ' + (item['text'] ?? '')).toLowerCase();
                                categoryMatch = content.contains('otp') || content.contains('code') || 
                                                content.contains('verification') || content.contains('password') || 
                                                content.contains('security') || content.contains('login') || 
                                                content.contains('alert') || content.contains('reset');
                              } else {
                                categoryMatch = item['category'] == _selectedCategoryFilter;
                              }
                            }
                            return categoryMatch && (_selectedPackageFilter == null || item['packageName'] == _selectedPackageFilter);
                          }).length,
                          separatorBuilder: (context, index) => const Divider(color: Colors.white12, thickness: 1, height: 1),
                          itemBuilder: (context, index) {
                            final filteredList = _historyData.where((item) {
                              bool categoryMatch = _selectedCategoryFilter == null;
                              if (!categoryMatch) {
                                if (_selectedCategoryFilter == 3) {
                                  final content = ((item['title'] ?? '') + ' ' + (item['text'] ?? '')).toLowerCase();
                                  categoryMatch = content.contains('otp') || content.contains('code') || 
                                                  content.contains('verification') || content.contains('password') || 
                                                  content.contains('security') || content.contains('login') || 
                                                  content.contains('alert') || content.contains('reset');
                                } else {
                                  categoryMatch = item['category'] == _selectedCategoryFilter;
                                }
                              }
                              return categoryMatch && (_selectedPackageFilter == null || item['packageName'] == _selectedPackageFilter);
                            }).toList();
                            final item = filteredList[index];
                            final int category = item['category'] ?? 2;
                            
                            Color dotColor;
                            if (category == 0) dotColor = AppTheme.urgentAccent;
                            else if (category == 1) dotColor = AppTheme.bufferAccent;
                            else dotColor = AppTheme.spamAccent;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: GestureDetector(
                                onTap: () => _showGlassModal(context, item),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                  // Colored Status Dot
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: dotColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: dotColor.withOpacity(0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Log Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${_getAppName(item['packageName'])} • ${_formatTime(item['timestamp'])}',
                                            style: GoogleFonts.inter(
                                              color: Colors.white38,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          if (item['title'] != null && item['title'].toString().trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              item['title'],
                                              style: GoogleFonts.inter(
                                                color: Colors.white70,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        const SizedBox(height: 6),
                                        Text(
                                          item['content'] ?? '',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, int? categoryIndex) {
    final isSelected = _selectedCategoryFilter == categoryIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryFilter = categoryIndex;
          // IMPORTANT: Reset the sub-category package filter whenever category changes
          _selectedPackageFilter = null; 
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white24,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: isSelected ? Colors.black : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageChip(String originalLabel, String? packageKey) {
    final isSelected = _selectedPackageFilter == packageKey;
    final label = originalLabel.split('.').last.toUpperCase();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackageFilter = packageKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white60 : Colors.white12,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _teachEngine(BuildContext context, Map<String, dynamic> item, int category) {
    Navigator.pop(context);

    final title = item['title']?.toString() ?? '';
    final content = item['content']?.toString() ?? '';
    final appName = _getAppName(item['packageName']);

    final appController = TextEditingController(text: appName);
    final titleController = TextEditingController(text: title);
    final contentController = TextEditingController(text: content);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Stack(
          children: [
            // Fade-in glass overlay
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: FadeTransition(
                opacity: animation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),
            ),
            
            // Pop-scale exact same dialog as the notification view
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // Handle keyboard
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
                  child: FadeTransition(
                    opacity: animation,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24.0),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.90,
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.85,
                            ),
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05), // Glassmorphism container
                              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'TEACH ENGINE',
                                          style: GoogleFonts.inter(
                                            color: category == 0 ? Colors.amber : (category == 1 ? Colors.blueAccent : Colors.redAccent),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: const Icon(CupertinoIcons.xmark, color: Colors.white54, size: 20),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Edit and select the specific fragment that should exclusively trigger this rule.',
                                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, height: 1.4),
                                  ),
                                  const SizedBox(height: 24),
                                    if (appName.isNotEmpty)
                                      _buildTeachOption(context, 'APP NAME', appController, category, isReadOnly: true),

                                    if (appName.isNotEmpty && title.isNotEmpty)
                                      const SizedBox(height: 12),
                                  if (title.isNotEmpty)
                                      _buildTeachOption(context, 'SENDER / TITLE', titleController, category),

                                  if (title.isNotEmpty && content.isNotEmpty)
                                      const SizedBox(height: 12),

                                  if (content.isNotEmpty)
                                      _buildTeachOption(context, 'MESSAGE CONTENT', contentController, category),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    );
  }

  Widget _buildTeachOption(BuildContext context, String label, TextEditingController controller, int category, {bool isReadOnly = false}) {
     Color accentColor = category == 0 ? Colors.amber : (category == 1 ? Colors.blueAccent : Colors.redAccent);
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Padding(
           padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
           child: Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
         ),
         ClipRRect(
           borderRadius: BorderRadius.circular(16),
           child: BackdropFilter(
             filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Lighter glass blur
             child: Container(
               width: double.infinity,
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.04), // Very light glass layer
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: Colors.white.withOpacity(0.1)),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   TextField(
                     controller: controller,                       readOnly: isReadOnly,                     textAlign: TextAlign.start, // Left aligned for natural reading of long texts
                     style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.5),
                     maxLines: 6,
                     minLines: 3, // Decent height padding for the text area
                     cursorColor: accentColor,
                     decoration: const InputDecoration(
                       isDense: true,
                       border: InputBorder.none,
                       contentPadding: EdgeInsets.zero,
                     ),
                   ),
                   const SizedBox(height: 12),
                   Align(
                     alignment: Alignment.centerRight,
                     child: GestureDetector(
                       onTap: () async {
                         final text = controller.text.trim();
                         if (text.isEmpty) return;

                         Navigator.pop(context);
                         final prefs = await SharedPreferences.getInstance();
                         String dartKey;
                         if (category == 0) dartKey = 'vip_keywords';
                         else if (category == 1) dartKey = 'buffer_keywords';
                         else dartKey = 'block_keywords';

                         List<String> storedStrList = prefs.getStringList(dartKey) ?? [];

                         if (!storedStrList.contains(text.toLowerCase())) {
                            storedStrList.insert(0, text.toLowerCase());
                            await prefs.setStringList(dartKey, storedStrList);
                         }

                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text('Engine Memorized Rule: "$text"', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                             backgroundColor: accentColor,
                             duration: const Duration(seconds: 3),
                             behavior: SnackBarBehavior.floating,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           )
                         );
                       },
                       behavior: HitTestBehavior.opaque,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                         decoration: BoxDecoration(
                           color: accentColor.withOpacity(0.15),
                           borderRadius: BorderRadius.circular(100),
                           border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
                         ),
                         child: Text('TEACH', style: GoogleFonts.inter(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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
  }

  void _showGlassModal(BuildContext context, Map<String, dynamic> item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Stack(
          children: [
            // Fade-in glassmorphism overlay
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: FadeTransition(
                opacity: animation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),
            ),
            
            // Pop-scale OLED dialog
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
                child: FadeTransition(
                  opacity: animation,
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.90,
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.85,
                          ),
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05), // Glassmorphism container
                            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getAppName(item['packageName']),
                                        style: GoogleFonts.inter(
                                          color: Colors.white54,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (item['title'] != null && item['title'].toString().trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item['title'],
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(CupertinoIcons.xmark, color: Colors.white54, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Text(
                                item['content'] ?? '',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // DYNAMIC TRAINING PORTAL
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _teachEngine(context, item, 0),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '⚡ URGENT',
                                        style: GoogleFonts.inter(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _teachEngine(context, item, 1),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '⏳ BUFFER',
                                        style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _teachEngine(context, item, 2),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '⛔ BLOCK',
                                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // NEW DEEP LINK MESSAGE PORTAL BUTTON
                            if (item['timestamp'] != null && item['packageName'] != null) ...[
                              GestureDetector(
                                onTap: () {
                                  DatabaseService().launchMessage(item['timestamp'] as int, item['packageName'] as String);
                                Navigator.pop(context);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white, // Primary Solid Styling
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Center(
                                  child: Text(
                                    'NAVIGATE TO MESSAGE',
                                    style: GoogleFonts.inter(
                                      color: Colors.black, // High contrast text
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // SECONDARY SOURCE APP BUTTON
                          GestureDetector(
                            onTap: () {
                              if (item['packageName'] != null) {
                                DatabaseService().launchApp(item['packageName']);
                              }
                              Navigator.pop(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: Colors.white38, width: 1), // Muted secondary outline
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Center(
                                child: Text(
                                  'NAVIGATE TO SOURCE APP',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink(); // Fallback shell
      },
    );
  }
}
