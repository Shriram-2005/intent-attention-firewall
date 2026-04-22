import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

import '../../../../core/services/database_service.dart';
import '../../../../core/state/engine_state.dart';
import '../../../settings/presentation/screens/history_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasAccess = true;
  bool _isLoading = true;
  int _urgentCount = 0;
  int _bufferCount = 0;
  int _spamCount = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EngineState.databaseUpdateTick.addListener(_pollData);
    _pollData();
  }

  @override
  void dispose() {
    EngineState.databaseUpdateTick.removeListener(_pollData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollData();
    }
  }

  Future<void> _pollData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final hasAccess = await DatabaseService().checkAccess();
    if (hasAccess) {
      final db = DatabaseService();
      final counts = await db.getCounts();
      double requiredMins = (prefs.getDouble('target_focus_hours') ?? 1.0) * 60.0;
      final streak = await db.getFocusStreak(requiredMins: requiredMins);
      setState(() {
        _urgentCount = counts['urgent'] ?? 0;
        _bufferCount = counts['buffer'] ?? 0;
        _spamCount = counts['spam'] ?? 0;
        _streak = streak;
      });
    }
    setState(() {
      _hasAccess = hasAccess;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                _buildSmartModeToggle(),
                const SizedBox(height: 48),
                _isLoading 
                    ? const Center(child: Padding(padding: EdgeInsets.only(top: 60), child: CupertinoActivityIndicator(color: Colors.white54)))
                    : (!_hasAccess ? _buildPermissionGate() : _buildDashboardData()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'DASHBOARD',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w300,
            letterSpacing: 2.0,
          ),
        ),
        GestureDetector(
          onTap: () {
            _showStreakModal();
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 28),
              const SizedBox(height: 2),
              Text(
                '$_streak ${_streak == 1 ? 'day' : 'days'}',
                style: GoogleFonts.inter(
                  fontSize: 12, 
                  color: AppTheme.textPrimary, 
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmartModeToggle() {
    return ValueListenableBuilder<bool>(
      valueListenable: EngineState.isSmartModeActive,
      builder: (context, isActive, _) {
        return GestureDetector(
          onTap: () {
            EngineState.setSmartMode(!isActive);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.surfaceElevated : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isActive 
                    ? AppTheme.surfaceBorder 
                    : AppTheme.surfaceBorder.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  color: isActive ? AppTheme.primaryColor : AppTheme.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 12),
                Text(
                  isActive ? 'ENGINE ACTIVE' : 'ENGINE OFFLINE',
                  style: GoogleFonts.inter(
                    color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionGate() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CupertinoIcons.lock_shield, color: Colors.white24, size: 64),
        const SizedBox(height: 24),
        Text(
          'ACCESS REQUIRED',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Intent Engine needs OS permission to intercept and analyze notifications locally.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        GestureDetector(
          onTap: () async {
            await DatabaseService().requestAccess();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.black, // True Black
              border: Border.all(color: Colors.white, width: 1), // White 1px border
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              'ACTIVATE INTENT ENGINE',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow(
          label: 'URGENT',
          count: _urgentCount,
          color: AppTheme.urgentAccent,
          categoryIndex: 0,
        ),
        const SizedBox(height: 32),
        const Divider(color: AppTheme.surfaceBorder, thickness: 1),
        const SizedBox(height: 32),
        _buildDataRow(
          label: 'BUFFER',
          count: _bufferCount,
          color: AppTheme.bufferAccent,
          categoryIndex: 1,
        ),
        const SizedBox(height: 32),
        const Divider(color: AppTheme.surfaceBorder, thickness: 1),
        const SizedBox(height: 32),
        _buildDataRow(
          label: 'BLOCKED',
          count: _spamCount,
          color: AppTheme.spamAccent,
          categoryIndex: 2,
        ),
        const SizedBox(height: 48),
      ],
    );
  }


  Future<void> _showStreakModal() async {
    DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    bool isLoading = true;
    Set<int> litDays = {};
    double currentTarget = 1.0;

    Future<void> fetchMonthData(DateTime month, StateSetter setState) async {
      setState(() => isLoading = true);
      litDays.clear();
      
      final db = DatabaseService();
      final prefs = await SharedPreferences.getInstance();
      currentTarget = prefs.getDouble('target_focus_hours') ?? 1.0;
      
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      for (int d = 1; d <= daysInMonth; d++) {
        final start = DateTime(month.year, month.month, d);
        final end = DateTime(month.year, month.month, d, 23, 59, 59);
        var stats = await db.getCountsBetween(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
        double savedHours = ((stats['cognitive_mins'] as num?)?.toDouble() ?? 0.0) / 60.0;
        
        if (savedHours >= currentTarget) {
          litDays.add(d);
        }
      }
      
      if (mounted) {
        setState(() => isLoading = false);
      }
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            if (isLoading && litDays.isEmpty) {
              fetchMonthData(currentMonth, setState);
            }
            
            final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            final monthName = monthNames[currentMonth.month - 1];
            final year = currentMonth.year;
            
            final daysInCurrentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
            final firstDayWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday; // 1 = Monday
            
            // Generate full grid items including empty slots
            List<Widget> gridItems = [];
            // Emtpy slots before the 1st
            for (int i = 1; i < firstDayWeekday; i++) {
              gridItems.add(const SizedBox.shrink());
            }
            // Real days
            for (int d = 1; d <= daysInCurrentMonth; d++) {
              final isLit = litDays.contains(d);
              final isToday = d == DateTime.now().day && currentMonth.month == DateTime.now().month && currentMonth.year == DateTime.now().year;
              gridItems.add(
                Container(
                  decoration: BoxDecoration(
                    color: isLit ? Colors.orangeAccent.withValues(alpha: 0.15) : AppTheme.surfaceDark.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday 
                          ? Colors.orangeAccent 
                          : isLit 
                              ? Colors.orangeAccent.withValues(alpha: 0.4) 
                              : AppTheme.surfaceBorder.withValues(alpha: 0.3),
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isLit 
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.local_fire_department, size: 30, color: Colors.orangeAccent.withValues(alpha: 0.8)),
                          Text(
                            d.toString(), 
                            style: GoogleFonts.inter(
                              color: Colors.white, 
                              fontSize: 13, 
                              fontWeight: FontWeight.w900,
                              shadows: [
                                const Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                const Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 0)),
                              ]
                            )
                          ),
                        ],
                      )
                    : Text(d.toString(), style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              );
            }
            
            // Pad the end to always have 42 cells (6 rows) so height never hops
            while (gridItems.length < 42) {
              gridItems.add(const SizedBox.shrink());
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.65), // Stronger glassmorphism
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Streak Calendar',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Current Streak: $_streak ${_streak == 1 ? "day" : "days"}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<double>(
                                value: currentTarget,
                                dropdownColor: AppTheme.surfaceDark,
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                                items: [1.0, 2.0, 3.0, 4.0, 5.0].map((double value) {
                                  return DropdownMenuItem<double>(
                                    value: value,
                                    child: Text('${value.toInt()} hr target'),
                                  );
                                }).toList(),
                                onChanged: (value) async {
                                  if (value != null) {
                                    setState(() => currentTarget = value);
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setDouble('target_focus_hours', value);                                      final double requiredMins = value * 60.0;
                                      final int newStreak = await DatabaseService().getFocusStreak(requiredMins: requiredMins);
                                      this.setState(() {
                                        _streak = newStreak;
                                      });
                                      setState(() {});                                    // Recalculate streak!
                                    fetchMonthData(currentMonth, setState);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep it up! Save enough cognitive focus to keep your streak.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Dynamic Calendar Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.surfaceBorder.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Month Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                                      fetchMonthData(currentMonth, setState);
                                    });
                                  },
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                  child: Text(
                                    '$monthName $year',
                                    key: ValueKey<String>('$monthName$year'),
                                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                                      fetchMonthData(currentMonth, setState);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Days Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            
                            // Grid
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: isLoading 
                              ? Container(
                                  key: const ValueKey('loading'),
                                  height: 280, // Fixed height matching grid roughly
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(color: Colors.orangeAccent),
                                )
                              : GridView.count(
                                  key: ValueKey<String>('grid_$monthName$year'),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 7,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                  childAspectRatio: 1.05,
                                  children: gridItems,
                                ),
                            )
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceElevated,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],

                      ),

                     ),

                    ),
      ),
    );
  },
  );
  },
  );
}

  Widget _buildDataRow({required String label, required int count, required Color color, required int categoryIndex}) {
    return ValueListenableBuilder<bool>(
      valueListenable: EngineState.isSmartModeActive,
      builder: (context, isActive, _) {
        return GestureDetector(
          onTap: () {
            if (!isActive) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryScreen(initialCategoryFilter: categoryIndex),
              )
            );
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1.0 : 0.3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4.0,
                  ),
                ),
                Text(
                  count.toString().padLeft(2, '0'),
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                    letterSpacing: -2.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _pollData(); // Refresh streak on dashboard dynamically
  }
}
