import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class VipManagerScreen extends StatefulWidget {
  const VipManagerScreen({super.key});

  @override
  State<VipManagerScreen> createState() => _VipManagerScreenState();
}

class _VipManagerScreenState extends State<VipManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<String> _absoluteVipKeywords = [];
  List<String> _urgentKeywords = [];
  List<String> _bufferKeywords = [];
  List<String> _blockKeywords = [];
  
  final TextEditingController _vipController = TextEditingController();
  final TextEditingController _implicitController = TextEditingController();
  
  int _selectedImplicitTab = 0; // 0 = Urgent, 1 = Buffer, 2 = Block

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
    _vipController.dispose();
    _implicitController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _absoluteVipKeywords = prefs.getStringList('absolute_vip_keywords') ?? ['Mom', 'Dad'];
        _urgentKeywords = prefs.getStringList('urgent_keywords') ?? ['OTP', 'Urgent'];
        _bufferKeywords = prefs.getStringList('buffer_keywords') ?? ['Newsletter', 'Receipt', 'Weather'];
        _blockKeywords = prefs.getStringList('block_keywords') ?? ['Promo', 'Offer', 'Discount'];
      });
    } catch (e) {
      debugPrint("Error loading keywords: $e");
    }
  }

  Future<void> _saveKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('absolute_vip_keywords', _absoluteVipKeywords);
    await prefs.setStringList('urgent_keywords', _urgentKeywords);
    await prefs.setStringList('buffer_keywords', _bufferKeywords);
    await prefs.setStringList('block_keywords', _blockKeywords);
  }


  void _addKeyword(bool isVipTab) {
    final text = isVipTab ? _vipController.text.trim() : _implicitController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (isVipTab) {
          if (!_absoluteVipKeywords.contains(text)) _absoluteVipKeywords.insert(0, text);
          _vipController.clear();
        } else {
          if (_selectedImplicitTab == 0 && !_urgentKeywords.contains(text)) {
            _urgentKeywords.insert(0, text);
          } else if (_selectedImplicitTab == 1 && !_bufferKeywords.contains(text)) {
            _bufferKeywords.insert(0, text);
          } else if (_selectedImplicitTab == 2 && !_blockKeywords.contains(text)) {
            _blockKeywords.insert(0, text);
          }
          _implicitController.clear();
        }
      });
      _saveKeywords();
    }
  }

  Future<void> _pickContact(bool isVipTab) async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status == PermissionStatus.granted) {
      final pickedId = await FlutterContacts.native.showPicker();
      if (pickedId != null) {
        final fullContact = await FlutterContacts.get(pickedId, properties: ContactProperties.all);
        if (fullContact != null) {
          List<String> extractionVectors = [];
          
          final String? dName = fullContact.displayName;
          if (dName != null && dName.isNotEmpty) extractionVectors.add(dName);
          
          for (var email in fullContact.emails) {
            if (email.address.isNotEmpty) extractionVectors.add(email.address);
          }
          
          final Set<String> normalizedPhones = {};
          for (var phone in fullContact.phones) {
            if (phone.number.isNotEmpty) {
              final String normalized = phone.number.replaceAll(RegExp(r'[^0-9+]'), '');
              if (!normalizedPhones.contains(normalized)) {
                normalizedPhones.add(normalized);
                extractionVectors.add(normalized);
              }
            }
          }
          
          if (extractionVectors.isNotEmpty) {
            setState(() {
              for (String trigger in extractionVectors) {
                if (isVipTab) {
                  if (!_absoluteVipKeywords.contains(trigger)) _absoluteVipKeywords.insert(0, trigger);
                } else {
                  if (_selectedImplicitTab == 0 && !_urgentKeywords.contains(trigger)) {
                    _urgentKeywords.insert(0, trigger);
                  } else if (_selectedImplicitTab == 1 && !_bufferKeywords.contains(trigger)) {
                    _bufferKeywords.insert(0, trigger);
                  } else if (_selectedImplicitTab == 2 && !_blockKeywords.contains(trigger)) {
                    _blockKeywords.insert(0, trigger);
                  }
                }
              }
            });
            _saveKeywords();
          }
        }
      }
    }
  }

  void _showCustomProfileModal(bool isVipTab) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('CREATE REDUNDANT PROFILE', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
               const SizedBox(height: 8),
               Text('Enter details manually so the engine intercepts messages from any of these addresses natively.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.4)),
               const SizedBox(height: 24),
               TextField(
                 controller: nameController,
                 style: const TextStyle(color: Colors.white),
                 decoration: InputDecoration(hintText: 'Display Name (e.g., Mom)', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: phoneController,
                 style: const TextStyle(color: Colors.white),
                 decoration: InputDecoration(hintText: 'Phone Number (e.g., +1 555-0192)', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: emailController,
                 style: const TextStyle(color: Colors.white),
                 decoration: InputDecoration(hintText: 'Email Address', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
               ),
               const SizedBox(height: 24),
               GestureDetector(
                 onTap: () {
                    final n = nameController.text.trim();
                    final p = phoneController.text.trim();
                    final e = emailController.text.trim();
                    
                    setState(() {
                       void addIfValid(String val) {
                          if (val.isNotEmpty) {
                             if (isVipTab) {
                               if (!_absoluteVipKeywords.contains(val)) _absoluteVipKeywords.insert(0, val);
                             } else {
                               if (_selectedImplicitTab == 0 && !_urgentKeywords.contains(val)) _urgentKeywords.insert(0, val);
                               else if (_selectedImplicitTab == 1 && !_bufferKeywords.contains(val)) _bufferKeywords.insert(0, val);
                               else if (_selectedImplicitTab == 2 && !_blockKeywords.contains(val)) _blockKeywords.insert(0, val);
                             }
                          }
                       }
                       addIfValid(n);
                       addIfValid(p);
                       addIfValid(e);
                    });
                    _saveKeywords();
                    Navigator.pop(context);
                 },
                 child: Container(
                   width: double.infinity,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                   child: Center(child: Text('INJECT INTO ENGINE', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.0))),
                 )
               ),
               const SizedBox(height: 24),
            ],
          )
        );
      }
    );
  }

  void _removeKeyword(bool isVipTab, int index) {
    setState(() {
      if (isVipTab) {
        _absoluteVipKeywords.removeAt(index);
      } else {
        if (_selectedImplicitTab == 0) {
          _urgentKeywords.removeAt(index);
        } else if (_selectedImplicitTab == 1) {
          _bufferKeywords.removeAt(index);
        } else {
          _blockKeywords.removeAt(index);
        }
      }
    });
    _saveKeywords();
  }

  Widget _buildInputArea(bool isVipTab) {
    final controller = isVipTab ? _vipController : _implicitController;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                  cursorColor: Colors.white,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Type exact Keyword, Phrase, or Email...',
                    hintStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _addKeyword(isVipTab),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _addKeyword(isVipTab),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.checkmark_alt, color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
          if (isVipTab) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickContact(isVipTab),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.person_crop_circle_badge_plus, color: Colors.blueAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Add Contact',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCustomProfileModal(isVipTab),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.contact_page_outlined, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Custom Profile',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(bool isVipTab) {
    final list = isVipTab 
        ? _absoluteVipKeywords 
        : (_selectedImplicitTab == 0 ? _urgentKeywords : (_selectedImplicitTab == 1 ? _bufferKeywords : _blockKeywords));
        
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) => const Divider(color: Colors.white12, thickness: 1, height: 1),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  list[index],
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _removeKeyword(isVipTab, index),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: Colors.white24,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
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
                    Text(
                      'ENGINE RULES',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
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
                      color: AppTheme.urgentAccent.withOpacity(0.2),
                      border: Border.all(color: AppTheme.urgentAccent, width: 1),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
                    tabs: const [
                      Tab(text: 'VIP RULES'),
                      Tab(text: 'IMPLICIT RULES'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- VIP TAB ---
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.urgentAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.urgentAccent.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.security, color: AppTheme.urgentAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Absolute Bypass', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text('Instantly bypass AI analysis to the OS.', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInputArea(true),
                        Expanded(child: _buildList(true)),
                      ],
                    ),
                    
                    // --- IMPLICIT TAB ---
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: CupertinoSlidingSegmentedControl<int>(
                              backgroundColor: Colors.white10,
                              thumbColor: Colors.white,
                              groupValue: _selectedImplicitTab,
                              children: {
                                0: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Urgent', style: GoogleFonts.inter(color: _selectedImplicitTab == 0 ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                                1: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Buffer', style: GoogleFonts.inter(color: _selectedImplicitTab == 1 ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                                2: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Spam', style: GoogleFonts.inter(color: _selectedImplicitTab == 2 ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              },
                              onValueChanged: (int? value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedImplicitTab = value;
                                    _implicitController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInputArea(false),
                        Expanded(child: _buildList(false)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
