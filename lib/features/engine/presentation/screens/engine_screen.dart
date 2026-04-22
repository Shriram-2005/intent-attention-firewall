import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class EngineScreen extends StatefulWidget {
  const EngineScreen({super.key});

  @override
  State<EngineScreen> createState() => _EngineScreenState();
}

class _EngineScreenState extends State<EngineScreen> {
  // Track the active engine state. 0 = Heuristic, 1 = Neural AI
  int _selectedEngineIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadEngineState();
  }

  Future<void> _loadEngineState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedEngineIndex = prefs.getInt('engine_type') ?? 1; // Default to Neural
    });
  }

  Future<void> _saveEngineState(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('engine_type', index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 64),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildEngineOption(
                      index: 0,
                      title: 'Heuristic Matching',
                      subtitle: 'Strict keyword rules. Zero latency and maximum battery efficiency.',
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: 24),
                    _buildEngineOption(
                      index: 1,
                      title: 'Neural Intent Classification',
                      subtitle: 'On-device LSTM network. Deep context-aware filtering and semantic analysis.',
                      icon: Icons.psychology_rounded,
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

  Widget _buildHeader() {
    return Text(
      'CORE ENGINE',
      style: GoogleFonts.inter(
        color: AppTheme.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w300,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildEngineOption({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isActive = _selectedEngineIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEngineIndex = index;
        });
        _saveEngineState(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.white : AppTheme.surfaceBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                key: ValueKey<bool>(isActive),
                color: isActive ? AppTheme.textPrimary : Colors.white24,
                size: 28,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isActive ? AppTheme.textPrimary : Colors.white54,
                      fontSize: 18,
                      fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: isActive ? Colors.white70 : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
