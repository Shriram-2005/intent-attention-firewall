import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class TelemetryScreen extends StatefulWidget {
  const TelemetryScreen({super.key});

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  static const EventChannel _telemetryChannel = EventChannel('com.intent.intent_app/telemetry');
  
  int _speed = 0;
  double _targetHeading = 0.0; // The continuously expanding unwrapped angle
  bool _hasPermission = false;
  bool _isLoading = true;
  int _threshold = 20;

  @override
  void initState() {
    super.initState();
    _enforcePermissions();
  }

  Future<void> _enforcePermissions() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }
    
    // Background location needs to be requested separately on Android 11+
    if (status.isGranted) {
      PermissionStatus bgStatus = await Permission.locationAlways.status;
      if (!bgStatus.isGranted) {
        await Permission.locationAlways.request();
      }
    }

    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _hasPermission = status.isGranted;
        _isLoading = false;
        int t = prefs.getInt('driving_speed_threshold') ?? 20;
        if (![20, 30, 40, 50, 60].contains(t)) t = 20;
        _threshold = t;
      });

      if (_hasPermission) {
        _bindTelemetryStream();
      }
    }
  }

  void _bindTelemetryStream() {
    _telemetryChannel.receiveBroadcastStream().listen((data) {
      if (mounted) {
        try {
          final Map<String, dynamic> raw = jsonDecode(data.toString());
          setState(() {
            if (raw.containsKey('speed')) {
              _speed = (raw['speed'] as num).toInt();
            }
            
            if (raw.containsKey('heading')) {
              // Shortest Path Rotational Math to prevent 360 -> 0 snap-backs
              double newHeading = (raw['heading'] as num).toDouble();
              double diff = newHeading - (_targetHeading.remainder(360.0));
              if (diff < -180.0) diff += 360.0;
              if (diff > 180.0) diff -= 360.0;
              _targetHeading += diff;
            }
          });
        } catch (e) {
          print("Telemetry parse error: $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {}, // Blocks the shell swipe
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
            _buildAppBar(context),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.white24))
                : !_hasPermission
                  ? _buildPermissionDeniedUI()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 64, top: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildCompass(),
                          const SizedBox(height: 48),
                          _buildSpeedometer(),
                          const SizedBox(height: 48),
                          _buildThresholdSelector(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            'HARDWARE TELEMETRY',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, color: Colors.white24, size: 64),
          const SizedBox(height: 24),
          Text(
            'GPS OFFLINE',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The Do-Or-Die engine requires "Always Allow" location tracking natively to passively block distractions while locked. Please enable it in Android Settings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => openAppSettings(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'OPEN SETTINGS',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometer() {
    return Column(
      children: [
        Text(
          _speed.toString(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 120, // Massive typography
            fontWeight: FontWeight.w200,
            height: 1.0,
            letterSpacing: -4.0,
          ),
        ),
        Text(
          'KM/H',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 4.0,
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdSelector() {
    final Map<int, String> options = {
      20: 'Safest',
      30: 'Strict',
      40: 'Standard',
      50: 'Lenient',
      60: 'Highway Only',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: AppTheme.urgentAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'DRIVING THRESHOLD',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _threshold,
            dropdownColor: AppTheme.surfaceDark,
            icon: const Icon(Icons.expand_more, color: Colors.white70),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.urgentAccent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: options.entries.map((e) {
              return DropdownMenuItem<int>(
                value: e.key,
                child: Text(
                  '${e.key} KM/H - ${e.value}',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (val) async {
              if (val != null) {
                setState(() => _threshold = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('driving_speed_threshold', val);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'If your speed exceeds this threshold, the Do-Or-Die Engine will block all notifications except absolute VIPs.',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: _targetHeading, end: _targetHeading),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, animatedHeading, child) {
          // Normalize back to 0-360 for UI highlighting logic
          double displayHeading = animatedHeading.remainder(360.0);
          if (displayHeading < 0) displayHeading += 360.0;

          return CustomPaint(
            painter: CompassPainter(heading: animatedHeading),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(top: 15, child: _compassLabel('N', displayHeading < 45 || displayHeading > 315)),
                Positioned(bottom: 15, child: _compassLabel('S', displayHeading > 135 && displayHeading < 225)),
                Positioned(right: 15, child: _compassLabel('E', displayHeading >= 45 && displayHeading <= 135)),
                Positioned(left: 15, child: _compassLabel('W', displayHeading >= 225 && displayHeading <= 315)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _compassLabel(String text, bool isHighlighted) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: isHighlighted ? Colors.white : Colors.white38,
        fontSize: 16,
        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;

  CompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final double radians = (heading - 90) * pi / 180;
    
    // Needle pointing to current heading
    final endX = center.dx + cos(radians) * (size.width / 2.5);
    final endY = center.dy + sin(radians) * (size.height / 2.5);

    // Reverse orientation visually so N/S/E/W map properly to a physical device
    canvas.drawLine(center, Offset(endX, endY), paint);

    // Draw center dot
    canvas.drawCircle(center, 4, paint);
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
      return oldDelegate.heading != heading;
  }
}
