import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class AppManagerScreen extends StatefulWidget {
  const AppManagerScreen({super.key});

  @override
  State<AppManagerScreen> createState() => _AppManagerScreenState();
}

class _AppManagerScreenState extends State<AppManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<String> _socialMediaPackages = [];
  List<String> _ignoredPackages = [];
  
  final TextEditingController _socialController = TextEditingController();
  final TextEditingController _ignoredController = TextEditingController();
  
  static const _settingsChannel = MethodChannel('com.intent.intent_app/settings');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadKeywords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _socialController.dispose();
    _ignoredController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _socialMediaPackages = prefs.getStringList('social_media_packages') ?? [
          "com.instagram.android",
          "com.zhiliaoapp.musically",
          "com.twitter.android",
          "com.facebook.katana",
          "com.snapchat.android",
          "com.reddit.frontpage",
          "tv.twitch.android",
          "com.pinterest",
          "com.google.android.youtube"
        ];
        _ignoredPackages = prefs.getStringList('ignored_packages') ?? [
          "android",
          "com.android.systemui",
          "com.android.phone",
          "com.android.settings",
          "com.google.android.apps.nexuslauncher",
          "com.sec.android.app.launcher"
        ];
      });
    } catch (e) {
      debugPrint("Error loading packages: $e");
    }
  }

  Future<void> _saveKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('social_media_packages', _socialMediaPackages);
    await prefs.setStringList('ignored_packages', _ignoredPackages);

    try {
      await _settingsChannel.invokeMethod('settings.syncKeywords', {});
    } catch (e) {
      debugPrint("Failed to sync natively: $e");
    }
  }

  void _addKeyword(bool isSocialTab) {
    final text = isSocialTab ? _socialController.text.trim().toLowerCase() : _ignoredController.text.trim().toLowerCase();
    if (text.isNotEmpty) {
      setState(() {
        if (isSocialTab) {
          if (!_socialMediaPackages.contains(text)) _socialMediaPackages.insert(0, text);
          _socialController.clear();
        } else {
          if (!_ignoredPackages.contains(text)) _ignoredPackages.insert(0, text);
          _ignoredController.clear();
        }
      });
      _saveKeywords();
    }
  }

  void _removeKeyword(bool isSocialTab, String text) {
    setState(() {
      if (isSocialTab) {
        _socialMediaPackages.remove(text);
      } else {
        _ignoredPackages.remove(text);
      }
    });
    _saveKeywords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildListTab(
                    isSocialTab: true,
                    items: _socialMediaPackages,
                    controller: _socialController,
                    title: 'Distracting Apps',
                    subtitle: 'These apps will NOT be blocked if you are actively using them.',
                    hintText: 'e.g., com.facebook.orca',
                  ),
                  _buildListTab(
                    isSocialTab: false,
                    items: _ignoredPackages,
                    controller: _ignoredController,
                    title: 'Ignored Apps',
                    subtitle: 'These system apps are completely invisible to the AI engine.',
                    hintText: 'e.g., com.whatsapp',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 32.0, top: 16.0, bottom: 24.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'APP CLASSIFICATIONS',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.bufferAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.bufferAccent, width: 1),
        ),
        labelColor: AppTheme.bufferAccent,
        unselectedLabelColor: Colors.white54,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, letterSpacing: 1.0),
        tabs: const [
          Tab(text: 'SOCIAL'),
          Tab(text: 'IGNORED'),
        ],
      ),
    );
  }

  Widget _buildListTab({
    required bool isSocialTab,
    required List<String> items,
    required TextEditingController controller,
    required String title,
    required String subtitle,
    required String hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, height: 1.5)),
          const SizedBox(height: 32),
          _buildInputField(controller, hintText, () => _addKeyword(isSocialTab)),
          const SizedBox(height: 24),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text('No apps configured.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.apps, color: Colors.white54, size: 16),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(item, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                            ),
                            GestureDetector(
                              onTap: () => _removeKeyword(isSocialTab, item),
                              child: const Icon(Icons.close, color: Colors.white38, size: 20),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hintText, VoidCallback onSubmitted) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.add, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          GestureDetector(
            onTap: onSubmitted,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bufferAccent.withOpacity(0.2),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: Text('ADD', style: GoogleFonts.inter(color: AppTheme.bufferAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
