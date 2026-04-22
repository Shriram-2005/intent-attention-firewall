import '../datasources/local/db_channel_service.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final DbChannelService _dbService;

  NotificationRepository(this._dbService);

  Future<List<NotificationModel>> getRecentNotifications({int limit = 50}) {
    return _dbService.getRecentNotifications(limit: limit);
  }

  Future<int> getUnreadCount() {
    return _dbService.getUnreadCount();
  }

  Future<int> getTodayCount() {
    return _dbService.getTodayCount();
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown() {
    return _dbService.getCategoryBreakdown();
  }

  Future<void> insertNotification(Map<String, dynamic> data) {
    return _dbService.insertNotification(data);
  }

  Future<void> markAsRead(int id) {
    return _dbService.markAsRead(id);
  }

  Future<void> markAsDismissed(int id) {
    return _dbService.markAsDismissed(id);
  }

  Future<void> snoozeNotification(int id, int until) {
    return _dbService.snoozeNotification(id, until);
  }

  Future<void> markAllAsRead() {
    return _dbService.markAllAsRead();
  }

  Future<void> deleteNotificationById(int id) {
    return _dbService.deleteNotificationById(id);
  }

  Future<void> deleteAllNotifications() {
    return _dbService.deleteAllNotifications();
  }
}
