// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationModelImpl _$$NotificationModelImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationModelImpl(
      id: (json['id'] as num).toInt(),
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String,
      priority: (json['priority'] as num).toInt(),
      isRead: json['isRead'] as bool,
      isDismissed: json['isDismissed'] as bool,
      isSnoozed: json['isSnoozed'] as bool,
      snoozeUntil: (json['snoozeUntil'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
      sender: json['sender'] as String,
      aiScore: (json['aiScore'] as num).toDouble(),
    );

Map<String, dynamic> _$$NotificationModelImplToJson(
        _$NotificationModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'packageName': instance.packageName,
      'appName': instance.appName,
      'title': instance.title,
      'body': instance.body,
      'category': instance.category,
      'priority': instance.priority,
      'isRead': instance.isRead,
      'isDismissed': instance.isDismissed,
      'isSnoozed': instance.isSnoozed,
      'snoozeUntil': instance.snoozeUntil,
      'timestamp': instance.timestamp,
      'sender': instance.sender,
      'aiScore': instance.aiScore,
    };
