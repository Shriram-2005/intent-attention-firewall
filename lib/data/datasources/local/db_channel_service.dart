import 'package:flutter/services.dart';
import '../../models/notification_model.dart';
import '../../models/app_rule_model.dart';

class DbChannelService {
  static const MethodChannel _channel = MethodChannel('com.intent.intent_app/db');

  // ── Notifications ────────────────────────────────────────────────────────

  Future<List<NotificationModel>> getRecentNotifications({int limit = 50}) async {
    final List<dynamic>? result = await _channel.invokeMethod('notifications.getRecent', {'limit': limit});
    if (result == null) return [];
    return result.map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<int> getUnreadCount() async {
    final int? result = await _channel.invokeMethod('notifications.getUnreadCount');
    return result ?? 0;
  }

  Future<int> getTodayCount() async {
    final int? result = await _channel.invokeMethod('notifications.getTodayCount');
    return result ?? 0;
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown() async {
    final List<dynamic>? result = await _channel.invokeMethod('notifications.getCategoryBreakdown');
    if (result == null) return [];
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> insertNotification(Map<String, dynamic> data) async {
    await _channel.invokeMethod('notifications.insert', data);
  }

  Future<void> markAsRead(int id) async {
    await _channel.invokeMethod('notifications.markAsRead', {'id': id});
  }

  Future<void> markAsDismissed(int id) async {
    await _channel.invokeMethod('notifications.markAsDismissed', {'id': id});
  }

  Future<void> snoozeNotification(int id, int until) async {
    await _channel.invokeMethod('notifications.snooze', {'id': id, 'until': until});
  }

  Future<void> markAllAsRead() async {
    await _channel.invokeMethod('notifications.markAllAsRead');
  }

  Future<void> deleteNotificationById(int id) async {
    await _channel.invokeMethod('notifications.deleteById', {'id': id});
  }

  Future<void> deleteAllNotifications() async {
    await _channel.invokeMethod('notifications.deleteAll');
  }

  // ── App Rules ────────────────────────────────────────────────────────────

  Future<List<AppRuleModel>> getAllRules() async {
    final List<dynamic>? result = await _channel.invokeMethod('rules.getAll');
    if (result == null) return [];
    return result.map((e) => AppRuleModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<AppRuleModel?> getRuleByPackage(String packageName) async {
    final dynamic result = await _channel.invokeMethod('rules.getByPackage', {'packageName': packageName});
    if (result == null) return null;
    return AppRuleModel.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> insertRule(Map<String, dynamic> data) async {
    await _channel.invokeMethod('rules.insert', data);
  }

  Future<void> updateRuleMode(String packageName, String mode) async {
    await _channel.invokeMethod('rules.updateMode', {'packageName': packageName, 'mode': mode});
  }

  Future<void> setRuleEnabled(String packageName, bool enabled) async {
    await _channel.invokeMethod('rules.setEnabled', {'packageName': packageName, 'enabled': enabled});
  }

  Future<void> deleteRuleByPackage(String packageName) async {
    await _channel.invokeMethod('rules.deleteByPackage', {'packageName': packageName});
  }

  Future<int> getEnabledRulesCount() async {
    final int? result = await _channel.invokeMethod('rules.getEnabledCount');
    return result ?? 0;
  }
}
