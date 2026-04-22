// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_rule_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AppRuleModel _$AppRuleModelFromJson(Map<String, dynamic> json) {
  return _AppRuleModel.fromJson(json);
}

/// @nodoc
mixin _$AppRuleModel {
  int get id => throw _privateConstructorUsedError;
  String get packageName => throw _privateConstructorUsedError;
  String get appName => throw _privateConstructorUsedError;
  String get ruleMode => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;
  int get minPriority => throw _privateConstructorUsedError;
  int get createdAt => throw _privateConstructorUsedError;
  int get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AppRuleModelCopyWith<AppRuleModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppRuleModelCopyWith<$Res> {
  factory $AppRuleModelCopyWith(
          AppRuleModel value, $Res Function(AppRuleModel) then) =
      _$AppRuleModelCopyWithImpl<$Res, AppRuleModel>;
  @useResult
  $Res call(
      {int id,
      String packageName,
      String appName,
      String ruleMode,
      bool isEnabled,
      int minPriority,
      int createdAt,
      int updatedAt});
}

/// @nodoc
class _$AppRuleModelCopyWithImpl<$Res, $Val extends AppRuleModel>
    implements $AppRuleModelCopyWith<$Res> {
  _$AppRuleModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? packageName = null,
    Object? appName = null,
    Object? ruleMode = null,
    Object? isEnabled = null,
    Object? minPriority = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      packageName: null == packageName
          ? _value.packageName
          : packageName // ignore: cast_nullable_to_non_nullable
              as String,
      appName: null == appName
          ? _value.appName
          : appName // ignore: cast_nullable_to_non_nullable
              as String,
      ruleMode: null == ruleMode
          ? _value.ruleMode
          : ruleMode // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      minPriority: null == minPriority
          ? _value.minPriority
          : minPriority // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppRuleModelImplCopyWith<$Res>
    implements $AppRuleModelCopyWith<$Res> {
  factory _$$AppRuleModelImplCopyWith(
          _$AppRuleModelImpl value, $Res Function(_$AppRuleModelImpl) then) =
      __$$AppRuleModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String packageName,
      String appName,
      String ruleMode,
      bool isEnabled,
      int minPriority,
      int createdAt,
      int updatedAt});
}

/// @nodoc
class __$$AppRuleModelImplCopyWithImpl<$Res>
    extends _$AppRuleModelCopyWithImpl<$Res, _$AppRuleModelImpl>
    implements _$$AppRuleModelImplCopyWith<$Res> {
  __$$AppRuleModelImplCopyWithImpl(
      _$AppRuleModelImpl _value, $Res Function(_$AppRuleModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? packageName = null,
    Object? appName = null,
    Object? ruleMode = null,
    Object? isEnabled = null,
    Object? minPriority = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$AppRuleModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      packageName: null == packageName
          ? _value.packageName
          : packageName // ignore: cast_nullable_to_non_nullable
              as String,
      appName: null == appName
          ? _value.appName
          : appName // ignore: cast_nullable_to_non_nullable
              as String,
      ruleMode: null == ruleMode
          ? _value.ruleMode
          : ruleMode // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      minPriority: null == minPriority
          ? _value.minPriority
          : minPriority // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppRuleModelImpl implements _AppRuleModel {
  const _$AppRuleModelImpl(
      {required this.id,
      required this.packageName,
      required this.appName,
      required this.ruleMode,
      required this.isEnabled,
      required this.minPriority,
      required this.createdAt,
      required this.updatedAt});

  factory _$AppRuleModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppRuleModelImplFromJson(json);

  @override
  final int id;
  @override
  final String packageName;
  @override
  final String appName;
  @override
  final String ruleMode;
  @override
  final bool isEnabled;
  @override
  final int minPriority;
  @override
  final int createdAt;
  @override
  final int updatedAt;

  @override
  String toString() {
    return 'AppRuleModel(id: $id, packageName: $packageName, appName: $appName, ruleMode: $ruleMode, isEnabled: $isEnabled, minPriority: $minPriority, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppRuleModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.packageName, packageName) ||
                other.packageName == packageName) &&
            (identical(other.appName, appName) || other.appName == appName) &&
            (identical(other.ruleMode, ruleMode) ||
                other.ruleMode == ruleMode) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled) &&
            (identical(other.minPriority, minPriority) ||
                other.minPriority == minPriority) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, packageName, appName,
      ruleMode, isEnabled, minPriority, createdAt, updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AppRuleModelImplCopyWith<_$AppRuleModelImpl> get copyWith =>
      __$$AppRuleModelImplCopyWithImpl<_$AppRuleModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppRuleModelImplToJson(
      this,
    );
  }
}

abstract class _AppRuleModel implements AppRuleModel {
  const factory _AppRuleModel(
      {required final int id,
      required final String packageName,
      required final String appName,
      required final String ruleMode,
      required final bool isEnabled,
      required final int minPriority,
      required final int createdAt,
      required final int updatedAt}) = _$AppRuleModelImpl;

  factory _AppRuleModel.fromJson(Map<String, dynamic> json) =
      _$AppRuleModelImpl.fromJson;

  @override
  int get id;
  @override
  String get packageName;
  @override
  String get appName;
  @override
  String get ruleMode;
  @override
  bool get isEnabled;
  @override
  int get minPriority;
  @override
  int get createdAt;
  @override
  int get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$AppRuleModelImplCopyWith<_$AppRuleModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
