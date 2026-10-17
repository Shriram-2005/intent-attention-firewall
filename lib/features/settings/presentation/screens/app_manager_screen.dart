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

  static const List<String> _verifiedSocialApps = [
    'Instagram', 'WhatsApp', 'Facebook', 'TikTok', 'Twitter', 'Snapchat', 'Reddit', 
    'Pinterest', 'YouTube', 'Telegram', 'Discord', 'Messenger', 'Twitch', 'LinkedIn', 
    'Tinder', 'BeReal', 'Tumblr', 'X', 'Threads', 'WeChat'
  ];

  static const List<String> _verifiedIgnoredApps = [
    'Settings', 'Phone', 'Messages', 'Clock', 'Camera', 'Gallery', 'Calculator', 
    'Calendar', 'Contacts', 'Google', 'Play Store', 'Android System', 'System UI', 
    'Google Play Services', 'File Manager', 'Maps', 'Keyboard', 'Android Auto', 
    'Carrier Services', 'Digital Wellbeing'
  ];

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
        List<String> loadedSocial = prefs.getStringList('social_media_packages') ?? [];
        List<String> loadedIgnored = prefs.getStringList('ignored_packages') ?? [];

        // Migration: Erase old com.x.x.x strings from previous builds
        loadedSocial.removeWhere((app) => app.contains('.'));
        loadedIgnored.removeWhere((app) => app.contains('.'));

        if (loadedSocial.isEmpty) {
          loadedSocial = ["instagram", "whatsapp"];
        }
        if (loadedIgnored.isEmpty) {
          loadedIgnored = ["system ui", "settings", "phone"];
        }

        _socialMediaPackages = loadedSocial;
        _ignoredPackages = loadedIgnored;
      });
    } catch (e) {
      debugPrint("Error loading packages: \$e");
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
                    subtitle: 'The AI will hold these notifications until delivery, unless you are actively using the app.',
                    hintText: 'e.g., WhatsApp, Instagram',
                  ),
                  _buildListTab(
                    isSocialTab: false,
                    items: _ignoredPackages,
                    controller: _ignoredController,
                    title: 'Ignored Apps',
                    subtitle: 'These system apps are completely invisible to the AI engine.',
                    hintText: 'e.g., Settings, Phone',
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'APP CLASSIFICATIONS',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.bufferAccent.withOpacity(0.2),
            border: Border.all(color: AppTheme.bufferAccent, width: 1),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
          tabs: const [
            Tab(text: 'SOCIAL'),
            Tab(text: 'IGNORED'),
          ],
        ),
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
          _buildInputField(controller, hintText, () => _addKeyword(isSocialTab), isSocialTab),
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

  Widget _buildInputField(TextEditingController controller, String hintText, VoidCallback onSubmitted, bool isSocialTab) {
    final List<String> options = isSocialTab ? _verifiedSocialApps : _verifiedIgnoredApps;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          return options.where((String option) {
            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
          });
        },
        onSelected: (String selection) {
          controller.text = selection;
        },
        fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
          return Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (String value) {
                    if (options.any((app) => app.toLowerCase() == value.toLowerCase())) {
                      controller.text = value;
                      onSubmitted();
                      fieldTextEditingController.clear();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.black87,
                          content: Text(
                            "This application is currently unsupported. It will be added to the verified classification database in a future update.",
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      fieldTextEditingController.clear();
                    }
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  final value = fieldTextEditingController.text;
                  if (options.any((app) => app.toLowerCase() == value.toLowerCase())) {
                    controller.text = value;
                    onSubmitted();
                    fieldTextEditingController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.black87,
                        content: Text(
                          "This application is currently unsupported. It will be added to the verified classification database in a future update.",
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    fieldTextEditingController.clear();
                  }
                },
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
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width - 64,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          option,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
