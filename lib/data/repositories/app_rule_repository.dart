import '../datasources/local/db_channel_service.dart';
import '../models/app_rule_model.dart';

class AppRuleRepository {
  final DbChannelService _dbService;

  AppRuleRepository(this._dbService);

  Future<List<AppRuleModel>> getAllRules() {
    return _dbService.getAllRules();
  }

  Future<AppRuleModel?> getRuleByPackage(String packageName) {
    return _dbService.getRuleByPackage(packageName);
  }

  Future<void> insertRule(Map<String, dynamic> data) {
    return _dbService.insertRule(data);
  }

  Future<void> updateRuleMode(String packageName, String mode) {
    return _dbService.updateRuleMode(packageName, mode);
  }

  Future<void> setRuleEnabled(String packageName, bool enabled) {
    return _dbService.setRuleEnabled(packageName, enabled);
  }

  Future<void> deleteRuleByPackage(String packageName) {
    return _dbService.deleteRuleByPackage(packageName);
  }

  Future<int> getEnabledRulesCount() {
    return _dbService.getEnabledRulesCount();
  }
}
