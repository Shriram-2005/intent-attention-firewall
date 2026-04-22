import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local/db_channel_service.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/app_rule_repository.dart';

// Service Provider
final dbChannelServiceProvider = Provider<DbChannelService>((ref) {
  return DbChannelService();
});

// Repository Providers
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dbService = ref.watch(dbChannelServiceProvider);
  return NotificationRepository(dbService);
});

final appRuleRepositoryProvider = Provider<AppRuleRepository>((ref) {
  final dbService = ref.watch(dbChannelServiceProvider);
  return AppRuleRepository(dbService);
});
