// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HabitDefTable extends HabitDef
    with TableInfo<$HabitDefTable, HabitDefData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitDefTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<String> createTime = GeneratedColumn<String>(
    'createTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<String> updateTime = GeneratedColumn<String>(
    'updateTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chainActionsMeta = const VerificationMeta(
    'chainActions',
  );
  @override
  late final GeneratedColumn<String> chainActions = GeneratedColumn<String>(
    'chainActions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekDaysMeta = const VerificationMeta(
    'weekDays',
  );
  @override
  late final GeneratedColumn<String> weekDays = GeneratedColumn<String>(
    'weekDays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<String> enabled = GeneratedColumn<String>(
    'enabled',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderTimesMeta = const VerificationMeta(
    'reminderTimes',
  );
  @override
  late final GeneratedColumn<String> reminderTimes = GeneratedColumn<String>(
    'reminderTimes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _freqTypeMeta = const VerificationMeta(
    'freqType',
  );
  @override
  late final GeneratedColumn<String> freqType = GeneratedColumn<String>(
    'freqType',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    key,
    createTime,
    updateTime,
    chainActions,
    weekDays,
    enabled,
    reminderTimes,
    remark,
    freqType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_def';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitDefData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('createTime')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['createTime']!, _createTimeMeta),
      );
    }
    if (data.containsKey('updateTime')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['updateTime']!, _updateTimeMeta),
      );
    }
    if (data.containsKey('chainActions')) {
      context.handle(
        _chainActionsMeta,
        chainActions.isAcceptableOrUnknown(
          data['chainActions']!,
          _chainActionsMeta,
        ),
      );
    }
    if (data.containsKey('weekDays')) {
      context.handle(
        _weekDaysMeta,
        weekDays.isAcceptableOrUnknown(data['weekDays']!, _weekDaysMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('reminderTimes')) {
      context.handle(
        _reminderTimesMeta,
        reminderTimes.isAcceptableOrUnknown(
          data['reminderTimes']!,
          _reminderTimesMeta,
        ),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('freqType')) {
      context.handle(
        _freqTypeMeta,
        freqType.isAcceptableOrUnknown(data['freqType']!, _freqTypeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitDefData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitDefData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}createTime'],
      ),
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updateTime'],
      ),
      chainActions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chainActions'],
      ),
      weekDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekDays'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled'],
      ),
      reminderTimes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminderTimes'],
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      freqType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}freqType'],
      ),
    );
  }

  @override
  $HabitDefTable createAlias(String alias) {
    return $HabitDefTable(attachedDatabase, alias);
  }
}

class HabitDefData extends DataClass implements Insertable<HabitDefData> {
  /// 旧层自增主键（桌面端声明的主键）
  final int id;
  final String? name;
  final String? value;
  final String? createdAt;

  /// 业务主键，形如 habit:mtdnjxqr-xc665i
  final String? key;
  final String? createTime;
  final String? updateTime;

  /// 链式动作 JSON，如 [{"type":"themeConversation"}]
  final String? chainActions;

  /// 生效星期 JSON，如 []
  final String? weekDays;

  /// 是否启用：'1'/'0'（桌面端布尔即文本）
  final String? enabled;

  /// 提醒时间 JSON，如 ["08:39"]
  final String? reminderTimes;
  final String? remark;

  /// 频率类型，如 daily
  final String? freqType;
  const HabitDefData({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.key,
    this.createTime,
    this.updateTime,
    this.chainActions,
    this.weekDays,
    this.enabled,
    this.reminderTimes,
    this.remark,
    this.freqType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    if (!nullToAbsent || createTime != null) {
      map['createTime'] = Variable<String>(createTime);
    }
    if (!nullToAbsent || updateTime != null) {
      map['updateTime'] = Variable<String>(updateTime);
    }
    if (!nullToAbsent || chainActions != null) {
      map['chainActions'] = Variable<String>(chainActions);
    }
    if (!nullToAbsent || weekDays != null) {
      map['weekDays'] = Variable<String>(weekDays);
    }
    if (!nullToAbsent || enabled != null) {
      map['enabled'] = Variable<String>(enabled);
    }
    if (!nullToAbsent || reminderTimes != null) {
      map['reminderTimes'] = Variable<String>(reminderTimes);
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    if (!nullToAbsent || freqType != null) {
      map['freqType'] = Variable<String>(freqType);
    }
    return map;
  }

  HabitDefCompanion toCompanion(bool nullToAbsent) {
    return HabitDefCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
      updateTime: updateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(updateTime),
      chainActions: chainActions == null && nullToAbsent
          ? const Value.absent()
          : Value(chainActions),
      weekDays: weekDays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekDays),
      enabled: enabled == null && nullToAbsent
          ? const Value.absent()
          : Value(enabled),
      reminderTimes: reminderTimes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderTimes),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      freqType: freqType == null && nullToAbsent
          ? const Value.absent()
          : Value(freqType),
    );
  }

  factory HabitDefData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitDefData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      key: serializer.fromJson<String?>(json['key']),
      createTime: serializer.fromJson<String?>(json['createTime']),
      updateTime: serializer.fromJson<String?>(json['updateTime']),
      chainActions: serializer.fromJson<String?>(json['chainActions']),
      weekDays: serializer.fromJson<String?>(json['weekDays']),
      enabled: serializer.fromJson<String?>(json['enabled']),
      reminderTimes: serializer.fromJson<String?>(json['reminderTimes']),
      remark: serializer.fromJson<String?>(json['remark']),
      freqType: serializer.fromJson<String?>(json['freqType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'key': serializer.toJson<String?>(key),
      'createTime': serializer.toJson<String?>(createTime),
      'updateTime': serializer.toJson<String?>(updateTime),
      'chainActions': serializer.toJson<String?>(chainActions),
      'weekDays': serializer.toJson<String?>(weekDays),
      'enabled': serializer.toJson<String?>(enabled),
      'reminderTimes': serializer.toJson<String?>(reminderTimes),
      'remark': serializer.toJson<String?>(remark),
      'freqType': serializer.toJson<String?>(freqType),
    };
  }

  HabitDefData copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> key = const Value.absent(),
    Value<String?> createTime = const Value.absent(),
    Value<String?> updateTime = const Value.absent(),
    Value<String?> chainActions = const Value.absent(),
    Value<String?> weekDays = const Value.absent(),
    Value<String?> enabled = const Value.absent(),
    Value<String?> reminderTimes = const Value.absent(),
    Value<String?> remark = const Value.absent(),
    Value<String?> freqType = const Value.absent(),
  }) => HabitDefData(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    key: key.present ? key.value : this.key,
    createTime: createTime.present ? createTime.value : this.createTime,
    updateTime: updateTime.present ? updateTime.value : this.updateTime,
    chainActions: chainActions.present ? chainActions.value : this.chainActions,
    weekDays: weekDays.present ? weekDays.value : this.weekDays,
    enabled: enabled.present ? enabled.value : this.enabled,
    reminderTimes: reminderTimes.present
        ? reminderTimes.value
        : this.reminderTimes,
    remark: remark.present ? remark.value : this.remark,
    freqType: freqType.present ? freqType.value : this.freqType,
  );
  HabitDefData copyWithCompanion(HabitDefCompanion data) {
    return HabitDefData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      key: data.key.present ? data.key.value : this.key,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
      chainActions: data.chainActions.present
          ? data.chainActions.value
          : this.chainActions,
      weekDays: data.weekDays.present ? data.weekDays.value : this.weekDays,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      reminderTimes: data.reminderTimes.present
          ? data.reminderTimes.value
          : this.reminderTimes,
      remark: data.remark.present ? data.remark.value : this.remark,
      freqType: data.freqType.present ? data.freqType.value : this.freqType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitDefData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('key: $key, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('chainActions: $chainActions, ')
          ..write('weekDays: $weekDays, ')
          ..write('enabled: $enabled, ')
          ..write('reminderTimes: $reminderTimes, ')
          ..write('remark: $remark, ')
          ..write('freqType: $freqType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    value,
    createdAt,
    key,
    createTime,
    updateTime,
    chainActions,
    weekDays,
    enabled,
    reminderTimes,
    remark,
    freqType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitDefData &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.key == this.key &&
          other.createTime == this.createTime &&
          other.updateTime == this.updateTime &&
          other.chainActions == this.chainActions &&
          other.weekDays == this.weekDays &&
          other.enabled == this.enabled &&
          other.reminderTimes == this.reminderTimes &&
          other.remark == this.remark &&
          other.freqType == this.freqType);
}

class HabitDefCompanion extends UpdateCompanion<HabitDefData> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> key;
  final Value<String?> createTime;
  final Value<String?> updateTime;
  final Value<String?> chainActions;
  final Value<String?> weekDays;
  final Value<String?> enabled;
  final Value<String?> reminderTimes;
  final Value<String?> remark;
  final Value<String?> freqType;
  const HabitDefCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.key = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.chainActions = const Value.absent(),
    this.weekDays = const Value.absent(),
    this.enabled = const Value.absent(),
    this.reminderTimes = const Value.absent(),
    this.remark = const Value.absent(),
    this.freqType = const Value.absent(),
  });
  HabitDefCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.key = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.chainActions = const Value.absent(),
    this.weekDays = const Value.absent(),
    this.enabled = const Value.absent(),
    this.reminderTimes = const Value.absent(),
    this.remark = const Value.absent(),
    this.freqType = const Value.absent(),
  });
  static Insertable<HabitDefData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? key,
    Expression<String>? createTime,
    Expression<String>? updateTime,
    Expression<String>? chainActions,
    Expression<String>? weekDays,
    Expression<String>? enabled,
    Expression<String>? reminderTimes,
    Expression<String>? remark,
    Expression<String>? freqType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (key != null) 'key': key,
      if (createTime != null) 'createTime': createTime,
      if (updateTime != null) 'updateTime': updateTime,
      if (chainActions != null) 'chainActions': chainActions,
      if (weekDays != null) 'weekDays': weekDays,
      if (enabled != null) 'enabled': enabled,
      if (reminderTimes != null) 'reminderTimes': reminderTimes,
      if (remark != null) 'remark': remark,
      if (freqType != null) 'freqType': freqType,
    });
  }

  HabitDefCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? key,
    Value<String?>? createTime,
    Value<String?>? updateTime,
    Value<String?>? chainActions,
    Value<String?>? weekDays,
    Value<String?>? enabled,
    Value<String?>? reminderTimes,
    Value<String?>? remark,
    Value<String?>? freqType,
  }) {
    return HabitDefCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      key: key ?? this.key,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      chainActions: chainActions ?? this.chainActions,
      weekDays: weekDays ?? this.weekDays,
      enabled: enabled ?? this.enabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      remark: remark ?? this.remark,
      freqType: freqType ?? this.freqType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (createTime.present) {
      map['createTime'] = Variable<String>(createTime.value);
    }
    if (updateTime.present) {
      map['updateTime'] = Variable<String>(updateTime.value);
    }
    if (chainActions.present) {
      map['chainActions'] = Variable<String>(chainActions.value);
    }
    if (weekDays.present) {
      map['weekDays'] = Variable<String>(weekDays.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<String>(enabled.value);
    }
    if (reminderTimes.present) {
      map['reminderTimes'] = Variable<String>(reminderTimes.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (freqType.present) {
      map['freqType'] = Variable<String>(freqType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitDefCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('key: $key, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('chainActions: $chainActions, ')
          ..write('weekDays: $weekDays, ')
          ..write('enabled: $enabled, ')
          ..write('reminderTimes: $reminderTimes, ')
          ..write('remark: $remark, ')
          ..write('freqType: $freqType')
          ..write(')'))
        .toString();
  }
}

class $HabitCheckinTable extends HabitCheckin
    with TableInfo<$HabitCheckinTable, HabitCheckinData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitCheckinTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _habitKeyMeta = const VerificationMeta(
    'habitKey',
  );
  @override
  late final GeneratedColumn<String> habitKey = GeneratedColumn<String>(
    'habitKey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    key,
    habitKey,
    note,
    date,
    source,
    time,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_checkin';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitCheckinData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('habitKey')) {
      context.handle(
        _habitKeyMeta,
        habitKey.isAcceptableOrUnknown(data['habitKey']!, _habitKeyMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitCheckinData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitCheckinData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      habitKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habitKey'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      ),
    );
  }

  @override
  $HabitCheckinTable createAlias(String alias) {
    return $HabitCheckinTable(attachedDatabase, alias);
  }
}

class HabitCheckinData extends DataClass
    implements Insertable<HabitCheckinData> {
  /// 旧层自增主键
  final int id;
  final String? name;
  final String? value;
  final String? createdAt;

  /// 打卡主键，形如 habit:xxx#2026-08-29
  final String? key;

  /// 所属习惯的 key
  final String? habitKey;
  final String? note;

  /// 打卡日期 yyyy-MM-dd
  final String? date;

  /// 来源，如 manual
  final String? source;

  /// 打卡时间 HH:mm:ss
  final String? time;
  const HabitCheckinData({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.key,
    this.habitKey,
    this.note,
    this.date,
    this.source,
    this.time,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    if (!nullToAbsent || habitKey != null) {
      map['habitKey'] = Variable<String>(habitKey);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<String>(time);
    }
    return map;
  }

  HabitCheckinCompanion toCompanion(bool nullToAbsent) {
    return HabitCheckinCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      habitKey: habitKey == null && nullToAbsent
          ? const Value.absent()
          : Value(habitKey),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
    );
  }

  factory HabitCheckinData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitCheckinData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      key: serializer.fromJson<String?>(json['key']),
      habitKey: serializer.fromJson<String?>(json['habitKey']),
      note: serializer.fromJson<String?>(json['note']),
      date: serializer.fromJson<String?>(json['date']),
      source: serializer.fromJson<String?>(json['source']),
      time: serializer.fromJson<String?>(json['time']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'key': serializer.toJson<String?>(key),
      'habitKey': serializer.toJson<String?>(habitKey),
      'note': serializer.toJson<String?>(note),
      'date': serializer.toJson<String?>(date),
      'source': serializer.toJson<String?>(source),
      'time': serializer.toJson<String?>(time),
    };
  }

  HabitCheckinData copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> key = const Value.absent(),
    Value<String?> habitKey = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> date = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> time = const Value.absent(),
  }) => HabitCheckinData(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    key: key.present ? key.value : this.key,
    habitKey: habitKey.present ? habitKey.value : this.habitKey,
    note: note.present ? note.value : this.note,
    date: date.present ? date.value : this.date,
    source: source.present ? source.value : this.source,
    time: time.present ? time.value : this.time,
  );
  HabitCheckinData copyWithCompanion(HabitCheckinCompanion data) {
    return HabitCheckinData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      key: data.key.present ? data.key.value : this.key,
      habitKey: data.habitKey.present ? data.habitKey.value : this.habitKey,
      note: data.note.present ? data.note.value : this.note,
      date: data.date.present ? data.date.value : this.date,
      source: data.source.present ? data.source.value : this.source,
      time: data.time.present ? data.time.value : this.time,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitCheckinData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('key: $key, ')
          ..write('habitKey: $habitKey, ')
          ..write('note: $note, ')
          ..write('date: $date, ')
          ..write('source: $source, ')
          ..write('time: $time')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    value,
    createdAt,
    key,
    habitKey,
    note,
    date,
    source,
    time,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitCheckinData &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.key == this.key &&
          other.habitKey == this.habitKey &&
          other.note == this.note &&
          other.date == this.date &&
          other.source == this.source &&
          other.time == this.time);
}

class HabitCheckinCompanion extends UpdateCompanion<HabitCheckinData> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> key;
  final Value<String?> habitKey;
  final Value<String?> note;
  final Value<String?> date;
  final Value<String?> source;
  final Value<String?> time;
  const HabitCheckinCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.key = const Value.absent(),
    this.habitKey = const Value.absent(),
    this.note = const Value.absent(),
    this.date = const Value.absent(),
    this.source = const Value.absent(),
    this.time = const Value.absent(),
  });
  HabitCheckinCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.key = const Value.absent(),
    this.habitKey = const Value.absent(),
    this.note = const Value.absent(),
    this.date = const Value.absent(),
    this.source = const Value.absent(),
    this.time = const Value.absent(),
  });
  static Insertable<HabitCheckinData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? key,
    Expression<String>? habitKey,
    Expression<String>? note,
    Expression<String>? date,
    Expression<String>? source,
    Expression<String>? time,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (key != null) 'key': key,
      if (habitKey != null) 'habitKey': habitKey,
      if (note != null) 'note': note,
      if (date != null) 'date': date,
      if (source != null) 'source': source,
      if (time != null) 'time': time,
    });
  }

  HabitCheckinCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? key,
    Value<String?>? habitKey,
    Value<String?>? note,
    Value<String?>? date,
    Value<String?>? source,
    Value<String?>? time,
  }) {
    return HabitCheckinCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      key: key ?? this.key,
      habitKey: habitKey ?? this.habitKey,
      note: note ?? this.note,
      date: date ?? this.date,
      source: source ?? this.source,
      time: time ?? this.time,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (habitKey.present) {
      map['habitKey'] = Variable<String>(habitKey.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitCheckinCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('key: $key, ')
          ..write('habitKey: $habitKey, ')
          ..write('note: $note, ')
          ..write('date: $date, ')
          ..write('source: $source, ')
          ..write('time: $time')
          ..write(')'))
        .toString();
  }
}

class $TodoListTable extends TodoList
    with TableInfo<$TodoListTable, TodoListData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoListTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'dueDate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<String> createTime = GeneratedColumn<String>(
    'createTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedTimeMeta = const VerificationMeta(
    'completedTime',
  );
  @override
  late final GeneratedColumn<String> completedTime = GeneratedColumn<String>(
    'completedTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<String> updateTime = GeneratedColumn<String>(
    'updateTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<String> completed = GeneratedColumn<String>(
    'completed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deadlineReminderMeta = const VerificationMeta(
    'deadlineReminder',
  );
  @override
  late final GeneratedColumn<String> deadlineReminder = GeneratedColumn<String>(
    'deadlineReminder',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindCountMeta = const VerificationMeta(
    'remindCount',
  );
  @override
  late final GeneratedColumn<String> remindCount = GeneratedColumn<String>(
    'remindCount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindIntervalMeta = const VerificationMeta(
    'remindInterval',
  );
  @override
  late final GeneratedColumn<String> remindInterval = GeneratedColumn<String>(
    'remindInterval',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindIntervalUnitMeta =
      const VerificationMeta('remindIntervalUnit');
  @override
  late final GeneratedColumn<String> remindIntervalUnit =
      GeneratedColumn<String>(
        'remindIntervalUnit',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parentId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceEndMeta = const VerificationMeta(
    'recurrenceEnd',
  );
  @override
  late final GeneratedColumn<String> recurrenceEnd = GeneratedColumn<String>(
    'recurrenceEnd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceIdMeta = const VerificationMeta(
    'recurrenceId',
  );
  @override
  late final GeneratedColumn<String> recurrenceId = GeneratedColumn<String>(
    'recurrenceId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceIntervalMeta =
      const VerificationMeta('recurrenceInterval');
  @override
  late final GeneratedColumn<String> recurrenceInterval =
      GeneratedColumn<String>(
        'recurrenceInterval',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isRecurrenceInstanceMeta =
      const VerificationMeta('isRecurrenceInstance');
  @override
  late final GeneratedColumn<String> isRecurrenceInstance =
      GeneratedColumn<String>(
        'isRecurrenceInstance',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta(
    'recurrenceRule',
  );
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>(
    'recurrenceRule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceWeekdaysMeta =
      const VerificationMeta('recurrenceWeekdays');
  @override
  late final GeneratedColumn<String> recurrenceWeekdays =
      GeneratedColumn<String>(
        'recurrenceWeekdays',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<String> sortOrder = GeneratedColumn<String>(
    'sortOrder',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdsMeta = const VerificationMeta(
    'parentIds',
  );
  @override
  late final GeneratedColumn<String> parentIds = GeneratedColumn<String>(
    'parentIds',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    name,
    value,
    createdAt,
    priority,
    dueDate,
    createTime,
    completedTime,
    tags,
    updateTime,
    completed,
    title,
    description,
    deadlineReminder,
    remindCount,
    remindInterval,
    remindIntervalUnit,
    status,
    parentId,
    recurrenceEnd,
    recurrenceId,
    recurrenceInterval,
    isRecurrenceInstance,
    recurrenceRule,
    recurrenceWeekdays,
    sortOrder,
    parentIds,
    id,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_list';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoListData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('dueDate')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['dueDate']!, _dueDateMeta),
      );
    }
    if (data.containsKey('createTime')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['createTime']!, _createTimeMeta),
      );
    }
    if (data.containsKey('completedTime')) {
      context.handle(
        _completedTimeMeta,
        completedTime.isAcceptableOrUnknown(
          data['completedTime']!,
          _completedTimeMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('updateTime')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['updateTime']!, _updateTimeMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('deadlineReminder')) {
      context.handle(
        _deadlineReminderMeta,
        deadlineReminder.isAcceptableOrUnknown(
          data['deadlineReminder']!,
          _deadlineReminderMeta,
        ),
      );
    }
    if (data.containsKey('remindCount')) {
      context.handle(
        _remindCountMeta,
        remindCount.isAcceptableOrUnknown(
          data['remindCount']!,
          _remindCountMeta,
        ),
      );
    }
    if (data.containsKey('remindInterval')) {
      context.handle(
        _remindIntervalMeta,
        remindInterval.isAcceptableOrUnknown(
          data['remindInterval']!,
          _remindIntervalMeta,
        ),
      );
    }
    if (data.containsKey('remindIntervalUnit')) {
      context.handle(
        _remindIntervalUnitMeta,
        remindIntervalUnit.isAcceptableOrUnknown(
          data['remindIntervalUnit']!,
          _remindIntervalUnitMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('parentId')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parentId']!, _parentIdMeta),
      );
    }
    if (data.containsKey('recurrenceEnd')) {
      context.handle(
        _recurrenceEndMeta,
        recurrenceEnd.isAcceptableOrUnknown(
          data['recurrenceEnd']!,
          _recurrenceEndMeta,
        ),
      );
    }
    if (data.containsKey('recurrenceId')) {
      context.handle(
        _recurrenceIdMeta,
        recurrenceId.isAcceptableOrUnknown(
          data['recurrenceId']!,
          _recurrenceIdMeta,
        ),
      );
    }
    if (data.containsKey('recurrenceInterval')) {
      context.handle(
        _recurrenceIntervalMeta,
        recurrenceInterval.isAcceptableOrUnknown(
          data['recurrenceInterval']!,
          _recurrenceIntervalMeta,
        ),
      );
    }
    if (data.containsKey('isRecurrenceInstance')) {
      context.handle(
        _isRecurrenceInstanceMeta,
        isRecurrenceInstance.isAcceptableOrUnknown(
          data['isRecurrenceInstance']!,
          _isRecurrenceInstanceMeta,
        ),
      );
    }
    if (data.containsKey('recurrenceRule')) {
      context.handle(
        _recurrenceRuleMeta,
        recurrenceRule.isAcceptableOrUnknown(
          data['recurrenceRule']!,
          _recurrenceRuleMeta,
        ),
      );
    }
    if (data.containsKey('recurrenceWeekdays')) {
      context.handle(
        _recurrenceWeekdaysMeta,
        recurrenceWeekdays.isAcceptableOrUnknown(
          data['recurrenceWeekdays']!,
          _recurrenceWeekdaysMeta,
        ),
      );
    }
    if (data.containsKey('sortOrder')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sortOrder']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('parentIds')) {
      context.handle(
        _parentIdsMeta,
        parentIds.isAcceptableOrUnknown(data['parentIds']!, _parentIdsMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  TodoListData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoListData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dueDate'],
      ),
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}createTime'],
      ),
      completedTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completedTime'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updateTime'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      deadlineReminder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deadlineReminder'],
      ),
      remindCount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remindCount'],
      ),
      remindInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remindInterval'],
      ),
      remindIntervalUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remindIntervalUnit'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parentId'],
      ),
      recurrenceEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrenceEnd'],
      ),
      recurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrenceId'],
      ),
      recurrenceInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrenceInterval'],
      ),
      isRecurrenceInstance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isRecurrenceInstance'],
      ),
      recurrenceRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrenceRule'],
      ),
      recurrenceWeekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrenceWeekdays'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sortOrder'],
      ),
      parentIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parentIds'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
    );
  }

  @override
  $TodoListTable createAlias(String alias) {
    return $TodoListTable(attachedDatabase, alias);
  }
}

class TodoListData extends DataClass implements Insertable<TodoListData> {
  /// 业务主键（UUID）
  final String key;
  final String? name;
  final String? value;
  final String? createdAt;
  final String? priority;
  final String? dueDate;
  final String? createTime;
  final String? completedTime;

  /// 标签 JSON 数组（todo_tags.key 列表）
  final String? tags;
  final String? updateTime;

  /// 是否完成：'1'/'0'
  final String? completed;
  final String? title;
  final String? description;

  /// 截止提醒配置
  final String? deadlineReminder;
  final String? remindCount;
  final String? remindInterval;
  final String? remindIntervalUnit;
  final String? status;

  /// 父任务 key（父子任务）
  final String? parentId;
  final String? recurrenceEnd;
  final String? recurrenceId;
  final String? recurrenceInterval;
  final String? isRecurrenceInstance;
  final String? recurrenceRule;
  final String? recurrenceWeekdays;
  final String? sortOrder;
  final String? parentIds;

  /// 旧层遗留的可空整型列（桌面库存在，样例全为 NULL）
  final int? id;
  const TodoListData({
    required this.key,
    this.name,
    this.value,
    this.createdAt,
    this.priority,
    this.dueDate,
    this.createTime,
    this.completedTime,
    this.tags,
    this.updateTime,
    this.completed,
    this.title,
    this.description,
    this.deadlineReminder,
    this.remindCount,
    this.remindInterval,
    this.remindIntervalUnit,
    this.status,
    this.parentId,
    this.recurrenceEnd,
    this.recurrenceId,
    this.recurrenceInterval,
    this.isRecurrenceInstance,
    this.recurrenceRule,
    this.recurrenceWeekdays,
    this.sortOrder,
    this.parentIds,
    this.id,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<String>(priority);
    }
    if (!nullToAbsent || dueDate != null) {
      map['dueDate'] = Variable<String>(dueDate);
    }
    if (!nullToAbsent || createTime != null) {
      map['createTime'] = Variable<String>(createTime);
    }
    if (!nullToAbsent || completedTime != null) {
      map['completedTime'] = Variable<String>(completedTime);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || updateTime != null) {
      map['updateTime'] = Variable<String>(updateTime);
    }
    if (!nullToAbsent || completed != null) {
      map['completed'] = Variable<String>(completed);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || deadlineReminder != null) {
      map['deadlineReminder'] = Variable<String>(deadlineReminder);
    }
    if (!nullToAbsent || remindCount != null) {
      map['remindCount'] = Variable<String>(remindCount);
    }
    if (!nullToAbsent || remindInterval != null) {
      map['remindInterval'] = Variable<String>(remindInterval);
    }
    if (!nullToAbsent || remindIntervalUnit != null) {
      map['remindIntervalUnit'] = Variable<String>(remindIntervalUnit);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || parentId != null) {
      map['parentId'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || recurrenceEnd != null) {
      map['recurrenceEnd'] = Variable<String>(recurrenceEnd);
    }
    if (!nullToAbsent || recurrenceId != null) {
      map['recurrenceId'] = Variable<String>(recurrenceId);
    }
    if (!nullToAbsent || recurrenceInterval != null) {
      map['recurrenceInterval'] = Variable<String>(recurrenceInterval);
    }
    if (!nullToAbsent || isRecurrenceInstance != null) {
      map['isRecurrenceInstance'] = Variable<String>(isRecurrenceInstance);
    }
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrenceRule'] = Variable<String>(recurrenceRule);
    }
    if (!nullToAbsent || recurrenceWeekdays != null) {
      map['recurrenceWeekdays'] = Variable<String>(recurrenceWeekdays);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sortOrder'] = Variable<String>(sortOrder);
    }
    if (!nullToAbsent || parentIds != null) {
      map['parentIds'] = Variable<String>(parentIds);
    }
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    return map;
  }

  TodoListCompanion toCompanion(bool nullToAbsent) {
    return TodoListCompanion(
      key: Value(key),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      priority: priority == null && nullToAbsent
          ? const Value.absent()
          : Value(priority),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
      completedTime: completedTime == null && nullToAbsent
          ? const Value.absent()
          : Value(completedTime),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      updateTime: updateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(updateTime),
      completed: completed == null && nullToAbsent
          ? const Value.absent()
          : Value(completed),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      deadlineReminder: deadlineReminder == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineReminder),
      remindCount: remindCount == null && nullToAbsent
          ? const Value.absent()
          : Value(remindCount),
      remindInterval: remindInterval == null && nullToAbsent
          ? const Value.absent()
          : Value(remindInterval),
      remindIntervalUnit: remindIntervalUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(remindIntervalUnit),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      recurrenceEnd: recurrenceEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceEnd),
      recurrenceId: recurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceId),
      recurrenceInterval: recurrenceInterval == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceInterval),
      isRecurrenceInstance: isRecurrenceInstance == null && nullToAbsent
          ? const Value.absent()
          : Value(isRecurrenceInstance),
      recurrenceRule: recurrenceRule == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRule),
      recurrenceWeekdays: recurrenceWeekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceWeekdays),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      parentIds: parentIds == null && nullToAbsent
          ? const Value.absent()
          : Value(parentIds),
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
    );
  }

  factory TodoListData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoListData(
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      priority: serializer.fromJson<String?>(json['priority']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
      createTime: serializer.fromJson<String?>(json['createTime']),
      completedTime: serializer.fromJson<String?>(json['completedTime']),
      tags: serializer.fromJson<String?>(json['tags']),
      updateTime: serializer.fromJson<String?>(json['updateTime']),
      completed: serializer.fromJson<String?>(json['completed']),
      title: serializer.fromJson<String?>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      deadlineReminder: serializer.fromJson<String?>(json['deadlineReminder']),
      remindCount: serializer.fromJson<String?>(json['remindCount']),
      remindInterval: serializer.fromJson<String?>(json['remindInterval']),
      remindIntervalUnit: serializer.fromJson<String?>(
        json['remindIntervalUnit'],
      ),
      status: serializer.fromJson<String?>(json['status']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      recurrenceEnd: serializer.fromJson<String?>(json['recurrenceEnd']),
      recurrenceId: serializer.fromJson<String?>(json['recurrenceId']),
      recurrenceInterval: serializer.fromJson<String?>(
        json['recurrenceInterval'],
      ),
      isRecurrenceInstance: serializer.fromJson<String?>(
        json['isRecurrenceInstance'],
      ),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
      recurrenceWeekdays: serializer.fromJson<String?>(
        json['recurrenceWeekdays'],
      ),
      sortOrder: serializer.fromJson<String?>(json['sortOrder']),
      parentIds: serializer.fromJson<String?>(json['parentIds']),
      id: serializer.fromJson<int?>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'priority': serializer.toJson<String?>(priority),
      'dueDate': serializer.toJson<String?>(dueDate),
      'createTime': serializer.toJson<String?>(createTime),
      'completedTime': serializer.toJson<String?>(completedTime),
      'tags': serializer.toJson<String?>(tags),
      'updateTime': serializer.toJson<String?>(updateTime),
      'completed': serializer.toJson<String?>(completed),
      'title': serializer.toJson<String?>(title),
      'description': serializer.toJson<String?>(description),
      'deadlineReminder': serializer.toJson<String?>(deadlineReminder),
      'remindCount': serializer.toJson<String?>(remindCount),
      'remindInterval': serializer.toJson<String?>(remindInterval),
      'remindIntervalUnit': serializer.toJson<String?>(remindIntervalUnit),
      'status': serializer.toJson<String?>(status),
      'parentId': serializer.toJson<String?>(parentId),
      'recurrenceEnd': serializer.toJson<String?>(recurrenceEnd),
      'recurrenceId': serializer.toJson<String?>(recurrenceId),
      'recurrenceInterval': serializer.toJson<String?>(recurrenceInterval),
      'isRecurrenceInstance': serializer.toJson<String?>(isRecurrenceInstance),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
      'recurrenceWeekdays': serializer.toJson<String?>(recurrenceWeekdays),
      'sortOrder': serializer.toJson<String?>(sortOrder),
      'parentIds': serializer.toJson<String?>(parentIds),
      'id': serializer.toJson<int?>(id),
    };
  }

  TodoListData copyWith({
    String? key,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> priority = const Value.absent(),
    Value<String?> dueDate = const Value.absent(),
    Value<String?> createTime = const Value.absent(),
    Value<String?> completedTime = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> updateTime = const Value.absent(),
    Value<String?> completed = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> deadlineReminder = const Value.absent(),
    Value<String?> remindCount = const Value.absent(),
    Value<String?> remindInterval = const Value.absent(),
    Value<String?> remindIntervalUnit = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    Value<String?> recurrenceEnd = const Value.absent(),
    Value<String?> recurrenceId = const Value.absent(),
    Value<String?> recurrenceInterval = const Value.absent(),
    Value<String?> isRecurrenceInstance = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<String?> recurrenceWeekdays = const Value.absent(),
    Value<String?> sortOrder = const Value.absent(),
    Value<String?> parentIds = const Value.absent(),
    Value<int?> id = const Value.absent(),
  }) => TodoListData(
    key: key ?? this.key,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    priority: priority.present ? priority.value : this.priority,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    createTime: createTime.present ? createTime.value : this.createTime,
    completedTime: completedTime.present
        ? completedTime.value
        : this.completedTime,
    tags: tags.present ? tags.value : this.tags,
    updateTime: updateTime.present ? updateTime.value : this.updateTime,
    completed: completed.present ? completed.value : this.completed,
    title: title.present ? title.value : this.title,
    description: description.present ? description.value : this.description,
    deadlineReminder: deadlineReminder.present
        ? deadlineReminder.value
        : this.deadlineReminder,
    remindCount: remindCount.present ? remindCount.value : this.remindCount,
    remindInterval: remindInterval.present
        ? remindInterval.value
        : this.remindInterval,
    remindIntervalUnit: remindIntervalUnit.present
        ? remindIntervalUnit.value
        : this.remindIntervalUnit,
    status: status.present ? status.value : this.status,
    parentId: parentId.present ? parentId.value : this.parentId,
    recurrenceEnd: recurrenceEnd.present
        ? recurrenceEnd.value
        : this.recurrenceEnd,
    recurrenceId: recurrenceId.present ? recurrenceId.value : this.recurrenceId,
    recurrenceInterval: recurrenceInterval.present
        ? recurrenceInterval.value
        : this.recurrenceInterval,
    isRecurrenceInstance: isRecurrenceInstance.present
        ? isRecurrenceInstance.value
        : this.isRecurrenceInstance,
    recurrenceRule: recurrenceRule.present
        ? recurrenceRule.value
        : this.recurrenceRule,
    recurrenceWeekdays: recurrenceWeekdays.present
        ? recurrenceWeekdays.value
        : this.recurrenceWeekdays,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    parentIds: parentIds.present ? parentIds.value : this.parentIds,
    id: id.present ? id.value : this.id,
  );
  TodoListData copyWithCompanion(TodoListCompanion data) {
    return TodoListData(
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
      completedTime: data.completedTime.present
          ? data.completedTime.value
          : this.completedTime,
      tags: data.tags.present ? data.tags.value : this.tags,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
      completed: data.completed.present ? data.completed.value : this.completed,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      deadlineReminder: data.deadlineReminder.present
          ? data.deadlineReminder.value
          : this.deadlineReminder,
      remindCount: data.remindCount.present
          ? data.remindCount.value
          : this.remindCount,
      remindInterval: data.remindInterval.present
          ? data.remindInterval.value
          : this.remindInterval,
      remindIntervalUnit: data.remindIntervalUnit.present
          ? data.remindIntervalUnit.value
          : this.remindIntervalUnit,
      status: data.status.present ? data.status.value : this.status,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      recurrenceEnd: data.recurrenceEnd.present
          ? data.recurrenceEnd.value
          : this.recurrenceEnd,
      recurrenceId: data.recurrenceId.present
          ? data.recurrenceId.value
          : this.recurrenceId,
      recurrenceInterval: data.recurrenceInterval.present
          ? data.recurrenceInterval.value
          : this.recurrenceInterval,
      isRecurrenceInstance: data.isRecurrenceInstance.present
          ? data.isRecurrenceInstance.value
          : this.isRecurrenceInstance,
      recurrenceRule: data.recurrenceRule.present
          ? data.recurrenceRule.value
          : this.recurrenceRule,
      recurrenceWeekdays: data.recurrenceWeekdays.present
          ? data.recurrenceWeekdays.value
          : this.recurrenceWeekdays,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      parentIds: data.parentIds.present ? data.parentIds.value : this.parentIds,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoListData(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('createTime: $createTime, ')
          ..write('completedTime: $completedTime, ')
          ..write('tags: $tags, ')
          ..write('updateTime: $updateTime, ')
          ..write('completed: $completed, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('deadlineReminder: $deadlineReminder, ')
          ..write('remindCount: $remindCount, ')
          ..write('remindInterval: $remindInterval, ')
          ..write('remindIntervalUnit: $remindIntervalUnit, ')
          ..write('status: $status, ')
          ..write('parentId: $parentId, ')
          ..write('recurrenceEnd: $recurrenceEnd, ')
          ..write('recurrenceId: $recurrenceId, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('isRecurrenceInstance: $isRecurrenceInstance, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceWeekdays: $recurrenceWeekdays, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentIds: $parentIds, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    key,
    name,
    value,
    createdAt,
    priority,
    dueDate,
    createTime,
    completedTime,
    tags,
    updateTime,
    completed,
    title,
    description,
    deadlineReminder,
    remindCount,
    remindInterval,
    remindIntervalUnit,
    status,
    parentId,
    recurrenceEnd,
    recurrenceId,
    recurrenceInterval,
    isRecurrenceInstance,
    recurrenceRule,
    recurrenceWeekdays,
    sortOrder,
    parentIds,
    id,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoListData &&
          other.key == this.key &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.priority == this.priority &&
          other.dueDate == this.dueDate &&
          other.createTime == this.createTime &&
          other.completedTime == this.completedTime &&
          other.tags == this.tags &&
          other.updateTime == this.updateTime &&
          other.completed == this.completed &&
          other.title == this.title &&
          other.description == this.description &&
          other.deadlineReminder == this.deadlineReminder &&
          other.remindCount == this.remindCount &&
          other.remindInterval == this.remindInterval &&
          other.remindIntervalUnit == this.remindIntervalUnit &&
          other.status == this.status &&
          other.parentId == this.parentId &&
          other.recurrenceEnd == this.recurrenceEnd &&
          other.recurrenceId == this.recurrenceId &&
          other.recurrenceInterval == this.recurrenceInterval &&
          other.isRecurrenceInstance == this.isRecurrenceInstance &&
          other.recurrenceRule == this.recurrenceRule &&
          other.recurrenceWeekdays == this.recurrenceWeekdays &&
          other.sortOrder == this.sortOrder &&
          other.parentIds == this.parentIds &&
          other.id == this.id);
}

class TodoListCompanion extends UpdateCompanion<TodoListData> {
  final Value<String> key;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> priority;
  final Value<String?> dueDate;
  final Value<String?> createTime;
  final Value<String?> completedTime;
  final Value<String?> tags;
  final Value<String?> updateTime;
  final Value<String?> completed;
  final Value<String?> title;
  final Value<String?> description;
  final Value<String?> deadlineReminder;
  final Value<String?> remindCount;
  final Value<String?> remindInterval;
  final Value<String?> remindIntervalUnit;
  final Value<String?> status;
  final Value<String?> parentId;
  final Value<String?> recurrenceEnd;
  final Value<String?> recurrenceId;
  final Value<String?> recurrenceInterval;
  final Value<String?> isRecurrenceInstance;
  final Value<String?> recurrenceRule;
  final Value<String?> recurrenceWeekdays;
  final Value<String?> sortOrder;
  final Value<String?> parentIds;
  final Value<int?> id;
  final Value<int> rowid;
  const TodoListCompanion({
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createTime = const Value.absent(),
    this.completedTime = const Value.absent(),
    this.tags = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.completed = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.deadlineReminder = const Value.absent(),
    this.remindCount = const Value.absent(),
    this.remindInterval = const Value.absent(),
    this.remindIntervalUnit = const Value.absent(),
    this.status = const Value.absent(),
    this.parentId = const Value.absent(),
    this.recurrenceEnd = const Value.absent(),
    this.recurrenceId = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.isRecurrenceInstance = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceWeekdays = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentIds = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoListCompanion.insert({
    required String key,
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createTime = const Value.absent(),
    this.completedTime = const Value.absent(),
    this.tags = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.completed = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.deadlineReminder = const Value.absent(),
    this.remindCount = const Value.absent(),
    this.remindInterval = const Value.absent(),
    this.remindIntervalUnit = const Value.absent(),
    this.status = const Value.absent(),
    this.parentId = const Value.absent(),
    this.recurrenceEnd = const Value.absent(),
    this.recurrenceId = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.isRecurrenceInstance = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceWeekdays = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentIds = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<TodoListData> custom({
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? priority,
    Expression<String>? dueDate,
    Expression<String>? createTime,
    Expression<String>? completedTime,
    Expression<String>? tags,
    Expression<String>? updateTime,
    Expression<String>? completed,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? deadlineReminder,
    Expression<String>? remindCount,
    Expression<String>? remindInterval,
    Expression<String>? remindIntervalUnit,
    Expression<String>? status,
    Expression<String>? parentId,
    Expression<String>? recurrenceEnd,
    Expression<String>? recurrenceId,
    Expression<String>? recurrenceInterval,
    Expression<String>? isRecurrenceInstance,
    Expression<String>? recurrenceRule,
    Expression<String>? recurrenceWeekdays,
    Expression<String>? sortOrder,
    Expression<String>? parentIds,
    Expression<int>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (priority != null) 'priority': priority,
      if (dueDate != null) 'dueDate': dueDate,
      if (createTime != null) 'createTime': createTime,
      if (completedTime != null) 'completedTime': completedTime,
      if (tags != null) 'tags': tags,
      if (updateTime != null) 'updateTime': updateTime,
      if (completed != null) 'completed': completed,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (deadlineReminder != null) 'deadlineReminder': deadlineReminder,
      if (remindCount != null) 'remindCount': remindCount,
      if (remindInterval != null) 'remindInterval': remindInterval,
      if (remindIntervalUnit != null) 'remindIntervalUnit': remindIntervalUnit,
      if (status != null) 'status': status,
      if (parentId != null) 'parentId': parentId,
      if (recurrenceEnd != null) 'recurrenceEnd': recurrenceEnd,
      if (recurrenceId != null) 'recurrenceId': recurrenceId,
      if (recurrenceInterval != null) 'recurrenceInterval': recurrenceInterval,
      if (isRecurrenceInstance != null)
        'isRecurrenceInstance': isRecurrenceInstance,
      if (recurrenceRule != null) 'recurrenceRule': recurrenceRule,
      if (recurrenceWeekdays != null) 'recurrenceWeekdays': recurrenceWeekdays,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (parentIds != null) 'parentIds': parentIds,
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoListCompanion copyWith({
    Value<String>? key,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? priority,
    Value<String?>? dueDate,
    Value<String?>? createTime,
    Value<String?>? completedTime,
    Value<String?>? tags,
    Value<String?>? updateTime,
    Value<String?>? completed,
    Value<String?>? title,
    Value<String?>? description,
    Value<String?>? deadlineReminder,
    Value<String?>? remindCount,
    Value<String?>? remindInterval,
    Value<String?>? remindIntervalUnit,
    Value<String?>? status,
    Value<String?>? parentId,
    Value<String?>? recurrenceEnd,
    Value<String?>? recurrenceId,
    Value<String?>? recurrenceInterval,
    Value<String?>? isRecurrenceInstance,
    Value<String?>? recurrenceRule,
    Value<String?>? recurrenceWeekdays,
    Value<String?>? sortOrder,
    Value<String?>? parentIds,
    Value<int?>? id,
    Value<int>? rowid,
  }) {
    return TodoListCompanion(
      key: key ?? this.key,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createTime: createTime ?? this.createTime,
      completedTime: completedTime ?? this.completedTime,
      tags: tags ?? this.tags,
      updateTime: updateTime ?? this.updateTime,
      completed: completed ?? this.completed,
      title: title ?? this.title,
      description: description ?? this.description,
      deadlineReminder: deadlineReminder ?? this.deadlineReminder,
      remindCount: remindCount ?? this.remindCount,
      remindInterval: remindInterval ?? this.remindInterval,
      remindIntervalUnit: remindIntervalUnit ?? this.remindIntervalUnit,
      status: status ?? this.status,
      parentId: parentId ?? this.parentId,
      recurrenceEnd: recurrenceEnd ?? this.recurrenceEnd,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      isRecurrenceInstance: isRecurrenceInstance ?? this.isRecurrenceInstance,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceWeekdays: recurrenceWeekdays ?? this.recurrenceWeekdays,
      sortOrder: sortOrder ?? this.sortOrder,
      parentIds: parentIds ?? this.parentIds,
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (dueDate.present) {
      map['dueDate'] = Variable<String>(dueDate.value);
    }
    if (createTime.present) {
      map['createTime'] = Variable<String>(createTime.value);
    }
    if (completedTime.present) {
      map['completedTime'] = Variable<String>(completedTime.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (updateTime.present) {
      map['updateTime'] = Variable<String>(updateTime.value);
    }
    if (completed.present) {
      map['completed'] = Variable<String>(completed.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (deadlineReminder.present) {
      map['deadlineReminder'] = Variable<String>(deadlineReminder.value);
    }
    if (remindCount.present) {
      map['remindCount'] = Variable<String>(remindCount.value);
    }
    if (remindInterval.present) {
      map['remindInterval'] = Variable<String>(remindInterval.value);
    }
    if (remindIntervalUnit.present) {
      map['remindIntervalUnit'] = Variable<String>(remindIntervalUnit.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (parentId.present) {
      map['parentId'] = Variable<String>(parentId.value);
    }
    if (recurrenceEnd.present) {
      map['recurrenceEnd'] = Variable<String>(recurrenceEnd.value);
    }
    if (recurrenceId.present) {
      map['recurrenceId'] = Variable<String>(recurrenceId.value);
    }
    if (recurrenceInterval.present) {
      map['recurrenceInterval'] = Variable<String>(recurrenceInterval.value);
    }
    if (isRecurrenceInstance.present) {
      map['isRecurrenceInstance'] = Variable<String>(
        isRecurrenceInstance.value,
      );
    }
    if (recurrenceRule.present) {
      map['recurrenceRule'] = Variable<String>(recurrenceRule.value);
    }
    if (recurrenceWeekdays.present) {
      map['recurrenceWeekdays'] = Variable<String>(recurrenceWeekdays.value);
    }
    if (sortOrder.present) {
      map['sortOrder'] = Variable<String>(sortOrder.value);
    }
    if (parentIds.present) {
      map['parentIds'] = Variable<String>(parentIds.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListCompanion(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('createTime: $createTime, ')
          ..write('completedTime: $completedTime, ')
          ..write('tags: $tags, ')
          ..write('updateTime: $updateTime, ')
          ..write('completed: $completed, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('deadlineReminder: $deadlineReminder, ')
          ..write('remindCount: $remindCount, ')
          ..write('remindInterval: $remindInterval, ')
          ..write('remindIntervalUnit: $remindIntervalUnit, ')
          ..write('status: $status, ')
          ..write('parentId: $parentId, ')
          ..write('recurrenceEnd: $recurrenceEnd, ')
          ..write('recurrenceId: $recurrenceId, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('isRecurrenceInstance: $isRecurrenceInstance, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceWeekdays: $recurrenceWeekdays, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentIds: $parentIds, ')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoTagsTable extends TodoTags with TableInfo<$TodoTagsTable, TodoTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    key,
    color,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
    );
  }

  @override
  $TodoTagsTable createAlias(String alias) {
    return $TodoTagsTable(attachedDatabase, alias);
  }
}

class TodoTag extends DataClass implements Insertable<TodoTag> {
  /// 旧层自增主键
  final int id;
  final String? name;
  final String? value;
  final String? createdAt;

  /// 标签业务主键（UUID）
  final String? key;
  final String? color;
  const TodoTag({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.key,
    this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    return map;
  }

  TodoTagsCompanion toCompanion(bool nullToAbsent) {
    return TodoTagsCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
    );
  }

  factory TodoTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoTag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      key: serializer.fromJson<String?>(json['key']),
      color: serializer.fromJson<String?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'key': serializer.toJson<String?>(key),
      'color': serializer.toJson<String?>(color),
    };
  }

  TodoTag copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> key = const Value.absent(),
    Value<String?> color = const Value.absent(),
  }) => TodoTag(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    key: key.present ? key.value : this.key,
    color: color.present ? color.value : this.color,
  );
  TodoTag copyWithCompanion(TodoTagsCompanion data) {
    return TodoTag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      key: data.key.present ? data.key.value : this.key,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoTag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('key: $key, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, value, createdAt, key, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTag &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.key == this.key &&
          other.color == this.color);
}

class TodoTagsCompanion extends UpdateCompanion<TodoTag> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> key;
  final Value<String?> color;
  const TodoTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.key = const Value.absent(),
    this.color = const Value.absent(),
  });
  TodoTagsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.key = const Value.absent(),
    this.color = const Value.absent(),
  });
  static Insertable<TodoTag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? key,
    Expression<String>? color,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (key != null) 'key': key,
      if (color != null) 'color': color,
    });
  }

  TodoTagsCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? key,
    Value<String?>? color,
  }) {
    return TodoTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      key: key ?? this.key,
      color: color ?? this.color,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('key: $key, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'startTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statesMeta = const VerificationMeta('states');
  @override
  late final GeneratedColumn<String> states = GeneratedColumn<String>(
    'states',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekDaysMeta = const VerificationMeta(
    'weekDays',
  );
  @override
  late final GeneratedColumn<String> weekDays = GeneratedColumn<String>(
    'weekDays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loopMeta = const VerificationMeta('loop');
  @override
  late final GeneratedColumn<String> loop = GeneratedColumn<String>(
    'loop',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordAfterMeta = const VerificationMeta(
    'recordAfter',
  );
  @override
  late final GeneratedColumn<String> recordAfter = GeneratedColumn<String>(
    'recordAfter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<String> interval = GeneratedColumn<String>(
    'interval',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<String> minute = GeneratedColumn<String>(
    'minute',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<String> dayOfMonth = GeneratedColumn<String>(
    'dayOfMonth',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<String> enabled = GeneratedColumn<String>(
    'enabled',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idleTimeMeta = const VerificationMeta(
    'idleTime',
  );
  @override
  late final GeneratedColumn<String> idleTime = GeneratedColumn<String>(
    'idleTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<String> repeat = GeneratedColumn<String>(
    'repeat',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    mode,
    startTime,
    states,
    weekDays,
    loop,
    recordAfter,
    interval,
    month,
    minute,
    dayOfMonth,
    unit,
    title,
    content,
    enabled,
    idleTime,
    time,
    repeat,
    date,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('startTime')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['startTime']!, _startTimeMeta),
      );
    }
    if (data.containsKey('states')) {
      context.handle(
        _statesMeta,
        states.isAcceptableOrUnknown(data['states']!, _statesMeta),
      );
    }
    if (data.containsKey('weekDays')) {
      context.handle(
        _weekDaysMeta,
        weekDays.isAcceptableOrUnknown(data['weekDays']!, _weekDaysMeta),
      );
    }
    if (data.containsKey('loop')) {
      context.handle(
        _loopMeta,
        loop.isAcceptableOrUnknown(data['loop']!, _loopMeta),
      );
    }
    if (data.containsKey('recordAfter')) {
      context.handle(
        _recordAfterMeta,
        recordAfter.isAcceptableOrUnknown(
          data['recordAfter']!,
          _recordAfterMeta,
        ),
      );
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    }
    if (data.containsKey('dayOfMonth')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(data['dayOfMonth']!, _dayOfMonthMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('idleTime')) {
      context.handle(
        _idleTimeMeta,
        idleTime.isAcceptableOrUnknown(data['idleTime']!, _idleTimeMeta),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}startTime'],
      ),
      states: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}states'],
      ),
      weekDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekDays'],
      ),
      loop: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loop'],
      ),
      recordAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recordAfter'],
      ),
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interval'],
      ),
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      ),
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}minute'],
      ),
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dayOfMonth'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled'],
      ),
      idleTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idleTime'],
      ),
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      ),
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  /// 业务主键（如 pomodoro / habit:xxx / todo:xxx）
  final String id;
  final String? name;
  final String? value;
  final String? createdAt;

  /// 提醒模式，如 stateful（状态机型）/ 定时型
  final String? mode;

  /// 状态机起始时间戳（ms）
  final String? startTime;

  /// 状态机定义 JSON，如 [{"key":"work","label":"工作","duration":23,...}]
  final String? states;

  /// 生效星期 JSON
  final String? weekDays;

  /// 是否循环：'1'/'0'
  final String? loop;
  final String? recordAfter;
  final String? interval;
  final String? month;
  final String? minute;
  final String? dayOfMonth;
  final String? unit;
  final String? title;
  final String? content;

  /// 是否启用：'1'/'0'
  final String? enabled;

  /// 免打扰时段 JSON，如 [{"start":"10:15","end":"10:57"}]
  final String? idleTime;
  final String? time;
  final String? repeat;
  final String? date;

  /// 提醒来源（桌面端待办截止提醒引擎写入 'todo'；用户手建为空）
  final String? source;
  const Reminder({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.mode,
    this.startTime,
    this.states,
    this.weekDays,
    this.loop,
    this.recordAfter,
    this.interval,
    this.month,
    this.minute,
    this.dayOfMonth,
    this.unit,
    this.title,
    this.content,
    this.enabled,
    this.idleTime,
    this.time,
    this.repeat,
    this.date,
    this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || startTime != null) {
      map['startTime'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || states != null) {
      map['states'] = Variable<String>(states);
    }
    if (!nullToAbsent || weekDays != null) {
      map['weekDays'] = Variable<String>(weekDays);
    }
    if (!nullToAbsent || loop != null) {
      map['loop'] = Variable<String>(loop);
    }
    if (!nullToAbsent || recordAfter != null) {
      map['recordAfter'] = Variable<String>(recordAfter);
    }
    if (!nullToAbsent || interval != null) {
      map['interval'] = Variable<String>(interval);
    }
    if (!nullToAbsent || month != null) {
      map['month'] = Variable<String>(month);
    }
    if (!nullToAbsent || minute != null) {
      map['minute'] = Variable<String>(minute);
    }
    if (!nullToAbsent || dayOfMonth != null) {
      map['dayOfMonth'] = Variable<String>(dayOfMonth);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || enabled != null) {
      map['enabled'] = Variable<String>(enabled);
    }
    if (!nullToAbsent || idleTime != null) {
      map['idleTime'] = Variable<String>(idleTime);
    }
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<String>(time);
    }
    if (!nullToAbsent || repeat != null) {
      map['repeat'] = Variable<String>(repeat);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      states: states == null && nullToAbsent
          ? const Value.absent()
          : Value(states),
      weekDays: weekDays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekDays),
      loop: loop == null && nullToAbsent ? const Value.absent() : Value(loop),
      recordAfter: recordAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(recordAfter),
      interval: interval == null && nullToAbsent
          ? const Value.absent()
          : Value(interval),
      month: month == null && nullToAbsent
          ? const Value.absent()
          : Value(month),
      minute: minute == null && nullToAbsent
          ? const Value.absent()
          : Value(minute),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      enabled: enabled == null && nullToAbsent
          ? const Value.absent()
          : Value(enabled),
      idleTime: idleTime == null && nullToAbsent
          ? const Value.absent()
          : Value(idleTime),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
      repeat: repeat == null && nullToAbsent
          ? const Value.absent()
          : Value(repeat),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      mode: serializer.fromJson<String?>(json['mode']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      states: serializer.fromJson<String?>(json['states']),
      weekDays: serializer.fromJson<String?>(json['weekDays']),
      loop: serializer.fromJson<String?>(json['loop']),
      recordAfter: serializer.fromJson<String?>(json['recordAfter']),
      interval: serializer.fromJson<String?>(json['interval']),
      month: serializer.fromJson<String?>(json['month']),
      minute: serializer.fromJson<String?>(json['minute']),
      dayOfMonth: serializer.fromJson<String?>(json['dayOfMonth']),
      unit: serializer.fromJson<String?>(json['unit']),
      title: serializer.fromJson<String?>(json['title']),
      content: serializer.fromJson<String?>(json['content']),
      enabled: serializer.fromJson<String?>(json['enabled']),
      idleTime: serializer.fromJson<String?>(json['idleTime']),
      time: serializer.fromJson<String?>(json['time']),
      repeat: serializer.fromJson<String?>(json['repeat']),
      date: serializer.fromJson<String?>(json['date']),
      source: serializer.fromJson<String?>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'mode': serializer.toJson<String?>(mode),
      'startTime': serializer.toJson<String?>(startTime),
      'states': serializer.toJson<String?>(states),
      'weekDays': serializer.toJson<String?>(weekDays),
      'loop': serializer.toJson<String?>(loop),
      'recordAfter': serializer.toJson<String?>(recordAfter),
      'interval': serializer.toJson<String?>(interval),
      'month': serializer.toJson<String?>(month),
      'minute': serializer.toJson<String?>(minute),
      'dayOfMonth': serializer.toJson<String?>(dayOfMonth),
      'unit': serializer.toJson<String?>(unit),
      'title': serializer.toJson<String?>(title),
      'content': serializer.toJson<String?>(content),
      'enabled': serializer.toJson<String?>(enabled),
      'idleTime': serializer.toJson<String?>(idleTime),
      'time': serializer.toJson<String?>(time),
      'repeat': serializer.toJson<String?>(repeat),
      'date': serializer.toJson<String?>(date),
      'source': serializer.toJson<String?>(source),
    };
  }

  Reminder copyWith({
    String? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> mode = const Value.absent(),
    Value<String?> startTime = const Value.absent(),
    Value<String?> states = const Value.absent(),
    Value<String?> weekDays = const Value.absent(),
    Value<String?> loop = const Value.absent(),
    Value<String?> recordAfter = const Value.absent(),
    Value<String?> interval = const Value.absent(),
    Value<String?> month = const Value.absent(),
    Value<String?> minute = const Value.absent(),
    Value<String?> dayOfMonth = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> enabled = const Value.absent(),
    Value<String?> idleTime = const Value.absent(),
    Value<String?> time = const Value.absent(),
    Value<String?> repeat = const Value.absent(),
    Value<String?> date = const Value.absent(),
    Value<String?> source = const Value.absent(),
  }) => Reminder(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    mode: mode.present ? mode.value : this.mode,
    startTime: startTime.present ? startTime.value : this.startTime,
    states: states.present ? states.value : this.states,
    weekDays: weekDays.present ? weekDays.value : this.weekDays,
    loop: loop.present ? loop.value : this.loop,
    recordAfter: recordAfter.present ? recordAfter.value : this.recordAfter,
    interval: interval.present ? interval.value : this.interval,
    month: month.present ? month.value : this.month,
    minute: minute.present ? minute.value : this.minute,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    unit: unit.present ? unit.value : this.unit,
    title: title.present ? title.value : this.title,
    content: content.present ? content.value : this.content,
    enabled: enabled.present ? enabled.value : this.enabled,
    idleTime: idleTime.present ? idleTime.value : this.idleTime,
    time: time.present ? time.value : this.time,
    repeat: repeat.present ? repeat.value : this.repeat,
    date: date.present ? date.value : this.date,
    source: source.present ? source.value : this.source,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      mode: data.mode.present ? data.mode.value : this.mode,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      states: data.states.present ? data.states.value : this.states,
      weekDays: data.weekDays.present ? data.weekDays.value : this.weekDays,
      loop: data.loop.present ? data.loop.value : this.loop,
      recordAfter: data.recordAfter.present
          ? data.recordAfter.value
          : this.recordAfter,
      interval: data.interval.present ? data.interval.value : this.interval,
      month: data.month.present ? data.month.value : this.month,
      minute: data.minute.present ? data.minute.value : this.minute,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      unit: data.unit.present ? data.unit.value : this.unit,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      idleTime: data.idleTime.present ? data.idleTime.value : this.idleTime,
      time: data.time.present ? data.time.value : this.time,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      date: data.date.present ? data.date.value : this.date,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('mode: $mode, ')
          ..write('startTime: $startTime, ')
          ..write('states: $states, ')
          ..write('weekDays: $weekDays, ')
          ..write('loop: $loop, ')
          ..write('recordAfter: $recordAfter, ')
          ..write('interval: $interval, ')
          ..write('month: $month, ')
          ..write('minute: $minute, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('unit: $unit, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('enabled: $enabled, ')
          ..write('idleTime: $idleTime, ')
          ..write('time: $time, ')
          ..write('repeat: $repeat, ')
          ..write('date: $date, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    value,
    createdAt,
    mode,
    startTime,
    states,
    weekDays,
    loop,
    recordAfter,
    interval,
    month,
    minute,
    dayOfMonth,
    unit,
    title,
    content,
    enabled,
    idleTime,
    time,
    repeat,
    date,
    source,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.mode == this.mode &&
          other.startTime == this.startTime &&
          other.states == this.states &&
          other.weekDays == this.weekDays &&
          other.loop == this.loop &&
          other.recordAfter == this.recordAfter &&
          other.interval == this.interval &&
          other.month == this.month &&
          other.minute == this.minute &&
          other.dayOfMonth == this.dayOfMonth &&
          other.unit == this.unit &&
          other.title == this.title &&
          other.content == this.content &&
          other.enabled == this.enabled &&
          other.idleTime == this.idleTime &&
          other.time == this.time &&
          other.repeat == this.repeat &&
          other.date == this.date &&
          other.source == this.source);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<String> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> mode;
  final Value<String?> startTime;
  final Value<String?> states;
  final Value<String?> weekDays;
  final Value<String?> loop;
  final Value<String?> recordAfter;
  final Value<String?> interval;
  final Value<String?> month;
  final Value<String?> minute;
  final Value<String?> dayOfMonth;
  final Value<String?> unit;
  final Value<String?> title;
  final Value<String?> content;
  final Value<String?> enabled;
  final Value<String?> idleTime;
  final Value<String?> time;
  final Value<String?> repeat;
  final Value<String?> date;
  final Value<String?> source;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.mode = const Value.absent(),
    this.startTime = const Value.absent(),
    this.states = const Value.absent(),
    this.weekDays = const Value.absent(),
    this.loop = const Value.absent(),
    this.recordAfter = const Value.absent(),
    this.interval = const Value.absent(),
    this.month = const Value.absent(),
    this.minute = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.unit = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.enabled = const Value.absent(),
    this.idleTime = const Value.absent(),
    this.time = const Value.absent(),
    this.repeat = const Value.absent(),
    this.date = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.mode = const Value.absent(),
    this.startTime = const Value.absent(),
    this.states = const Value.absent(),
    this.weekDays = const Value.absent(),
    this.loop = const Value.absent(),
    this.recordAfter = const Value.absent(),
    this.interval = const Value.absent(),
    this.month = const Value.absent(),
    this.minute = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.unit = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.enabled = const Value.absent(),
    this.idleTime = const Value.absent(),
    this.time = const Value.absent(),
    this.repeat = const Value.absent(),
    this.date = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Reminder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? mode,
    Expression<String>? startTime,
    Expression<String>? states,
    Expression<String>? weekDays,
    Expression<String>? loop,
    Expression<String>? recordAfter,
    Expression<String>? interval,
    Expression<String>? month,
    Expression<String>? minute,
    Expression<String>? dayOfMonth,
    Expression<String>? unit,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? enabled,
    Expression<String>? idleTime,
    Expression<String>? time,
    Expression<String>? repeat,
    Expression<String>? date,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (mode != null) 'mode': mode,
      if (startTime != null) 'startTime': startTime,
      if (states != null) 'states': states,
      if (weekDays != null) 'weekDays': weekDays,
      if (loop != null) 'loop': loop,
      if (recordAfter != null) 'recordAfter': recordAfter,
      if (interval != null) 'interval': interval,
      if (month != null) 'month': month,
      if (minute != null) 'minute': minute,
      if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
      if (unit != null) 'unit': unit,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (enabled != null) 'enabled': enabled,
      if (idleTime != null) 'idleTime': idleTime,
      if (time != null) 'time': time,
      if (repeat != null) 'repeat': repeat,
      if (date != null) 'date': date,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? mode,
    Value<String?>? startTime,
    Value<String?>? states,
    Value<String?>? weekDays,
    Value<String?>? loop,
    Value<String?>? recordAfter,
    Value<String?>? interval,
    Value<String?>? month,
    Value<String?>? minute,
    Value<String?>? dayOfMonth,
    Value<String?>? unit,
    Value<String?>? title,
    Value<String?>? content,
    Value<String?>? enabled,
    Value<String?>? idleTime,
    Value<String?>? time,
    Value<String?>? repeat,
    Value<String?>? date,
    Value<String?>? source,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      states: states ?? this.states,
      weekDays: weekDays ?? this.weekDays,
      loop: loop ?? this.loop,
      recordAfter: recordAfter ?? this.recordAfter,
      interval: interval ?? this.interval,
      month: month ?? this.month,
      minute: minute ?? this.minute,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      unit: unit ?? this.unit,
      title: title ?? this.title,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      idleTime: idleTime ?? this.idleTime,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
      date: date ?? this.date,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (startTime.present) {
      map['startTime'] = Variable<String>(startTime.value);
    }
    if (states.present) {
      map['states'] = Variable<String>(states.value);
    }
    if (weekDays.present) {
      map['weekDays'] = Variable<String>(weekDays.value);
    }
    if (loop.present) {
      map['loop'] = Variable<String>(loop.value);
    }
    if (recordAfter.present) {
      map['recordAfter'] = Variable<String>(recordAfter.value);
    }
    if (interval.present) {
      map['interval'] = Variable<String>(interval.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (minute.present) {
      map['minute'] = Variable<String>(minute.value);
    }
    if (dayOfMonth.present) {
      map['dayOfMonth'] = Variable<String>(dayOfMonth.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<String>(enabled.value);
    }
    if (idleTime.present) {
      map['idleTime'] = Variable<String>(idleTime.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<String>(repeat.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('mode: $mode, ')
          ..write('startTime: $startTime, ')
          ..write('states: $states, ')
          ..write('weekDays: $weekDays, ')
          ..write('loop: $loop, ')
          ..write('recordAfter: $recordAfter, ')
          ..write('interval: $interval, ')
          ..write('month: $month, ')
          ..write('minute: $minute, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('unit: $unit, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('enabled: $enabled, ')
          ..write('idleTime: $idleTime, ')
          ..write('time: $time, ')
          ..write('repeat: $repeat, ')
          ..write('date: $date, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteBookTable extends NoteBook
    with TableInfo<$NoteBookTable, NoteBookData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteBookTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _excerptMeta = const VerificationMeta(
    'excerpt',
  );
  @override
  late final GeneratedColumn<String> excerpt = GeneratedColumn<String>(
    'excerpt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _htmlMeta = const VerificationMeta('html');
  @override
  late final GeneratedColumn<String> html = GeneratedColumn<String>(
    'html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<String> createTime = GeneratedColumn<String>(
    'createTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<String> updateTime = GeneratedColumn<String>(
    'updateTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mdTextMeta = const VerificationMeta('mdText');
  @override
  late final GeneratedColumn<String> mdText = GeneratedColumn<String>(
    'mdText',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whereStrMeta = const VerificationMeta(
    'whereStr',
  );
  @override
  late final GeneratedColumn<String> whereStr = GeneratedColumn<String>(
    'whereStr',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    excerpt,
    html,
    createTime,
    updateTime,
    mdText,
    tags,
    whereStr,
    content,
    category,
    id,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_book';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteBookData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('excerpt')) {
      context.handle(
        _excerptMeta,
        excerpt.isAcceptableOrUnknown(data['excerpt']!, _excerptMeta),
      );
    }
    if (data.containsKey('html')) {
      context.handle(
        _htmlMeta,
        html.isAcceptableOrUnknown(data['html']!, _htmlMeta),
      );
    }
    if (data.containsKey('createTime')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['createTime']!, _createTimeMeta),
      );
    }
    if (data.containsKey('updateTime')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['updateTime']!, _updateTimeMeta),
      );
    }
    if (data.containsKey('mdText')) {
      context.handle(
        _mdTextMeta,
        mdText.isAcceptableOrUnknown(data['mdText']!, _mdTextMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('whereStr')) {
      context.handle(
        _whereStrMeta,
        whereStr.isAcceptableOrUnknown(data['whereStr']!, _whereStrMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  NoteBookData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteBookData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      excerpt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}excerpt'],
      ),
      html: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}html'],
      ),
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}createTime'],
      ),
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updateTime'],
      ),
      mdText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mdText'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      whereStr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}whereStr'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
    );
  }

  @override
  $NoteBookTable createAlias(String alias) {
    return $NoteBookTable(attachedDatabase, alias);
  }
}

class NoteBookData extends DataClass implements Insertable<NoteBookData> {
  /// 业务主键（UUID）
  final String key;

  /// 摘要（列表展示用）
  final String? excerpt;

  /// 富文本 HTML（vue-quill 产出）
  final String? html;
  final String? createTime;
  final String? updateTime;
  final String? mdText;
  final String? tags;
  final String? whereStr;
  final String? content;

  /// 分类
  final String? category;

  /// 旧层遗留可空整型列
  final int? id;
  const NoteBookData({
    required this.key,
    this.excerpt,
    this.html,
    this.createTime,
    this.updateTime,
    this.mdText,
    this.tags,
    this.whereStr,
    this.content,
    this.category,
    this.id,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || excerpt != null) {
      map['excerpt'] = Variable<String>(excerpt);
    }
    if (!nullToAbsent || html != null) {
      map['html'] = Variable<String>(html);
    }
    if (!nullToAbsent || createTime != null) {
      map['createTime'] = Variable<String>(createTime);
    }
    if (!nullToAbsent || updateTime != null) {
      map['updateTime'] = Variable<String>(updateTime);
    }
    if (!nullToAbsent || mdText != null) {
      map['mdText'] = Variable<String>(mdText);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || whereStr != null) {
      map['whereStr'] = Variable<String>(whereStr);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    return map;
  }

  NoteBookCompanion toCompanion(bool nullToAbsent) {
    return NoteBookCompanion(
      key: Value(key),
      excerpt: excerpt == null && nullToAbsent
          ? const Value.absent()
          : Value(excerpt),
      html: html == null && nullToAbsent ? const Value.absent() : Value(html),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
      updateTime: updateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(updateTime),
      mdText: mdText == null && nullToAbsent
          ? const Value.absent()
          : Value(mdText),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      whereStr: whereStr == null && nullToAbsent
          ? const Value.absent()
          : Value(whereStr),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
    );
  }

  factory NoteBookData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteBookData(
      key: serializer.fromJson<String>(json['key']),
      excerpt: serializer.fromJson<String?>(json['excerpt']),
      html: serializer.fromJson<String?>(json['html']),
      createTime: serializer.fromJson<String?>(json['createTime']),
      updateTime: serializer.fromJson<String?>(json['updateTime']),
      mdText: serializer.fromJson<String?>(json['mdText']),
      tags: serializer.fromJson<String?>(json['tags']),
      whereStr: serializer.fromJson<String?>(json['whereStr']),
      content: serializer.fromJson<String?>(json['content']),
      category: serializer.fromJson<String?>(json['category']),
      id: serializer.fromJson<int?>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'excerpt': serializer.toJson<String?>(excerpt),
      'html': serializer.toJson<String?>(html),
      'createTime': serializer.toJson<String?>(createTime),
      'updateTime': serializer.toJson<String?>(updateTime),
      'mdText': serializer.toJson<String?>(mdText),
      'tags': serializer.toJson<String?>(tags),
      'whereStr': serializer.toJson<String?>(whereStr),
      'content': serializer.toJson<String?>(content),
      'category': serializer.toJson<String?>(category),
      'id': serializer.toJson<int?>(id),
    };
  }

  NoteBookData copyWith({
    String? key,
    Value<String?> excerpt = const Value.absent(),
    Value<String?> html = const Value.absent(),
    Value<String?> createTime = const Value.absent(),
    Value<String?> updateTime = const Value.absent(),
    Value<String?> mdText = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> whereStr = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<int?> id = const Value.absent(),
  }) => NoteBookData(
    key: key ?? this.key,
    excerpt: excerpt.present ? excerpt.value : this.excerpt,
    html: html.present ? html.value : this.html,
    createTime: createTime.present ? createTime.value : this.createTime,
    updateTime: updateTime.present ? updateTime.value : this.updateTime,
    mdText: mdText.present ? mdText.value : this.mdText,
    tags: tags.present ? tags.value : this.tags,
    whereStr: whereStr.present ? whereStr.value : this.whereStr,
    content: content.present ? content.value : this.content,
    category: category.present ? category.value : this.category,
    id: id.present ? id.value : this.id,
  );
  NoteBookData copyWithCompanion(NoteBookCompanion data) {
    return NoteBookData(
      key: data.key.present ? data.key.value : this.key,
      excerpt: data.excerpt.present ? data.excerpt.value : this.excerpt,
      html: data.html.present ? data.html.value : this.html,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
      mdText: data.mdText.present ? data.mdText.value : this.mdText,
      tags: data.tags.present ? data.tags.value : this.tags,
      whereStr: data.whereStr.present ? data.whereStr.value : this.whereStr,
      content: data.content.present ? data.content.value : this.content,
      category: data.category.present ? data.category.value : this.category,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteBookData(')
          ..write('key: $key, ')
          ..write('excerpt: $excerpt, ')
          ..write('html: $html, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('mdText: $mdText, ')
          ..write('tags: $tags, ')
          ..write('whereStr: $whereStr, ')
          ..write('content: $content, ')
          ..write('category: $category, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    excerpt,
    html,
    createTime,
    updateTime,
    mdText,
    tags,
    whereStr,
    content,
    category,
    id,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteBookData &&
          other.key == this.key &&
          other.excerpt == this.excerpt &&
          other.html == this.html &&
          other.createTime == this.createTime &&
          other.updateTime == this.updateTime &&
          other.mdText == this.mdText &&
          other.tags == this.tags &&
          other.whereStr == this.whereStr &&
          other.content == this.content &&
          other.category == this.category &&
          other.id == this.id);
}

class NoteBookCompanion extends UpdateCompanion<NoteBookData> {
  final Value<String> key;
  final Value<String?> excerpt;
  final Value<String?> html;
  final Value<String?> createTime;
  final Value<String?> updateTime;
  final Value<String?> mdText;
  final Value<String?> tags;
  final Value<String?> whereStr;
  final Value<String?> content;
  final Value<String?> category;
  final Value<int?> id;
  final Value<int> rowid;
  const NoteBookCompanion({
    this.key = const Value.absent(),
    this.excerpt = const Value.absent(),
    this.html = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.mdText = const Value.absent(),
    this.tags = const Value.absent(),
    this.whereStr = const Value.absent(),
    this.content = const Value.absent(),
    this.category = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteBookCompanion.insert({
    required String key,
    this.excerpt = const Value.absent(),
    this.html = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.mdText = const Value.absent(),
    this.tags = const Value.absent(),
    this.whereStr = const Value.absent(),
    this.content = const Value.absent(),
    this.category = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<NoteBookData> custom({
    Expression<String>? key,
    Expression<String>? excerpt,
    Expression<String>? html,
    Expression<String>? createTime,
    Expression<String>? updateTime,
    Expression<String>? mdText,
    Expression<String>? tags,
    Expression<String>? whereStr,
    Expression<String>? content,
    Expression<String>? category,
    Expression<int>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (excerpt != null) 'excerpt': excerpt,
      if (html != null) 'html': html,
      if (createTime != null) 'createTime': createTime,
      if (updateTime != null) 'updateTime': updateTime,
      if (mdText != null) 'mdText': mdText,
      if (tags != null) 'tags': tags,
      if (whereStr != null) 'whereStr': whereStr,
      if (content != null) 'content': content,
      if (category != null) 'category': category,
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteBookCompanion copyWith({
    Value<String>? key,
    Value<String?>? excerpt,
    Value<String?>? html,
    Value<String?>? createTime,
    Value<String?>? updateTime,
    Value<String?>? mdText,
    Value<String?>? tags,
    Value<String?>? whereStr,
    Value<String?>? content,
    Value<String?>? category,
    Value<int?>? id,
    Value<int>? rowid,
  }) {
    return NoteBookCompanion(
      key: key ?? this.key,
      excerpt: excerpt ?? this.excerpt,
      html: html ?? this.html,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      mdText: mdText ?? this.mdText,
      tags: tags ?? this.tags,
      whereStr: whereStr ?? this.whereStr,
      content: content ?? this.content,
      category: category ?? this.category,
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (excerpt.present) {
      map['excerpt'] = Variable<String>(excerpt.value);
    }
    if (html.present) {
      map['html'] = Variable<String>(html.value);
    }
    if (createTime.present) {
      map['createTime'] = Variable<String>(createTime.value);
    }
    if (updateTime.present) {
      map['updateTime'] = Variable<String>(updateTime.value);
    }
    if (mdText.present) {
      map['mdText'] = Variable<String>(mdText.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (whereStr.present) {
      map['whereStr'] = Variable<String>(whereStr.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteBookCompanion(')
          ..write('key: $key, ')
          ..write('excerpt: $excerpt, ')
          ..write('html: $html, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('mdText: $mdText, ')
          ..write('tags: $tags, ')
          ..write('whereStr: $whereStr, ')
          ..write('content: $content, ')
          ..write('category: $category, ')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BasicInfoTable extends BasicInfo
    with TableInfo<$BasicInfoTable, BasicInfoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BasicInfoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whereStrMeta = const VerificationMeta(
    'whereStr',
  );
  @override
  late final GeneratedColumn<String> whereStr = GeneratedColumn<String>(
    'whereStr',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderByDescMeta = const VerificationMeta(
    'orderByDesc',
  );
  @override
  late final GeneratedColumn<String> orderByDesc = GeneratedColumn<String>(
    'orderByDesc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderByMeta = const VerificationMeta(
    'orderBy',
  );
  @override
  late final GeneratedColumn<String> orderBy = GeneratedColumn<String>(
    'orderBy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    value,
    whereStr,
    orderByDesc,
    orderBy,
    id,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'basic_info';
  @override
  VerificationContext validateIntegrity(
    Insertable<BasicInfoData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('whereStr')) {
      context.handle(
        _whereStrMeta,
        whereStr.isAcceptableOrUnknown(data['whereStr']!, _whereStrMeta),
      );
    }
    if (data.containsKey('orderByDesc')) {
      context.handle(
        _orderByDescMeta,
        orderByDesc.isAcceptableOrUnknown(
          data['orderByDesc']!,
          _orderByDescMeta,
        ),
      );
    }
    if (data.containsKey('orderBy')) {
      context.handle(
        _orderByMeta,
        orderBy.isAcceptableOrUnknown(data['orderBy']!, _orderByMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  BasicInfoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BasicInfoData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      whereStr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}whereStr'],
      ),
      orderByDesc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}orderByDesc'],
      ),
      orderBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}orderBy'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
    );
  }

  @override
  $BasicInfoTable createAlias(String alias) {
    return $BasicInfoTable(attachedDatabase, alias);
  }
}

class BasicInfoData extends DataClass implements Insertable<BasicInfoData> {
  /// 配置键（如 twoFactorVaultPath / appLockVault / note_tags / closeWorkTime）
  final String key;

  /// 配置值（vault 相关键的 value 为路径或哨兵 JSON）
  final String? value;
  final String? whereStr;
  final String? orderByDesc;
  final String? orderBy;

  /// 旧层遗留可空整型列
  final int? id;
  const BasicInfoData({
    required this.key,
    this.value,
    this.whereStr,
    this.orderByDesc,
    this.orderBy,
    this.id,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || whereStr != null) {
      map['whereStr'] = Variable<String>(whereStr);
    }
    if (!nullToAbsent || orderByDesc != null) {
      map['orderByDesc'] = Variable<String>(orderByDesc);
    }
    if (!nullToAbsent || orderBy != null) {
      map['orderBy'] = Variable<String>(orderBy);
    }
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    return map;
  }

  BasicInfoCompanion toCompanion(bool nullToAbsent) {
    return BasicInfoCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      whereStr: whereStr == null && nullToAbsent
          ? const Value.absent()
          : Value(whereStr),
      orderByDesc: orderByDesc == null && nullToAbsent
          ? const Value.absent()
          : Value(orderByDesc),
      orderBy: orderBy == null && nullToAbsent
          ? const Value.absent()
          : Value(orderBy),
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
    );
  }

  factory BasicInfoData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BasicInfoData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      whereStr: serializer.fromJson<String?>(json['whereStr']),
      orderByDesc: serializer.fromJson<String?>(json['orderByDesc']),
      orderBy: serializer.fromJson<String?>(json['orderBy']),
      id: serializer.fromJson<int?>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'whereStr': serializer.toJson<String?>(whereStr),
      'orderByDesc': serializer.toJson<String?>(orderByDesc),
      'orderBy': serializer.toJson<String?>(orderBy),
      'id': serializer.toJson<int?>(id),
    };
  }

  BasicInfoData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
    Value<String?> whereStr = const Value.absent(),
    Value<String?> orderByDesc = const Value.absent(),
    Value<String?> orderBy = const Value.absent(),
    Value<int?> id = const Value.absent(),
  }) => BasicInfoData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    whereStr: whereStr.present ? whereStr.value : this.whereStr,
    orderByDesc: orderByDesc.present ? orderByDesc.value : this.orderByDesc,
    orderBy: orderBy.present ? orderBy.value : this.orderBy,
    id: id.present ? id.value : this.id,
  );
  BasicInfoData copyWithCompanion(BasicInfoCompanion data) {
    return BasicInfoData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      whereStr: data.whereStr.present ? data.whereStr.value : this.whereStr,
      orderByDesc: data.orderByDesc.present
          ? data.orderByDesc.value
          : this.orderByDesc,
      orderBy: data.orderBy.present ? data.orderBy.value : this.orderBy,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BasicInfoData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('whereStr: $whereStr, ')
          ..write('orderByDesc: $orderByDesc, ')
          ..write('orderBy: $orderBy, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, value, whereStr, orderByDesc, orderBy, id);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BasicInfoData &&
          other.key == this.key &&
          other.value == this.value &&
          other.whereStr == this.whereStr &&
          other.orderByDesc == this.orderByDesc &&
          other.orderBy == this.orderBy &&
          other.id == this.id);
}

class BasicInfoCompanion extends UpdateCompanion<BasicInfoData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<String?> whereStr;
  final Value<String?> orderByDesc;
  final Value<String?> orderBy;
  final Value<int?> id;
  final Value<int> rowid;
  const BasicInfoCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.whereStr = const Value.absent(),
    this.orderByDesc = const Value.absent(),
    this.orderBy = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BasicInfoCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.whereStr = const Value.absent(),
    this.orderByDesc = const Value.absent(),
    this.orderBy = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<BasicInfoData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? whereStr,
    Expression<String>? orderByDesc,
    Expression<String>? orderBy,
    Expression<int>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (whereStr != null) 'whereStr': whereStr,
      if (orderByDesc != null) 'orderByDesc': orderByDesc,
      if (orderBy != null) 'orderBy': orderBy,
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BasicInfoCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<String?>? whereStr,
    Value<String?>? orderByDesc,
    Value<String?>? orderBy,
    Value<int?>? id,
    Value<int>? rowid,
  }) {
    return BasicInfoCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      whereStr: whereStr ?? this.whereStr,
      orderByDesc: orderByDesc ?? this.orderByDesc,
      orderBy: orderBy ?? this.orderBy,
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (whereStr.present) {
      map['whereStr'] = Variable<String>(whereStr.value);
    }
    if (orderByDesc.present) {
      map['orderByDesc'] = Variable<String>(orderByDesc.value);
    }
    if (orderBy.present) {
      map['orderBy'] = Variable<String>(orderBy.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BasicInfoCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('whereStr: $whereStr, ')
          ..write('orderByDesc: $orderByDesc, ')
          ..write('orderBy: $orderBy, ')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PomodoroStatusTable extends PomodoroStatus
    with TableInfo<$PomodoroStatusTable, PomodoroStatusData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PomodoroStatusTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<String> createTime = GeneratedColumn<String>(
    'create_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<String> recordedAt = GeneratedColumn<String>(
    'dateTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    value,
    mode,
    createTime,
    date,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pomodoro_status';
  @override
  VerificationContext validateIntegrity(
    Insertable<PomodoroStatusData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('create_time')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['create_time']!, _createTimeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('dateTime')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['dateTime']!, _recordedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PomodoroStatusData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PomodoroStatusData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}create_time'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dateTime'],
      ),
    );
  }

  @override
  $PomodoroStatusTable createAlias(String alias) {
    return $PomodoroStatusTable(attachedDatabase, alias);
  }
}

class PomodoroStatusData extends DataClass
    implements Insertable<PomodoroStatusData> {
  /// 自增主键
  final int id;

  /// 展示标签，如 '正在工作'
  final String? label;

  /// 状态值：work / rest / lock
  final String? value;

  /// 场景模式，如 development
  final String? mode;

  /// 创建时间（桌面端为下划线列名，drift 默认转换即对齐，named() 显式锁定）
  final String? createTime;
  final String? date;

  /// 状态变更时刻（桌面端为驼峰列名）
  /// ⚠️ getter 不能叫 dateTime（与 drift Table.dateTime() 构造方法冲突），
  ///    改名 recordedAt 并用 named('dateTime') 锁定桌面列名。
  final String? recordedAt;
  const PomodoroStatusData({
    required this.id,
    this.label,
    this.value,
    this.mode,
    this.createTime,
    this.date,
    this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || createTime != null) {
      map['create_time'] = Variable<String>(createTime);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || recordedAt != null) {
      map['dateTime'] = Variable<String>(recordedAt);
    }
    return map;
  }

  PomodoroStatusCompanion toCompanion(bool nullToAbsent) {
    return PomodoroStatusCompanion(
      id: Value(id),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      recordedAt: recordedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(recordedAt),
    );
  }

  factory PomodoroStatusData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PomodoroStatusData(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String?>(json['label']),
      value: serializer.fromJson<String?>(json['value']),
      mode: serializer.fromJson<String?>(json['mode']),
      createTime: serializer.fromJson<String?>(json['createTime']),
      date: serializer.fromJson<String?>(json['date']),
      recordedAt: serializer.fromJson<String?>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String?>(label),
      'value': serializer.toJson<String?>(value),
      'mode': serializer.toJson<String?>(mode),
      'createTime': serializer.toJson<String?>(createTime),
      'date': serializer.toJson<String?>(date),
      'recordedAt': serializer.toJson<String?>(recordedAt),
    };
  }

  PomodoroStatusData copyWith({
    int? id,
    Value<String?> label = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> mode = const Value.absent(),
    Value<String?> createTime = const Value.absent(),
    Value<String?> date = const Value.absent(),
    Value<String?> recordedAt = const Value.absent(),
  }) => PomodoroStatusData(
    id: id ?? this.id,
    label: label.present ? label.value : this.label,
    value: value.present ? value.value : this.value,
    mode: mode.present ? mode.value : this.mode,
    createTime: createTime.present ? createTime.value : this.createTime,
    date: date.present ? date.value : this.date,
    recordedAt: recordedAt.present ? recordedAt.value : this.recordedAt,
  );
  PomodoroStatusData copyWithCompanion(PomodoroStatusCompanion data) {
    return PomodoroStatusData(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
      mode: data.mode.present ? data.mode.value : this.mode,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
      date: data.date.present ? data.date.value : this.date,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroStatusData(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('mode: $mode, ')
          ..write('createTime: $createTime, ')
          ..write('date: $date, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, label, value, mode, createTime, date, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PomodoroStatusData &&
          other.id == this.id &&
          other.label == this.label &&
          other.value == this.value &&
          other.mode == this.mode &&
          other.createTime == this.createTime &&
          other.date == this.date &&
          other.recordedAt == this.recordedAt);
}

class PomodoroStatusCompanion extends UpdateCompanion<PomodoroStatusData> {
  final Value<int> id;
  final Value<String?> label;
  final Value<String?> value;
  final Value<String?> mode;
  final Value<String?> createTime;
  final Value<String?> date;
  final Value<String?> recordedAt;
  const PomodoroStatusCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.mode = const Value.absent(),
    this.createTime = const Value.absent(),
    this.date = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  PomodoroStatusCompanion.insert({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.mode = const Value.absent(),
    this.createTime = const Value.absent(),
    this.date = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  static Insertable<PomodoroStatusData> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? value,
    Expression<String>? mode,
    Expression<String>? createTime,
    Expression<String>? date,
    Expression<String>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (mode != null) 'mode': mode,
      if (createTime != null) 'create_time': createTime,
      if (date != null) 'date': date,
      if (recordedAt != null) 'dateTime': recordedAt,
    });
  }

  PomodoroStatusCompanion copyWith({
    Value<int>? id,
    Value<String?>? label,
    Value<String?>? value,
    Value<String?>? mode,
    Value<String?>? createTime,
    Value<String?>? date,
    Value<String?>? recordedAt,
  }) {
    return PomodoroStatusCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      mode: mode ?? this.mode,
      createTime: createTime ?? this.createTime,
      date: date ?? this.date,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (createTime.present) {
      map['create_time'] = Variable<String>(createTime.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (recordedAt.present) {
      map['dateTime'] = Variable<String>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroStatusCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('mode: $mode, ')
          ..write('createTime: $createTime, ')
          ..write('date: $date, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $PomodoroMiniConfigTable extends PomodoroMiniConfig
    with TableInfo<$PomodoroMiniConfigTable, PomodoroMiniConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PomodoroMiniConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skinMeta = const VerificationMeta('skin');
  @override
  late final GeneratedColumn<String> skin = GeneratedColumn<String>(
    'skin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, skin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pomodoro_mini_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<PomodoroMiniConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('skin')) {
      context.handle(
        _skinMeta,
        skin.isAcceptableOrUnknown(data['skin']!, _skinMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PomodoroMiniConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PomodoroMiniConfigData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      skin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skin'],
      ),
    );
  }

  @override
  $PomodoroMiniConfigTable createAlias(String alias) {
    return $PomodoroMiniConfigTable(attachedDatabase, alias);
  }
}

class PomodoroMiniConfigData extends DataClass
    implements Insertable<PomodoroMiniConfigData> {
  final String key;
  final String? skin;
  const PomodoroMiniConfigData({required this.key, this.skin});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || skin != null) {
      map['skin'] = Variable<String>(skin);
    }
    return map;
  }

  PomodoroMiniConfigCompanion toCompanion(bool nullToAbsent) {
    return PomodoroMiniConfigCompanion(
      key: Value(key),
      skin: skin == null && nullToAbsent ? const Value.absent() : Value(skin),
    );
  }

  factory PomodoroMiniConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PomodoroMiniConfigData(
      key: serializer.fromJson<String>(json['key']),
      skin: serializer.fromJson<String?>(json['skin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'skin': serializer.toJson<String?>(skin),
    };
  }

  PomodoroMiniConfigData copyWith({
    String? key,
    Value<String?> skin = const Value.absent(),
  }) => PomodoroMiniConfigData(
    key: key ?? this.key,
    skin: skin.present ? skin.value : this.skin,
  );
  PomodoroMiniConfigData copyWithCompanion(PomodoroMiniConfigCompanion data) {
    return PomodoroMiniConfigData(
      key: data.key.present ? data.key.value : this.key,
      skin: data.skin.present ? data.skin.value : this.skin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroMiniConfigData(')
          ..write('key: $key, ')
          ..write('skin: $skin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, skin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PomodoroMiniConfigData &&
          other.key == this.key &&
          other.skin == this.skin);
}

class PomodoroMiniConfigCompanion
    extends UpdateCompanion<PomodoroMiniConfigData> {
  final Value<String> key;
  final Value<String?> skin;
  final Value<int> rowid;
  const PomodoroMiniConfigCompanion({
    this.key = const Value.absent(),
    this.skin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PomodoroMiniConfigCompanion.insert({
    required String key,
    this.skin = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<PomodoroMiniConfigData> custom({
    Expression<String>? key,
    Expression<String>? skin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (skin != null) 'skin': skin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PomodoroMiniConfigCompanion copyWith({
    Value<String>? key,
    Value<String?>? skin,
    Value<int>? rowid,
  }) {
    return PomodoroMiniConfigCompanion(
      key: key ?? this.key,
      skin: skin ?? this.skin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (skin.present) {
      map['skin'] = Variable<String>(skin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroMiniConfigCompanion(')
          ..write('key: $key, ')
          ..write('skin: $skin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationTable extends Conversation
    with TableInfo<$ConversationTable, ConversationData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeIdMeta = const VerificationMeta(
    'themeId',
  );
  @override
  late final GeneratedColumn<String> themeId = GeneratedColumn<String>(
    'theme_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<String> createTime = GeneratedColumn<String>(
    'create_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotateTimeMeta = const VerificationMeta(
    'annotateTime',
  );
  @override
  late final GeneratedColumn<String> annotateTime = GeneratedColumn<String>(
    'annotate_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<String> pinned = GeneratedColumn<String>(
    'pinned',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<String> isDeleted = GeneratedColumn<String>(
    'is_deleted',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refIdsMeta = const VerificationMeta('refIds');
  @override
  late final GeneratedColumn<String> refIds = GeneratedColumn<String>(
    'ref_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isRichMeta = const VerificationMeta('isRich');
  @override
  late final GeneratedColumn<String> isRich = GeneratedColumn<String>(
    'is_rich',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _is_Meta = const VerificationMeta('is_');
  @override
  late final GeneratedColumn<String> is_ = GeneratedColumn<String>(
    'is_',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _crossRefsMeta = const VerificationMeta(
    'crossRefs',
  );
  @override
  late final GeneratedColumn<String> crossRefs = GeneratedColumn<String>(
    'cross_refs',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extKeyMeta = const VerificationMeta('extKey');
  @override
  late final GeneratedColumn<String> extKey = GeneratedColumn<String>(
    'ext_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    themeId,
    content,
    tags,
    createTime,
    annotateTime,
    pinned,
    isDeleted,
    refIds,
    isRich,
    is_,
    crossRefs,
    extKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('theme_id')) {
      context.handle(
        _themeIdMeta,
        themeId.isAcceptableOrUnknown(data['theme_id']!, _themeIdMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('create_time')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['create_time']!, _createTimeMeta),
      );
    }
    if (data.containsKey('annotate_time')) {
      context.handle(
        _annotateTimeMeta,
        annotateTime.isAcceptableOrUnknown(
          data['annotate_time']!,
          _annotateTimeMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('ref_ids')) {
      context.handle(
        _refIdsMeta,
        refIds.isAcceptableOrUnknown(data['ref_ids']!, _refIdsMeta),
      );
    }
    if (data.containsKey('is_rich')) {
      context.handle(
        _isRichMeta,
        isRich.isAcceptableOrUnknown(data['is_rich']!, _isRichMeta),
      );
    }
    if (data.containsKey('is_')) {
      context.handle(
        _is_Meta,
        is_.isAcceptableOrUnknown(data['is_']!, _is_Meta),
      );
    }
    if (data.containsKey('cross_refs')) {
      context.handle(
        _crossRefsMeta,
        crossRefs.isAcceptableOrUnknown(data['cross_refs']!, _crossRefsMeta),
      );
    }
    if (data.containsKey('ext_key')) {
      context.handle(
        _extKeyMeta,
        extKey.isAcceptableOrUnknown(data['ext_key']!, _extKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      themeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}create_time'],
      ),
      annotateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotate_time'],
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinned'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}is_deleted'],
      ),
      refIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_ids'],
      ),
      isRich: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}is_rich'],
      ),
      is_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}is_'],
      ),
      crossRefs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cross_refs'],
      ),
      extKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext_key'],
      ),
    );
  }

  @override
  $ConversationTable createAlias(String alias) {
    return $ConversationTable(attachedDatabase, alias);
  }
}

class ConversationData extends DataClass
    implements Insertable<ConversationData> {
  final int id;
  final String? name;
  final String? value;
  final String? createdAt;

  /// 所属主题 id（conversation_theme.id 的字符串形式）
  final String? themeId;

  /// 消息内容
  final String? content;

  /// 标签 JSON 数组
  final String? tags;
  final String? createTime;

  /// 标注时间
  final String? annotateTime;

  /// 是否置顶：'1'/'0'
  final String? pinned;

  /// 软删除标记：'1'/'0'
  final String? isDeleted;

  /// 引用的消息 id JSON
  final String? refIds;

  /// 是否富文本：'1'/'0'
  final String? isRich;

  /// 桌面端遗留的截断列名（真实列就叫 is_），原样保留
  final String? is_;

  /// 交叉引用 JSON
  final String? crossRefs;

  /// 扩展键
  final String? extKey;
  const ConversationData({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.themeId,
    this.content,
    this.tags,
    this.createTime,
    this.annotateTime,
    this.pinned,
    this.isDeleted,
    this.refIds,
    this.isRich,
    this.is_,
    this.crossRefs,
    this.extKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || themeId != null) {
      map['theme_id'] = Variable<String>(themeId);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || createTime != null) {
      map['create_time'] = Variable<String>(createTime);
    }
    if (!nullToAbsent || annotateTime != null) {
      map['annotate_time'] = Variable<String>(annotateTime);
    }
    if (!nullToAbsent || pinned != null) {
      map['pinned'] = Variable<String>(pinned);
    }
    if (!nullToAbsent || isDeleted != null) {
      map['is_deleted'] = Variable<String>(isDeleted);
    }
    if (!nullToAbsent || refIds != null) {
      map['ref_ids'] = Variable<String>(refIds);
    }
    if (!nullToAbsent || isRich != null) {
      map['is_rich'] = Variable<String>(isRich);
    }
    if (!nullToAbsent || is_ != null) {
      map['is_'] = Variable<String>(is_);
    }
    if (!nullToAbsent || crossRefs != null) {
      map['cross_refs'] = Variable<String>(crossRefs);
    }
    if (!nullToAbsent || extKey != null) {
      map['ext_key'] = Variable<String>(extKey);
    }
    return map;
  }

  ConversationCompanion toCompanion(bool nullToAbsent) {
    return ConversationCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      themeId: themeId == null && nullToAbsent
          ? const Value.absent()
          : Value(themeId),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
      annotateTime: annotateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(annotateTime),
      pinned: pinned == null && nullToAbsent
          ? const Value.absent()
          : Value(pinned),
      isDeleted: isDeleted == null && nullToAbsent
          ? const Value.absent()
          : Value(isDeleted),
      refIds: refIds == null && nullToAbsent
          ? const Value.absent()
          : Value(refIds),
      isRich: isRich == null && nullToAbsent
          ? const Value.absent()
          : Value(isRich),
      is_: is_ == null && nullToAbsent ? const Value.absent() : Value(is_),
      crossRefs: crossRefs == null && nullToAbsent
          ? const Value.absent()
          : Value(crossRefs),
      extKey: extKey == null && nullToAbsent
          ? const Value.absent()
          : Value(extKey),
    );
  }

  factory ConversationData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      themeId: serializer.fromJson<String?>(json['themeId']),
      content: serializer.fromJson<String?>(json['content']),
      tags: serializer.fromJson<String?>(json['tags']),
      createTime: serializer.fromJson<String?>(json['createTime']),
      annotateTime: serializer.fromJson<String?>(json['annotateTime']),
      pinned: serializer.fromJson<String?>(json['pinned']),
      isDeleted: serializer.fromJson<String?>(json['isDeleted']),
      refIds: serializer.fromJson<String?>(json['refIds']),
      isRich: serializer.fromJson<String?>(json['isRich']),
      is_: serializer.fromJson<String?>(json['is_']),
      crossRefs: serializer.fromJson<String?>(json['crossRefs']),
      extKey: serializer.fromJson<String?>(json['extKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'themeId': serializer.toJson<String?>(themeId),
      'content': serializer.toJson<String?>(content),
      'tags': serializer.toJson<String?>(tags),
      'createTime': serializer.toJson<String?>(createTime),
      'annotateTime': serializer.toJson<String?>(annotateTime),
      'pinned': serializer.toJson<String?>(pinned),
      'isDeleted': serializer.toJson<String?>(isDeleted),
      'refIds': serializer.toJson<String?>(refIds),
      'isRich': serializer.toJson<String?>(isRich),
      'is_': serializer.toJson<String?>(is_),
      'crossRefs': serializer.toJson<String?>(crossRefs),
      'extKey': serializer.toJson<String?>(extKey),
    };
  }

  ConversationData copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> themeId = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> createTime = const Value.absent(),
    Value<String?> annotateTime = const Value.absent(),
    Value<String?> pinned = const Value.absent(),
    Value<String?> isDeleted = const Value.absent(),
    Value<String?> refIds = const Value.absent(),
    Value<String?> isRich = const Value.absent(),
    Value<String?> is_ = const Value.absent(),
    Value<String?> crossRefs = const Value.absent(),
    Value<String?> extKey = const Value.absent(),
  }) => ConversationData(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    themeId: themeId.present ? themeId.value : this.themeId,
    content: content.present ? content.value : this.content,
    tags: tags.present ? tags.value : this.tags,
    createTime: createTime.present ? createTime.value : this.createTime,
    annotateTime: annotateTime.present ? annotateTime.value : this.annotateTime,
    pinned: pinned.present ? pinned.value : this.pinned,
    isDeleted: isDeleted.present ? isDeleted.value : this.isDeleted,
    refIds: refIds.present ? refIds.value : this.refIds,
    isRich: isRich.present ? isRich.value : this.isRich,
    is_: is_.present ? is_.value : this.is_,
    crossRefs: crossRefs.present ? crossRefs.value : this.crossRefs,
    extKey: extKey.present ? extKey.value : this.extKey,
  );
  ConversationData copyWithCompanion(ConversationCompanion data) {
    return ConversationData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      themeId: data.themeId.present ? data.themeId.value : this.themeId,
      content: data.content.present ? data.content.value : this.content,
      tags: data.tags.present ? data.tags.value : this.tags,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
      annotateTime: data.annotateTime.present
          ? data.annotateTime.value
          : this.annotateTime,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      refIds: data.refIds.present ? data.refIds.value : this.refIds,
      isRich: data.isRich.present ? data.isRich.value : this.isRich,
      is_: data.is_.present ? data.is_.value : this.is_,
      crossRefs: data.crossRefs.present ? data.crossRefs.value : this.crossRefs,
      extKey: data.extKey.present ? data.extKey.value : this.extKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('themeId: $themeId, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('createTime: $createTime, ')
          ..write('annotateTime: $annotateTime, ')
          ..write('pinned: $pinned, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('refIds: $refIds, ')
          ..write('isRich: $isRich, ')
          ..write('is_: $is_, ')
          ..write('crossRefs: $crossRefs, ')
          ..write('extKey: $extKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    value,
    createdAt,
    themeId,
    content,
    tags,
    createTime,
    annotateTime,
    pinned,
    isDeleted,
    refIds,
    isRich,
    is_,
    crossRefs,
    extKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationData &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.themeId == this.themeId &&
          other.content == this.content &&
          other.tags == this.tags &&
          other.createTime == this.createTime &&
          other.annotateTime == this.annotateTime &&
          other.pinned == this.pinned &&
          other.isDeleted == this.isDeleted &&
          other.refIds == this.refIds &&
          other.isRich == this.isRich &&
          other.is_ == this.is_ &&
          other.crossRefs == this.crossRefs &&
          other.extKey == this.extKey);
}

class ConversationCompanion extends UpdateCompanion<ConversationData> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> themeId;
  final Value<String?> content;
  final Value<String?> tags;
  final Value<String?> createTime;
  final Value<String?> annotateTime;
  final Value<String?> pinned;
  final Value<String?> isDeleted;
  final Value<String?> refIds;
  final Value<String?> isRich;
  final Value<String?> is_;
  final Value<String?> crossRefs;
  final Value<String?> extKey;
  const ConversationCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.themeId = const Value.absent(),
    this.content = const Value.absent(),
    this.tags = const Value.absent(),
    this.createTime = const Value.absent(),
    this.annotateTime = const Value.absent(),
    this.pinned = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.refIds = const Value.absent(),
    this.isRich = const Value.absent(),
    this.is_ = const Value.absent(),
    this.crossRefs = const Value.absent(),
    this.extKey = const Value.absent(),
  });
  ConversationCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.themeId = const Value.absent(),
    this.content = const Value.absent(),
    this.tags = const Value.absent(),
    this.createTime = const Value.absent(),
    this.annotateTime = const Value.absent(),
    this.pinned = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.refIds = const Value.absent(),
    this.isRich = const Value.absent(),
    this.is_ = const Value.absent(),
    this.crossRefs = const Value.absent(),
    this.extKey = const Value.absent(),
  });
  static Insertable<ConversationData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? themeId,
    Expression<String>? content,
    Expression<String>? tags,
    Expression<String>? createTime,
    Expression<String>? annotateTime,
    Expression<String>? pinned,
    Expression<String>? isDeleted,
    Expression<String>? refIds,
    Expression<String>? isRich,
    Expression<String>? is_,
    Expression<String>? crossRefs,
    Expression<String>? extKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (themeId != null) 'theme_id': themeId,
      if (content != null) 'content': content,
      if (tags != null) 'tags': tags,
      if (createTime != null) 'create_time': createTime,
      if (annotateTime != null) 'annotate_time': annotateTime,
      if (pinned != null) 'pinned': pinned,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (refIds != null) 'ref_ids': refIds,
      if (isRich != null) 'is_rich': isRich,
      if (is_ != null) 'is_': is_,
      if (crossRefs != null) 'cross_refs': crossRefs,
      if (extKey != null) 'ext_key': extKey,
    });
  }

  ConversationCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? themeId,
    Value<String?>? content,
    Value<String?>? tags,
    Value<String?>? createTime,
    Value<String?>? annotateTime,
    Value<String?>? pinned,
    Value<String?>? isDeleted,
    Value<String?>? refIds,
    Value<String?>? isRich,
    Value<String?>? is_,
    Value<String?>? crossRefs,
    Value<String?>? extKey,
  }) {
    return ConversationCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      themeId: themeId ?? this.themeId,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createTime: createTime ?? this.createTime,
      annotateTime: annotateTime ?? this.annotateTime,
      pinned: pinned ?? this.pinned,
      isDeleted: isDeleted ?? this.isDeleted,
      refIds: refIds ?? this.refIds,
      isRich: isRich ?? this.isRich,
      is_: is_ ?? this.is_,
      crossRefs: crossRefs ?? this.crossRefs,
      extKey: extKey ?? this.extKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (themeId.present) {
      map['theme_id'] = Variable<String>(themeId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createTime.present) {
      map['create_time'] = Variable<String>(createTime.value);
    }
    if (annotateTime.present) {
      map['annotate_time'] = Variable<String>(annotateTime.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<String>(pinned.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<String>(isDeleted.value);
    }
    if (refIds.present) {
      map['ref_ids'] = Variable<String>(refIds.value);
    }
    if (isRich.present) {
      map['is_rich'] = Variable<String>(isRich.value);
    }
    if (is_.present) {
      map['is_'] = Variable<String>(is_.value);
    }
    if (crossRefs.present) {
      map['cross_refs'] = Variable<String>(crossRefs.value);
    }
    if (extKey.present) {
      map['ext_key'] = Variable<String>(extKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('themeId: $themeId, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('createTime: $createTime, ')
          ..write('annotateTime: $annotateTime, ')
          ..write('pinned: $pinned, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('refIds: $refIds, ')
          ..write('isRich: $isRich, ')
          ..write('is_: $is_, ')
          ..write('crossRefs: $crossRefs, ')
          ..write('extKey: $extKey')
          ..write(')'))
        .toString();
  }
}

class $ConversationThemeTable extends ConversationTheme
    with TableInfo<$ConversationThemeTable, ConversationThemeData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationThemeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<String> createTime = GeneratedColumn<String>(
    'create_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<String> updateTime = GeneratedColumn<String>(
    'update_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    title,
    tags,
    createTime,
    updateTime,
    remark,
    parentId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_theme';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationThemeData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('create_time')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['create_time']!, _createTimeMeta),
      );
    }
    if (data.containsKey('update_time')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['update_time']!, _updateTimeMeta),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationThemeData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationThemeData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}create_time'],
      ),
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}update_time'],
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $ConversationThemeTable createAlias(String alias) {
    return $ConversationThemeTable(attachedDatabase, alias);
  }
}

class ConversationThemeData extends DataClass
    implements Insertable<ConversationThemeData> {
  final int id;
  final String? name;
  final String? value;
  final String? createdAt;
  final String? title;
  final String? tags;
  final String? createTime;
  final String? updateTime;
  final String? remark;

  /// 父主题 id（主题树）
  final String? parentId;
  const ConversationThemeData({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.title,
    this.tags,
    this.createTime,
    this.updateTime,
    this.remark,
    this.parentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || createTime != null) {
      map['create_time'] = Variable<String>(createTime);
    }
    if (!nullToAbsent || updateTime != null) {
      map['update_time'] = Variable<String>(updateTime);
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    return map;
  }

  ConversationThemeCompanion toCompanion(bool nullToAbsent) {
    return ConversationThemeCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
      updateTime: updateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(updateTime),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory ConversationThemeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationThemeData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      title: serializer.fromJson<String?>(json['title']),
      tags: serializer.fromJson<String?>(json['tags']),
      createTime: serializer.fromJson<String?>(json['createTime']),
      updateTime: serializer.fromJson<String?>(json['updateTime']),
      remark: serializer.fromJson<String?>(json['remark']),
      parentId: serializer.fromJson<String?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'title': serializer.toJson<String?>(title),
      'tags': serializer.toJson<String?>(tags),
      'createTime': serializer.toJson<String?>(createTime),
      'updateTime': serializer.toJson<String?>(updateTime),
      'remark': serializer.toJson<String?>(remark),
      'parentId': serializer.toJson<String?>(parentId),
    };
  }

  ConversationThemeData copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> createTime = const Value.absent(),
    Value<String?> updateTime = const Value.absent(),
    Value<String?> remark = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
  }) => ConversationThemeData(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    title: title.present ? title.value : this.title,
    tags: tags.present ? tags.value : this.tags,
    createTime: createTime.present ? createTime.value : this.createTime,
    updateTime: updateTime.present ? updateTime.value : this.updateTime,
    remark: remark.present ? remark.value : this.remark,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  ConversationThemeData copyWithCompanion(ConversationThemeCompanion data) {
    return ConversationThemeData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      title: data.title.present ? data.title.value : this.title,
      tags: data.tags.present ? data.tags.value : this.tags,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
      remark: data.remark.present ? data.remark.value : this.remark,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationThemeData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title, ')
          ..write('tags: $tags, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('remark: $remark, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    value,
    createdAt,
    title,
    tags,
    createTime,
    updateTime,
    remark,
    parentId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationThemeData &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.title == this.title &&
          other.tags == this.tags &&
          other.createTime == this.createTime &&
          other.updateTime == this.updateTime &&
          other.remark == this.remark &&
          other.parentId == this.parentId);
}

class ConversationThemeCompanion
    extends UpdateCompanion<ConversationThemeData> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> title;
  final Value<String?> tags;
  final Value<String?> createTime;
  final Value<String?> updateTime;
  final Value<String?> remark;
  final Value<String?> parentId;
  const ConversationThemeCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.title = const Value.absent(),
    this.tags = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.remark = const Value.absent(),
    this.parentId = const Value.absent(),
  });
  ConversationThemeCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.title = const Value.absent(),
    this.tags = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.remark = const Value.absent(),
    this.parentId = const Value.absent(),
  });
  static Insertable<ConversationThemeData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? title,
    Expression<String>? tags,
    Expression<String>? createTime,
    Expression<String>? updateTime,
    Expression<String>? remark,
    Expression<String>? parentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (title != null) 'title': title,
      if (tags != null) 'tags': tags,
      if (createTime != null) 'create_time': createTime,
      if (updateTime != null) 'update_time': updateTime,
      if (remark != null) 'remark': remark,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  ConversationThemeCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? title,
    Value<String?>? tags,
    Value<String?>? createTime,
    Value<String?>? updateTime,
    Value<String?>? remark,
    Value<String?>? parentId,
  }) {
    return ConversationThemeCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      remark: remark ?? this.remark,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createTime.present) {
      map['create_time'] = Variable<String>(createTime.value);
    }
    if (updateTime.present) {
      map['update_time'] = Variable<String>(updateTime.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationThemeCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title, ')
          ..write('tags: $tags, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('remark: $remark, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }
}

class $ConversationTagTable extends ConversationTag
    with TableInfo<$ConversationTagTable, ConversationTagData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationTagTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<String> createTime = GeneratedColumn<String>(
    'create_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    color,
    scope,
    createTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_tag';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationTagData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('create_time')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['create_time']!, _createTimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationTagData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationTagData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      ),
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}create_time'],
      ),
    );
  }

  @override
  $ConversationTagTable createAlias(String alias) {
    return $ConversationTagTable(attachedDatabase, alias);
  }
}

class ConversationTagData extends DataClass
    implements Insertable<ConversationTagData> {
  final int id;
  final String? name;
  final String? value;
  final String? createdAt;
  final String? color;
  final String? scope;
  final String? createTime;
  const ConversationTagData({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.color,
    this.scope,
    this.createTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || scope != null) {
      map['scope'] = Variable<String>(scope);
    }
    if (!nullToAbsent || createTime != null) {
      map['create_time'] = Variable<String>(createTime);
    }
    return map;
  }

  ConversationTagCompanion toCompanion(bool nullToAbsent) {
    return ConversationTagCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      scope: scope == null && nullToAbsent
          ? const Value.absent()
          : Value(scope),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
    );
  }

  factory ConversationTagData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationTagData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      color: serializer.fromJson<String?>(json['color']),
      scope: serializer.fromJson<String?>(json['scope']),
      createTime: serializer.fromJson<String?>(json['createTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'color': serializer.toJson<String?>(color),
      'scope': serializer.toJson<String?>(scope),
      'createTime': serializer.toJson<String?>(createTime),
    };
  }

  ConversationTagData copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<String?> scope = const Value.absent(),
    Value<String?> createTime = const Value.absent(),
  }) => ConversationTagData(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    color: color.present ? color.value : this.color,
    scope: scope.present ? scope.value : this.scope,
    createTime: createTime.present ? createTime.value : this.createTime,
  );
  ConversationTagData copyWithCompanion(ConversationTagCompanion data) {
    return ConversationTagData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      color: data.color.present ? data.color.value : this.color,
      scope: data.scope.present ? data.scope.value : this.scope,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationTagData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('color: $color, ')
          ..write('scope: $scope, ')
          ..write('createTime: $createTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, value, createdAt, color, scope, createTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationTagData &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.color == this.color &&
          other.scope == this.scope &&
          other.createTime == this.createTime);
}

class ConversationTagCompanion extends UpdateCompanion<ConversationTagData> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> color;
  final Value<String?> scope;
  final Value<String?> createTime;
  const ConversationTagCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.color = const Value.absent(),
    this.scope = const Value.absent(),
    this.createTime = const Value.absent(),
  });
  ConversationTagCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.color = const Value.absent(),
    this.scope = const Value.absent(),
    this.createTime = const Value.absent(),
  });
  static Insertable<ConversationTagData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? color,
    Expression<String>? scope,
    Expression<String>? createTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (color != null) 'color': color,
      if (scope != null) 'scope': scope,
      if (createTime != null) 'create_time': createTime,
    });
  }

  ConversationTagCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? color,
    Value<String?>? scope,
    Value<String?>? createTime,
  }) {
    return ConversationTagCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      scope: scope ?? this.scope,
      createTime: createTime ?? this.createTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (createTime.present) {
      map['create_time'] = Variable<String>(createTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationTagCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('color: $color, ')
          ..write('scope: $scope, ')
          ..write('createTime: $createTime')
          ..write(')'))
        .toString();
  }
}

class $FileVaultConfigTable extends FileVaultConfig
    with TableInfo<$FileVaultConfigTable, FileVaultConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileVaultConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_vault_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileVaultConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  FileVaultConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileVaultConfigData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
    );
  }

  @override
  $FileVaultConfigTable createAlias(String alias) {
    return $FileVaultConfigTable(attachedDatabase, alias);
  }
}

class FileVaultConfigData extends DataClass
    implements Insertable<FileVaultConfigData> {
  /// 目前只有 'vault'
  final String key;

  /// JSON：{"salt":"...","wrappedKey":"..."}（用户口令包装主密钥）
  final String? value;

  /// 旧层遗留可空整型列
  final int? id;
  const FileVaultConfigData({required this.key, this.value, this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    return map;
  }

  FileVaultConfigCompanion toCompanion(bool nullToAbsent) {
    return FileVaultConfigCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
    );
  }

  factory FileVaultConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileVaultConfigData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      id: serializer.fromJson<int?>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'id': serializer.toJson<int?>(id),
    };
  }

  FileVaultConfigData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
    Value<int?> id = const Value.absent(),
  }) => FileVaultConfigData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    id: id.present ? id.value : this.id,
  );
  FileVaultConfigData copyWithCompanion(FileVaultConfigCompanion data) {
    return FileVaultConfigData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileVaultConfigData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, id);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileVaultConfigData &&
          other.key == this.key &&
          other.value == this.value &&
          other.id == this.id);
}

class FileVaultConfigCompanion extends UpdateCompanion<FileVaultConfigData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int?> id;
  final Value<int> rowid;
  const FileVaultConfigCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileVaultConfigCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<FileVaultConfigData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileVaultConfigCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int?>? id,
    Value<int>? rowid,
  }) {
    return FileVaultConfigCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileVaultConfigCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileVaultFilesTable extends FileVaultFiles
    with TableInfo<$FileVaultFilesTable, FileVaultFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileVaultFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ciphertextPathMeta = const VerificationMeta(
    'ciphertextPath',
  );
  @override
  late final GeneratedColumn<String> ciphertextPath = GeneratedColumn<String>(
    'ciphertext_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    mime,
    ext,
    size,
    ciphertextPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_vault_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileVaultFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('ciphertext_path')) {
      context.handle(
        _ciphertextPathMeta,
        ciphertextPath.isAcceptableOrUnknown(
          data['ciphertext_path']!,
          _ciphertextPathMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FileVaultFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileVaultFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      ),
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size'],
      ),
      ciphertextPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ciphertext_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $FileVaultFilesTable createAlias(String alias) {
    return $FileVaultFilesTable(attachedDatabase, alias);
  }
}

class FileVaultFile extends DataClass implements Insertable<FileVaultFile> {
  /// 文件 UUID 主键
  final String id;

  /// 加密后的文件名（桌面端即为密文 base64）
  final String? name;
  final String? mime;
  final String? ext;
  final String? size;

  /// 密文文件磁盘路径（桌面端路径；移动端需把密文拷进沙盒并重写）
  final String? ciphertextPath;
  final String? createdAt;
  const FileVaultFile({
    required this.id,
    this.name,
    this.mime,
    this.ext,
    this.size,
    this.ciphertextPath,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    if (!nullToAbsent || ext != null) {
      map['ext'] = Variable<String>(ext);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<String>(size);
    }
    if (!nullToAbsent || ciphertextPath != null) {
      map['ciphertext_path'] = Variable<String>(ciphertextPath);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    return map;
  }

  FileVaultFilesCompanion toCompanion(bool nullToAbsent) {
    return FileVaultFilesCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      ext: ext == null && nullToAbsent ? const Value.absent() : Value(ext),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      ciphertextPath: ciphertextPath == null && nullToAbsent
          ? const Value.absent()
          : Value(ciphertextPath),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory FileVaultFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileVaultFile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      mime: serializer.fromJson<String?>(json['mime']),
      ext: serializer.fromJson<String?>(json['ext']),
      size: serializer.fromJson<String?>(json['size']),
      ciphertextPath: serializer.fromJson<String?>(json['ciphertextPath']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'mime': serializer.toJson<String?>(mime),
      'ext': serializer.toJson<String?>(ext),
      'size': serializer.toJson<String?>(size),
      'ciphertextPath': serializer.toJson<String?>(ciphertextPath),
      'createdAt': serializer.toJson<String?>(createdAt),
    };
  }

  FileVaultFile copyWith({
    String? id,
    Value<String?> name = const Value.absent(),
    Value<String?> mime = const Value.absent(),
    Value<String?> ext = const Value.absent(),
    Value<String?> size = const Value.absent(),
    Value<String?> ciphertextPath = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
  }) => FileVaultFile(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    mime: mime.present ? mime.value : this.mime,
    ext: ext.present ? ext.value : this.ext,
    size: size.present ? size.value : this.size,
    ciphertextPath: ciphertextPath.present
        ? ciphertextPath.value
        : this.ciphertextPath,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  FileVaultFile copyWithCompanion(FileVaultFilesCompanion data) {
    return FileVaultFile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      mime: data.mime.present ? data.mime.value : this.mime,
      ext: data.ext.present ? data.ext.value : this.ext,
      size: data.size.present ? data.size.value : this.size,
      ciphertextPath: data.ciphertextPath.present
          ? data.ciphertextPath.value
          : this.ciphertextPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileVaultFile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('ext: $ext, ')
          ..write('size: $size, ')
          ..write('ciphertextPath: $ciphertextPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, mime, ext, size, ciphertextPath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileVaultFile &&
          other.id == this.id &&
          other.name == this.name &&
          other.mime == this.mime &&
          other.ext == this.ext &&
          other.size == this.size &&
          other.ciphertextPath == this.ciphertextPath &&
          other.createdAt == this.createdAt);
}

class FileVaultFilesCompanion extends UpdateCompanion<FileVaultFile> {
  final Value<String> id;
  final Value<String?> name;
  final Value<String?> mime;
  final Value<String?> ext;
  final Value<String?> size;
  final Value<String?> ciphertextPath;
  final Value<String?> createdAt;
  final Value<int> rowid;
  const FileVaultFilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.mime = const Value.absent(),
    this.ext = const Value.absent(),
    this.size = const Value.absent(),
    this.ciphertextPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileVaultFilesCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.mime = const Value.absent(),
    this.ext = const Value.absent(),
    this.size = const Value.absent(),
    this.ciphertextPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<FileVaultFile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? mime,
    Expression<String>? ext,
    Expression<String>? size,
    Expression<String>? ciphertextPath,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (mime != null) 'mime': mime,
      if (ext != null) 'ext': ext,
      if (size != null) 'size': size,
      if (ciphertextPath != null) 'ciphertext_path': ciphertextPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileVaultFilesCompanion copyWith({
    Value<String>? id,
    Value<String?>? name,
    Value<String?>? mime,
    Value<String?>? ext,
    Value<String?>? size,
    Value<String?>? ciphertextPath,
    Value<String?>? createdAt,
    Value<int>? rowid,
  }) {
    return FileVaultFilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      ext: ext ?? this.ext,
      size: size ?? this.size,
      ciphertextPath: ciphertextPath ?? this.ciphertextPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (ciphertextPath.present) {
      map['ciphertext_path'] = Variable<String>(ciphertextPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileVaultFilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('ext: $ext, ')
          ..write('size: $size, ')
          ..write('ciphertextPath: $ciphertextPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EbookBookshelfTable extends EbookBookshelf
    with TableInfo<$EbookBookshelfTable, EbookBookshelfData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EbookBookshelfTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<double> percent = GeneratedColumn<double>(
    'percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<String> lastReadAt = GeneratedColumn<String>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<String> addedAt = GeneratedColumn<String>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    filePath,
    name,
    format,
    percent,
    lastReadAt,
    addedAt,
    title,
    author,
    cover,
    contentHash,
    id,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ebook_bookshelf';
  @override
  VerificationContext validateIntegrity(
    Insertable<EbookBookshelfData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  EbookBookshelfData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EbookBookshelfData(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent'],
      ),
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_read_at'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_at'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
    );
  }

  @override
  $EbookBookshelfTable createAlias(String alias) {
    return $EbookBookshelfTable(attachedDatabase, alias);
  }
}

class EbookBookshelfData extends DataClass
    implements Insertable<EbookBookshelfData> {
  /// 桌面端文件绝对路径（主键；移动端同步后需以 content_hash 重映射）
  final String filePath;
  final String? name;
  final String? format;

  /// 阅读进度百分比（桌面端 REAL）
  final double? percent;
  final String? lastReadAt;
  final String? addedAt;
  final String? title;
  final String? author;

  /// 封面（data URL 或路径）
  final String? cover;

  /// 文件内容哈希（跨端稳定映射键）
  final String? contentHash;

  /// 旧层遗留可空整型列
  final int? id;
  const EbookBookshelfData({
    required this.filePath,
    this.name,
    this.format,
    this.percent,
    this.lastReadAt,
    this.addedAt,
    this.title,
    this.author,
    this.cover,
    this.contentHash,
    this.id,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || percent != null) {
      map['percent'] = Variable<double>(percent);
    }
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<String>(lastReadAt);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<String>(addedAt);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    return map;
  }

  EbookBookshelfCompanion toCompanion(bool nullToAbsent) {
    return EbookBookshelfCompanion(
      filePath: Value(filePath),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      percent: percent == null && nullToAbsent
          ? const Value.absent()
          : Value(percent),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
    );
  }

  factory EbookBookshelfData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EbookBookshelfData(
      filePath: serializer.fromJson<String>(json['filePath']),
      name: serializer.fromJson<String?>(json['name']),
      format: serializer.fromJson<String?>(json['format']),
      percent: serializer.fromJson<double?>(json['percent']),
      lastReadAt: serializer.fromJson<String?>(json['lastReadAt']),
      addedAt: serializer.fromJson<String?>(json['addedAt']),
      title: serializer.fromJson<String?>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      cover: serializer.fromJson<String?>(json['cover']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      id: serializer.fromJson<int?>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'name': serializer.toJson<String?>(name),
      'format': serializer.toJson<String?>(format),
      'percent': serializer.toJson<double?>(percent),
      'lastReadAt': serializer.toJson<String?>(lastReadAt),
      'addedAt': serializer.toJson<String?>(addedAt),
      'title': serializer.toJson<String?>(title),
      'author': serializer.toJson<String?>(author),
      'cover': serializer.toJson<String?>(cover),
      'contentHash': serializer.toJson<String?>(contentHash),
      'id': serializer.toJson<int?>(id),
    };
  }

  EbookBookshelfData copyWith({
    String? filePath,
    Value<String?> name = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<double?> percent = const Value.absent(),
    Value<String?> lastReadAt = const Value.absent(),
    Value<String?> addedAt = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    Value<int?> id = const Value.absent(),
  }) => EbookBookshelfData(
    filePath: filePath ?? this.filePath,
    name: name.present ? name.value : this.name,
    format: format.present ? format.value : this.format,
    percent: percent.present ? percent.value : this.percent,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    title: title.present ? title.value : this.title,
    author: author.present ? author.value : this.author,
    cover: cover.present ? cover.value : this.cover,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    id: id.present ? id.value : this.id,
  );
  EbookBookshelfData copyWithCompanion(EbookBookshelfCompanion data) {
    return EbookBookshelfData(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      name: data.name.present ? data.name.value : this.name,
      format: data.format.present ? data.format.value : this.format,
      percent: data.percent.present ? data.percent.value : this.percent,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      cover: data.cover.present ? data.cover.value : this.cover,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EbookBookshelfData(')
          ..write('filePath: $filePath, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('percent: $percent, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('cover: $cover, ')
          ..write('contentHash: $contentHash, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    filePath,
    name,
    format,
    percent,
    lastReadAt,
    addedAt,
    title,
    author,
    cover,
    contentHash,
    id,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EbookBookshelfData &&
          other.filePath == this.filePath &&
          other.name == this.name &&
          other.format == this.format &&
          other.percent == this.percent &&
          other.lastReadAt == this.lastReadAt &&
          other.addedAt == this.addedAt &&
          other.title == this.title &&
          other.author == this.author &&
          other.cover == this.cover &&
          other.contentHash == this.contentHash &&
          other.id == this.id);
}

class EbookBookshelfCompanion extends UpdateCompanion<EbookBookshelfData> {
  final Value<String> filePath;
  final Value<String?> name;
  final Value<String?> format;
  final Value<double?> percent;
  final Value<String?> lastReadAt;
  final Value<String?> addedAt;
  final Value<String?> title;
  final Value<String?> author;
  final Value<String?> cover;
  final Value<String?> contentHash;
  final Value<int?> id;
  final Value<int> rowid;
  const EbookBookshelfCompanion({
    this.filePath = const Value.absent(),
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.percent = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.cover = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EbookBookshelfCompanion.insert({
    required String filePath,
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.percent = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.cover = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath);
  static Insertable<EbookBookshelfData> custom({
    Expression<String>? filePath,
    Expression<String>? name,
    Expression<String>? format,
    Expression<double>? percent,
    Expression<String>? lastReadAt,
    Expression<String>? addedAt,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? cover,
    Expression<String>? contentHash,
    Expression<int>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (name != null) 'name': name,
      if (format != null) 'format': format,
      if (percent != null) 'percent': percent,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (addedAt != null) 'added_at': addedAt,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (cover != null) 'cover': cover,
      if (contentHash != null) 'content_hash': contentHash,
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EbookBookshelfCompanion copyWith({
    Value<String>? filePath,
    Value<String?>? name,
    Value<String?>? format,
    Value<double?>? percent,
    Value<String?>? lastReadAt,
    Value<String?>? addedAt,
    Value<String?>? title,
    Value<String?>? author,
    Value<String?>? cover,
    Value<String?>? contentHash,
    Value<int?>? id,
    Value<int>? rowid,
  }) {
    return EbookBookshelfCompanion(
      filePath: filePath ?? this.filePath,
      name: name ?? this.name,
      format: format ?? this.format,
      percent: percent ?? this.percent,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      addedAt: addedAt ?? this.addedAt,
      title: title ?? this.title,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      contentHash: contentHash ?? this.contentHash,
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (percent.present) {
      map['percent'] = Variable<double>(percent.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<String>(lastReadAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<String>(addedAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EbookBookshelfCompanion(')
          ..write('filePath: $filePath, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('percent: $percent, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('cover: $cover, ')
          ..write('contentHash: $contentHash, ')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EbookProgressTable extends EbookProgress
    with TableInfo<$EbookProgressTable, EbookProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EbookProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cfiMeta = const VerificationMeta('cfi');
  @override
  late final GeneratedColumn<String> cfi = GeneratedColumn<String>(
    'cfi',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<double> percent = GeneratedColumn<double>(
    'percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    filePath,
    format,
    cfi,
    percent,
    updatedAt,
    contentHash,
    id,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ebook_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<EbookProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('cfi')) {
      context.handle(
        _cfiMeta,
        cfi.isAcceptableOrUnknown(data['cfi']!, _cfiMeta),
      );
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  EbookProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EbookProgressData(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      cfi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cfi'],
      ),
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
    );
  }

  @override
  $EbookProgressTable createAlias(String alias) {
    return $EbookProgressTable(attachedDatabase, alias);
  }
}

class EbookProgressData extends DataClass
    implements Insertable<EbookProgressData> {
  final String filePath;
  final String? format;

  /// epub CFI 定位串
  final String? cfi;

  /// 阅读进度百分比（桌面端 REAL）
  final double? percent;
  final String? updatedAt;
  final String? contentHash;
  final int? id;
  const EbookProgressData({
    required this.filePath,
    this.format,
    this.cfi,
    this.percent,
    this.updatedAt,
    this.contentHash,
    this.id,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || cfi != null) {
      map['cfi'] = Variable<String>(cfi);
    }
    if (!nullToAbsent || percent != null) {
      map['percent'] = Variable<double>(percent);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    return map;
  }

  EbookProgressCompanion toCompanion(bool nullToAbsent) {
    return EbookProgressCompanion(
      filePath: Value(filePath),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      cfi: cfi == null && nullToAbsent ? const Value.absent() : Value(cfi),
      percent: percent == null && nullToAbsent
          ? const Value.absent()
          : Value(percent),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
    );
  }

  factory EbookProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EbookProgressData(
      filePath: serializer.fromJson<String>(json['filePath']),
      format: serializer.fromJson<String?>(json['format']),
      cfi: serializer.fromJson<String?>(json['cfi']),
      percent: serializer.fromJson<double?>(json['percent']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      id: serializer.fromJson<int?>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'format': serializer.toJson<String?>(format),
      'cfi': serializer.toJson<String?>(cfi),
      'percent': serializer.toJson<double?>(percent),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'contentHash': serializer.toJson<String?>(contentHash),
      'id': serializer.toJson<int?>(id),
    };
  }

  EbookProgressData copyWith({
    String? filePath,
    Value<String?> format = const Value.absent(),
    Value<String?> cfi = const Value.absent(),
    Value<double?> percent = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    Value<int?> id = const Value.absent(),
  }) => EbookProgressData(
    filePath: filePath ?? this.filePath,
    format: format.present ? format.value : this.format,
    cfi: cfi.present ? cfi.value : this.cfi,
    percent: percent.present ? percent.value : this.percent,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    id: id.present ? id.value : this.id,
  );
  EbookProgressData copyWithCompanion(EbookProgressCompanion data) {
    return EbookProgressData(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      format: data.format.present ? data.format.value : this.format,
      cfi: data.cfi.present ? data.cfi.value : this.cfi,
      percent: data.percent.present ? data.percent.value : this.percent,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EbookProgressData(')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('cfi: $cfi, ')
          ..write('percent: $percent, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(filePath, format, cfi, percent, updatedAt, contentHash, id);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EbookProgressData &&
          other.filePath == this.filePath &&
          other.format == this.format &&
          other.cfi == this.cfi &&
          other.percent == this.percent &&
          other.updatedAt == this.updatedAt &&
          other.contentHash == this.contentHash &&
          other.id == this.id);
}

class EbookProgressCompanion extends UpdateCompanion<EbookProgressData> {
  final Value<String> filePath;
  final Value<String?> format;
  final Value<String?> cfi;
  final Value<double?> percent;
  final Value<String?> updatedAt;
  final Value<String?> contentHash;
  final Value<int?> id;
  final Value<int> rowid;
  const EbookProgressCompanion({
    this.filePath = const Value.absent(),
    this.format = const Value.absent(),
    this.cfi = const Value.absent(),
    this.percent = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EbookProgressCompanion.insert({
    required String filePath,
    this.format = const Value.absent(),
    this.cfi = const Value.absent(),
    this.percent = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath);
  static Insertable<EbookProgressData> custom({
    Expression<String>? filePath,
    Expression<String>? format,
    Expression<String>? cfi,
    Expression<double>? percent,
    Expression<String>? updatedAt,
    Expression<String>? contentHash,
    Expression<int>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (format != null) 'format': format,
      if (cfi != null) 'cfi': cfi,
      if (percent != null) 'percent': percent,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (contentHash != null) 'content_hash': contentHash,
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EbookProgressCompanion copyWith({
    Value<String>? filePath,
    Value<String?>? format,
    Value<String?>? cfi,
    Value<double?>? percent,
    Value<String?>? updatedAt,
    Value<String?>? contentHash,
    Value<int?>? id,
    Value<int>? rowid,
  }) {
    return EbookProgressCompanion(
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      cfi: cfi ?? this.cfi,
      percent: percent ?? this.percent,
      updatedAt: updatedAt ?? this.updatedAt,
      contentHash: contentHash ?? this.contentHash,
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (cfi.present) {
      map['cfi'] = Variable<String>(cfi.value);
    }
    if (percent.present) {
      map['percent'] = Variable<double>(percent.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EbookProgressCompanion(')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('cfi: $cfi, ')
          ..write('percent: $percent, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EbookBookmarkTable extends EbookBookmark
    with TableInfo<$EbookBookmarkTable, EbookBookmarkData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EbookBookmarkTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cfiMeta = const VerificationMeta('cfi');
  @override
  late final GeneratedColumn<String> cfi = GeneratedColumn<String>(
    'cfi',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<String> percent = GeneratedColumn<String>(
    'percent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filePath,
    format,
    cfi,
    label,
    percent,
    createdAt,
    contentHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ebook_bookmark';
  @override
  VerificationContext validateIntegrity(
    Insertable<EbookBookmarkData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('cfi')) {
      context.handle(
        _cfiMeta,
        cfi.isAcceptableOrUnknown(data['cfi']!, _cfiMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EbookBookmarkData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EbookBookmarkData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      cfi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cfi'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}percent'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
    );
  }

  @override
  $EbookBookmarkTable createAlias(String alias) {
    return $EbookBookmarkTable(attachedDatabase, alias);
  }
}

class EbookBookmarkData extends DataClass
    implements Insertable<EbookBookmarkData> {
  final int id;
  final String? filePath;
  final String? format;
  final String? cfi;
  final String? label;
  final String? percent;
  final String? createdAt;
  final String? contentHash;
  const EbookBookmarkData({
    required this.id,
    this.filePath,
    this.format,
    this.cfi,
    this.label,
    this.percent,
    this.createdAt,
    this.contentHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || cfi != null) {
      map['cfi'] = Variable<String>(cfi);
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || percent != null) {
      map['percent'] = Variable<String>(percent);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    return map;
  }

  EbookBookmarkCompanion toCompanion(bool nullToAbsent) {
    return EbookBookmarkCompanion(
      id: Value(id),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      cfi: cfi == null && nullToAbsent ? const Value.absent() : Value(cfi),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      percent: percent == null && nullToAbsent
          ? const Value.absent()
          : Value(percent),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
    );
  }

  factory EbookBookmarkData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EbookBookmarkData(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      format: serializer.fromJson<String?>(json['format']),
      cfi: serializer.fromJson<String?>(json['cfi']),
      label: serializer.fromJson<String?>(json['label']),
      percent: serializer.fromJson<String?>(json['percent']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String?>(filePath),
      'format': serializer.toJson<String?>(format),
      'cfi': serializer.toJson<String?>(cfi),
      'label': serializer.toJson<String?>(label),
      'percent': serializer.toJson<String?>(percent),
      'createdAt': serializer.toJson<String?>(createdAt),
      'contentHash': serializer.toJson<String?>(contentHash),
    };
  }

  EbookBookmarkData copyWith({
    int? id,
    Value<String?> filePath = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<String?> cfi = const Value.absent(),
    Value<String?> label = const Value.absent(),
    Value<String?> percent = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
  }) => EbookBookmarkData(
    id: id ?? this.id,
    filePath: filePath.present ? filePath.value : this.filePath,
    format: format.present ? format.value : this.format,
    cfi: cfi.present ? cfi.value : this.cfi,
    label: label.present ? label.value : this.label,
    percent: percent.present ? percent.value : this.percent,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
  );
  EbookBookmarkData copyWithCompanion(EbookBookmarkCompanion data) {
    return EbookBookmarkData(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      format: data.format.present ? data.format.value : this.format,
      cfi: data.cfi.present ? data.cfi.value : this.cfi,
      label: data.label.present ? data.label.value : this.label,
      percent: data.percent.present ? data.percent.value : this.percent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EbookBookmarkData(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('cfi: $cfi, ')
          ..write('label: $label, ')
          ..write('percent: $percent, ')
          ..write('createdAt: $createdAt, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filePath,
    format,
    cfi,
    label,
    percent,
    createdAt,
    contentHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EbookBookmarkData &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.format == this.format &&
          other.cfi == this.cfi &&
          other.label == this.label &&
          other.percent == this.percent &&
          other.createdAt == this.createdAt &&
          other.contentHash == this.contentHash);
}

class EbookBookmarkCompanion extends UpdateCompanion<EbookBookmarkData> {
  final Value<int> id;
  final Value<String?> filePath;
  final Value<String?> format;
  final Value<String?> cfi;
  final Value<String?> label;
  final Value<String?> percent;
  final Value<String?> createdAt;
  final Value<String?> contentHash;
  const EbookBookmarkCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.format = const Value.absent(),
    this.cfi = const Value.absent(),
    this.label = const Value.absent(),
    this.percent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.contentHash = const Value.absent(),
  });
  EbookBookmarkCompanion.insert({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.format = const Value.absent(),
    this.cfi = const Value.absent(),
    this.label = const Value.absent(),
    this.percent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.contentHash = const Value.absent(),
  });
  static Insertable<EbookBookmarkData> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? format,
    Expression<String>? cfi,
    Expression<String>? label,
    Expression<String>? percent,
    Expression<String>? createdAt,
    Expression<String>? contentHash,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (format != null) 'format': format,
      if (cfi != null) 'cfi': cfi,
      if (label != null) 'label': label,
      if (percent != null) 'percent': percent,
      if (createdAt != null) 'created_at': createdAt,
      if (contentHash != null) 'content_hash': contentHash,
    });
  }

  EbookBookmarkCompanion copyWith({
    Value<int>? id,
    Value<String?>? filePath,
    Value<String?>? format,
    Value<String?>? cfi,
    Value<String?>? label,
    Value<String?>? percent,
    Value<String?>? createdAt,
    Value<String?>? contentHash,
  }) {
    return EbookBookmarkCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      cfi: cfi ?? this.cfi,
      label: label ?? this.label,
      percent: percent ?? this.percent,
      createdAt: createdAt ?? this.createdAt,
      contentHash: contentHash ?? this.contentHash,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (cfi.present) {
      map['cfi'] = Variable<String>(cfi.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (percent.present) {
      map['percent'] = Variable<String>(percent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EbookBookmarkCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('cfi: $cfi, ')
          ..write('label: $label, ')
          ..write('percent: $percent, ')
          ..write('createdAt: $createdAt, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }
}

class $EbookAnnotationTable extends EbookAnnotation
    with TableInfo<$EbookAnnotationTable, EbookAnnotationData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EbookAnnotationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anchorMeta = const VerificationMeta('anchor');
  @override
  late final GeneratedColumn<String> anchor = GeneratedColumn<String>(
    'anchor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotatedTextMeta = const VerificationMeta(
    'annotatedText',
  );
  @override
  late final GeneratedColumn<String> annotatedText = GeneratedColumn<String>(
    'text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filePath,
    format,
    anchor,
    annotatedText,
    note,
    color,
    createdAt,
    updatedAt,
    type,
    contentHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ebook_annotation';
  @override
  VerificationContext validateIntegrity(
    Insertable<EbookAnnotationData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('anchor')) {
      context.handle(
        _anchorMeta,
        anchor.isAcceptableOrUnknown(data['anchor']!, _anchorMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _annotatedTextMeta,
        annotatedText.isAcceptableOrUnknown(data['text']!, _annotatedTextMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EbookAnnotationData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EbookAnnotationData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      anchor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor'],
      ),
      annotatedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
    );
  }

  @override
  $EbookAnnotationTable createAlias(String alias) {
    return $EbookAnnotationTable(attachedDatabase, alias);
  }
}

class EbookAnnotationData extends DataClass
    implements Insertable<EbookAnnotationData> {
  final int id;
  final String? filePath;
  final String? format;

  /// 定位锚点（epub CFI / pdf 坐标串）
  final String? anchor;

  /// 选中原文
  /// ⚠️ getter 不能叫 text（与 drift Table.text() 构造方法冲突），
  ///    改名 annotatedText 并用 named('text') 锁定桌面列名。
  final String? annotatedText;

  /// 批注内容
  final String? note;

  /// 标注颜色（桌面端默认 'yellow'）
  final String? color;
  final String? createdAt;
  final String? updatedAt;

  /// 类型，如 markStrong
  final String? type;
  final String? contentHash;
  const EbookAnnotationData({
    required this.id,
    this.filePath,
    this.format,
    this.anchor,
    this.annotatedText,
    this.note,
    this.color,
    this.createdAt,
    this.updatedAt,
    this.type,
    this.contentHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || anchor != null) {
      map['anchor'] = Variable<String>(anchor);
    }
    if (!nullToAbsent || annotatedText != null) {
      map['text'] = Variable<String>(annotatedText);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    return map;
  }

  EbookAnnotationCompanion toCompanion(bool nullToAbsent) {
    return EbookAnnotationCompanion(
      id: Value(id),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      anchor: anchor == null && nullToAbsent
          ? const Value.absent()
          : Value(anchor),
      annotatedText: annotatedText == null && nullToAbsent
          ? const Value.absent()
          : Value(annotatedText),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
    );
  }

  factory EbookAnnotationData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EbookAnnotationData(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      format: serializer.fromJson<String?>(json['format']),
      anchor: serializer.fromJson<String?>(json['anchor']),
      annotatedText: serializer.fromJson<String?>(json['annotatedText']),
      note: serializer.fromJson<String?>(json['note']),
      color: serializer.fromJson<String?>(json['color']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      type: serializer.fromJson<String?>(json['type']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String?>(filePath),
      'format': serializer.toJson<String?>(format),
      'anchor': serializer.toJson<String?>(anchor),
      'annotatedText': serializer.toJson<String?>(annotatedText),
      'note': serializer.toJson<String?>(note),
      'color': serializer.toJson<String?>(color),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'type': serializer.toJson<String?>(type),
      'contentHash': serializer.toJson<String?>(contentHash),
    };
  }

  EbookAnnotationData copyWith({
    int? id,
    Value<String?> filePath = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<String?> anchor = const Value.absent(),
    Value<String?> annotatedText = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
  }) => EbookAnnotationData(
    id: id ?? this.id,
    filePath: filePath.present ? filePath.value : this.filePath,
    format: format.present ? format.value : this.format,
    anchor: anchor.present ? anchor.value : this.anchor,
    annotatedText: annotatedText.present
        ? annotatedText.value
        : this.annotatedText,
    note: note.present ? note.value : this.note,
    color: color.present ? color.value : this.color,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    type: type.present ? type.value : this.type,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
  );
  EbookAnnotationData copyWithCompanion(EbookAnnotationCompanion data) {
    return EbookAnnotationData(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      format: data.format.present ? data.format.value : this.format,
      anchor: data.anchor.present ? data.anchor.value : this.anchor,
      annotatedText: data.annotatedText.present
          ? data.annotatedText.value
          : this.annotatedText,
      note: data.note.present ? data.note.value : this.note,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      type: data.type.present ? data.type.value : this.type,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EbookAnnotationData(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('anchor: $anchor, ')
          ..write('annotatedText: $annotatedText, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('type: $type, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filePath,
    format,
    anchor,
    annotatedText,
    note,
    color,
    createdAt,
    updatedAt,
    type,
    contentHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EbookAnnotationData &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.format == this.format &&
          other.anchor == this.anchor &&
          other.annotatedText == this.annotatedText &&
          other.note == this.note &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.type == this.type &&
          other.contentHash == this.contentHash);
}

class EbookAnnotationCompanion extends UpdateCompanion<EbookAnnotationData> {
  final Value<int> id;
  final Value<String?> filePath;
  final Value<String?> format;
  final Value<String?> anchor;
  final Value<String?> annotatedText;
  final Value<String?> note;
  final Value<String?> color;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> type;
  final Value<String?> contentHash;
  const EbookAnnotationCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.format = const Value.absent(),
    this.anchor = const Value.absent(),
    this.annotatedText = const Value.absent(),
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.type = const Value.absent(),
    this.contentHash = const Value.absent(),
  });
  EbookAnnotationCompanion.insert({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.format = const Value.absent(),
    this.anchor = const Value.absent(),
    this.annotatedText = const Value.absent(),
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.type = const Value.absent(),
    this.contentHash = const Value.absent(),
  });
  static Insertable<EbookAnnotationData> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? format,
    Expression<String>? anchor,
    Expression<String>? annotatedText,
    Expression<String>? note,
    Expression<String>? color,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? type,
    Expression<String>? contentHash,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (format != null) 'format': format,
      if (anchor != null) 'anchor': anchor,
      if (annotatedText != null) 'text': annotatedText,
      if (note != null) 'note': note,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (type != null) 'type': type,
      if (contentHash != null) 'content_hash': contentHash,
    });
  }

  EbookAnnotationCompanion copyWith({
    Value<int>? id,
    Value<String?>? filePath,
    Value<String?>? format,
    Value<String?>? anchor,
    Value<String?>? annotatedText,
    Value<String?>? note,
    Value<String?>? color,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? type,
    Value<String?>? contentHash,
  }) {
    return EbookAnnotationCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      anchor: anchor ?? this.anchor,
      annotatedText: annotatedText ?? this.annotatedText,
      note: note ?? this.note,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      contentHash: contentHash ?? this.contentHash,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (anchor.present) {
      map['anchor'] = Variable<String>(anchor.value);
    }
    if (annotatedText.present) {
      map['text'] = Variable<String>(annotatedText.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EbookAnnotationCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('anchor: $anchor, ')
          ..write('annotatedText: $annotatedText, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('type: $type, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }
}

class $EbookCategoryTable extends EbookCategory
    with TableInfo<$EbookCategoryTable, EbookCategoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EbookCategoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ebook_category';
  @override
  VerificationContext validateIntegrity(
    Insertable<EbookCategoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EbookCategoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EbookCategoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
    );
  }

  @override
  $EbookCategoryTable createAlias(String alias) {
    return $EbookCategoryTable(attachedDatabase, alias);
  }
}

class EbookCategoryData extends DataClass
    implements Insertable<EbookCategoryData> {
  final int id;
  final String name;
  final String? createdAt;
  final String? color;
  const EbookCategoryData({
    required this.id,
    required this.name,
    this.createdAt,
    this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    return map;
  }

  EbookCategoryCompanion toCompanion(bool nullToAbsent) {
    return EbookCategoryCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
    );
  }

  factory EbookCategoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EbookCategoryData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      color: serializer.fromJson<String?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<String?>(createdAt),
      'color': serializer.toJson<String?>(color),
    };
  }

  EbookCategoryData copyWith({
    int? id,
    String? name,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> color = const Value.absent(),
  }) => EbookCategoryData(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    color: color.present ? color.value : this.color,
  );
  EbookCategoryData copyWithCompanion(EbookCategoryCompanion data) {
    return EbookCategoryData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EbookCategoryData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EbookCategoryData &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.color == this.color);
}

class EbookCategoryCompanion extends UpdateCompanion<EbookCategoryData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> createdAt;
  final Value<String?> color;
  const EbookCategoryCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.color = const Value.absent(),
  });
  EbookCategoryCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
    this.color = const Value.absent(),
  }) : name = Value(name);
  static Insertable<EbookCategoryData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? createdAt,
    Expression<String>? color,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (color != null) 'color': color,
    });
  }

  EbookCategoryCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? createdAt,
    Value<String?>? color,
  }) {
    return EbookCategoryCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EbookCategoryCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }
}

class $EbookBookCategoryTable extends EbookBookCategory
    with TableInfo<$EbookBookCategoryTable, EbookBookCategoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EbookBookCategoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookPathMeta = const VerificationMeta(
    'bookPath',
  );
  @override
  late final GeneratedColumn<String> bookPath = GeneratedColumn<String>(
    'book_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [bookPath, categoryId, id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ebook_book_category';
  @override
  VerificationContext validateIntegrity(
    Insertable<EbookBookCategoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_path')) {
      context.handle(
        _bookPathMeta,
        bookPath.isAcceptableOrUnknown(data['book_path']!, _bookPathMeta),
      );
    } else if (isInserting) {
      context.missing(_bookPathMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookPath, categoryId};
  @override
  EbookBookCategoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EbookBookCategoryData(
      bookPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_path'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
    );
  }

  @override
  $EbookBookCategoryTable createAlias(String alias) {
    return $EbookBookCategoryTable(attachedDatabase, alias);
  }
}

class EbookBookCategoryData extends DataClass
    implements Insertable<EbookBookCategoryData> {
  final String bookPath;
  final int categoryId;

  /// 旧层遗留可空整型列
  final int? id;
  const EbookBookCategoryData({
    required this.bookPath,
    required this.categoryId,
    this.id,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_path'] = Variable<String>(bookPath);
    map['category_id'] = Variable<int>(categoryId);
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    return map;
  }

  EbookBookCategoryCompanion toCompanion(bool nullToAbsent) {
    return EbookBookCategoryCompanion(
      bookPath: Value(bookPath),
      categoryId: Value(categoryId),
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
    );
  }

  factory EbookBookCategoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EbookBookCategoryData(
      bookPath: serializer.fromJson<String>(json['bookPath']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      id: serializer.fromJson<int?>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookPath': serializer.toJson<String>(bookPath),
      'categoryId': serializer.toJson<int>(categoryId),
      'id': serializer.toJson<int?>(id),
    };
  }

  EbookBookCategoryData copyWith({
    String? bookPath,
    int? categoryId,
    Value<int?> id = const Value.absent(),
  }) => EbookBookCategoryData(
    bookPath: bookPath ?? this.bookPath,
    categoryId: categoryId ?? this.categoryId,
    id: id.present ? id.value : this.id,
  );
  EbookBookCategoryData copyWithCompanion(EbookBookCategoryCompanion data) {
    return EbookBookCategoryData(
      bookPath: data.bookPath.present ? data.bookPath.value : this.bookPath,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EbookBookCategoryData(')
          ..write('bookPath: $bookPath, ')
          ..write('categoryId: $categoryId, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookPath, categoryId, id);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EbookBookCategoryData &&
          other.bookPath == this.bookPath &&
          other.categoryId == this.categoryId &&
          other.id == this.id);
}

class EbookBookCategoryCompanion
    extends UpdateCompanion<EbookBookCategoryData> {
  final Value<String> bookPath;
  final Value<int> categoryId;
  final Value<int?> id;
  final Value<int> rowid;
  const EbookBookCategoryCompanion({
    this.bookPath = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EbookBookCategoryCompanion.insert({
    required String bookPath,
    required int categoryId,
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookPath = Value(bookPath),
       categoryId = Value(categoryId);
  static Insertable<EbookBookCategoryData> custom({
    Expression<String>? bookPath,
    Expression<int>? categoryId,
    Expression<int>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookPath != null) 'book_path': bookPath,
      if (categoryId != null) 'category_id': categoryId,
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EbookBookCategoryCompanion copyWith({
    Value<String>? bookPath,
    Value<int>? categoryId,
    Value<int?>? id,
    Value<int>? rowid,
  }) {
    return EbookBookCategoryCompanion(
      bookPath: bookPath ?? this.bookPath,
      categoryId: categoryId ?? this.categoryId,
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookPath.present) {
      map['book_path'] = Variable<String>(bookPath.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EbookBookCategoryCompanion(')
          ..write('bookPath: $bookPath, ')
          ..write('categoryId: $categoryId, ')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EbookBgImageTable extends EbookBgImage
    with TableInfo<$EbookBgImageTable, EbookBgImageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EbookBgImageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _dataUrlMeta = const VerificationMeta(
    'dataUrl',
  );
  @override
  late final GeneratedColumn<String> dataUrl = GeneratedColumn<String>(
    'data_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, imagePath, dataUrl, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ebook_bg_image';
  @override
  VerificationContext validateIntegrity(
    Insertable<EbookBgImageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('data_url')) {
      context.handle(
        _dataUrlMeta,
        dataUrl.isAcceptableOrUnknown(data['data_url']!, _dataUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EbookBgImageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EbookBgImageData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      dataUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $EbookBgImageTable createAlias(String alias) {
    return $EbookBgImageTable(attachedDatabase, alias);
  }
}

class EbookBgImageData extends DataClass
    implements Insertable<EbookBgImageData> {
  final int id;
  final String imagePath;
  final String? dataUrl;
  final String? createdAt;
  const EbookBgImageData({
    required this.id,
    required this.imagePath,
    this.dataUrl,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || dataUrl != null) {
      map['data_url'] = Variable<String>(dataUrl);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    return map;
  }

  EbookBgImageCompanion toCompanion(bool nullToAbsent) {
    return EbookBgImageCompanion(
      id: Value(id),
      imagePath: Value(imagePath),
      dataUrl: dataUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(dataUrl),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory EbookBgImageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EbookBgImageData(
      id: serializer.fromJson<int>(json['id']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      dataUrl: serializer.fromJson<String?>(json['dataUrl']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'imagePath': serializer.toJson<String>(imagePath),
      'dataUrl': serializer.toJson<String?>(dataUrl),
      'createdAt': serializer.toJson<String?>(createdAt),
    };
  }

  EbookBgImageData copyWith({
    int? id,
    String? imagePath,
    Value<String?> dataUrl = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
  }) => EbookBgImageData(
    id: id ?? this.id,
    imagePath: imagePath ?? this.imagePath,
    dataUrl: dataUrl.present ? dataUrl.value : this.dataUrl,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  EbookBgImageData copyWithCompanion(EbookBgImageCompanion data) {
    return EbookBgImageData(
      id: data.id.present ? data.id.value : this.id,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      dataUrl: data.dataUrl.present ? data.dataUrl.value : this.dataUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EbookBgImageData(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('dataUrl: $dataUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, imagePath, dataUrl, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EbookBgImageData &&
          other.id == this.id &&
          other.imagePath == this.imagePath &&
          other.dataUrl == this.dataUrl &&
          other.createdAt == this.createdAt);
}

class EbookBgImageCompanion extends UpdateCompanion<EbookBgImageData> {
  final Value<int> id;
  final Value<String> imagePath;
  final Value<String?> dataUrl;
  final Value<String?> createdAt;
  const EbookBgImageCompanion({
    this.id = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.dataUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EbookBgImageCompanion.insert({
    this.id = const Value.absent(),
    required String imagePath,
    this.dataUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : imagePath = Value(imagePath);
  static Insertable<EbookBgImageData> custom({
    Expression<int>? id,
    Expression<String>? imagePath,
    Expression<String>? dataUrl,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imagePath != null) 'image_path': imagePath,
      if (dataUrl != null) 'data_url': dataUrl,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EbookBgImageCompanion copyWith({
    Value<int>? id,
    Value<String>? imagePath,
    Value<String?>? dataUrl,
    Value<String?>? createdAt,
  }) {
    return EbookBgImageCompanion(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      dataUrl: dataUrl ?? this.dataUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (dataUrl.present) {
      map['data_url'] = Variable<String>(dataUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EbookBgImageCompanion(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('dataUrl: $dataUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ScreenshotsTable extends Screenshots
    with TableInfo<$ScreenshotsTable, Screenshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScreenshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<String> width = GeneratedColumn<String>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<String> height = GeneratedColumn<String>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stickerStatusMeta = const VerificationMeta(
    'stickerStatus',
  );
  @override
  late final GeneratedColumn<String> stickerStatus = GeneratedColumn<String>(
    'sticker_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    value,
    createdAt,
    path,
    action,
    width,
    height,
    stickerStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'screenshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Screenshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('sticker_status')) {
      context.handle(
        _stickerStatusMeta,
        stickerStatus.isAcceptableOrUnknown(
          data['sticker_status']!,
          _stickerStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Screenshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Screenshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}height'],
      ),
      stickerStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sticker_status'],
      ),
    );
  }

  @override
  $ScreenshotsTable createAlias(String alias) {
    return $ScreenshotsTable(attachedDatabase, alias);
  }
}

class Screenshot extends DataClass implements Insertable<Screenshot> {
  final int id;
  final String? name;
  final String? value;
  final String? createdAt;

  /// 图片路径（桌面端为系统路径；移动端为沙盒内路径）
  final String? path;

  /// 动作，如 save
  final String? action;
  final String? width;
  final String? height;

  /// 贴纸处理状态
  final String? stickerStatus;
  const Screenshot({
    required this.id,
    this.name,
    this.value,
    this.createdAt,
    this.path,
    this.action,
    this.width,
    this.height,
    this.stickerStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || action != null) {
      map['action'] = Variable<String>(action);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<String>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<String>(height);
    }
    if (!nullToAbsent || stickerStatus != null) {
      map['sticker_status'] = Variable<String>(stickerStatus);
    }
    return map;
  }

  ScreenshotsCompanion toCompanion(bool nullToAbsent) {
    return ScreenshotsCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      action: action == null && nullToAbsent
          ? const Value.absent()
          : Value(action),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      stickerStatus: stickerStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(stickerStatus),
    );
  }

  factory Screenshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Screenshot(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      value: serializer.fromJson<String?>(json['value']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      path: serializer.fromJson<String?>(json['path']),
      action: serializer.fromJson<String?>(json['action']),
      width: serializer.fromJson<String?>(json['width']),
      height: serializer.fromJson<String?>(json['height']),
      stickerStatus: serializer.fromJson<String?>(json['stickerStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'value': serializer.toJson<String?>(value),
      'createdAt': serializer.toJson<String?>(createdAt),
      'path': serializer.toJson<String?>(path),
      'action': serializer.toJson<String?>(action),
      'width': serializer.toJson<String?>(width),
      'height': serializer.toJson<String?>(height),
      'stickerStatus': serializer.toJson<String?>(stickerStatus),
    };
  }

  Screenshot copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> path = const Value.absent(),
    Value<String?> action = const Value.absent(),
    Value<String?> width = const Value.absent(),
    Value<String?> height = const Value.absent(),
    Value<String?> stickerStatus = const Value.absent(),
  }) => Screenshot(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    value: value.present ? value.value : this.value,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    path: path.present ? path.value : this.path,
    action: action.present ? action.value : this.action,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    stickerStatus: stickerStatus.present
        ? stickerStatus.value
        : this.stickerStatus,
  );
  Screenshot copyWithCompanion(ScreenshotsCompanion data) {
    return Screenshot(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      path: data.path.present ? data.path.value : this.path,
      action: data.action.present ? data.action.value : this.action,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      stickerStatus: data.stickerStatus.present
          ? data.stickerStatus.value
          : this.stickerStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Screenshot(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('path: $path, ')
          ..write('action: $action, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('stickerStatus: $stickerStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    value,
    createdAt,
    path,
    action,
    width,
    height,
    stickerStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Screenshot &&
          other.id == this.id &&
          other.name == this.name &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.path == this.path &&
          other.action == this.action &&
          other.width == this.width &&
          other.height == this.height &&
          other.stickerStatus == this.stickerStatus);
}

class ScreenshotsCompanion extends UpdateCompanion<Screenshot> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String?> value;
  final Value<String?> createdAt;
  final Value<String?> path;
  final Value<String?> action;
  final Value<String?> width;
  final Value<String?> height;
  final Value<String?> stickerStatus;
  const ScreenshotsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.path = const Value.absent(),
    this.action = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.stickerStatus = const Value.absent(),
  });
  ScreenshotsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.path = const Value.absent(),
    this.action = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.stickerStatus = const Value.absent(),
  });
  static Insertable<Screenshot> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? createdAt,
    Expression<String>? path,
    Expression<String>? action,
    Expression<String>? width,
    Expression<String>? height,
    Expression<String>? stickerStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (path != null) 'path': path,
      if (action != null) 'action': action,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (stickerStatus != null) 'sticker_status': stickerStatus,
    });
  }

  ScreenshotsCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String?>? value,
    Value<String?>? createdAt,
    Value<String?>? path,
    Value<String?>? action,
    Value<String?>? width,
    Value<String?>? height,
    Value<String?>? stickerStatus,
  }) {
    return ScreenshotsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      path: path ?? this.path,
      action: action ?? this.action,
      width: width ?? this.width,
      height: height ?? this.height,
      stickerStatus: stickerStatus ?? this.stickerStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (width.present) {
      map['width'] = Variable<String>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<String>(height.value);
    }
    if (stickerStatus.present) {
      map['sticker_status'] = Variable<String>(stickerStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScreenshotsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('path: $path, ')
          ..write('action: $action, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('stickerStatus: $stickerStatus')
          ..write(')'))
        .toString();
  }
}

class $CountdownTable extends Countdown
    with TableInfo<$CountdownTable, CountdownData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountdownTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<int> endTime = GeneratedColumn<int>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedRemainingMeta = const VerificationMeta(
    'pausedRemaining',
  );
  @override
  late final GeneratedColumn<int> pausedRemaining = GeneratedColumn<int>(
    'paused_remaining',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notifyMeta = const VerificationMeta('notify');
  @override
  late final GeneratedColumn<String> notify = GeneratedColumn<String>(
    'notify',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soundMeta = const VerificationMeta('sound');
  @override
  late final GeneratedColumn<String> sound = GeneratedColumn<String>(
    'sound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    name,
    mode,
    endTime,
    duration,
    pausedRemaining,
    status,
    notify,
    sound,
    color,
    createdAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'countdown';
  @override
  VerificationContext validateIntegrity(
    Insertable<CountdownData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('paused_remaining')) {
      context.handle(
        _pausedRemainingMeta,
        pausedRemaining.isAcceptableOrUnknown(
          data['paused_remaining']!,
          _pausedRemainingMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notify')) {
      context.handle(
        _notifyMeta,
        notify.isAcceptableOrUnknown(data['notify']!, _notifyMeta),
      );
    }
    if (data.containsKey('sound')) {
      context.handle(
        _soundMeta,
        sound.isAcceptableOrUnknown(data['sound']!, _soundMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CountdownData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CountdownData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      pausedRemaining: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_remaining'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      notify: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notify'],
      ),
      sound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sound'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $CountdownTable createAlias(String alias) {
    return $CountdownTable(attachedDatabase, alias);
  }
}

class CountdownData extends DataClass implements Insertable<CountdownData> {
  final String key;

  /// 名称
  final String? name;

  /// datetime（指定时刻）/ duration（指定时长）
  final String? mode;

  /// 目标结束时间戳(ms) —— 计时基准
  final int? endTime;

  /// 原始时长(ms)，用于「重置」
  final int? duration;

  /// 暂停时冻结的剩余(ms)
  final int? pausedRemaining;

  /// running / paused / finished
  final String? status;

  /// 是否完成通知：0/1
  final String? notify;

  /// 提示音（桌面端预留字段）
  final String? sound;

  /// 卡片/进度环颜色
  final String? color;
  final int? createdAt;
  final int? finishedAt;
  const CountdownData({
    required this.key,
    this.name,
    this.mode,
    this.endTime,
    this.duration,
    this.pausedRemaining,
    this.status,
    this.notify,
    this.sound,
    this.color,
    this.createdAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<int>(endTime);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || pausedRemaining != null) {
      map['paused_remaining'] = Variable<int>(pausedRemaining);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || notify != null) {
      map['notify'] = Variable<String>(notify);
    }
    if (!nullToAbsent || sound != null) {
      map['sound'] = Variable<String>(sound);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    return map;
  }

  CountdownCompanion toCompanion(bool nullToAbsent) {
    return CountdownCompanion(
      key: Value(key),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      pausedRemaining: pausedRemaining == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedRemaining),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      notify: notify == null && nullToAbsent
          ? const Value.absent()
          : Value(notify),
      sound: sound == null && nullToAbsent
          ? const Value.absent()
          : Value(sound),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory CountdownData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CountdownData(
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String?>(json['name']),
      mode: serializer.fromJson<String?>(json['mode']),
      endTime: serializer.fromJson<int?>(json['endTime']),
      duration: serializer.fromJson<int?>(json['duration']),
      pausedRemaining: serializer.fromJson<int?>(json['pausedRemaining']),
      status: serializer.fromJson<String?>(json['status']),
      notify: serializer.fromJson<String?>(json['notify']),
      sound: serializer.fromJson<String?>(json['sound']),
      color: serializer.fromJson<String?>(json['color']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      finishedAt: serializer.fromJson<int?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String?>(name),
      'mode': serializer.toJson<String?>(mode),
      'endTime': serializer.toJson<int?>(endTime),
      'duration': serializer.toJson<int?>(duration),
      'pausedRemaining': serializer.toJson<int?>(pausedRemaining),
      'status': serializer.toJson<String?>(status),
      'notify': serializer.toJson<String?>(notify),
      'sound': serializer.toJson<String?>(sound),
      'color': serializer.toJson<String?>(color),
      'createdAt': serializer.toJson<int?>(createdAt),
      'finishedAt': serializer.toJson<int?>(finishedAt),
    };
  }

  CountdownData copyWith({
    String? key,
    Value<String?> name = const Value.absent(),
    Value<String?> mode = const Value.absent(),
    Value<int?> endTime = const Value.absent(),
    Value<int?> duration = const Value.absent(),
    Value<int?> pausedRemaining = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> notify = const Value.absent(),
    Value<String?> sound = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
    Value<int?> finishedAt = const Value.absent(),
  }) => CountdownData(
    key: key ?? this.key,
    name: name.present ? name.value : this.name,
    mode: mode.present ? mode.value : this.mode,
    endTime: endTime.present ? endTime.value : this.endTime,
    duration: duration.present ? duration.value : this.duration,
    pausedRemaining: pausedRemaining.present
        ? pausedRemaining.value
        : this.pausedRemaining,
    status: status.present ? status.value : this.status,
    notify: notify.present ? notify.value : this.notify,
    sound: sound.present ? sound.value : this.sound,
    color: color.present ? color.value : this.color,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  CountdownData copyWithCompanion(CountdownCompanion data) {
    return CountdownData(
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      mode: data.mode.present ? data.mode.value : this.mode,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      duration: data.duration.present ? data.duration.value : this.duration,
      pausedRemaining: data.pausedRemaining.present
          ? data.pausedRemaining.value
          : this.pausedRemaining,
      status: data.status.present ? data.status.value : this.status,
      notify: data.notify.present ? data.notify.value : this.notify,
      sound: data.sound.present ? data.sound.value : this.sound,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CountdownData(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('mode: $mode, ')
          ..write('endTime: $endTime, ')
          ..write('duration: $duration, ')
          ..write('pausedRemaining: $pausedRemaining, ')
          ..write('status: $status, ')
          ..write('notify: $notify, ')
          ..write('sound: $sound, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    name,
    mode,
    endTime,
    duration,
    pausedRemaining,
    status,
    notify,
    sound,
    color,
    createdAt,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountdownData &&
          other.key == this.key &&
          other.name == this.name &&
          other.mode == this.mode &&
          other.endTime == this.endTime &&
          other.duration == this.duration &&
          other.pausedRemaining == this.pausedRemaining &&
          other.status == this.status &&
          other.notify == this.notify &&
          other.sound == this.sound &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.finishedAt == this.finishedAt);
}

class CountdownCompanion extends UpdateCompanion<CountdownData> {
  final Value<String> key;
  final Value<String?> name;
  final Value<String?> mode;
  final Value<int?> endTime;
  final Value<int?> duration;
  final Value<int?> pausedRemaining;
  final Value<String?> status;
  final Value<String?> notify;
  final Value<String?> sound;
  final Value<String?> color;
  final Value<int?> createdAt;
  final Value<int?> finishedAt;
  final Value<int> rowid;
  const CountdownCompanion({
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.mode = const Value.absent(),
    this.endTime = const Value.absent(),
    this.duration = const Value.absent(),
    this.pausedRemaining = const Value.absent(),
    this.status = const Value.absent(),
    this.notify = const Value.absent(),
    this.sound = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CountdownCompanion.insert({
    required String key,
    this.name = const Value.absent(),
    this.mode = const Value.absent(),
    this.endTime = const Value.absent(),
    this.duration = const Value.absent(),
    this.pausedRemaining = const Value.absent(),
    this.status = const Value.absent(),
    this.notify = const Value.absent(),
    this.sound = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<CountdownData> custom({
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? mode,
    Expression<int>? endTime,
    Expression<int>? duration,
    Expression<int>? pausedRemaining,
    Expression<String>? status,
    Expression<String>? notify,
    Expression<String>? sound,
    Expression<String>? color,
    Expression<int>? createdAt,
    Expression<int>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (mode != null) 'mode': mode,
      if (endTime != null) 'end_time': endTime,
      if (duration != null) 'duration': duration,
      if (pausedRemaining != null) 'paused_remaining': pausedRemaining,
      if (status != null) 'status': status,
      if (notify != null) 'notify': notify,
      if (sound != null) 'sound': sound,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CountdownCompanion copyWith({
    Value<String>? key,
    Value<String?>? name,
    Value<String?>? mode,
    Value<int?>? endTime,
    Value<int?>? duration,
    Value<int?>? pausedRemaining,
    Value<String?>? status,
    Value<String?>? notify,
    Value<String?>? sound,
    Value<String?>? color,
    Value<int?>? createdAt,
    Value<int?>? finishedAt,
    Value<int>? rowid,
  }) {
    return CountdownCompanion(
      key: key ?? this.key,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      pausedRemaining: pausedRemaining ?? this.pausedRemaining,
      status: status ?? this.status,
      notify: notify ?? this.notify,
      sound: sound ?? this.sound,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<int>(endTime.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (pausedRemaining.present) {
      map['paused_remaining'] = Variable<int>(pausedRemaining.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notify.present) {
      map['notify'] = Variable<String>(notify.value);
    }
    if (sound.present) {
      map['sound'] = Variable<String>(sound.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountdownCompanion(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('mode: $mode, ')
          ..write('endTime: $endTime, ')
          ..write('duration: $duration, ')
          ..write('pausedRemaining: $pausedRemaining, ')
          ..write('status: $status, ')
          ..write('notify: $notify, ')
          ..write('sound: $sound, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QrHistoryTable extends QrHistory
    with TableInfo<$QrHistoryTable, QrHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QrHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    source,
    type,
    content,
    style,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qr_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<QrHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  QrHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QrHistoryData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $QrHistoryTable createAlias(String alias) {
    return $QrHistoryTable(attachedDatabase, alias);
  }
}

class QrHistoryData extends DataClass implements Insertable<QrHistoryData> {
  final String key;

  /// 来源标识：'qrCode' 页面 | 其它业务模块名
  final String? source;

  /// 内容类型：text/url/wifi/contact/email/...
  final String? type;

  /// 二维码原始文本
  final String? content;

  /// 样式 JSON（QrStyleOptions 序列化）
  final String? style;
  final String? note;
  final String? createdAt;
  const QrHistoryData({
    required this.key,
    this.source,
    this.type,
    this.content,
    this.style,
    this.note,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || style != null) {
      map['style'] = Variable<String>(style);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    return map;
  }

  QrHistoryCompanion toCompanion(bool nullToAbsent) {
    return QrHistoryCompanion(
      key: Value(key),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      style: style == null && nullToAbsent
          ? const Value.absent()
          : Value(style),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory QrHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QrHistoryData(
      key: serializer.fromJson<String>(json['key']),
      source: serializer.fromJson<String?>(json['source']),
      type: serializer.fromJson<String?>(json['type']),
      content: serializer.fromJson<String?>(json['content']),
      style: serializer.fromJson<String?>(json['style']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'source': serializer.toJson<String?>(source),
      'type': serializer.toJson<String?>(type),
      'content': serializer.toJson<String?>(content),
      'style': serializer.toJson<String?>(style),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<String?>(createdAt),
    };
  }

  QrHistoryData copyWith({
    String? key,
    Value<String?> source = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> style = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
  }) => QrHistoryData(
    key: key ?? this.key,
    source: source.present ? source.value : this.source,
    type: type.present ? type.value : this.type,
    content: content.present ? content.value : this.content,
    style: style.present ? style.value : this.style,
    note: note.present ? note.value : this.note,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  QrHistoryData copyWithCompanion(QrHistoryCompanion data) {
    return QrHistoryData(
      key: data.key.present ? data.key.value : this.key,
      source: data.source.present ? data.source.value : this.source,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      style: data.style.present ? data.style.value : this.style,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QrHistoryData(')
          ..write('key: $key, ')
          ..write('source: $source, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('style: $style, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, source, type, content, style, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QrHistoryData &&
          other.key == this.key &&
          other.source == this.source &&
          other.type == this.type &&
          other.content == this.content &&
          other.style == this.style &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class QrHistoryCompanion extends UpdateCompanion<QrHistoryData> {
  final Value<String> key;
  final Value<String?> source;
  final Value<String?> type;
  final Value<String?> content;
  final Value<String?> style;
  final Value<String?> note;
  final Value<String?> createdAt;
  final Value<int> rowid;
  const QrHistoryCompanion({
    this.key = const Value.absent(),
    this.source = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.style = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QrHistoryCompanion.insert({
    required String key,
    this.source = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.style = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<QrHistoryData> custom({
    Expression<String>? key,
    Expression<String>? source,
    Expression<String>? type,
    Expression<String>? content,
    Expression<String>? style,
    Expression<String>? note,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (source != null) 'source': source,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (style != null) 'style': style,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QrHistoryCompanion copyWith({
    Value<String>? key,
    Value<String?>? source,
    Value<String?>? type,
    Value<String?>? content,
    Value<String?>? style,
    Value<String?>? note,
    Value<String?>? createdAt,
    Value<int>? rowid,
  }) {
    return QrHistoryCompanion(
      key: key ?? this.key,
      source: source ?? this.source,
      type: type ?? this.type,
      content: content ?? this.content,
      style: style ?? this.style,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QrHistoryCompanion(')
          ..write('key: $key, ')
          ..write('source: $source, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('style: $style, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QrTemplateTable extends QrTemplate
    with TableInfo<$QrTemplateTable, QrTemplateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QrTemplateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    name,
    source,
    type,
    content,
    style,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qr_template';
  @override
  VerificationContext validateIntegrity(
    Insertable<QrTemplateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  QrTemplateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QrTemplateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $QrTemplateTable createAlias(String alias) {
    return $QrTemplateTable(attachedDatabase, alias);
  }
}

class QrTemplateData extends DataClass implements Insertable<QrTemplateData> {
  final String key;
  final String? name;
  final String? source;
  final String? type;
  final String? content;
  final String? style;
  final String? createdAt;
  const QrTemplateData({
    required this.key,
    this.name,
    this.source,
    this.type,
    this.content,
    this.style,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || style != null) {
      map['style'] = Variable<String>(style);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    return map;
  }

  QrTemplateCompanion toCompanion(bool nullToAbsent) {
    return QrTemplateCompanion(
      key: Value(key),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      style: style == null && nullToAbsent
          ? const Value.absent()
          : Value(style),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory QrTemplateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QrTemplateData(
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String?>(json['name']),
      source: serializer.fromJson<String?>(json['source']),
      type: serializer.fromJson<String?>(json['type']),
      content: serializer.fromJson<String?>(json['content']),
      style: serializer.fromJson<String?>(json['style']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String?>(name),
      'source': serializer.toJson<String?>(source),
      'type': serializer.toJson<String?>(type),
      'content': serializer.toJson<String?>(content),
      'style': serializer.toJson<String?>(style),
      'createdAt': serializer.toJson<String?>(createdAt),
    };
  }

  QrTemplateData copyWith({
    String? key,
    Value<String?> name = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> style = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
  }) => QrTemplateData(
    key: key ?? this.key,
    name: name.present ? name.value : this.name,
    source: source.present ? source.value : this.source,
    type: type.present ? type.value : this.type,
    content: content.present ? content.value : this.content,
    style: style.present ? style.value : this.style,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  QrTemplateData copyWithCompanion(QrTemplateCompanion data) {
    return QrTemplateData(
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      source: data.source.present ? data.source.value : this.source,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      style: data.style.present ? data.style.value : this.style,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QrTemplateData(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('style: $style, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, name, source, type, content, style, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QrTemplateData &&
          other.key == this.key &&
          other.name == this.name &&
          other.source == this.source &&
          other.type == this.type &&
          other.content == this.content &&
          other.style == this.style &&
          other.createdAt == this.createdAt);
}

class QrTemplateCompanion extends UpdateCompanion<QrTemplateData> {
  final Value<String> key;
  final Value<String?> name;
  final Value<String?> source;
  final Value<String?> type;
  final Value<String?> content;
  final Value<String?> style;
  final Value<String?> createdAt;
  final Value<int> rowid;
  const QrTemplateCompanion({
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.source = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.style = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QrTemplateCompanion.insert({
    required String key,
    this.name = const Value.absent(),
    this.source = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.style = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<QrTemplateData> custom({
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? source,
    Expression<String>? type,
    Expression<String>? content,
    Expression<String>? style,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (source != null) 'source': source,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (style != null) 'style': style,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QrTemplateCompanion copyWith({
    Value<String>? key,
    Value<String?>? name,
    Value<String?>? source,
    Value<String?>? type,
    Value<String?>? content,
    Value<String?>? style,
    Value<String?>? createdAt,
    Value<int>? rowid,
  }) {
    return QrTemplateCompanion(
      key: key ?? this.key,
      name: name ?? this.name,
      source: source ?? this.source,
      type: type ?? this.type,
      content: content ?? this.content,
      style: style ?? this.style,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QrTemplateCompanion(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('style: $style, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HabitDefTable habitDef = $HabitDefTable(this);
  late final $HabitCheckinTable habitCheckin = $HabitCheckinTable(this);
  late final $TodoListTable todoList = $TodoListTable(this);
  late final $TodoTagsTable todoTags = $TodoTagsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $NoteBookTable noteBook = $NoteBookTable(this);
  late final $BasicInfoTable basicInfo = $BasicInfoTable(this);
  late final $PomodoroStatusTable pomodoroStatus = $PomodoroStatusTable(this);
  late final $PomodoroMiniConfigTable pomodoroMiniConfig =
      $PomodoroMiniConfigTable(this);
  late final $ConversationTable conversation = $ConversationTable(this);
  late final $ConversationThemeTable conversationTheme =
      $ConversationThemeTable(this);
  late final $ConversationTagTable conversationTag = $ConversationTagTable(
    this,
  );
  late final $FileVaultConfigTable fileVaultConfig = $FileVaultConfigTable(
    this,
  );
  late final $FileVaultFilesTable fileVaultFiles = $FileVaultFilesTable(this);
  late final $EbookBookshelfTable ebookBookshelf = $EbookBookshelfTable(this);
  late final $EbookProgressTable ebookProgress = $EbookProgressTable(this);
  late final $EbookBookmarkTable ebookBookmark = $EbookBookmarkTable(this);
  late final $EbookAnnotationTable ebookAnnotation = $EbookAnnotationTable(
    this,
  );
  late final $EbookCategoryTable ebookCategory = $EbookCategoryTable(this);
  late final $EbookBookCategoryTable ebookBookCategory =
      $EbookBookCategoryTable(this);
  late final $EbookBgImageTable ebookBgImage = $EbookBgImageTable(this);
  late final $ScreenshotsTable screenshots = $ScreenshotsTable(this);
  late final $CountdownTable countdown = $CountdownTable(this);
  late final $QrHistoryTable qrHistory = $QrHistoryTable(this);
  late final $QrTemplateTable qrTemplate = $QrTemplateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    habitDef,
    habitCheckin,
    todoList,
    todoTags,
    reminders,
    noteBook,
    basicInfo,
    pomodoroStatus,
    pomodoroMiniConfig,
    conversation,
    conversationTheme,
    conversationTag,
    fileVaultConfig,
    fileVaultFiles,
    ebookBookshelf,
    ebookProgress,
    ebookBookmark,
    ebookAnnotation,
    ebookCategory,
    ebookBookCategory,
    ebookBgImage,
    screenshots,
    countdown,
    qrHistory,
    qrTemplate,
  ];
}

typedef $$HabitDefTableCreateCompanionBuilder = HabitDefCompanion Function({
  Value<int> id,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> key,
  Value<String?> createTime,
  Value<String?> updateTime,
  Value<String?> chainActions,
  Value<String?> weekDays,
  Value<String?> enabled,
  Value<String?> reminderTimes,
  Value<String?> remark,
  Value<String?> freqType,
});
typedef $$HabitDefTableUpdateCompanionBuilder = HabitDefCompanion Function({
  Value<int> id,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> key,
  Value<String?> createTime,
  Value<String?> updateTime,
  Value<String?> chainActions,
  Value<String?> weekDays,
  Value<String?> enabled,
  Value<String?> reminderTimes,
  Value<String?> remark,
  Value<String?> freqType,
});

class $$HabitDefTableFilterComposer
    extends Composer<_$AppDatabase, $HabitDefTable> {
  $$HabitDefTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chainActions => $composableBuilder(
    column: $table.chainActions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekDays => $composableBuilder(
    column: $table.weekDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTimes => $composableBuilder(
    column: $table.reminderTimes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get freqType => $composableBuilder(
    column: $table.freqType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitDefTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitDefTable> {
  $$HabitDefTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chainActions => $composableBuilder(
    column: $table.chainActions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekDays => $composableBuilder(
    column: $table.weekDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTimes => $composableBuilder(
    column: $table.reminderTimes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get freqType => $composableBuilder(
    column: $table.freqType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitDefTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitDefTable> {
  $$HabitDefTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chainActions => $composableBuilder(
    column: $table.chainActions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weekDays =>
      $composableBuilder(column: $table.weekDays, builder: (column) => column);

  GeneratedColumn<String> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get reminderTimes => $composableBuilder(
    column: $table.reminderTimes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<String> get freqType =>
      $composableBuilder(column: $table.freqType, builder: (column) => column);
}

class $$HabitDefTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitDefTable,
          HabitDefData,
          $$HabitDefTableFilterComposer,
          $$HabitDefTableOrderingComposer,
          $$HabitDefTableAnnotationComposer,
          $$HabitDefTableCreateCompanionBuilder,
          $$HabitDefTableUpdateCompanionBuilder,
          (
            HabitDefData,
            BaseReferences<_$AppDatabase, $HabitDefTable, HabitDefData>,
          ),
          HabitDefData,
          PrefetchHooks Function()
        > {
  $$HabitDefTableTableManager(_$AppDatabase db, $HabitDefTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitDefTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitDefTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitDefTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> chainActions = const Value.absent(),
                Value<String?> weekDays = const Value.absent(),
                Value<String?> enabled = const Value.absent(),
                Value<String?> reminderTimes = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<String?> freqType = const Value.absent(),
              }) => HabitDefCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                key: key,
                createTime: createTime,
                updateTime: updateTime,
                chainActions: chainActions,
                weekDays: weekDays,
                enabled: enabled,
                reminderTimes: reminderTimes,
                remark: remark,
                freqType: freqType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> chainActions = const Value.absent(),
                Value<String?> weekDays = const Value.absent(),
                Value<String?> enabled = const Value.absent(),
                Value<String?> reminderTimes = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<String?> freqType = const Value.absent(),
              }) => HabitDefCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                key: key,
                createTime: createTime,
                updateTime: updateTime,
                chainActions: chainActions,
                weekDays: weekDays,
                enabled: enabled,
                reminderTimes: reminderTimes,
                remark: remark,
                freqType: freqType,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitDefTable, HabitDefData>(table),
                  BaseReferences<_$AppDatabase, $HabitDefTable, HabitDefData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitDefTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitDefTable,
      HabitDefData,
      $$HabitDefTableFilterComposer,
      $$HabitDefTableOrderingComposer,
      $$HabitDefTableAnnotationComposer,
      $$HabitDefTableCreateCompanionBuilder,
      $$HabitDefTableUpdateCompanionBuilder,
      (
        HabitDefData,
        BaseReferences<_$AppDatabase, $HabitDefTable, HabitDefData>,
      ),
      HabitDefData,
      PrefetchHooks Function()
    >;
typedef $$HabitCheckinTableCreateCompanionBuilder =
    HabitCheckinCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> key,
      Value<String?> habitKey,
      Value<String?> note,
      Value<String?> date,
      Value<String?> source,
      Value<String?> time,
    });
typedef $$HabitCheckinTableUpdateCompanionBuilder =
    HabitCheckinCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> key,
      Value<String?> habitKey,
      Value<String?> note,
      Value<String?> date,
      Value<String?> source,
      Value<String?> time,
    });

class $$HabitCheckinTableFilterComposer
    extends Composer<_$AppDatabase, $HabitCheckinTable> {
  $$HabitCheckinTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitKey => $composableBuilder(
    column: $table.habitKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitCheckinTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitCheckinTable> {
  $$HabitCheckinTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitKey => $composableBuilder(
    column: $table.habitKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitCheckinTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitCheckinTable> {
  $$HabitCheckinTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get habitKey =>
      $composableBuilder(column: $table.habitKey, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);
}

class $$HabitCheckinTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitCheckinTable,
          HabitCheckinData,
          $$HabitCheckinTableFilterComposer,
          $$HabitCheckinTableOrderingComposer,
          $$HabitCheckinTableAnnotationComposer,
          $$HabitCheckinTableCreateCompanionBuilder,
          $$HabitCheckinTableUpdateCompanionBuilder,
          (
            HabitCheckinData,
            BaseReferences<_$AppDatabase, $HabitCheckinTable, HabitCheckinData>,
          ),
          HabitCheckinData,
          PrefetchHooks Function()
        > {
  $$HabitCheckinTableTableManager(_$AppDatabase db, $HabitCheckinTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitCheckinTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitCheckinTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitCheckinTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> habitKey = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> time = const Value.absent(),
              }) => HabitCheckinCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                key: key,
                habitKey: habitKey,
                note: note,
                date: date,
                source: source,
                time: time,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> habitKey = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> time = const Value.absent(),
              }) => HabitCheckinCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                key: key,
                habitKey: habitKey,
                note: note,
                date: date,
                source: source,
                time: time,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitCheckinTable, HabitCheckinData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HabitCheckinTable,
                    HabitCheckinData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitCheckinTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitCheckinTable,
      HabitCheckinData,
      $$HabitCheckinTableFilterComposer,
      $$HabitCheckinTableOrderingComposer,
      $$HabitCheckinTableAnnotationComposer,
      $$HabitCheckinTableCreateCompanionBuilder,
      $$HabitCheckinTableUpdateCompanionBuilder,
      (
        HabitCheckinData,
        BaseReferences<_$AppDatabase, $HabitCheckinTable, HabitCheckinData>,
      ),
      HabitCheckinData,
      PrefetchHooks Function()
    >;
typedef $$TodoListTableCreateCompanionBuilder = TodoListCompanion Function({
  required String key,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> priority,
  Value<String?> dueDate,
  Value<String?> createTime,
  Value<String?> completedTime,
  Value<String?> tags,
  Value<String?> updateTime,
  Value<String?> completed,
  Value<String?> title,
  Value<String?> description,
  Value<String?> deadlineReminder,
  Value<String?> remindCount,
  Value<String?> remindInterval,
  Value<String?> remindIntervalUnit,
  Value<String?> status,
  Value<String?> parentId,
  Value<String?> recurrenceEnd,
  Value<String?> recurrenceId,
  Value<String?> recurrenceInterval,
  Value<String?> isRecurrenceInstance,
  Value<String?> recurrenceRule,
  Value<String?> recurrenceWeekdays,
  Value<String?> sortOrder,
  Value<String?> parentIds,
  Value<int?> id,
  Value<int> rowid,
});
typedef $$TodoListTableUpdateCompanionBuilder = TodoListCompanion Function({
  Value<String> key,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> priority,
  Value<String?> dueDate,
  Value<String?> createTime,
  Value<String?> completedTime,
  Value<String?> tags,
  Value<String?> updateTime,
  Value<String?> completed,
  Value<String?> title,
  Value<String?> description,
  Value<String?> deadlineReminder,
  Value<String?> remindCount,
  Value<String?> remindInterval,
  Value<String?> remindIntervalUnit,
  Value<String?> status,
  Value<String?> parentId,
  Value<String?> recurrenceEnd,
  Value<String?> recurrenceId,
  Value<String?> recurrenceInterval,
  Value<String?> isRecurrenceInstance,
  Value<String?> recurrenceRule,
  Value<String?> recurrenceWeekdays,
  Value<String?> sortOrder,
  Value<String?> parentIds,
  Value<int?> id,
  Value<int> rowid,
});

class $$TodoListTableFilterComposer
    extends Composer<_$AppDatabase, $TodoListTable> {
  $$TodoListTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedTime => $composableBuilder(
    column: $table.completedTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deadlineReminder => $composableBuilder(
    column: $table.deadlineReminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindCount => $composableBuilder(
    column: $table.remindCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindInterval => $composableBuilder(
    column: $table.remindInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindIntervalUnit => $composableBuilder(
    column: $table.remindIntervalUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceEnd => $composableBuilder(
    column: $table.recurrenceEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isRecurrenceInstance => $composableBuilder(
    column: $table.isRecurrenceInstance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceWeekdays => $composableBuilder(
    column: $table.recurrenceWeekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentIds => $composableBuilder(
    column: $table.parentIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoListTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListTable> {
  $$TodoListTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedTime => $composableBuilder(
    column: $table.completedTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deadlineReminder => $composableBuilder(
    column: $table.deadlineReminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindCount => $composableBuilder(
    column: $table.remindCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindInterval => $composableBuilder(
    column: $table.remindInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindIntervalUnit => $composableBuilder(
    column: $table.remindIntervalUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceEnd => $composableBuilder(
    column: $table.recurrenceEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isRecurrenceInstance => $composableBuilder(
    column: $table.isRecurrenceInstance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceWeekdays => $composableBuilder(
    column: $table.recurrenceWeekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentIds => $composableBuilder(
    column: $table.parentIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoListTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoListTable> {
  $$TodoListTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedTime => $composableBuilder(
    column: $table.completedTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deadlineReminder => $composableBuilder(
    column: $table.deadlineReminder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remindCount => $composableBuilder(
    column: $table.remindCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remindInterval => $composableBuilder(
    column: $table.remindInterval,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remindIntervalUnit => $composableBuilder(
    column: $table.remindIntervalUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get recurrenceEnd => $composableBuilder(
    column: $table.recurrenceEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => column,
  );

  GeneratedColumn<String> get isRecurrenceInstance => $composableBuilder(
    column: $table.isRecurrenceInstance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceWeekdays => $composableBuilder(
    column: $table.recurrenceWeekdays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get parentIds =>
      $composableBuilder(column: $table.parentIds, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$TodoListTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoListTable,
          TodoListData,
          $$TodoListTableFilterComposer,
          $$TodoListTableOrderingComposer,
          $$TodoListTableAnnotationComposer,
          $$TodoListTableCreateCompanionBuilder,
          $$TodoListTableUpdateCompanionBuilder,
          (
            TodoListData,
            BaseReferences<_$AppDatabase, $TodoListTable, TodoListData>,
          ),
          TodoListData,
          PrefetchHooks Function()
        > {
  $$TodoListTableTableManager(_$AppDatabase db, $TodoListTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoListTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoListTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoListTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> priority = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> completedTime = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> completed = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> deadlineReminder = const Value.absent(),
                Value<String?> remindCount = const Value.absent(),
                Value<String?> remindInterval = const Value.absent(),
                Value<String?> remindIntervalUnit = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> recurrenceEnd = const Value.absent(),
                Value<String?> recurrenceId = const Value.absent(),
                Value<String?> recurrenceInterval = const Value.absent(),
                Value<String?> isRecurrenceInstance = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceWeekdays = const Value.absent(),
                Value<String?> sortOrder = const Value.absent(),
                Value<String?> parentIds = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListCompanion(
                key: key,
                name: name,
                value: value,
                createdAt: createdAt,
                priority: priority,
                dueDate: dueDate,
                createTime: createTime,
                completedTime: completedTime,
                tags: tags,
                updateTime: updateTime,
                completed: completed,
                title: title,
                description: description,
                deadlineReminder: deadlineReminder,
                remindCount: remindCount,
                remindInterval: remindInterval,
                remindIntervalUnit: remindIntervalUnit,
                status: status,
                parentId: parentId,
                recurrenceEnd: recurrenceEnd,
                recurrenceId: recurrenceId,
                recurrenceInterval: recurrenceInterval,
                isRecurrenceInstance: isRecurrenceInstance,
                recurrenceRule: recurrenceRule,
                recurrenceWeekdays: recurrenceWeekdays,
                sortOrder: sortOrder,
                parentIds: parentIds,
                id: id,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> priority = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> completedTime = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> completed = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> deadlineReminder = const Value.absent(),
                Value<String?> remindCount = const Value.absent(),
                Value<String?> remindInterval = const Value.absent(),
                Value<String?> remindIntervalUnit = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> recurrenceEnd = const Value.absent(),
                Value<String?> recurrenceId = const Value.absent(),
                Value<String?> recurrenceInterval = const Value.absent(),
                Value<String?> isRecurrenceInstance = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceWeekdays = const Value.absent(),
                Value<String?> sortOrder = const Value.absent(),
                Value<String?> parentIds = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListCompanion.insert(
                key: key,
                name: name,
                value: value,
                createdAt: createdAt,
                priority: priority,
                dueDate: dueDate,
                createTime: createTime,
                completedTime: completedTime,
                tags: tags,
                updateTime: updateTime,
                completed: completed,
                title: title,
                description: description,
                deadlineReminder: deadlineReminder,
                remindCount: remindCount,
                remindInterval: remindInterval,
                remindIntervalUnit: remindIntervalUnit,
                status: status,
                parentId: parentId,
                recurrenceEnd: recurrenceEnd,
                recurrenceId: recurrenceId,
                recurrenceInterval: recurrenceInterval,
                isRecurrenceInstance: isRecurrenceInstance,
                recurrenceRule: recurrenceRule,
                recurrenceWeekdays: recurrenceWeekdays,
                sortOrder: sortOrder,
                parentIds: parentIds,
                id: id,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TodoListTable, TodoListData>(table),
                  BaseReferences<_$AppDatabase, $TodoListTable, TodoListData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoListTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoListTable,
      TodoListData,
      $$TodoListTableFilterComposer,
      $$TodoListTableOrderingComposer,
      $$TodoListTableAnnotationComposer,
      $$TodoListTableCreateCompanionBuilder,
      $$TodoListTableUpdateCompanionBuilder,
      (
        TodoListData,
        BaseReferences<_$AppDatabase, $TodoListTable, TodoListData>,
      ),
      TodoListData,
      PrefetchHooks Function()
    >;
typedef $$TodoTagsTableCreateCompanionBuilder = TodoTagsCompanion Function({
  Value<int> id,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> key,
  Value<String?> color,
});
typedef $$TodoTagsTableUpdateCompanionBuilder = TodoTagsCompanion Function({
  Value<int> id,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> key,
  Value<String?> color,
});

class $$TodoTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoTagsTable> {
  $$TodoTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoTagsTable> {
  $$TodoTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoTagsTable> {
  $$TodoTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$TodoTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoTagsTable,
          TodoTag,
          $$TodoTagsTableFilterComposer,
          $$TodoTagsTableOrderingComposer,
          $$TodoTagsTableAnnotationComposer,
          $$TodoTagsTableCreateCompanionBuilder,
          $$TodoTagsTableUpdateCompanionBuilder,
          (TodoTag, BaseReferences<_$AppDatabase, $TodoTagsTable, TodoTag>),
          TodoTag,
          PrefetchHooks Function()
        > {
  $$TodoTagsTableTableManager(_$AppDatabase db, $TodoTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> color = const Value.absent(),
              }) => TodoTagsCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                key: key,
                color: color,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> color = const Value.absent(),
              }) => TodoTagsCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                key: key,
                color: color,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TodoTagsTable, TodoTag>(table),
                  BaseReferences<_$AppDatabase, $TodoTagsTable, TodoTag>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoTagsTable,
      TodoTag,
      $$TodoTagsTableFilterComposer,
      $$TodoTagsTableOrderingComposer,
      $$TodoTagsTableAnnotationComposer,
      $$TodoTagsTableCreateCompanionBuilder,
      $$TodoTagsTableUpdateCompanionBuilder,
      (TodoTag, BaseReferences<_$AppDatabase, $TodoTagsTable, TodoTag>),
      TodoTag,
      PrefetchHooks Function()
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  required String id,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> mode,
  Value<String?> startTime,
  Value<String?> states,
  Value<String?> weekDays,
  Value<String?> loop,
  Value<String?> recordAfter,
  Value<String?> interval,
  Value<String?> month,
  Value<String?> minute,
  Value<String?> dayOfMonth,
  Value<String?> unit,
  Value<String?> title,
  Value<String?> content,
  Value<String?> enabled,
  Value<String?> idleTime,
  Value<String?> time,
  Value<String?> repeat,
  Value<String?> date,
  Value<String?> source,
  Value<int> rowid,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<String> id,
  Value<String?> name,
  Value<String?> value,
  Value<String?> createdAt,
  Value<String?> mode,
  Value<String?> startTime,
  Value<String?> states,
  Value<String?> weekDays,
  Value<String?> loop,
  Value<String?> recordAfter,
  Value<String?> interval,
  Value<String?> month,
  Value<String?> minute,
  Value<String?> dayOfMonth,
  Value<String?> unit,
  Value<String?> title,
  Value<String?> content,
  Value<String?> enabled,
  Value<String?> idleTime,
  Value<String?> time,
  Value<String?> repeat,
  Value<String?> date,
  Value<String?> source,
  Value<int> rowid,
});

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get states => $composableBuilder(
    column: $table.states,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekDays => $composableBuilder(
    column: $table.weekDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loop => $composableBuilder(
    column: $table.loop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordAfter => $composableBuilder(
    column: $table.recordAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idleTime => $composableBuilder(
    column: $table.idleTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get states => $composableBuilder(
    column: $table.states,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekDays => $composableBuilder(
    column: $table.weekDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loop => $composableBuilder(
    column: $table.loop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordAfter => $composableBuilder(
    column: $table.recordAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idleTime => $composableBuilder(
    column: $table.idleTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get states =>
      $composableBuilder(column: $table.states, builder: (column) => column);

  GeneratedColumn<String> get weekDays =>
      $composableBuilder(column: $table.weekDays, builder: (column) => column);

  GeneratedColumn<String> get loop =>
      $composableBuilder(column: $table.loop, builder: (column) => column);

  GeneratedColumn<String> get recordAfter => $composableBuilder(
    column: $table.recordAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get idleTime =>
      $composableBuilder(column: $table.idleTime, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
          Reminder,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> states = const Value.absent(),
                Value<String?> weekDays = const Value.absent(),
                Value<String?> loop = const Value.absent(),
                Value<String?> recordAfter = const Value.absent(),
                Value<String?> interval = const Value.absent(),
                Value<String?> month = const Value.absent(),
                Value<String?> minute = const Value.absent(),
                Value<String?> dayOfMonth = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> enabled = const Value.absent(),
                Value<String?> idleTime = const Value.absent(),
                Value<String?> time = const Value.absent(),
                Value<String?> repeat = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                mode: mode,
                startTime: startTime,
                states: states,
                weekDays: weekDays,
                loop: loop,
                recordAfter: recordAfter,
                interval: interval,
                month: month,
                minute: minute,
                dayOfMonth: dayOfMonth,
                unit: unit,
                title: title,
                content: content,
                enabled: enabled,
                idleTime: idleTime,
                time: time,
                repeat: repeat,
                date: date,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> states = const Value.absent(),
                Value<String?> weekDays = const Value.absent(),
                Value<String?> loop = const Value.absent(),
                Value<String?> recordAfter = const Value.absent(),
                Value<String?> interval = const Value.absent(),
                Value<String?> month = const Value.absent(),
                Value<String?> minute = const Value.absent(),
                Value<String?> dayOfMonth = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> enabled = const Value.absent(),
                Value<String?> idleTime = const Value.absent(),
                Value<String?> time = const Value.absent(),
                Value<String?> repeat = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                mode: mode,
                startTime: startTime,
                states: states,
                weekDays: weekDays,
                loop: loop,
                recordAfter: recordAfter,
                interval: interval,
                month: month,
                minute: minute,
                dayOfMonth: dayOfMonth,
                unit: unit,
                title: title,
                content: content,
                enabled: enabled,
                idleTime: idleTime,
                time: time,
                repeat: repeat,
                date: date,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, Reminder>(table),
                  BaseReferences<_$AppDatabase, $RemindersTable, Reminder>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
      Reminder,
      PrefetchHooks Function()
    >;
typedef $$NoteBookTableCreateCompanionBuilder = NoteBookCompanion Function({
  required String key,
  Value<String?> excerpt,
  Value<String?> html,
  Value<String?> createTime,
  Value<String?> updateTime,
  Value<String?> mdText,
  Value<String?> tags,
  Value<String?> whereStr,
  Value<String?> content,
  Value<String?> category,
  Value<int?> id,
  Value<int> rowid,
});
typedef $$NoteBookTableUpdateCompanionBuilder = NoteBookCompanion Function({
  Value<String> key,
  Value<String?> excerpt,
  Value<String?> html,
  Value<String?> createTime,
  Value<String?> updateTime,
  Value<String?> mdText,
  Value<String?> tags,
  Value<String?> whereStr,
  Value<String?> content,
  Value<String?> category,
  Value<int?> id,
  Value<int> rowid,
});

class $$NoteBookTableFilterComposer
    extends Composer<_$AppDatabase, $NoteBookTable> {
  $$NoteBookTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get html => $composableBuilder(
    column: $table.html,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mdText => $composableBuilder(
    column: $table.mdText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whereStr => $composableBuilder(
    column: $table.whereStr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteBookTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteBookTable> {
  $$NoteBookTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get html => $composableBuilder(
    column: $table.html,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mdText => $composableBuilder(
    column: $table.mdText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whereStr => $composableBuilder(
    column: $table.whereStr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteBookTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteBookTable> {
  $$NoteBookTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get excerpt =>
      $composableBuilder(column: $table.excerpt, builder: (column) => column);

  GeneratedColumn<String> get html =>
      $composableBuilder(column: $table.html, builder: (column) => column);

  GeneratedColumn<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mdText =>
      $composableBuilder(column: $table.mdText, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get whereStr =>
      $composableBuilder(column: $table.whereStr, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$NoteBookTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteBookTable,
          NoteBookData,
          $$NoteBookTableFilterComposer,
          $$NoteBookTableOrderingComposer,
          $$NoteBookTableAnnotationComposer,
          $$NoteBookTableCreateCompanionBuilder,
          $$NoteBookTableUpdateCompanionBuilder,
          (
            NoteBookData,
            BaseReferences<_$AppDatabase, $NoteBookTable, NoteBookData>,
          ),
          NoteBookData,
          PrefetchHooks Function()
        > {
  $$NoteBookTableTableManager(_$AppDatabase db, $NoteBookTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteBookTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteBookTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteBookTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> excerpt = const Value.absent(),
                Value<String?> html = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> mdText = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> whereStr = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteBookCompanion(
                key: key,
                excerpt: excerpt,
                html: html,
                createTime: createTime,
                updateTime: updateTime,
                mdText: mdText,
                tags: tags,
                whereStr: whereStr,
                content: content,
                category: category,
                id: id,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> excerpt = const Value.absent(),
                Value<String?> html = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> mdText = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> whereStr = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteBookCompanion.insert(
                key: key,
                excerpt: excerpt,
                html: html,
                createTime: createTime,
                updateTime: updateTime,
                mdText: mdText,
                tags: tags,
                whereStr: whereStr,
                content: content,
                category: category,
                id: id,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteBookTable, NoteBookData>(table),
                  BaseReferences<_$AppDatabase, $NoteBookTable, NoteBookData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteBookTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteBookTable,
      NoteBookData,
      $$NoteBookTableFilterComposer,
      $$NoteBookTableOrderingComposer,
      $$NoteBookTableAnnotationComposer,
      $$NoteBookTableCreateCompanionBuilder,
      $$NoteBookTableUpdateCompanionBuilder,
      (
        NoteBookData,
        BaseReferences<_$AppDatabase, $NoteBookTable, NoteBookData>,
      ),
      NoteBookData,
      PrefetchHooks Function()
    >;
typedef $$BasicInfoTableCreateCompanionBuilder = BasicInfoCompanion Function({
  required String key,
  Value<String?> value,
  Value<String?> whereStr,
  Value<String?> orderByDesc,
  Value<String?> orderBy,
  Value<int?> id,
  Value<int> rowid,
});
typedef $$BasicInfoTableUpdateCompanionBuilder = BasicInfoCompanion Function({
  Value<String> key,
  Value<String?> value,
  Value<String?> whereStr,
  Value<String?> orderByDesc,
  Value<String?> orderBy,
  Value<int?> id,
  Value<int> rowid,
});

class $$BasicInfoTableFilterComposer
    extends Composer<_$AppDatabase, $BasicInfoTable> {
  $$BasicInfoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whereStr => $composableBuilder(
    column: $table.whereStr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderByDesc => $composableBuilder(
    column: $table.orderByDesc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderBy => $composableBuilder(
    column: $table.orderBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BasicInfoTableOrderingComposer
    extends Composer<_$AppDatabase, $BasicInfoTable> {
  $$BasicInfoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whereStr => $composableBuilder(
    column: $table.whereStr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderByDesc => $composableBuilder(
    column: $table.orderByDesc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderBy => $composableBuilder(
    column: $table.orderBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BasicInfoTableAnnotationComposer
    extends Composer<_$AppDatabase, $BasicInfoTable> {
  $$BasicInfoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get whereStr =>
      $composableBuilder(column: $table.whereStr, builder: (column) => column);

  GeneratedColumn<String> get orderByDesc => $composableBuilder(
    column: $table.orderByDesc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orderBy =>
      $composableBuilder(column: $table.orderBy, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$BasicInfoTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BasicInfoTable,
          BasicInfoData,
          $$BasicInfoTableFilterComposer,
          $$BasicInfoTableOrderingComposer,
          $$BasicInfoTableAnnotationComposer,
          $$BasicInfoTableCreateCompanionBuilder,
          $$BasicInfoTableUpdateCompanionBuilder,
          (
            BasicInfoData,
            BaseReferences<_$AppDatabase, $BasicInfoTable, BasicInfoData>,
          ),
          BasicInfoData,
          PrefetchHooks Function()
        > {
  $$BasicInfoTableTableManager(_$AppDatabase db, $BasicInfoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BasicInfoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BasicInfoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BasicInfoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> whereStr = const Value.absent(),
                Value<String?> orderByDesc = const Value.absent(),
                Value<String?> orderBy = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BasicInfoCompanion(
                key: key,
                value: value,
                whereStr: whereStr,
                orderByDesc: orderByDesc,
                orderBy: orderBy,
                id: id,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<String?> whereStr = const Value.absent(),
                Value<String?> orderByDesc = const Value.absent(),
                Value<String?> orderBy = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BasicInfoCompanion.insert(
                key: key,
                value: value,
                whereStr: whereStr,
                orderByDesc: orderByDesc,
                orderBy: orderBy,
                id: id,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BasicInfoTable, BasicInfoData>(table),
                  BaseReferences<_$AppDatabase, $BasicInfoTable, BasicInfoData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BasicInfoTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BasicInfoTable,
      BasicInfoData,
      $$BasicInfoTableFilterComposer,
      $$BasicInfoTableOrderingComposer,
      $$BasicInfoTableAnnotationComposer,
      $$BasicInfoTableCreateCompanionBuilder,
      $$BasicInfoTableUpdateCompanionBuilder,
      (
        BasicInfoData,
        BaseReferences<_$AppDatabase, $BasicInfoTable, BasicInfoData>,
      ),
      BasicInfoData,
      PrefetchHooks Function()
    >;
typedef $$PomodoroStatusTableCreateCompanionBuilder =
    PomodoroStatusCompanion Function({
      Value<int> id,
      Value<String?> label,
      Value<String?> value,
      Value<String?> mode,
      Value<String?> createTime,
      Value<String?> date,
      Value<String?> recordedAt,
    });
typedef $$PomodoroStatusTableUpdateCompanionBuilder =
    PomodoroStatusCompanion Function({
      Value<int> id,
      Value<String?> label,
      Value<String?> value,
      Value<String?> mode,
      Value<String?> createTime,
      Value<String?> date,
      Value<String?> recordedAt,
    });

class $$PomodoroStatusTableFilterComposer
    extends Composer<_$AppDatabase, $PomodoroStatusTable> {
  $$PomodoroStatusTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PomodoroStatusTableOrderingComposer
    extends Composer<_$AppDatabase, $PomodoroStatusTable> {
  $$PomodoroStatusTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PomodoroStatusTableAnnotationComposer
    extends Composer<_$AppDatabase, $PomodoroStatusTable> {
  $$PomodoroStatusTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$PomodoroStatusTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PomodoroStatusTable,
          PomodoroStatusData,
          $$PomodoroStatusTableFilterComposer,
          $$PomodoroStatusTableOrderingComposer,
          $$PomodoroStatusTableAnnotationComposer,
          $$PomodoroStatusTableCreateCompanionBuilder,
          $$PomodoroStatusTableUpdateCompanionBuilder,
          (
            PomodoroStatusData,
            BaseReferences<
              _$AppDatabase,
              $PomodoroStatusTable,
              PomodoroStatusData
            >,
          ),
          PomodoroStatusData,
          PrefetchHooks Function()
        > {
  $$PomodoroStatusTableTableManager(
    _$AppDatabase db,
    $PomodoroStatusTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PomodoroStatusTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PomodoroStatusTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PomodoroStatusTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> recordedAt = const Value.absent(),
              }) => PomodoroStatusCompanion(
                id: id,
                label: label,
                value: value,
                mode: mode,
                createTime: createTime,
                date: date,
                recordedAt: recordedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> recordedAt = const Value.absent(),
              }) => PomodoroStatusCompanion.insert(
                id: id,
                label: label,
                value: value,
                mode: mode,
                createTime: createTime,
                date: date,
                recordedAt: recordedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PomodoroStatusTable, PomodoroStatusData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PomodoroStatusTable,
                    PomodoroStatusData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PomodoroStatusTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PomodoroStatusTable,
      PomodoroStatusData,
      $$PomodoroStatusTableFilterComposer,
      $$PomodoroStatusTableOrderingComposer,
      $$PomodoroStatusTableAnnotationComposer,
      $$PomodoroStatusTableCreateCompanionBuilder,
      $$PomodoroStatusTableUpdateCompanionBuilder,
      (
        PomodoroStatusData,
        BaseReferences<_$AppDatabase, $PomodoroStatusTable, PomodoroStatusData>,
      ),
      PomodoroStatusData,
      PrefetchHooks Function()
    >;
typedef $$PomodoroMiniConfigTableCreateCompanionBuilder =
    PomodoroMiniConfigCompanion Function({
      required String key,
      Value<String?> skin,
      Value<int> rowid,
    });
typedef $$PomodoroMiniConfigTableUpdateCompanionBuilder =
    PomodoroMiniConfigCompanion Function({
      Value<String> key,
      Value<String?> skin,
      Value<int> rowid,
    });

class $$PomodoroMiniConfigTableFilterComposer
    extends Composer<_$AppDatabase, $PomodoroMiniConfigTable> {
  $$PomodoroMiniConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skin => $composableBuilder(
    column: $table.skin,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PomodoroMiniConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $PomodoroMiniConfigTable> {
  $$PomodoroMiniConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skin => $composableBuilder(
    column: $table.skin,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PomodoroMiniConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $PomodoroMiniConfigTable> {
  $$PomodoroMiniConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get skin =>
      $composableBuilder(column: $table.skin, builder: (column) => column);
}

class $$PomodoroMiniConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PomodoroMiniConfigTable,
          PomodoroMiniConfigData,
          $$PomodoroMiniConfigTableFilterComposer,
          $$PomodoroMiniConfigTableOrderingComposer,
          $$PomodoroMiniConfigTableAnnotationComposer,
          $$PomodoroMiniConfigTableCreateCompanionBuilder,
          $$PomodoroMiniConfigTableUpdateCompanionBuilder,
          (
            PomodoroMiniConfigData,
            BaseReferences<
              _$AppDatabase,
              $PomodoroMiniConfigTable,
              PomodoroMiniConfigData
            >,
          ),
          PomodoroMiniConfigData,
          PrefetchHooks Function()
        > {
  $$PomodoroMiniConfigTableTableManager(
    _$AppDatabase db,
    $PomodoroMiniConfigTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PomodoroMiniConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PomodoroMiniConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PomodoroMiniConfigTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String?> skin = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PomodoroMiniConfigCompanion(key: key, skin: skin, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> skin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PomodoroMiniConfigCompanion.insert(
                key: key,
                skin: skin,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PomodoroMiniConfigTable, PomodoroMiniConfigData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PomodoroMiniConfigTable,
                    PomodoroMiniConfigData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PomodoroMiniConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PomodoroMiniConfigTable,
      PomodoroMiniConfigData,
      $$PomodoroMiniConfigTableFilterComposer,
      $$PomodoroMiniConfigTableOrderingComposer,
      $$PomodoroMiniConfigTableAnnotationComposer,
      $$PomodoroMiniConfigTableCreateCompanionBuilder,
      $$PomodoroMiniConfigTableUpdateCompanionBuilder,
      (
        PomodoroMiniConfigData,
        BaseReferences<
          _$AppDatabase,
          $PomodoroMiniConfigTable,
          PomodoroMiniConfigData
        >,
      ),
      PomodoroMiniConfigData,
      PrefetchHooks Function()
    >;
typedef $$ConversationTableCreateCompanionBuilder =
    ConversationCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> themeId,
      Value<String?> content,
      Value<String?> tags,
      Value<String?> createTime,
      Value<String?> annotateTime,
      Value<String?> pinned,
      Value<String?> isDeleted,
      Value<String?> refIds,
      Value<String?> isRich,
      Value<String?> is_,
      Value<String?> crossRefs,
      Value<String?> extKey,
    });
typedef $$ConversationTableUpdateCompanionBuilder =
    ConversationCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> themeId,
      Value<String?> content,
      Value<String?> tags,
      Value<String?> createTime,
      Value<String?> annotateTime,
      Value<String?> pinned,
      Value<String?> isDeleted,
      Value<String?> refIds,
      Value<String?> isRich,
      Value<String?> is_,
      Value<String?> crossRefs,
      Value<String?> extKey,
    });

class $$ConversationTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationTable> {
  $$ConversationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeId => $composableBuilder(
    column: $table.themeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotateTime => $composableBuilder(
    column: $table.annotateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refIds => $composableBuilder(
    column: $table.refIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isRich => $composableBuilder(
    column: $table.isRich,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get is_ => $composableBuilder(
    column: $table.is_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get crossRefs => $composableBuilder(
    column: $table.crossRefs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extKey => $composableBuilder(
    column: $table.extKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationTable> {
  $$ConversationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeId => $composableBuilder(
    column: $table.themeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotateTime => $composableBuilder(
    column: $table.annotateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refIds => $composableBuilder(
    column: $table.refIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isRich => $composableBuilder(
    column: $table.isRich,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get is_ => $composableBuilder(
    column: $table.is_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get crossRefs => $composableBuilder(
    column: $table.crossRefs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extKey => $composableBuilder(
    column: $table.extKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationTable> {
  $$ConversationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get themeId =>
      $composableBuilder(column: $table.themeId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get annotateTime => $composableBuilder(
    column: $table.annotateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<String> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get refIds =>
      $composableBuilder(column: $table.refIds, builder: (column) => column);

  GeneratedColumn<String> get isRich =>
      $composableBuilder(column: $table.isRich, builder: (column) => column);

  GeneratedColumn<String> get is_ =>
      $composableBuilder(column: $table.is_, builder: (column) => column);

  GeneratedColumn<String> get crossRefs =>
      $composableBuilder(column: $table.crossRefs, builder: (column) => column);

  GeneratedColumn<String> get extKey =>
      $composableBuilder(column: $table.extKey, builder: (column) => column);
}

class $$ConversationTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationTable,
          ConversationData,
          $$ConversationTableFilterComposer,
          $$ConversationTableOrderingComposer,
          $$ConversationTableAnnotationComposer,
          $$ConversationTableCreateCompanionBuilder,
          $$ConversationTableUpdateCompanionBuilder,
          (
            ConversationData,
            BaseReferences<_$AppDatabase, $ConversationTable, ConversationData>,
          ),
          ConversationData,
          PrefetchHooks Function()
        > {
  $$ConversationTableTableManager(_$AppDatabase db, $ConversationTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> themeId = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> annotateTime = const Value.absent(),
                Value<String?> pinned = const Value.absent(),
                Value<String?> isDeleted = const Value.absent(),
                Value<String?> refIds = const Value.absent(),
                Value<String?> isRich = const Value.absent(),
                Value<String?> is_ = const Value.absent(),
                Value<String?> crossRefs = const Value.absent(),
                Value<String?> extKey = const Value.absent(),
              }) => ConversationCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                themeId: themeId,
                content: content,
                tags: tags,
                createTime: createTime,
                annotateTime: annotateTime,
                pinned: pinned,
                isDeleted: isDeleted,
                refIds: refIds,
                isRich: isRich,
                is_: is_,
                crossRefs: crossRefs,
                extKey: extKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> themeId = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> annotateTime = const Value.absent(),
                Value<String?> pinned = const Value.absent(),
                Value<String?> isDeleted = const Value.absent(),
                Value<String?> refIds = const Value.absent(),
                Value<String?> isRich = const Value.absent(),
                Value<String?> is_ = const Value.absent(),
                Value<String?> crossRefs = const Value.absent(),
                Value<String?> extKey = const Value.absent(),
              }) => ConversationCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                themeId: themeId,
                content: content,
                tags: tags,
                createTime: createTime,
                annotateTime: annotateTime,
                pinned: pinned,
                isDeleted: isDeleted,
                refIds: refIds,
                isRich: isRich,
                is_: is_,
                crossRefs: crossRefs,
                extKey: extKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationTable, ConversationData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ConversationTable,
                    ConversationData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationTable,
      ConversationData,
      $$ConversationTableFilterComposer,
      $$ConversationTableOrderingComposer,
      $$ConversationTableAnnotationComposer,
      $$ConversationTableCreateCompanionBuilder,
      $$ConversationTableUpdateCompanionBuilder,
      (
        ConversationData,
        BaseReferences<_$AppDatabase, $ConversationTable, ConversationData>,
      ),
      ConversationData,
      PrefetchHooks Function()
    >;
typedef $$ConversationThemeTableCreateCompanionBuilder =
    ConversationThemeCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> title,
      Value<String?> tags,
      Value<String?> createTime,
      Value<String?> updateTime,
      Value<String?> remark,
      Value<String?> parentId,
    });
typedef $$ConversationThemeTableUpdateCompanionBuilder =
    ConversationThemeCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> title,
      Value<String?> tags,
      Value<String?> createTime,
      Value<String?> updateTime,
      Value<String?> remark,
      Value<String?> parentId,
    });

class $$ConversationThemeTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationThemeTable> {
  $$ConversationThemeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationThemeTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationThemeTable> {
  $$ConversationThemeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationThemeTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationThemeTable> {
  $$ConversationThemeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);
}

class $$ConversationThemeTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationThemeTable,
          ConversationThemeData,
          $$ConversationThemeTableFilterComposer,
          $$ConversationThemeTableOrderingComposer,
          $$ConversationThemeTableAnnotationComposer,
          $$ConversationThemeTableCreateCompanionBuilder,
          $$ConversationThemeTableUpdateCompanionBuilder,
          (
            ConversationThemeData,
            BaseReferences<
              _$AppDatabase,
              $ConversationThemeTable,
              ConversationThemeData
            >,
          ),
          ConversationThemeData,
          PrefetchHooks Function()
        > {
  $$ConversationThemeTableTableManager(
    _$AppDatabase db,
    $ConversationThemeTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationThemeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationThemeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationThemeTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
              }) => ConversationThemeCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                title: title,
                tags: tags,
                createTime: createTime,
                updateTime: updateTime,
                remark: remark,
                parentId: parentId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
                Value<String?> updateTime = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
              }) => ConversationThemeCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                title: title,
                tags: tags,
                createTime: createTime,
                updateTime: updateTime,
                remark: remark,
                parentId: parentId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationThemeTable, ConversationThemeData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ConversationThemeTable,
                    ConversationThemeData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationThemeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationThemeTable,
      ConversationThemeData,
      $$ConversationThemeTableFilterComposer,
      $$ConversationThemeTableOrderingComposer,
      $$ConversationThemeTableAnnotationComposer,
      $$ConversationThemeTableCreateCompanionBuilder,
      $$ConversationThemeTableUpdateCompanionBuilder,
      (
        ConversationThemeData,
        BaseReferences<
          _$AppDatabase,
          $ConversationThemeTable,
          ConversationThemeData
        >,
      ),
      ConversationThemeData,
      PrefetchHooks Function()
    >;
typedef $$ConversationTagTableCreateCompanionBuilder =
    ConversationTagCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> color,
      Value<String?> scope,
      Value<String?> createTime,
    });
typedef $$ConversationTagTableUpdateCompanionBuilder =
    ConversationTagCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> color,
      Value<String?> scope,
      Value<String?> createTime,
    });

class $$ConversationTagTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationTagTable> {
  $$ConversationTagTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationTagTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationTagTable> {
  $$ConversationTagTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationTagTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationTagTable> {
  $$ConversationTagTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );
}

class $$ConversationTagTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationTagTable,
          ConversationTagData,
          $$ConversationTagTableFilterComposer,
          $$ConversationTagTableOrderingComposer,
          $$ConversationTagTableAnnotationComposer,
          $$ConversationTagTableCreateCompanionBuilder,
          $$ConversationTagTableUpdateCompanionBuilder,
          (
            ConversationTagData,
            BaseReferences<
              _$AppDatabase,
              $ConversationTagTable,
              ConversationTagData
            >,
          ),
          ConversationTagData,
          PrefetchHooks Function()
        > {
  $$ConversationTagTableTableManager(
    _$AppDatabase db,
    $ConversationTagTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationTagTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationTagTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationTagTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> scope = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
              }) => ConversationTagCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                color: color,
                scope: scope,
                createTime: createTime,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> scope = const Value.absent(),
                Value<String?> createTime = const Value.absent(),
              }) => ConversationTagCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                color: color,
                scope: scope,
                createTime: createTime,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationTagTable, ConversationTagData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ConversationTagTable,
                    ConversationTagData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationTagTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationTagTable,
      ConversationTagData,
      $$ConversationTagTableFilterComposer,
      $$ConversationTagTableOrderingComposer,
      $$ConversationTagTableAnnotationComposer,
      $$ConversationTagTableCreateCompanionBuilder,
      $$ConversationTagTableUpdateCompanionBuilder,
      (
        ConversationTagData,
        BaseReferences<
          _$AppDatabase,
          $ConversationTagTable,
          ConversationTagData
        >,
      ),
      ConversationTagData,
      PrefetchHooks Function()
    >;
typedef $$FileVaultConfigTableCreateCompanionBuilder =
    FileVaultConfigCompanion Function({
      required String key,
      Value<String?> value,
      Value<int?> id,
      Value<int> rowid,
    });
typedef $$FileVaultConfigTableUpdateCompanionBuilder =
    FileVaultConfigCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int?> id,
      Value<int> rowid,
    });

class $$FileVaultConfigTableFilterComposer
    extends Composer<_$AppDatabase, $FileVaultConfigTable> {
  $$FileVaultConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileVaultConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $FileVaultConfigTable> {
  $$FileVaultConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileVaultConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileVaultConfigTable> {
  $$FileVaultConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$FileVaultConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FileVaultConfigTable,
          FileVaultConfigData,
          $$FileVaultConfigTableFilterComposer,
          $$FileVaultConfigTableOrderingComposer,
          $$FileVaultConfigTableAnnotationComposer,
          $$FileVaultConfigTableCreateCompanionBuilder,
          $$FileVaultConfigTableUpdateCompanionBuilder,
          (
            FileVaultConfigData,
            BaseReferences<
              _$AppDatabase,
              $FileVaultConfigTable,
              FileVaultConfigData
            >,
          ),
          FileVaultConfigData,
          PrefetchHooks Function()
        > {
  $$FileVaultConfigTableTableManager(
    _$AppDatabase db,
    $FileVaultConfigTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileVaultConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileVaultConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileVaultConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileVaultConfigCompanion(
                key: key,
                value: value,
                id: id,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileVaultConfigCompanion.insert(
                key: key,
                value: value,
                id: id,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FileVaultConfigTable, FileVaultConfigData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $FileVaultConfigTable,
                    FileVaultConfigData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileVaultConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FileVaultConfigTable,
      FileVaultConfigData,
      $$FileVaultConfigTableFilterComposer,
      $$FileVaultConfigTableOrderingComposer,
      $$FileVaultConfigTableAnnotationComposer,
      $$FileVaultConfigTableCreateCompanionBuilder,
      $$FileVaultConfigTableUpdateCompanionBuilder,
      (
        FileVaultConfigData,
        BaseReferences<
          _$AppDatabase,
          $FileVaultConfigTable,
          FileVaultConfigData
        >,
      ),
      FileVaultConfigData,
      PrefetchHooks Function()
    >;
typedef $$FileVaultFilesTableCreateCompanionBuilder =
    FileVaultFilesCompanion Function({
      required String id,
      Value<String?> name,
      Value<String?> mime,
      Value<String?> ext,
      Value<String?> size,
      Value<String?> ciphertextPath,
      Value<String?> createdAt,
      Value<int> rowid,
    });
typedef $$FileVaultFilesTableUpdateCompanionBuilder =
    FileVaultFilesCompanion Function({
      Value<String> id,
      Value<String?> name,
      Value<String?> mime,
      Value<String?> ext,
      Value<String?> size,
      Value<String?> ciphertextPath,
      Value<String?> createdAt,
      Value<int> rowid,
    });

class $$FileVaultFilesTableFilterComposer
    extends Composer<_$AppDatabase, $FileVaultFilesTable> {
  $$FileVaultFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ciphertextPath => $composableBuilder(
    column: $table.ciphertextPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileVaultFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $FileVaultFilesTable> {
  $$FileVaultFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ciphertextPath => $composableBuilder(
    column: $table.ciphertextPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileVaultFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileVaultFilesTable> {
  $$FileVaultFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get ciphertextPath => $composableBuilder(
    column: $table.ciphertextPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FileVaultFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FileVaultFilesTable,
          FileVaultFile,
          $$FileVaultFilesTableFilterComposer,
          $$FileVaultFilesTableOrderingComposer,
          $$FileVaultFilesTableAnnotationComposer,
          $$FileVaultFilesTableCreateCompanionBuilder,
          $$FileVaultFilesTableUpdateCompanionBuilder,
          (
            FileVaultFile,
            BaseReferences<_$AppDatabase, $FileVaultFilesTable, FileVaultFile>,
          ),
          FileVaultFile,
          PrefetchHooks Function()
        > {
  $$FileVaultFilesTableTableManager(
    _$AppDatabase db,
    $FileVaultFilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileVaultFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileVaultFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileVaultFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<String?> size = const Value.absent(),
                Value<String?> ciphertextPath = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileVaultFilesCompanion(
                id: id,
                name: name,
                mime: mime,
                ext: ext,
                size: size,
                ciphertextPath: ciphertextPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> name = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<String?> size = const Value.absent(),
                Value<String?> ciphertextPath = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileVaultFilesCompanion.insert(
                id: id,
                name: name,
                mime: mime,
                ext: ext,
                size: size,
                ciphertextPath: ciphertextPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FileVaultFilesTable, FileVaultFile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FileVaultFilesTable,
                    FileVaultFile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileVaultFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FileVaultFilesTable,
      FileVaultFile,
      $$FileVaultFilesTableFilterComposer,
      $$FileVaultFilesTableOrderingComposer,
      $$FileVaultFilesTableAnnotationComposer,
      $$FileVaultFilesTableCreateCompanionBuilder,
      $$FileVaultFilesTableUpdateCompanionBuilder,
      (
        FileVaultFile,
        BaseReferences<_$AppDatabase, $FileVaultFilesTable, FileVaultFile>,
      ),
      FileVaultFile,
      PrefetchHooks Function()
    >;
typedef $$EbookBookshelfTableCreateCompanionBuilder =
    EbookBookshelfCompanion Function({
      required String filePath,
      Value<String?> name,
      Value<String?> format,
      Value<double?> percent,
      Value<String?> lastReadAt,
      Value<String?> addedAt,
      Value<String?> title,
      Value<String?> author,
      Value<String?> cover,
      Value<String?> contentHash,
      Value<int?> id,
      Value<int> rowid,
    });
typedef $$EbookBookshelfTableUpdateCompanionBuilder =
    EbookBookshelfCompanion Function({
      Value<String> filePath,
      Value<String?> name,
      Value<String?> format,
      Value<double?> percent,
      Value<String?> lastReadAt,
      Value<String?> addedAt,
      Value<String?> title,
      Value<String?> author,
      Value<String?> cover,
      Value<String?> contentHash,
      Value<int?> id,
      Value<int> rowid,
    });

class $$EbookBookshelfTableFilterComposer
    extends Composer<_$AppDatabase, $EbookBookshelfTable> {
  $$EbookBookshelfTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EbookBookshelfTableOrderingComposer
    extends Composer<_$AppDatabase, $EbookBookshelfTable> {
  $$EbookBookshelfTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EbookBookshelfTableAnnotationComposer
    extends Composer<_$AppDatabase, $EbookBookshelfTable> {
  $$EbookBookshelfTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<double> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<String> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$EbookBookshelfTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EbookBookshelfTable,
          EbookBookshelfData,
          $$EbookBookshelfTableFilterComposer,
          $$EbookBookshelfTableOrderingComposer,
          $$EbookBookshelfTableAnnotationComposer,
          $$EbookBookshelfTableCreateCompanionBuilder,
          $$EbookBookshelfTableUpdateCompanionBuilder,
          (
            EbookBookshelfData,
            BaseReferences<
              _$AppDatabase,
              $EbookBookshelfTable,
              EbookBookshelfData
            >,
          ),
          EbookBookshelfData,
          PrefetchHooks Function()
        > {
  $$EbookBookshelfTableTableManager(
    _$AppDatabase db,
    $EbookBookshelfTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EbookBookshelfTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EbookBookshelfTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EbookBookshelfTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<double?> percent = const Value.absent(),
                Value<String?> lastReadAt = const Value.absent(),
                Value<String?> addedAt = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EbookBookshelfCompanion(
                filePath: filePath,
                name: name,
                format: format,
                percent: percent,
                lastReadAt: lastReadAt,
                addedAt: addedAt,
                title: title,
                author: author,
                cover: cover,
                contentHash: contentHash,
                id: id,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                Value<String?> name = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<double?> percent = const Value.absent(),
                Value<String?> lastReadAt = const Value.absent(),
                Value<String?> addedAt = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EbookBookshelfCompanion.insert(
                filePath: filePath,
                name: name,
                format: format,
                percent: percent,
                lastReadAt: lastReadAt,
                addedAt: addedAt,
                title: title,
                author: author,
                cover: cover,
                contentHash: contentHash,
                id: id,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EbookBookshelfTable, EbookBookshelfData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EbookBookshelfTable,
                    EbookBookshelfData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EbookBookshelfTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EbookBookshelfTable,
      EbookBookshelfData,
      $$EbookBookshelfTableFilterComposer,
      $$EbookBookshelfTableOrderingComposer,
      $$EbookBookshelfTableAnnotationComposer,
      $$EbookBookshelfTableCreateCompanionBuilder,
      $$EbookBookshelfTableUpdateCompanionBuilder,
      (
        EbookBookshelfData,
        BaseReferences<_$AppDatabase, $EbookBookshelfTable, EbookBookshelfData>,
      ),
      EbookBookshelfData,
      PrefetchHooks Function()
    >;
typedef $$EbookProgressTableCreateCompanionBuilder =
    EbookProgressCompanion Function({
      required String filePath,
      Value<String?> format,
      Value<String?> cfi,
      Value<double?> percent,
      Value<String?> updatedAt,
      Value<String?> contentHash,
      Value<int?> id,
      Value<int> rowid,
    });
typedef $$EbookProgressTableUpdateCompanionBuilder =
    EbookProgressCompanion Function({
      Value<String> filePath,
      Value<String?> format,
      Value<String?> cfi,
      Value<double?> percent,
      Value<String?> updatedAt,
      Value<String?> contentHash,
      Value<int?> id,
      Value<int> rowid,
    });

class $$EbookProgressTableFilterComposer
    extends Composer<_$AppDatabase, $EbookProgressTable> {
  $$EbookProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cfi => $composableBuilder(
    column: $table.cfi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EbookProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $EbookProgressTable> {
  $$EbookProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cfi => $composableBuilder(
    column: $table.cfi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EbookProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $EbookProgressTable> {
  $$EbookProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get cfi =>
      $composableBuilder(column: $table.cfi, builder: (column) => column);

  GeneratedColumn<double> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$EbookProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EbookProgressTable,
          EbookProgressData,
          $$EbookProgressTableFilterComposer,
          $$EbookProgressTableOrderingComposer,
          $$EbookProgressTableAnnotationComposer,
          $$EbookProgressTableCreateCompanionBuilder,
          $$EbookProgressTableUpdateCompanionBuilder,
          (
            EbookProgressData,
            BaseReferences<
              _$AppDatabase,
              $EbookProgressTable,
              EbookProgressData
            >,
          ),
          EbookProgressData,
          PrefetchHooks Function()
        > {
  $$EbookProgressTableTableManager(_$AppDatabase db, $EbookProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EbookProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EbookProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EbookProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> cfi = const Value.absent(),
                Value<double?> percent = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EbookProgressCompanion(
                filePath: filePath,
                format: format,
                cfi: cfi,
                percent: percent,
                updatedAt: updatedAt,
                contentHash: contentHash,
                id: id,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                Value<String?> format = const Value.absent(),
                Value<String?> cfi = const Value.absent(),
                Value<double?> percent = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EbookProgressCompanion.insert(
                filePath: filePath,
                format: format,
                cfi: cfi,
                percent: percent,
                updatedAt: updatedAt,
                contentHash: contentHash,
                id: id,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EbookProgressTable, EbookProgressData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EbookProgressTable,
                    EbookProgressData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EbookProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EbookProgressTable,
      EbookProgressData,
      $$EbookProgressTableFilterComposer,
      $$EbookProgressTableOrderingComposer,
      $$EbookProgressTableAnnotationComposer,
      $$EbookProgressTableCreateCompanionBuilder,
      $$EbookProgressTableUpdateCompanionBuilder,
      (
        EbookProgressData,
        BaseReferences<_$AppDatabase, $EbookProgressTable, EbookProgressData>,
      ),
      EbookProgressData,
      PrefetchHooks Function()
    >;
typedef $$EbookBookmarkTableCreateCompanionBuilder =
    EbookBookmarkCompanion Function({
      Value<int> id,
      Value<String?> filePath,
      Value<String?> format,
      Value<String?> cfi,
      Value<String?> label,
      Value<String?> percent,
      Value<String?> createdAt,
      Value<String?> contentHash,
    });
typedef $$EbookBookmarkTableUpdateCompanionBuilder =
    EbookBookmarkCompanion Function({
      Value<int> id,
      Value<String?> filePath,
      Value<String?> format,
      Value<String?> cfi,
      Value<String?> label,
      Value<String?> percent,
      Value<String?> createdAt,
      Value<String?> contentHash,
    });

class $$EbookBookmarkTableFilterComposer
    extends Composer<_$AppDatabase, $EbookBookmarkTable> {
  $$EbookBookmarkTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cfi => $composableBuilder(
    column: $table.cfi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EbookBookmarkTableOrderingComposer
    extends Composer<_$AppDatabase, $EbookBookmarkTable> {
  $$EbookBookmarkTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cfi => $composableBuilder(
    column: $table.cfi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EbookBookmarkTableAnnotationComposer
    extends Composer<_$AppDatabase, $EbookBookmarkTable> {
  $$EbookBookmarkTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get cfi =>
      $composableBuilder(column: $table.cfi, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );
}

class $$EbookBookmarkTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EbookBookmarkTable,
          EbookBookmarkData,
          $$EbookBookmarkTableFilterComposer,
          $$EbookBookmarkTableOrderingComposer,
          $$EbookBookmarkTableAnnotationComposer,
          $$EbookBookmarkTableCreateCompanionBuilder,
          $$EbookBookmarkTableUpdateCompanionBuilder,
          (
            EbookBookmarkData,
            BaseReferences<
              _$AppDatabase,
              $EbookBookmarkTable,
              EbookBookmarkData
            >,
          ),
          EbookBookmarkData,
          PrefetchHooks Function()
        > {
  $$EbookBookmarkTableTableManager(_$AppDatabase db, $EbookBookmarkTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EbookBookmarkTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EbookBookmarkTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EbookBookmarkTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> cfi = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> percent = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
              }) => EbookBookmarkCompanion(
                id: id,
                filePath: filePath,
                format: format,
                cfi: cfi,
                label: label,
                percent: percent,
                createdAt: createdAt,
                contentHash: contentHash,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> cfi = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> percent = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
              }) => EbookBookmarkCompanion.insert(
                id: id,
                filePath: filePath,
                format: format,
                cfi: cfi,
                label: label,
                percent: percent,
                createdAt: createdAt,
                contentHash: contentHash,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EbookBookmarkTable, EbookBookmarkData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EbookBookmarkTable,
                    EbookBookmarkData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EbookBookmarkTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EbookBookmarkTable,
      EbookBookmarkData,
      $$EbookBookmarkTableFilterComposer,
      $$EbookBookmarkTableOrderingComposer,
      $$EbookBookmarkTableAnnotationComposer,
      $$EbookBookmarkTableCreateCompanionBuilder,
      $$EbookBookmarkTableUpdateCompanionBuilder,
      (
        EbookBookmarkData,
        BaseReferences<_$AppDatabase, $EbookBookmarkTable, EbookBookmarkData>,
      ),
      EbookBookmarkData,
      PrefetchHooks Function()
    >;
typedef $$EbookAnnotationTableCreateCompanionBuilder =
    EbookAnnotationCompanion Function({
      Value<int> id,
      Value<String?> filePath,
      Value<String?> format,
      Value<String?> anchor,
      Value<String?> annotatedText,
      Value<String?> note,
      Value<String?> color,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> type,
      Value<String?> contentHash,
    });
typedef $$EbookAnnotationTableUpdateCompanionBuilder =
    EbookAnnotationCompanion Function({
      Value<int> id,
      Value<String?> filePath,
      Value<String?> format,
      Value<String?> anchor,
      Value<String?> annotatedText,
      Value<String?> note,
      Value<String?> color,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> type,
      Value<String?> contentHash,
    });

class $$EbookAnnotationTableFilterComposer
    extends Composer<_$AppDatabase, $EbookAnnotationTable> {
  $$EbookAnnotationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotatedText => $composableBuilder(
    column: $table.annotatedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EbookAnnotationTableOrderingComposer
    extends Composer<_$AppDatabase, $EbookAnnotationTable> {
  $$EbookAnnotationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotatedText => $composableBuilder(
    column: $table.annotatedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EbookAnnotationTableAnnotationComposer
    extends Composer<_$AppDatabase, $EbookAnnotationTable> {
  $$EbookAnnotationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get anchor =>
      $composableBuilder(column: $table.anchor, builder: (column) => column);

  GeneratedColumn<String> get annotatedText => $composableBuilder(
    column: $table.annotatedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );
}

class $$EbookAnnotationTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EbookAnnotationTable,
          EbookAnnotationData,
          $$EbookAnnotationTableFilterComposer,
          $$EbookAnnotationTableOrderingComposer,
          $$EbookAnnotationTableAnnotationComposer,
          $$EbookAnnotationTableCreateCompanionBuilder,
          $$EbookAnnotationTableUpdateCompanionBuilder,
          (
            EbookAnnotationData,
            BaseReferences<
              _$AppDatabase,
              $EbookAnnotationTable,
              EbookAnnotationData
            >,
          ),
          EbookAnnotationData,
          PrefetchHooks Function()
        > {
  $$EbookAnnotationTableTableManager(
    _$AppDatabase db,
    $EbookAnnotationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EbookAnnotationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EbookAnnotationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EbookAnnotationTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> anchor = const Value.absent(),
                Value<String?> annotatedText = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
              }) => EbookAnnotationCompanion(
                id: id,
                filePath: filePath,
                format: format,
                anchor: anchor,
                annotatedText: annotatedText,
                note: note,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                type: type,
                contentHash: contentHash,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> anchor = const Value.absent(),
                Value<String?> annotatedText = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
              }) => EbookAnnotationCompanion.insert(
                id: id,
                filePath: filePath,
                format: format,
                anchor: anchor,
                annotatedText: annotatedText,
                note: note,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                type: type,
                contentHash: contentHash,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EbookAnnotationTable, EbookAnnotationData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $EbookAnnotationTable,
                    EbookAnnotationData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EbookAnnotationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EbookAnnotationTable,
      EbookAnnotationData,
      $$EbookAnnotationTableFilterComposer,
      $$EbookAnnotationTableOrderingComposer,
      $$EbookAnnotationTableAnnotationComposer,
      $$EbookAnnotationTableCreateCompanionBuilder,
      $$EbookAnnotationTableUpdateCompanionBuilder,
      (
        EbookAnnotationData,
        BaseReferences<
          _$AppDatabase,
          $EbookAnnotationTable,
          EbookAnnotationData
        >,
      ),
      EbookAnnotationData,
      PrefetchHooks Function()
    >;
typedef $$EbookCategoryTableCreateCompanionBuilder =
    EbookCategoryCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> createdAt,
      Value<String?> color,
    });
typedef $$EbookCategoryTableUpdateCompanionBuilder =
    EbookCategoryCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> createdAt,
      Value<String?> color,
    });

class $$EbookCategoryTableFilterComposer
    extends Composer<_$AppDatabase, $EbookCategoryTable> {
  $$EbookCategoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EbookCategoryTableOrderingComposer
    extends Composer<_$AppDatabase, $EbookCategoryTable> {
  $$EbookCategoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EbookCategoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $EbookCategoryTable> {
  $$EbookCategoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$EbookCategoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EbookCategoryTable,
          EbookCategoryData,
          $$EbookCategoryTableFilterComposer,
          $$EbookCategoryTableOrderingComposer,
          $$EbookCategoryTableAnnotationComposer,
          $$EbookCategoryTableCreateCompanionBuilder,
          $$EbookCategoryTableUpdateCompanionBuilder,
          (
            EbookCategoryData,
            BaseReferences<
              _$AppDatabase,
              $EbookCategoryTable,
              EbookCategoryData
            >,
          ),
          EbookCategoryData,
          PrefetchHooks Function()
        > {
  $$EbookCategoryTableTableManager(_$AppDatabase db, $EbookCategoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EbookCategoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EbookCategoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EbookCategoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> color = const Value.absent(),
              }) => EbookCategoryCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                color: color,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> createdAt = const Value.absent(),
                Value<String?> color = const Value.absent(),
              }) => EbookCategoryCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                color: color,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EbookCategoryTable, EbookCategoryData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EbookCategoryTable,
                    EbookCategoryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EbookCategoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EbookCategoryTable,
      EbookCategoryData,
      $$EbookCategoryTableFilterComposer,
      $$EbookCategoryTableOrderingComposer,
      $$EbookCategoryTableAnnotationComposer,
      $$EbookCategoryTableCreateCompanionBuilder,
      $$EbookCategoryTableUpdateCompanionBuilder,
      (
        EbookCategoryData,
        BaseReferences<_$AppDatabase, $EbookCategoryTable, EbookCategoryData>,
      ),
      EbookCategoryData,
      PrefetchHooks Function()
    >;
typedef $$EbookBookCategoryTableCreateCompanionBuilder =
    EbookBookCategoryCompanion Function({
      required String bookPath,
      required int categoryId,
      Value<int?> id,
      Value<int> rowid,
    });
typedef $$EbookBookCategoryTableUpdateCompanionBuilder =
    EbookBookCategoryCompanion Function({
      Value<String> bookPath,
      Value<int> categoryId,
      Value<int?> id,
      Value<int> rowid,
    });

class $$EbookBookCategoryTableFilterComposer
    extends Composer<_$AppDatabase, $EbookBookCategoryTable> {
  $$EbookBookCategoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookPath => $composableBuilder(
    column: $table.bookPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EbookBookCategoryTableOrderingComposer
    extends Composer<_$AppDatabase, $EbookBookCategoryTable> {
  $$EbookBookCategoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookPath => $composableBuilder(
    column: $table.bookPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EbookBookCategoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $EbookBookCategoryTable> {
  $$EbookBookCategoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookPath =>
      $composableBuilder(column: $table.bookPath, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$EbookBookCategoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EbookBookCategoryTable,
          EbookBookCategoryData,
          $$EbookBookCategoryTableFilterComposer,
          $$EbookBookCategoryTableOrderingComposer,
          $$EbookBookCategoryTableAnnotationComposer,
          $$EbookBookCategoryTableCreateCompanionBuilder,
          $$EbookBookCategoryTableUpdateCompanionBuilder,
          (
            EbookBookCategoryData,
            BaseReferences<
              _$AppDatabase,
              $EbookBookCategoryTable,
              EbookBookCategoryData
            >,
          ),
          EbookBookCategoryData,
          PrefetchHooks Function()
        > {
  $$EbookBookCategoryTableTableManager(
    _$AppDatabase db,
    $EbookBookCategoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EbookBookCategoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EbookBookCategoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EbookBookCategoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookPath = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EbookBookCategoryCompanion(
                bookPath: bookPath,
                categoryId: categoryId,
                id: id,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookPath,
                required int categoryId,
                Value<int?> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EbookBookCategoryCompanion.insert(
                bookPath: bookPath,
                categoryId: categoryId,
                id: id,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EbookBookCategoryTable, EbookBookCategoryData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $EbookBookCategoryTable,
                    EbookBookCategoryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EbookBookCategoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EbookBookCategoryTable,
      EbookBookCategoryData,
      $$EbookBookCategoryTableFilterComposer,
      $$EbookBookCategoryTableOrderingComposer,
      $$EbookBookCategoryTableAnnotationComposer,
      $$EbookBookCategoryTableCreateCompanionBuilder,
      $$EbookBookCategoryTableUpdateCompanionBuilder,
      (
        EbookBookCategoryData,
        BaseReferences<
          _$AppDatabase,
          $EbookBookCategoryTable,
          EbookBookCategoryData
        >,
      ),
      EbookBookCategoryData,
      PrefetchHooks Function()
    >;
typedef $$EbookBgImageTableCreateCompanionBuilder =
    EbookBgImageCompanion Function({
      Value<int> id,
      required String imagePath,
      Value<String?> dataUrl,
      Value<String?> createdAt,
    });
typedef $$EbookBgImageTableUpdateCompanionBuilder =
    EbookBgImageCompanion Function({
      Value<int> id,
      Value<String> imagePath,
      Value<String?> dataUrl,
      Value<String?> createdAt,
    });

class $$EbookBgImageTableFilterComposer
    extends Composer<_$AppDatabase, $EbookBgImageTable> {
  $$EbookBgImageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataUrl => $composableBuilder(
    column: $table.dataUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EbookBgImageTableOrderingComposer
    extends Composer<_$AppDatabase, $EbookBgImageTable> {
  $$EbookBgImageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataUrl => $composableBuilder(
    column: $table.dataUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EbookBgImageTableAnnotationComposer
    extends Composer<_$AppDatabase, $EbookBgImageTable> {
  $$EbookBgImageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get dataUrl =>
      $composableBuilder(column: $table.dataUrl, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EbookBgImageTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EbookBgImageTable,
          EbookBgImageData,
          $$EbookBgImageTableFilterComposer,
          $$EbookBgImageTableOrderingComposer,
          $$EbookBgImageTableAnnotationComposer,
          $$EbookBgImageTableCreateCompanionBuilder,
          $$EbookBgImageTableUpdateCompanionBuilder,
          (
            EbookBgImageData,
            BaseReferences<_$AppDatabase, $EbookBgImageTable, EbookBgImageData>,
          ),
          EbookBgImageData,
          PrefetchHooks Function()
        > {
  $$EbookBgImageTableTableManager(_$AppDatabase db, $EbookBgImageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EbookBgImageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EbookBgImageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EbookBgImageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String?> dataUrl = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
              }) => EbookBgImageCompanion(
                id: id,
                imagePath: imagePath,
                dataUrl: dataUrl,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String imagePath,
                Value<String?> dataUrl = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
              }) => EbookBgImageCompanion.insert(
                id: id,
                imagePath: imagePath,
                dataUrl: dataUrl,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EbookBgImageTable, EbookBgImageData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EbookBgImageTable,
                    EbookBgImageData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EbookBgImageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EbookBgImageTable,
      EbookBgImageData,
      $$EbookBgImageTableFilterComposer,
      $$EbookBgImageTableOrderingComposer,
      $$EbookBgImageTableAnnotationComposer,
      $$EbookBgImageTableCreateCompanionBuilder,
      $$EbookBgImageTableUpdateCompanionBuilder,
      (
        EbookBgImageData,
        BaseReferences<_$AppDatabase, $EbookBgImageTable, EbookBgImageData>,
      ),
      EbookBgImageData,
      PrefetchHooks Function()
    >;
typedef $$ScreenshotsTableCreateCompanionBuilder =
    ScreenshotsCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> path,
      Value<String?> action,
      Value<String?> width,
      Value<String?> height,
      Value<String?> stickerStatus,
    });
typedef $$ScreenshotsTableUpdateCompanionBuilder =
    ScreenshotsCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String?> value,
      Value<String?> createdAt,
      Value<String?> path,
      Value<String?> action,
      Value<String?> width,
      Value<String?> height,
      Value<String?> stickerStatus,
    });

class $$ScreenshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ScreenshotsTable> {
  $$ScreenshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stickerStatus => $composableBuilder(
    column: $table.stickerStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScreenshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScreenshotsTable> {
  $$ScreenshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stickerStatus => $composableBuilder(
    column: $table.stickerStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScreenshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScreenshotsTable> {
  $$ScreenshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<String> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get stickerStatus => $composableBuilder(
    column: $table.stickerStatus,
    builder: (column) => column,
  );
}

class $$ScreenshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScreenshotsTable,
          Screenshot,
          $$ScreenshotsTableFilterComposer,
          $$ScreenshotsTableOrderingComposer,
          $$ScreenshotsTableAnnotationComposer,
          $$ScreenshotsTableCreateCompanionBuilder,
          $$ScreenshotsTableUpdateCompanionBuilder,
          (
            Screenshot,
            BaseReferences<_$AppDatabase, $ScreenshotsTable, Screenshot>,
          ),
          Screenshot,
          PrefetchHooks Function()
        > {
  $$ScreenshotsTableTableManager(_$AppDatabase db, $ScreenshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScreenshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScreenshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScreenshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<String?> action = const Value.absent(),
                Value<String?> width = const Value.absent(),
                Value<String?> height = const Value.absent(),
                Value<String?> stickerStatus = const Value.absent(),
              }) => ScreenshotsCompanion(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                path: path,
                action: action,
                width: width,
                height: height,
                stickerStatus: stickerStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<String?> action = const Value.absent(),
                Value<String?> width = const Value.absent(),
                Value<String?> height = const Value.absent(),
                Value<String?> stickerStatus = const Value.absent(),
              }) => ScreenshotsCompanion.insert(
                id: id,
                name: name,
                value: value,
                createdAt: createdAt,
                path: path,
                action: action,
                width: width,
                height: height,
                stickerStatus: stickerStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScreenshotsTable, Screenshot>(table),
                  BaseReferences<_$AppDatabase, $ScreenshotsTable, Screenshot>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScreenshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScreenshotsTable,
      Screenshot,
      $$ScreenshotsTableFilterComposer,
      $$ScreenshotsTableOrderingComposer,
      $$ScreenshotsTableAnnotationComposer,
      $$ScreenshotsTableCreateCompanionBuilder,
      $$ScreenshotsTableUpdateCompanionBuilder,
      (
        Screenshot,
        BaseReferences<_$AppDatabase, $ScreenshotsTable, Screenshot>,
      ),
      Screenshot,
      PrefetchHooks Function()
    >;
typedef $$CountdownTableCreateCompanionBuilder = CountdownCompanion Function({
  required String key,
  Value<String?> name,
  Value<String?> mode,
  Value<int?> endTime,
  Value<int?> duration,
  Value<int?> pausedRemaining,
  Value<String?> status,
  Value<String?> notify,
  Value<String?> sound,
  Value<String?> color,
  Value<int?> createdAt,
  Value<int?> finishedAt,
  Value<int> rowid,
});
typedef $$CountdownTableUpdateCompanionBuilder = CountdownCompanion Function({
  Value<String> key,
  Value<String?> name,
  Value<String?> mode,
  Value<int?> endTime,
  Value<int?> duration,
  Value<int?> pausedRemaining,
  Value<String?> status,
  Value<String?> notify,
  Value<String?> sound,
  Value<String?> color,
  Value<int?> createdAt,
  Value<int?> finishedAt,
  Value<int> rowid,
});

class $$CountdownTableFilterComposer
    extends Composer<_$AppDatabase, $CountdownTable> {
  $$CountdownTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedRemaining => $composableBuilder(
    column: $table.pausedRemaining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CountdownTableOrderingComposer
    extends Composer<_$AppDatabase, $CountdownTable> {
  $$CountdownTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedRemaining => $composableBuilder(
    column: $table.pausedRemaining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CountdownTableAnnotationComposer
    extends Composer<_$AppDatabase, $CountdownTable> {
  $$CountdownTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get pausedRemaining => $composableBuilder(
    column: $table.pausedRemaining,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notify =>
      $composableBuilder(column: $table.notify, builder: (column) => column);

  GeneratedColumn<String> get sound =>
      $composableBuilder(column: $table.sound, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );
}

class $$CountdownTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CountdownTable,
          CountdownData,
          $$CountdownTableFilterComposer,
          $$CountdownTableOrderingComposer,
          $$CountdownTableAnnotationComposer,
          $$CountdownTableCreateCompanionBuilder,
          $$CountdownTableUpdateCompanionBuilder,
          (
            CountdownData,
            BaseReferences<_$AppDatabase, $CountdownTable, CountdownData>,
          ),
          CountdownData,
          PrefetchHooks Function()
        > {
  $$CountdownTableTableManager(_$AppDatabase db, $CountdownTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountdownTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountdownTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountdownTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<int?> endTime = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<int?> pausedRemaining = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> notify = const Value.absent(),
                Value<String?> sound = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CountdownCompanion(
                key: key,
                name: name,
                mode: mode,
                endTime: endTime,
                duration: duration,
                pausedRemaining: pausedRemaining,
                status: status,
                notify: notify,
                sound: sound,
                color: color,
                createdAt: createdAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> name = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<int?> endTime = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<int?> pausedRemaining = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> notify = const Value.absent(),
                Value<String?> sound = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CountdownCompanion.insert(
                key: key,
                name: name,
                mode: mode,
                endTime: endTime,
                duration: duration,
                pausedRemaining: pausedRemaining,
                status: status,
                notify: notify,
                sound: sound,
                color: color,
                createdAt: createdAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CountdownTable, CountdownData>(table),
                  BaseReferences<_$AppDatabase, $CountdownTable, CountdownData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CountdownTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CountdownTable,
      CountdownData,
      $$CountdownTableFilterComposer,
      $$CountdownTableOrderingComposer,
      $$CountdownTableAnnotationComposer,
      $$CountdownTableCreateCompanionBuilder,
      $$CountdownTableUpdateCompanionBuilder,
      (
        CountdownData,
        BaseReferences<_$AppDatabase, $CountdownTable, CountdownData>,
      ),
      CountdownData,
      PrefetchHooks Function()
    >;
typedef $$QrHistoryTableCreateCompanionBuilder = QrHistoryCompanion Function({
  required String key,
  Value<String?> source,
  Value<String?> type,
  Value<String?> content,
  Value<String?> style,
  Value<String?> note,
  Value<String?> createdAt,
  Value<int> rowid,
});
typedef $$QrHistoryTableUpdateCompanionBuilder = QrHistoryCompanion Function({
  Value<String> key,
  Value<String?> source,
  Value<String?> type,
  Value<String?> content,
  Value<String?> style,
  Value<String?> note,
  Value<String?> createdAt,
  Value<int> rowid,
});

class $$QrHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $QrHistoryTable> {
  $$QrHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QrHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $QrHistoryTable> {
  $$QrHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QrHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $QrHistoryTable> {
  $$QrHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QrHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QrHistoryTable,
          QrHistoryData,
          $$QrHistoryTableFilterComposer,
          $$QrHistoryTableOrderingComposer,
          $$QrHistoryTableAnnotationComposer,
          $$QrHistoryTableCreateCompanionBuilder,
          $$QrHistoryTableUpdateCompanionBuilder,
          (
            QrHistoryData,
            BaseReferences<_$AppDatabase, $QrHistoryTable, QrHistoryData>,
          ),
          QrHistoryData,
          PrefetchHooks Function()
        > {
  $$QrHistoryTableTableManager(_$AppDatabase db, $QrHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QrHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QrHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QrHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> style = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QrHistoryCompanion(
                key: key,
                source: source,
                type: type,
                content: content,
                style: style,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> source = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> style = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QrHistoryCompanion.insert(
                key: key,
                source: source,
                type: type,
                content: content,
                style: style,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QrHistoryTable, QrHistoryData>(table),
                  BaseReferences<_$AppDatabase, $QrHistoryTable, QrHistoryData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QrHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QrHistoryTable,
      QrHistoryData,
      $$QrHistoryTableFilterComposer,
      $$QrHistoryTableOrderingComposer,
      $$QrHistoryTableAnnotationComposer,
      $$QrHistoryTableCreateCompanionBuilder,
      $$QrHistoryTableUpdateCompanionBuilder,
      (
        QrHistoryData,
        BaseReferences<_$AppDatabase, $QrHistoryTable, QrHistoryData>,
      ),
      QrHistoryData,
      PrefetchHooks Function()
    >;
typedef $$QrTemplateTableCreateCompanionBuilder = QrTemplateCompanion Function({
  required String key,
  Value<String?> name,
  Value<String?> source,
  Value<String?> type,
  Value<String?> content,
  Value<String?> style,
  Value<String?> createdAt,
  Value<int> rowid,
});
typedef $$QrTemplateTableUpdateCompanionBuilder = QrTemplateCompanion Function({
  Value<String> key,
  Value<String?> name,
  Value<String?> source,
  Value<String?> type,
  Value<String?> content,
  Value<String?> style,
  Value<String?> createdAt,
  Value<int> rowid,
});

class $$QrTemplateTableFilterComposer
    extends Composer<_$AppDatabase, $QrTemplateTable> {
  $$QrTemplateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QrTemplateTableOrderingComposer
    extends Composer<_$AppDatabase, $QrTemplateTable> {
  $$QrTemplateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QrTemplateTableAnnotationComposer
    extends Composer<_$AppDatabase, $QrTemplateTable> {
  $$QrTemplateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QrTemplateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QrTemplateTable,
          QrTemplateData,
          $$QrTemplateTableFilterComposer,
          $$QrTemplateTableOrderingComposer,
          $$QrTemplateTableAnnotationComposer,
          $$QrTemplateTableCreateCompanionBuilder,
          $$QrTemplateTableUpdateCompanionBuilder,
          (
            QrTemplateData,
            BaseReferences<_$AppDatabase, $QrTemplateTable, QrTemplateData>,
          ),
          QrTemplateData,
          PrefetchHooks Function()
        > {
  $$QrTemplateTableTableManager(_$AppDatabase db, $QrTemplateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QrTemplateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QrTemplateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QrTemplateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> style = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QrTemplateCompanion(
                key: key,
                name: name,
                source: source,
                type: type,
                content: content,
                style: style,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> name = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> style = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QrTemplateCompanion.insert(
                key: key,
                name: name,
                source: source,
                type: type,
                content: content,
                style: style,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QrTemplateTable, QrTemplateData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $QrTemplateTable,
                    QrTemplateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QrTemplateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QrTemplateTable,
      QrTemplateData,
      $$QrTemplateTableFilterComposer,
      $$QrTemplateTableOrderingComposer,
      $$QrTemplateTableAnnotationComposer,
      $$QrTemplateTableCreateCompanionBuilder,
      $$QrTemplateTableUpdateCompanionBuilder,
      (
        QrTemplateData,
        BaseReferences<_$AppDatabase, $QrTemplateTable, QrTemplateData>,
      ),
      QrTemplateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HabitDefTableTableManager get habitDef =>
      $$HabitDefTableTableManager(_db, _db.habitDef);
  $$HabitCheckinTableTableManager get habitCheckin =>
      $$HabitCheckinTableTableManager(_db, _db.habitCheckin);
  $$TodoListTableTableManager get todoList =>
      $$TodoListTableTableManager(_db, _db.todoList);
  $$TodoTagsTableTableManager get todoTags =>
      $$TodoTagsTableTableManager(_db, _db.todoTags);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$NoteBookTableTableManager get noteBook =>
      $$NoteBookTableTableManager(_db, _db.noteBook);
  $$BasicInfoTableTableManager get basicInfo =>
      $$BasicInfoTableTableManager(_db, _db.basicInfo);
  $$PomodoroStatusTableTableManager get pomodoroStatus =>
      $$PomodoroStatusTableTableManager(_db, _db.pomodoroStatus);
  $$PomodoroMiniConfigTableTableManager get pomodoroMiniConfig =>
      $$PomodoroMiniConfigTableTableManager(_db, _db.pomodoroMiniConfig);
  $$ConversationTableTableManager get conversation =>
      $$ConversationTableTableManager(_db, _db.conversation);
  $$ConversationThemeTableTableManager get conversationTheme =>
      $$ConversationThemeTableTableManager(_db, _db.conversationTheme);
  $$ConversationTagTableTableManager get conversationTag =>
      $$ConversationTagTableTableManager(_db, _db.conversationTag);
  $$FileVaultConfigTableTableManager get fileVaultConfig =>
      $$FileVaultConfigTableTableManager(_db, _db.fileVaultConfig);
  $$FileVaultFilesTableTableManager get fileVaultFiles =>
      $$FileVaultFilesTableTableManager(_db, _db.fileVaultFiles);
  $$EbookBookshelfTableTableManager get ebookBookshelf =>
      $$EbookBookshelfTableTableManager(_db, _db.ebookBookshelf);
  $$EbookProgressTableTableManager get ebookProgress =>
      $$EbookProgressTableTableManager(_db, _db.ebookProgress);
  $$EbookBookmarkTableTableManager get ebookBookmark =>
      $$EbookBookmarkTableTableManager(_db, _db.ebookBookmark);
  $$EbookAnnotationTableTableManager get ebookAnnotation =>
      $$EbookAnnotationTableTableManager(_db, _db.ebookAnnotation);
  $$EbookCategoryTableTableManager get ebookCategory =>
      $$EbookCategoryTableTableManager(_db, _db.ebookCategory);
  $$EbookBookCategoryTableTableManager get ebookBookCategory =>
      $$EbookBookCategoryTableTableManager(_db, _db.ebookBookCategory);
  $$EbookBgImageTableTableManager get ebookBgImage =>
      $$EbookBgImageTableTableManager(_db, _db.ebookBgImage);
  $$ScreenshotsTableTableManager get screenshots =>
      $$ScreenshotsTableTableManager(_db, _db.screenshots);
  $$CountdownTableTableManager get countdown =>
      $$CountdownTableTableManager(_db, _db.countdown);
  $$QrHistoryTableTableManager get qrHistory =>
      $$QrHistoryTableTableManager(_db, _db.qrHistory);
  $$QrTemplateTableTableManager get qrTemplate =>
      $$QrTemplateTableTableManager(_db, _db.qrTemplate);
}
