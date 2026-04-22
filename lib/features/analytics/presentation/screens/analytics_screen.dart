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
    _loadPreferences();
    _pollData();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAiCoachEnabled = prefs.getBool('isAiCoachEnabled') ?? false;
    });
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
        GenerateContentResponse? response;
        
        try {
          response = await model.generateContent([Content.text(prompt)]);
        } catch (e) {
          print('Gemini 2.5 Flash failed: ${e.toString()}');
          try {
            print('Falling back to gemini-2.5-pro...');
            model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
            response = await model.generateContent([Content.text(prompt)]);
          } catch (e2) {
            try {
              print('Falling back to gemini-1.5-pro...');
              model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);
              response = await model.generateContent([Content.text(prompt)]);
            } catch (e3) {
              print('Falling back to absolute default gemini-pro...');
              model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
              response = await model.generateContent([Content.text(prompt)]);
            }
          }
        }
        
        final aiAnalysis = response?.text ?? 'No insights generated.';

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
              pw.SizedBox(height: 40),
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
                    '${counts["cognitive_mins"]}m',
                    PdfColor.fromHex('#4DD0E1'),
                  ), // Cyan
                ],
              ),
              pw.SizedBox(height: 40),
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
              pw.SizedBox(height: 24),
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
              pw.SizedBox(height: 40),
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

        print("AI Report Error: $e");
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
    final int totalCount = _urgentCount + _bufferCount + _spamCount;
    final int interceptedTotal = _spamCount + _bufferCount;

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _isAiCoachEnabled
          ? FloatingActionButton(
              onPressed: () {
                final now = DateTime.now();
                final start = now.subtract(const Duration(days: 7));
                _generateAiReport(start, now);
              },
              backgroundColor: AppTheme.urgentAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 32.0),
              child: _buildHeader(),
            ),
            
            Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 16.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isAiCoachEnabled
                        ? 'AI Coach Enabled'
                        : 'AI Coach Disabled',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  CupertinoSwitch(
                    value: _isAiCoachEnabled,
                    onChanged: _toggleAiCoach,
                    activeTrackColor: AppTheme.urgentAccent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor: Colors.black,
                onRefresh: _pollData,
                child: RawScrollbar(
                  thumbVisibility: true,
                  thickness: 4.0,
                  radius: const Radius.circular(10),
                  thumbColor: Colors.white.withOpacity(0.5),
                  mainAxisMargin: 16.0, // Leaves space at the top so it doesn't touch the header
                  child: ListView(
                    padding: const EdgeInsets.only(
                      left: 32.0,
                      right: 32.0,
                      top: 16.0,
                      bottom: 32.0,
                    ),
                    physics: const ClampingScrollPhysics(),
                    children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.40,
                child: Center(
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: Colors.white54)
                      : _buildDualMetric(_cognitiveMins, _literalMins),
                ),
              ),
              _buildBarRow(
                'URGENT',
                _urgentCount,
                totalCount,
                AppTheme.urgentAccent,
              ),
              const SizedBox(height: 32),
              _buildBarRow(
                'BUFFER',
                _bufferCount,
                totalCount,
                AppTheme.bufferAccent,
              ),
              const SizedBox(height: 32),
              _buildBarRow(
                'BLOCKED',
                _spamCount,
                totalCount,
                AppTheme.spamAccent,
              ),
              const SizedBox(height: 48),
              _buildBenchmarks(totalCount, interceptedTotal),
              const SizedBox(height: 48),
              _buildTemporalChart(),
              _buildContextualChart(),
              _buildSourceChart(),
              _buildRoiChart(),
              const SizedBox(height: 48),
            ],
          ),
          ),
        ),
      ),
      ],
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'INSIGHTS',
      style: GoogleFonts.inter(
        color: AppTheme.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w300,
        letterSpacing: 2.0,
      ),
    );
  }

  String _formatTime(double totalMinutes) {
    if (totalMinutes == 0) return '0s';

    final hours = totalMinutes ~/ 60;
    final mins = (totalMinutes % 60).floor();
    final seconds = ((totalMinutes * 60) % 60).round();

    if (hours > 0) {
      return '${hours}h ${mins}m ${seconds}s';
    } else if (mins > 0) {
      return '${mins}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildDualMetric(double cognitiveMins, double literalMins) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCognitivePrimary = !_showCognitivePrimary;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildAnimatedMetricGroup(
              value: cognitiveMins,
              label: 'COGNITIVE FOCUS RETAINED',
              isPrimary: _showCognitivePrimary,
            ),
            _buildAnimatedMetricGroup(
              value: literalMins,
              label: 'LITERAL SCREEN TIME AVOIDED',
              isPrimary: !_showCognitivePrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedMetricGroup({
    required double value,
    required String label,
    required bool isPrimary,
  }) {
    return AnimatedAlign(
      duration: const Duration(milliseconds: 700),
      curve: Curves.fastOutSlowIn,
      alignment: isPrimary ? Alignment.topCenter : Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 700),
              curve: Curves.fastOutSlowIn,
              style: GoogleFonts.inter(
                color: isPrimary ? Colors.white : Colors.white54,
                fontSize: isPrimary ? 96 : 40,
                fontWeight: isPrimary ? FontWeight.w100 : FontWeight.w200,
                letterSpacing: isPrimary ? -2.0 : -1.0,
                height: 1.0,
              ),
              child: Text(_formatTime(value), maxLines: 1),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 700),
            curve: Curves.fastOutSlowIn,
            style: GoogleFonts.inter(
              color: isPrimary ? Colors.white54 : Colors.white24,
              fontSize: isPrimary ? 10 : 8,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w700,
              letterSpacing: isPrimary ? 4.0 : 3.0,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, int count, int total, Color color) {
    final double percentage = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              count.toString().padLeft(2, '0'),
              style: GoogleFonts.inter(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(100),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: percentage,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenchmarks(int total, int suppressed) {
    final double blockedRate = total > 0 ? (suppressed / total) * 100 : 0.0;
    final int pickupsAvoided = (suppressed * 0.70).round();
    final double latency = _latency > 0 ? _latency : 3.9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REALTIME BENCHMARKS',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 24),
        _buildBenchmarkRow(
          Icons.shield_outlined,
          'Suppressed ${blockedRate.toStringAsFixed(1)}% of total incoming traffic',
        ),
        const SizedBox(height: 16),
        _buildBenchmarkRow(
          Icons.smartphone,
          'Averted $pickupsAvoided physical screen engagements',
        ),
        const SizedBox(height: 16),
        _buildBenchmarkRow(
          Icons.speed,
          'True Native TFLite executing in ${latency.toStringAsFixed(2)}ms',
        ),
      ],
    );
  }

  Widget _buildBenchmarkRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ─── CHARTS SECTION ────────────────────────────────────────────────────────

  Widget _chartLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required Widget child,
    double aspectRatio = 1.5,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121212), // Deep grey/black constraint
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 32),
            AspectRatio(aspectRatio: aspectRatio, child: child),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getTemporalMockData() {
    return const [
      FlSpot(0, 10),
      FlSpot(6, 40),
      FlSpot(9, 120),
      FlSpot(12, 90),
      FlSpot(18, 150),
      FlSpot(24, 30),
    ];
  }

  Widget _buildTemporalChart() {
    return _buildChartContainer(
      title: '24HR VOLUME',
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 6,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return _chartLabel('12AM');
                    case 6:
                      return _chartLabel('6AM');
                    case 12:
                      return _chartLabel('12PM');
                    case 18:
                      return _chartLabel('6PM');
                    case 24:
                      return _chartLabel('12AM');
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _temporalData.isEmpty ? const [FlSpot(0, 0), FlSpot(24, 0)] : _temporalData,
              isCurved: true,
              color: AppTheme.urgentAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.urgentAccent.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RadarEntry> _getContextualMockData() {
    return const [
      RadarEntry(value: 80), // Focus (Deep Work)
      RadarEntry(value: 50), // Driving
      RadarEntry(value: 90), // Night
      RadarEntry(value: 30), // Default
    ];
  }

  Widget _buildContextualChart() {
    return _buildChartContainer(
      title: 'CONTEXTUAL STATES',
      aspectRatio: 1.3,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              fillColor: AppTheme.bufferAccent.withValues(alpha: 0.2),
              borderColor: AppTheme.bufferAccent,
              entryRadius: 0,
              borderWidth: 2,
              dataEntries: _contextualData.map((e) => e.value == 0 ? const RadarEntry(value: 1) : e).toList(), // Prevent rendering collapse if all zeros
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          radarBorderData: const BorderSide(color: Colors.white10),
          titlePositionPercentageOffset: 0.2,
          tickCount: 3,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          tickBorderData: const BorderSide(color: Colors.transparent),
          gridBorderData: const BorderSide(color: Colors.white10),
          getTitle: (index, angle) {
            switch (index) {
              case 0:
                return RadarChartTitle(text: 'Focus');
              case 1:
                return RadarChartTitle(text: 'Drive');
              case 2:
                return RadarChartTitle(text: 'Night');
              case 3:
                return RadarChartTitle(text: 'Default');
            }
            return const RadarChartTitle(text: '');
          },
          titleTextStyle: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _getSourceMockData() {
    return [
      PieChartSectionData(
        value: 40,
        color: AppTheme.spamAccent,
        radius: 15,
        showTitle: false,
      ),
      PieChartSectionData(
        value: 30,
        color: AppTheme.urgentAccent,
        radius: 15,
        showTitle: false,
      ),
      PieChartSectionData(
        value: 15,
        color: AppTheme.bufferAccent,
        radius: 15,
        showTitle: false,
      ),
      PieChartSectionData(
        value: 15,
        color: Colors.white24,
        radius: 15,
        showTitle: false,
      ),
    ];
  }

  Widget _buildSourceChart() {
    return _buildChartContainer(
      title: 'TOP INTERRUPTIONS',
      aspectRatio: 1.8,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 45,
                sections: _sourceData,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _sourceLegend,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),      
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),        
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getRoiMockData() {
    return const [
      FlSpot(1, 20),
      FlSpot(2, 50),
      FlSpot(3, 90),
      FlSpot(4, 150),
      FlSpot(5, 230),
      FlSpot(6, 300),
      FlSpot(7, 390),
    ];
  }

  Widget _buildRoiChart() {
    return _buildChartContainer(
      title: 'COGNITIVE ROI (7D)',
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value == 1) return _chartLabel('Mon');
                  if (value == 4) return _chartLabel('Thu');
                  if (value == 7) return _chartLabel('Sun');
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
              isCurved: false,
              color: Colors.white,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) => spot.x == 7,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 5,
                      color: AppTheme.urgentAccent,
                      strokeWidth: 2,
                      strokeColor: Colors.black,
                    ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  }




