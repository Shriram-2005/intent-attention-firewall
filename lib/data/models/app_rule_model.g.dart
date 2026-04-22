// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_rule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppRuleModelImpl _$$AppRuleModelImplFromJson(Map<String, dynamic> json) =>
    _$AppRuleModelImpl(
      id: (json['id'] as num).toInt(),
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      ruleMode: json['ruleMode'] as String,
      isEnabled: json['isEnabled'] as bool,
      minPriority: (json['minPriority'] as num).toInt(),
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
    );

Map<String, dynamic> _$$AppRuleModelImplToJson(_$AppRuleModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'packageName': instance.packageName,
      'appName': instance.appName,
      'ruleMode': instance.ruleMode,
      'isEnabled': instance.isEnabled,
      'minPriority': instance.minPriority,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };
