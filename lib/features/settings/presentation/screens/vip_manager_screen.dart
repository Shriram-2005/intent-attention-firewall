import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../../core/theme/app_theme.dart';

class VipManagerScreen extends StatefulWidget {
  const VipManagerScreen({super.key});

  @override
  State<VipManagerScreen> createState() => _VipManagerScreenState();
}

class _VipManagerScreenState extends State<VipManagerScreen> {
  List<String> _vipKeywords = [];
  List<String> _bufferKeywords = [];
  List<String> _blockKeywords = [];
  final TextEditingController _controller = TextEditingController();
  int _selectedTab = 0; // 0 = VIP, 1 = Buffer, 2 = Block

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vipKeywords = prefs.getStringList('vip_keywords') ?? ['OTP', 'Dad', 'Urgent'];
      _bufferKeywords = prefs.getStringList('buffer_keywords') ?? ['Newsletter', 'Receipt', 'Weather'];
      _blockKeywords = prefs.getStringList('block_keywords') ?? ['Promo', 'Offer', 'Discount'];
    });
  }

  Future<void> _saveKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedTab == 0) {
      await prefs.setStringList('vip_keywords', _vipKeywords);
    } else if (_selectedTab == 1) {
      await prefs.setStringList('buffer_keywords', _bufferKeywords);
    } else {
      await prefs.setStringList('block_keywords', _blockKeywords);
    }
  }

  void _addKeyword() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (_selectedTab == 0 && !_vipKeywords.contains(text)) {
          _vipKeywords.insert(0, text);
        } else if (_selectedTab == 1 && !_bufferKeywords.contains(text)) {
          _bufferKeywords.insert(0, text);
        } else if (_selectedTab == 2 && !_blockKeywords.contains(text)) {
          _blockKeywords.insert(0, text);
        }
        _controller.clear();
      });
      _saveKeywords();
    }
  }

  Future<void> _pickContact() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status == PermissionStatus.granted) {
      final pickedId = await FlutterContacts.native.showPicker();
      if (pickedId != null) {
        final fullContact = await FlutterContacts.get(pickedId, properties: ContactProperties.all);
        if (fullContact != null) {
          List<String> extractionVectors = [];
          
          final String? dName = fullContact.displayName;
          if (dName != null && dName.isNotEmpty) {
            extractionVectors.add(dName);
          }
          
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
                if (_selectedTab == 0 && !_vipKeywords.contains(trigger)) {
                  _vipKeywords.insert(0, trigger);
                } else if (_selectedTab == 1 && !_bufferKeywords.contains(trigger)) {
                  _bufferKeywords.insert(0, trigger);
                } else if (_selectedTab == 2 && !_blockKeywords.contains(trigger)) {
                  _blockKeywords.insert(0, trigger);
                }
              }
            });
            _saveKeywords();
          }
        }
      }
    }
  }

  void _showCustomProfileModal() {
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
                             if (_selectedTab == 0 && !_vipKeywords.contains(val)) _vipKeywords.insert(0, val);
                             else if (_selectedTab == 1 && !_bufferKeywords.contains(val)) _bufferKeywords.insert(0, val);
                             else if (_selectedTab == 2 && !_blockKeywords.contains(val)) _blockKeywords.insert(0, val);
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

  void _removeKeyword(int index) {
    setState(() {
      if (_selectedTab == 0) {
        _vipKeywords.removeAt(index);
      } else if (_selectedTab == 1) {
        _bufferKeywords.removeAt(index);
      } else {
        _blockKeywords.removeAt(index);
      }
    });
    _saveKeywords();
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
            
            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  backgroundColor: Colors.white10,
                  thumbColor: Colors.white,
                  groupValue: _selectedTab,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Urgent', style: GoogleFonts.inter(color: _selectedTab == 0 ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Buffer', style: GoogleFonts.inter(color: _selectedTab == 1 ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Spam', style: GoogleFonts.inter(color: _selectedTab == 2 ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  },
                  onValueChanged: (int? value) {
                    if (value != null) {
                      setState(() {
                        _selectedTab = value;
                        _controller.clear();
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Input Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: _selectedTab == 0 ? 'Type exact Keyword or Email...' : 'Add Keyword...',
                            hintStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onSubmitted: (_) => _addKeyword(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _addKeyword,
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickContact,
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
                          onTap: _showCustomProfileModal,
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
              ),
            ),
            
            const SizedBox(height: 32),
            
            // List View
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                physics: const BouncingScrollPhysics(),
                itemCount: _selectedTab == 0 ? _vipKeywords.length : (_selectedTab == 1 ? _bufferKeywords.length : _blockKeywords.length),
                separatorBuilder: (context, index) => const Divider(color: Colors.white12, thickness: 1, height: 1),
                itemBuilder: (context, index) {
                  final text = _selectedTab == 0 ? _vipKeywords[index] : (_selectedTab == 1 ? _bufferKeywords[index] : _blockKeywords[index]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            text,
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
                          onTap: () => _removeKeyword(index),
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
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
