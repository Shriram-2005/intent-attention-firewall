import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/state/engine_state.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  int _urgentCount = 0;
  int _bufferCount = 0;
  int _spamCount = 0;
  double _latency = 0.0;
  double _literalMins = 0.0;
  double _cognitiveMins = 0.0;
  bool _showCognitivePrimary = true;

  bool _isAiCoachEnabled = false;

  List<FlSpot> _temporalData = [const FlSpot(0, 0), const FlSpot(6, 0), const FlSpot(12, 0), const FlSpot(18, 0), const FlSpot(24, 0)];
  List<RadarEntry> _contextualData = const [RadarEntry(value: 0), RadarEntry(value: 0), RadarEntry(value: 0), RadarEntry(value: 0)];
  List<PieChartSectionData> _sourceData = [];
  List<Widget> _sourceLegend = [];
  List<FlSpot> _roiData = [const FlSpot(1, 0), const FlSpot(4, 0), const FlSpot(7, 0)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EngineState.databaseUpdateTick.addListener(_pollData);
    _pollData();
  }

  Future<void> _toggleAiCoach(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAiCoachEnabled', value);
    setState(() {
      _isAiCoachEnabled = value;
    });
  }

  pw.Widget _buildPdfMetric(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#141414'),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColor.fromHex('#2A2A2A')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAiReport(DateTime start, DateTime end) async {
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 40.0,
                horizontal: 24.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Generating Insights...',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Applying Cognitive Coaching Models',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final counts = await DatabaseService().getCountsBetween(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        );
        final historyRaw = await DatabaseService().getHistoryBetween(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        );

        final trafficData = historyRaw.map((e) {
          final dynCat = e['category'];
          final cat = dynCat == 0 ? 'Urgent' : dynCat == 1 ? 'Buffer' : 'Spam';
          final t = DateTime.fromMillisecondsSinceEpoch((e['timestamp'] as num).toInt()).toLocal();
          return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}($cat)';
        }).join(', ');

        if (historyRaw.isEmpty || counts['urgent'] == 0 && counts['buffer'] == 0 && counts['spam'] == 0) {
          throw Exception('No data available in the selected date range to generate insights.');
        }

        final apiKey = dotenv.env['GEMINI_API_KEY'] ?? ''; 
        if (apiKey.isEmpty) {
          throw Exception('API Key is missing or empty! Please check your .env file and fully restart the app (Stop and start again).');
        }
        
        final dateStrStart = start.toLocal().toString().split(' ')[0];
        final dateStrEnd = end.toLocal().toString().split(' ')[0];

        final prompt =
            'Act as a behavioral data analyst reviewing digital focus from $dateStrStart to $dateStrEnd.\n'
            'Data: Urgent: ${counts["urgent"]}, Buffered: ${counts["buffer"]}, Blocked: ${counts["spam"]}, '
            'Time Protected: ${counts["cognitive_mins"]} mins.\n'
            'Traffic Log (Time and Category only): $trafficData\n\n'
            'Write a highly concise summary using standard sentence casing (DO NOT WRITE IN ALL CAPS!) under these 3 exact markdown headers:\n\n'
            '### Pattern Insight\n'
            'A single simple paragraph (1-2 sentences) about their interruption ratios and digital noise traffic patterns based on the arrival times.\n\n'
            '### Trend Insight\n'
            'A single simple paragraph (1-2 sentences) explaining the cognitive value of the protected time given their traffic.\n\n'
            '### Actionable Tips\n'
            'A simple markdown bulleted list of 2 short focus strategies referencing their peak traffic hours.\n\n'
            'IMPORTANT: Maintain strict privacy. Rely exclusively on these timestamps and categories rather than assuming content. Keep it simple, readable, and formatting-friendly. Absolutely no emojis, robotic greetings, or all-caps paragraphs.';
        
        GenerativeModel model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        final aiAnalysis = response.text ?? 'No insights generated.';

      List<pw.Widget> buildAiInsights(String text) {
        final List<pw.Widget> widgets = [];
        
        final lines = text.split('\n');
        String currentParagraph = '';

        void flushParagraph() {
          if (currentParagraph.isNotEmpty) {
            final normalText = currentParagraph.replaceAll(RegExp(r'\*\*|\*'), '').trim();
            if (normalText.isNotEmpty) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(
                    normalText,
                    textAlign: pw.TextAlign.justify,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey400,
                      lineSpacing: 1.8,
                    ),
                  ),
                ),
              );
            }
            currentParagraph = '';
          }
        }

        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            flushParagraph();
            continue;
          }

          if (trimmed.startsWith(RegExp(r'^#+ '))) {
            flushParagraph();
            final headingText = trimmed
                .replaceFirst(RegExp(r'^#\s*'), '')
                .replaceFirst(RegExp(r'^#+\s*'), '')
                .replaceAll(RegExp(r'\*\*|\*'), '');
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
                child: pw.Text(
                  headingText.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            );
          } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
            flushParagraph();
            final bulletText = trimmed
                .replaceFirst(RegExp(r'^[-|\*]\s*'), '')
                .replaceAll(RegExp(r'\*\*|\*'), '');
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8, left: 12),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 8, top: 4),
                      child: pw.Container(
                        width: 4,
                        height: 4,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey500,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        bulletText,
                        textAlign: pw.TextAlign.left,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey300,
                          lineSpacing: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Append to current paragraph, adding a space if necessary
            if (currentParagraph.isNotEmpty) {
              currentParagraph += ' ' + trimmed;
            } else {
              currentParagraph = trimmed;
            }
          }
        }
        flushParagraph();

        if (widgets.isEmpty) {
          widgets.add(
            pw.Text(
              'No insights generated.',
              style: const pw.TextStyle(color: PdfColors.grey500),
            ),
          );
        }
        return widgets;
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            buildBackground: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Container(color: PdfColor.fromHex('#0F0F0F')),
              );
            },
          ),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 24),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: PdfColor.fromHex('#2A2A2A'),
                      width: 1,
                    ),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'INTENT',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 4,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'COGNITIVE COACH REPORT',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey500,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      '${start.toLocal().toString().split(' ')[0]} - ${end.toLocal().toString().split(' ')[0]}',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'EXECUTIVE SUMMARY',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfMetric(
                    'URGENT',
                    '${counts["urgent"]}',
                    PdfColor.fromHex('#E57373'),
                  ), // Soft Red
                  _buildPdfMetric(
                    'BUFFERED',
                    '${counts["buffer"]}',
                    PdfColor.fromHex('#FFB74D'),
                  ), // Soft Orange
                  _buildPdfMetric(
                    'BLOCKED',
                    '${counts["spam"]}',
                    PdfColor.fromHex('#90A4AE'),
                  ), // Cyber Grey
                  _buildPdfMetric(
                    'FOCUS SAVED',
                    '${(counts["cognitive_mins"] as num? ?? 0).toStringAsFixed(2)}m',
                    PdfColor.fromHex('#4DD0E1'),
                  ), // Cyan
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'BEHAVIORAL INSIGHTS',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#141414'),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: PdfColor.fromHex('#2A2A2A')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: buildAiInsights(aiAnalysis),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'AI-powered insights are optional and operate only on aggregated metadata. Core functionality remains fully offline and privacy-preserving.\nNo raw notification content is transmitted to the cloud. Only anonymized aggregate statistics are used.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
            ];
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final dateStr = start.toIso8601String().split('T')[0];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${output.path}/Intent_Cognitive_Report_${dateStr}_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        if (dialogContext != null) {
          Navigator.pop(dialogContext!); // Safely specifically pop the dialog
        }
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Focus Analytics AI Report');
      }
    } catch (e) {
      if (mounted && dialogContext != null) {
        Navigator.pop(dialogContext!);

        debugPrint("AI Report Error: $e");
        final errString = e.toString().toLowerCase();
        String errorMessage = 'An error occurred generating insights.';
        
        if (errString.contains('socket') || 
            errString.contains('network') || 
            errString.contains('clientexception') || 
            errString.contains('failed host lookup')) {
          errorMessage = 'A network connection error occurred. Please try again.';
        } else if (errString.contains('503') ||
                   errString.contains('unavailable') ||
                   errString.contains('high demand') ||
                   errString.contains('server error')) {
          errorMessage = 'The Gemini 2.5 Flash model is currently experiencing exceptionally high demand. Please wait a moment and try again.';
        } else if (errString.contains('429') ||
                   errString.contains('quota') ||
                   errString.contains('exhausted')) {
          errorMessage = 'Our AI Coach is currently hitting API rate limits. Please try again later.';
        } else {
          errorMessage = 'AI Error: ${e.toString().length > 90 ? e.toString().substring(0, 90) + '...' : e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.urgentAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
      if (mounted && _isAiCoachEnabled) {
        setState(() {
          _isAiCoachEnabled = false;
        });
      }
      _pollData();
    }
  }

  Future<void> _pollData() async {
    final counts = await DatabaseService().getCounts();
    final dbLogs = await DatabaseService().getHistory();
    
    if (!mounted) return;
    
    // Calculate Temporal (24HR Volume)
    final now = DateTime.now();
    final tData = [0, 0, 0, 0, 0];
    
    // Calculate Contextual States
    final cData = [0, 0, 0, 0]; // focus, drive, night, default
    
    // Calculate 7D ROI
    final roiCounts = List<int>.filled(7, 0); // Mon (0) to Sun (6)
    
    // Sources map
    final Map<String, int> sourceCounts = {};
    
    for (var log in dbLogs) {
      if (log['timestamp'] == null) continue;
      final ts = DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int);
      
      // Calculate 24h
      if (now.difference(ts).inHours < 24) {
         if (ts.hour < 6) tData[0]++;
         else if (ts.hour < 12) tData[1]++;
         else if (ts.hour < 18) tData[2]++;
         else tData[3]++;
         tData[4]++; // Current end bucket
      }
      
      // Contextual
      final reason = (log['reason'] as String?)?.toLowerCase() ?? '';
      if (reason.contains('focus') || reason.contains('deep')) cData[0]++;
      else if (reason.contains('drive') || reason.contains('auto')) cData[1]++;
      else if (reason.contains('night') || reason.contains('sleep')) cData[2]++;
      else cData[3]++;
      
      // Top Interruptions (App name)
      final pkg = (log['packageName'] as String?)?.split('.').last ?? 'system';
      sourceCounts[pkg] = (sourceCounts[pkg] ?? 0) + 1;
      
      // 7D ROI (cumulative savings)
      if (now.difference(ts).inDays < 7) {
           final category = log['category'] as int?;
           // 0 = Urgent, 1 = Buffer, 2 = Spam
           if (category == 1 || category == 2) {
             // We buffered or blocked it, saving focus time!
             // Adding 1 to that weekday's count.
             roiCounts[ts.weekday - 1]++;
           }
      }
    }
    
    // Process sources for pie chart
    final sortedSources = sourceCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSources = sortedSources.take(3).toList();
    final otherCount = sortedSources.skip(3).fold(0, (sum, item) => sum + item.value);
    
    final List<PieChartSectionData> newSourceData = [];
    final List<Widget> newLegendWidgets = [];
    final colors = [AppTheme.spamAccent, AppTheme.urgentAccent, AppTheme.bufferAccent, Colors.white24];
    
    for (int i = 0; i < topSources.length; i++) {
        newSourceData.add(PieChartSectionData(value: topSources[i].value.toDouble(), color: colors[i], radius: 15, showTitle: false));
        newLegendWidgets.add(_buildLegendItem(topSources[i].key.toUpperCase(), colors[i]));
        newLegendWidgets.add(const SizedBox(height: 12));
    }
    if (otherCount > 0 || topSources.isEmpty) {
        newSourceData.add(PieChartSectionData(value: otherCount.toDouble(), color: colors[3], radius: 15, showTitle: false));
        newLegendWidgets.add(_buildLegendItem('OTHER', colors[3]));
    }

    setState(() {
      _urgentCount = (counts['urgent'] as num?)?.toInt() ?? 0;
      _bufferCount = (counts['buffer'] as num?)?.toInt() ?? 0;
      _spamCount = (counts['spam'] as num?)?.toInt() ?? 0;
      _latency = (counts['latency'] as num?)?.toDouble() ?? 0.0;
      _literalMins = (counts['literal_mins'] as num?)?.toDouble() ?? 0.0;
      _cognitiveMins = (counts['cognitive_mins'] as num?)?.toDouble() ?? 0.0;
      
      _temporalData = [
         FlSpot(0, tData[0].toDouble()),
         FlSpot(6, tData[1].toDouble()),
         FlSpot(12, tData[2].toDouble()),
         FlSpot(18, tData[3].toDouble()),
         FlSpot(24, tData[4].toDouble()),
      ];
      
      _contextualData = cData.map((e) => RadarEntry(value: e.toDouble())).toList();
      _sourceData = newSourceData.isEmpty ? [PieChartSectionData(value: 1, color: Colors.white24, radius: 15, showTitle: false)] : newSourceData;
      _sourceLegend = newLegendWidgets.isEmpty ? [_buildLegendItem('NO DATA', Colors.white24)] : newLegendWidgets;

      double cumulativeRoi = 0;
      _roiData = [];
      for (int i = 0; i < 7; i++) {
        cumulativeRoi += roiCounts[i];
        _roiData.add(FlSpot((i+1).toDouble(), cumulativeRoi));
      }
      
      _isLoading = false;
    });
  }

@override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final int totalCount = _urgentCount + _bufferCount + _spamCount;
    final int interceptedTotal = _spamCount + _bufferCount;
    final double suppressRate = totalCount == 0 ? 0 : (interceptedTotal / totalCount) * 100;

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: AnimatedScale(
        scale: _isAiCoachEnabled ? 1.0 : 0.0,
        curve: Curves.easeOutBack,
        duration: const Duration(milliseconds: 300),
        child: AnimatedOpacity(
          opacity: _isAiCoachEnabled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton(
            onPressed: _isAiCoachEnabled ? () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(start: now, end: now),
                firstDate: DateTime(2023),
                lastDate: now,
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      scaffoldBackgroundColor: Colors.black,
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.white,
                        onPrimary: Colors.black,
                        surface: Colors.black,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              
              if (range != null) {
                 final endInclusive = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
                 _generateAiReport(range.start, endInclusive);
              }
            } : null,
            backgroundColor: AppTheme.urgentAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INSIGHTS', style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 2)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('AI Coach Enabled', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16)),
                  Switch(
                    value: _isAiCoachEnabled,
                    onChanged: (val) {
                      _toggleAiCoach(val);
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppTheme.urgentAccent,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white24,
                  ),
                ],
              ),
              const SizedBox(height: 48),
              
              // Top Big Times
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showCognitivePrimary = !_showCognitivePrimary;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 850),
                        curve: Curves.easeInOutCubic,
                        alignment: _showCognitivePrimary ? Alignment.topCenter : Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 850),
                                curve: Curves.easeInOutCubic,
                                style: GoogleFonts.inter(
                                  color: _showCognitivePrimary ? Colors.white : Colors.white70,
                                  fontSize: _showCognitivePrimary ? 64 : 42,
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: 1,
                                ),
                                child: Text(_formatTime(_cognitiveMins)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 850),
                              curve: Curves.easeInOutCubic,
                              style: GoogleFonts.inter(
                                color: _showCognitivePrimary ? Colors.white54 : Colors.white30,
                                fontSize: _showCognitivePrimary ? 11 : 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3,
                              ),
                              child: const Text('COGNITIVE FOCUS RETAINED'),
                            ),
                          ],
                        ),
                      ),
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 850),
                        curve: Curves.easeInOutCubic,
                        alignment: !_showCognitivePrimary ? Alignment.topCenter : Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 850),
                                curve: Curves.easeInOutCubic,
                                style: GoogleFonts.inter(
                                  color: !_showCognitivePrimary ? Colors.white : Colors.white70,
                                  fontSize: !_showCognitivePrimary ? 64 : 42,
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: 1,
                                ),
                                child: Text(_formatTime(_literalMins)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 850),
                              curve: Curves.easeInOutCubic,
                              style: GoogleFonts.inter(
                                color: !_showCognitivePrimary ? Colors.white54 : Colors.white30,
                                fontSize: !_showCognitivePrimary ? 11 : 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3,
                              ),
                              child: const Text('LITERAL SCREEN TIME AVOIDED'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 64),
              // Category Progress Bars
              _buildProgressBar('URGENT', _urgentCount, totalCount, AppTheme.urgentAccent),
              const SizedBox(height: 24),
              _buildProgressBar('BUFFER', _bufferCount, totalCount, const Color(0xFF0F80FF)),
              const SizedBox(height: 24),
              _buildProgressBar('BLOCKED', _spamCount, totalCount, Colors.white24),
              
              const SizedBox(height: 64),
              Text('REALTIME BENCHMARKS', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 2)),
              const SizedBox(height: 24),
              _buildBenchmarkRow(Icons.shield_outlined, 'Suppressed ${suppressRate.toStringAsFixed(1)}% of total incoming traffic'),
              const SizedBox(height: 16),
              _buildBenchmarkRow(Icons.stay_current_portrait, 'Averted $interceptedTotal physical screen engagements'),
              const SizedBox(height: 16),
              _buildBenchmarkRow(Icons.speed, 'True Native TFLite executing in ${_latency.toStringAsFixed(2)}ms'),
              
              const SizedBox(height: 32),
              _buildCard(
                '24HR VOLUME',
                SizedBox(
                  height: 140,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 6,
                            getTitlesWidget: (value, meta) {
                              String t = '';
                              if (value == 0) t = '12AM';
                              if (value == 6) t = '6AM';
                              if (value == 12) t = '12PM';
                              if (value == 18) t = '6PM';
                              if (value == 24) t = '12AM';
                              return Text(t, style: GoogleFonts.inter(color: Colors.white30, fontSize: 10));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 24,
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _temporalData.isEmpty ? [const FlSpot(0,0)] : _temporalData,
                          isCurved: true,
                          color: AppTheme.urgentAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                               colors: [AppTheme.urgentAccent.withOpacity(0.3), Colors.transparent],
                               begin: Alignment.topCenter,
                               end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _buildCard(
                'CONTEXTUAL STATES',
                SizedBox(
                  height: 180,
                  child: RadarChart(
                    RadarChartData(
                      dataSets: [
                        RadarDataSet(
                          fillColor: const Color(0xFF0F80FF).withOpacity(0.2),
                          borderColor: const Color(0xFF0F80FF),
                          entryRadius: 0,
                          dataEntries: _contextualData.isEmpty ? List.generate(4, (_) => const RadarEntry(value: 0)) : _contextualData,
                          borderWidth: 2,
                        ),
                      ],
                      radarBackgroundColor: Colors.transparent,
                      borderData: FlBorderData(show: false),
                      radarBorderData: const BorderSide(color: Colors.white12, width: 1),
                      getTitle: (index, angle) {
                        final titles = ['Focus', 'Drive', 'Night', 'Default'];
                        return RadarChartTitle(
                          text: titles[index],
                          angle: 0,
                          positionPercentageOffset: 0.1,
                        );
                      },
                      titleTextStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                      tickCount: 3,
                      ticksTextStyle: const TextStyle(color: Colors.transparent),
                      tickBorderData: const BorderSide(color: Colors.white12, width: 1),
                      gridBorderData: const BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _buildCard(
                'TOP INTERRUPTIONS',
                Row(
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 40,
                          sections: _sourceData.isEmpty
                            ? [PieChartSectionData(color: Colors.white12, value: 1, showTitle: false)]
                            : _sourceData,
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _sourceLegend.isEmpty 
                            ? [const Text('No Data', style: TextStyle(color: Colors.white54))] 
                            : _sourceLegend,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildCard(
                'COGNITIVE ROI (7D)',
                SizedBox(
                  height: 140,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              if (value == 1) return Text('Mon', style: GoogleFonts.inter(color: Colors.white30, fontSize: 10));
                              if (value == 4) return Text('Thu', style: GoogleFonts.inter(color: Colors.white30, fontSize: 10));
                              if (value == 7) return Text('Sun', style: GoogleFonts.inter(color: Colors.white30, fontSize: 10));
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _roiData.isEmpty ? const [FlSpot(1, 0), FlSpot(7, 0)] : _roiData,
                          isCurved: true, 
                          color: Colors.white,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) => _roiData.isNotEmpty && spot.x == _roiData.last.x,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(radius: 4, color: AppTheme.urgentAccent, strokeWidth: 0),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(double totalMins) {
    if (totalMins == 0) return "0m";
    final h = totalMins ~/ 60;
    final m = (totalMins % 60).floor();
    final s = ((totalMins * 60) % 60).floor();
    if (h > 0) return "${h}h ${m}m ${s}s";
    return "${m}m ${s}s";
  }

  Widget _buildProgressBar(String title, int count, int total, Color color) {
    final flex = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
            Text('$count', style: GoogleFonts.inter(color: color == Colors.white24 ? Colors.white54 : color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: flex,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenchmarkRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14))),
      ],
    );
  }

  Widget _buildCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  Widget _buildLegendItem(String name, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name, 
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
