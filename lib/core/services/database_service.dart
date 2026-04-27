import 'package:flutter/services.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  final _dbChannel = const MethodChannel('com.intent.intent_app/db');
  final _permissionsChannel = const MethodChannel('com.intent.intent_app/permissions');
  final _settingsChannel = const MethodChannel('com.intent.intent_app/settings');

  /// Fetches historically stored notifications bypassing legacy features.
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final List<dynamic> result = await _dbChannel.invokeMethod('notifications.getHistory');
      return result.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Failed to get history: $e');
      return [];
    }
  }

  /// Fetches bounded historical notifications for Data Sovereignty filtering.
  Future<List<Map<String, dynamic>>> getHistoryBetween(int startMillis, int endMillis) async {
    try {
      final List<dynamic> result = await _dbChannel.invokeMethod('notifications.getHistoryBetween', {
        'startTime': startMillis,
        'endTime': endMillis,
      });
      return result.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Failed to get history between bounds: $e');
      return [];
    }
  }

  /// Truncates the SQLite database exactly within bounds for manual data purges
  Future<void> deleteHistoryBetween(int startMillis, int endMillis) async {
    try {
      await _dbChannel.invokeMethod('notifications.deleteHistoryBetween', {
        'startTime': startMillis,
        'endTime': endMillis,
      });
    } catch (e) {
      print('Failed to delete history: $e');
    }
  }

  /// Purges all data fully
  Future<void> deleteAllHistory() async {
    try {
      await _dbChannel.invokeMethod('notifications.deleteAllHistory');
    } catch (e) {
      print('Failed to delete all history: $e');
    }
  }

  /// Exports the fully checkpointed SQLite Database to a temp `.db` file and returns the path
  Future<String?> exportDatabase() async {
    try {
      final String? path = await _dbChannel.invokeMethod('notifications.exportDatabase');
      return path;
    } catch (e) {
      print('Failed to export DB: $e');
      return null;
    }
  }

  /// Imports a .db file.
  Future<void> importDatabase(String sourcePath) async {
    await _dbChannel.invokeMethod('notifications.importDatabase', {'filePath': sourcePath});
  }

  /// Calculates real-time metric counters globally for today.
  Future<Map<String, dynamic>> getCounts() async {
    try {
      final Map<dynamic, dynamic> result = await _dbChannel.invokeMethod('notifications.getCounts');
      return _parseCounts(result);
    } catch (e) {
      print('Failed to get counts: $e');
      return _emptyCounts();
    }
  }

  /// Calculates real-time metric counters strictly within a custom date range.
  Future<Map<String, dynamic>> getCountsBetween(int startMillis, int endMillis) async {
    try {
      final Map<dynamic, dynamic> result = await _dbChannel.invokeMethod('notifications.getCounts', {
        'startTime': startMillis,
        'endTime': endMillis,
      });
      return _parseCounts(result);
    } catch (e) {
      print('Failed to get counts bounded: $e');
      return _emptyCounts();
    }
  }

  Map<String, dynamic> _parseCounts(Map<dynamic, dynamic> result) {
      return {
        'urgent': result['urgent'] as num? ?? 0,
        'buffer': result['buffer'] as num? ?? 0,
        'spam': result['spam'] as num? ?? 0,
        'latency': result['latency'] as num? ?? 0.0,
        'literal_mins': result['literal_mins'] as num? ?? 0.0,
        'cognitive_mins': result['cognitive_mins'] as num? ?? 0.0,
      };
  }

  Map<String, dynamic> _emptyCounts() {
      return {'urgent': 0, 'buffer': 0, 'spam': 0, 'latency': 0.0, 'literal_mins': 0.0, 'cognitive_mins': 0.0};
  }

      /// Calculates the day streak of cognitive focus
    Future<int> getFocusStreak({double requiredMins = 60.0, int daysToCheck = 28}) async {
      int streak = 0;
      final now = DateTime.now();
      for (int i = 0; i < daysToCheck; i++) {
        final start = now.subtract(Duration(days: i)).copyWith(
          hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0
        );
        final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

        final counts = await getCountsBetween(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
        final mins = (counts['cognitive_mins'] as num?)?.toDouble() ?? 0.0;

        if (mins >= requiredMins) {
          streak++;
        } else {
          if (i == 0) continue; // It's today, keep the streak going since they have the rest of the day
          break; // Streak broken on a past day
        }
      }
      return streak;
    }

  /// Extremely fast intent launcher utilizing the pre-established db channel bridge
  Future<void> launchApp(String packageName) async {
    try {
      await _dbChannel.invokeMethod('notifications.launchApp', {'packageName': packageName});
    } catch (e) {
      print('Failed to launch app $packageName: $e');
    }
  }

  /// Fire the exact RAM-Cached message portal using the timestamp identity
  Future<void> launchMessage(int timestamp, String packageName) async {
    try {
      final success = await _dbChannel.invokeMethod<bool>('notifications.launchMessage', {'timestamp': timestamp});
      if (success != true) {
        print('Portal expired or OS cancelled... natively falling back to $packageName');
        await launchApp(packageName);
      }
    } catch (e) {
      print('Failed to launch portal $timestamp: $e');
      await launchApp(packageName);
    }
  }

  /// Pushes the new Daily Summary background execution frequency into WorkManager natively
  Future<void> updateSummaryInterval(int hours) async {
    try {
      await _settingsChannel.invokeMethod('settings.updateSummaryInterval', {'intervalHours': hours});
    } catch (e) {
      print('Failed to update summary interval: $e');
    }
  }

  Future<bool> checkAccess() async {
    try {
      final dynamic result = await _permissionsChannel.invokeMethod('permissions.check');
      if (result is Map) {
        return result['notification'] == true;
      }
      return result == true;
    } catch (e) {
      print('Failed to check permissions: $e');
      return false;
    }
  }

  Future<void> requestAccess() async {
    try {
      await _permissionsChannel.invokeMethod('permissions.request');
    } catch (e) {
      print('Failed to request permissions: $e');
    }
  }

  /// Sets the 9PM-ish end of day report Notification WorkManager natively
  Future<void> updateEndOfDayTime(int hour, int minute) async {
    try {
      await _settingsChannel.invokeMethod('settings.updateEndOfDay', {'hour': hour, 'minute': minute});
    } catch (e) {
      print('Failed to update end of day time: $e');
    }
  }
}

