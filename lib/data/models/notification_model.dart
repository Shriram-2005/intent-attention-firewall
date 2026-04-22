import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required int id,
    required String packageName,
    required String appName,
    required String title,
    required String body,
    required String category,
    required int priority,
    required bool isRead,
    required bool isDismissed,
    required bool isSnoozed,
    required int snoozeUntil,
    required int timestamp,
    required String sender,
    required double aiScore,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}
