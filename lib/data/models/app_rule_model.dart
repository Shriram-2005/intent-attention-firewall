import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_rule_model.freezed.dart';
part 'app_rule_model.g.dart';

@freezed
class AppRuleModel with _$AppRuleModel {
  const factory AppRuleModel({
    required int id,
    required String packageName,
    required String appName,
    required String ruleMode,
    required bool isEnabled,
    required int minPriority,
    required int createdAt,
    required int updatedAt,
  }) = _AppRuleModel;

  factory AppRuleModel.fromJson(Map<String, dynamic> json) =>
      _$AppRuleModelFromJson(json);
}
