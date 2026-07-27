// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UnitsTable extends Units with TableInfo<$UnitsTable, Unit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grammarTagsMeta = const VerificationMeta(
    'grammarTags',
  );
  @override
  late final GeneratedColumn<String> grammarTags = GeneratedColumn<String>(
    'grammar_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isExamPrepMeta = const VerificationMeta(
    'isExamPrep',
  );
  @override
  late final GeneratedColumn<bool> isExamPrep = GeneratedColumn<bool>(
    'is_exam_prep',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_exam_prep" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lessonCountMeta = const VerificationMeta(
    'lessonCount',
  );
  @override
  late final GeneratedColumn<int> lessonCount = GeneratedColumn<int>(
    'lesson_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    phase,
    orderIndex,
    grammarTags,
    isExamPrep,
    lessonCount,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'units';
  @override
  VerificationContext validateIntegrity(
    Insertable<Unit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('grammar_tags')) {
      context.handle(
        _grammarTagsMeta,
        grammarTags.isAcceptableOrUnknown(
          data['grammar_tags']!,
          _grammarTagsMeta,
        ),
      );
    }
    if (data.containsKey('is_exam_prep')) {
      context.handle(
        _isExamPrepMeta,
        isExamPrep.isAcceptableOrUnknown(
          data['is_exam_prep']!,
          _isExamPrepMeta,
        ),
      );
    }
    if (data.containsKey('lesson_count')) {
      context.handle(
        _lessonCountMeta,
        lessonCount.isAcceptableOrUnknown(
          data['lesson_count']!,
          _lessonCountMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Unit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Unit(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      phase:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}phase'],
          )!,
      orderIndex:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}order_index'],
          )!,
      grammarTags:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}grammar_tags'],
          )!,
      isExamPrep:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_exam_prep'],
          )!,
      lessonCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_count'],
      ),
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
    );
  }

  @override
  $UnitsTable createAlias(String alias) {
    return $UnitsTable(attachedDatabase, alias);
  }
}

class Unit extends DataClass implements Insertable<Unit> {
  final int id;
  final String title;
  final String description;
  final String phase;
  final int orderIndex;
  final String grammarTags;
  final bool isExamPrep;
  final int? lessonCount;
  final bool isActive;
  const Unit({
    required this.id,
    required this.title,
    required this.description,
    required this.phase,
    required this.orderIndex,
    required this.grammarTags,
    required this.isExamPrep,
    this.lessonCount,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['phase'] = Variable<String>(phase);
    map['order_index'] = Variable<int>(orderIndex);
    map['grammar_tags'] = Variable<String>(grammarTags);
    map['is_exam_prep'] = Variable<bool>(isExamPrep);
    if (!nullToAbsent || lessonCount != null) {
      map['lesson_count'] = Variable<int>(lessonCount);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  UnitsCompanion toCompanion(bool nullToAbsent) {
    return UnitsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      phase: Value(phase),
      orderIndex: Value(orderIndex),
      grammarTags: Value(grammarTags),
      isExamPrep: Value(isExamPrep),
      lessonCount:
          lessonCount == null && nullToAbsent
              ? const Value.absent()
              : Value(lessonCount),
      isActive: Value(isActive),
    );
  }

  factory Unit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Unit(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      phase: serializer.fromJson<String>(json['phase']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      grammarTags: serializer.fromJson<String>(json['grammarTags']),
      isExamPrep: serializer.fromJson<bool>(json['isExamPrep']),
      lessonCount: serializer.fromJson<int?>(json['lessonCount']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'phase': serializer.toJson<String>(phase),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'grammarTags': serializer.toJson<String>(grammarTags),
      'isExamPrep': serializer.toJson<bool>(isExamPrep),
      'lessonCount': serializer.toJson<int?>(lessonCount),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Unit copyWith({
    int? id,
    String? title,
    String? description,
    String? phase,
    int? orderIndex,
    String? grammarTags,
    bool? isExamPrep,
    Value<int?> lessonCount = const Value.absent(),
    bool? isActive,
  }) => Unit(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    phase: phase ?? this.phase,
    orderIndex: orderIndex ?? this.orderIndex,
    grammarTags: grammarTags ?? this.grammarTags,
    isExamPrep: isExamPrep ?? this.isExamPrep,
    lessonCount: lessonCount.present ? lessonCount.value : this.lessonCount,
    isActive: isActive ?? this.isActive,
  );
  Unit copyWithCompanion(UnitsCompanion data) {
    return Unit(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      phase: data.phase.present ? data.phase.value : this.phase,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
      grammarTags:
          data.grammarTags.present ? data.grammarTags.value : this.grammarTags,
      isExamPrep:
          data.isExamPrep.present ? data.isExamPrep.value : this.isExamPrep,
      lessonCount:
          data.lessonCount.present ? data.lessonCount.value : this.lessonCount,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Unit(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('phase: $phase, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('grammarTags: $grammarTags, ')
          ..write('isExamPrep: $isExamPrep, ')
          ..write('lessonCount: $lessonCount, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    phase,
    orderIndex,
    grammarTags,
    isExamPrep,
    lessonCount,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Unit &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.phase == this.phase &&
          other.orderIndex == this.orderIndex &&
          other.grammarTags == this.grammarTags &&
          other.isExamPrep == this.isExamPrep &&
          other.lessonCount == this.lessonCount &&
          other.isActive == this.isActive);
}

class UnitsCompanion extends UpdateCompanion<Unit> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> phase;
  final Value<int> orderIndex;
  final Value<String> grammarTags;
  final Value<bool> isExamPrep;
  final Value<int?> lessonCount;
  final Value<bool> isActive;
  const UnitsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.phase = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.grammarTags = const Value.absent(),
    this.isExamPrep = const Value.absent(),
    this.lessonCount = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  UnitsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String description,
    required String phase,
    required int orderIndex,
    this.grammarTags = const Value.absent(),
    this.isExamPrep = const Value.absent(),
    this.lessonCount = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : title = Value(title),
       description = Value(description),
       phase = Value(phase),
       orderIndex = Value(orderIndex);
  static Insertable<Unit> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? phase,
    Expression<int>? orderIndex,
    Expression<String>? grammarTags,
    Expression<bool>? isExamPrep,
    Expression<int>? lessonCount,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (phase != null) 'phase': phase,
      if (orderIndex != null) 'order_index': orderIndex,
      if (grammarTags != null) 'grammar_tags': grammarTags,
      if (isExamPrep != null) 'is_exam_prep': isExamPrep,
      if (lessonCount != null) 'lesson_count': lessonCount,
      if (isActive != null) 'is_active': isActive,
    });
  }

  UnitsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? phase,
    Value<int>? orderIndex,
    Value<String>? grammarTags,
    Value<bool>? isExamPrep,
    Value<int?>? lessonCount,
    Value<bool>? isActive,
  }) {
    return UnitsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      phase: phase ?? this.phase,
      orderIndex: orderIndex ?? this.orderIndex,
      grammarTags: grammarTags ?? this.grammarTags,
      isExamPrep: isExamPrep ?? this.isExamPrep,
      lessonCount: lessonCount ?? this.lessonCount,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (grammarTags.present) {
      map['grammar_tags'] = Variable<String>(grammarTags.value);
    }
    if (isExamPrep.present) {
      map['is_exam_prep'] = Variable<bool>(isExamPrep.value);
    }
    if (lessonCount.present) {
      map['lesson_count'] = Variable<int>(lessonCount.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnitsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('phase: $phase, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('grammarTags: $grammarTags, ')
          ..write('isExamPrep: $isExamPrep, ')
          ..write('lessonCount: $lessonCount, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $LessonsTable extends Lessons with TableInfo<$LessonsTable, Lesson> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<int> unitId = GeneratedColumn<int>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES units (id)',
    ),
  );
  static const VerificationMeta _orderInUnitMeta = const VerificationMeta(
    'orderInUnit',
  );
  @override
  late final GeneratedColumn<int> orderInUnit = GeneratedColumn<int>(
    'order_in_unit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _lessonTypeMeta = const VerificationMeta(
    'lessonType',
  );
  @override
  late final GeneratedColumn<String> lessonType = GeneratedColumn<String>(
    'lesson_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('introduction'),
  );
  static const VerificationMeta _isReviewMeta = const VerificationMeta(
    'isReview',
  );
  @override
  late final GeneratedColumn<bool> isReview = GeneratedColumn<bool>(
    'is_review',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_review" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unitId,
    orderInUnit,
    title,
    description,
    durationMinutes,
    lessonType,
    isReview,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lesson> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIdMeta);
    }
    if (data.containsKey('order_in_unit')) {
      context.handle(
        _orderInUnitMeta,
        orderInUnit.isAcceptableOrUnknown(
          data['order_in_unit']!,
          _orderInUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_orderInUnitMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('lesson_type')) {
      context.handle(
        _lessonTypeMeta,
        lessonType.isAcceptableOrUnknown(data['lesson_type']!, _lessonTypeMeta),
      );
    }
    if (data.containsKey('is_review')) {
      context.handle(
        _isReviewMeta,
        isReview.isAcceptableOrUnknown(data['is_review']!, _isReviewMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lesson map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lesson(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      unitId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}unit_id'],
          )!,
      orderInUnit:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}order_in_unit'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      durationMinutes:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}duration_minutes'],
          )!,
      lessonType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}lesson_type'],
          )!,
      isReview:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_review'],
          )!,
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
    );
  }

  @override
  $LessonsTable createAlias(String alias) {
    return $LessonsTable(attachedDatabase, alias);
  }
}

class Lesson extends DataClass implements Insertable<Lesson> {
  final int id;
  final int unitId;
  final int orderInUnit;
  final String title;
  final String description;
  final int durationMinutes;
  final String lessonType;
  final bool isReview;
  final bool isActive;
  const Lesson({
    required this.id,
    required this.unitId,
    required this.orderInUnit,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.lessonType,
    required this.isReview,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['unit_id'] = Variable<int>(unitId);
    map['order_in_unit'] = Variable<int>(orderInUnit);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['lesson_type'] = Variable<String>(lessonType);
    map['is_review'] = Variable<bool>(isReview);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  LessonsCompanion toCompanion(bool nullToAbsent) {
    return LessonsCompanion(
      id: Value(id),
      unitId: Value(unitId),
      orderInUnit: Value(orderInUnit),
      title: Value(title),
      description: Value(description),
      durationMinutes: Value(durationMinutes),
      lessonType: Value(lessonType),
      isReview: Value(isReview),
      isActive: Value(isActive),
    );
  }

  factory Lesson.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lesson(
      id: serializer.fromJson<int>(json['id']),
      unitId: serializer.fromJson<int>(json['unitId']),
      orderInUnit: serializer.fromJson<int>(json['orderInUnit']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      lessonType: serializer.fromJson<String>(json['lessonType']),
      isReview: serializer.fromJson<bool>(json['isReview']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'unitId': serializer.toJson<int>(unitId),
      'orderInUnit': serializer.toJson<int>(orderInUnit),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'lessonType': serializer.toJson<String>(lessonType),
      'isReview': serializer.toJson<bool>(isReview),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Lesson copyWith({
    int? id,
    int? unitId,
    int? orderInUnit,
    String? title,
    String? description,
    int? durationMinutes,
    String? lessonType,
    bool? isReview,
    bool? isActive,
  }) => Lesson(
    id: id ?? this.id,
    unitId: unitId ?? this.unitId,
    orderInUnit: orderInUnit ?? this.orderInUnit,
    title: title ?? this.title,
    description: description ?? this.description,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    lessonType: lessonType ?? this.lessonType,
    isReview: isReview ?? this.isReview,
    isActive: isActive ?? this.isActive,
  );
  Lesson copyWithCompanion(LessonsCompanion data) {
    return Lesson(
      id: data.id.present ? data.id.value : this.id,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      orderInUnit:
          data.orderInUnit.present ? data.orderInUnit.value : this.orderInUnit,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      durationMinutes:
          data.durationMinutes.present
              ? data.durationMinutes.value
              : this.durationMinutes,
      lessonType:
          data.lessonType.present ? data.lessonType.value : this.lessonType,
      isReview: data.isReview.present ? data.isReview.value : this.isReview,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lesson(')
          ..write('id: $id, ')
          ..write('unitId: $unitId, ')
          ..write('orderInUnit: $orderInUnit, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('lessonType: $lessonType, ')
          ..write('isReview: $isReview, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    unitId,
    orderInUnit,
    title,
    description,
    durationMinutes,
    lessonType,
    isReview,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lesson &&
          other.id == this.id &&
          other.unitId == this.unitId &&
          other.orderInUnit == this.orderInUnit &&
          other.title == this.title &&
          other.description == this.description &&
          other.durationMinutes == this.durationMinutes &&
          other.lessonType == this.lessonType &&
          other.isReview == this.isReview &&
          other.isActive == this.isActive);
}

class LessonsCompanion extends UpdateCompanion<Lesson> {
  final Value<int> id;
  final Value<int> unitId;
  final Value<int> orderInUnit;
  final Value<String> title;
  final Value<String> description;
  final Value<int> durationMinutes;
  final Value<String> lessonType;
  final Value<bool> isReview;
  final Value<bool> isActive;
  const LessonsCompanion({
    this.id = const Value.absent(),
    this.unitId = const Value.absent(),
    this.orderInUnit = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.lessonType = const Value.absent(),
    this.isReview = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  LessonsCompanion.insert({
    this.id = const Value.absent(),
    required int unitId,
    required int orderInUnit,
    required String title,
    required String description,
    this.durationMinutes = const Value.absent(),
    this.lessonType = const Value.absent(),
    this.isReview = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : unitId = Value(unitId),
       orderInUnit = Value(orderInUnit),
       title = Value(title),
       description = Value(description);
  static Insertable<Lesson> custom({
    Expression<int>? id,
    Expression<int>? unitId,
    Expression<int>? orderInUnit,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? durationMinutes,
    Expression<String>? lessonType,
    Expression<bool>? isReview,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unitId != null) 'unit_id': unitId,
      if (orderInUnit != null) 'order_in_unit': orderInUnit,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (lessonType != null) 'lesson_type': lessonType,
      if (isReview != null) 'is_review': isReview,
      if (isActive != null) 'is_active': isActive,
    });
  }

  LessonsCompanion copyWith({
    Value<int>? id,
    Value<int>? unitId,
    Value<int>? orderInUnit,
    Value<String>? title,
    Value<String>? description,
    Value<int>? durationMinutes,
    Value<String>? lessonType,
    Value<bool>? isReview,
    Value<bool>? isActive,
  }) {
    return LessonsCompanion(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      orderInUnit: orderInUnit ?? this.orderInUnit,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      lessonType: lessonType ?? this.lessonType,
      isReview: isReview ?? this.isReview,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<int>(unitId.value);
    }
    if (orderInUnit.present) {
      map['order_in_unit'] = Variable<int>(orderInUnit.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (lessonType.present) {
      map['lesson_type'] = Variable<String>(lessonType.value);
    }
    if (isReview.present) {
      map['is_review'] = Variable<bool>(isReview.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonsCompanion(')
          ..write('id: $id, ')
          ..write('unitId: $unitId, ')
          ..write('orderInUnit: $orderInUnit, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('lessonType: $lessonType, ')
          ..write('isReview: $isReview, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lessons (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerKeyMeta = const VerificationMeta(
    'answerKey',
  );
  @override
  late final GeneratedColumn<String> answerKey = GeneratedColumn<String>(
    'answer_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grammarRuleIdMeta = const VerificationMeta(
    'grammarRuleId',
  );
  @override
  late final GeneratedColumn<String> grammarRuleId = GeneratedColumn<String>(
    'grammar_rule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _xpRewardMeta = const VerificationMeta(
    'xpReward',
  );
  @override
  late final GeneratedColumn<int> xpReward = GeneratedColumn<int>(
    'xp_reward',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonId,
    type,
    prompt,
    data,
    answerKey,
    grammarRuleId,
    xpReward,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('answer_key')) {
      context.handle(
        _answerKeyMeta,
        answerKey.isAcceptableOrUnknown(data['answer_key']!, _answerKeyMeta),
      );
    }
    if (data.containsKey('grammar_rule_id')) {
      context.handle(
        _grammarRuleIdMeta,
        grammarRuleId.isAcceptableOrUnknown(
          data['grammar_rule_id']!,
          _grammarRuleIdMeta,
        ),
      );
    }
    if (data.containsKey('xp_reward')) {
      context.handle(
        _xpRewardMeta,
        xpReward.isAcceptableOrUnknown(data['xp_reward']!, _xpRewardMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      lessonId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lesson_id'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      prompt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}prompt'],
          )!,
      data:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}data'],
          )!,
      answerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_key'],
      ),
      grammarRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grammar_rule_id'],
      ),
      xpReward:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}xp_reward'],
          )!,
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final int lessonId;
  final String type;
  final String prompt;
  final String data;
  final String? answerKey;
  final String? grammarRuleId;
  final int xpReward;
  final bool isActive;
  const Exercise({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.prompt,
    required this.data,
    this.answerKey,
    this.grammarRuleId,
    required this.xpReward,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lesson_id'] = Variable<int>(lessonId);
    map['type'] = Variable<String>(type);
    map['prompt'] = Variable<String>(prompt);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || answerKey != null) {
      map['answer_key'] = Variable<String>(answerKey);
    }
    if (!nullToAbsent || grammarRuleId != null) {
      map['grammar_rule_id'] = Variable<String>(grammarRuleId);
    }
    map['xp_reward'] = Variable<int>(xpReward);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      lessonId: Value(lessonId),
      type: Value(type),
      prompt: Value(prompt),
      data: Value(data),
      answerKey:
          answerKey == null && nullToAbsent
              ? const Value.absent()
              : Value(answerKey),
      grammarRuleId:
          grammarRuleId == null && nullToAbsent
              ? const Value.absent()
              : Value(grammarRuleId),
      xpReward: Value(xpReward),
      isActive: Value(isActive),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      type: serializer.fromJson<String>(json['type']),
      prompt: serializer.fromJson<String>(json['prompt']),
      data: serializer.fromJson<String>(json['data']),
      answerKey: serializer.fromJson<String?>(json['answerKey']),
      grammarRuleId: serializer.fromJson<String?>(json['grammarRuleId']),
      xpReward: serializer.fromJson<int>(json['xpReward']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lessonId': serializer.toJson<int>(lessonId),
      'type': serializer.toJson<String>(type),
      'prompt': serializer.toJson<String>(prompt),
      'data': serializer.toJson<String>(data),
      'answerKey': serializer.toJson<String?>(answerKey),
      'grammarRuleId': serializer.toJson<String?>(grammarRuleId),
      'xpReward': serializer.toJson<int>(xpReward),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Exercise copyWith({
    int? id,
    int? lessonId,
    String? type,
    String? prompt,
    String? data,
    Value<String?> answerKey = const Value.absent(),
    Value<String?> grammarRuleId = const Value.absent(),
    int? xpReward,
    bool? isActive,
  }) => Exercise(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    type: type ?? this.type,
    prompt: prompt ?? this.prompt,
    data: data ?? this.data,
    answerKey: answerKey.present ? answerKey.value : this.answerKey,
    grammarRuleId:
        grammarRuleId.present ? grammarRuleId.value : this.grammarRuleId,
    xpReward: xpReward ?? this.xpReward,
    isActive: isActive ?? this.isActive,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      type: data.type.present ? data.type.value : this.type,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      data: data.data.present ? data.data.value : this.data,
      answerKey: data.answerKey.present ? data.answerKey.value : this.answerKey,
      grammarRuleId:
          data.grammarRuleId.present
              ? data.grammarRuleId.value
              : this.grammarRuleId,
      xpReward: data.xpReward.present ? data.xpReward.value : this.xpReward,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('type: $type, ')
          ..write('prompt: $prompt, ')
          ..write('data: $data, ')
          ..write('answerKey: $answerKey, ')
          ..write('grammarRuleId: $grammarRuleId, ')
          ..write('xpReward: $xpReward, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lessonId,
    type,
    prompt,
    data,
    answerKey,
    grammarRuleId,
    xpReward,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.lessonId == this.lessonId &&
          other.type == this.type &&
          other.prompt == this.prompt &&
          other.data == this.data &&
          other.answerKey == this.answerKey &&
          other.grammarRuleId == this.grammarRuleId &&
          other.xpReward == this.xpReward &&
          other.isActive == this.isActive);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<int> lessonId;
  final Value<String> type;
  final Value<String> prompt;
  final Value<String> data;
  final Value<String?> answerKey;
  final Value<String?> grammarRuleId;
  final Value<int> xpReward;
  final Value<bool> isActive;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.type = const Value.absent(),
    this.prompt = const Value.absent(),
    this.data = const Value.absent(),
    this.answerKey = const Value.absent(),
    this.grammarRuleId = const Value.absent(),
    this.xpReward = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int lessonId,
    required String type,
    required String prompt,
    required String data,
    this.answerKey = const Value.absent(),
    this.grammarRuleId = const Value.absent(),
    this.xpReward = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : lessonId = Value(lessonId),
       type = Value(type),
       prompt = Value(prompt),
       data = Value(data);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<int>? lessonId,
    Expression<String>? type,
    Expression<String>? prompt,
    Expression<String>? data,
    Expression<String>? answerKey,
    Expression<String>? grammarRuleId,
    Expression<int>? xpReward,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonId != null) 'lesson_id': lessonId,
      if (type != null) 'type': type,
      if (prompt != null) 'prompt': prompt,
      if (data != null) 'data': data,
      if (answerKey != null) 'answer_key': answerKey,
      if (grammarRuleId != null) 'grammar_rule_id': grammarRuleId,
      if (xpReward != null) 'xp_reward': xpReward,
      if (isActive != null) 'is_active': isActive,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<int>? lessonId,
    Value<String>? type,
    Value<String>? prompt,
    Value<String>? data,
    Value<String?>? answerKey,
    Value<String?>? grammarRuleId,
    Value<int>? xpReward,
    Value<bool>? isActive,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      data: data ?? this.data,
      answerKey: answerKey ?? this.answerKey,
      grammarRuleId: grammarRuleId ?? this.grammarRuleId,
      xpReward: xpReward ?? this.xpReward,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (answerKey.present) {
      map['answer_key'] = Variable<String>(answerKey.value);
    }
    if (grammarRuleId.present) {
      map['grammar_rule_id'] = Variable<String>(grammarRuleId.value);
    }
    if (xpReward.present) {
      map['xp_reward'] = Variable<int>(xpReward.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('type: $type, ')
          ..write('prompt: $prompt, ')
          ..write('data: $data, ')
          ..write('answerKey: $answerKey, ')
          ..write('grammarRuleId: $grammarRuleId, ')
          ..write('xpReward: $xpReward, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $FlashcardsTable extends Flashcards
    with TableInfo<$FlashcardsTable, Flashcard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordCzMeta = const VerificationMeta('wordCz');
  @override
  late final GeneratedColumn<String> wordCz = GeneratedColumn<String>(
    'word_cz',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordEnMeta = const VerificationMeta('wordEn');
  @override
  late final GeneratedColumn<String> wordEn = GeneratedColumn<String>(
    'word_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipaMeta = const VerificationMeta('ipa');
  @override
  late final GeneratedColumn<String> ipa = GeneratedColumn<String>(
    'ipa',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caseInfoMeta = const VerificationMeta(
    'caseInfo',
  );
  @override
  late final GeneratedColumn<String> caseInfo = GeneratedColumn<String>(
    'case_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioHashMeta = const VerificationMeta(
    'audioHash',
  );
  @override
  late final GeneratedColumn<String> audioHash = GeneratedColumn<String>(
    'audio_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exampleCzMeta = const VerificationMeta(
    'exampleCz',
  );
  @override
  late final GeneratedColumn<String> exampleCz = GeneratedColumn<String>(
    'example_cz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exampleEnMeta = const VerificationMeta(
    'exampleEn',
  );
  @override
  late final GeneratedColumn<String> exampleEn = GeneratedColumn<String>(
    'example_en',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lemmaMeta = const VerificationMeta('lemma');
  @override
  late final GeneratedColumn<String> lemma = GeneratedColumn<String>(
    'lemma',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senseKeyMeta = const VerificationMeta(
    'senseKey',
  );
  @override
  late final GeneratedColumn<String> senseKey = GeneratedColumn<String>(
    'sense_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partOfSpeechMeta = const VerificationMeta(
    'partOfSpeech',
  );
  @override
  late final GeneratedColumn<String> partOfSpeech = GeneratedColumn<String>(
    'part_of_speech',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _morphologyJsonMeta = const VerificationMeta(
    'morphologyJson',
  );
  @override
  late final GeneratedColumn<String> morphologyJson = GeneratedColumn<String>(
    'morphology_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registerLabelMeta = const VerificationMeta(
    'registerLabel',
  );
  @override
  late final GeneratedColumn<String> registerLabel = GeneratedColumn<String>(
    'register_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pronunciationSourceMeta =
      const VerificationMeta('pronunciationSource');
  @override
  late final GeneratedColumn<String> pronunciationSource =
      GeneratedColumn<String>(
        'pronunciation_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _contentUidMeta = const VerificationMeta(
    'contentUid',
  );
  @override
  late final GeneratedColumn<String> contentUid = GeneratedColumn<String>(
    'content_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<int> unitId = GeneratedColumn<int>(
    'unit_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES units (id)',
    ),
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lessons (id)',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wordCz,
    wordEn,
    ipa,
    gender,
    caseInfo,
    audioHash,
    imagePath,
    exampleCz,
    exampleEn,
    lemma,
    senseKey,
    partOfSpeech,
    morphologyJson,
    registerLabel,
    pronunciationSource,
    contentUid,
    unitId,
    lessonId,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Flashcard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word_cz')) {
      context.handle(
        _wordCzMeta,
        wordCz.isAcceptableOrUnknown(data['word_cz']!, _wordCzMeta),
      );
    } else if (isInserting) {
      context.missing(_wordCzMeta);
    }
    if (data.containsKey('word_en')) {
      context.handle(
        _wordEnMeta,
        wordEn.isAcceptableOrUnknown(data['word_en']!, _wordEnMeta),
      );
    } else if (isInserting) {
      context.missing(_wordEnMeta);
    }
    if (data.containsKey('ipa')) {
      context.handle(
        _ipaMeta,
        ipa.isAcceptableOrUnknown(data['ipa']!, _ipaMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('case_info')) {
      context.handle(
        _caseInfoMeta,
        caseInfo.isAcceptableOrUnknown(data['case_info']!, _caseInfoMeta),
      );
    }
    if (data.containsKey('audio_hash')) {
      context.handle(
        _audioHashMeta,
        audioHash.isAcceptableOrUnknown(data['audio_hash']!, _audioHashMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('example_cz')) {
      context.handle(
        _exampleCzMeta,
        exampleCz.isAcceptableOrUnknown(data['example_cz']!, _exampleCzMeta),
      );
    }
    if (data.containsKey('example_en')) {
      context.handle(
        _exampleEnMeta,
        exampleEn.isAcceptableOrUnknown(data['example_en']!, _exampleEnMeta),
      );
    }
    if (data.containsKey('lemma')) {
      context.handle(
        _lemmaMeta,
        lemma.isAcceptableOrUnknown(data['lemma']!, _lemmaMeta),
      );
    }
    if (data.containsKey('sense_key')) {
      context.handle(
        _senseKeyMeta,
        senseKey.isAcceptableOrUnknown(data['sense_key']!, _senseKeyMeta),
      );
    }
    if (data.containsKey('part_of_speech')) {
      context.handle(
        _partOfSpeechMeta,
        partOfSpeech.isAcceptableOrUnknown(
          data['part_of_speech']!,
          _partOfSpeechMeta,
        ),
      );
    }
    if (data.containsKey('morphology_json')) {
      context.handle(
        _morphologyJsonMeta,
        morphologyJson.isAcceptableOrUnknown(
          data['morphology_json']!,
          _morphologyJsonMeta,
        ),
      );
    }
    if (data.containsKey('register_label')) {
      context.handle(
        _registerLabelMeta,
        registerLabel.isAcceptableOrUnknown(
          data['register_label']!,
          _registerLabelMeta,
        ),
      );
    }
    if (data.containsKey('pronunciation_source')) {
      context.handle(
        _pronunciationSourceMeta,
        pronunciationSource.isAcceptableOrUnknown(
          data['pronunciation_source']!,
          _pronunciationSourceMeta,
        ),
      );
    }
    if (data.containsKey('content_uid')) {
      context.handle(
        _contentUidMeta,
        contentUid.isAcceptableOrUnknown(data['content_uid']!, _contentUidMeta),
      );
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Flashcard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Flashcard(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      wordCz:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}word_cz'],
          )!,
      wordEn:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}word_en'],
          )!,
      ipa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ipa'],
      ),
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      caseInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_info'],
      ),
      audioHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_hash'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      exampleCz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_cz'],
      ),
      exampleEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_en'],
      ),
      lemma: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lemma'],
      ),
      senseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sense_key'],
      ),
      partOfSpeech: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_of_speech'],
      ),
      morphologyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}morphology_json'],
      ),
      registerLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_label'],
      ),
      pronunciationSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pronunciation_source'],
      ),
      contentUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_uid'],
      ),
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_id'],
      ),
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      ),
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
    );
  }

  @override
  $FlashcardsTable createAlias(String alias) {
    return $FlashcardsTable(attachedDatabase, alias);
  }
}

class Flashcard extends DataClass implements Insertable<Flashcard> {
  final int id;
  final String wordCz;
  final String wordEn;
  final String? ipa;
  final String? gender;
  final String? caseInfo;
  final String? audioHash;
  final String? imagePath;
  final String? exampleCz;
  final String? exampleEn;
  final String? lemma;
  final String? senseKey;
  final String? partOfSpeech;
  final String? morphologyJson;
  final String? registerLabel;
  final String? pronunciationSource;

  /// Stable, device-independent identity for user-created ("manual") cards.
  /// Managed/seeded cards leave this null and are keyed cross-device by their
  /// deterministic seeded id. Manual cards get a UUID at creation so two
  /// devices adding different words can never collide on the same sync
  /// `content_key` (the local autoincrement id is not stable across devices).
  final String? contentUid;
  final int? unitId;

  /// The lesson that introduces this word. When set, the word is only
  /// scheduled for review once that lesson is completed (finer-grained than
  /// [unitId] gating). Null falls back to unit-level gating.
  final int? lessonId;
  final bool isActive;
  const Flashcard({
    required this.id,
    required this.wordCz,
    required this.wordEn,
    this.ipa,
    this.gender,
    this.caseInfo,
    this.audioHash,
    this.imagePath,
    this.exampleCz,
    this.exampleEn,
    this.lemma,
    this.senseKey,
    this.partOfSpeech,
    this.morphologyJson,
    this.registerLabel,
    this.pronunciationSource,
    this.contentUid,
    this.unitId,
    this.lessonId,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word_cz'] = Variable<String>(wordCz);
    map['word_en'] = Variable<String>(wordEn);
    if (!nullToAbsent || ipa != null) {
      map['ipa'] = Variable<String>(ipa);
    }
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || caseInfo != null) {
      map['case_info'] = Variable<String>(caseInfo);
    }
    if (!nullToAbsent || audioHash != null) {
      map['audio_hash'] = Variable<String>(audioHash);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || exampleCz != null) {
      map['example_cz'] = Variable<String>(exampleCz);
    }
    if (!nullToAbsent || exampleEn != null) {
      map['example_en'] = Variable<String>(exampleEn);
    }
    if (!nullToAbsent || lemma != null) {
      map['lemma'] = Variable<String>(lemma);
    }
    if (!nullToAbsent || senseKey != null) {
      map['sense_key'] = Variable<String>(senseKey);
    }
    if (!nullToAbsent || partOfSpeech != null) {
      map['part_of_speech'] = Variable<String>(partOfSpeech);
    }
    if (!nullToAbsent || morphologyJson != null) {
      map['morphology_json'] = Variable<String>(morphologyJson);
    }
    if (!nullToAbsent || registerLabel != null) {
      map['register_label'] = Variable<String>(registerLabel);
    }
    if (!nullToAbsent || pronunciationSource != null) {
      map['pronunciation_source'] = Variable<String>(pronunciationSource);
    }
    if (!nullToAbsent || contentUid != null) {
      map['content_uid'] = Variable<String>(contentUid);
    }
    if (!nullToAbsent || unitId != null) {
      map['unit_id'] = Variable<int>(unitId);
    }
    if (!nullToAbsent || lessonId != null) {
      map['lesson_id'] = Variable<int>(lessonId);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  FlashcardsCompanion toCompanion(bool nullToAbsent) {
    return FlashcardsCompanion(
      id: Value(id),
      wordCz: Value(wordCz),
      wordEn: Value(wordEn),
      ipa: ipa == null && nullToAbsent ? const Value.absent() : Value(ipa),
      gender:
          gender == null && nullToAbsent ? const Value.absent() : Value(gender),
      caseInfo:
          caseInfo == null && nullToAbsent
              ? const Value.absent()
              : Value(caseInfo),
      audioHash:
          audioHash == null && nullToAbsent
              ? const Value.absent()
              : Value(audioHash),
      imagePath:
          imagePath == null && nullToAbsent
              ? const Value.absent()
              : Value(imagePath),
      exampleCz:
          exampleCz == null && nullToAbsent
              ? const Value.absent()
              : Value(exampleCz),
      exampleEn:
          exampleEn == null && nullToAbsent
              ? const Value.absent()
              : Value(exampleEn),
      lemma:
          lemma == null && nullToAbsent ? const Value.absent() : Value(lemma),
      senseKey:
          senseKey == null && nullToAbsent
              ? const Value.absent()
              : Value(senseKey),
      partOfSpeech:
          partOfSpeech == null && nullToAbsent
              ? const Value.absent()
              : Value(partOfSpeech),
      morphologyJson:
          morphologyJson == null && nullToAbsent
              ? const Value.absent()
              : Value(morphologyJson),
      registerLabel:
          registerLabel == null && nullToAbsent
              ? const Value.absent()
              : Value(registerLabel),
      pronunciationSource:
          pronunciationSource == null && nullToAbsent
              ? const Value.absent()
              : Value(pronunciationSource),
      contentUid:
          contentUid == null && nullToAbsent
              ? const Value.absent()
              : Value(contentUid),
      unitId:
          unitId == null && nullToAbsent ? const Value.absent() : Value(unitId),
      lessonId:
          lessonId == null && nullToAbsent
              ? const Value.absent()
              : Value(lessonId),
      isActive: Value(isActive),
    );
  }

  factory Flashcard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Flashcard(
      id: serializer.fromJson<int>(json['id']),
      wordCz: serializer.fromJson<String>(json['wordCz']),
      wordEn: serializer.fromJson<String>(json['wordEn']),
      ipa: serializer.fromJson<String?>(json['ipa']),
      gender: serializer.fromJson<String?>(json['gender']),
      caseInfo: serializer.fromJson<String?>(json['caseInfo']),
      audioHash: serializer.fromJson<String?>(json['audioHash']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      exampleCz: serializer.fromJson<String?>(json['exampleCz']),
      exampleEn: serializer.fromJson<String?>(json['exampleEn']),
      lemma: serializer.fromJson<String?>(json['lemma']),
      senseKey: serializer.fromJson<String?>(json['senseKey']),
      partOfSpeech: serializer.fromJson<String?>(json['partOfSpeech']),
      morphologyJson: serializer.fromJson<String?>(json['morphologyJson']),
      registerLabel: serializer.fromJson<String?>(json['registerLabel']),
      pronunciationSource: serializer.fromJson<String?>(
        json['pronunciationSource'],
      ),
      contentUid: serializer.fromJson<String?>(json['contentUid']),
      unitId: serializer.fromJson<int?>(json['unitId']),
      lessonId: serializer.fromJson<int?>(json['lessonId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wordCz': serializer.toJson<String>(wordCz),
      'wordEn': serializer.toJson<String>(wordEn),
      'ipa': serializer.toJson<String?>(ipa),
      'gender': serializer.toJson<String?>(gender),
      'caseInfo': serializer.toJson<String?>(caseInfo),
      'audioHash': serializer.toJson<String?>(audioHash),
      'imagePath': serializer.toJson<String?>(imagePath),
      'exampleCz': serializer.toJson<String?>(exampleCz),
      'exampleEn': serializer.toJson<String?>(exampleEn),
      'lemma': serializer.toJson<String?>(lemma),
      'senseKey': serializer.toJson<String?>(senseKey),
      'partOfSpeech': serializer.toJson<String?>(partOfSpeech),
      'morphologyJson': serializer.toJson<String?>(morphologyJson),
      'registerLabel': serializer.toJson<String?>(registerLabel),
      'pronunciationSource': serializer.toJson<String?>(pronunciationSource),
      'contentUid': serializer.toJson<String?>(contentUid),
      'unitId': serializer.toJson<int?>(unitId),
      'lessonId': serializer.toJson<int?>(lessonId),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Flashcard copyWith({
    int? id,
    String? wordCz,
    String? wordEn,
    Value<String?> ipa = const Value.absent(),
    Value<String?> gender = const Value.absent(),
    Value<String?> caseInfo = const Value.absent(),
    Value<String?> audioHash = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    Value<String?> exampleCz = const Value.absent(),
    Value<String?> exampleEn = const Value.absent(),
    Value<String?> lemma = const Value.absent(),
    Value<String?> senseKey = const Value.absent(),
    Value<String?> partOfSpeech = const Value.absent(),
    Value<String?> morphologyJson = const Value.absent(),
    Value<String?> registerLabel = const Value.absent(),
    Value<String?> pronunciationSource = const Value.absent(),
    Value<String?> contentUid = const Value.absent(),
    Value<int?> unitId = const Value.absent(),
    Value<int?> lessonId = const Value.absent(),
    bool? isActive,
  }) => Flashcard(
    id: id ?? this.id,
    wordCz: wordCz ?? this.wordCz,
    wordEn: wordEn ?? this.wordEn,
    ipa: ipa.present ? ipa.value : this.ipa,
    gender: gender.present ? gender.value : this.gender,
    caseInfo: caseInfo.present ? caseInfo.value : this.caseInfo,
    audioHash: audioHash.present ? audioHash.value : this.audioHash,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    exampleCz: exampleCz.present ? exampleCz.value : this.exampleCz,
    exampleEn: exampleEn.present ? exampleEn.value : this.exampleEn,
    lemma: lemma.present ? lemma.value : this.lemma,
    senseKey: senseKey.present ? senseKey.value : this.senseKey,
    partOfSpeech: partOfSpeech.present ? partOfSpeech.value : this.partOfSpeech,
    morphologyJson:
        morphologyJson.present ? morphologyJson.value : this.morphologyJson,
    registerLabel:
        registerLabel.present ? registerLabel.value : this.registerLabel,
    pronunciationSource:
        pronunciationSource.present
            ? pronunciationSource.value
            : this.pronunciationSource,
    contentUid: contentUid.present ? contentUid.value : this.contentUid,
    unitId: unitId.present ? unitId.value : this.unitId,
    lessonId: lessonId.present ? lessonId.value : this.lessonId,
    isActive: isActive ?? this.isActive,
  );
  Flashcard copyWithCompanion(FlashcardsCompanion data) {
    return Flashcard(
      id: data.id.present ? data.id.value : this.id,
      wordCz: data.wordCz.present ? data.wordCz.value : this.wordCz,
      wordEn: data.wordEn.present ? data.wordEn.value : this.wordEn,
      ipa: data.ipa.present ? data.ipa.value : this.ipa,
      gender: data.gender.present ? data.gender.value : this.gender,
      caseInfo: data.caseInfo.present ? data.caseInfo.value : this.caseInfo,
      audioHash: data.audioHash.present ? data.audioHash.value : this.audioHash,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      exampleCz: data.exampleCz.present ? data.exampleCz.value : this.exampleCz,
      exampleEn: data.exampleEn.present ? data.exampleEn.value : this.exampleEn,
      lemma: data.lemma.present ? data.lemma.value : this.lemma,
      senseKey: data.senseKey.present ? data.senseKey.value : this.senseKey,
      partOfSpeech:
          data.partOfSpeech.present
              ? data.partOfSpeech.value
              : this.partOfSpeech,
      morphologyJson:
          data.morphologyJson.present
              ? data.morphologyJson.value
              : this.morphologyJson,
      registerLabel:
          data.registerLabel.present
              ? data.registerLabel.value
              : this.registerLabel,
      pronunciationSource:
          data.pronunciationSource.present
              ? data.pronunciationSource.value
              : this.pronunciationSource,
      contentUid:
          data.contentUid.present ? data.contentUid.value : this.contentUid,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Flashcard(')
          ..write('id: $id, ')
          ..write('wordCz: $wordCz, ')
          ..write('wordEn: $wordEn, ')
          ..write('ipa: $ipa, ')
          ..write('gender: $gender, ')
          ..write('caseInfo: $caseInfo, ')
          ..write('audioHash: $audioHash, ')
          ..write('imagePath: $imagePath, ')
          ..write('exampleCz: $exampleCz, ')
          ..write('exampleEn: $exampleEn, ')
          ..write('lemma: $lemma, ')
          ..write('senseKey: $senseKey, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('morphologyJson: $morphologyJson, ')
          ..write('registerLabel: $registerLabel, ')
          ..write('pronunciationSource: $pronunciationSource, ')
          ..write('contentUid: $contentUid, ')
          ..write('unitId: $unitId, ')
          ..write('lessonId: $lessonId, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wordCz,
    wordEn,
    ipa,
    gender,
    caseInfo,
    audioHash,
    imagePath,
    exampleCz,
    exampleEn,
    lemma,
    senseKey,
    partOfSpeech,
    morphologyJson,
    registerLabel,
    pronunciationSource,
    contentUid,
    unitId,
    lessonId,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Flashcard &&
          other.id == this.id &&
          other.wordCz == this.wordCz &&
          other.wordEn == this.wordEn &&
          other.ipa == this.ipa &&
          other.gender == this.gender &&
          other.caseInfo == this.caseInfo &&
          other.audioHash == this.audioHash &&
          other.imagePath == this.imagePath &&
          other.exampleCz == this.exampleCz &&
          other.exampleEn == this.exampleEn &&
          other.lemma == this.lemma &&
          other.senseKey == this.senseKey &&
          other.partOfSpeech == this.partOfSpeech &&
          other.morphologyJson == this.morphologyJson &&
          other.registerLabel == this.registerLabel &&
          other.pronunciationSource == this.pronunciationSource &&
          other.contentUid == this.contentUid &&
          other.unitId == this.unitId &&
          other.lessonId == this.lessonId &&
          other.isActive == this.isActive);
}

class FlashcardsCompanion extends UpdateCompanion<Flashcard> {
  final Value<int> id;
  final Value<String> wordCz;
  final Value<String> wordEn;
  final Value<String?> ipa;
  final Value<String?> gender;
  final Value<String?> caseInfo;
  final Value<String?> audioHash;
  final Value<String?> imagePath;
  final Value<String?> exampleCz;
  final Value<String?> exampleEn;
  final Value<String?> lemma;
  final Value<String?> senseKey;
  final Value<String?> partOfSpeech;
  final Value<String?> morphologyJson;
  final Value<String?> registerLabel;
  final Value<String?> pronunciationSource;
  final Value<String?> contentUid;
  final Value<int?> unitId;
  final Value<int?> lessonId;
  final Value<bool> isActive;
  const FlashcardsCompanion({
    this.id = const Value.absent(),
    this.wordCz = const Value.absent(),
    this.wordEn = const Value.absent(),
    this.ipa = const Value.absent(),
    this.gender = const Value.absent(),
    this.caseInfo = const Value.absent(),
    this.audioHash = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.exampleCz = const Value.absent(),
    this.exampleEn = const Value.absent(),
    this.lemma = const Value.absent(),
    this.senseKey = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
    this.morphologyJson = const Value.absent(),
    this.registerLabel = const Value.absent(),
    this.pronunciationSource = const Value.absent(),
    this.contentUid = const Value.absent(),
    this.unitId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  FlashcardsCompanion.insert({
    this.id = const Value.absent(),
    required String wordCz,
    required String wordEn,
    this.ipa = const Value.absent(),
    this.gender = const Value.absent(),
    this.caseInfo = const Value.absent(),
    this.audioHash = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.exampleCz = const Value.absent(),
    this.exampleEn = const Value.absent(),
    this.lemma = const Value.absent(),
    this.senseKey = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
    this.morphologyJson = const Value.absent(),
    this.registerLabel = const Value.absent(),
    this.pronunciationSource = const Value.absent(),
    this.contentUid = const Value.absent(),
    this.unitId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : wordCz = Value(wordCz),
       wordEn = Value(wordEn);
  static Insertable<Flashcard> custom({
    Expression<int>? id,
    Expression<String>? wordCz,
    Expression<String>? wordEn,
    Expression<String>? ipa,
    Expression<String>? gender,
    Expression<String>? caseInfo,
    Expression<String>? audioHash,
    Expression<String>? imagePath,
    Expression<String>? exampleCz,
    Expression<String>? exampleEn,
    Expression<String>? lemma,
    Expression<String>? senseKey,
    Expression<String>? partOfSpeech,
    Expression<String>? morphologyJson,
    Expression<String>? registerLabel,
    Expression<String>? pronunciationSource,
    Expression<String>? contentUid,
    Expression<int>? unitId,
    Expression<int>? lessonId,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wordCz != null) 'word_cz': wordCz,
      if (wordEn != null) 'word_en': wordEn,
      if (ipa != null) 'ipa': ipa,
      if (gender != null) 'gender': gender,
      if (caseInfo != null) 'case_info': caseInfo,
      if (audioHash != null) 'audio_hash': audioHash,
      if (imagePath != null) 'image_path': imagePath,
      if (exampleCz != null) 'example_cz': exampleCz,
      if (exampleEn != null) 'example_en': exampleEn,
      if (lemma != null) 'lemma': lemma,
      if (senseKey != null) 'sense_key': senseKey,
      if (partOfSpeech != null) 'part_of_speech': partOfSpeech,
      if (morphologyJson != null) 'morphology_json': morphologyJson,
      if (registerLabel != null) 'register_label': registerLabel,
      if (pronunciationSource != null)
        'pronunciation_source': pronunciationSource,
      if (contentUid != null) 'content_uid': contentUid,
      if (unitId != null) 'unit_id': unitId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (isActive != null) 'is_active': isActive,
    });
  }

  FlashcardsCompanion copyWith({
    Value<int>? id,
    Value<String>? wordCz,
    Value<String>? wordEn,
    Value<String?>? ipa,
    Value<String?>? gender,
    Value<String?>? caseInfo,
    Value<String?>? audioHash,
    Value<String?>? imagePath,
    Value<String?>? exampleCz,
    Value<String?>? exampleEn,
    Value<String?>? lemma,
    Value<String?>? senseKey,
    Value<String?>? partOfSpeech,
    Value<String?>? morphologyJson,
    Value<String?>? registerLabel,
    Value<String?>? pronunciationSource,
    Value<String?>? contentUid,
    Value<int?>? unitId,
    Value<int?>? lessonId,
    Value<bool>? isActive,
  }) {
    return FlashcardsCompanion(
      id: id ?? this.id,
      wordCz: wordCz ?? this.wordCz,
      wordEn: wordEn ?? this.wordEn,
      ipa: ipa ?? this.ipa,
      gender: gender ?? this.gender,
      caseInfo: caseInfo ?? this.caseInfo,
      audioHash: audioHash ?? this.audioHash,
      imagePath: imagePath ?? this.imagePath,
      exampleCz: exampleCz ?? this.exampleCz,
      exampleEn: exampleEn ?? this.exampleEn,
      lemma: lemma ?? this.lemma,
      senseKey: senseKey ?? this.senseKey,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      morphologyJson: morphologyJson ?? this.morphologyJson,
      registerLabel: registerLabel ?? this.registerLabel,
      pronunciationSource: pronunciationSource ?? this.pronunciationSource,
      contentUid: contentUid ?? this.contentUid,
      unitId: unitId ?? this.unitId,
      lessonId: lessonId ?? this.lessonId,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wordCz.present) {
      map['word_cz'] = Variable<String>(wordCz.value);
    }
    if (wordEn.present) {
      map['word_en'] = Variable<String>(wordEn.value);
    }
    if (ipa.present) {
      map['ipa'] = Variable<String>(ipa.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (caseInfo.present) {
      map['case_info'] = Variable<String>(caseInfo.value);
    }
    if (audioHash.present) {
      map['audio_hash'] = Variable<String>(audioHash.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (exampleCz.present) {
      map['example_cz'] = Variable<String>(exampleCz.value);
    }
    if (exampleEn.present) {
      map['example_en'] = Variable<String>(exampleEn.value);
    }
    if (lemma.present) {
      map['lemma'] = Variable<String>(lemma.value);
    }
    if (senseKey.present) {
      map['sense_key'] = Variable<String>(senseKey.value);
    }
    if (partOfSpeech.present) {
      map['part_of_speech'] = Variable<String>(partOfSpeech.value);
    }
    if (morphologyJson.present) {
      map['morphology_json'] = Variable<String>(morphologyJson.value);
    }
    if (registerLabel.present) {
      map['register_label'] = Variable<String>(registerLabel.value);
    }
    if (pronunciationSource.present) {
      map['pronunciation_source'] = Variable<String>(pronunciationSource.value);
    }
    if (contentUid.present) {
      map['content_uid'] = Variable<String>(contentUid.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<int>(unitId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsCompanion(')
          ..write('id: $id, ')
          ..write('wordCz: $wordCz, ')
          ..write('wordEn: $wordEn, ')
          ..write('ipa: $ipa, ')
          ..write('gender: $gender, ')
          ..write('caseInfo: $caseInfo, ')
          ..write('audioHash: $audioHash, ')
          ..write('imagePath: $imagePath, ')
          ..write('exampleCz: $exampleCz, ')
          ..write('exampleEn: $exampleEn, ')
          ..write('lemma: $lemma, ')
          ..write('senseKey: $senseKey, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('morphologyJson: $morphologyJson, ')
          ..write('registerLabel: $registerLabel, ')
          ..write('pronunciationSource: $pronunciationSource, ')
          ..write('contentUid: $contentUid, ')
          ..write('unitId: $unitId, ')
          ..write('lessonId: $lessonId, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $SrsCardsTable extends SrsCards with TableInfo<$SrsCardsTable, SrsCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SrsCardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cardTypeMeta = const VerificationMeta(
    'cardType',
  );
  @override
  late final GeneratedColumn<String> cardType = GeneratedColumn<String>(
    'card_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flashcardIdMeta = const VerificationMeta(
    'flashcardId',
  );
  @override
  late final GeneratedColumn<int> flashcardId = GeneratedColumn<int>(
    'flashcard_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES flashcards (id)',
    ),
  );
  static const VerificationMeta _grammarPatternKeyMeta = const VerificationMeta(
    'grammarPatternKey',
  );
  @override
  late final GeneratedColumn<String> grammarPatternKey =
      GeneratedColumn<String>(
        'grammar_pattern_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<DateTime> due = GeneratedColumn<DateTime>(
    'due',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('newCard'),
  );
  static const VerificationMeta _lastReviewedMeta = const VerificationMeta(
    'lastReviewed',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewed = GeneratedColumn<DateTime>(
    'last_reviewed',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardType,
    flashcardId,
    grammarPatternKey,
    stability,
    difficulty,
    due,
    reps,
    state,
    lastReviewed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'srs_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<SrsCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_type')) {
      context.handle(
        _cardTypeMeta,
        cardType.isAcceptableOrUnknown(data['card_type']!, _cardTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_cardTypeMeta);
    }
    if (data.containsKey('flashcard_id')) {
      context.handle(
        _flashcardIdMeta,
        flashcardId.isAcceptableOrUnknown(
          data['flashcard_id']!,
          _flashcardIdMeta,
        ),
      );
    }
    if (data.containsKey('grammar_pattern_key')) {
      context.handle(
        _grammarPatternKeyMeta,
        grammarPatternKey.isAcceptableOrUnknown(
          data['grammar_pattern_key']!,
          _grammarPatternKeyMeta,
        ),
      );
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('last_reviewed')) {
      context.handle(
        _lastReviewedMeta,
        lastReviewed.isAcceptableOrUnknown(
          data['last_reviewed']!,
          _lastReviewedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SrsCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SrsCard(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      cardType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}card_type'],
          )!,
      flashcardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flashcard_id'],
      ),
      grammarPatternKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grammar_pattern_key'],
      ),
      stability:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}stability'],
          )!,
      difficulty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}difficulty'],
          )!,
      due:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}due'],
          )!,
      reps:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}reps'],
          )!,
      state:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}state'],
          )!,
      lastReviewed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed'],
      ),
    );
  }

  @override
  $SrsCardsTable createAlias(String alias) {
    return $SrsCardsTable(attachedDatabase, alias);
  }
}

class SrsCard extends DataClass implements Insertable<SrsCard> {
  final int id;
  final String cardType;
  final int? flashcardId;
  final String? grammarPatternKey;
  final double stability;
  final double difficulty;
  final DateTime due;
  final int reps;
  final String state;
  final DateTime? lastReviewed;
  const SrsCard({
    required this.id,
    required this.cardType,
    this.flashcardId,
    this.grammarPatternKey,
    required this.stability,
    required this.difficulty,
    required this.due,
    required this.reps,
    required this.state,
    this.lastReviewed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_type'] = Variable<String>(cardType);
    if (!nullToAbsent || flashcardId != null) {
      map['flashcard_id'] = Variable<int>(flashcardId);
    }
    if (!nullToAbsent || grammarPatternKey != null) {
      map['grammar_pattern_key'] = Variable<String>(grammarPatternKey);
    }
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    map['due'] = Variable<DateTime>(due);
    map['reps'] = Variable<int>(reps);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastReviewed != null) {
      map['last_reviewed'] = Variable<DateTime>(lastReviewed);
    }
    return map;
  }

  SrsCardsCompanion toCompanion(bool nullToAbsent) {
    return SrsCardsCompanion(
      id: Value(id),
      cardType: Value(cardType),
      flashcardId:
          flashcardId == null && nullToAbsent
              ? const Value.absent()
              : Value(flashcardId),
      grammarPatternKey:
          grammarPatternKey == null && nullToAbsent
              ? const Value.absent()
              : Value(grammarPatternKey),
      stability: Value(stability),
      difficulty: Value(difficulty),
      due: Value(due),
      reps: Value(reps),
      state: Value(state),
      lastReviewed:
          lastReviewed == null && nullToAbsent
              ? const Value.absent()
              : Value(lastReviewed),
    );
  }

  factory SrsCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SrsCard(
      id: serializer.fromJson<int>(json['id']),
      cardType: serializer.fromJson<String>(json['cardType']),
      flashcardId: serializer.fromJson<int?>(json['flashcardId']),
      grammarPatternKey: serializer.fromJson<String?>(
        json['grammarPatternKey'],
      ),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      due: serializer.fromJson<DateTime>(json['due']),
      reps: serializer.fromJson<int>(json['reps']),
      state: serializer.fromJson<String>(json['state']),
      lastReviewed: serializer.fromJson<DateTime?>(json['lastReviewed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardType': serializer.toJson<String>(cardType),
      'flashcardId': serializer.toJson<int?>(flashcardId),
      'grammarPatternKey': serializer.toJson<String?>(grammarPatternKey),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'due': serializer.toJson<DateTime>(due),
      'reps': serializer.toJson<int>(reps),
      'state': serializer.toJson<String>(state),
      'lastReviewed': serializer.toJson<DateTime?>(lastReviewed),
    };
  }

  SrsCard copyWith({
    int? id,
    String? cardType,
    Value<int?> flashcardId = const Value.absent(),
    Value<String?> grammarPatternKey = const Value.absent(),
    double? stability,
    double? difficulty,
    DateTime? due,
    int? reps,
    String? state,
    Value<DateTime?> lastReviewed = const Value.absent(),
  }) => SrsCard(
    id: id ?? this.id,
    cardType: cardType ?? this.cardType,
    flashcardId: flashcardId.present ? flashcardId.value : this.flashcardId,
    grammarPatternKey:
        grammarPatternKey.present
            ? grammarPatternKey.value
            : this.grammarPatternKey,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    due: due ?? this.due,
    reps: reps ?? this.reps,
    state: state ?? this.state,
    lastReviewed: lastReviewed.present ? lastReviewed.value : this.lastReviewed,
  );
  SrsCard copyWithCompanion(SrsCardsCompanion data) {
    return SrsCard(
      id: data.id.present ? data.id.value : this.id,
      cardType: data.cardType.present ? data.cardType.value : this.cardType,
      flashcardId:
          data.flashcardId.present ? data.flashcardId.value : this.flashcardId,
      grammarPatternKey:
          data.grammarPatternKey.present
              ? data.grammarPatternKey.value
              : this.grammarPatternKey,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      due: data.due.present ? data.due.value : this.due,
      reps: data.reps.present ? data.reps.value : this.reps,
      state: data.state.present ? data.state.value : this.state,
      lastReviewed:
          data.lastReviewed.present
              ? data.lastReviewed.value
              : this.lastReviewed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SrsCard(')
          ..write('id: $id, ')
          ..write('cardType: $cardType, ')
          ..write('flashcardId: $flashcardId, ')
          ..write('grammarPatternKey: $grammarPatternKey, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('reps: $reps, ')
          ..write('state: $state, ')
          ..write('lastReviewed: $lastReviewed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardType,
    flashcardId,
    grammarPatternKey,
    stability,
    difficulty,
    due,
    reps,
    state,
    lastReviewed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SrsCard &&
          other.id == this.id &&
          other.cardType == this.cardType &&
          other.flashcardId == this.flashcardId &&
          other.grammarPatternKey == this.grammarPatternKey &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.due == this.due &&
          other.reps == this.reps &&
          other.state == this.state &&
          other.lastReviewed == this.lastReviewed);
}

class SrsCardsCompanion extends UpdateCompanion<SrsCard> {
  final Value<int> id;
  final Value<String> cardType;
  final Value<int?> flashcardId;
  final Value<String?> grammarPatternKey;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<DateTime> due;
  final Value<int> reps;
  final Value<String> state;
  final Value<DateTime?> lastReviewed;
  const SrsCardsCompanion({
    this.id = const Value.absent(),
    this.cardType = const Value.absent(),
    this.flashcardId = const Value.absent(),
    this.grammarPatternKey = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.due = const Value.absent(),
    this.reps = const Value.absent(),
    this.state = const Value.absent(),
    this.lastReviewed = const Value.absent(),
  });
  SrsCardsCompanion.insert({
    this.id = const Value.absent(),
    required String cardType,
    this.flashcardId = const Value.absent(),
    this.grammarPatternKey = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.due = const Value.absent(),
    this.reps = const Value.absent(),
    this.state = const Value.absent(),
    this.lastReviewed = const Value.absent(),
  }) : cardType = Value(cardType);
  static Insertable<SrsCard> custom({
    Expression<int>? id,
    Expression<String>? cardType,
    Expression<int>? flashcardId,
    Expression<String>? grammarPatternKey,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<DateTime>? due,
    Expression<int>? reps,
    Expression<String>? state,
    Expression<DateTime>? lastReviewed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardType != null) 'card_type': cardType,
      if (flashcardId != null) 'flashcard_id': flashcardId,
      if (grammarPatternKey != null) 'grammar_pattern_key': grammarPatternKey,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (due != null) 'due': due,
      if (reps != null) 'reps': reps,
      if (state != null) 'state': state,
      if (lastReviewed != null) 'last_reviewed': lastReviewed,
    });
  }

  SrsCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? cardType,
    Value<int?>? flashcardId,
    Value<String?>? grammarPatternKey,
    Value<double>? stability,
    Value<double>? difficulty,
    Value<DateTime>? due,
    Value<int>? reps,
    Value<String>? state,
    Value<DateTime?>? lastReviewed,
  }) {
    return SrsCardsCompanion(
      id: id ?? this.id,
      cardType: cardType ?? this.cardType,
      flashcardId: flashcardId ?? this.flashcardId,
      grammarPatternKey: grammarPatternKey ?? this.grammarPatternKey,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      due: due ?? this.due,
      reps: reps ?? this.reps,
      state: state ?? this.state,
      lastReviewed: lastReviewed ?? this.lastReviewed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardType.present) {
      map['card_type'] = Variable<String>(cardType.value);
    }
    if (flashcardId.present) {
      map['flashcard_id'] = Variable<int>(flashcardId.value);
    }
    if (grammarPatternKey.present) {
      map['grammar_pattern_key'] = Variable<String>(grammarPatternKey.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (due.present) {
      map['due'] = Variable<DateTime>(due.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastReviewed.present) {
      map['last_reviewed'] = Variable<DateTime>(lastReviewed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SrsCardsCompanion(')
          ..write('id: $id, ')
          ..write('cardType: $cardType, ')
          ..write('flashcardId: $flashcardId, ')
          ..write('grammarPatternKey: $grammarPatternKey, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('reps: $reps, ')
          ..write('state: $state, ')
          ..write('lastReviewed: $lastReviewed')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scenarioMeta = const VerificationMeta(
    'scenario',
  );
  @override
  late final GeneratedColumn<String> scenario = GeneratedColumn<String>(
    'scenario',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cefrLevelMeta = const VerificationMeta(
    'cefrLevel',
  );
  @override
  late final GeneratedColumn<String> cefrLevel = GeneratedColumn<String>(
    'cefr_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [id, scenario, cefrLevel, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scenario')) {
      context.handle(
        _scenarioMeta,
        scenario.isAcceptableOrUnknown(data['scenario']!, _scenarioMeta),
      );
    } else if (isInserting) {
      context.missing(_scenarioMeta);
    }
    if (data.containsKey('cefr_level')) {
      context.handle(
        _cefrLevelMeta,
        cefrLevel.isAcceptableOrUnknown(data['cefr_level']!, _cefrLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_cefrLevelMeta);
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
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      scenario:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}scenario'],
          )!,
      cefrLevel:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}cefr_level'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;
  final String scenario;
  final String cefrLevel;
  final DateTime createdAt;
  const Conversation({
    required this.id,
    required this.scenario,
    required this.cefrLevel,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scenario'] = Variable<String>(scenario);
    map['cefr_level'] = Variable<String>(cefrLevel);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      scenario: Value(scenario),
      cefrLevel: Value(cefrLevel),
      createdAt: Value(createdAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      scenario: serializer.fromJson<String>(json['scenario']),
      cefrLevel: serializer.fromJson<String>(json['cefrLevel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scenario': serializer.toJson<String>(scenario),
      'cefrLevel': serializer.toJson<String>(cefrLevel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Conversation copyWith({
    String? id,
    String? scenario,
    String? cefrLevel,
    DateTime? createdAt,
  }) => Conversation(
    id: id ?? this.id,
    scenario: scenario ?? this.scenario,
    cefrLevel: cefrLevel ?? this.cefrLevel,
    createdAt: createdAt ?? this.createdAt,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      scenario: data.scenario.present ? data.scenario.value : this.scenario,
      cefrLevel: data.cefrLevel.present ? data.cefrLevel.value : this.cefrLevel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('scenario: $scenario, ')
          ..write('cefrLevel: $cefrLevel, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scenario, cefrLevel, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.scenario == this.scenario &&
          other.cefrLevel == this.cefrLevel &&
          other.createdAt == this.createdAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<String> scenario;
  final Value<String> cefrLevel;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.scenario = const Value.absent(),
    this.cefrLevel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String scenario,
    required String cefrLevel,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scenario = Value(scenario),
       cefrLevel = Value(cefrLevel);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? scenario,
    Expression<String>? cefrLevel,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scenario != null) 'scenario': scenario,
      if (cefrLevel != null) 'cefr_level': cefrLevel,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? scenario,
    Value<String>? cefrLevel,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      scenario: scenario ?? this.scenario,
      cefrLevel: cefrLevel ?? this.cefrLevel,
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
    if (scenario.present) {
      map['scenario'] = Variable<String>(scenario.value);
    }
    if (cefrLevel.present) {
      map['cefr_level'] = Variable<String>(cefrLevel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('scenario: $scenario, ')
          ..write('cefrLevel: $cefrLevel, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id)',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _correctionsMeta = const VerificationMeta(
    'corrections',
  );
  @override
  late final GeneratedColumn<String> corrections = GeneratedColumn<String>(
    'corrections',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newVocabularyMeta = const VerificationMeta(
    'newVocabulary',
  );
  @override
  late final GeneratedColumn<String> newVocabulary = GeneratedColumn<String>(
    'new_vocabulary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    role,
    content,
    translation,
    corrections,
    newVocabulary,
    audioPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    }
    if (data.containsKey('corrections')) {
      context.handle(
        _correctionsMeta,
        corrections.isAcceptableOrUnknown(
          data['corrections']!,
          _correctionsMeta,
        ),
      );
    }
    if (data.containsKey('new_vocabulary')) {
      context.handle(
        _newVocabularyMeta,
        newVocabulary.isAcceptableOrUnknown(
          data['new_vocabulary']!,
          _newVocabularyMeta,
        ),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
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
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      conversationId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}conversation_id'],
          )!,
      role:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}role'],
          )!,
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      ),
      corrections: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}corrections'],
      ),
      newVocabulary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_vocabulary'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final int id;
  final String conversationId;
  final String role;
  final String content;
  final String? translation;
  final String? corrections;
  final String? newVocabulary;
  final String? audioPath;
  final DateTime createdAt;
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.translation,
    this.corrections,
    this.newVocabulary,
    this.audioPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || translation != null) {
      map['translation'] = Variable<String>(translation);
    }
    if (!nullToAbsent || corrections != null) {
      map['corrections'] = Variable<String>(corrections);
    }
    if (!nullToAbsent || newVocabulary != null) {
      map['new_vocabulary'] = Variable<String>(newVocabulary);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      translation:
          translation == null && nullToAbsent
              ? const Value.absent()
              : Value(translation),
      corrections:
          corrections == null && nullToAbsent
              ? const Value.absent()
              : Value(corrections),
      newVocabulary:
          newVocabulary == null && nullToAbsent
              ? const Value.absent()
              : Value(newVocabulary),
      audioPath:
          audioPath == null && nullToAbsent
              ? const Value.absent()
              : Value(audioPath),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      translation: serializer.fromJson<String?>(json['translation']),
      corrections: serializer.fromJson<String?>(json['corrections']),
      newVocabulary: serializer.fromJson<String?>(json['newVocabulary']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'translation': serializer.toJson<String?>(translation),
      'corrections': serializer.toJson<String?>(corrections),
      'newVocabulary': serializer.toJson<String?>(newVocabulary),
      'audioPath': serializer.toJson<String?>(audioPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessage copyWith({
    int? id,
    String? conversationId,
    String? role,
    String? content,
    Value<String?> translation = const Value.absent(),
    Value<String?> corrections = const Value.absent(),
    Value<String?> newVocabulary = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    translation: translation.present ? translation.value : this.translation,
    corrections: corrections.present ? corrections.value : this.corrections,
    newVocabulary:
        newVocabulary.present ? newVocabulary.value : this.newVocabulary,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId:
          data.conversationId.present
              ? data.conversationId.value
              : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      translation:
          data.translation.present ? data.translation.value : this.translation,
      corrections:
          data.corrections.present ? data.corrections.value : this.corrections,
      newVocabulary:
          data.newVocabulary.present
              ? data.newVocabulary.value
              : this.newVocabulary,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('translation: $translation, ')
          ..write('corrections: $corrections, ')
          ..write('newVocabulary: $newVocabulary, ')
          ..write('audioPath: $audioPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    role,
    content,
    translation,
    corrections,
    newVocabulary,
    audioPath,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.translation == this.translation &&
          other.corrections == this.corrections &&
          other.newVocabulary == this.newVocabulary &&
          other.audioPath == this.audioPath &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<int> id;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String?> translation;
  final Value<String?> corrections;
  final Value<String?> newVocabulary;
  final Value<String?> audioPath;
  final Value<DateTime> createdAt;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.translation = const Value.absent(),
    this.corrections = const Value.absent(),
    this.newVocabulary = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String conversationId,
    required String role,
    required String content,
    this.translation = const Value.absent(),
    this.corrections = const Value.absent(),
    this.newVocabulary = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : conversationId = Value(conversationId),
       role = Value(role),
       content = Value(content);
  static Insertable<ChatMessage> custom({
    Expression<int>? id,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? translation,
    Expression<String>? corrections,
    Expression<String>? newVocabulary,
    Expression<String>? audioPath,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (translation != null) 'translation': translation,
      if (corrections != null) 'corrections': corrections,
      if (newVocabulary != null) 'new_vocabulary': newVocabulary,
      if (audioPath != null) 'audio_path': audioPath,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? conversationId,
    Value<String>? role,
    Value<String>? content,
    Value<String?>? translation,
    Value<String?>? corrections,
    Value<String?>? newVocabulary,
    Value<String?>? audioPath,
    Value<DateTime>? createdAt,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      translation: translation ?? this.translation,
      corrections: corrections ?? this.corrections,
      newVocabulary: newVocabulary ?? this.newVocabulary,
      audioPath: audioPath ?? this.audioPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (corrections.present) {
      map['corrections'] = Variable<String>(corrections.value);
    }
    if (newVocabulary.present) {
      map['new_vocabulary'] = Variable<String>(newVocabulary.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('translation: $translation, ')
          ..write('corrections: $corrections, ')
          ..write('newVocabulary: $newVocabulary, ')
          ..write('audioPath: $audioPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GrammarRulesTable extends GrammarRules
    with TableInfo<$GrammarRulesTable, GrammarRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GrammarRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleNameMeta = const VerificationMeta(
    'ruleName',
  );
  @override
  late final GeneratedColumn<String> ruleName = GeneratedColumn<String>(
    'rule_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseAffectedMeta = const VerificationMeta(
    'caseAffected',
  );
  @override
  late final GeneratedColumn<String> caseAffected = GeneratedColumn<String>(
    'case_affected',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _examplesMeta = const VerificationMeta(
    'examples',
  );
  @override
  late final GeneratedColumn<String> examples = GeneratedColumn<String>(
    'examples',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<int> unitId = GeneratedColumn<int>(
    'unit_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES units (id)',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ruleName,
    pattern,
    explanation,
    caseAffected,
    examples,
    unitId,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grammar_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<GrammarRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('rule_name')) {
      context.handle(
        _ruleNameMeta,
        ruleName.isAcceptableOrUnknown(data['rule_name']!, _ruleNameMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleNameMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_explanationMeta);
    }
    if (data.containsKey('case_affected')) {
      context.handle(
        _caseAffectedMeta,
        caseAffected.isAcceptableOrUnknown(
          data['case_affected']!,
          _caseAffectedMeta,
        ),
      );
    }
    if (data.containsKey('examples')) {
      context.handle(
        _examplesMeta,
        examples.isAcceptableOrUnknown(data['examples']!, _examplesMeta),
      );
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GrammarRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GrammarRule(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      ruleName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}rule_name'],
          )!,
      pattern:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}pattern'],
          )!,
      explanation:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}explanation'],
          )!,
      caseAffected: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_affected'],
      ),
      examples:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}examples'],
          )!,
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_id'],
      ),
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
    );
  }

  @override
  $GrammarRulesTable createAlias(String alias) {
    return $GrammarRulesTable(attachedDatabase, alias);
  }
}

class GrammarRule extends DataClass implements Insertable<GrammarRule> {
  final String id;
  final String ruleName;
  final String pattern;
  final String explanation;
  final String? caseAffected;
  final String examples;
  final int? unitId;
  final bool isActive;
  const GrammarRule({
    required this.id,
    required this.ruleName,
    required this.pattern,
    required this.explanation,
    this.caseAffected,
    required this.examples,
    this.unitId,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['rule_name'] = Variable<String>(ruleName);
    map['pattern'] = Variable<String>(pattern);
    map['explanation'] = Variable<String>(explanation);
    if (!nullToAbsent || caseAffected != null) {
      map['case_affected'] = Variable<String>(caseAffected);
    }
    map['examples'] = Variable<String>(examples);
    if (!nullToAbsent || unitId != null) {
      map['unit_id'] = Variable<int>(unitId);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  GrammarRulesCompanion toCompanion(bool nullToAbsent) {
    return GrammarRulesCompanion(
      id: Value(id),
      ruleName: Value(ruleName),
      pattern: Value(pattern),
      explanation: Value(explanation),
      caseAffected:
          caseAffected == null && nullToAbsent
              ? const Value.absent()
              : Value(caseAffected),
      examples: Value(examples),
      unitId:
          unitId == null && nullToAbsent ? const Value.absent() : Value(unitId),
      isActive: Value(isActive),
    );
  }

  factory GrammarRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GrammarRule(
      id: serializer.fromJson<String>(json['id']),
      ruleName: serializer.fromJson<String>(json['ruleName']),
      pattern: serializer.fromJson<String>(json['pattern']),
      explanation: serializer.fromJson<String>(json['explanation']),
      caseAffected: serializer.fromJson<String?>(json['caseAffected']),
      examples: serializer.fromJson<String>(json['examples']),
      unitId: serializer.fromJson<int?>(json['unitId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ruleName': serializer.toJson<String>(ruleName),
      'pattern': serializer.toJson<String>(pattern),
      'explanation': serializer.toJson<String>(explanation),
      'caseAffected': serializer.toJson<String?>(caseAffected),
      'examples': serializer.toJson<String>(examples),
      'unitId': serializer.toJson<int?>(unitId),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  GrammarRule copyWith({
    String? id,
    String? ruleName,
    String? pattern,
    String? explanation,
    Value<String?> caseAffected = const Value.absent(),
    String? examples,
    Value<int?> unitId = const Value.absent(),
    bool? isActive,
  }) => GrammarRule(
    id: id ?? this.id,
    ruleName: ruleName ?? this.ruleName,
    pattern: pattern ?? this.pattern,
    explanation: explanation ?? this.explanation,
    caseAffected: caseAffected.present ? caseAffected.value : this.caseAffected,
    examples: examples ?? this.examples,
    unitId: unitId.present ? unitId.value : this.unitId,
    isActive: isActive ?? this.isActive,
  );
  GrammarRule copyWithCompanion(GrammarRulesCompanion data) {
    return GrammarRule(
      id: data.id.present ? data.id.value : this.id,
      ruleName: data.ruleName.present ? data.ruleName.value : this.ruleName,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      explanation:
          data.explanation.present ? data.explanation.value : this.explanation,
      caseAffected:
          data.caseAffected.present
              ? data.caseAffected.value
              : this.caseAffected,
      examples: data.examples.present ? data.examples.value : this.examples,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GrammarRule(')
          ..write('id: $id, ')
          ..write('ruleName: $ruleName, ')
          ..write('pattern: $pattern, ')
          ..write('explanation: $explanation, ')
          ..write('caseAffected: $caseAffected, ')
          ..write('examples: $examples, ')
          ..write('unitId: $unitId, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ruleName,
    pattern,
    explanation,
    caseAffected,
    examples,
    unitId,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GrammarRule &&
          other.id == this.id &&
          other.ruleName == this.ruleName &&
          other.pattern == this.pattern &&
          other.explanation == this.explanation &&
          other.caseAffected == this.caseAffected &&
          other.examples == this.examples &&
          other.unitId == this.unitId &&
          other.isActive == this.isActive);
}

class GrammarRulesCompanion extends UpdateCompanion<GrammarRule> {
  final Value<String> id;
  final Value<String> ruleName;
  final Value<String> pattern;
  final Value<String> explanation;
  final Value<String?> caseAffected;
  final Value<String> examples;
  final Value<int?> unitId;
  final Value<bool> isActive;
  final Value<int> rowid;
  const GrammarRulesCompanion({
    this.id = const Value.absent(),
    this.ruleName = const Value.absent(),
    this.pattern = const Value.absent(),
    this.explanation = const Value.absent(),
    this.caseAffected = const Value.absent(),
    this.examples = const Value.absent(),
    this.unitId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GrammarRulesCompanion.insert({
    required String id,
    required String ruleName,
    required String pattern,
    required String explanation,
    this.caseAffected = const Value.absent(),
    this.examples = const Value.absent(),
    this.unitId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ruleName = Value(ruleName),
       pattern = Value(pattern),
       explanation = Value(explanation);
  static Insertable<GrammarRule> custom({
    Expression<String>? id,
    Expression<String>? ruleName,
    Expression<String>? pattern,
    Expression<String>? explanation,
    Expression<String>? caseAffected,
    Expression<String>? examples,
    Expression<int>? unitId,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ruleName != null) 'rule_name': ruleName,
      if (pattern != null) 'pattern': pattern,
      if (explanation != null) 'explanation': explanation,
      if (caseAffected != null) 'case_affected': caseAffected,
      if (examples != null) 'examples': examples,
      if (unitId != null) 'unit_id': unitId,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GrammarRulesCompanion copyWith({
    Value<String>? id,
    Value<String>? ruleName,
    Value<String>? pattern,
    Value<String>? explanation,
    Value<String?>? caseAffected,
    Value<String>? examples,
    Value<int?>? unitId,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return GrammarRulesCompanion(
      id: id ?? this.id,
      ruleName: ruleName ?? this.ruleName,
      pattern: pattern ?? this.pattern,
      explanation: explanation ?? this.explanation,
      caseAffected: caseAffected ?? this.caseAffected,
      examples: examples ?? this.examples,
      unitId: unitId ?? this.unitId,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ruleName.present) {
      map['rule_name'] = Variable<String>(ruleName.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (caseAffected.present) {
      map['case_affected'] = Variable<String>(caseAffected.value);
    }
    if (examples.present) {
      map['examples'] = Variable<String>(examples.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<int>(unitId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GrammarRulesCompanion(')
          ..write('id: $id, ')
          ..write('ruleName: $ruleName, ')
          ..write('pattern: $pattern, ')
          ..write('explanation: $explanation, ')
          ..write('caseAffected: $caseAffected, ')
          ..write('examples: $examples, ')
          ..write('unitId: $unitId, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExamResultsTable extends ExamResults
    with TableInfo<$ExamResultsTable, ExamResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExamResultsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productMeta = const VerificationMeta(
    'product',
  );
  @override
  late final GeneratedColumn<String> product = GeneratedColumn<String>(
    'product',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('permanent_residence'),
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  static const VerificationMeta _readingScoreMeta = const VerificationMeta(
    'readingScore',
  );
  @override
  late final GeneratedColumn<int> readingScore = GeneratedColumn<int>(
    'reading_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _listeningScoreMeta = const VerificationMeta(
    'listeningScore',
  );
  @override
  late final GeneratedColumn<int> listeningScore = GeneratedColumn<int>(
    'listening_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _writingScoreMeta = const VerificationMeta(
    'writingScore',
  );
  @override
  late final GeneratedColumn<int> writingScore = GeneratedColumn<int>(
    'writing_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _speakingScoreMeta = const VerificationMeta(
    'speakingScore',
  );
  @override
  late final GeneratedColumn<int> speakingScore = GeneratedColumn<int>(
    'speaking_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalScoreMeta = const VerificationMeta(
    'totalScore',
  );
  @override
  late final GeneratedColumn<int> totalScore = GeneratedColumn<int>(
    'total_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _passedMeta = const VerificationMeta('passed');
  @override
  late final GeneratedColumn<bool> passed = GeneratedColumn<bool>(
    'passed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("passed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    level,
    product,
    takenAt,
    readingScore,
    listeningScore,
    writingScore,
    speakingScore,
    totalScore,
    passed,
    details,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exam_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExamResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('product')) {
      context.handle(
        _productMeta,
        product.isAcceptableOrUnknown(data['product']!, _productMeta),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('reading_score')) {
      context.handle(
        _readingScoreMeta,
        readingScore.isAcceptableOrUnknown(
          data['reading_score']!,
          _readingScoreMeta,
        ),
      );
    }
    if (data.containsKey('listening_score')) {
      context.handle(
        _listeningScoreMeta,
        listeningScore.isAcceptableOrUnknown(
          data['listening_score']!,
          _listeningScoreMeta,
        ),
      );
    }
    if (data.containsKey('writing_score')) {
      context.handle(
        _writingScoreMeta,
        writingScore.isAcceptableOrUnknown(
          data['writing_score']!,
          _writingScoreMeta,
        ),
      );
    }
    if (data.containsKey('speaking_score')) {
      context.handle(
        _speakingScoreMeta,
        speakingScore.isAcceptableOrUnknown(
          data['speaking_score']!,
          _speakingScoreMeta,
        ),
      );
    }
    if (data.containsKey('total_score')) {
      context.handle(
        _totalScoreMeta,
        totalScore.isAcceptableOrUnknown(data['total_score']!, _totalScoreMeta),
      );
    }
    if (data.containsKey('passed')) {
      context.handle(
        _passedMeta,
        passed.isAcceptableOrUnknown(data['passed']!, _passedMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExamResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExamResult(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      level:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}level'],
          )!,
      product:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}product'],
          )!,
      takenAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}taken_at'],
          )!,
      readingScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}reading_score'],
          )!,
      listeningScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}listening_score'],
          )!,
      writingScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}writing_score'],
          )!,
      speakingScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}speaking_score'],
          )!,
      totalScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total_score'],
          )!,
      passed:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}passed'],
          )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
    );
  }

  @override
  $ExamResultsTable createAlias(String alias) {
    return $ExamResultsTable(attachedDatabase, alias);
  }
}

class ExamResult extends DataClass implements Insertable<ExamResult> {
  final int id;
  final String level;

  /// Official exam product: 'permanent_residence' (default) or 'cce'.
  final String product;
  final DateTime takenAt;
  final int readingScore;
  final int listeningScore;
  final int writingScore;
  final int speakingScore;
  final int totalScore;
  final bool passed;
  final String? details;
  const ExamResult({
    required this.id,
    required this.level,
    required this.product,
    required this.takenAt,
    required this.readingScore,
    required this.listeningScore,
    required this.writingScore,
    required this.speakingScore,
    required this.totalScore,
    required this.passed,
    this.details,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['level'] = Variable<String>(level);
    map['product'] = Variable<String>(product);
    map['taken_at'] = Variable<DateTime>(takenAt);
    map['reading_score'] = Variable<int>(readingScore);
    map['listening_score'] = Variable<int>(listeningScore);
    map['writing_score'] = Variable<int>(writingScore);
    map['speaking_score'] = Variable<int>(speakingScore);
    map['total_score'] = Variable<int>(totalScore);
    map['passed'] = Variable<bool>(passed);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    return map;
  }

  ExamResultsCompanion toCompanion(bool nullToAbsent) {
    return ExamResultsCompanion(
      id: Value(id),
      level: Value(level),
      product: Value(product),
      takenAt: Value(takenAt),
      readingScore: Value(readingScore),
      listeningScore: Value(listeningScore),
      writingScore: Value(writingScore),
      speakingScore: Value(speakingScore),
      totalScore: Value(totalScore),
      passed: Value(passed),
      details:
          details == null && nullToAbsent
              ? const Value.absent()
              : Value(details),
    );
  }

  factory ExamResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExamResult(
      id: serializer.fromJson<int>(json['id']),
      level: serializer.fromJson<String>(json['level']),
      product: serializer.fromJson<String>(json['product']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
      readingScore: serializer.fromJson<int>(json['readingScore']),
      listeningScore: serializer.fromJson<int>(json['listeningScore']),
      writingScore: serializer.fromJson<int>(json['writingScore']),
      speakingScore: serializer.fromJson<int>(json['speakingScore']),
      totalScore: serializer.fromJson<int>(json['totalScore']),
      passed: serializer.fromJson<bool>(json['passed']),
      details: serializer.fromJson<String?>(json['details']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'level': serializer.toJson<String>(level),
      'product': serializer.toJson<String>(product),
      'takenAt': serializer.toJson<DateTime>(takenAt),
      'readingScore': serializer.toJson<int>(readingScore),
      'listeningScore': serializer.toJson<int>(listeningScore),
      'writingScore': serializer.toJson<int>(writingScore),
      'speakingScore': serializer.toJson<int>(speakingScore),
      'totalScore': serializer.toJson<int>(totalScore),
      'passed': serializer.toJson<bool>(passed),
      'details': serializer.toJson<String?>(details),
    };
  }

  ExamResult copyWith({
    int? id,
    String? level,
    String? product,
    DateTime? takenAt,
    int? readingScore,
    int? listeningScore,
    int? writingScore,
    int? speakingScore,
    int? totalScore,
    bool? passed,
    Value<String?> details = const Value.absent(),
  }) => ExamResult(
    id: id ?? this.id,
    level: level ?? this.level,
    product: product ?? this.product,
    takenAt: takenAt ?? this.takenAt,
    readingScore: readingScore ?? this.readingScore,
    listeningScore: listeningScore ?? this.listeningScore,
    writingScore: writingScore ?? this.writingScore,
    speakingScore: speakingScore ?? this.speakingScore,
    totalScore: totalScore ?? this.totalScore,
    passed: passed ?? this.passed,
    details: details.present ? details.value : this.details,
  );
  ExamResult copyWithCompanion(ExamResultsCompanion data) {
    return ExamResult(
      id: data.id.present ? data.id.value : this.id,
      level: data.level.present ? data.level.value : this.level,
      product: data.product.present ? data.product.value : this.product,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      readingScore:
          data.readingScore.present
              ? data.readingScore.value
              : this.readingScore,
      listeningScore:
          data.listeningScore.present
              ? data.listeningScore.value
              : this.listeningScore,
      writingScore:
          data.writingScore.present
              ? data.writingScore.value
              : this.writingScore,
      speakingScore:
          data.speakingScore.present
              ? data.speakingScore.value
              : this.speakingScore,
      totalScore:
          data.totalScore.present ? data.totalScore.value : this.totalScore,
      passed: data.passed.present ? data.passed.value : this.passed,
      details: data.details.present ? data.details.value : this.details,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExamResult(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('product: $product, ')
          ..write('takenAt: $takenAt, ')
          ..write('readingScore: $readingScore, ')
          ..write('listeningScore: $listeningScore, ')
          ..write('writingScore: $writingScore, ')
          ..write('speakingScore: $speakingScore, ')
          ..write('totalScore: $totalScore, ')
          ..write('passed: $passed, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    level,
    product,
    takenAt,
    readingScore,
    listeningScore,
    writingScore,
    speakingScore,
    totalScore,
    passed,
    details,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExamResult &&
          other.id == this.id &&
          other.level == this.level &&
          other.product == this.product &&
          other.takenAt == this.takenAt &&
          other.readingScore == this.readingScore &&
          other.listeningScore == this.listeningScore &&
          other.writingScore == this.writingScore &&
          other.speakingScore == this.speakingScore &&
          other.totalScore == this.totalScore &&
          other.passed == this.passed &&
          other.details == this.details);
}

class ExamResultsCompanion extends UpdateCompanion<ExamResult> {
  final Value<int> id;
  final Value<String> level;
  final Value<String> product;
  final Value<DateTime> takenAt;
  final Value<int> readingScore;
  final Value<int> listeningScore;
  final Value<int> writingScore;
  final Value<int> speakingScore;
  final Value<int> totalScore;
  final Value<bool> passed;
  final Value<String?> details;
  const ExamResultsCompanion({
    this.id = const Value.absent(),
    this.level = const Value.absent(),
    this.product = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.readingScore = const Value.absent(),
    this.listeningScore = const Value.absent(),
    this.writingScore = const Value.absent(),
    this.speakingScore = const Value.absent(),
    this.totalScore = const Value.absent(),
    this.passed = const Value.absent(),
    this.details = const Value.absent(),
  });
  ExamResultsCompanion.insert({
    this.id = const Value.absent(),
    required String level,
    this.product = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.readingScore = const Value.absent(),
    this.listeningScore = const Value.absent(),
    this.writingScore = const Value.absent(),
    this.speakingScore = const Value.absent(),
    this.totalScore = const Value.absent(),
    this.passed = const Value.absent(),
    this.details = const Value.absent(),
  }) : level = Value(level);
  static Insertable<ExamResult> custom({
    Expression<int>? id,
    Expression<String>? level,
    Expression<String>? product,
    Expression<DateTime>? takenAt,
    Expression<int>? readingScore,
    Expression<int>? listeningScore,
    Expression<int>? writingScore,
    Expression<int>? speakingScore,
    Expression<int>? totalScore,
    Expression<bool>? passed,
    Expression<String>? details,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (level != null) 'level': level,
      if (product != null) 'product': product,
      if (takenAt != null) 'taken_at': takenAt,
      if (readingScore != null) 'reading_score': readingScore,
      if (listeningScore != null) 'listening_score': listeningScore,
      if (writingScore != null) 'writing_score': writingScore,
      if (speakingScore != null) 'speaking_score': speakingScore,
      if (totalScore != null) 'total_score': totalScore,
      if (passed != null) 'passed': passed,
      if (details != null) 'details': details,
    });
  }

  ExamResultsCompanion copyWith({
    Value<int>? id,
    Value<String>? level,
    Value<String>? product,
    Value<DateTime>? takenAt,
    Value<int>? readingScore,
    Value<int>? listeningScore,
    Value<int>? writingScore,
    Value<int>? speakingScore,
    Value<int>? totalScore,
    Value<bool>? passed,
    Value<String?>? details,
  }) {
    return ExamResultsCompanion(
      id: id ?? this.id,
      level: level ?? this.level,
      product: product ?? this.product,
      takenAt: takenAt ?? this.takenAt,
      readingScore: readingScore ?? this.readingScore,
      listeningScore: listeningScore ?? this.listeningScore,
      writingScore: writingScore ?? this.writingScore,
      speakingScore: speakingScore ?? this.speakingScore,
      totalScore: totalScore ?? this.totalScore,
      passed: passed ?? this.passed,
      details: details ?? this.details,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (product.present) {
      map['product'] = Variable<String>(product.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (readingScore.present) {
      map['reading_score'] = Variable<int>(readingScore.value);
    }
    if (listeningScore.present) {
      map['listening_score'] = Variable<int>(listeningScore.value);
    }
    if (writingScore.present) {
      map['writing_score'] = Variable<int>(writingScore.value);
    }
    if (speakingScore.present) {
      map['speaking_score'] = Variable<int>(speakingScore.value);
    }
    if (totalScore.present) {
      map['total_score'] = Variable<int>(totalScore.value);
    }
    if (passed.present) {
      map['passed'] = Variable<bool>(passed.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExamResultsCompanion(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('product: $product, ')
          ..write('takenAt: $takenAt, ')
          ..write('readingScore: $readingScore, ')
          ..write('listeningScore: $listeningScore, ')
          ..write('writingScore: $writingScore, ')
          ..write('speakingScore: $speakingScore, ')
          ..write('totalScore: $totalScore, ')
          ..write('passed: $passed, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }
}

class $UserProgressTable extends UserProgress
    with TableInfo<$UserProgressTable, UserProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProgressTable(this.attachedDatabase, [this._alias]);
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProgressData> instance, {
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
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProgressData(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $UserProgressTable createAlias(String alias) {
    return $UserProgressTable(attachedDatabase, alias);
  }
}

class UserProgressData extends DataClass
    implements Insertable<UserProgressData> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const UserProgressData({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProgressCompanion toCompanion(bool nullToAbsent) {
    return UserProgressCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProgressData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProgressData copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => UserProgressData(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProgressData copyWithCompanion(UserProgressCompanion data) {
    return UserProgressData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProgressData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProgressData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class UserProgressCompanion extends UpdateCompanion<UserProgressData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserProgressCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProgressCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<UserProgressData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProgressCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserProgressCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProgressCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EarnedBadgesTable extends EarnedBadges
    with TableInfo<$EarnedBadgesTable, EarnedBadge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EarnedBadgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _badgeIdMeta = const VerificationMeta(
    'badgeId',
  );
  @override
  late final GeneratedColumn<String> badgeId = GeneratedColumn<String>(
    'badge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _earnedAtMeta = const VerificationMeta(
    'earnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> earnedAt = GeneratedColumn<DateTime>(
    'earned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [badgeId, earnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'earned_badges';
  @override
  VerificationContext validateIntegrity(
    Insertable<EarnedBadge> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('badge_id')) {
      context.handle(
        _badgeIdMeta,
        badgeId.isAcceptableOrUnknown(data['badge_id']!, _badgeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_badgeIdMeta);
    }
    if (data.containsKey('earned_at')) {
      context.handle(
        _earnedAtMeta,
        earnedAt.isAcceptableOrUnknown(data['earned_at']!, _earnedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {badgeId};
  @override
  EarnedBadge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EarnedBadge(
      badgeId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}badge_id'],
          )!,
      earnedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}earned_at'],
          )!,
    );
  }

  @override
  $EarnedBadgesTable createAlias(String alias) {
    return $EarnedBadgesTable(attachedDatabase, alias);
  }
}

class EarnedBadge extends DataClass implements Insertable<EarnedBadge> {
  final String badgeId;
  final DateTime earnedAt;
  const EarnedBadge({required this.badgeId, required this.earnedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['badge_id'] = Variable<String>(badgeId);
    map['earned_at'] = Variable<DateTime>(earnedAt);
    return map;
  }

  EarnedBadgesCompanion toCompanion(bool nullToAbsent) {
    return EarnedBadgesCompanion(
      badgeId: Value(badgeId),
      earnedAt: Value(earnedAt),
    );
  }

  factory EarnedBadge.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EarnedBadge(
      badgeId: serializer.fromJson<String>(json['badgeId']),
      earnedAt: serializer.fromJson<DateTime>(json['earnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'badgeId': serializer.toJson<String>(badgeId),
      'earnedAt': serializer.toJson<DateTime>(earnedAt),
    };
  }

  EarnedBadge copyWith({String? badgeId, DateTime? earnedAt}) => EarnedBadge(
    badgeId: badgeId ?? this.badgeId,
    earnedAt: earnedAt ?? this.earnedAt,
  );
  EarnedBadge copyWithCompanion(EarnedBadgesCompanion data) {
    return EarnedBadge(
      badgeId: data.badgeId.present ? data.badgeId.value : this.badgeId,
      earnedAt: data.earnedAt.present ? data.earnedAt.value : this.earnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EarnedBadge(')
          ..write('badgeId: $badgeId, ')
          ..write('earnedAt: $earnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(badgeId, earnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EarnedBadge &&
          other.badgeId == this.badgeId &&
          other.earnedAt == this.earnedAt);
}

class EarnedBadgesCompanion extends UpdateCompanion<EarnedBadge> {
  final Value<String> badgeId;
  final Value<DateTime> earnedAt;
  final Value<int> rowid;
  const EarnedBadgesCompanion({
    this.badgeId = const Value.absent(),
    this.earnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EarnedBadgesCompanion.insert({
    required String badgeId,
    this.earnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : badgeId = Value(badgeId);
  static Insertable<EarnedBadge> custom({
    Expression<String>? badgeId,
    Expression<DateTime>? earnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (badgeId != null) 'badge_id': badgeId,
      if (earnedAt != null) 'earned_at': earnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EarnedBadgesCompanion copyWith({
    Value<String>? badgeId,
    Value<DateTime>? earnedAt,
    Value<int>? rowid,
  }) {
    return EarnedBadgesCompanion(
      badgeId: badgeId ?? this.badgeId,
      earnedAt: earnedAt ?? this.earnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (badgeId.present) {
      map['badge_id'] = Variable<String>(badgeId.value);
    }
    if (earnedAt.present) {
      map['earned_at'] = Variable<DateTime>(earnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EarnedBadgesCompanion(')
          ..write('badgeId: $badgeId, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConsentRecordsTable extends ConsentRecords
    with TableInfo<$ConsentRecordsTable, ConsentRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsentRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noticeVersionMeta = const VerificationMeta(
    'noticeVersion',
  );
  @override
  late final GeneratedColumn<String> noticeVersion = GeneratedColumn<String>(
    'notice_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _policyVersionMeta = const VerificationMeta(
    'policyVersion',
  );
  @override
  late final GeneratedColumn<String> policyVersion = GeneratedColumn<String>(
    'policy_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grantedMeta = const VerificationMeta(
    'granted',
  );
  @override
  late final GeneratedColumn<bool> granted = GeneratedColumn<bool>(
    'granted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("granted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _decidedAtMeta = const VerificationMeta(
    'decidedAt',
  );
  @override
  late final GeneratedColumn<String> decidedAt = GeneratedColumn<String>(
    'decided_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    purpose,
    noticeVersion,
    policyVersion,
    granted,
    decidedAt,
    appVersion,
    platform,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consent_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConsentRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    } else if (isInserting) {
      context.missing(_purposeMeta);
    }
    if (data.containsKey('notice_version')) {
      context.handle(
        _noticeVersionMeta,
        noticeVersion.isAcceptableOrUnknown(
          data['notice_version']!,
          _noticeVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_noticeVersionMeta);
    }
    if (data.containsKey('policy_version')) {
      context.handle(
        _policyVersionMeta,
        policyVersion.isAcceptableOrUnknown(
          data['policy_version']!,
          _policyVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_policyVersionMeta);
    }
    if (data.containsKey('granted')) {
      context.handle(
        _grantedMeta,
        granted.isAcceptableOrUnknown(data['granted']!, _grantedMeta),
      );
    } else if (isInserting) {
      context.missing(_grantedMeta);
    }
    if (data.containsKey('decided_at')) {
      context.handle(
        _decidedAtMeta,
        decidedAt.isAcceptableOrUnknown(data['decided_at']!, _decidedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_decidedAtMeta);
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConsentRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsentRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      purpose:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}purpose'],
          )!,
      noticeVersion:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}notice_version'],
          )!,
      policyVersion:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}policy_version'],
          )!,
      granted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}granted'],
          )!,
      decidedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}decided_at'],
          )!,
      appVersion:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}app_version'],
          )!,
      platform:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}platform'],
          )!,
      synced:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}synced'],
          )!,
    );
  }

  @override
  $ConsentRecordsTable createAlias(String alias) {
    return $ConsentRecordsTable(attachedDatabase, alias);
  }
}

class ConsentRecord extends DataClass implements Insertable<ConsentRecord> {
  final int id;

  /// What was consented to, e.g. `voice_cloud_processing`.
  final String purpose;

  /// Version of the notice shown, e.g. `voice-cloud-v1`. Sourced from the same
  /// constant the screen renders, so it cannot drift from what was displayed.
  final String noticeVersion;

  /// Privacy policy version current at the time of the decision.
  final String policyVersion;

  /// True for granted, false for withdrawn.
  final bool granted;

  /// ISO-8601 in UTC, e.g. `2026-07-26T09:12:33.000Z`.
  ///
  /// Text rather than a DateTime column on purpose. Drift reconstructs
  /// DateTime values in local time, so the UTC marker does not survive a
  /// round-trip — the instant is still correct, but the stored value is not
  /// self-describing. Evidence that might one day be handed to a regulator
  /// should say what it means without needing the code that wrote it.
  final String decidedAt;

  /// App version and platform, so a later question about what a specific build
  /// showed can actually be answered.
  final String appVersion;
  final String platform;

  /// Whether this row has reached the server yet. Records are written locally
  /// first: if it only lived server-side, a failed sync would lose exactly the
  /// evidence you would need.
  final bool synced;
  const ConsentRecord({
    required this.id,
    required this.purpose,
    required this.noticeVersion,
    required this.policyVersion,
    required this.granted,
    required this.decidedAt,
    required this.appVersion,
    required this.platform,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['purpose'] = Variable<String>(purpose);
    map['notice_version'] = Variable<String>(noticeVersion);
    map['policy_version'] = Variable<String>(policyVersion);
    map['granted'] = Variable<bool>(granted);
    map['decided_at'] = Variable<String>(decidedAt);
    map['app_version'] = Variable<String>(appVersion);
    map['platform'] = Variable<String>(platform);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  ConsentRecordsCompanion toCompanion(bool nullToAbsent) {
    return ConsentRecordsCompanion(
      id: Value(id),
      purpose: Value(purpose),
      noticeVersion: Value(noticeVersion),
      policyVersion: Value(policyVersion),
      granted: Value(granted),
      decidedAt: Value(decidedAt),
      appVersion: Value(appVersion),
      platform: Value(platform),
      synced: Value(synced),
    );
  }

  factory ConsentRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsentRecord(
      id: serializer.fromJson<int>(json['id']),
      purpose: serializer.fromJson<String>(json['purpose']),
      noticeVersion: serializer.fromJson<String>(json['noticeVersion']),
      policyVersion: serializer.fromJson<String>(json['policyVersion']),
      granted: serializer.fromJson<bool>(json['granted']),
      decidedAt: serializer.fromJson<String>(json['decidedAt']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
      platform: serializer.fromJson<String>(json['platform']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'purpose': serializer.toJson<String>(purpose),
      'noticeVersion': serializer.toJson<String>(noticeVersion),
      'policyVersion': serializer.toJson<String>(policyVersion),
      'granted': serializer.toJson<bool>(granted),
      'decidedAt': serializer.toJson<String>(decidedAt),
      'appVersion': serializer.toJson<String>(appVersion),
      'platform': serializer.toJson<String>(platform),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  ConsentRecord copyWith({
    int? id,
    String? purpose,
    String? noticeVersion,
    String? policyVersion,
    bool? granted,
    String? decidedAt,
    String? appVersion,
    String? platform,
    bool? synced,
  }) => ConsentRecord(
    id: id ?? this.id,
    purpose: purpose ?? this.purpose,
    noticeVersion: noticeVersion ?? this.noticeVersion,
    policyVersion: policyVersion ?? this.policyVersion,
    granted: granted ?? this.granted,
    decidedAt: decidedAt ?? this.decidedAt,
    appVersion: appVersion ?? this.appVersion,
    platform: platform ?? this.platform,
    synced: synced ?? this.synced,
  );
  ConsentRecord copyWithCompanion(ConsentRecordsCompanion data) {
    return ConsentRecord(
      id: data.id.present ? data.id.value : this.id,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      noticeVersion:
          data.noticeVersion.present
              ? data.noticeVersion.value
              : this.noticeVersion,
      policyVersion:
          data.policyVersion.present
              ? data.policyVersion.value
              : this.policyVersion,
      granted: data.granted.present ? data.granted.value : this.granted,
      decidedAt: data.decidedAt.present ? data.decidedAt.value : this.decidedAt,
      appVersion:
          data.appVersion.present ? data.appVersion.value : this.appVersion,
      platform: data.platform.present ? data.platform.value : this.platform,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsentRecord(')
          ..write('id: $id, ')
          ..write('purpose: $purpose, ')
          ..write('noticeVersion: $noticeVersion, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('granted: $granted, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('platform: $platform, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    purpose,
    noticeVersion,
    policyVersion,
    granted,
    decidedAt,
    appVersion,
    platform,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsentRecord &&
          other.id == this.id &&
          other.purpose == this.purpose &&
          other.noticeVersion == this.noticeVersion &&
          other.policyVersion == this.policyVersion &&
          other.granted == this.granted &&
          other.decidedAt == this.decidedAt &&
          other.appVersion == this.appVersion &&
          other.platform == this.platform &&
          other.synced == this.synced);
}

class ConsentRecordsCompanion extends UpdateCompanion<ConsentRecord> {
  final Value<int> id;
  final Value<String> purpose;
  final Value<String> noticeVersion;
  final Value<String> policyVersion;
  final Value<bool> granted;
  final Value<String> decidedAt;
  final Value<String> appVersion;
  final Value<String> platform;
  final Value<bool> synced;
  const ConsentRecordsCompanion({
    this.id = const Value.absent(),
    this.purpose = const Value.absent(),
    this.noticeVersion = const Value.absent(),
    this.policyVersion = const Value.absent(),
    this.granted = const Value.absent(),
    this.decidedAt = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.platform = const Value.absent(),
    this.synced = const Value.absent(),
  });
  ConsentRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String purpose,
    required String noticeVersion,
    required String policyVersion,
    required bool granted,
    required String decidedAt,
    this.appVersion = const Value.absent(),
    this.platform = const Value.absent(),
    this.synced = const Value.absent(),
  }) : purpose = Value(purpose),
       noticeVersion = Value(noticeVersion),
       policyVersion = Value(policyVersion),
       granted = Value(granted),
       decidedAt = Value(decidedAt);
  static Insertable<ConsentRecord> custom({
    Expression<int>? id,
    Expression<String>? purpose,
    Expression<String>? noticeVersion,
    Expression<String>? policyVersion,
    Expression<bool>? granted,
    Expression<String>? decidedAt,
    Expression<String>? appVersion,
    Expression<String>? platform,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (purpose != null) 'purpose': purpose,
      if (noticeVersion != null) 'notice_version': noticeVersion,
      if (policyVersion != null) 'policy_version': policyVersion,
      if (granted != null) 'granted': granted,
      if (decidedAt != null) 'decided_at': decidedAt,
      if (appVersion != null) 'app_version': appVersion,
      if (platform != null) 'platform': platform,
      if (synced != null) 'synced': synced,
    });
  }

  ConsentRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? purpose,
    Value<String>? noticeVersion,
    Value<String>? policyVersion,
    Value<bool>? granted,
    Value<String>? decidedAt,
    Value<String>? appVersion,
    Value<String>? platform,
    Value<bool>? synced,
  }) {
    return ConsentRecordsCompanion(
      id: id ?? this.id,
      purpose: purpose ?? this.purpose,
      noticeVersion: noticeVersion ?? this.noticeVersion,
      policyVersion: policyVersion ?? this.policyVersion,
      granted: granted ?? this.granted,
      decidedAt: decidedAt ?? this.decidedAt,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (noticeVersion.present) {
      map['notice_version'] = Variable<String>(noticeVersion.value);
    }
    if (policyVersion.present) {
      map['policy_version'] = Variable<String>(policyVersion.value);
    }
    if (granted.present) {
      map['granted'] = Variable<bool>(granted.value);
    }
    if (decidedAt.present) {
      map['decided_at'] = Variable<String>(decidedAt.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsentRecordsCompanion(')
          ..write('id: $id, ')
          ..write('purpose: $purpose, ')
          ..write('noticeVersion: $noticeVersion, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('granted: $granted, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('platform: $platform, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $LessonProgressTable extends LessonProgress
    with TableInfo<$LessonProgressTable, LessonProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<int> unitId = GeneratedColumn<int>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bestScoreMeta = const VerificationMeta(
    'bestScore',
  );
  @override
  late final GeneratedColumn<double> bestScore = GeneratedColumn<double>(
    'best_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptedMeta = const VerificationMeta(
    'lastAttempted',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttempted =
      GeneratedColumn<DateTime>(
        'last_attempted',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    lessonId,
    unitId,
    isCompleted,
    bestScore,
    attempts,
    lastAttempted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIdMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('best_score')) {
      context.handle(
        _bestScoreMeta,
        bestScore.isAcceptableOrUnknown(data['best_score']!, _bestScoreMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_attempted')) {
      context.handle(
        _lastAttemptedMeta,
        lastAttempted.isAcceptableOrUnknown(
          data['last_attempted']!,
          _lastAttemptedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lessonId};
  @override
  LessonProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonProgressData(
      lessonId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lesson_id'],
          )!,
      unitId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}unit_id'],
          )!,
      isCompleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_completed'],
          )!,
      bestScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}best_score'],
          )!,
      attempts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}attempts'],
          )!,
      lastAttempted: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempted'],
      ),
    );
  }

  @override
  $LessonProgressTable createAlias(String alias) {
    return $LessonProgressTable(attachedDatabase, alias);
  }
}

class LessonProgressData extends DataClass
    implements Insertable<LessonProgressData> {
  final int lessonId;
  final int unitId;
  final bool isCompleted;
  final double bestScore;
  final int attempts;
  final DateTime? lastAttempted;
  const LessonProgressData({
    required this.lessonId,
    required this.unitId,
    required this.isCompleted,
    required this.bestScore,
    required this.attempts,
    this.lastAttempted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lesson_id'] = Variable<int>(lessonId);
    map['unit_id'] = Variable<int>(unitId);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['best_score'] = Variable<double>(bestScore);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttempted != null) {
      map['last_attempted'] = Variable<DateTime>(lastAttempted);
    }
    return map;
  }

  LessonProgressCompanion toCompanion(bool nullToAbsent) {
    return LessonProgressCompanion(
      lessonId: Value(lessonId),
      unitId: Value(unitId),
      isCompleted: Value(isCompleted),
      bestScore: Value(bestScore),
      attempts: Value(attempts),
      lastAttempted:
          lastAttempted == null && nullToAbsent
              ? const Value.absent()
              : Value(lastAttempted),
    );
  }

  factory LessonProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonProgressData(
      lessonId: serializer.fromJson<int>(json['lessonId']),
      unitId: serializer.fromJson<int>(json['unitId']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      bestScore: serializer.fromJson<double>(json['bestScore']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttempted: serializer.fromJson<DateTime?>(json['lastAttempted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lessonId': serializer.toJson<int>(lessonId),
      'unitId': serializer.toJson<int>(unitId),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'bestScore': serializer.toJson<double>(bestScore),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttempted': serializer.toJson<DateTime?>(lastAttempted),
    };
  }

  LessonProgressData copyWith({
    int? lessonId,
    int? unitId,
    bool? isCompleted,
    double? bestScore,
    int? attempts,
    Value<DateTime?> lastAttempted = const Value.absent(),
  }) => LessonProgressData(
    lessonId: lessonId ?? this.lessonId,
    unitId: unitId ?? this.unitId,
    isCompleted: isCompleted ?? this.isCompleted,
    bestScore: bestScore ?? this.bestScore,
    attempts: attempts ?? this.attempts,
    lastAttempted:
        lastAttempted.present ? lastAttempted.value : this.lastAttempted,
  );
  LessonProgressData copyWithCompanion(LessonProgressCompanion data) {
    return LessonProgressData(
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      bestScore: data.bestScore.present ? data.bestScore.value : this.bestScore,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastAttempted:
          data.lastAttempted.present
              ? data.lastAttempted.value
              : this.lastAttempted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressData(')
          ..write('lessonId: $lessonId, ')
          ..write('unitId: $unitId, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('bestScore: $bestScore, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttempted: $lastAttempted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    lessonId,
    unitId,
    isCompleted,
    bestScore,
    attempts,
    lastAttempted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonProgressData &&
          other.lessonId == this.lessonId &&
          other.unitId == this.unitId &&
          other.isCompleted == this.isCompleted &&
          other.bestScore == this.bestScore &&
          other.attempts == this.attempts &&
          other.lastAttempted == this.lastAttempted);
}

class LessonProgressCompanion extends UpdateCompanion<LessonProgressData> {
  final Value<int> lessonId;
  final Value<int> unitId;
  final Value<bool> isCompleted;
  final Value<double> bestScore;
  final Value<int> attempts;
  final Value<DateTime?> lastAttempted;
  const LessonProgressCompanion({
    this.lessonId = const Value.absent(),
    this.unitId = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttempted = const Value.absent(),
  });
  LessonProgressCompanion.insert({
    this.lessonId = const Value.absent(),
    required int unitId,
    this.isCompleted = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttempted = const Value.absent(),
  }) : unitId = Value(unitId);
  static Insertable<LessonProgressData> custom({
    Expression<int>? lessonId,
    Expression<int>? unitId,
    Expression<bool>? isCompleted,
    Expression<double>? bestScore,
    Expression<int>? attempts,
    Expression<DateTime>? lastAttempted,
  }) {
    return RawValuesInsertable({
      if (lessonId != null) 'lesson_id': lessonId,
      if (unitId != null) 'unit_id': unitId,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (bestScore != null) 'best_score': bestScore,
      if (attempts != null) 'attempts': attempts,
      if (lastAttempted != null) 'last_attempted': lastAttempted,
    });
  }

  LessonProgressCompanion copyWith({
    Value<int>? lessonId,
    Value<int>? unitId,
    Value<bool>? isCompleted,
    Value<double>? bestScore,
    Value<int>? attempts,
    Value<DateTime?>? lastAttempted,
  }) {
    return LessonProgressCompanion(
      lessonId: lessonId ?? this.lessonId,
      unitId: unitId ?? this.unitId,
      isCompleted: isCompleted ?? this.isCompleted,
      bestScore: bestScore ?? this.bestScore,
      attempts: attempts ?? this.attempts,
      lastAttempted: lastAttempted ?? this.lastAttempted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<int>(unitId.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (bestScore.present) {
      map['best_score'] = Variable<double>(bestScore.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttempted.present) {
      map['last_attempted'] = Variable<DateTime>(lastAttempted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressCompanion(')
          ..write('lessonId: $lessonId, ')
          ..write('unitId: $unitId, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('bestScore: $bestScore, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttempted: $lastAttempted')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityKeyMeta = const VerificationMeta(
    'entityKey',
  );
  @override
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'entity_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('upsert'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deadLetteredAtMeta = const VerificationMeta(
    'deadLetteredAt',
  );
  @override
  late final GeneratedColumn<DateTime> deadLetteredAt =
      GeneratedColumn<DateTime>(
        'dead_lettered_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entity,
    entityKey,
    op,
    payload,
    deviceId,
    updatedAt,
    attempts,
    nextAttemptAt,
    deadLetteredAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_key')) {
      context.handle(
        _entityKeyMeta,
        entityKey.isAcceptableOrUnknown(data['entity_key']!, _entityKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKeyMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('dead_lettered_at')) {
      context.handle(
        _deadLetteredAtMeta,
        deadLetteredAt.isAcceptableOrUnknown(
          data['dead_lettered_at']!,
          _deadLetteredAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      entity:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity'],
          )!,
      entityKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity_key'],
          )!,
      op:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}op'],
          )!,
      payload:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload'],
          )!,
      deviceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}device_id'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      attempts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}attempts'],
          )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      deadLetteredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dead_lettered_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;

  /// Logical target table on the backend, e.g. `lesson_progress`, `srs_cards`,
  /// `earned_badges`, `user_progress`.
  final String entity;

  /// Globally-stable identity of the affected row *within* [entity], as a
  /// string. For content-keyed rows this is the natural key (badgeId,
  /// user_progress key, lessonId, or the srs card's content key) — never a
  /// local autoincrement id, which collides across devices.
  final String entityKey;

  /// `upsert` or `delete`.
  final String op;

  /// Full row snapshot as JSON — what to send to the backend.
  final String payload;

  /// Origin device; part of the LWW tiebreaker.
  final String deviceId;

  /// Client mutation time — the LWW clock. Server compares this against the
  /// stored row and keeps the newer one.
  final DateTime updatedAt;

  /// Set when a push attempt fails, for backoff/inspection.
  final int attempts;

  /// Earliest time this row may be retried after a transient failure.
  final DateTime? nextAttemptAt;

  /// Rows exceeding the retry budget remain inspectable but are no longer
  /// selected for automatic delivery.
  final DateTime? deadLetteredAt;

  /// Sanitized diagnostic text for support and future recovery UI.
  final String? lastError;
  const SyncQueueData({
    required this.id,
    required this.entity,
    required this.entityKey,
    required this.op,
    required this.payload,
    required this.deviceId,
    required this.updatedAt,
    required this.attempts,
    this.nextAttemptAt,
    this.deadLetteredAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity'] = Variable<String>(entity);
    map['entity_key'] = Variable<String>(entityKey);
    map['op'] = Variable<String>(op);
    map['payload'] = Variable<String>(payload);
    map['device_id'] = Variable<String>(deviceId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || deadLetteredAt != null) {
      map['dead_lettered_at'] = Variable<DateTime>(deadLetteredAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entity: Value(entity),
      entityKey: Value(entityKey),
      op: Value(op),
      payload: Value(payload),
      deviceId: Value(deviceId),
      updatedAt: Value(updatedAt),
      attempts: Value(attempts),
      nextAttemptAt:
          nextAttemptAt == null && nullToAbsent
              ? const Value.absent()
              : Value(nextAttemptAt),
      deadLetteredAt:
          deadLetteredAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deadLetteredAt),
      lastError:
          lastError == null && nullToAbsent
              ? const Value.absent()
              : Value(lastError),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      entityKey: serializer.fromJson<String>(json['entityKey']),
      op: serializer.fromJson<String>(json['op']),
      payload: serializer.fromJson<String>(json['payload']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      deadLetteredAt: serializer.fromJson<DateTime?>(json['deadLetteredAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity': serializer.toJson<String>(entity),
      'entityKey': serializer.toJson<String>(entityKey),
      'op': serializer.toJson<String>(op),
      'payload': serializer.toJson<String>(payload),
      'deviceId': serializer.toJson<String>(deviceId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'deadLetteredAt': serializer.toJson<DateTime?>(deadLetteredAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? entity,
    String? entityKey,
    String? op,
    String? payload,
    String? deviceId,
    DateTime? updatedAt,
    int? attempts,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<DateTime?> deadLetteredAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncQueueData(
    id: id ?? this.id,
    entity: entity ?? this.entity,
    entityKey: entityKey ?? this.entityKey,
    op: op ?? this.op,
    payload: payload ?? this.payload,
    deviceId: deviceId ?? this.deviceId,
    updatedAt: updatedAt ?? this.updatedAt,
    attempts: attempts ?? this.attempts,
    nextAttemptAt:
        nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
    deadLetteredAt:
        deadLetteredAt.present ? deadLetteredAt.value : this.deadLetteredAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
      op: data.op.present ? data.op.value : this.op,
      payload: data.payload.present ? data.payload.value : this.payload,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt:
          data.nextAttemptAt.present
              ? data.nextAttemptAt.value
              : this.nextAttemptAt,
      deadLetteredAt:
          data.deadLetteredAt.present
              ? data.deadLetteredAt.value
              : this.deadLetteredAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityKey: $entityKey, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('deviceId: $deviceId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('deadLetteredAt: $deadLetteredAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    entityKey,
    op,
    payload,
    deviceId,
    updatedAt,
    attempts,
    nextAttemptAt,
    deadLetteredAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.entityKey == this.entityKey &&
          other.op == this.op &&
          other.payload == this.payload &&
          other.deviceId == this.deviceId &&
          other.updatedAt == this.updatedAt &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.deadLetteredAt == this.deadLetteredAt &&
          other.lastError == this.lastError);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> entity;
  final Value<String> entityKey;
  final Value<String> op;
  final Value<String> payload;
  final Value<String> deviceId;
  final Value<DateTime> updatedAt;
  final Value<int> attempts;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime?> deadLetteredAt;
  final Value<String?> lastError;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityKey = const Value.absent(),
    this.op = const Value.absent(),
    this.payload = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.deadLetteredAt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String entity,
    required String entityKey,
    this.op = const Value.absent(),
    required String payload,
    required String deviceId,
    this.updatedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.deadLetteredAt = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : entity = Value(entity),
       entityKey = Value(entityKey),
       payload = Value(payload),
       deviceId = Value(deviceId);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? entity,
    Expression<String>? entityKey,
    Expression<String>? op,
    Expression<String>? payload,
    Expression<String>? deviceId,
    Expression<DateTime>? updatedAt,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? deadLetteredAt,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (entityKey != null) 'entity_key': entityKey,
      if (op != null) 'op': op,
      if (payload != null) 'payload': payload,
      if (deviceId != null) 'device_id': deviceId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (deadLetteredAt != null) 'dead_lettered_at': deadLetteredAt,
      if (lastError != null) 'last_error': lastError,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? entity,
    Value<String>? entityKey,
    Value<String>? op,
    Value<String>? payload,
    Value<String>? deviceId,
    Value<DateTime>? updatedAt,
    Value<int>? attempts,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime?>? deadLetteredAt,
    Value<String?>? lastError,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      entityKey: entityKey ?? this.entityKey,
      op: op ?? this.op,
      payload: payload ?? this.payload,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      deadLetteredAt: deadLetteredAt ?? this.deadLetteredAt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityKey.present) {
      map['entity_key'] = Variable<String>(entityKey.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (deadLetteredAt.present) {
      map['dead_lettered_at'] = Variable<DateTime>(deadLetteredAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityKey: $entityKey, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('deviceId: $deviceId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('deadLetteredAt: $deadLetteredAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
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
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String key;
  final String value;
  const SyncStateData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateData copyWith({String? key, String? value}) =>
      SyncStateData(key: key ?? this.key, value: value ?? this.value);
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GamificationStateTableTable extends GamificationStateTable
    with TableInfo<$GamificationStateTableTable, GamificationStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamificationStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heartsMeta = const VerificationMeta('hearts');
  @override
  late final GeneratedColumn<int> hearts = GeneratedColumn<int>(
    'hearts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _maxHeartsMeta = const VerificationMeta(
    'maxHearts',
  );
  @override
  late final GeneratedColumn<int> maxHearts = GeneratedColumn<int>(
    'max_hearts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestStreakMeta = const VerificationMeta(
    'longestStreak',
  );
  @override
  late final GeneratedColumn<int> longestStreak = GeneratedColumn<int>(
    'longest_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalXpMeta = const VerificationMeta(
    'totalXp',
  );
  @override
  late final GeneratedColumn<int> totalXp = GeneratedColumn<int>(
    'total_xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dailyXpMeta = const VerificationMeta(
    'dailyXp',
  );
  @override
  late final GeneratedColumn<int> dailyXp = GeneratedColumn<int>(
    'daily_xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dailyGoalXpMeta = const VerificationMeta(
    'dailyGoalXp',
  );
  @override
  late final GeneratedColumn<int> dailyGoalXp = GeneratedColumn<int>(
    'daily_goal_xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(50),
  );
  static const VerificationMeta _gemsMeta = const VerificationMeta('gems');
  @override
  late final GeneratedColumn<int> gems = GeneratedColumn<int>(
    'gems',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _earnedBadgesMeta = const VerificationMeta(
    'earnedBadges',
  );
  @override
  late final GeneratedColumn<String> earnedBadges = GeneratedColumn<String>(
    'earned_badges',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastHeartRefillMeta = const VerificationMeta(
    'lastHeartRefill',
  );
  @override
  late final GeneratedColumn<DateTime> lastHeartRefill =
      GeneratedColumn<DateTime>(
        'last_heart_refill',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _streakFreezeAvailableMeta =
      const VerificationMeta('streakFreezeAvailable');
  @override
  late final GeneratedColumn<bool> streakFreezeAvailable =
      GeneratedColumn<bool>(
        'streak_freeze_available',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("streak_freeze_available" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _lastOpenDateMeta = const VerificationMeta(
    'lastOpenDate',
  );
  @override
  late final GeneratedColumn<String> lastOpenDate = GeneratedColumn<String>(
    'last_open_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyXpResetDateMeta = const VerificationMeta(
    'dailyXpResetDate',
  );
  @override
  late final GeneratedColumn<String> dailyXpResetDate = GeneratedColumn<String>(
    'daily_xp_reset_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    hearts,
    maxHearts,
    currentStreak,
    longestStreak,
    totalXp,
    dailyXp,
    dailyGoalXp,
    gems,
    earnedBadges,
    lastHeartRefill,
    streakFreezeAvailable,
    lastOpenDate,
    dailyXpResetDate,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gamification_state_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GamificationStateTableData> instance, {
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
    if (data.containsKey('hearts')) {
      context.handle(
        _heartsMeta,
        hearts.isAcceptableOrUnknown(data['hearts']!, _heartsMeta),
      );
    }
    if (data.containsKey('max_hearts')) {
      context.handle(
        _maxHeartsMeta,
        maxHearts.isAcceptableOrUnknown(data['max_hearts']!, _maxHeartsMeta),
      );
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
      );
    }
    if (data.containsKey('longest_streak')) {
      context.handle(
        _longestStreakMeta,
        longestStreak.isAcceptableOrUnknown(
          data['longest_streak']!,
          _longestStreakMeta,
        ),
      );
    }
    if (data.containsKey('total_xp')) {
      context.handle(
        _totalXpMeta,
        totalXp.isAcceptableOrUnknown(data['total_xp']!, _totalXpMeta),
      );
    }
    if (data.containsKey('daily_xp')) {
      context.handle(
        _dailyXpMeta,
        dailyXp.isAcceptableOrUnknown(data['daily_xp']!, _dailyXpMeta),
      );
    }
    if (data.containsKey('daily_goal_xp')) {
      context.handle(
        _dailyGoalXpMeta,
        dailyGoalXp.isAcceptableOrUnknown(
          data['daily_goal_xp']!,
          _dailyGoalXpMeta,
        ),
      );
    }
    if (data.containsKey('gems')) {
      context.handle(
        _gemsMeta,
        gems.isAcceptableOrUnknown(data['gems']!, _gemsMeta),
      );
    }
    if (data.containsKey('earned_badges')) {
      context.handle(
        _earnedBadgesMeta,
        earnedBadges.isAcceptableOrUnknown(
          data['earned_badges']!,
          _earnedBadgesMeta,
        ),
      );
    }
    if (data.containsKey('last_heart_refill')) {
      context.handle(
        _lastHeartRefillMeta,
        lastHeartRefill.isAcceptableOrUnknown(
          data['last_heart_refill']!,
          _lastHeartRefillMeta,
        ),
      );
    }
    if (data.containsKey('streak_freeze_available')) {
      context.handle(
        _streakFreezeAvailableMeta,
        streakFreezeAvailable.isAcceptableOrUnknown(
          data['streak_freeze_available']!,
          _streakFreezeAvailableMeta,
        ),
      );
    }
    if (data.containsKey('last_open_date')) {
      context.handle(
        _lastOpenDateMeta,
        lastOpenDate.isAcceptableOrUnknown(
          data['last_open_date']!,
          _lastOpenDateMeta,
        ),
      );
    }
    if (data.containsKey('daily_xp_reset_date')) {
      context.handle(
        _dailyXpResetDateMeta,
        dailyXpResetDate.isAcceptableOrUnknown(
          data['daily_xp_reset_date']!,
          _dailyXpResetDateMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  GamificationStateTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GamificationStateTableData(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      hearts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}hearts'],
          )!,
      maxHearts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}max_hearts'],
          )!,
      currentStreak:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}current_streak'],
          )!,
      longestStreak:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}longest_streak'],
          )!,
      totalXp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total_xp'],
          )!,
      dailyXp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}daily_xp'],
          )!,
      dailyGoalXp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}daily_goal_xp'],
          )!,
      gems:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}gems'],
          )!,
      earnedBadges:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}earned_badges'],
          )!,
      lastHeartRefill: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_heart_refill'],
      ),
      streakFreezeAvailable:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}streak_freeze_available'],
          )!,
      lastOpenDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_open_date'],
      ),
      dailyXpResetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}daily_xp_reset_date'],
      ),
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $GamificationStateTableTable createAlias(String alias) {
    return $GamificationStateTableTable(attachedDatabase, alias);
  }
}

class GamificationStateTableData extends DataClass
    implements Insertable<GamificationStateTableData> {
  final String key;
  final int hearts;
  final int maxHearts;
  final int currentStreak;
  final int longestStreak;
  final int totalXp;
  final int dailyXp;
  final int dailyGoalXp;
  final int gems;
  final String earnedBadges;
  final DateTime? lastHeartRefill;
  final bool streakFreezeAvailable;
  final String? lastOpenDate;
  final String? dailyXpResetDate;
  final DateTime updatedAt;
  const GamificationStateTableData({
    required this.key,
    required this.hearts,
    required this.maxHearts,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalXp,
    required this.dailyXp,
    required this.dailyGoalXp,
    required this.gems,
    required this.earnedBadges,
    this.lastHeartRefill,
    required this.streakFreezeAvailable,
    this.lastOpenDate,
    this.dailyXpResetDate,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['hearts'] = Variable<int>(hearts);
    map['max_hearts'] = Variable<int>(maxHearts);
    map['current_streak'] = Variable<int>(currentStreak);
    map['longest_streak'] = Variable<int>(longestStreak);
    map['total_xp'] = Variable<int>(totalXp);
    map['daily_xp'] = Variable<int>(dailyXp);
    map['daily_goal_xp'] = Variable<int>(dailyGoalXp);
    map['gems'] = Variable<int>(gems);
    map['earned_badges'] = Variable<String>(earnedBadges);
    if (!nullToAbsent || lastHeartRefill != null) {
      map['last_heart_refill'] = Variable<DateTime>(lastHeartRefill);
    }
    map['streak_freeze_available'] = Variable<bool>(streakFreezeAvailable);
    if (!nullToAbsent || lastOpenDate != null) {
      map['last_open_date'] = Variable<String>(lastOpenDate);
    }
    if (!nullToAbsent || dailyXpResetDate != null) {
      map['daily_xp_reset_date'] = Variable<String>(dailyXpResetDate);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GamificationStateTableCompanion toCompanion(bool nullToAbsent) {
    return GamificationStateTableCompanion(
      key: Value(key),
      hearts: Value(hearts),
      maxHearts: Value(maxHearts),
      currentStreak: Value(currentStreak),
      longestStreak: Value(longestStreak),
      totalXp: Value(totalXp),
      dailyXp: Value(dailyXp),
      dailyGoalXp: Value(dailyGoalXp),
      gems: Value(gems),
      earnedBadges: Value(earnedBadges),
      lastHeartRefill:
          lastHeartRefill == null && nullToAbsent
              ? const Value.absent()
              : Value(lastHeartRefill),
      streakFreezeAvailable: Value(streakFreezeAvailable),
      lastOpenDate:
          lastOpenDate == null && nullToAbsent
              ? const Value.absent()
              : Value(lastOpenDate),
      dailyXpResetDate:
          dailyXpResetDate == null && nullToAbsent
              ? const Value.absent()
              : Value(dailyXpResetDate),
      updatedAt: Value(updatedAt),
    );
  }

  factory GamificationStateTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GamificationStateTableData(
      key: serializer.fromJson<String>(json['key']),
      hearts: serializer.fromJson<int>(json['hearts']),
      maxHearts: serializer.fromJson<int>(json['maxHearts']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      longestStreak: serializer.fromJson<int>(json['longestStreak']),
      totalXp: serializer.fromJson<int>(json['totalXp']),
      dailyXp: serializer.fromJson<int>(json['dailyXp']),
      dailyGoalXp: serializer.fromJson<int>(json['dailyGoalXp']),
      gems: serializer.fromJson<int>(json['gems']),
      earnedBadges: serializer.fromJson<String>(json['earnedBadges']),
      lastHeartRefill: serializer.fromJson<DateTime?>(json['lastHeartRefill']),
      streakFreezeAvailable: serializer.fromJson<bool>(
        json['streakFreezeAvailable'],
      ),
      lastOpenDate: serializer.fromJson<String?>(json['lastOpenDate']),
      dailyXpResetDate: serializer.fromJson<String?>(json['dailyXpResetDate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'hearts': serializer.toJson<int>(hearts),
      'maxHearts': serializer.toJson<int>(maxHearts),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'longestStreak': serializer.toJson<int>(longestStreak),
      'totalXp': serializer.toJson<int>(totalXp),
      'dailyXp': serializer.toJson<int>(dailyXp),
      'dailyGoalXp': serializer.toJson<int>(dailyGoalXp),
      'gems': serializer.toJson<int>(gems),
      'earnedBadges': serializer.toJson<String>(earnedBadges),
      'lastHeartRefill': serializer.toJson<DateTime?>(lastHeartRefill),
      'streakFreezeAvailable': serializer.toJson<bool>(streakFreezeAvailable),
      'lastOpenDate': serializer.toJson<String?>(lastOpenDate),
      'dailyXpResetDate': serializer.toJson<String?>(dailyXpResetDate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GamificationStateTableData copyWith({
    String? key,
    int? hearts,
    int? maxHearts,
    int? currentStreak,
    int? longestStreak,
    int? totalXp,
    int? dailyXp,
    int? dailyGoalXp,
    int? gems,
    String? earnedBadges,
    Value<DateTime?> lastHeartRefill = const Value.absent(),
    bool? streakFreezeAvailable,
    Value<String?> lastOpenDate = const Value.absent(),
    Value<String?> dailyXpResetDate = const Value.absent(),
    DateTime? updatedAt,
  }) => GamificationStateTableData(
    key: key ?? this.key,
    hearts: hearts ?? this.hearts,
    maxHearts: maxHearts ?? this.maxHearts,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    totalXp: totalXp ?? this.totalXp,
    dailyXp: dailyXp ?? this.dailyXp,
    dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
    gems: gems ?? this.gems,
    earnedBadges: earnedBadges ?? this.earnedBadges,
    lastHeartRefill:
        lastHeartRefill.present ? lastHeartRefill.value : this.lastHeartRefill,
    streakFreezeAvailable: streakFreezeAvailable ?? this.streakFreezeAvailable,
    lastOpenDate: lastOpenDate.present ? lastOpenDate.value : this.lastOpenDate,
    dailyXpResetDate:
        dailyXpResetDate.present
            ? dailyXpResetDate.value
            : this.dailyXpResetDate,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GamificationStateTableData copyWithCompanion(
    GamificationStateTableCompanion data,
  ) {
    return GamificationStateTableData(
      key: data.key.present ? data.key.value : this.key,
      hearts: data.hearts.present ? data.hearts.value : this.hearts,
      maxHearts: data.maxHearts.present ? data.maxHearts.value : this.maxHearts,
      currentStreak:
          data.currentStreak.present
              ? data.currentStreak.value
              : this.currentStreak,
      longestStreak:
          data.longestStreak.present
              ? data.longestStreak.value
              : this.longestStreak,
      totalXp: data.totalXp.present ? data.totalXp.value : this.totalXp,
      dailyXp: data.dailyXp.present ? data.dailyXp.value : this.dailyXp,
      dailyGoalXp:
          data.dailyGoalXp.present ? data.dailyGoalXp.value : this.dailyGoalXp,
      gems: data.gems.present ? data.gems.value : this.gems,
      earnedBadges:
          data.earnedBadges.present
              ? data.earnedBadges.value
              : this.earnedBadges,
      lastHeartRefill:
          data.lastHeartRefill.present
              ? data.lastHeartRefill.value
              : this.lastHeartRefill,
      streakFreezeAvailable:
          data.streakFreezeAvailable.present
              ? data.streakFreezeAvailable.value
              : this.streakFreezeAvailable,
      lastOpenDate:
          data.lastOpenDate.present
              ? data.lastOpenDate.value
              : this.lastOpenDate,
      dailyXpResetDate:
          data.dailyXpResetDate.present
              ? data.dailyXpResetDate.value
              : this.dailyXpResetDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GamificationStateTableData(')
          ..write('key: $key, ')
          ..write('hearts: $hearts, ')
          ..write('maxHearts: $maxHearts, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('totalXp: $totalXp, ')
          ..write('dailyXp: $dailyXp, ')
          ..write('dailyGoalXp: $dailyGoalXp, ')
          ..write('gems: $gems, ')
          ..write('earnedBadges: $earnedBadges, ')
          ..write('lastHeartRefill: $lastHeartRefill, ')
          ..write('streakFreezeAvailable: $streakFreezeAvailable, ')
          ..write('lastOpenDate: $lastOpenDate, ')
          ..write('dailyXpResetDate: $dailyXpResetDate, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    hearts,
    maxHearts,
    currentStreak,
    longestStreak,
    totalXp,
    dailyXp,
    dailyGoalXp,
    gems,
    earnedBadges,
    lastHeartRefill,
    streakFreezeAvailable,
    lastOpenDate,
    dailyXpResetDate,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GamificationStateTableData &&
          other.key == this.key &&
          other.hearts == this.hearts &&
          other.maxHearts == this.maxHearts &&
          other.currentStreak == this.currentStreak &&
          other.longestStreak == this.longestStreak &&
          other.totalXp == this.totalXp &&
          other.dailyXp == this.dailyXp &&
          other.dailyGoalXp == this.dailyGoalXp &&
          other.gems == this.gems &&
          other.earnedBadges == this.earnedBadges &&
          other.lastHeartRefill == this.lastHeartRefill &&
          other.streakFreezeAvailable == this.streakFreezeAvailable &&
          other.lastOpenDate == this.lastOpenDate &&
          other.dailyXpResetDate == this.dailyXpResetDate &&
          other.updatedAt == this.updatedAt);
}

class GamificationStateTableCompanion
    extends UpdateCompanion<GamificationStateTableData> {
  final Value<String> key;
  final Value<int> hearts;
  final Value<int> maxHearts;
  final Value<int> currentStreak;
  final Value<int> longestStreak;
  final Value<int> totalXp;
  final Value<int> dailyXp;
  final Value<int> dailyGoalXp;
  final Value<int> gems;
  final Value<String> earnedBadges;
  final Value<DateTime?> lastHeartRefill;
  final Value<bool> streakFreezeAvailable;
  final Value<String?> lastOpenDate;
  final Value<String?> dailyXpResetDate;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GamificationStateTableCompanion({
    this.key = const Value.absent(),
    this.hearts = const Value.absent(),
    this.maxHearts = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.totalXp = const Value.absent(),
    this.dailyXp = const Value.absent(),
    this.dailyGoalXp = const Value.absent(),
    this.gems = const Value.absent(),
    this.earnedBadges = const Value.absent(),
    this.lastHeartRefill = const Value.absent(),
    this.streakFreezeAvailable = const Value.absent(),
    this.lastOpenDate = const Value.absent(),
    this.dailyXpResetDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GamificationStateTableCompanion.insert({
    required String key,
    this.hearts = const Value.absent(),
    this.maxHearts = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.totalXp = const Value.absent(),
    this.dailyXp = const Value.absent(),
    this.dailyGoalXp = const Value.absent(),
    this.gems = const Value.absent(),
    this.earnedBadges = const Value.absent(),
    this.lastHeartRefill = const Value.absent(),
    this.streakFreezeAvailable = const Value.absent(),
    this.lastOpenDate = const Value.absent(),
    this.dailyXpResetDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<GamificationStateTableData> custom({
    Expression<String>? key,
    Expression<int>? hearts,
    Expression<int>? maxHearts,
    Expression<int>? currentStreak,
    Expression<int>? longestStreak,
    Expression<int>? totalXp,
    Expression<int>? dailyXp,
    Expression<int>? dailyGoalXp,
    Expression<int>? gems,
    Expression<String>? earnedBadges,
    Expression<DateTime>? lastHeartRefill,
    Expression<bool>? streakFreezeAvailable,
    Expression<String>? lastOpenDate,
    Expression<String>? dailyXpResetDate,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (hearts != null) 'hearts': hearts,
      if (maxHearts != null) 'max_hearts': maxHearts,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (longestStreak != null) 'longest_streak': longestStreak,
      if (totalXp != null) 'total_xp': totalXp,
      if (dailyXp != null) 'daily_xp': dailyXp,
      if (dailyGoalXp != null) 'daily_goal_xp': dailyGoalXp,
      if (gems != null) 'gems': gems,
      if (earnedBadges != null) 'earned_badges': earnedBadges,
      if (lastHeartRefill != null) 'last_heart_refill': lastHeartRefill,
      if (streakFreezeAvailable != null)
        'streak_freeze_available': streakFreezeAvailable,
      if (lastOpenDate != null) 'last_open_date': lastOpenDate,
      if (dailyXpResetDate != null) 'daily_xp_reset_date': dailyXpResetDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GamificationStateTableCompanion copyWith({
    Value<String>? key,
    Value<int>? hearts,
    Value<int>? maxHearts,
    Value<int>? currentStreak,
    Value<int>? longestStreak,
    Value<int>? totalXp,
    Value<int>? dailyXp,
    Value<int>? dailyGoalXp,
    Value<int>? gems,
    Value<String>? earnedBadges,
    Value<DateTime?>? lastHeartRefill,
    Value<bool>? streakFreezeAvailable,
    Value<String?>? lastOpenDate,
    Value<String?>? dailyXpResetDate,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GamificationStateTableCompanion(
      key: key ?? this.key,
      hearts: hearts ?? this.hearts,
      maxHearts: maxHearts ?? this.maxHearts,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalXp: totalXp ?? this.totalXp,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      gems: gems ?? this.gems,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      lastHeartRefill: lastHeartRefill ?? this.lastHeartRefill,
      streakFreezeAvailable:
          streakFreezeAvailable ?? this.streakFreezeAvailable,
      lastOpenDate: lastOpenDate ?? this.lastOpenDate,
      dailyXpResetDate: dailyXpResetDate ?? this.dailyXpResetDate,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (hearts.present) {
      map['hearts'] = Variable<int>(hearts.value);
    }
    if (maxHearts.present) {
      map['max_hearts'] = Variable<int>(maxHearts.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (longestStreak.present) {
      map['longest_streak'] = Variable<int>(longestStreak.value);
    }
    if (totalXp.present) {
      map['total_xp'] = Variable<int>(totalXp.value);
    }
    if (dailyXp.present) {
      map['daily_xp'] = Variable<int>(dailyXp.value);
    }
    if (dailyGoalXp.present) {
      map['daily_goal_xp'] = Variable<int>(dailyGoalXp.value);
    }
    if (gems.present) {
      map['gems'] = Variable<int>(gems.value);
    }
    if (earnedBadges.present) {
      map['earned_badges'] = Variable<String>(earnedBadges.value);
    }
    if (lastHeartRefill.present) {
      map['last_heart_refill'] = Variable<DateTime>(lastHeartRefill.value);
    }
    if (streakFreezeAvailable.present) {
      map['streak_freeze_available'] = Variable<bool>(
        streakFreezeAvailable.value,
      );
    }
    if (lastOpenDate.present) {
      map['last_open_date'] = Variable<String>(lastOpenDate.value);
    }
    if (dailyXpResetDate.present) {
      map['daily_xp_reset_date'] = Variable<String>(dailyXpResetDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamificationStateTableCompanion(')
          ..write('key: $key, ')
          ..write('hearts: $hearts, ')
          ..write('maxHearts: $maxHearts, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('totalXp: $totalXp, ')
          ..write('dailyXp: $dailyXp, ')
          ..write('dailyGoalXp: $dailyGoalXp, ')
          ..write('gems: $gems, ')
          ..write('earnedBadges: $earnedBadges, ')
          ..write('lastHeartRefill: $lastHeartRefill, ')
          ..write('streakFreezeAvailable: $streakFreezeAvailable, ')
          ..write('lastOpenDate: $lastOpenDate, ')
          ..write('dailyXpResetDate: $dailyXpResetDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LessonAttemptsTable extends LessonAttempts
    with TableInfo<$LessonAttemptsTable, LessonAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<int> unitId = GeneratedColumn<int>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incorrectCountMeta = const VerificationMeta(
    'incorrectCount',
  );
  @override
  late final GeneratedColumn<int> incorrectCount = GeneratedColumn<int>(
    'incorrect_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skippedCountMeta = const VerificationMeta(
    'skippedCount',
  );
  @override
  late final GeneratedColumn<int> skippedCount = GeneratedColumn<int>(
    'skipped_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _committedAtMeta = const VerificationMeta(
    'committedAt',
  );
  @override
  late final GeneratedColumn<DateTime> committedAt = GeneratedColumn<DateTime>(
    'committed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    attemptId,
    lessonId,
    unitId,
    phase,
    score,
    correctCount,
    incorrectCount,
    skippedCount,
    startedAt,
    committedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIdMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctCountMeta);
    }
    if (data.containsKey('incorrect_count')) {
      context.handle(
        _incorrectCountMeta,
        incorrectCount.isAcceptableOrUnknown(
          data['incorrect_count']!,
          _incorrectCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incorrectCountMeta);
    }
    if (data.containsKey('skipped_count')) {
      context.handle(
        _skippedCountMeta,
        skippedCount.isAcceptableOrUnknown(
          data['skipped_count']!,
          _skippedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_skippedCountMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('committed_at')) {
      context.handle(
        _committedAtMeta,
        committedAt.isAcceptableOrUnknown(
          data['committed_at']!,
          _committedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_committedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attemptId};
  @override
  LessonAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonAttempt(
      attemptId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}attempt_id'],
          )!,
      lessonId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lesson_id'],
          )!,
      unitId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}unit_id'],
          )!,
      phase:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}phase'],
          )!,
      score:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}score'],
          )!,
      correctCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}correct_count'],
          )!,
      incorrectCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}incorrect_count'],
          )!,
      skippedCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}skipped_count'],
          )!,
      startedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}started_at'],
          )!,
      committedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}committed_at'],
          )!,
    );
  }

  @override
  $LessonAttemptsTable createAlias(String alias) {
    return $LessonAttemptsTable(attachedDatabase, alias);
  }
}

class LessonAttempt extends DataClass implements Insertable<LessonAttempt> {
  final String attemptId;
  final int lessonId;
  final int unitId;
  final String phase;
  final double score;
  final int correctCount;
  final int incorrectCount;
  final int skippedCount;
  final DateTime startedAt;
  final DateTime committedAt;
  const LessonAttempt({
    required this.attemptId,
    required this.lessonId,
    required this.unitId,
    required this.phase,
    required this.score,
    required this.correctCount,
    required this.incorrectCount,
    required this.skippedCount,
    required this.startedAt,
    required this.committedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attempt_id'] = Variable<String>(attemptId);
    map['lesson_id'] = Variable<int>(lessonId);
    map['unit_id'] = Variable<int>(unitId);
    map['phase'] = Variable<String>(phase);
    map['score'] = Variable<double>(score);
    map['correct_count'] = Variable<int>(correctCount);
    map['incorrect_count'] = Variable<int>(incorrectCount);
    map['skipped_count'] = Variable<int>(skippedCount);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['committed_at'] = Variable<DateTime>(committedAt);
    return map;
  }

  LessonAttemptsCompanion toCompanion(bool nullToAbsent) {
    return LessonAttemptsCompanion(
      attemptId: Value(attemptId),
      lessonId: Value(lessonId),
      unitId: Value(unitId),
      phase: Value(phase),
      score: Value(score),
      correctCount: Value(correctCount),
      incorrectCount: Value(incorrectCount),
      skippedCount: Value(skippedCount),
      startedAt: Value(startedAt),
      committedAt: Value(committedAt),
    );
  }

  factory LessonAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonAttempt(
      attemptId: serializer.fromJson<String>(json['attemptId']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      unitId: serializer.fromJson<int>(json['unitId']),
      phase: serializer.fromJson<String>(json['phase']),
      score: serializer.fromJson<double>(json['score']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      incorrectCount: serializer.fromJson<int>(json['incorrectCount']),
      skippedCount: serializer.fromJson<int>(json['skippedCount']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      committedAt: serializer.fromJson<DateTime>(json['committedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attemptId': serializer.toJson<String>(attemptId),
      'lessonId': serializer.toJson<int>(lessonId),
      'unitId': serializer.toJson<int>(unitId),
      'phase': serializer.toJson<String>(phase),
      'score': serializer.toJson<double>(score),
      'correctCount': serializer.toJson<int>(correctCount),
      'incorrectCount': serializer.toJson<int>(incorrectCount),
      'skippedCount': serializer.toJson<int>(skippedCount),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'committedAt': serializer.toJson<DateTime>(committedAt),
    };
  }

  LessonAttempt copyWith({
    String? attemptId,
    int? lessonId,
    int? unitId,
    String? phase,
    double? score,
    int? correctCount,
    int? incorrectCount,
    int? skippedCount,
    DateTime? startedAt,
    DateTime? committedAt,
  }) => LessonAttempt(
    attemptId: attemptId ?? this.attemptId,
    lessonId: lessonId ?? this.lessonId,
    unitId: unitId ?? this.unitId,
    phase: phase ?? this.phase,
    score: score ?? this.score,
    correctCount: correctCount ?? this.correctCount,
    incorrectCount: incorrectCount ?? this.incorrectCount,
    skippedCount: skippedCount ?? this.skippedCount,
    startedAt: startedAt ?? this.startedAt,
    committedAt: committedAt ?? this.committedAt,
  );
  LessonAttempt copyWithCompanion(LessonAttemptsCompanion data) {
    return LessonAttempt(
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      phase: data.phase.present ? data.phase.value : this.phase,
      score: data.score.present ? data.score.value : this.score,
      correctCount:
          data.correctCount.present
              ? data.correctCount.value
              : this.correctCount,
      incorrectCount:
          data.incorrectCount.present
              ? data.incorrectCount.value
              : this.incorrectCount,
      skippedCount:
          data.skippedCount.present
              ? data.skippedCount.value
              : this.skippedCount,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      committedAt:
          data.committedAt.present ? data.committedAt.value : this.committedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonAttempt(')
          ..write('attemptId: $attemptId, ')
          ..write('lessonId: $lessonId, ')
          ..write('unitId: $unitId, ')
          ..write('phase: $phase, ')
          ..write('score: $score, ')
          ..write('correctCount: $correctCount, ')
          ..write('incorrectCount: $incorrectCount, ')
          ..write('skippedCount: $skippedCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('committedAt: $committedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    attemptId,
    lessonId,
    unitId,
    phase,
    score,
    correctCount,
    incorrectCount,
    skippedCount,
    startedAt,
    committedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonAttempt &&
          other.attemptId == this.attemptId &&
          other.lessonId == this.lessonId &&
          other.unitId == this.unitId &&
          other.phase == this.phase &&
          other.score == this.score &&
          other.correctCount == this.correctCount &&
          other.incorrectCount == this.incorrectCount &&
          other.skippedCount == this.skippedCount &&
          other.startedAt == this.startedAt &&
          other.committedAt == this.committedAt);
}

class LessonAttemptsCompanion extends UpdateCompanion<LessonAttempt> {
  final Value<String> attemptId;
  final Value<int> lessonId;
  final Value<int> unitId;
  final Value<String> phase;
  final Value<double> score;
  final Value<int> correctCount;
  final Value<int> incorrectCount;
  final Value<int> skippedCount;
  final Value<DateTime> startedAt;
  final Value<DateTime> committedAt;
  final Value<int> rowid;
  const LessonAttemptsCompanion({
    this.attemptId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.unitId = const Value.absent(),
    this.phase = const Value.absent(),
    this.score = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.incorrectCount = const Value.absent(),
    this.skippedCount = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.committedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonAttemptsCompanion.insert({
    required String attemptId,
    required int lessonId,
    required int unitId,
    required String phase,
    required double score,
    required int correctCount,
    required int incorrectCount,
    required int skippedCount,
    required DateTime startedAt,
    required DateTime committedAt,
    this.rowid = const Value.absent(),
  }) : attemptId = Value(attemptId),
       lessonId = Value(lessonId),
       unitId = Value(unitId),
       phase = Value(phase),
       score = Value(score),
       correctCount = Value(correctCount),
       incorrectCount = Value(incorrectCount),
       skippedCount = Value(skippedCount),
       startedAt = Value(startedAt),
       committedAt = Value(committedAt);
  static Insertable<LessonAttempt> custom({
    Expression<String>? attemptId,
    Expression<int>? lessonId,
    Expression<int>? unitId,
    Expression<String>? phase,
    Expression<double>? score,
    Expression<int>? correctCount,
    Expression<int>? incorrectCount,
    Expression<int>? skippedCount,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? committedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attemptId != null) 'attempt_id': attemptId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (unitId != null) 'unit_id': unitId,
      if (phase != null) 'phase': phase,
      if (score != null) 'score': score,
      if (correctCount != null) 'correct_count': correctCount,
      if (incorrectCount != null) 'incorrect_count': incorrectCount,
      if (skippedCount != null) 'skipped_count': skippedCount,
      if (startedAt != null) 'started_at': startedAt,
      if (committedAt != null) 'committed_at': committedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonAttemptsCompanion copyWith({
    Value<String>? attemptId,
    Value<int>? lessonId,
    Value<int>? unitId,
    Value<String>? phase,
    Value<double>? score,
    Value<int>? correctCount,
    Value<int>? incorrectCount,
    Value<int>? skippedCount,
    Value<DateTime>? startedAt,
    Value<DateTime>? committedAt,
    Value<int>? rowid,
  }) {
    return LessonAttemptsCompanion(
      attemptId: attemptId ?? this.attemptId,
      lessonId: lessonId ?? this.lessonId,
      unitId: unitId ?? this.unitId,
      phase: phase ?? this.phase,
      score: score ?? this.score,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      skippedCount: skippedCount ?? this.skippedCount,
      startedAt: startedAt ?? this.startedAt,
      committedAt: committedAt ?? this.committedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<int>(unitId.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (incorrectCount.present) {
      map['incorrect_count'] = Variable<int>(incorrectCount.value);
    }
    if (skippedCount.present) {
      map['skipped_count'] = Variable<int>(skippedCount.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (committedAt.present) {
      map['committed_at'] = Variable<DateTime>(committedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonAttemptsCompanion(')
          ..write('attemptId: $attemptId, ')
          ..write('lessonId: $lessonId, ')
          ..write('unitId: $unitId, ')
          ..write('phase: $phase, ')
          ..write('score: $score, ')
          ..write('correctCount: $correctCount, ')
          ..write('incorrectCount: $incorrectCount, ')
          ..write('skippedCount: $skippedCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('committedAt: $committedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RewardLedgerTable extends RewardLedger
    with TableInfo<$RewardLedgerTable, RewardLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardLedgerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rewardIdMeta = const VerificationMeta(
    'rewardId',
  );
  @override
  late final GeneratedColumn<String> rewardId = GeneratedColumn<String>(
    'reward_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rewardTypeMeta = const VerificationMeta(
    'rewardType',
  );
  @override
  late final GeneratedColumn<String> rewardType = GeneratedColumn<String>(
    'reward_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
    'xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _awardedAtMeta = const VerificationMeta(
    'awardedAt',
  );
  @override
  late final GeneratedColumn<DateTime> awardedAt = GeneratedColumn<DateTime>(
    'awarded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rewardId,
    sourceId,
    rewardType,
    xp,
    awardedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reward_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<RewardLedgerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reward_id')) {
      context.handle(
        _rewardIdMeta,
        rewardId.isAcceptableOrUnknown(data['reward_id']!, _rewardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rewardIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('reward_type')) {
      context.handle(
        _rewardTypeMeta,
        rewardType.isAcceptableOrUnknown(data['reward_type']!, _rewardTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_rewardTypeMeta);
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    } else if (isInserting) {
      context.missing(_xpMeta);
    }
    if (data.containsKey('awarded_at')) {
      context.handle(
        _awardedAtMeta,
        awardedAt.isAcceptableOrUnknown(data['awarded_at']!, _awardedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_awardedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rewardId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, rewardType},
  ];
  @override
  RewardLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RewardLedgerData(
      rewardId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}reward_id'],
          )!,
      sourceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_id'],
          )!,
      rewardType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}reward_type'],
          )!,
      xp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}xp'],
          )!,
      awardedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}awarded_at'],
          )!,
    );
  }

  @override
  $RewardLedgerTable createAlias(String alias) {
    return $RewardLedgerTable(attachedDatabase, alias);
  }
}

class RewardLedgerData extends DataClass
    implements Insertable<RewardLedgerData> {
  final String rewardId;
  final String sourceId;
  final String rewardType;
  final int xp;
  final DateTime awardedAt;
  const RewardLedgerData({
    required this.rewardId,
    required this.sourceId,
    required this.rewardType,
    required this.xp,
    required this.awardedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reward_id'] = Variable<String>(rewardId);
    map['source_id'] = Variable<String>(sourceId);
    map['reward_type'] = Variable<String>(rewardType);
    map['xp'] = Variable<int>(xp);
    map['awarded_at'] = Variable<DateTime>(awardedAt);
    return map;
  }

  RewardLedgerCompanion toCompanion(bool nullToAbsent) {
    return RewardLedgerCompanion(
      rewardId: Value(rewardId),
      sourceId: Value(sourceId),
      rewardType: Value(rewardType),
      xp: Value(xp),
      awardedAt: Value(awardedAt),
    );
  }

  factory RewardLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RewardLedgerData(
      rewardId: serializer.fromJson<String>(json['rewardId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      rewardType: serializer.fromJson<String>(json['rewardType']),
      xp: serializer.fromJson<int>(json['xp']),
      awardedAt: serializer.fromJson<DateTime>(json['awardedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rewardId': serializer.toJson<String>(rewardId),
      'sourceId': serializer.toJson<String>(sourceId),
      'rewardType': serializer.toJson<String>(rewardType),
      'xp': serializer.toJson<int>(xp),
      'awardedAt': serializer.toJson<DateTime>(awardedAt),
    };
  }

  RewardLedgerData copyWith({
    String? rewardId,
    String? sourceId,
    String? rewardType,
    int? xp,
    DateTime? awardedAt,
  }) => RewardLedgerData(
    rewardId: rewardId ?? this.rewardId,
    sourceId: sourceId ?? this.sourceId,
    rewardType: rewardType ?? this.rewardType,
    xp: xp ?? this.xp,
    awardedAt: awardedAt ?? this.awardedAt,
  );
  RewardLedgerData copyWithCompanion(RewardLedgerCompanion data) {
    return RewardLedgerData(
      rewardId: data.rewardId.present ? data.rewardId.value : this.rewardId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      rewardType:
          data.rewardType.present ? data.rewardType.value : this.rewardType,
      xp: data.xp.present ? data.xp.value : this.xp,
      awardedAt: data.awardedAt.present ? data.awardedAt.value : this.awardedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RewardLedgerData(')
          ..write('rewardId: $rewardId, ')
          ..write('sourceId: $sourceId, ')
          ..write('rewardType: $rewardType, ')
          ..write('xp: $xp, ')
          ..write('awardedAt: $awardedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(rewardId, sourceId, rewardType, xp, awardedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RewardLedgerData &&
          other.rewardId == this.rewardId &&
          other.sourceId == this.sourceId &&
          other.rewardType == this.rewardType &&
          other.xp == this.xp &&
          other.awardedAt == this.awardedAt);
}

class RewardLedgerCompanion extends UpdateCompanion<RewardLedgerData> {
  final Value<String> rewardId;
  final Value<String> sourceId;
  final Value<String> rewardType;
  final Value<int> xp;
  final Value<DateTime> awardedAt;
  final Value<int> rowid;
  const RewardLedgerCompanion({
    this.rewardId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.rewardType = const Value.absent(),
    this.xp = const Value.absent(),
    this.awardedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RewardLedgerCompanion.insert({
    required String rewardId,
    required String sourceId,
    required String rewardType,
    required int xp,
    required DateTime awardedAt,
    this.rowid = const Value.absent(),
  }) : rewardId = Value(rewardId),
       sourceId = Value(sourceId),
       rewardType = Value(rewardType),
       xp = Value(xp),
       awardedAt = Value(awardedAt);
  static Insertable<RewardLedgerData> custom({
    Expression<String>? rewardId,
    Expression<String>? sourceId,
    Expression<String>? rewardType,
    Expression<int>? xp,
    Expression<DateTime>? awardedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rewardId != null) 'reward_id': rewardId,
      if (sourceId != null) 'source_id': sourceId,
      if (rewardType != null) 'reward_type': rewardType,
      if (xp != null) 'xp': xp,
      if (awardedAt != null) 'awarded_at': awardedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RewardLedgerCompanion copyWith({
    Value<String>? rewardId,
    Value<String>? sourceId,
    Value<String>? rewardType,
    Value<int>? xp,
    Value<DateTime>? awardedAt,
    Value<int>? rowid,
  }) {
    return RewardLedgerCompanion(
      rewardId: rewardId ?? this.rewardId,
      sourceId: sourceId ?? this.sourceId,
      rewardType: rewardType ?? this.rewardType,
      xp: xp ?? this.xp,
      awardedAt: awardedAt ?? this.awardedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rewardId.present) {
      map['reward_id'] = Variable<String>(rewardId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (rewardType.present) {
      map['reward_type'] = Variable<String>(rewardType.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (awardedAt.present) {
      map['awarded_at'] = Variable<DateTime>(awardedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardLedgerCompanion(')
          ..write('rewardId: $rewardId, ')
          ..write('sourceId: $sourceId, ')
          ..write('rewardType: $rewardType, ')
          ..write('xp: $xp, ')
          ..write('awardedAt: $awardedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseAttemptsTable extends ExerciseAttempts
    with TableInfo<$ExerciseAttemptsTable, ExerciseAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _presentationIdMeta = const VerificationMeta(
    'presentationId',
  );
  @override
  late final GeneratedColumn<String> presentationId = GeneratedColumn<String>(
    'presentation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonAttemptIdMeta = const VerificationMeta(
    'lessonAttemptId',
  );
  @override
  late final GeneratedColumn<String> lessonAttemptId = GeneratedColumn<String>(
    'lesson_attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<DateTime> answeredAt = GeneratedColumn<DateTime>(
    'answered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    presentationId,
    lessonAttemptId,
    exerciseId,
    phase,
    outcome,
    answeredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('presentation_id')) {
      context.handle(
        _presentationIdMeta,
        presentationId.isAcceptableOrUnknown(
          data['presentation_id']!,
          _presentationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_presentationIdMeta);
    }
    if (data.containsKey('lesson_attempt_id')) {
      context.handle(
        _lessonAttemptIdMeta,
        lessonAttemptId.isAcceptableOrUnknown(
          data['lesson_attempt_id']!,
          _lessonAttemptIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lessonAttemptIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_answeredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {presentationId};
  @override
  ExerciseAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseAttempt(
      presentationId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}presentation_id'],
          )!,
      lessonAttemptId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}lesson_attempt_id'],
          )!,
      exerciseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}exercise_id'],
          )!,
      phase:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}phase'],
          )!,
      outcome:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}outcome'],
          )!,
      answeredAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}answered_at'],
          )!,
    );
  }

  @override
  $ExerciseAttemptsTable createAlias(String alias) {
    return $ExerciseAttemptsTable(attachedDatabase, alias);
  }
}

class ExerciseAttempt extends DataClass implements Insertable<ExerciseAttempt> {
  final String presentationId;
  final String lessonAttemptId;
  final int exerciseId;
  final String phase;
  final String outcome;
  final DateTime answeredAt;
  const ExerciseAttempt({
    required this.presentationId,
    required this.lessonAttemptId,
    required this.exerciseId,
    required this.phase,
    required this.outcome,
    required this.answeredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['presentation_id'] = Variable<String>(presentationId);
    map['lesson_attempt_id'] = Variable<String>(lessonAttemptId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['phase'] = Variable<String>(phase);
    map['outcome'] = Variable<String>(outcome);
    map['answered_at'] = Variable<DateTime>(answeredAt);
    return map;
  }

  ExerciseAttemptsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseAttemptsCompanion(
      presentationId: Value(presentationId),
      lessonAttemptId: Value(lessonAttemptId),
      exerciseId: Value(exerciseId),
      phase: Value(phase),
      outcome: Value(outcome),
      answeredAt: Value(answeredAt),
    );
  }

  factory ExerciseAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseAttempt(
      presentationId: serializer.fromJson<String>(json['presentationId']),
      lessonAttemptId: serializer.fromJson<String>(json['lessonAttemptId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      phase: serializer.fromJson<String>(json['phase']),
      outcome: serializer.fromJson<String>(json['outcome']),
      answeredAt: serializer.fromJson<DateTime>(json['answeredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'presentationId': serializer.toJson<String>(presentationId),
      'lessonAttemptId': serializer.toJson<String>(lessonAttemptId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'phase': serializer.toJson<String>(phase),
      'outcome': serializer.toJson<String>(outcome),
      'answeredAt': serializer.toJson<DateTime>(answeredAt),
    };
  }

  ExerciseAttempt copyWith({
    String? presentationId,
    String? lessonAttemptId,
    int? exerciseId,
    String? phase,
    String? outcome,
    DateTime? answeredAt,
  }) => ExerciseAttempt(
    presentationId: presentationId ?? this.presentationId,
    lessonAttemptId: lessonAttemptId ?? this.lessonAttemptId,
    exerciseId: exerciseId ?? this.exerciseId,
    phase: phase ?? this.phase,
    outcome: outcome ?? this.outcome,
    answeredAt: answeredAt ?? this.answeredAt,
  );
  ExerciseAttempt copyWithCompanion(ExerciseAttemptsCompanion data) {
    return ExerciseAttempt(
      presentationId:
          data.presentationId.present
              ? data.presentationId.value
              : this.presentationId,
      lessonAttemptId:
          data.lessonAttemptId.present
              ? data.lessonAttemptId.value
              : this.lessonAttemptId,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      phase: data.phase.present ? data.phase.value : this.phase,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      answeredAt:
          data.answeredAt.present ? data.answeredAt.value : this.answeredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseAttempt(')
          ..write('presentationId: $presentationId, ')
          ..write('lessonAttemptId: $lessonAttemptId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('phase: $phase, ')
          ..write('outcome: $outcome, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    presentationId,
    lessonAttemptId,
    exerciseId,
    phase,
    outcome,
    answeredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseAttempt &&
          other.presentationId == this.presentationId &&
          other.lessonAttemptId == this.lessonAttemptId &&
          other.exerciseId == this.exerciseId &&
          other.phase == this.phase &&
          other.outcome == this.outcome &&
          other.answeredAt == this.answeredAt);
}

class ExerciseAttemptsCompanion extends UpdateCompanion<ExerciseAttempt> {
  final Value<String> presentationId;
  final Value<String> lessonAttemptId;
  final Value<int> exerciseId;
  final Value<String> phase;
  final Value<String> outcome;
  final Value<DateTime> answeredAt;
  final Value<int> rowid;
  const ExerciseAttemptsCompanion({
    this.presentationId = const Value.absent(),
    this.lessonAttemptId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.phase = const Value.absent(),
    this.outcome = const Value.absent(),
    this.answeredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseAttemptsCompanion.insert({
    required String presentationId,
    required String lessonAttemptId,
    required int exerciseId,
    required String phase,
    required String outcome,
    required DateTime answeredAt,
    this.rowid = const Value.absent(),
  }) : presentationId = Value(presentationId),
       lessonAttemptId = Value(lessonAttemptId),
       exerciseId = Value(exerciseId),
       phase = Value(phase),
       outcome = Value(outcome),
       answeredAt = Value(answeredAt);
  static Insertable<ExerciseAttempt> custom({
    Expression<String>? presentationId,
    Expression<String>? lessonAttemptId,
    Expression<int>? exerciseId,
    Expression<String>? phase,
    Expression<String>? outcome,
    Expression<DateTime>? answeredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (presentationId != null) 'presentation_id': presentationId,
      if (lessonAttemptId != null) 'lesson_attempt_id': lessonAttemptId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (phase != null) 'phase': phase,
      if (outcome != null) 'outcome': outcome,
      if (answeredAt != null) 'answered_at': answeredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseAttemptsCompanion copyWith({
    Value<String>? presentationId,
    Value<String>? lessonAttemptId,
    Value<int>? exerciseId,
    Value<String>? phase,
    Value<String>? outcome,
    Value<DateTime>? answeredAt,
    Value<int>? rowid,
  }) {
    return ExerciseAttemptsCompanion(
      presentationId: presentationId ?? this.presentationId,
      lessonAttemptId: lessonAttemptId ?? this.lessonAttemptId,
      exerciseId: exerciseId ?? this.exerciseId,
      phase: phase ?? this.phase,
      outcome: outcome ?? this.outcome,
      answeredAt: answeredAt ?? this.answeredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (presentationId.present) {
      map['presentation_id'] = Variable<String>(presentationId.value);
    }
    if (lessonAttemptId.present) {
      map['lesson_attempt_id'] = Variable<String>(lessonAttemptId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<DateTime>(answeredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseAttemptsCompanion(')
          ..write('presentationId: $presentationId, ')
          ..write('lessonAttemptId: $lessonAttemptId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('phase: $phase, ')
          ..write('outcome: $outcome, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewAttemptsTable extends ReviewAttempts
    with TableInfo<$ReviewAttemptsTable, ReviewAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reviewIdMeta = const VerificationMeta(
    'reviewId',
  );
  @override
  late final GeneratedColumn<String> reviewId = GeneratedColumn<String>(
    'review_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _srsCardIdMeta = const VerificationMeta(
    'srsCardId',
  );
  @override
  late final GeneratedColumn<int> srsCardId = GeneratedColumn<int>(
    'srs_card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _introducedNewCardMeta = const VerificationMeta(
    'introducedNewCard',
  );
  @override
  late final GeneratedColumn<bool> introducedNewCard = GeneratedColumn<bool>(
    'introduced_new_card',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("introduced_new_card" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    reviewId,
    srsCardId,
    rating,
    reviewedAt,
    introducedNewCard,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('review_id')) {
      context.handle(
        _reviewIdMeta,
        reviewId.isAcceptableOrUnknown(data['review_id']!, _reviewIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewIdMeta);
    }
    if (data.containsKey('srs_card_id')) {
      context.handle(
        _srsCardIdMeta,
        srsCardId.isAcceptableOrUnknown(data['srs_card_id']!, _srsCardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_srsCardIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('introduced_new_card')) {
      context.handle(
        _introducedNewCardMeta,
        introducedNewCard.isAcceptableOrUnknown(
          data['introduced_new_card']!,
          _introducedNewCardMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reviewId};
  @override
  ReviewAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewAttempt(
      reviewId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}review_id'],
          )!,
      srsCardId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}srs_card_id'],
          )!,
      rating:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}rating'],
          )!,
      reviewedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}reviewed_at'],
          )!,
      introducedNewCard:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}introduced_new_card'],
          )!,
    );
  }

  @override
  $ReviewAttemptsTable createAlias(String alias) {
    return $ReviewAttemptsTable(attachedDatabase, alias);
  }
}

class ReviewAttempt extends DataClass implements Insertable<ReviewAttempt> {
  final String reviewId;
  final int srsCardId;
  final String rating;
  final DateTime reviewedAt;
  final bool introducedNewCard;
  const ReviewAttempt({
    required this.reviewId,
    required this.srsCardId,
    required this.rating,
    required this.reviewedAt,
    required this.introducedNewCard,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['review_id'] = Variable<String>(reviewId);
    map['srs_card_id'] = Variable<int>(srsCardId);
    map['rating'] = Variable<String>(rating);
    map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    map['introduced_new_card'] = Variable<bool>(introducedNewCard);
    return map;
  }

  ReviewAttemptsCompanion toCompanion(bool nullToAbsent) {
    return ReviewAttemptsCompanion(
      reviewId: Value(reviewId),
      srsCardId: Value(srsCardId),
      rating: Value(rating),
      reviewedAt: Value(reviewedAt),
      introducedNewCard: Value(introducedNewCard),
    );
  }

  factory ReviewAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewAttempt(
      reviewId: serializer.fromJson<String>(json['reviewId']),
      srsCardId: serializer.fromJson<int>(json['srsCardId']),
      rating: serializer.fromJson<String>(json['rating']),
      reviewedAt: serializer.fromJson<DateTime>(json['reviewedAt']),
      introducedNewCard: serializer.fromJson<bool>(json['introducedNewCard']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reviewId': serializer.toJson<String>(reviewId),
      'srsCardId': serializer.toJson<int>(srsCardId),
      'rating': serializer.toJson<String>(rating),
      'reviewedAt': serializer.toJson<DateTime>(reviewedAt),
      'introducedNewCard': serializer.toJson<bool>(introducedNewCard),
    };
  }

  ReviewAttempt copyWith({
    String? reviewId,
    int? srsCardId,
    String? rating,
    DateTime? reviewedAt,
    bool? introducedNewCard,
  }) => ReviewAttempt(
    reviewId: reviewId ?? this.reviewId,
    srsCardId: srsCardId ?? this.srsCardId,
    rating: rating ?? this.rating,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    introducedNewCard: introducedNewCard ?? this.introducedNewCard,
  );
  ReviewAttempt copyWithCompanion(ReviewAttemptsCompanion data) {
    return ReviewAttempt(
      reviewId: data.reviewId.present ? data.reviewId.value : this.reviewId,
      srsCardId: data.srsCardId.present ? data.srsCardId.value : this.srsCardId,
      rating: data.rating.present ? data.rating.value : this.rating,
      reviewedAt:
          data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
      introducedNewCard:
          data.introducedNewCard.present
              ? data.introducedNewCard.value
              : this.introducedNewCard,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewAttempt(')
          ..write('reviewId: $reviewId, ')
          ..write('srsCardId: $srsCardId, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('introducedNewCard: $introducedNewCard')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(reviewId, srsCardId, rating, reviewedAt, introducedNewCard);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewAttempt &&
          other.reviewId == this.reviewId &&
          other.srsCardId == this.srsCardId &&
          other.rating == this.rating &&
          other.reviewedAt == this.reviewedAt &&
          other.introducedNewCard == this.introducedNewCard);
}

class ReviewAttemptsCompanion extends UpdateCompanion<ReviewAttempt> {
  final Value<String> reviewId;
  final Value<int> srsCardId;
  final Value<String> rating;
  final Value<DateTime> reviewedAt;
  final Value<bool> introducedNewCard;
  final Value<int> rowid;
  const ReviewAttemptsCompanion({
    this.reviewId = const Value.absent(),
    this.srsCardId = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.introducedNewCard = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewAttemptsCompanion.insert({
    required String reviewId,
    required int srsCardId,
    required String rating,
    required DateTime reviewedAt,
    this.introducedNewCard = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : reviewId = Value(reviewId),
       srsCardId = Value(srsCardId),
       rating = Value(rating),
       reviewedAt = Value(reviewedAt);
  static Insertable<ReviewAttempt> custom({
    Expression<String>? reviewId,
    Expression<int>? srsCardId,
    Expression<String>? rating,
    Expression<DateTime>? reviewedAt,
    Expression<bool>? introducedNewCard,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reviewId != null) 'review_id': reviewId,
      if (srsCardId != null) 'srs_card_id': srsCardId,
      if (rating != null) 'rating': rating,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (introducedNewCard != null) 'introduced_new_card': introducedNewCard,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewAttemptsCompanion copyWith({
    Value<String>? reviewId,
    Value<int>? srsCardId,
    Value<String>? rating,
    Value<DateTime>? reviewedAt,
    Value<bool>? introducedNewCard,
    Value<int>? rowid,
  }) {
    return ReviewAttemptsCompanion(
      reviewId: reviewId ?? this.reviewId,
      srsCardId: srsCardId ?? this.srsCardId,
      rating: rating ?? this.rating,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      introducedNewCard: introducedNewCard ?? this.introducedNewCard,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reviewId.present) {
      map['review_id'] = Variable<String>(reviewId.value);
    }
    if (srsCardId.present) {
      map['srs_card_id'] = Variable<int>(srsCardId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (introducedNewCard.present) {
      map['introduced_new_card'] = Variable<bool>(introducedNewCard.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewAttemptsCompanion(')
          ..write('reviewId: $reviewId, ')
          ..write('srsCardId: $srsCardId, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('introducedNewCard: $introducedNewCard, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentReleaseInstallationsTable extends ContentReleaseInstallations
    with
        TableInfo<
          $ContentReleaseInstallationsTable,
          ContentReleaseInstallation
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentReleaseInstallationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _releaseIdMeta = const VerificationMeta(
    'releaseId',
  );
  @override
  late final GeneratedColumn<String> releaseId = GeneratedColumn<String>(
    'release_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentChecksumMeta = const VerificationMeta(
    'contentChecksum',
  );
  @override
  late final GeneratedColumn<String> contentChecksum = GeneratedColumn<String>(
    'content_checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPreviousMeta = const VerificationMeta(
    'isPrevious',
  );
  @override
  late final GeneratedColumn<bool> isPrevious = GeneratedColumn<bool>(
    'is_previous',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_previous" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    releaseId,
    version,
    contentChecksum,
    notes,
    isActive,
    isPrevious,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_release_installations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentReleaseInstallation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('release_id')) {
      context.handle(
        _releaseIdMeta,
        releaseId.isAcceptableOrUnknown(data['release_id']!, _releaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_releaseIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('content_checksum')) {
      context.handle(
        _contentChecksumMeta,
        contentChecksum.isAcceptableOrUnknown(
          data['content_checksum']!,
          _contentChecksumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentChecksumMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('is_previous')) {
      context.handle(
        _isPreviousMeta,
        isPrevious.isAcceptableOrUnknown(data['is_previous']!, _isPreviousMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {releaseId};
  @override
  ContentReleaseInstallation map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentReleaseInstallation(
      releaseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}release_id'],
          )!,
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      contentChecksum:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content_checksum'],
          )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
      isPrevious:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_previous'],
          )!,
      installedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}installed_at'],
          )!,
    );
  }

  @override
  $ContentReleaseInstallationsTable createAlias(String alias) {
    return $ContentReleaseInstallationsTable(attachedDatabase, alias);
  }
}

class ContentReleaseInstallation extends DataClass
    implements Insertable<ContentReleaseInstallation> {
  final String releaseId;
  final int version;
  final String contentChecksum;
  final String? notes;
  final bool isActive;
  final bool isPrevious;
  final DateTime installedAt;
  const ContentReleaseInstallation({
    required this.releaseId,
    required this.version,
    required this.contentChecksum,
    this.notes,
    required this.isActive,
    required this.isPrevious,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['release_id'] = Variable<String>(releaseId);
    map['version'] = Variable<int>(version);
    map['content_checksum'] = Variable<String>(contentChecksum);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['is_previous'] = Variable<bool>(isPrevious);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  ContentReleaseInstallationsCompanion toCompanion(bool nullToAbsent) {
    return ContentReleaseInstallationsCompanion(
      releaseId: Value(releaseId),
      version: Value(version),
      contentChecksum: Value(contentChecksum),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      isActive: Value(isActive),
      isPrevious: Value(isPrevious),
      installedAt: Value(installedAt),
    );
  }

  factory ContentReleaseInstallation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentReleaseInstallation(
      releaseId: serializer.fromJson<String>(json['releaseId']),
      version: serializer.fromJson<int>(json['version']),
      contentChecksum: serializer.fromJson<String>(json['contentChecksum']),
      notes: serializer.fromJson<String?>(json['notes']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      isPrevious: serializer.fromJson<bool>(json['isPrevious']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'releaseId': serializer.toJson<String>(releaseId),
      'version': serializer.toJson<int>(version),
      'contentChecksum': serializer.toJson<String>(contentChecksum),
      'notes': serializer.toJson<String?>(notes),
      'isActive': serializer.toJson<bool>(isActive),
      'isPrevious': serializer.toJson<bool>(isPrevious),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  ContentReleaseInstallation copyWith({
    String? releaseId,
    int? version,
    String? contentChecksum,
    Value<String?> notes = const Value.absent(),
    bool? isActive,
    bool? isPrevious,
    DateTime? installedAt,
  }) => ContentReleaseInstallation(
    releaseId: releaseId ?? this.releaseId,
    version: version ?? this.version,
    contentChecksum: contentChecksum ?? this.contentChecksum,
    notes: notes.present ? notes.value : this.notes,
    isActive: isActive ?? this.isActive,
    isPrevious: isPrevious ?? this.isPrevious,
    installedAt: installedAt ?? this.installedAt,
  );
  ContentReleaseInstallation copyWithCompanion(
    ContentReleaseInstallationsCompanion data,
  ) {
    return ContentReleaseInstallation(
      releaseId: data.releaseId.present ? data.releaseId.value : this.releaseId,
      version: data.version.present ? data.version.value : this.version,
      contentChecksum:
          data.contentChecksum.present
              ? data.contentChecksum.value
              : this.contentChecksum,
      notes: data.notes.present ? data.notes.value : this.notes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      isPrevious:
          data.isPrevious.present ? data.isPrevious.value : this.isPrevious,
      installedAt:
          data.installedAt.present ? data.installedAt.value : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentReleaseInstallation(')
          ..write('releaseId: $releaseId, ')
          ..write('version: $version, ')
          ..write('contentChecksum: $contentChecksum, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('isPrevious: $isPrevious, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    releaseId,
    version,
    contentChecksum,
    notes,
    isActive,
    isPrevious,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentReleaseInstallation &&
          other.releaseId == this.releaseId &&
          other.version == this.version &&
          other.contentChecksum == this.contentChecksum &&
          other.notes == this.notes &&
          other.isActive == this.isActive &&
          other.isPrevious == this.isPrevious &&
          other.installedAt == this.installedAt);
}

class ContentReleaseInstallationsCompanion
    extends UpdateCompanion<ContentReleaseInstallation> {
  final Value<String> releaseId;
  final Value<int> version;
  final Value<String> contentChecksum;
  final Value<String?> notes;
  final Value<bool> isActive;
  final Value<bool> isPrevious;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const ContentReleaseInstallationsCompanion({
    this.releaseId = const Value.absent(),
    this.version = const Value.absent(),
    this.contentChecksum = const Value.absent(),
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isPrevious = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentReleaseInstallationsCompanion.insert({
    required String releaseId,
    required int version,
    required String contentChecksum,
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isPrevious = const Value.absent(),
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : releaseId = Value(releaseId),
       version = Value(version),
       contentChecksum = Value(contentChecksum),
       installedAt = Value(installedAt);
  static Insertable<ContentReleaseInstallation> custom({
    Expression<String>? releaseId,
    Expression<int>? version,
    Expression<String>? contentChecksum,
    Expression<String>? notes,
    Expression<bool>? isActive,
    Expression<bool>? isPrevious,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (releaseId != null) 'release_id': releaseId,
      if (version != null) 'version': version,
      if (contentChecksum != null) 'content_checksum': contentChecksum,
      if (notes != null) 'notes': notes,
      if (isActive != null) 'is_active': isActive,
      if (isPrevious != null) 'is_previous': isPrevious,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentReleaseInstallationsCompanion copyWith({
    Value<String>? releaseId,
    Value<int>? version,
    Value<String>? contentChecksum,
    Value<String?>? notes,
    Value<bool>? isActive,
    Value<bool>? isPrevious,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return ContentReleaseInstallationsCompanion(
      releaseId: releaseId ?? this.releaseId,
      version: version ?? this.version,
      contentChecksum: contentChecksum ?? this.contentChecksum,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      isPrevious: isPrevious ?? this.isPrevious,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (releaseId.present) {
      map['release_id'] = Variable<String>(releaseId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (contentChecksum.present) {
      map['content_checksum'] = Variable<String>(contentChecksum.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (isPrevious.present) {
      map['is_previous'] = Variable<bool>(isPrevious.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentReleaseInstallationsCompanion(')
          ..write('releaseId: $releaseId, ')
          ..write('version: $version, ')
          ..write('contentChecksum: $contentChecksum, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('isPrevious: $isPrevious, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentReleasePacksTable extends ContentReleasePacks
    with TableInfo<$ContentReleasePacksTable, ContentReleasePack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentReleasePacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _releaseIdMeta = const VerificationMeta(
    'releaseId',
  );
  @override
  late final GeneratedColumn<String> releaseId = GeneratedColumn<String>(
    'release_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES content_release_installations (release_id)',
    ),
  );
  static const VerificationMeta _packKeyMeta = const VerificationMeta(
    'packKey',
  );
  @override
  late final GeneratedColumn<String> packKey = GeneratedColumn<String>(
    'pack_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packVersionMeta = const VerificationMeta(
    'packVersion',
  );
  @override
  late final GeneratedColumn<int> packVersion = GeneratedColumn<int>(
    'pack_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    releaseId,
    packKey,
    packVersion,
    checksum,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_release_packs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentReleasePack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('release_id')) {
      context.handle(
        _releaseIdMeta,
        releaseId.isAcceptableOrUnknown(data['release_id']!, _releaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_releaseIdMeta);
    }
    if (data.containsKey('pack_key')) {
      context.handle(
        _packKeyMeta,
        packKey.isAcceptableOrUnknown(data['pack_key']!, _packKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_packKeyMeta);
    }
    if (data.containsKey('pack_version')) {
      context.handle(
        _packVersionMeta,
        packVersion.isAcceptableOrUnknown(
          data['pack_version']!,
          _packVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packVersionMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {releaseId, packKey};
  @override
  ContentReleasePack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentReleasePack(
      releaseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}release_id'],
          )!,
      packKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}pack_key'],
          )!,
      packVersion:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}pack_version'],
          )!,
      checksum:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}checksum'],
          )!,
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
    );
  }

  @override
  $ContentReleasePacksTable createAlias(String alias) {
    return $ContentReleasePacksTable(attachedDatabase, alias);
  }
}

class ContentReleasePack extends DataClass
    implements Insertable<ContentReleasePack> {
  final String releaseId;
  final String packKey;
  final int packVersion;
  final String checksum;
  final String content;
  const ContentReleasePack({
    required this.releaseId,
    required this.packKey,
    required this.packVersion,
    required this.checksum,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['release_id'] = Variable<String>(releaseId);
    map['pack_key'] = Variable<String>(packKey);
    map['pack_version'] = Variable<int>(packVersion);
    map['checksum'] = Variable<String>(checksum);
    map['content'] = Variable<String>(content);
    return map;
  }

  ContentReleasePacksCompanion toCompanion(bool nullToAbsent) {
    return ContentReleasePacksCompanion(
      releaseId: Value(releaseId),
      packKey: Value(packKey),
      packVersion: Value(packVersion),
      checksum: Value(checksum),
      content: Value(content),
    );
  }

  factory ContentReleasePack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentReleasePack(
      releaseId: serializer.fromJson<String>(json['releaseId']),
      packKey: serializer.fromJson<String>(json['packKey']),
      packVersion: serializer.fromJson<int>(json['packVersion']),
      checksum: serializer.fromJson<String>(json['checksum']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'releaseId': serializer.toJson<String>(releaseId),
      'packKey': serializer.toJson<String>(packKey),
      'packVersion': serializer.toJson<int>(packVersion),
      'checksum': serializer.toJson<String>(checksum),
      'content': serializer.toJson<String>(content),
    };
  }

  ContentReleasePack copyWith({
    String? releaseId,
    String? packKey,
    int? packVersion,
    String? checksum,
    String? content,
  }) => ContentReleasePack(
    releaseId: releaseId ?? this.releaseId,
    packKey: packKey ?? this.packKey,
    packVersion: packVersion ?? this.packVersion,
    checksum: checksum ?? this.checksum,
    content: content ?? this.content,
  );
  ContentReleasePack copyWithCompanion(ContentReleasePacksCompanion data) {
    return ContentReleasePack(
      releaseId: data.releaseId.present ? data.releaseId.value : this.releaseId,
      packKey: data.packKey.present ? data.packKey.value : this.packKey,
      packVersion:
          data.packVersion.present ? data.packVersion.value : this.packVersion,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentReleasePack(')
          ..write('releaseId: $releaseId, ')
          ..write('packKey: $packKey, ')
          ..write('packVersion: $packVersion, ')
          ..write('checksum: $checksum, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(releaseId, packKey, packVersion, checksum, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentReleasePack &&
          other.releaseId == this.releaseId &&
          other.packKey == this.packKey &&
          other.packVersion == this.packVersion &&
          other.checksum == this.checksum &&
          other.content == this.content);
}

class ContentReleasePacksCompanion extends UpdateCompanion<ContentReleasePack> {
  final Value<String> releaseId;
  final Value<String> packKey;
  final Value<int> packVersion;
  final Value<String> checksum;
  final Value<String> content;
  final Value<int> rowid;
  const ContentReleasePacksCompanion({
    this.releaseId = const Value.absent(),
    this.packKey = const Value.absent(),
    this.packVersion = const Value.absent(),
    this.checksum = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentReleasePacksCompanion.insert({
    required String releaseId,
    required String packKey,
    required int packVersion,
    required String checksum,
    required String content,
    this.rowid = const Value.absent(),
  }) : releaseId = Value(releaseId),
       packKey = Value(packKey),
       packVersion = Value(packVersion),
       checksum = Value(checksum),
       content = Value(content);
  static Insertable<ContentReleasePack> custom({
    Expression<String>? releaseId,
    Expression<String>? packKey,
    Expression<int>? packVersion,
    Expression<String>? checksum,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (releaseId != null) 'release_id': releaseId,
      if (packKey != null) 'pack_key': packKey,
      if (packVersion != null) 'pack_version': packVersion,
      if (checksum != null) 'checksum': checksum,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentReleasePacksCompanion copyWith({
    Value<String>? releaseId,
    Value<String>? packKey,
    Value<int>? packVersion,
    Value<String>? checksum,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return ContentReleasePacksCompanion(
      releaseId: releaseId ?? this.releaseId,
      packKey: packKey ?? this.packKey,
      packVersion: packVersion ?? this.packVersion,
      checksum: checksum ?? this.checksum,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (releaseId.present) {
      map['release_id'] = Variable<String>(releaseId.value);
    }
    if (packKey.present) {
      map['pack_key'] = Variable<String>(packKey.value);
    }
    if (packVersion.present) {
      map['pack_version'] = Variable<int>(packVersion.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentReleasePacksCompanion(')
          ..write('releaseId: $releaseId, ')
          ..write('packKey: $packKey, ')
          ..write('packVersion: $packVersion, ')
          ..write('checksum: $checksum, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningEvidenceEventsTable extends LearningEvidenceEvents
    with TableInfo<$LearningEvidenceEventsTable, LearningEvidenceEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningEvidenceEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _evidenceIdMeta = const VerificationMeta(
    'evidenceId',
  );
  @override
  late final GeneratedColumn<String> evidenceId = GeneratedColumn<String>(
    'evidence_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skillMeta = const VerificationMeta('skill');
  @override
  late final GeneratedColumn<String> skill = GeneratedColumn<String>(
    'skill',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _novelTaskMeta = const VerificationMeta(
    'novelTask',
  );
  @override
  late final GeneratedColumn<bool> novelTask = GeneratedColumn<bool>(
    'novel_task',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("novel_task" IN (0, 1))',
    ),
  );
  static const VerificationMeta _supportsJsonMeta = const VerificationMeta(
    'supportsJson',
  );
  @override
  late final GeneratedColumn<String> supportsJson = GeneratedColumn<String>(
    'supports_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _conceptKeysJsonMeta = const VerificationMeta(
    'conceptKeysJson',
  );
  @override
  late final GeneratedColumn<String> conceptKeysJson = GeneratedColumn<String>(
    'concept_keys_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _responseLatencyMsMeta = const VerificationMeta(
    'responseLatencyMs',
  );
  @override
  late final GeneratedColumn<int> responseLatencyMs = GeneratedColumn<int>(
    'response_latency_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _observedAtMeta = const VerificationMeta(
    'observedAt',
  );
  @override
  late final GeneratedColumn<DateTime> observedAt = GeneratedColumn<DateTime>(
    'observed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    evidenceId,
    lessonId,
    exerciseId,
    skill,
    phase,
    correct,
    novelTask,
    supportsJson,
    conceptKeysJson,
    responseLatencyMs,
    observedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_evidence_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningEvidenceEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('evidence_id')) {
      context.handle(
        _evidenceIdMeta,
        evidenceId.isAcceptableOrUnknown(data['evidence_id']!, _evidenceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_evidenceIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    }
    if (data.containsKey('skill')) {
      context.handle(
        _skillMeta,
        skill.isAcceptableOrUnknown(data['skill']!, _skillMeta),
      );
    } else if (isInserting) {
      context.missing(_skillMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('novel_task')) {
      context.handle(
        _novelTaskMeta,
        novelTask.isAcceptableOrUnknown(data['novel_task']!, _novelTaskMeta),
      );
    } else if (isInserting) {
      context.missing(_novelTaskMeta);
    }
    if (data.containsKey('supports_json')) {
      context.handle(
        _supportsJsonMeta,
        supportsJson.isAcceptableOrUnknown(
          data['supports_json']!,
          _supportsJsonMeta,
        ),
      );
    }
    if (data.containsKey('concept_keys_json')) {
      context.handle(
        _conceptKeysJsonMeta,
        conceptKeysJson.isAcceptableOrUnknown(
          data['concept_keys_json']!,
          _conceptKeysJsonMeta,
        ),
      );
    }
    if (data.containsKey('response_latency_ms')) {
      context.handle(
        _responseLatencyMsMeta,
        responseLatencyMs.isAcceptableOrUnknown(
          data['response_latency_ms']!,
          _responseLatencyMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseLatencyMsMeta);
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {evidenceId};
  @override
  LearningEvidenceEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningEvidenceEvent(
      evidenceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}evidence_id'],
          )!,
      lessonId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lesson_id'],
          )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      ),
      skill:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}skill'],
          )!,
      phase:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}phase'],
          )!,
      correct:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}correct'],
          )!,
      novelTask:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}novel_task'],
          )!,
      supportsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}supports_json'],
          )!,
      conceptKeysJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}concept_keys_json'],
          )!,
      responseLatencyMs:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}response_latency_ms'],
          )!,
      observedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}observed_at'],
          )!,
    );
  }

  @override
  $LearningEvidenceEventsTable createAlias(String alias) {
    return $LearningEvidenceEventsTable(attachedDatabase, alias);
  }
}

class LearningEvidenceEvent extends DataClass
    implements Insertable<LearningEvidenceEvent> {
  final String evidenceId;
  final int lessonId;
  final int? exerciseId;
  final String skill;
  final String phase;
  final bool correct;
  final bool novelTask;
  final String supportsJson;
  final String conceptKeysJson;
  final int responseLatencyMs;
  final DateTime observedAt;
  const LearningEvidenceEvent({
    required this.evidenceId,
    required this.lessonId,
    this.exerciseId,
    required this.skill,
    required this.phase,
    required this.correct,
    required this.novelTask,
    required this.supportsJson,
    required this.conceptKeysJson,
    required this.responseLatencyMs,
    required this.observedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['evidence_id'] = Variable<String>(evidenceId);
    map['lesson_id'] = Variable<int>(lessonId);
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<int>(exerciseId);
    }
    map['skill'] = Variable<String>(skill);
    map['phase'] = Variable<String>(phase);
    map['correct'] = Variable<bool>(correct);
    map['novel_task'] = Variable<bool>(novelTask);
    map['supports_json'] = Variable<String>(supportsJson);
    map['concept_keys_json'] = Variable<String>(conceptKeysJson);
    map['response_latency_ms'] = Variable<int>(responseLatencyMs);
    map['observed_at'] = Variable<DateTime>(observedAt);
    return map;
  }

  LearningEvidenceEventsCompanion toCompanion(bool nullToAbsent) {
    return LearningEvidenceEventsCompanion(
      evidenceId: Value(evidenceId),
      lessonId: Value(lessonId),
      exerciseId:
          exerciseId == null && nullToAbsent
              ? const Value.absent()
              : Value(exerciseId),
      skill: Value(skill),
      phase: Value(phase),
      correct: Value(correct),
      novelTask: Value(novelTask),
      supportsJson: Value(supportsJson),
      conceptKeysJson: Value(conceptKeysJson),
      responseLatencyMs: Value(responseLatencyMs),
      observedAt: Value(observedAt),
    );
  }

  factory LearningEvidenceEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningEvidenceEvent(
      evidenceId: serializer.fromJson<String>(json['evidenceId']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      exerciseId: serializer.fromJson<int?>(json['exerciseId']),
      skill: serializer.fromJson<String>(json['skill']),
      phase: serializer.fromJson<String>(json['phase']),
      correct: serializer.fromJson<bool>(json['correct']),
      novelTask: serializer.fromJson<bool>(json['novelTask']),
      supportsJson: serializer.fromJson<String>(json['supportsJson']),
      conceptKeysJson: serializer.fromJson<String>(json['conceptKeysJson']),
      responseLatencyMs: serializer.fromJson<int>(json['responseLatencyMs']),
      observedAt: serializer.fromJson<DateTime>(json['observedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'evidenceId': serializer.toJson<String>(evidenceId),
      'lessonId': serializer.toJson<int>(lessonId),
      'exerciseId': serializer.toJson<int?>(exerciseId),
      'skill': serializer.toJson<String>(skill),
      'phase': serializer.toJson<String>(phase),
      'correct': serializer.toJson<bool>(correct),
      'novelTask': serializer.toJson<bool>(novelTask),
      'supportsJson': serializer.toJson<String>(supportsJson),
      'conceptKeysJson': serializer.toJson<String>(conceptKeysJson),
      'responseLatencyMs': serializer.toJson<int>(responseLatencyMs),
      'observedAt': serializer.toJson<DateTime>(observedAt),
    };
  }

  LearningEvidenceEvent copyWith({
    String? evidenceId,
    int? lessonId,
    Value<int?> exerciseId = const Value.absent(),
    String? skill,
    String? phase,
    bool? correct,
    bool? novelTask,
    String? supportsJson,
    String? conceptKeysJson,
    int? responseLatencyMs,
    DateTime? observedAt,
  }) => LearningEvidenceEvent(
    evidenceId: evidenceId ?? this.evidenceId,
    lessonId: lessonId ?? this.lessonId,
    exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
    skill: skill ?? this.skill,
    phase: phase ?? this.phase,
    correct: correct ?? this.correct,
    novelTask: novelTask ?? this.novelTask,
    supportsJson: supportsJson ?? this.supportsJson,
    conceptKeysJson: conceptKeysJson ?? this.conceptKeysJson,
    responseLatencyMs: responseLatencyMs ?? this.responseLatencyMs,
    observedAt: observedAt ?? this.observedAt,
  );
  LearningEvidenceEvent copyWithCompanion(
    LearningEvidenceEventsCompanion data,
  ) {
    return LearningEvidenceEvent(
      evidenceId:
          data.evidenceId.present ? data.evidenceId.value : this.evidenceId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      skill: data.skill.present ? data.skill.value : this.skill,
      phase: data.phase.present ? data.phase.value : this.phase,
      correct: data.correct.present ? data.correct.value : this.correct,
      novelTask: data.novelTask.present ? data.novelTask.value : this.novelTask,
      supportsJson:
          data.supportsJson.present
              ? data.supportsJson.value
              : this.supportsJson,
      conceptKeysJson:
          data.conceptKeysJson.present
              ? data.conceptKeysJson.value
              : this.conceptKeysJson,
      responseLatencyMs:
          data.responseLatencyMs.present
              ? data.responseLatencyMs.value
              : this.responseLatencyMs,
      observedAt:
          data.observedAt.present ? data.observedAt.value : this.observedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningEvidenceEvent(')
          ..write('evidenceId: $evidenceId, ')
          ..write('lessonId: $lessonId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('skill: $skill, ')
          ..write('phase: $phase, ')
          ..write('correct: $correct, ')
          ..write('novelTask: $novelTask, ')
          ..write('supportsJson: $supportsJson, ')
          ..write('conceptKeysJson: $conceptKeysJson, ')
          ..write('responseLatencyMs: $responseLatencyMs, ')
          ..write('observedAt: $observedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    evidenceId,
    lessonId,
    exerciseId,
    skill,
    phase,
    correct,
    novelTask,
    supportsJson,
    conceptKeysJson,
    responseLatencyMs,
    observedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningEvidenceEvent &&
          other.evidenceId == this.evidenceId &&
          other.lessonId == this.lessonId &&
          other.exerciseId == this.exerciseId &&
          other.skill == this.skill &&
          other.phase == this.phase &&
          other.correct == this.correct &&
          other.novelTask == this.novelTask &&
          other.supportsJson == this.supportsJson &&
          other.conceptKeysJson == this.conceptKeysJson &&
          other.responseLatencyMs == this.responseLatencyMs &&
          other.observedAt == this.observedAt);
}

class LearningEvidenceEventsCompanion
    extends UpdateCompanion<LearningEvidenceEvent> {
  final Value<String> evidenceId;
  final Value<int> lessonId;
  final Value<int?> exerciseId;
  final Value<String> skill;
  final Value<String> phase;
  final Value<bool> correct;
  final Value<bool> novelTask;
  final Value<String> supportsJson;
  final Value<String> conceptKeysJson;
  final Value<int> responseLatencyMs;
  final Value<DateTime> observedAt;
  final Value<int> rowid;
  const LearningEvidenceEventsCompanion({
    this.evidenceId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.skill = const Value.absent(),
    this.phase = const Value.absent(),
    this.correct = const Value.absent(),
    this.novelTask = const Value.absent(),
    this.supportsJson = const Value.absent(),
    this.conceptKeysJson = const Value.absent(),
    this.responseLatencyMs = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningEvidenceEventsCompanion.insert({
    required String evidenceId,
    required int lessonId,
    this.exerciseId = const Value.absent(),
    required String skill,
    required String phase,
    required bool correct,
    required bool novelTask,
    this.supportsJson = const Value.absent(),
    this.conceptKeysJson = const Value.absent(),
    required int responseLatencyMs,
    required DateTime observedAt,
    this.rowid = const Value.absent(),
  }) : evidenceId = Value(evidenceId),
       lessonId = Value(lessonId),
       skill = Value(skill),
       phase = Value(phase),
       correct = Value(correct),
       novelTask = Value(novelTask),
       responseLatencyMs = Value(responseLatencyMs),
       observedAt = Value(observedAt);
  static Insertable<LearningEvidenceEvent> custom({
    Expression<String>? evidenceId,
    Expression<int>? lessonId,
    Expression<int>? exerciseId,
    Expression<String>? skill,
    Expression<String>? phase,
    Expression<bool>? correct,
    Expression<bool>? novelTask,
    Expression<String>? supportsJson,
    Expression<String>? conceptKeysJson,
    Expression<int>? responseLatencyMs,
    Expression<DateTime>? observedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (evidenceId != null) 'evidence_id': evidenceId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (skill != null) 'skill': skill,
      if (phase != null) 'phase': phase,
      if (correct != null) 'correct': correct,
      if (novelTask != null) 'novel_task': novelTask,
      if (supportsJson != null) 'supports_json': supportsJson,
      if (conceptKeysJson != null) 'concept_keys_json': conceptKeysJson,
      if (responseLatencyMs != null) 'response_latency_ms': responseLatencyMs,
      if (observedAt != null) 'observed_at': observedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningEvidenceEventsCompanion copyWith({
    Value<String>? evidenceId,
    Value<int>? lessonId,
    Value<int?>? exerciseId,
    Value<String>? skill,
    Value<String>? phase,
    Value<bool>? correct,
    Value<bool>? novelTask,
    Value<String>? supportsJson,
    Value<String>? conceptKeysJson,
    Value<int>? responseLatencyMs,
    Value<DateTime>? observedAt,
    Value<int>? rowid,
  }) {
    return LearningEvidenceEventsCompanion(
      evidenceId: evidenceId ?? this.evidenceId,
      lessonId: lessonId ?? this.lessonId,
      exerciseId: exerciseId ?? this.exerciseId,
      skill: skill ?? this.skill,
      phase: phase ?? this.phase,
      correct: correct ?? this.correct,
      novelTask: novelTask ?? this.novelTask,
      supportsJson: supportsJson ?? this.supportsJson,
      conceptKeysJson: conceptKeysJson ?? this.conceptKeysJson,
      responseLatencyMs: responseLatencyMs ?? this.responseLatencyMs,
      observedAt: observedAt ?? this.observedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (evidenceId.present) {
      map['evidence_id'] = Variable<String>(evidenceId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (skill.present) {
      map['skill'] = Variable<String>(skill.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (novelTask.present) {
      map['novel_task'] = Variable<bool>(novelTask.value);
    }
    if (supportsJson.present) {
      map['supports_json'] = Variable<String>(supportsJson.value);
    }
    if (conceptKeysJson.present) {
      map['concept_keys_json'] = Variable<String>(conceptKeysJson.value);
    }
    if (responseLatencyMs.present) {
      map['response_latency_ms'] = Variable<int>(responseLatencyMs.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<DateTime>(observedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningEvidenceEventsCompanion(')
          ..write('evidenceId: $evidenceId, ')
          ..write('lessonId: $lessonId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('skill: $skill, ')
          ..write('phase: $phase, ')
          ..write('correct: $correct, ')
          ..write('novelTask: $novelTask, ')
          ..write('supportsJson: $supportsJson, ')
          ..write('conceptKeysJson: $conceptKeysJson, ')
          ..write('responseLatencyMs: $responseLatencyMs, ')
          ..write('observedAt: $observedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlacementProfilesTable extends PlacementProfiles
    with TableInfo<$PlacementProfilesTable, PlacementProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacementProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('primary'),
  );
  static const VerificationMeta _provisionalUnitMeta = const VerificationMeta(
    'provisionalUnit',
  );
  @override
  late final GeneratedColumn<int> provisionalUnit = GeneratedColumn<int>(
    'provisional_unit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learnerOverrideUnitMeta =
      const VerificationMeta('learnerOverrideUnit');
  @override
  late final GeneratedColumn<int> learnerOverrideUnit = GeneratedColumn<int>(
    'learner_override_unit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatesJsonMeta = const VerificationMeta(
    'estimatesJson',
  );
  @override
  late final GeneratedColumn<String> estimatesJson = GeneratedColumn<String>(
    'estimates_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleSizeMeta = const VerificationMeta(
    'sampleSize',
  );
  @override
  late final GeneratedColumn<int> sampleSize = GeneratedColumn<int>(
    'sample_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    provisionalUnit,
    learnerOverrideUnit,
    estimatesJson,
    sampleSize,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'placement_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlacementProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('provisional_unit')) {
      context.handle(
        _provisionalUnitMeta,
        provisionalUnit.isAcceptableOrUnknown(
          data['provisional_unit']!,
          _provisionalUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_provisionalUnitMeta);
    }
    if (data.containsKey('learner_override_unit')) {
      context.handle(
        _learnerOverrideUnitMeta,
        learnerOverrideUnit.isAcceptableOrUnknown(
          data['learner_override_unit']!,
          _learnerOverrideUnitMeta,
        ),
      );
    }
    if (data.containsKey('estimates_json')) {
      context.handle(
        _estimatesJsonMeta,
        estimatesJson.isAcceptableOrUnknown(
          data['estimates_json']!,
          _estimatesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estimatesJsonMeta);
    }
    if (data.containsKey('sample_size')) {
      context.handle(
        _sampleSizeMeta,
        sampleSize.isAcceptableOrUnknown(data['sample_size']!, _sampleSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sampleSizeMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PlacementProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlacementProfile(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      provisionalUnit:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}provisional_unit'],
          )!,
      learnerOverrideUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}learner_override_unit'],
      ),
      estimatesJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}estimates_json'],
          )!,
      sampleSize:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sample_size'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $PlacementProfilesTable createAlias(String alias) {
    return $PlacementProfilesTable(attachedDatabase, alias);
  }
}

class PlacementProfile extends DataClass
    implements Insertable<PlacementProfile> {
  final String key;
  final int provisionalUnit;
  final int? learnerOverrideUnit;
  final String estimatesJson;
  final int sampleSize;
  final DateTime updatedAt;
  const PlacementProfile({
    required this.key,
    required this.provisionalUnit,
    this.learnerOverrideUnit,
    required this.estimatesJson,
    required this.sampleSize,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['provisional_unit'] = Variable<int>(provisionalUnit);
    if (!nullToAbsent || learnerOverrideUnit != null) {
      map['learner_override_unit'] = Variable<int>(learnerOverrideUnit);
    }
    map['estimates_json'] = Variable<String>(estimatesJson);
    map['sample_size'] = Variable<int>(sampleSize);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlacementProfilesCompanion toCompanion(bool nullToAbsent) {
    return PlacementProfilesCompanion(
      key: Value(key),
      provisionalUnit: Value(provisionalUnit),
      learnerOverrideUnit:
          learnerOverrideUnit == null && nullToAbsent
              ? const Value.absent()
              : Value(learnerOverrideUnit),
      estimatesJson: Value(estimatesJson),
      sampleSize: Value(sampleSize),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlacementProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlacementProfile(
      key: serializer.fromJson<String>(json['key']),
      provisionalUnit: serializer.fromJson<int>(json['provisionalUnit']),
      learnerOverrideUnit: serializer.fromJson<int?>(
        json['learnerOverrideUnit'],
      ),
      estimatesJson: serializer.fromJson<String>(json['estimatesJson']),
      sampleSize: serializer.fromJson<int>(json['sampleSize']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'provisionalUnit': serializer.toJson<int>(provisionalUnit),
      'learnerOverrideUnit': serializer.toJson<int?>(learnerOverrideUnit),
      'estimatesJson': serializer.toJson<String>(estimatesJson),
      'sampleSize': serializer.toJson<int>(sampleSize),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlacementProfile copyWith({
    String? key,
    int? provisionalUnit,
    Value<int?> learnerOverrideUnit = const Value.absent(),
    String? estimatesJson,
    int? sampleSize,
    DateTime? updatedAt,
  }) => PlacementProfile(
    key: key ?? this.key,
    provisionalUnit: provisionalUnit ?? this.provisionalUnit,
    learnerOverrideUnit:
        learnerOverrideUnit.present
            ? learnerOverrideUnit.value
            : this.learnerOverrideUnit,
    estimatesJson: estimatesJson ?? this.estimatesJson,
    sampleSize: sampleSize ?? this.sampleSize,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlacementProfile copyWithCompanion(PlacementProfilesCompanion data) {
    return PlacementProfile(
      key: data.key.present ? data.key.value : this.key,
      provisionalUnit:
          data.provisionalUnit.present
              ? data.provisionalUnit.value
              : this.provisionalUnit,
      learnerOverrideUnit:
          data.learnerOverrideUnit.present
              ? data.learnerOverrideUnit.value
              : this.learnerOverrideUnit,
      estimatesJson:
          data.estimatesJson.present
              ? data.estimatesJson.value
              : this.estimatesJson,
      sampleSize:
          data.sampleSize.present ? data.sampleSize.value : this.sampleSize,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlacementProfile(')
          ..write('key: $key, ')
          ..write('provisionalUnit: $provisionalUnit, ')
          ..write('learnerOverrideUnit: $learnerOverrideUnit, ')
          ..write('estimatesJson: $estimatesJson, ')
          ..write('sampleSize: $sampleSize, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    provisionalUnit,
    learnerOverrideUnit,
    estimatesJson,
    sampleSize,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlacementProfile &&
          other.key == this.key &&
          other.provisionalUnit == this.provisionalUnit &&
          other.learnerOverrideUnit == this.learnerOverrideUnit &&
          other.estimatesJson == this.estimatesJson &&
          other.sampleSize == this.sampleSize &&
          other.updatedAt == this.updatedAt);
}

class PlacementProfilesCompanion extends UpdateCompanion<PlacementProfile> {
  final Value<String> key;
  final Value<int> provisionalUnit;
  final Value<int?> learnerOverrideUnit;
  final Value<String> estimatesJson;
  final Value<int> sampleSize;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlacementProfilesCompanion({
    this.key = const Value.absent(),
    this.provisionalUnit = const Value.absent(),
    this.learnerOverrideUnit = const Value.absent(),
    this.estimatesJson = const Value.absent(),
    this.sampleSize = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlacementProfilesCompanion.insert({
    this.key = const Value.absent(),
    required int provisionalUnit,
    this.learnerOverrideUnit = const Value.absent(),
    required String estimatesJson,
    required int sampleSize,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : provisionalUnit = Value(provisionalUnit),
       estimatesJson = Value(estimatesJson),
       sampleSize = Value(sampleSize),
       updatedAt = Value(updatedAt);
  static Insertable<PlacementProfile> custom({
    Expression<String>? key,
    Expression<int>? provisionalUnit,
    Expression<int>? learnerOverrideUnit,
    Expression<String>? estimatesJson,
    Expression<int>? sampleSize,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (provisionalUnit != null) 'provisional_unit': provisionalUnit,
      if (learnerOverrideUnit != null)
        'learner_override_unit': learnerOverrideUnit,
      if (estimatesJson != null) 'estimates_json': estimatesJson,
      if (sampleSize != null) 'sample_size': sampleSize,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlacementProfilesCompanion copyWith({
    Value<String>? key,
    Value<int>? provisionalUnit,
    Value<int?>? learnerOverrideUnit,
    Value<String>? estimatesJson,
    Value<int>? sampleSize,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlacementProfilesCompanion(
      key: key ?? this.key,
      provisionalUnit: provisionalUnit ?? this.provisionalUnit,
      learnerOverrideUnit: learnerOverrideUnit ?? this.learnerOverrideUnit,
      estimatesJson: estimatesJson ?? this.estimatesJson,
      sampleSize: sampleSize ?? this.sampleSize,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (provisionalUnit.present) {
      map['provisional_unit'] = Variable<int>(provisionalUnit.value);
    }
    if (learnerOverrideUnit.present) {
      map['learner_override_unit'] = Variable<int>(learnerOverrideUnit.value);
    }
    if (estimatesJson.present) {
      map['estimates_json'] = Variable<String>(estimatesJson.value);
    }
    if (sampleSize.present) {
      map['sample_size'] = Variable<int>(sampleSize.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacementProfilesCompanion(')
          ..write('key: $key, ')
          ..write('provisionalUnit: $provisionalUnit, ')
          ..write('learnerOverrideUnit: $learnerOverrideUnit, ')
          ..write('estimatesJson: $estimatesJson, ')
          ..write('sampleSize: $sampleSize, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DelayedTransferAssignmentsTable extends DelayedTransferAssignments
    with
        TableInfo<$DelayedTransferAssignmentsTable, DelayedTransferAssignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DelayedTransferAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assignmentIdMeta = const VerificationMeta(
    'assignmentId',
  );
  @override
  late final GeneratedColumn<String> assignmentId = GeneratedColumn<String>(
    'assignment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAttemptIdMeta = const VerificationMeta(
    'sourceAttemptId',
  );
  @override
  late final GeneratedColumn<String> sourceAttemptId = GeneratedColumn<String>(
    'source_attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceExerciseIdMeta = const VerificationMeta(
    'sourceExerciseId',
  );
  @override
  late final GeneratedColumn<int> sourceExerciseId = GeneratedColumn<int>(
    'source_exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _completedEvidenceIdMeta =
      const VerificationMeta('completedEvidenceId');
  @override
  late final GeneratedColumn<String> completedEvidenceId =
      GeneratedColumn<String>(
        'completed_evidence_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    assignmentId,
    sourceAttemptId,
    lessonId,
    sourceExerciseId,
    dueAt,
    status,
    completedEvidenceId,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'delayed_transfer_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DelayedTransferAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('assignment_id')) {
      context.handle(
        _assignmentIdMeta,
        assignmentId.isAcceptableOrUnknown(
          data['assignment_id']!,
          _assignmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assignmentIdMeta);
    }
    if (data.containsKey('source_attempt_id')) {
      context.handle(
        _sourceAttemptIdMeta,
        sourceAttemptId.isAcceptableOrUnknown(
          data['source_attempt_id']!,
          _sourceAttemptIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceAttemptIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('source_exercise_id')) {
      context.handle(
        _sourceExerciseIdMeta,
        sourceExerciseId.isAcceptableOrUnknown(
          data['source_exercise_id']!,
          _sourceExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceExerciseIdMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('completed_evidence_id')) {
      context.handle(
        _completedEvidenceIdMeta,
        completedEvidenceId.isAcceptableOrUnknown(
          data['completed_evidence_id']!,
          _completedEvidenceIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assignmentId};
  @override
  DelayedTransferAssignment map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DelayedTransferAssignment(
      assignmentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}assignment_id'],
          )!,
      sourceAttemptId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_attempt_id'],
          )!,
      lessonId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lesson_id'],
          )!,
      sourceExerciseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}source_exercise_id'],
          )!,
      dueAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}due_at'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      completedEvidenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_evidence_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DelayedTransferAssignmentsTable createAlias(String alias) {
    return $DelayedTransferAssignmentsTable(attachedDatabase, alias);
  }
}

class DelayedTransferAssignment extends DataClass
    implements Insertable<DelayedTransferAssignment> {
  final String assignmentId;
  final String sourceAttemptId;
  final int lessonId;
  final int sourceExerciseId;
  final DateTime dueAt;
  final String status;
  final String? completedEvidenceId;
  final DateTime createdAt;
  final DateTime? completedAt;
  const DelayedTransferAssignment({
    required this.assignmentId,
    required this.sourceAttemptId,
    required this.lessonId,
    required this.sourceExerciseId,
    required this.dueAt,
    required this.status,
    this.completedEvidenceId,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['assignment_id'] = Variable<String>(assignmentId);
    map['source_attempt_id'] = Variable<String>(sourceAttemptId);
    map['lesson_id'] = Variable<int>(lessonId);
    map['source_exercise_id'] = Variable<int>(sourceExerciseId);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || completedEvidenceId != null) {
      map['completed_evidence_id'] = Variable<String>(completedEvidenceId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DelayedTransferAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return DelayedTransferAssignmentsCompanion(
      assignmentId: Value(assignmentId),
      sourceAttemptId: Value(sourceAttemptId),
      lessonId: Value(lessonId),
      sourceExerciseId: Value(sourceExerciseId),
      dueAt: Value(dueAt),
      status: Value(status),
      completedEvidenceId:
          completedEvidenceId == null && nullToAbsent
              ? const Value.absent()
              : Value(completedEvidenceId),
      createdAt: Value(createdAt),
      completedAt:
          completedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(completedAt),
    );
  }

  factory DelayedTransferAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DelayedTransferAssignment(
      assignmentId: serializer.fromJson<String>(json['assignmentId']),
      sourceAttemptId: serializer.fromJson<String>(json['sourceAttemptId']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      sourceExerciseId: serializer.fromJson<int>(json['sourceExerciseId']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      status: serializer.fromJson<String>(json['status']),
      completedEvidenceId: serializer.fromJson<String?>(
        json['completedEvidenceId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assignmentId': serializer.toJson<String>(assignmentId),
      'sourceAttemptId': serializer.toJson<String>(sourceAttemptId),
      'lessonId': serializer.toJson<int>(lessonId),
      'sourceExerciseId': serializer.toJson<int>(sourceExerciseId),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'status': serializer.toJson<String>(status),
      'completedEvidenceId': serializer.toJson<String?>(completedEvidenceId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DelayedTransferAssignment copyWith({
    String? assignmentId,
    String? sourceAttemptId,
    int? lessonId,
    int? sourceExerciseId,
    DateTime? dueAt,
    String? status,
    Value<String?> completedEvidenceId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DelayedTransferAssignment(
    assignmentId: assignmentId ?? this.assignmentId,
    sourceAttemptId: sourceAttemptId ?? this.sourceAttemptId,
    lessonId: lessonId ?? this.lessonId,
    sourceExerciseId: sourceExerciseId ?? this.sourceExerciseId,
    dueAt: dueAt ?? this.dueAt,
    status: status ?? this.status,
    completedEvidenceId:
        completedEvidenceId.present
            ? completedEvidenceId.value
            : this.completedEvidenceId,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DelayedTransferAssignment copyWithCompanion(
    DelayedTransferAssignmentsCompanion data,
  ) {
    return DelayedTransferAssignment(
      assignmentId:
          data.assignmentId.present
              ? data.assignmentId.value
              : this.assignmentId,
      sourceAttemptId:
          data.sourceAttemptId.present
              ? data.sourceAttemptId.value
              : this.sourceAttemptId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      sourceExerciseId:
          data.sourceExerciseId.present
              ? data.sourceExerciseId.value
              : this.sourceExerciseId,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      status: data.status.present ? data.status.value : this.status,
      completedEvidenceId:
          data.completedEvidenceId.present
              ? data.completedEvidenceId.value
              : this.completedEvidenceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DelayedTransferAssignment(')
          ..write('assignmentId: $assignmentId, ')
          ..write('sourceAttemptId: $sourceAttemptId, ')
          ..write('lessonId: $lessonId, ')
          ..write('sourceExerciseId: $sourceExerciseId, ')
          ..write('dueAt: $dueAt, ')
          ..write('status: $status, ')
          ..write('completedEvidenceId: $completedEvidenceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    assignmentId,
    sourceAttemptId,
    lessonId,
    sourceExerciseId,
    dueAt,
    status,
    completedEvidenceId,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DelayedTransferAssignment &&
          other.assignmentId == this.assignmentId &&
          other.sourceAttemptId == this.sourceAttemptId &&
          other.lessonId == this.lessonId &&
          other.sourceExerciseId == this.sourceExerciseId &&
          other.dueAt == this.dueAt &&
          other.status == this.status &&
          other.completedEvidenceId == this.completedEvidenceId &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DelayedTransferAssignmentsCompanion
    extends UpdateCompanion<DelayedTransferAssignment> {
  final Value<String> assignmentId;
  final Value<String> sourceAttemptId;
  final Value<int> lessonId;
  final Value<int> sourceExerciseId;
  final Value<DateTime> dueAt;
  final Value<String> status;
  final Value<String?> completedEvidenceId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DelayedTransferAssignmentsCompanion({
    this.assignmentId = const Value.absent(),
    this.sourceAttemptId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.sourceExerciseId = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.status = const Value.absent(),
    this.completedEvidenceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DelayedTransferAssignmentsCompanion.insert({
    required String assignmentId,
    required String sourceAttemptId,
    required int lessonId,
    required int sourceExerciseId,
    required DateTime dueAt,
    this.status = const Value.absent(),
    this.completedEvidenceId = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : assignmentId = Value(assignmentId),
       sourceAttemptId = Value(sourceAttemptId),
       lessonId = Value(lessonId),
       sourceExerciseId = Value(sourceExerciseId),
       dueAt = Value(dueAt),
       createdAt = Value(createdAt);
  static Insertable<DelayedTransferAssignment> custom({
    Expression<String>? assignmentId,
    Expression<String>? sourceAttemptId,
    Expression<int>? lessonId,
    Expression<int>? sourceExerciseId,
    Expression<DateTime>? dueAt,
    Expression<String>? status,
    Expression<String>? completedEvidenceId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assignmentId != null) 'assignment_id': assignmentId,
      if (sourceAttemptId != null) 'source_attempt_id': sourceAttemptId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (sourceExerciseId != null) 'source_exercise_id': sourceExerciseId,
      if (dueAt != null) 'due_at': dueAt,
      if (status != null) 'status': status,
      if (completedEvidenceId != null)
        'completed_evidence_id': completedEvidenceId,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DelayedTransferAssignmentsCompanion copyWith({
    Value<String>? assignmentId,
    Value<String>? sourceAttemptId,
    Value<int>? lessonId,
    Value<int>? sourceExerciseId,
    Value<DateTime>? dueAt,
    Value<String>? status,
    Value<String?>? completedEvidenceId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DelayedTransferAssignmentsCompanion(
      assignmentId: assignmentId ?? this.assignmentId,
      sourceAttemptId: sourceAttemptId ?? this.sourceAttemptId,
      lessonId: lessonId ?? this.lessonId,
      sourceExerciseId: sourceExerciseId ?? this.sourceExerciseId,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      completedEvidenceId: completedEvidenceId ?? this.completedEvidenceId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assignmentId.present) {
      map['assignment_id'] = Variable<String>(assignmentId.value);
    }
    if (sourceAttemptId.present) {
      map['source_attempt_id'] = Variable<String>(sourceAttemptId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (sourceExerciseId.present) {
      map['source_exercise_id'] = Variable<int>(sourceExerciseId.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (completedEvidenceId.present) {
      map['completed_evidence_id'] = Variable<String>(
        completedEvidenceId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DelayedTransferAssignmentsCompanion(')
          ..write('assignmentId: $assignmentId, ')
          ..write('sourceAttemptId: $sourceAttemptId, ')
          ..write('lessonId: $lessonId, ')
          ..write('sourceExerciseId: $sourceExerciseId, ')
          ..write('dueAt: $dueAt, ')
          ..write('status: $status, ')
          ..write('completedEvidenceId: $completedEvidenceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UnitsTable units = $UnitsTable(this);
  late final $LessonsTable lessons = $LessonsTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $FlashcardsTable flashcards = $FlashcardsTable(this);
  late final $SrsCardsTable srsCards = $SrsCardsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $GrammarRulesTable grammarRules = $GrammarRulesTable(this);
  late final $ExamResultsTable examResults = $ExamResultsTable(this);
  late final $UserProgressTable userProgress = $UserProgressTable(this);
  late final $EarnedBadgesTable earnedBadges = $EarnedBadgesTable(this);
  late final $ConsentRecordsTable consentRecords = $ConsentRecordsTable(this);
  late final $LessonProgressTable lessonProgress = $LessonProgressTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $GamificationStateTableTable gamificationStateTable =
      $GamificationStateTableTable(this);
  late final $LessonAttemptsTable lessonAttempts = $LessonAttemptsTable(this);
  late final $RewardLedgerTable rewardLedger = $RewardLedgerTable(this);
  late final $ExerciseAttemptsTable exerciseAttempts = $ExerciseAttemptsTable(
    this,
  );
  late final $ReviewAttemptsTable reviewAttempts = $ReviewAttemptsTable(this);
  late final $ContentReleaseInstallationsTable contentReleaseInstallations =
      $ContentReleaseInstallationsTable(this);
  late final $ContentReleasePacksTable contentReleasePacks =
      $ContentReleasePacksTable(this);
  late final $LearningEvidenceEventsTable learningEvidenceEvents =
      $LearningEvidenceEventsTable(this);
  late final $PlacementProfilesTable placementProfiles =
      $PlacementProfilesTable(this);
  late final $DelayedTransferAssignmentsTable delayedTransferAssignments =
      $DelayedTransferAssignmentsTable(this);
  late final CurriculumDao curriculumDao = CurriculumDao(this as AppDatabase);
  late final VocabularyDao vocabularyDao = VocabularyDao(this as AppDatabase);
  late final ConversationDao conversationDao = ConversationDao(
    this as AppDatabase,
  );
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  late final GamificationDao gamificationDao = GamificationDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    units,
    lessons,
    exercises,
    flashcards,
    srsCards,
    conversations,
    chatMessages,
    grammarRules,
    examResults,
    userProgress,
    earnedBadges,
    consentRecords,
    lessonProgress,
    syncQueue,
    syncState,
    gamificationStateTable,
    lessonAttempts,
    rewardLedger,
    exerciseAttempts,
    reviewAttempts,
    contentReleaseInstallations,
    contentReleasePacks,
    learningEvidenceEvents,
    placementProfiles,
    delayedTransferAssignments,
  ];
}

typedef $$UnitsTableCreateCompanionBuilder =
    UnitsCompanion Function({
      Value<int> id,
      required String title,
      required String description,
      required String phase,
      required int orderIndex,
      Value<String> grammarTags,
      Value<bool> isExamPrep,
      Value<int?> lessonCount,
      Value<bool> isActive,
    });
typedef $$UnitsTableUpdateCompanionBuilder =
    UnitsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> description,
      Value<String> phase,
      Value<int> orderIndex,
      Value<String> grammarTags,
      Value<bool> isExamPrep,
      Value<int?> lessonCount,
      Value<bool> isActive,
    });

final class $$UnitsTableReferences
    extends BaseReferences<_$AppDatabase, $UnitsTable, Unit> {
  $$UnitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LessonsTable, List<Lesson>> _lessonsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.lessons,
    aliasName: 'units__id__lessons__unit_id',
  );

  $$LessonsTableProcessedTableManager get lessonsRefs {
    final manager = $$LessonsTableTableManager(
      $_db,
      $_db.lessons,
    ).filter((f) => f.unitId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lessonsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlashcardsTable, List<Flashcard>>
  _flashcardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flashcards,
    aliasName: 'units__id__flashcards__unit_id',
  );

  $$FlashcardsTableProcessedTableManager get flashcardsRefs {
    final manager = $$FlashcardsTableTableManager(
      $_db,
      $_db.flashcards,
    ).filter((f) => f.unitId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flashcardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GrammarRulesTable, List<GrammarRule>>
  _grammarRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.grammarRules,
    aliasName: 'units__id__grammar_rules__unit_id',
  );

  $$GrammarRulesTableProcessedTableManager get grammarRulesRefs {
    final manager = $$GrammarRulesTableTableManager(
      $_db,
      $_db.grammarRules,
    ).filter((f) => f.unitId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_grammarRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UnitsTableFilterComposer extends Composer<_$AppDatabase, $UnitsTable> {
  $$UnitsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grammarTags => $composableBuilder(
    column: $table.grammarTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isExamPrep => $composableBuilder(
    column: $table.isExamPrep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonCount => $composableBuilder(
    column: $table.lessonCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> lessonsRefs(
    Expression<bool> Function($$LessonsTableFilterComposer f) f,
  ) {
    final $$LessonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.unitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableFilterComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flashcardsRefs(
    Expression<bool> Function($$FlashcardsTableFilterComposer f) f,
  ) {
    final $$FlashcardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.unitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableFilterComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> grammarRulesRefs(
    Expression<bool> Function($$GrammarRulesTableFilterComposer f) f,
  ) {
    final $$GrammarRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.grammarRules,
      getReferencedColumn: (t) => t.unitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GrammarRulesTableFilterComposer(
            $db: $db,
            $table: $db.grammarRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UnitsTableOrderingComposer
    extends Composer<_$AppDatabase, $UnitsTable> {
  $$UnitsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grammarTags => $composableBuilder(
    column: $table.grammarTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isExamPrep => $composableBuilder(
    column: $table.isExamPrep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonCount => $composableBuilder(
    column: $table.lessonCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnitsTable> {
  $$UnitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get grammarTags => $composableBuilder(
    column: $table.grammarTags,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isExamPrep => $composableBuilder(
    column: $table.isExamPrep,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lessonCount => $composableBuilder(
    column: $table.lessonCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> lessonsRefs<T extends Object>(
    Expression<T> Function($$LessonsTableAnnotationComposer a) f,
  ) {
    final $$LessonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.unitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableAnnotationComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> flashcardsRefs<T extends Object>(
    Expression<T> Function($$FlashcardsTableAnnotationComposer a) f,
  ) {
    final $$FlashcardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.unitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> grammarRulesRefs<T extends Object>(
    Expression<T> Function($$GrammarRulesTableAnnotationComposer a) f,
  ) {
    final $$GrammarRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.grammarRules,
      getReferencedColumn: (t) => t.unitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GrammarRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.grammarRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UnitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UnitsTable,
          Unit,
          $$UnitsTableFilterComposer,
          $$UnitsTableOrderingComposer,
          $$UnitsTableAnnotationComposer,
          $$UnitsTableCreateCompanionBuilder,
          $$UnitsTableUpdateCompanionBuilder,
          (Unit, $$UnitsTableReferences),
          Unit,
          PrefetchHooks Function({
            bool lessonsRefs,
            bool flashcardsRefs,
            bool grammarRulesRefs,
          })
        > {
  $$UnitsTableTableManager(_$AppDatabase db, $UnitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UnitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$UnitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$UnitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> grammarTags = const Value.absent(),
                Value<bool> isExamPrep = const Value.absent(),
                Value<int?> lessonCount = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => UnitsCompanion(
                id: id,
                title: title,
                description: description,
                phase: phase,
                orderIndex: orderIndex,
                grammarTags: grammarTags,
                isExamPrep: isExamPrep,
                lessonCount: lessonCount,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String description,
                required String phase,
                required int orderIndex,
                Value<String> grammarTags = const Value.absent(),
                Value<bool> isExamPrep = const Value.absent(),
                Value<int?> lessonCount = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => UnitsCompanion.insert(
                id: id,
                title: title,
                description: description,
                phase: phase,
                orderIndex: orderIndex,
                grammarTags: grammarTags,
                isExamPrep: isExamPrep,
                lessonCount: lessonCount,
                isActive: isActive,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$UnitsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            lessonsRefs = false,
            flashcardsRefs = false,
            grammarRulesRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (lessonsRefs) db.lessons,
                if (flashcardsRefs) db.flashcards,
                if (grammarRulesRefs) db.grammarRules,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lessonsRefs)
                    await $_getPrefetchedData<Unit, $UnitsTable, Lesson>(
                      currentTable: table,
                      referencedTable: $$UnitsTableReferences._lessonsRefsTable(
                        db,
                      ),
                      managerFromTypedResult:
                          (p0) =>
                              $$UnitsTableReferences(db, table, p0).lessonsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.unitId == item.id),
                      typedResults: items,
                    ),
                  if (flashcardsRefs)
                    await $_getPrefetchedData<Unit, $UnitsTable, Flashcard>(
                      currentTable: table,
                      referencedTable: $$UnitsTableReferences
                          ._flashcardsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$UnitsTableReferences(
                                db,
                                table,
                                p0,
                              ).flashcardsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.unitId == item.id),
                      typedResults: items,
                    ),
                  if (grammarRulesRefs)
                    await $_getPrefetchedData<Unit, $UnitsTable, GrammarRule>(
                      currentTable: table,
                      referencedTable: $$UnitsTableReferences
                          ._grammarRulesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$UnitsTableReferences(
                                db,
                                table,
                                p0,
                              ).grammarRulesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.unitId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UnitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UnitsTable,
      Unit,
      $$UnitsTableFilterComposer,
      $$UnitsTableOrderingComposer,
      $$UnitsTableAnnotationComposer,
      $$UnitsTableCreateCompanionBuilder,
      $$UnitsTableUpdateCompanionBuilder,
      (Unit, $$UnitsTableReferences),
      Unit,
      PrefetchHooks Function({
        bool lessonsRefs,
        bool flashcardsRefs,
        bool grammarRulesRefs,
      })
    >;
typedef $$LessonsTableCreateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      required int unitId,
      required int orderInUnit,
      required String title,
      required String description,
      Value<int> durationMinutes,
      Value<String> lessonType,
      Value<bool> isReview,
      Value<bool> isActive,
    });
typedef $$LessonsTableUpdateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      Value<int> unitId,
      Value<int> orderInUnit,
      Value<String> title,
      Value<String> description,
      Value<int> durationMinutes,
      Value<String> lessonType,
      Value<bool> isReview,
      Value<bool> isActive,
    });

final class $$LessonsTableReferences
    extends BaseReferences<_$AppDatabase, $LessonsTable, Lesson> {
  $$LessonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UnitsTable _unitIdTable(_$AppDatabase db) =>
      db.units.createAlias('lessons__unit_id__units__id');

  $$UnitsTableProcessedTableManager get unitId {
    final $_column = $_itemColumn<int>('unit_id')!;

    final manager = $$UnitsTableTableManager(
      $_db,
      $_db.units,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_unitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ExercisesTable, List<Exercise>>
  _exercisesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.exercises,
    aliasName: 'lessons__id__exercises__lesson_id',
  );

  $$ExercisesTableProcessedTableManager get exercisesRefs {
    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.lessonId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_exercisesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlashcardsTable, List<Flashcard>>
  _flashcardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flashcards,
    aliasName: 'lessons__id__flashcards__lesson_id',
  );

  $$FlashcardsTableProcessedTableManager get flashcardsRefs {
    final manager = $$FlashcardsTableTableManager(
      $_db,
      $_db.flashcards,
    ).filter((f) => f.lessonId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flashcardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LessonsTableFilterComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableFilterComposer({
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

  ColumnFilters<int> get orderInUnit => $composableBuilder(
    column: $table.orderInUnit,
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

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonType => $composableBuilder(
    column: $table.lessonType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReview => $composableBuilder(
    column: $table.isReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$UnitsTableFilterComposer get unitId {
    final $$UnitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableFilterComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> exercisesRefs(
    Expression<bool> Function($$ExercisesTableFilterComposer f) f,
  ) {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flashcardsRefs(
    Expression<bool> Function($$FlashcardsTableFilterComposer f) f,
  ) {
    final $$FlashcardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableFilterComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LessonsTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableOrderingComposer({
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

  ColumnOrderings<int> get orderInUnit => $composableBuilder(
    column: $table.orderInUnit,
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

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonType => $composableBuilder(
    column: $table.lessonType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReview => $composableBuilder(
    column: $table.isReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$UnitsTableOrderingComposer get unitId {
    final $$UnitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableOrderingComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LessonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderInUnit => $composableBuilder(
    column: $table.orderInUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lessonType => $composableBuilder(
    column: $table.lessonType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isReview =>
      $composableBuilder(column: $table.isReview, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$UnitsTableAnnotationComposer get unitId {
    final $$UnitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableAnnotationComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> exercisesRefs<T extends Object>(
    Expression<T> Function($$ExercisesTableAnnotationComposer a) f,
  ) {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> flashcardsRefs<T extends Object>(
    Expression<T> Function($$FlashcardsTableAnnotationComposer a) f,
  ) {
    final $$FlashcardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LessonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonsTable,
          Lesson,
          $$LessonsTableFilterComposer,
          $$LessonsTableOrderingComposer,
          $$LessonsTableAnnotationComposer,
          $$LessonsTableCreateCompanionBuilder,
          $$LessonsTableUpdateCompanionBuilder,
          (Lesson, $$LessonsTableReferences),
          Lesson,
          PrefetchHooks Function({
            bool unitId,
            bool exercisesRefs,
            bool flashcardsRefs,
          })
        > {
  $$LessonsTableTableManager(_$AppDatabase db, $LessonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$LessonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$LessonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$LessonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> unitId = const Value.absent(),
                Value<int> orderInUnit = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String> lessonType = const Value.absent(),
                Value<bool> isReview = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => LessonsCompanion(
                id: id,
                unitId: unitId,
                orderInUnit: orderInUnit,
                title: title,
                description: description,
                durationMinutes: durationMinutes,
                lessonType: lessonType,
                isReview: isReview,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int unitId,
                required int orderInUnit,
                required String title,
                required String description,
                Value<int> durationMinutes = const Value.absent(),
                Value<String> lessonType = const Value.absent(),
                Value<bool> isReview = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => LessonsCompanion.insert(
                id: id,
                unitId: unitId,
                orderInUnit: orderInUnit,
                title: title,
                description: description,
                durationMinutes: durationMinutes,
                lessonType: lessonType,
                isReview: isReview,
                isActive: isActive,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$LessonsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            unitId = false,
            exercisesRefs = false,
            flashcardsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (exercisesRefs) db.exercises,
                if (flashcardsRefs) db.flashcards,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (unitId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.unitId,
                            referencedTable: $$LessonsTableReferences
                                ._unitIdTable(db),
                            referencedColumn:
                                $$LessonsTableReferences._unitIdTable(db).id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (exercisesRefs)
                    await $_getPrefetchedData<Lesson, $LessonsTable, Exercise>(
                      currentTable: table,
                      referencedTable: $$LessonsTableReferences
                          ._exercisesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$LessonsTableReferences(
                                db,
                                table,
                                p0,
                              ).exercisesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.lessonId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (flashcardsRefs)
                    await $_getPrefetchedData<Lesson, $LessonsTable, Flashcard>(
                      currentTable: table,
                      referencedTable: $$LessonsTableReferences
                          ._flashcardsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$LessonsTableReferences(
                                db,
                                table,
                                p0,
                              ).flashcardsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.lessonId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LessonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonsTable,
      Lesson,
      $$LessonsTableFilterComposer,
      $$LessonsTableOrderingComposer,
      $$LessonsTableAnnotationComposer,
      $$LessonsTableCreateCompanionBuilder,
      $$LessonsTableUpdateCompanionBuilder,
      (Lesson, $$LessonsTableReferences),
      Lesson,
      PrefetchHooks Function({
        bool unitId,
        bool exercisesRefs,
        bool flashcardsRefs,
      })
    >;
typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      required int lessonId,
      required String type,
      required String prompt,
      required String data,
      Value<String?> answerKey,
      Value<String?> grammarRuleId,
      Value<int> xpReward,
      Value<bool> isActive,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<int> lessonId,
      Value<String> type,
      Value<String> prompt,
      Value<String> data,
      Value<String?> answerKey,
      Value<String?> grammarRuleId,
      Value<int> xpReward,
      Value<bool> isActive,
    });

final class $$ExercisesTableReferences
    extends BaseReferences<_$AppDatabase, $ExercisesTable, Exercise> {
  $$ExercisesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LessonsTable _lessonIdTable(_$AppDatabase db) =>
      db.lessons.createAlias('exercises__lesson_id__lessons__id');

  $$LessonsTableProcessedTableManager get lessonId {
    final $_column = $_itemColumn<int>('lesson_id')!;

    final manager = $$LessonsTableTableManager(
      $_db,
      $_db.lessons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lessonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerKey => $composableBuilder(
    column: $table.answerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grammarRuleId => $composableBuilder(
    column: $table.grammarRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xpReward => $composableBuilder(
    column: $table.xpReward,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$LessonsTableFilterComposer get lessonId {
    final $$LessonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableFilterComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerKey => $composableBuilder(
    column: $table.answerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grammarRuleId => $composableBuilder(
    column: $table.grammarRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xpReward => $composableBuilder(
    column: $table.xpReward,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$LessonsTableOrderingComposer get lessonId {
    final $$LessonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableOrderingComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get answerKey =>
      $composableBuilder(column: $table.answerKey, builder: (column) => column);

  GeneratedColumn<String> get grammarRuleId => $composableBuilder(
    column: $table.grammarRuleId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get xpReward =>
      $composableBuilder(column: $table.xpReward, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$LessonsTableAnnotationComposer get lessonId {
    final $$LessonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableAnnotationComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, $$ExercisesTableReferences),
          Exercise,
          PrefetchHooks Function({bool lessonId})
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> answerKey = const Value.absent(),
                Value<String?> grammarRuleId = const Value.absent(),
                Value<int> xpReward = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                lessonId: lessonId,
                type: type,
                prompt: prompt,
                data: data,
                answerKey: answerKey,
                grammarRuleId: grammarRuleId,
                xpReward: xpReward,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lessonId,
                required String type,
                required String prompt,
                required String data,
                Value<String?> answerKey = const Value.absent(),
                Value<String?> grammarRuleId = const Value.absent(),
                Value<int> xpReward = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                lessonId: lessonId,
                type: type,
                prompt: prompt,
                data: data,
                answerKey: answerKey,
                grammarRuleId: grammarRuleId,
                xpReward: xpReward,
                isActive: isActive,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ExercisesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({lessonId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (lessonId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.lessonId,
                            referencedTable: $$ExercisesTableReferences
                                ._lessonIdTable(db),
                            referencedColumn:
                                $$ExercisesTableReferences
                                    ._lessonIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, $$ExercisesTableReferences),
      Exercise,
      PrefetchHooks Function({bool lessonId})
    >;
typedef $$FlashcardsTableCreateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      required String wordCz,
      required String wordEn,
      Value<String?> ipa,
      Value<String?> gender,
      Value<String?> caseInfo,
      Value<String?> audioHash,
      Value<String?> imagePath,
      Value<String?> exampleCz,
      Value<String?> exampleEn,
      Value<String?> lemma,
      Value<String?> senseKey,
      Value<String?> partOfSpeech,
      Value<String?> morphologyJson,
      Value<String?> registerLabel,
      Value<String?> pronunciationSource,
      Value<String?> contentUid,
      Value<int?> unitId,
      Value<int?> lessonId,
      Value<bool> isActive,
    });
typedef $$FlashcardsTableUpdateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      Value<String> wordCz,
      Value<String> wordEn,
      Value<String?> ipa,
      Value<String?> gender,
      Value<String?> caseInfo,
      Value<String?> audioHash,
      Value<String?> imagePath,
      Value<String?> exampleCz,
      Value<String?> exampleEn,
      Value<String?> lemma,
      Value<String?> senseKey,
      Value<String?> partOfSpeech,
      Value<String?> morphologyJson,
      Value<String?> registerLabel,
      Value<String?> pronunciationSource,
      Value<String?> contentUid,
      Value<int?> unitId,
      Value<int?> lessonId,
      Value<bool> isActive,
    });

final class $$FlashcardsTableReferences
    extends BaseReferences<_$AppDatabase, $FlashcardsTable, Flashcard> {
  $$FlashcardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UnitsTable _unitIdTable(_$AppDatabase db) =>
      db.units.createAlias('flashcards__unit_id__units__id');

  $$UnitsTableProcessedTableManager? get unitId {
    final $_column = $_itemColumn<int>('unit_id');
    if ($_column == null) return null;
    final manager = $$UnitsTableTableManager(
      $_db,
      $_db.units,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_unitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LessonsTable _lessonIdTable(_$AppDatabase db) =>
      db.lessons.createAlias('flashcards__lesson_id__lessons__id');

  $$LessonsTableProcessedTableManager? get lessonId {
    final $_column = $_itemColumn<int>('lesson_id');
    if ($_column == null) return null;
    final manager = $$LessonsTableTableManager(
      $_db,
      $_db.lessons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lessonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SrsCardsTable, List<SrsCard>> _srsCardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.srsCards,
    aliasName: 'flashcards__id__srs_cards__flashcard_id',
  );

  $$SrsCardsTableProcessedTableManager get srsCardsRefs {
    final manager = $$SrsCardsTableTableManager(
      $_db,
      $_db.srsCards,
    ).filter((f) => f.flashcardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_srsCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FlashcardsTableFilterComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableFilterComposer({
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

  ColumnFilters<String> get wordCz => $composableBuilder(
    column: $table.wordCz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordEn => $composableBuilder(
    column: $table.wordEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseInfo => $composableBuilder(
    column: $table.caseInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioHash => $composableBuilder(
    column: $table.audioHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleCz => $composableBuilder(
    column: $table.exampleCz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleEn => $composableBuilder(
    column: $table.exampleEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lemma => $composableBuilder(
    column: $table.lemma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senseKey => $composableBuilder(
    column: $table.senseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get morphologyJson => $composableBuilder(
    column: $table.morphologyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registerLabel => $composableBuilder(
    column: $table.registerLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pronunciationSource => $composableBuilder(
    column: $table.pronunciationSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentUid => $composableBuilder(
    column: $table.contentUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$UnitsTableFilterComposer get unitId {
    final $$UnitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableFilterComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LessonsTableFilterComposer get lessonId {
    final $$LessonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableFilterComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> srsCardsRefs(
    Expression<bool> Function($$SrsCardsTableFilterComposer f) f,
  ) {
    final $$SrsCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.srsCards,
      getReferencedColumn: (t) => t.flashcardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SrsCardsTableFilterComposer(
            $db: $db,
            $table: $db.srsCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlashcardsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableOrderingComposer({
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

  ColumnOrderings<String> get wordCz => $composableBuilder(
    column: $table.wordCz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordEn => $composableBuilder(
    column: $table.wordEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseInfo => $composableBuilder(
    column: $table.caseInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioHash => $composableBuilder(
    column: $table.audioHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleCz => $composableBuilder(
    column: $table.exampleCz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleEn => $composableBuilder(
    column: $table.exampleEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lemma => $composableBuilder(
    column: $table.lemma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senseKey => $composableBuilder(
    column: $table.senseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get morphologyJson => $composableBuilder(
    column: $table.morphologyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registerLabel => $composableBuilder(
    column: $table.registerLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pronunciationSource => $composableBuilder(
    column: $table.pronunciationSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentUid => $composableBuilder(
    column: $table.contentUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$UnitsTableOrderingComposer get unitId {
    final $$UnitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableOrderingComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LessonsTableOrderingComposer get lessonId {
    final $$LessonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableOrderingComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wordCz =>
      $composableBuilder(column: $table.wordCz, builder: (column) => column);

  GeneratedColumn<String> get wordEn =>
      $composableBuilder(column: $table.wordEn, builder: (column) => column);

  GeneratedColumn<String> get ipa =>
      $composableBuilder(column: $table.ipa, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get caseInfo =>
      $composableBuilder(column: $table.caseInfo, builder: (column) => column);

  GeneratedColumn<String> get audioHash =>
      $composableBuilder(column: $table.audioHash, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get exampleCz =>
      $composableBuilder(column: $table.exampleCz, builder: (column) => column);

  GeneratedColumn<String> get exampleEn =>
      $composableBuilder(column: $table.exampleEn, builder: (column) => column);

  GeneratedColumn<String> get lemma =>
      $composableBuilder(column: $table.lemma, builder: (column) => column);

  GeneratedColumn<String> get senseKey =>
      $composableBuilder(column: $table.senseKey, builder: (column) => column);

  GeneratedColumn<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => column,
  );

  GeneratedColumn<String> get morphologyJson => $composableBuilder(
    column: $table.morphologyJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registerLabel => $composableBuilder(
    column: $table.registerLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pronunciationSource => $composableBuilder(
    column: $table.pronunciationSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentUid => $composableBuilder(
    column: $table.contentUid,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$UnitsTableAnnotationComposer get unitId {
    final $$UnitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableAnnotationComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LessonsTableAnnotationComposer get lessonId {
    final $$LessonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableAnnotationComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> srsCardsRefs<T extends Object>(
    Expression<T> Function($$SrsCardsTableAnnotationComposer a) f,
  ) {
    final $$SrsCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.srsCards,
      getReferencedColumn: (t) => t.flashcardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SrsCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.srsCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlashcardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlashcardsTable,
          Flashcard,
          $$FlashcardsTableFilterComposer,
          $$FlashcardsTableOrderingComposer,
          $$FlashcardsTableAnnotationComposer,
          $$FlashcardsTableCreateCompanionBuilder,
          $$FlashcardsTableUpdateCompanionBuilder,
          (Flashcard, $$FlashcardsTableReferences),
          Flashcard,
          PrefetchHooks Function({
            bool unitId,
            bool lessonId,
            bool srsCardsRefs,
          })
        > {
  $$FlashcardsTableTableManager(_$AppDatabase db, $FlashcardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$FlashcardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$FlashcardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$FlashcardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> wordCz = const Value.absent(),
                Value<String> wordEn = const Value.absent(),
                Value<String?> ipa = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<String?> caseInfo = const Value.absent(),
                Value<String?> audioHash = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> exampleCz = const Value.absent(),
                Value<String?> exampleEn = const Value.absent(),
                Value<String?> lemma = const Value.absent(),
                Value<String?> senseKey = const Value.absent(),
                Value<String?> partOfSpeech = const Value.absent(),
                Value<String?> morphologyJson = const Value.absent(),
                Value<String?> registerLabel = const Value.absent(),
                Value<String?> pronunciationSource = const Value.absent(),
                Value<String?> contentUid = const Value.absent(),
                Value<int?> unitId = const Value.absent(),
                Value<int?> lessonId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => FlashcardsCompanion(
                id: id,
                wordCz: wordCz,
                wordEn: wordEn,
                ipa: ipa,
                gender: gender,
                caseInfo: caseInfo,
                audioHash: audioHash,
                imagePath: imagePath,
                exampleCz: exampleCz,
                exampleEn: exampleEn,
                lemma: lemma,
                senseKey: senseKey,
                partOfSpeech: partOfSpeech,
                morphologyJson: morphologyJson,
                registerLabel: registerLabel,
                pronunciationSource: pronunciationSource,
                contentUid: contentUid,
                unitId: unitId,
                lessonId: lessonId,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String wordCz,
                required String wordEn,
                Value<String?> ipa = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<String?> caseInfo = const Value.absent(),
                Value<String?> audioHash = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> exampleCz = const Value.absent(),
                Value<String?> exampleEn = const Value.absent(),
                Value<String?> lemma = const Value.absent(),
                Value<String?> senseKey = const Value.absent(),
                Value<String?> partOfSpeech = const Value.absent(),
                Value<String?> morphologyJson = const Value.absent(),
                Value<String?> registerLabel = const Value.absent(),
                Value<String?> pronunciationSource = const Value.absent(),
                Value<String?> contentUid = const Value.absent(),
                Value<int?> unitId = const Value.absent(),
                Value<int?> lessonId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => FlashcardsCompanion.insert(
                id: id,
                wordCz: wordCz,
                wordEn: wordEn,
                ipa: ipa,
                gender: gender,
                caseInfo: caseInfo,
                audioHash: audioHash,
                imagePath: imagePath,
                exampleCz: exampleCz,
                exampleEn: exampleEn,
                lemma: lemma,
                senseKey: senseKey,
                partOfSpeech: partOfSpeech,
                morphologyJson: morphologyJson,
                registerLabel: registerLabel,
                pronunciationSource: pronunciationSource,
                contentUid: contentUid,
                unitId: unitId,
                lessonId: lessonId,
                isActive: isActive,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$FlashcardsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            unitId = false,
            lessonId = false,
            srsCardsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (srsCardsRefs) db.srsCards],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (unitId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.unitId,
                            referencedTable: $$FlashcardsTableReferences
                                ._unitIdTable(db),
                            referencedColumn:
                                $$FlashcardsTableReferences._unitIdTable(db).id,
                          )
                          as T;
                }
                if (lessonId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.lessonId,
                            referencedTable: $$FlashcardsTableReferences
                                ._lessonIdTable(db),
                            referencedColumn:
                                $$FlashcardsTableReferences
                                    ._lessonIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (srsCardsRefs)
                    await $_getPrefetchedData<
                      Flashcard,
                      $FlashcardsTable,
                      SrsCard
                    >(
                      currentTable: table,
                      referencedTable: $$FlashcardsTableReferences
                          ._srsCardsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$FlashcardsTableReferences(
                                db,
                                table,
                                p0,
                              ).srsCardsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.flashcardId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FlashcardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlashcardsTable,
      Flashcard,
      $$FlashcardsTableFilterComposer,
      $$FlashcardsTableOrderingComposer,
      $$FlashcardsTableAnnotationComposer,
      $$FlashcardsTableCreateCompanionBuilder,
      $$FlashcardsTableUpdateCompanionBuilder,
      (Flashcard, $$FlashcardsTableReferences),
      Flashcard,
      PrefetchHooks Function({bool unitId, bool lessonId, bool srsCardsRefs})
    >;
typedef $$SrsCardsTableCreateCompanionBuilder =
    SrsCardsCompanion Function({
      Value<int> id,
      required String cardType,
      Value<int?> flashcardId,
      Value<String?> grammarPatternKey,
      Value<double> stability,
      Value<double> difficulty,
      Value<DateTime> due,
      Value<int> reps,
      Value<String> state,
      Value<DateTime?> lastReviewed,
    });
typedef $$SrsCardsTableUpdateCompanionBuilder =
    SrsCardsCompanion Function({
      Value<int> id,
      Value<String> cardType,
      Value<int?> flashcardId,
      Value<String?> grammarPatternKey,
      Value<double> stability,
      Value<double> difficulty,
      Value<DateTime> due,
      Value<int> reps,
      Value<String> state,
      Value<DateTime?> lastReviewed,
    });

final class $$SrsCardsTableReferences
    extends BaseReferences<_$AppDatabase, $SrsCardsTable, SrsCard> {
  $$SrsCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FlashcardsTable _flashcardIdTable(_$AppDatabase db) =>
      db.flashcards.createAlias('srs_cards__flashcard_id__flashcards__id');

  $$FlashcardsTableProcessedTableManager? get flashcardId {
    final $_column = $_itemColumn<int>('flashcard_id');
    if ($_column == null) return null;
    final manager = $$FlashcardsTableTableManager(
      $_db,
      $_db.flashcards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_flashcardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SrsCardsTableFilterComposer
    extends Composer<_$AppDatabase, $SrsCardsTable> {
  $$SrsCardsTableFilterComposer({
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

  ColumnFilters<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grammarPatternKey => $composableBuilder(
    column: $table.grammarPatternKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewed => $composableBuilder(
    column: $table.lastReviewed,
    builder: (column) => ColumnFilters(column),
  );

  $$FlashcardsTableFilterComposer get flashcardId {
    final $$FlashcardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.flashcardId,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableFilterComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SrsCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $SrsCardsTable> {
  $$SrsCardsTableOrderingComposer({
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

  ColumnOrderings<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grammarPatternKey => $composableBuilder(
    column: $table.grammarPatternKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewed => $composableBuilder(
    column: $table.lastReviewed,
    builder: (column) => ColumnOrderings(column),
  );

  $$FlashcardsTableOrderingComposer get flashcardId {
    final $$FlashcardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.flashcardId,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableOrderingComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SrsCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SrsCardsTable> {
  $$SrsCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cardType =>
      $composableBuilder(column: $table.cardType, builder: (column) => column);

  GeneratedColumn<String> get grammarPatternKey => $composableBuilder(
    column: $table.grammarPatternKey,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewed => $composableBuilder(
    column: $table.lastReviewed,
    builder: (column) => column,
  );

  $$FlashcardsTableAnnotationComposer get flashcardId {
    final $$FlashcardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.flashcardId,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SrsCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SrsCardsTable,
          SrsCard,
          $$SrsCardsTableFilterComposer,
          $$SrsCardsTableOrderingComposer,
          $$SrsCardsTableAnnotationComposer,
          $$SrsCardsTableCreateCompanionBuilder,
          $$SrsCardsTableUpdateCompanionBuilder,
          (SrsCard, $$SrsCardsTableReferences),
          SrsCard,
          PrefetchHooks Function({bool flashcardId})
        > {
  $$SrsCardsTableTableManager(_$AppDatabase db, $SrsCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SrsCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SrsCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SrsCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cardType = const Value.absent(),
                Value<int?> flashcardId = const Value.absent(),
                Value<String?> grammarPatternKey = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<DateTime> due = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime?> lastReviewed = const Value.absent(),
              }) => SrsCardsCompanion(
                id: id,
                cardType: cardType,
                flashcardId: flashcardId,
                grammarPatternKey: grammarPatternKey,
                stability: stability,
                difficulty: difficulty,
                due: due,
                reps: reps,
                state: state,
                lastReviewed: lastReviewed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String cardType,
                Value<int?> flashcardId = const Value.absent(),
                Value<String?> grammarPatternKey = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<DateTime> due = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime?> lastReviewed = const Value.absent(),
              }) => SrsCardsCompanion.insert(
                id: id,
                cardType: cardType,
                flashcardId: flashcardId,
                grammarPatternKey: grammarPatternKey,
                stability: stability,
                difficulty: difficulty,
                due: due,
                reps: reps,
                state: state,
                lastReviewed: lastReviewed,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$SrsCardsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({flashcardId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (flashcardId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.flashcardId,
                            referencedTable: $$SrsCardsTableReferences
                                ._flashcardIdTable(db),
                            referencedColumn:
                                $$SrsCardsTableReferences
                                    ._flashcardIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SrsCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SrsCardsTable,
      SrsCard,
      $$SrsCardsTableFilterComposer,
      $$SrsCardsTableOrderingComposer,
      $$SrsCardsTableAnnotationComposer,
      $$SrsCardsTableCreateCompanionBuilder,
      $$SrsCardsTableUpdateCompanionBuilder,
      (SrsCard, $$SrsCardsTableReferences),
      SrsCard,
      PrefetchHooks Function({bool flashcardId})
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      required String scenario,
      required String cefrLevel,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> scenario,
      Value<String> cefrLevel,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ConversationsTableReferences
    extends BaseReferences<_$AppDatabase, $ConversationsTable, Conversation> {
  $$ConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ChatMessagesTable, List<ChatMessage>>
  _chatMessagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chatMessages,
    aliasName: 'conversations__id__chat_messages__conversation_id',
  );

  $$ChatMessagesTableProcessedTableManager get chatMessagesRefs {
    final manager = $$ChatMessagesTableTableManager(
      $_db,
      $_db.chatMessages,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chatMessagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
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

  ColumnFilters<String> get scenario => $composableBuilder(
    column: $table.scenario,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cefrLevel => $composableBuilder(
    column: $table.cefrLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> chatMessagesRefs(
    Expression<bool> Function($$ChatMessagesTableFilterComposer f) f,
  ) {
    final $$ChatMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatMessagesTableFilterComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
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

  ColumnOrderings<String> get scenario => $composableBuilder(
    column: $table.scenario,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cefrLevel => $composableBuilder(
    column: $table.cefrLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scenario =>
      $composableBuilder(column: $table.scenario, builder: (column) => column);

  GeneratedColumn<String> get cefrLevel =>
      $composableBuilder(column: $table.cefrLevel, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> chatMessagesRefs<T extends Object>(
    Expression<T> Function($$ChatMessagesTableAnnotationComposer a) f,
  ) {
    final $$ChatMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (Conversation, $$ConversationsTableReferences),
          Conversation,
          PrefetchHooks Function({bool chatMessagesRefs})
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scenario = const Value.absent(),
                Value<String> cefrLevel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                scenario: scenario,
                cefrLevel: cefrLevel,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scenario,
                required String cefrLevel,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                scenario: scenario,
                cefrLevel: cefrLevel,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ConversationsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({chatMessagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (chatMessagesRefs) db.chatMessages],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (chatMessagesRefs)
                    await $_getPrefetchedData<
                      Conversation,
                      $ConversationsTable,
                      ChatMessage
                    >(
                      currentTable: table,
                      referencedTable: $$ConversationsTableReferences
                          ._chatMessagesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).chatMessagesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.conversationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (Conversation, $$ConversationsTableReferences),
      Conversation,
      PrefetchHooks Function({bool chatMessagesRefs})
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<int> id,
      required String conversationId,
      required String role,
      required String content,
      Value<String?> translation,
      Value<String?> corrections,
      Value<String?> newVocabulary,
      Value<String?> audioPath,
      Value<DateTime> createdAt,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<int> id,
      Value<String> conversationId,
      Value<String> role,
      Value<String> content,
      Value<String?> translation,
      Value<String?> corrections,
      Value<String?> newVocabulary,
      Value<String?> audioPath,
      Value<DateTime> createdAt,
    });

final class $$ChatMessagesTableReferences
    extends BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage> {
  $$ChatMessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('chat_messages__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
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

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get corrections => $composableBuilder(
    column: $table.corrections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newVocabulary => $composableBuilder(
    column: $table.newVocabulary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get corrections => $composableBuilder(
    column: $table.corrections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newVocabulary => $composableBuilder(
    column: $table.newVocabulary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get corrections => $composableBuilder(
    column: $table.corrections,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newVocabulary => $composableBuilder(
    column: $table.newVocabulary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (ChatMessage, $$ChatMessagesTableReferences),
          ChatMessage,
          PrefetchHooks Function({bool conversationId})
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<String?> corrections = const Value.absent(),
                Value<String?> newVocabulary = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                translation: translation,
                corrections: corrections,
                newVocabulary: newVocabulary,
                audioPath: audioPath,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String conversationId,
                required String role,
                required String content,
                Value<String?> translation = const Value.absent(),
                Value<String?> corrections = const Value.absent(),
                Value<String?> newVocabulary = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                translation: translation,
                corrections: corrections,
                newVocabulary: newVocabulary,
                audioPath: audioPath,
                createdAt: createdAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ChatMessagesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (conversationId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.conversationId,
                            referencedTable: $$ChatMessagesTableReferences
                                ._conversationIdTable(db),
                            referencedColumn:
                                $$ChatMessagesTableReferences
                                    ._conversationIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (ChatMessage, $$ChatMessagesTableReferences),
      ChatMessage,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$GrammarRulesTableCreateCompanionBuilder =
    GrammarRulesCompanion Function({
      required String id,
      required String ruleName,
      required String pattern,
      required String explanation,
      Value<String?> caseAffected,
      Value<String> examples,
      Value<int?> unitId,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$GrammarRulesTableUpdateCompanionBuilder =
    GrammarRulesCompanion Function({
      Value<String> id,
      Value<String> ruleName,
      Value<String> pattern,
      Value<String> explanation,
      Value<String?> caseAffected,
      Value<String> examples,
      Value<int?> unitId,
      Value<bool> isActive,
      Value<int> rowid,
    });

final class $$GrammarRulesTableReferences
    extends BaseReferences<_$AppDatabase, $GrammarRulesTable, GrammarRule> {
  $$GrammarRulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UnitsTable _unitIdTable(_$AppDatabase db) =>
      db.units.createAlias('grammar_rules__unit_id__units__id');

  $$UnitsTableProcessedTableManager? get unitId {
    final $_column = $_itemColumn<int>('unit_id');
    if ($_column == null) return null;
    final manager = $$UnitsTableTableManager(
      $_db,
      $_db.units,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_unitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GrammarRulesTableFilterComposer
    extends Composer<_$AppDatabase, $GrammarRulesTable> {
  $$GrammarRulesTableFilterComposer({
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

  ColumnFilters<String> get ruleName => $composableBuilder(
    column: $table.ruleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseAffected => $composableBuilder(
    column: $table.caseAffected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examples => $composableBuilder(
    column: $table.examples,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$UnitsTableFilterComposer get unitId {
    final $$UnitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableFilterComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GrammarRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $GrammarRulesTable> {
  $$GrammarRulesTableOrderingComposer({
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

  ColumnOrderings<String> get ruleName => $composableBuilder(
    column: $table.ruleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseAffected => $composableBuilder(
    column: $table.caseAffected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examples => $composableBuilder(
    column: $table.examples,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$UnitsTableOrderingComposer get unitId {
    final $$UnitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableOrderingComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GrammarRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GrammarRulesTable> {
  $$GrammarRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ruleName =>
      $composableBuilder(column: $table.ruleName, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caseAffected => $composableBuilder(
    column: $table.caseAffected,
    builder: (column) => column,
  );

  GeneratedColumn<String> get examples =>
      $composableBuilder(column: $table.examples, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$UnitsTableAnnotationComposer get unitId {
    final $$UnitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitId,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableAnnotationComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GrammarRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GrammarRulesTable,
          GrammarRule,
          $$GrammarRulesTableFilterComposer,
          $$GrammarRulesTableOrderingComposer,
          $$GrammarRulesTableAnnotationComposer,
          $$GrammarRulesTableCreateCompanionBuilder,
          $$GrammarRulesTableUpdateCompanionBuilder,
          (GrammarRule, $$GrammarRulesTableReferences),
          GrammarRule,
          PrefetchHooks Function({bool unitId})
        > {
  $$GrammarRulesTableTableManager(_$AppDatabase db, $GrammarRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$GrammarRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$GrammarRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$GrammarRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ruleName = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<String?> caseAffected = const Value.absent(),
                Value<String> examples = const Value.absent(),
                Value<int?> unitId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GrammarRulesCompanion(
                id: id,
                ruleName: ruleName,
                pattern: pattern,
                explanation: explanation,
                caseAffected: caseAffected,
                examples: examples,
                unitId: unitId,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ruleName,
                required String pattern,
                required String explanation,
                Value<String?> caseAffected = const Value.absent(),
                Value<String> examples = const Value.absent(),
                Value<int?> unitId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GrammarRulesCompanion.insert(
                id: id,
                ruleName: ruleName,
                pattern: pattern,
                explanation: explanation,
                caseAffected: caseAffected,
                examples: examples,
                unitId: unitId,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$GrammarRulesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({unitId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (unitId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.unitId,
                            referencedTable: $$GrammarRulesTableReferences
                                ._unitIdTable(db),
                            referencedColumn:
                                $$GrammarRulesTableReferences
                                    ._unitIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GrammarRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GrammarRulesTable,
      GrammarRule,
      $$GrammarRulesTableFilterComposer,
      $$GrammarRulesTableOrderingComposer,
      $$GrammarRulesTableAnnotationComposer,
      $$GrammarRulesTableCreateCompanionBuilder,
      $$GrammarRulesTableUpdateCompanionBuilder,
      (GrammarRule, $$GrammarRulesTableReferences),
      GrammarRule,
      PrefetchHooks Function({bool unitId})
    >;
typedef $$ExamResultsTableCreateCompanionBuilder =
    ExamResultsCompanion Function({
      Value<int> id,
      required String level,
      Value<String> product,
      Value<DateTime> takenAt,
      Value<int> readingScore,
      Value<int> listeningScore,
      Value<int> writingScore,
      Value<int> speakingScore,
      Value<int> totalScore,
      Value<bool> passed,
      Value<String?> details,
    });
typedef $$ExamResultsTableUpdateCompanionBuilder =
    ExamResultsCompanion Function({
      Value<int> id,
      Value<String> level,
      Value<String> product,
      Value<DateTime> takenAt,
      Value<int> readingScore,
      Value<int> listeningScore,
      Value<int> writingScore,
      Value<int> speakingScore,
      Value<int> totalScore,
      Value<bool> passed,
      Value<String?> details,
    });

class $$ExamResultsTableFilterComposer
    extends Composer<_$AppDatabase, $ExamResultsTable> {
  $$ExamResultsTableFilterComposer({
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

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingScore => $composableBuilder(
    column: $table.readingScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listeningScore => $composableBuilder(
    column: $table.listeningScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get writingScore => $composableBuilder(
    column: $table.writingScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get speakingScore => $composableBuilder(
    column: $table.speakingScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalScore => $composableBuilder(
    column: $table.totalScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExamResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExamResultsTable> {
  $$ExamResultsTableOrderingComposer({
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

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingScore => $composableBuilder(
    column: $table.readingScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listeningScore => $composableBuilder(
    column: $table.listeningScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get writingScore => $composableBuilder(
    column: $table.writingScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get speakingScore => $composableBuilder(
    column: $table.speakingScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalScore => $composableBuilder(
    column: $table.totalScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExamResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExamResultsTable> {
  $$ExamResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get product =>
      $composableBuilder(column: $table.product, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<int> get readingScore => $composableBuilder(
    column: $table.readingScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get listeningScore => $composableBuilder(
    column: $table.listeningScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get writingScore => $composableBuilder(
    column: $table.writingScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get speakingScore => $composableBuilder(
    column: $table.speakingScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalScore => $composableBuilder(
    column: $table.totalScore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get passed =>
      $composableBuilder(column: $table.passed, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);
}

class $$ExamResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExamResultsTable,
          ExamResult,
          $$ExamResultsTableFilterComposer,
          $$ExamResultsTableOrderingComposer,
          $$ExamResultsTableAnnotationComposer,
          $$ExamResultsTableCreateCompanionBuilder,
          $$ExamResultsTableUpdateCompanionBuilder,
          (
            ExamResult,
            BaseReferences<_$AppDatabase, $ExamResultsTable, ExamResult>,
          ),
          ExamResult,
          PrefetchHooks Function()
        > {
  $$ExamResultsTableTableManager(_$AppDatabase db, $ExamResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ExamResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ExamResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$ExamResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> product = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
                Value<int> readingScore = const Value.absent(),
                Value<int> listeningScore = const Value.absent(),
                Value<int> writingScore = const Value.absent(),
                Value<int> speakingScore = const Value.absent(),
                Value<int> totalScore = const Value.absent(),
                Value<bool> passed = const Value.absent(),
                Value<String?> details = const Value.absent(),
              }) => ExamResultsCompanion(
                id: id,
                level: level,
                product: product,
                takenAt: takenAt,
                readingScore: readingScore,
                listeningScore: listeningScore,
                writingScore: writingScore,
                speakingScore: speakingScore,
                totalScore: totalScore,
                passed: passed,
                details: details,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String level,
                Value<String> product = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
                Value<int> readingScore = const Value.absent(),
                Value<int> listeningScore = const Value.absent(),
                Value<int> writingScore = const Value.absent(),
                Value<int> speakingScore = const Value.absent(),
                Value<int> totalScore = const Value.absent(),
                Value<bool> passed = const Value.absent(),
                Value<String?> details = const Value.absent(),
              }) => ExamResultsCompanion.insert(
                id: id,
                level: level,
                product: product,
                takenAt: takenAt,
                readingScore: readingScore,
                listeningScore: listeningScore,
                writingScore: writingScore,
                speakingScore: speakingScore,
                totalScore: totalScore,
                passed: passed,
                details: details,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExamResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExamResultsTable,
      ExamResult,
      $$ExamResultsTableFilterComposer,
      $$ExamResultsTableOrderingComposer,
      $$ExamResultsTableAnnotationComposer,
      $$ExamResultsTableCreateCompanionBuilder,
      $$ExamResultsTableUpdateCompanionBuilder,
      (
        ExamResult,
        BaseReferences<_$AppDatabase, $ExamResultsTable, ExamResult>,
      ),
      ExamResult,
      PrefetchHooks Function()
    >;
typedef $$UserProgressTableCreateCompanionBuilder =
    UserProgressCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$UserProgressTableUpdateCompanionBuilder =
    UserProgressCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserProgressTableFilterComposer
    extends Composer<_$AppDatabase, $UserProgressTable> {
  $$UserProgressTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProgressTable> {
  $$UserProgressTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProgressTable> {
  $$UserProgressTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProgressTable,
          UserProgressData,
          $$UserProgressTableFilterComposer,
          $$UserProgressTableOrderingComposer,
          $$UserProgressTableAnnotationComposer,
          $$UserProgressTableCreateCompanionBuilder,
          $$UserProgressTableUpdateCompanionBuilder,
          (
            UserProgressData,
            BaseReferences<_$AppDatabase, $UserProgressTable, UserProgressData>,
          ),
          UserProgressData,
          PrefetchHooks Function()
        > {
  $$UserProgressTableTableManager(_$AppDatabase db, $UserProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UserProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$UserProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$UserProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProgressCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProgressCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProgressTable,
      UserProgressData,
      $$UserProgressTableFilterComposer,
      $$UserProgressTableOrderingComposer,
      $$UserProgressTableAnnotationComposer,
      $$UserProgressTableCreateCompanionBuilder,
      $$UserProgressTableUpdateCompanionBuilder,
      (
        UserProgressData,
        BaseReferences<_$AppDatabase, $UserProgressTable, UserProgressData>,
      ),
      UserProgressData,
      PrefetchHooks Function()
    >;
typedef $$EarnedBadgesTableCreateCompanionBuilder =
    EarnedBadgesCompanion Function({
      required String badgeId,
      Value<DateTime> earnedAt,
      Value<int> rowid,
    });
typedef $$EarnedBadgesTableUpdateCompanionBuilder =
    EarnedBadgesCompanion Function({
      Value<String> badgeId,
      Value<DateTime> earnedAt,
      Value<int> rowid,
    });

class $$EarnedBadgesTableFilterComposer
    extends Composer<_$AppDatabase, $EarnedBadgesTable> {
  $$EarnedBadgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get badgeId => $composableBuilder(
    column: $table.badgeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EarnedBadgesTableOrderingComposer
    extends Composer<_$AppDatabase, $EarnedBadgesTable> {
  $$EarnedBadgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get badgeId => $composableBuilder(
    column: $table.badgeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EarnedBadgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EarnedBadgesTable> {
  $$EarnedBadgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get badgeId =>
      $composableBuilder(column: $table.badgeId, builder: (column) => column);

  GeneratedColumn<DateTime> get earnedAt =>
      $composableBuilder(column: $table.earnedAt, builder: (column) => column);
}

class $$EarnedBadgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EarnedBadgesTable,
          EarnedBadge,
          $$EarnedBadgesTableFilterComposer,
          $$EarnedBadgesTableOrderingComposer,
          $$EarnedBadgesTableAnnotationComposer,
          $$EarnedBadgesTableCreateCompanionBuilder,
          $$EarnedBadgesTableUpdateCompanionBuilder,
          (
            EarnedBadge,
            BaseReferences<_$AppDatabase, $EarnedBadgesTable, EarnedBadge>,
          ),
          EarnedBadge,
          PrefetchHooks Function()
        > {
  $$EarnedBadgesTableTableManager(_$AppDatabase db, $EarnedBadgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$EarnedBadgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$EarnedBadgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$EarnedBadgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> badgeId = const Value.absent(),
                Value<DateTime> earnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EarnedBadgesCompanion(
                badgeId: badgeId,
                earnedAt: earnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String badgeId,
                Value<DateTime> earnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EarnedBadgesCompanion.insert(
                badgeId: badgeId,
                earnedAt: earnedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EarnedBadgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EarnedBadgesTable,
      EarnedBadge,
      $$EarnedBadgesTableFilterComposer,
      $$EarnedBadgesTableOrderingComposer,
      $$EarnedBadgesTableAnnotationComposer,
      $$EarnedBadgesTableCreateCompanionBuilder,
      $$EarnedBadgesTableUpdateCompanionBuilder,
      (
        EarnedBadge,
        BaseReferences<_$AppDatabase, $EarnedBadgesTable, EarnedBadge>,
      ),
      EarnedBadge,
      PrefetchHooks Function()
    >;
typedef $$ConsentRecordsTableCreateCompanionBuilder =
    ConsentRecordsCompanion Function({
      Value<int> id,
      required String purpose,
      required String noticeVersion,
      required String policyVersion,
      required bool granted,
      required String decidedAt,
      Value<String> appVersion,
      Value<String> platform,
      Value<bool> synced,
    });
typedef $$ConsentRecordsTableUpdateCompanionBuilder =
    ConsentRecordsCompanion Function({
      Value<int> id,
      Value<String> purpose,
      Value<String> noticeVersion,
      Value<String> policyVersion,
      Value<bool> granted,
      Value<String> decidedAt,
      Value<String> appVersion,
      Value<String> platform,
      Value<bool> synced,
    });

class $$ConsentRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ConsentRecordsTable> {
  $$ConsentRecordsTableFilterComposer({
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

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noticeVersion => $composableBuilder(
    column: $table.noticeVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get granted => $composableBuilder(
    column: $table.granted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConsentRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConsentRecordsTable> {
  $$ConsentRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noticeVersion => $composableBuilder(
    column: $table.noticeVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get granted => $composableBuilder(
    column: $table.granted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConsentRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConsentRecordsTable> {
  $$ConsentRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get noticeVersion => $composableBuilder(
    column: $table.noticeVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get granted =>
      $composableBuilder(column: $table.granted, builder: (column) => column);

  GeneratedColumn<String> get decidedAt =>
      $composableBuilder(column: $table.decidedAt, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$ConsentRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConsentRecordsTable,
          ConsentRecord,
          $$ConsentRecordsTableFilterComposer,
          $$ConsentRecordsTableOrderingComposer,
          $$ConsentRecordsTableAnnotationComposer,
          $$ConsentRecordsTableCreateCompanionBuilder,
          $$ConsentRecordsTableUpdateCompanionBuilder,
          (
            ConsentRecord,
            BaseReferences<_$AppDatabase, $ConsentRecordsTable, ConsentRecord>,
          ),
          ConsentRecord,
          PrefetchHooks Function()
        > {
  $$ConsentRecordsTableTableManager(
    _$AppDatabase db,
    $ConsentRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ConsentRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ConsentRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ConsentRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<String> noticeVersion = const Value.absent(),
                Value<String> policyVersion = const Value.absent(),
                Value<bool> granted = const Value.absent(),
                Value<String> decidedAt = const Value.absent(),
                Value<String> appVersion = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => ConsentRecordsCompanion(
                id: id,
                purpose: purpose,
                noticeVersion: noticeVersion,
                policyVersion: policyVersion,
                granted: granted,
                decidedAt: decidedAt,
                appVersion: appVersion,
                platform: platform,
                synced: synced,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String purpose,
                required String noticeVersion,
                required String policyVersion,
                required bool granted,
                required String decidedAt,
                Value<String> appVersion = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => ConsentRecordsCompanion.insert(
                id: id,
                purpose: purpose,
                noticeVersion: noticeVersion,
                policyVersion: policyVersion,
                granted: granted,
                decidedAt: decidedAt,
                appVersion: appVersion,
                platform: platform,
                synced: synced,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConsentRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConsentRecordsTable,
      ConsentRecord,
      $$ConsentRecordsTableFilterComposer,
      $$ConsentRecordsTableOrderingComposer,
      $$ConsentRecordsTableAnnotationComposer,
      $$ConsentRecordsTableCreateCompanionBuilder,
      $$ConsentRecordsTableUpdateCompanionBuilder,
      (
        ConsentRecord,
        BaseReferences<_$AppDatabase, $ConsentRecordsTable, ConsentRecord>,
      ),
      ConsentRecord,
      PrefetchHooks Function()
    >;
typedef $$LessonProgressTableCreateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<int> lessonId,
      required int unitId,
      Value<bool> isCompleted,
      Value<double> bestScore,
      Value<int> attempts,
      Value<DateTime?> lastAttempted,
    });
typedef $$LessonProgressTableUpdateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<int> lessonId,
      Value<int> unitId,
      Value<bool> isCompleted,
      Value<double> bestScore,
      Value<int> attempts,
      Value<DateTime?> lastAttempted,
    });

class $$LessonProgressTableFilterComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttempted => $composableBuilder(
    column: $table.lastAttempted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttempted => $composableBuilder(
    column: $table.lastAttempted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get unitId =>
      $composableBuilder(column: $table.unitId, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bestScore =>
      $composableBuilder(column: $table.bestScore, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttempted => $composableBuilder(
    column: $table.lastAttempted,
    builder: (column) => column,
  );
}

class $$LessonProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonProgressTable,
          LessonProgressData,
          $$LessonProgressTableFilterComposer,
          $$LessonProgressTableOrderingComposer,
          $$LessonProgressTableAnnotationComposer,
          $$LessonProgressTableCreateCompanionBuilder,
          $$LessonProgressTableUpdateCompanionBuilder,
          (
            LessonProgressData,
            BaseReferences<
              _$AppDatabase,
              $LessonProgressTable,
              LessonProgressData
            >,
          ),
          LessonProgressData,
          PrefetchHooks Function()
        > {
  $$LessonProgressTableTableManager(
    _$AppDatabase db,
    $LessonProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$LessonProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$LessonProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$LessonProgressTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> lessonId = const Value.absent(),
                Value<int> unitId = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<double> bestScore = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttempted = const Value.absent(),
              }) => LessonProgressCompanion(
                lessonId: lessonId,
                unitId: unitId,
                isCompleted: isCompleted,
                bestScore: bestScore,
                attempts: attempts,
                lastAttempted: lastAttempted,
              ),
          createCompanionCallback:
              ({
                Value<int> lessonId = const Value.absent(),
                required int unitId,
                Value<bool> isCompleted = const Value.absent(),
                Value<double> bestScore = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttempted = const Value.absent(),
              }) => LessonProgressCompanion.insert(
                lessonId: lessonId,
                unitId: unitId,
                isCompleted: isCompleted,
                bestScore: bestScore,
                attempts: attempts,
                lastAttempted: lastAttempted,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonProgressTable,
      LessonProgressData,
      $$LessonProgressTableFilterComposer,
      $$LessonProgressTableOrderingComposer,
      $$LessonProgressTableAnnotationComposer,
      $$LessonProgressTableCreateCompanionBuilder,
      $$LessonProgressTableUpdateCompanionBuilder,
      (
        LessonProgressData,
        BaseReferences<_$AppDatabase, $LessonProgressTable, LessonProgressData>,
      ),
      LessonProgressData,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String entity,
      required String entityKey,
      Value<String> op,
      required String payload,
      required String deviceId,
      Value<DateTime> updatedAt,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime?> deadLetteredAt,
      Value<String?> lastError,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> entity,
      Value<String> entityKey,
      Value<String> op,
      Value<String> payload,
      Value<String> deviceId,
      Value<DateTime> updatedAt,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime?> deadLetteredAt,
      Value<String?> lastError,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadLetteredAt => $composableBuilder(
    column: $table.deadLetteredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadLetteredAt => $composableBuilder(
    column: $table.deadLetteredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityKey =>
      $composableBuilder(column: $table.entityKey, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deadLetteredAt => $composableBuilder(
    column: $table.deadLetteredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityKey = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> deadLetteredAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entity: entity,
                entityKey: entityKey,
                op: op,
                payload: payload,
                deviceId: deviceId,
                updatedAt: updatedAt,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                deadLetteredAt: deadLetteredAt,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entity,
                required String entityKey,
                Value<String> op = const Value.absent(),
                required String payload,
                required String deviceId,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> deadLetteredAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entity: entity,
                entityKey: entityKey,
                op: op,
                payload: payload,
                deviceId: deviceId,
                updatedAt: updatedAt,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                deadLetteredAt: deadLetteredAt,
                lastError: lastError,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
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
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
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
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
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
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$GamificationStateTableTableCreateCompanionBuilder =
    GamificationStateTableCompanion Function({
      required String key,
      Value<int> hearts,
      Value<int> maxHearts,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<int> totalXp,
      Value<int> dailyXp,
      Value<int> dailyGoalXp,
      Value<int> gems,
      Value<String> earnedBadges,
      Value<DateTime?> lastHeartRefill,
      Value<bool> streakFreezeAvailable,
      Value<String?> lastOpenDate,
      Value<String?> dailyXpResetDate,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$GamificationStateTableTableUpdateCompanionBuilder =
    GamificationStateTableCompanion Function({
      Value<String> key,
      Value<int> hearts,
      Value<int> maxHearts,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<int> totalXp,
      Value<int> dailyXp,
      Value<int> dailyGoalXp,
      Value<int> gems,
      Value<String> earnedBadges,
      Value<DateTime?> lastHeartRefill,
      Value<bool> streakFreezeAvailable,
      Value<String?> lastOpenDate,
      Value<String?> dailyXpResetDate,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$GamificationStateTableTableFilterComposer
    extends Composer<_$AppDatabase, $GamificationStateTableTable> {
  $$GamificationStateTableTableFilterComposer({
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

  ColumnFilters<int> get hearts => $composableBuilder(
    column: $table.hearts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxHearts => $composableBuilder(
    column: $table.maxHearts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalXp => $composableBuilder(
    column: $table.totalXp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyXp => $composableBuilder(
    column: $table.dailyXp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyGoalXp => $composableBuilder(
    column: $table.dailyGoalXp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gems => $composableBuilder(
    column: $table.gems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get earnedBadges => $composableBuilder(
    column: $table.earnedBadges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastHeartRefill => $composableBuilder(
    column: $table.lastHeartRefill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get streakFreezeAvailable => $composableBuilder(
    column: $table.streakFreezeAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastOpenDate => $composableBuilder(
    column: $table.lastOpenDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dailyXpResetDate => $composableBuilder(
    column: $table.dailyXpResetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GamificationStateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GamificationStateTableTable> {
  $$GamificationStateTableTableOrderingComposer({
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

  ColumnOrderings<int> get hearts => $composableBuilder(
    column: $table.hearts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxHearts => $composableBuilder(
    column: $table.maxHearts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalXp => $composableBuilder(
    column: $table.totalXp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyXp => $composableBuilder(
    column: $table.dailyXp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyGoalXp => $composableBuilder(
    column: $table.dailyGoalXp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gems => $composableBuilder(
    column: $table.gems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get earnedBadges => $composableBuilder(
    column: $table.earnedBadges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastHeartRefill => $composableBuilder(
    column: $table.lastHeartRefill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get streakFreezeAvailable => $composableBuilder(
    column: $table.streakFreezeAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastOpenDate => $composableBuilder(
    column: $table.lastOpenDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dailyXpResetDate => $composableBuilder(
    column: $table.dailyXpResetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamificationStateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamificationStateTableTable> {
  $$GamificationStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get hearts =>
      $composableBuilder(column: $table.hearts, builder: (column) => column);

  GeneratedColumn<int> get maxHearts =>
      $composableBuilder(column: $table.maxHearts, builder: (column) => column);

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalXp =>
      $composableBuilder(column: $table.totalXp, builder: (column) => column);

  GeneratedColumn<int> get dailyXp =>
      $composableBuilder(column: $table.dailyXp, builder: (column) => column);

  GeneratedColumn<int> get dailyGoalXp => $composableBuilder(
    column: $table.dailyGoalXp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gems =>
      $composableBuilder(column: $table.gems, builder: (column) => column);

  GeneratedColumn<String> get earnedBadges => $composableBuilder(
    column: $table.earnedBadges,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastHeartRefill => $composableBuilder(
    column: $table.lastHeartRefill,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get streakFreezeAvailable => $composableBuilder(
    column: $table.streakFreezeAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastOpenDate => $composableBuilder(
    column: $table.lastOpenDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dailyXpResetDate => $composableBuilder(
    column: $table.dailyXpResetDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GamificationStateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamificationStateTableTable,
          GamificationStateTableData,
          $$GamificationStateTableTableFilterComposer,
          $$GamificationStateTableTableOrderingComposer,
          $$GamificationStateTableTableAnnotationComposer,
          $$GamificationStateTableTableCreateCompanionBuilder,
          $$GamificationStateTableTableUpdateCompanionBuilder,
          (
            GamificationStateTableData,
            BaseReferences<
              _$AppDatabase,
              $GamificationStateTableTable,
              GamificationStateTableData
            >,
          ),
          GamificationStateTableData,
          PrefetchHooks Function()
        > {
  $$GamificationStateTableTableTableManager(
    _$AppDatabase db,
    $GamificationStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$GamificationStateTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$GamificationStateTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$GamificationStateTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> hearts = const Value.absent(),
                Value<int> maxHearts = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<int> totalXp = const Value.absent(),
                Value<int> dailyXp = const Value.absent(),
                Value<int> dailyGoalXp = const Value.absent(),
                Value<int> gems = const Value.absent(),
                Value<String> earnedBadges = const Value.absent(),
                Value<DateTime?> lastHeartRefill = const Value.absent(),
                Value<bool> streakFreezeAvailable = const Value.absent(),
                Value<String?> lastOpenDate = const Value.absent(),
                Value<String?> dailyXpResetDate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamificationStateTableCompanion(
                key: key,
                hearts: hearts,
                maxHearts: maxHearts,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                totalXp: totalXp,
                dailyXp: dailyXp,
                dailyGoalXp: dailyGoalXp,
                gems: gems,
                earnedBadges: earnedBadges,
                lastHeartRefill: lastHeartRefill,
                streakFreezeAvailable: streakFreezeAvailable,
                lastOpenDate: lastOpenDate,
                dailyXpResetDate: dailyXpResetDate,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<int> hearts = const Value.absent(),
                Value<int> maxHearts = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<int> totalXp = const Value.absent(),
                Value<int> dailyXp = const Value.absent(),
                Value<int> dailyGoalXp = const Value.absent(),
                Value<int> gems = const Value.absent(),
                Value<String> earnedBadges = const Value.absent(),
                Value<DateTime?> lastHeartRefill = const Value.absent(),
                Value<bool> streakFreezeAvailable = const Value.absent(),
                Value<String?> lastOpenDate = const Value.absent(),
                Value<String?> dailyXpResetDate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamificationStateTableCompanion.insert(
                key: key,
                hearts: hearts,
                maxHearts: maxHearts,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                totalXp: totalXp,
                dailyXp: dailyXp,
                dailyGoalXp: dailyGoalXp,
                gems: gems,
                earnedBadges: earnedBadges,
                lastHeartRefill: lastHeartRefill,
                streakFreezeAvailable: streakFreezeAvailable,
                lastOpenDate: lastOpenDate,
                dailyXpResetDate: dailyXpResetDate,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GamificationStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamificationStateTableTable,
      GamificationStateTableData,
      $$GamificationStateTableTableFilterComposer,
      $$GamificationStateTableTableOrderingComposer,
      $$GamificationStateTableTableAnnotationComposer,
      $$GamificationStateTableTableCreateCompanionBuilder,
      $$GamificationStateTableTableUpdateCompanionBuilder,
      (
        GamificationStateTableData,
        BaseReferences<
          _$AppDatabase,
          $GamificationStateTableTable,
          GamificationStateTableData
        >,
      ),
      GamificationStateTableData,
      PrefetchHooks Function()
    >;
typedef $$LessonAttemptsTableCreateCompanionBuilder =
    LessonAttemptsCompanion Function({
      required String attemptId,
      required int lessonId,
      required int unitId,
      required String phase,
      required double score,
      required int correctCount,
      required int incorrectCount,
      required int skippedCount,
      required DateTime startedAt,
      required DateTime committedAt,
      Value<int> rowid,
    });
typedef $$LessonAttemptsTableUpdateCompanionBuilder =
    LessonAttemptsCompanion Function({
      Value<String> attemptId,
      Value<int> lessonId,
      Value<int> unitId,
      Value<String> phase,
      Value<double> score,
      Value<int> correctCount,
      Value<int> incorrectCount,
      Value<int> skippedCount,
      Value<DateTime> startedAt,
      Value<DateTime> committedAt,
      Value<int> rowid,
    });

class $$LessonAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $LessonAttemptsTable> {
  $$LessonAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get incorrectCount => $composableBuilder(
    column: $table.incorrectCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get committedAt => $composableBuilder(
    column: $table.committedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonAttemptsTable> {
  $$LessonAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get incorrectCount => $composableBuilder(
    column: $table.incorrectCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get committedAt => $composableBuilder(
    column: $table.committedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonAttemptsTable> {
  $$LessonAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get unitId =>
      $composableBuilder(column: $table.unitId, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get incorrectCount => $composableBuilder(
    column: $table.incorrectCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get committedAt => $composableBuilder(
    column: $table.committedAt,
    builder: (column) => column,
  );
}

class $$LessonAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonAttemptsTable,
          LessonAttempt,
          $$LessonAttemptsTableFilterComposer,
          $$LessonAttemptsTableOrderingComposer,
          $$LessonAttemptsTableAnnotationComposer,
          $$LessonAttemptsTableCreateCompanionBuilder,
          $$LessonAttemptsTableUpdateCompanionBuilder,
          (
            LessonAttempt,
            BaseReferences<_$AppDatabase, $LessonAttemptsTable, LessonAttempt>,
          ),
          LessonAttempt,
          PrefetchHooks Function()
        > {
  $$LessonAttemptsTableTableManager(
    _$AppDatabase db,
    $LessonAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$LessonAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$LessonAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$LessonAttemptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> attemptId = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<int> unitId = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> incorrectCount = const Value.absent(),
                Value<int> skippedCount = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> committedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonAttemptsCompanion(
                attemptId: attemptId,
                lessonId: lessonId,
                unitId: unitId,
                phase: phase,
                score: score,
                correctCount: correctCount,
                incorrectCount: incorrectCount,
                skippedCount: skippedCount,
                startedAt: startedAt,
                committedAt: committedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String attemptId,
                required int lessonId,
                required int unitId,
                required String phase,
                required double score,
                required int correctCount,
                required int incorrectCount,
                required int skippedCount,
                required DateTime startedAt,
                required DateTime committedAt,
                Value<int> rowid = const Value.absent(),
              }) => LessonAttemptsCompanion.insert(
                attemptId: attemptId,
                lessonId: lessonId,
                unitId: unitId,
                phase: phase,
                score: score,
                correctCount: correctCount,
                incorrectCount: incorrectCount,
                skippedCount: skippedCount,
                startedAt: startedAt,
                committedAt: committedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonAttemptsTable,
      LessonAttempt,
      $$LessonAttemptsTableFilterComposer,
      $$LessonAttemptsTableOrderingComposer,
      $$LessonAttemptsTableAnnotationComposer,
      $$LessonAttemptsTableCreateCompanionBuilder,
      $$LessonAttemptsTableUpdateCompanionBuilder,
      (
        LessonAttempt,
        BaseReferences<_$AppDatabase, $LessonAttemptsTable, LessonAttempt>,
      ),
      LessonAttempt,
      PrefetchHooks Function()
    >;
typedef $$RewardLedgerTableCreateCompanionBuilder =
    RewardLedgerCompanion Function({
      required String rewardId,
      required String sourceId,
      required String rewardType,
      required int xp,
      required DateTime awardedAt,
      Value<int> rowid,
    });
typedef $$RewardLedgerTableUpdateCompanionBuilder =
    RewardLedgerCompanion Function({
      Value<String> rewardId,
      Value<String> sourceId,
      Value<String> rewardType,
      Value<int> xp,
      Value<DateTime> awardedAt,
      Value<int> rowid,
    });

class $$RewardLedgerTableFilterComposer
    extends Composer<_$AppDatabase, $RewardLedgerTable> {
  $$RewardLedgerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rewardId => $composableBuilder(
    column: $table.rewardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rewardType => $composableBuilder(
    column: $table.rewardType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get awardedAt => $composableBuilder(
    column: $table.awardedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RewardLedgerTableOrderingComposer
    extends Composer<_$AppDatabase, $RewardLedgerTable> {
  $$RewardLedgerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rewardId => $composableBuilder(
    column: $table.rewardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewardType => $composableBuilder(
    column: $table.rewardType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get awardedAt => $composableBuilder(
    column: $table.awardedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RewardLedgerTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewardLedgerTable> {
  $$RewardLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rewardId =>
      $composableBuilder(column: $table.rewardId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get rewardType => $composableBuilder(
    column: $table.rewardType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<DateTime> get awardedAt =>
      $composableBuilder(column: $table.awardedAt, builder: (column) => column);
}

class $$RewardLedgerTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RewardLedgerTable,
          RewardLedgerData,
          $$RewardLedgerTableFilterComposer,
          $$RewardLedgerTableOrderingComposer,
          $$RewardLedgerTableAnnotationComposer,
          $$RewardLedgerTableCreateCompanionBuilder,
          $$RewardLedgerTableUpdateCompanionBuilder,
          (
            RewardLedgerData,
            BaseReferences<_$AppDatabase, $RewardLedgerTable, RewardLedgerData>,
          ),
          RewardLedgerData,
          PrefetchHooks Function()
        > {
  $$RewardLedgerTableTableManager(_$AppDatabase db, $RewardLedgerTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RewardLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$RewardLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$RewardLedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rewardId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> rewardType = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<DateTime> awardedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RewardLedgerCompanion(
                rewardId: rewardId,
                sourceId: sourceId,
                rewardType: rewardType,
                xp: xp,
                awardedAt: awardedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rewardId,
                required String sourceId,
                required String rewardType,
                required int xp,
                required DateTime awardedAt,
                Value<int> rowid = const Value.absent(),
              }) => RewardLedgerCompanion.insert(
                rewardId: rewardId,
                sourceId: sourceId,
                rewardType: rewardType,
                xp: xp,
                awardedAt: awardedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RewardLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RewardLedgerTable,
      RewardLedgerData,
      $$RewardLedgerTableFilterComposer,
      $$RewardLedgerTableOrderingComposer,
      $$RewardLedgerTableAnnotationComposer,
      $$RewardLedgerTableCreateCompanionBuilder,
      $$RewardLedgerTableUpdateCompanionBuilder,
      (
        RewardLedgerData,
        BaseReferences<_$AppDatabase, $RewardLedgerTable, RewardLedgerData>,
      ),
      RewardLedgerData,
      PrefetchHooks Function()
    >;
typedef $$ExerciseAttemptsTableCreateCompanionBuilder =
    ExerciseAttemptsCompanion Function({
      required String presentationId,
      required String lessonAttemptId,
      required int exerciseId,
      required String phase,
      required String outcome,
      required DateTime answeredAt,
      Value<int> rowid,
    });
typedef $$ExerciseAttemptsTableUpdateCompanionBuilder =
    ExerciseAttemptsCompanion Function({
      Value<String> presentationId,
      Value<String> lessonAttemptId,
      Value<int> exerciseId,
      Value<String> phase,
      Value<String> outcome,
      Value<DateTime> answeredAt,
      Value<int> rowid,
    });

class $$ExerciseAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseAttemptsTable> {
  $$ExerciseAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get presentationId => $composableBuilder(
    column: $table.presentationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonAttemptId => $composableBuilder(
    column: $table.lessonAttemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseAttemptsTable> {
  $$ExerciseAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get presentationId => $composableBuilder(
    column: $table.presentationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonAttemptId => $composableBuilder(
    column: $table.lessonAttemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseAttemptsTable> {
  $$ExerciseAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get presentationId => $composableBuilder(
    column: $table.presentationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lessonAttemptId => $composableBuilder(
    column: $table.lessonAttemptId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );
}

class $$ExerciseAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseAttemptsTable,
          ExerciseAttempt,
          $$ExerciseAttemptsTableFilterComposer,
          $$ExerciseAttemptsTableOrderingComposer,
          $$ExerciseAttemptsTableAnnotationComposer,
          $$ExerciseAttemptsTableCreateCompanionBuilder,
          $$ExerciseAttemptsTableUpdateCompanionBuilder,
          (
            ExerciseAttempt,
            BaseReferences<
              _$AppDatabase,
              $ExerciseAttemptsTable,
              ExerciseAttempt
            >,
          ),
          ExerciseAttempt,
          PrefetchHooks Function()
        > {
  $$ExerciseAttemptsTableTableManager(
    _$AppDatabase db,
    $ExerciseAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$ExerciseAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ExerciseAttemptsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ExerciseAttemptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> presentationId = const Value.absent(),
                Value<String> lessonAttemptId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<DateTime> answeredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseAttemptsCompanion(
                presentationId: presentationId,
                lessonAttemptId: lessonAttemptId,
                exerciseId: exerciseId,
                phase: phase,
                outcome: outcome,
                answeredAt: answeredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String presentationId,
                required String lessonAttemptId,
                required int exerciseId,
                required String phase,
                required String outcome,
                required DateTime answeredAt,
                Value<int> rowid = const Value.absent(),
              }) => ExerciseAttemptsCompanion.insert(
                presentationId: presentationId,
                lessonAttemptId: lessonAttemptId,
                exerciseId: exerciseId,
                phase: phase,
                outcome: outcome,
                answeredAt: answeredAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseAttemptsTable,
      ExerciseAttempt,
      $$ExerciseAttemptsTableFilterComposer,
      $$ExerciseAttemptsTableOrderingComposer,
      $$ExerciseAttemptsTableAnnotationComposer,
      $$ExerciseAttemptsTableCreateCompanionBuilder,
      $$ExerciseAttemptsTableUpdateCompanionBuilder,
      (
        ExerciseAttempt,
        BaseReferences<_$AppDatabase, $ExerciseAttemptsTable, ExerciseAttempt>,
      ),
      ExerciseAttempt,
      PrefetchHooks Function()
    >;
typedef $$ReviewAttemptsTableCreateCompanionBuilder =
    ReviewAttemptsCompanion Function({
      required String reviewId,
      required int srsCardId,
      required String rating,
      required DateTime reviewedAt,
      Value<bool> introducedNewCard,
      Value<int> rowid,
    });
typedef $$ReviewAttemptsTableUpdateCompanionBuilder =
    ReviewAttemptsCompanion Function({
      Value<String> reviewId,
      Value<int> srsCardId,
      Value<String> rating,
      Value<DateTime> reviewedAt,
      Value<bool> introducedNewCard,
      Value<int> rowid,
    });

class $$ReviewAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewAttemptsTable> {
  $$ReviewAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get reviewId => $composableBuilder(
    column: $table.reviewId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get srsCardId => $composableBuilder(
    column: $table.srsCardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get introducedNewCard => $composableBuilder(
    column: $table.introducedNewCard,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewAttemptsTable> {
  $$ReviewAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get reviewId => $composableBuilder(
    column: $table.reviewId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get srsCardId => $composableBuilder(
    column: $table.srsCardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get introducedNewCard => $composableBuilder(
    column: $table.introducedNewCard,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewAttemptsTable> {
  $$ReviewAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get reviewId =>
      $composableBuilder(column: $table.reviewId, builder: (column) => column);

  GeneratedColumn<int> get srsCardId =>
      $composableBuilder(column: $table.srsCardId, builder: (column) => column);

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get introducedNewCard => $composableBuilder(
    column: $table.introducedNewCard,
    builder: (column) => column,
  );
}

class $$ReviewAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewAttemptsTable,
          ReviewAttempt,
          $$ReviewAttemptsTableFilterComposer,
          $$ReviewAttemptsTableOrderingComposer,
          $$ReviewAttemptsTableAnnotationComposer,
          $$ReviewAttemptsTableCreateCompanionBuilder,
          $$ReviewAttemptsTableUpdateCompanionBuilder,
          (
            ReviewAttempt,
            BaseReferences<_$AppDatabase, $ReviewAttemptsTable, ReviewAttempt>,
          ),
          ReviewAttempt,
          PrefetchHooks Function()
        > {
  $$ReviewAttemptsTableTableManager(
    _$AppDatabase db,
    $ReviewAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ReviewAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ReviewAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ReviewAttemptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> reviewId = const Value.absent(),
                Value<int> srsCardId = const Value.absent(),
                Value<String> rating = const Value.absent(),
                Value<DateTime> reviewedAt = const Value.absent(),
                Value<bool> introducedNewCard = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewAttemptsCompanion(
                reviewId: reviewId,
                srsCardId: srsCardId,
                rating: rating,
                reviewedAt: reviewedAt,
                introducedNewCard: introducedNewCard,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String reviewId,
                required int srsCardId,
                required String rating,
                required DateTime reviewedAt,
                Value<bool> introducedNewCard = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewAttemptsCompanion.insert(
                reviewId: reviewId,
                srsCardId: srsCardId,
                rating: rating,
                reviewedAt: reviewedAt,
                introducedNewCard: introducedNewCard,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewAttemptsTable,
      ReviewAttempt,
      $$ReviewAttemptsTableFilterComposer,
      $$ReviewAttemptsTableOrderingComposer,
      $$ReviewAttemptsTableAnnotationComposer,
      $$ReviewAttemptsTableCreateCompanionBuilder,
      $$ReviewAttemptsTableUpdateCompanionBuilder,
      (
        ReviewAttempt,
        BaseReferences<_$AppDatabase, $ReviewAttemptsTable, ReviewAttempt>,
      ),
      ReviewAttempt,
      PrefetchHooks Function()
    >;
typedef $$ContentReleaseInstallationsTableCreateCompanionBuilder =
    ContentReleaseInstallationsCompanion Function({
      required String releaseId,
      required int version,
      required String contentChecksum,
      Value<String?> notes,
      Value<bool> isActive,
      Value<bool> isPrevious,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$ContentReleaseInstallationsTableUpdateCompanionBuilder =
    ContentReleaseInstallationsCompanion Function({
      Value<String> releaseId,
      Value<int> version,
      Value<String> contentChecksum,
      Value<String?> notes,
      Value<bool> isActive,
      Value<bool> isPrevious,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

final class $$ContentReleaseInstallationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ContentReleaseInstallationsTable,
          ContentReleaseInstallation
        > {
  $$ContentReleaseInstallationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $ContentReleasePacksTable,
    List<ContentReleasePack>
  >
  _contentReleasePacksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.contentReleasePacks,
    aliasName:
        'content_release_installations__release_id__content_release_packs__release_id',
  );

  $$ContentReleasePacksTableProcessedTableManager get contentReleasePacksRefs {
    final manager = $$ContentReleasePacksTableTableManager(
      $_db,
      $_db.contentReleasePacks,
    ).filter(
      (f) =>
          f.releaseId.releaseId.sqlEquals($_itemColumn<String>('release_id')!),
    );

    final cache = $_typedResult.readTableOrNull(
      _contentReleasePacksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ContentReleaseInstallationsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentReleaseInstallationsTable> {
  $$ContentReleaseInstallationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get releaseId => $composableBuilder(
    column: $table.releaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentChecksum => $composableBuilder(
    column: $table.contentChecksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrevious => $composableBuilder(
    column: $table.isPrevious,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> contentReleasePacksRefs(
    Expression<bool> Function($$ContentReleasePacksTableFilterComposer f) f,
  ) {
    final $$ContentReleasePacksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.releaseId,
      referencedTable: $db.contentReleasePacks,
      getReferencedColumn: (t) => t.releaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentReleasePacksTableFilterComposer(
            $db: $db,
            $table: $db.contentReleasePacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContentReleaseInstallationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentReleaseInstallationsTable> {
  $$ContentReleaseInstallationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get releaseId => $composableBuilder(
    column: $table.releaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentChecksum => $composableBuilder(
    column: $table.contentChecksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrevious => $composableBuilder(
    column: $table.isPrevious,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentReleaseInstallationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentReleaseInstallationsTable> {
  $$ContentReleaseInstallationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get releaseId =>
      $composableBuilder(column: $table.releaseId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get contentChecksum => $composableBuilder(
    column: $table.contentChecksum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get isPrevious => $composableBuilder(
    column: $table.isPrevious,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  Expression<T> contentReleasePacksRefs<T extends Object>(
    Expression<T> Function($$ContentReleasePacksTableAnnotationComposer a) f,
  ) {
    final $$ContentReleasePacksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.releaseId,
          referencedTable: $db.contentReleasePacks,
          getReferencedColumn: (t) => t.releaseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ContentReleasePacksTableAnnotationComposer(
                $db: $db,
                $table: $db.contentReleasePacks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ContentReleaseInstallationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentReleaseInstallationsTable,
          ContentReleaseInstallation,
          $$ContentReleaseInstallationsTableFilterComposer,
          $$ContentReleaseInstallationsTableOrderingComposer,
          $$ContentReleaseInstallationsTableAnnotationComposer,
          $$ContentReleaseInstallationsTableCreateCompanionBuilder,
          $$ContentReleaseInstallationsTableUpdateCompanionBuilder,
          (
            ContentReleaseInstallation,
            $$ContentReleaseInstallationsTableReferences,
          ),
          ContentReleaseInstallation,
          PrefetchHooks Function({bool contentReleasePacksRefs})
        > {
  $$ContentReleaseInstallationsTableTableManager(
    _$AppDatabase db,
    $ContentReleaseInstallationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ContentReleaseInstallationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ContentReleaseInstallationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ContentReleaseInstallationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> releaseId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> contentChecksum = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isPrevious = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentReleaseInstallationsCompanion(
                releaseId: releaseId,
                version: version,
                contentChecksum: contentChecksum,
                notes: notes,
                isActive: isActive,
                isPrevious: isPrevious,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String releaseId,
                required int version,
                required String contentChecksum,
                Value<String?> notes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isPrevious = const Value.absent(),
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentReleaseInstallationsCompanion.insert(
                releaseId: releaseId,
                version: version,
                contentChecksum: contentChecksum,
                notes: notes,
                isActive: isActive,
                isPrevious: isPrevious,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ContentReleaseInstallationsTableReferences(
                            db,
                            table,
                            e,
                          ),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({contentReleasePacksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (contentReleasePacksRefs) db.contentReleasePacks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (contentReleasePacksRefs)
                    await $_getPrefetchedData<
                      ContentReleaseInstallation,
                      $ContentReleaseInstallationsTable,
                      ContentReleasePack
                    >(
                      currentTable: table,
                      referencedTable:
                          $$ContentReleaseInstallationsTableReferences
                              ._contentReleasePacksRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ContentReleaseInstallationsTableReferences(
                                db,
                                table,
                                p0,
                              ).contentReleasePacksRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.releaseId == item.releaseId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ContentReleaseInstallationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentReleaseInstallationsTable,
      ContentReleaseInstallation,
      $$ContentReleaseInstallationsTableFilterComposer,
      $$ContentReleaseInstallationsTableOrderingComposer,
      $$ContentReleaseInstallationsTableAnnotationComposer,
      $$ContentReleaseInstallationsTableCreateCompanionBuilder,
      $$ContentReleaseInstallationsTableUpdateCompanionBuilder,
      (
        ContentReleaseInstallation,
        $$ContentReleaseInstallationsTableReferences,
      ),
      ContentReleaseInstallation,
      PrefetchHooks Function({bool contentReleasePacksRefs})
    >;
typedef $$ContentReleasePacksTableCreateCompanionBuilder =
    ContentReleasePacksCompanion Function({
      required String releaseId,
      required String packKey,
      required int packVersion,
      required String checksum,
      required String content,
      Value<int> rowid,
    });
typedef $$ContentReleasePacksTableUpdateCompanionBuilder =
    ContentReleasePacksCompanion Function({
      Value<String> releaseId,
      Value<String> packKey,
      Value<int> packVersion,
      Value<String> checksum,
      Value<String> content,
      Value<int> rowid,
    });

final class $$ContentReleasePacksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ContentReleasePacksTable,
          ContentReleasePack
        > {
  $$ContentReleasePacksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ContentReleaseInstallationsTable _releaseIdTable(
    _$AppDatabase db,
  ) => db.contentReleaseInstallations.createAlias(
    'content_release_packs__release_id__content_release_installations__release_id',
  );

  $$ContentReleaseInstallationsTableProcessedTableManager get releaseId {
    final $_column = $_itemColumn<String>('release_id')!;

    final manager = $$ContentReleaseInstallationsTableTableManager(
      $_db,
      $_db.contentReleaseInstallations,
    ).filter((f) => f.releaseId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_releaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ContentReleasePacksTableFilterComposer
    extends Composer<_$AppDatabase, $ContentReleasePacksTable> {
  $$ContentReleasePacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get packKey => $composableBuilder(
    column: $table.packKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get packVersion => $composableBuilder(
    column: $table.packVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$ContentReleaseInstallationsTableFilterComposer get releaseId {
    final $$ContentReleaseInstallationsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.releaseId,
          referencedTable: $db.contentReleaseInstallations,
          getReferencedColumn: (t) => t.releaseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ContentReleaseInstallationsTableFilterComposer(
                $db: $db,
                $table: $db.contentReleaseInstallations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ContentReleasePacksTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentReleasePacksTable> {
  $$ContentReleasePacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get packKey => $composableBuilder(
    column: $table.packKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get packVersion => $composableBuilder(
    column: $table.packVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContentReleaseInstallationsTableOrderingComposer get releaseId {
    final $$ContentReleaseInstallationsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.releaseId,
          referencedTable: $db.contentReleaseInstallations,
          getReferencedColumn: (t) => t.releaseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ContentReleaseInstallationsTableOrderingComposer(
                $db: $db,
                $table: $db.contentReleaseInstallations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ContentReleasePacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentReleasePacksTable> {
  $$ContentReleasePacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get packKey =>
      $composableBuilder(column: $table.packKey, builder: (column) => column);

  GeneratedColumn<int> get packVersion => $composableBuilder(
    column: $table.packVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$ContentReleaseInstallationsTableAnnotationComposer get releaseId {
    final $$ContentReleaseInstallationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.releaseId,
          referencedTable: $db.contentReleaseInstallations,
          getReferencedColumn: (t) => t.releaseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ContentReleaseInstallationsTableAnnotationComposer(
                $db: $db,
                $table: $db.contentReleaseInstallations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ContentReleasePacksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentReleasePacksTable,
          ContentReleasePack,
          $$ContentReleasePacksTableFilterComposer,
          $$ContentReleasePacksTableOrderingComposer,
          $$ContentReleasePacksTableAnnotationComposer,
          $$ContentReleasePacksTableCreateCompanionBuilder,
          $$ContentReleasePacksTableUpdateCompanionBuilder,
          (ContentReleasePack, $$ContentReleasePacksTableReferences),
          ContentReleasePack,
          PrefetchHooks Function({bool releaseId})
        > {
  $$ContentReleasePacksTableTableManager(
    _$AppDatabase db,
    $ContentReleasePacksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ContentReleasePacksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ContentReleasePacksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ContentReleasePacksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> releaseId = const Value.absent(),
                Value<String> packKey = const Value.absent(),
                Value<int> packVersion = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentReleasePacksCompanion(
                releaseId: releaseId,
                packKey: packKey,
                packVersion: packVersion,
                checksum: checksum,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String releaseId,
                required String packKey,
                required int packVersion,
                required String checksum,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => ContentReleasePacksCompanion.insert(
                releaseId: releaseId,
                packKey: packKey,
                packVersion: packVersion,
                checksum: checksum,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ContentReleasePacksTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({releaseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (releaseId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.releaseId,
                            referencedTable:
                                $$ContentReleasePacksTableReferences
                                    ._releaseIdTable(db),
                            referencedColumn:
                                $$ContentReleasePacksTableReferences
                                    ._releaseIdTable(db)
                                    .releaseId,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ContentReleasePacksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentReleasePacksTable,
      ContentReleasePack,
      $$ContentReleasePacksTableFilterComposer,
      $$ContentReleasePacksTableOrderingComposer,
      $$ContentReleasePacksTableAnnotationComposer,
      $$ContentReleasePacksTableCreateCompanionBuilder,
      $$ContentReleasePacksTableUpdateCompanionBuilder,
      (ContentReleasePack, $$ContentReleasePacksTableReferences),
      ContentReleasePack,
      PrefetchHooks Function({bool releaseId})
    >;
typedef $$LearningEvidenceEventsTableCreateCompanionBuilder =
    LearningEvidenceEventsCompanion Function({
      required String evidenceId,
      required int lessonId,
      Value<int?> exerciseId,
      required String skill,
      required String phase,
      required bool correct,
      required bool novelTask,
      Value<String> supportsJson,
      Value<String> conceptKeysJson,
      required int responseLatencyMs,
      required DateTime observedAt,
      Value<int> rowid,
    });
typedef $$LearningEvidenceEventsTableUpdateCompanionBuilder =
    LearningEvidenceEventsCompanion Function({
      Value<String> evidenceId,
      Value<int> lessonId,
      Value<int?> exerciseId,
      Value<String> skill,
      Value<String> phase,
      Value<bool> correct,
      Value<bool> novelTask,
      Value<String> supportsJson,
      Value<String> conceptKeysJson,
      Value<int> responseLatencyMs,
      Value<DateTime> observedAt,
      Value<int> rowid,
    });

class $$LearningEvidenceEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LearningEvidenceEventsTable> {
  $$LearningEvidenceEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get novelTask => $composableBuilder(
    column: $table.novelTask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supportsJson => $composableBuilder(
    column: $table.supportsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conceptKeysJson => $composableBuilder(
    column: $table.conceptKeysJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responseLatencyMs => $composableBuilder(
    column: $table.responseLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearningEvidenceEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningEvidenceEventsTable> {
  $$LearningEvidenceEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get novelTask => $composableBuilder(
    column: $table.novelTask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supportsJson => $composableBuilder(
    column: $table.supportsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conceptKeysJson => $composableBuilder(
    column: $table.conceptKeysJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responseLatencyMs => $composableBuilder(
    column: $table.responseLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningEvidenceEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningEvidenceEventsTable> {
  $$LearningEvidenceEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skill =>
      $composableBuilder(column: $table.skill, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<bool> get novelTask =>
      $composableBuilder(column: $table.novelTask, builder: (column) => column);

  GeneratedColumn<String> get supportsJson => $composableBuilder(
    column: $table.supportsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conceptKeysJson => $composableBuilder(
    column: $table.conceptKeysJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get responseLatencyMs => $composableBuilder(
    column: $table.responseLatencyMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );
}

class $$LearningEvidenceEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningEvidenceEventsTable,
          LearningEvidenceEvent,
          $$LearningEvidenceEventsTableFilterComposer,
          $$LearningEvidenceEventsTableOrderingComposer,
          $$LearningEvidenceEventsTableAnnotationComposer,
          $$LearningEvidenceEventsTableCreateCompanionBuilder,
          $$LearningEvidenceEventsTableUpdateCompanionBuilder,
          (
            LearningEvidenceEvent,
            BaseReferences<
              _$AppDatabase,
              $LearningEvidenceEventsTable,
              LearningEvidenceEvent
            >,
          ),
          LearningEvidenceEvent,
          PrefetchHooks Function()
        > {
  $$LearningEvidenceEventsTableTableManager(
    _$AppDatabase db,
    $LearningEvidenceEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$LearningEvidenceEventsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$LearningEvidenceEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$LearningEvidenceEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> evidenceId = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<int?> exerciseId = const Value.absent(),
                Value<String> skill = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<bool> novelTask = const Value.absent(),
                Value<String> supportsJson = const Value.absent(),
                Value<String> conceptKeysJson = const Value.absent(),
                Value<int> responseLatencyMs = const Value.absent(),
                Value<DateTime> observedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningEvidenceEventsCompanion(
                evidenceId: evidenceId,
                lessonId: lessonId,
                exerciseId: exerciseId,
                skill: skill,
                phase: phase,
                correct: correct,
                novelTask: novelTask,
                supportsJson: supportsJson,
                conceptKeysJson: conceptKeysJson,
                responseLatencyMs: responseLatencyMs,
                observedAt: observedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String evidenceId,
                required int lessonId,
                Value<int?> exerciseId = const Value.absent(),
                required String skill,
                required String phase,
                required bool correct,
                required bool novelTask,
                Value<String> supportsJson = const Value.absent(),
                Value<String> conceptKeysJson = const Value.absent(),
                required int responseLatencyMs,
                required DateTime observedAt,
                Value<int> rowid = const Value.absent(),
              }) => LearningEvidenceEventsCompanion.insert(
                evidenceId: evidenceId,
                lessonId: lessonId,
                exerciseId: exerciseId,
                skill: skill,
                phase: phase,
                correct: correct,
                novelTask: novelTask,
                supportsJson: supportsJson,
                conceptKeysJson: conceptKeysJson,
                responseLatencyMs: responseLatencyMs,
                observedAt: observedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearningEvidenceEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningEvidenceEventsTable,
      LearningEvidenceEvent,
      $$LearningEvidenceEventsTableFilterComposer,
      $$LearningEvidenceEventsTableOrderingComposer,
      $$LearningEvidenceEventsTableAnnotationComposer,
      $$LearningEvidenceEventsTableCreateCompanionBuilder,
      $$LearningEvidenceEventsTableUpdateCompanionBuilder,
      (
        LearningEvidenceEvent,
        BaseReferences<
          _$AppDatabase,
          $LearningEvidenceEventsTable,
          LearningEvidenceEvent
        >,
      ),
      LearningEvidenceEvent,
      PrefetchHooks Function()
    >;
typedef $$PlacementProfilesTableCreateCompanionBuilder =
    PlacementProfilesCompanion Function({
      Value<String> key,
      required int provisionalUnit,
      Value<int?> learnerOverrideUnit,
      required String estimatesJson,
      required int sampleSize,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlacementProfilesTableUpdateCompanionBuilder =
    PlacementProfilesCompanion Function({
      Value<String> key,
      Value<int> provisionalUnit,
      Value<int?> learnerOverrideUnit,
      Value<String> estimatesJson,
      Value<int> sampleSize,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PlacementProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $PlacementProfilesTable> {
  $$PlacementProfilesTableFilterComposer({
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

  ColumnFilters<int> get provisionalUnit => $composableBuilder(
    column: $table.provisionalUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get learnerOverrideUnit => $composableBuilder(
    column: $table.learnerOverrideUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estimatesJson => $composableBuilder(
    column: $table.estimatesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleSize => $composableBuilder(
    column: $table.sampleSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlacementProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlacementProfilesTable> {
  $$PlacementProfilesTableOrderingComposer({
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

  ColumnOrderings<int> get provisionalUnit => $composableBuilder(
    column: $table.provisionalUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get learnerOverrideUnit => $composableBuilder(
    column: $table.learnerOverrideUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estimatesJson => $composableBuilder(
    column: $table.estimatesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleSize => $composableBuilder(
    column: $table.sampleSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlacementProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlacementProfilesTable> {
  $$PlacementProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get provisionalUnit => $composableBuilder(
    column: $table.provisionalUnit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get learnerOverrideUnit => $composableBuilder(
    column: $table.learnerOverrideUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estimatesJson => $composableBuilder(
    column: $table.estimatesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleSize => $composableBuilder(
    column: $table.sampleSize,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlacementProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlacementProfilesTable,
          PlacementProfile,
          $$PlacementProfilesTableFilterComposer,
          $$PlacementProfilesTableOrderingComposer,
          $$PlacementProfilesTableAnnotationComposer,
          $$PlacementProfilesTableCreateCompanionBuilder,
          $$PlacementProfilesTableUpdateCompanionBuilder,
          (
            PlacementProfile,
            BaseReferences<
              _$AppDatabase,
              $PlacementProfilesTable,
              PlacementProfile
            >,
          ),
          PlacementProfile,
          PrefetchHooks Function()
        > {
  $$PlacementProfilesTableTableManager(
    _$AppDatabase db,
    $PlacementProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PlacementProfilesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$PlacementProfilesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$PlacementProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> provisionalUnit = const Value.absent(),
                Value<int?> learnerOverrideUnit = const Value.absent(),
                Value<String> estimatesJson = const Value.absent(),
                Value<int> sampleSize = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlacementProfilesCompanion(
                key: key,
                provisionalUnit: provisionalUnit,
                learnerOverrideUnit: learnerOverrideUnit,
                estimatesJson: estimatesJson,
                sampleSize: sampleSize,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                required int provisionalUnit,
                Value<int?> learnerOverrideUnit = const Value.absent(),
                required String estimatesJson,
                required int sampleSize,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlacementProfilesCompanion.insert(
                key: key,
                provisionalUnit: provisionalUnit,
                learnerOverrideUnit: learnerOverrideUnit,
                estimatesJson: estimatesJson,
                sampleSize: sampleSize,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlacementProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlacementProfilesTable,
      PlacementProfile,
      $$PlacementProfilesTableFilterComposer,
      $$PlacementProfilesTableOrderingComposer,
      $$PlacementProfilesTableAnnotationComposer,
      $$PlacementProfilesTableCreateCompanionBuilder,
      $$PlacementProfilesTableUpdateCompanionBuilder,
      (
        PlacementProfile,
        BaseReferences<
          _$AppDatabase,
          $PlacementProfilesTable,
          PlacementProfile
        >,
      ),
      PlacementProfile,
      PrefetchHooks Function()
    >;
typedef $$DelayedTransferAssignmentsTableCreateCompanionBuilder =
    DelayedTransferAssignmentsCompanion Function({
      required String assignmentId,
      required String sourceAttemptId,
      required int lessonId,
      required int sourceExerciseId,
      required DateTime dueAt,
      Value<String> status,
      Value<String?> completedEvidenceId,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DelayedTransferAssignmentsTableUpdateCompanionBuilder =
    DelayedTransferAssignmentsCompanion Function({
      Value<String> assignmentId,
      Value<String> sourceAttemptId,
      Value<int> lessonId,
      Value<int> sourceExerciseId,
      Value<DateTime> dueAt,
      Value<String> status,
      Value<String?> completedEvidenceId,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$DelayedTransferAssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $DelayedTransferAssignmentsTable> {
  $$DelayedTransferAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assignmentId => $composableBuilder(
    column: $table.assignmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceAttemptId => $composableBuilder(
    column: $table.sourceAttemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceExerciseId => $composableBuilder(
    column: $table.sourceExerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedEvidenceId => $composableBuilder(
    column: $table.completedEvidenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DelayedTransferAssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DelayedTransferAssignmentsTable> {
  $$DelayedTransferAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assignmentId => $composableBuilder(
    column: $table.assignmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceAttemptId => $composableBuilder(
    column: $table.sourceAttemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceExerciseId => $composableBuilder(
    column: $table.sourceExerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedEvidenceId => $composableBuilder(
    column: $table.completedEvidenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DelayedTransferAssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DelayedTransferAssignmentsTable> {
  $$DelayedTransferAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assignmentId => $composableBuilder(
    column: $table.assignmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceAttemptId => $composableBuilder(
    column: $table.sourceAttemptId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get sourceExerciseId => $composableBuilder(
    column: $table.sourceExerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get completedEvidenceId => $composableBuilder(
    column: $table.completedEvidenceId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DelayedTransferAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DelayedTransferAssignmentsTable,
          DelayedTransferAssignment,
          $$DelayedTransferAssignmentsTableFilterComposer,
          $$DelayedTransferAssignmentsTableOrderingComposer,
          $$DelayedTransferAssignmentsTableAnnotationComposer,
          $$DelayedTransferAssignmentsTableCreateCompanionBuilder,
          $$DelayedTransferAssignmentsTableUpdateCompanionBuilder,
          (
            DelayedTransferAssignment,
            BaseReferences<
              _$AppDatabase,
              $DelayedTransferAssignmentsTable,
              DelayedTransferAssignment
            >,
          ),
          DelayedTransferAssignment,
          PrefetchHooks Function()
        > {
  $$DelayedTransferAssignmentsTableTableManager(
    _$AppDatabase db,
    $DelayedTransferAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DelayedTransferAssignmentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$DelayedTransferAssignmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DelayedTransferAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> assignmentId = const Value.absent(),
                Value<String> sourceAttemptId = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<int> sourceExerciseId = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> completedEvidenceId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DelayedTransferAssignmentsCompanion(
                assignmentId: assignmentId,
                sourceAttemptId: sourceAttemptId,
                lessonId: lessonId,
                sourceExerciseId: sourceExerciseId,
                dueAt: dueAt,
                status: status,
                completedEvidenceId: completedEvidenceId,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assignmentId,
                required String sourceAttemptId,
                required int lessonId,
                required int sourceExerciseId,
                required DateTime dueAt,
                Value<String> status = const Value.absent(),
                Value<String?> completedEvidenceId = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DelayedTransferAssignmentsCompanion.insert(
                assignmentId: assignmentId,
                sourceAttemptId: sourceAttemptId,
                lessonId: lessonId,
                sourceExerciseId: sourceExerciseId,
                dueAt: dueAt,
                status: status,
                completedEvidenceId: completedEvidenceId,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DelayedTransferAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DelayedTransferAssignmentsTable,
      DelayedTransferAssignment,
      $$DelayedTransferAssignmentsTableFilterComposer,
      $$DelayedTransferAssignmentsTableOrderingComposer,
      $$DelayedTransferAssignmentsTableAnnotationComposer,
      $$DelayedTransferAssignmentsTableCreateCompanionBuilder,
      $$DelayedTransferAssignmentsTableUpdateCompanionBuilder,
      (
        DelayedTransferAssignment,
        BaseReferences<
          _$AppDatabase,
          $DelayedTransferAssignmentsTable,
          DelayedTransferAssignment
        >,
      ),
      DelayedTransferAssignment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db, _db.units);
  $$LessonsTableTableManager get lessons =>
      $$LessonsTableTableManager(_db, _db.lessons);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$FlashcardsTableTableManager get flashcards =>
      $$FlashcardsTableTableManager(_db, _db.flashcards);
  $$SrsCardsTableTableManager get srsCards =>
      $$SrsCardsTableTableManager(_db, _db.srsCards);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$GrammarRulesTableTableManager get grammarRules =>
      $$GrammarRulesTableTableManager(_db, _db.grammarRules);
  $$ExamResultsTableTableManager get examResults =>
      $$ExamResultsTableTableManager(_db, _db.examResults);
  $$UserProgressTableTableManager get userProgress =>
      $$UserProgressTableTableManager(_db, _db.userProgress);
  $$EarnedBadgesTableTableManager get earnedBadges =>
      $$EarnedBadgesTableTableManager(_db, _db.earnedBadges);
  $$ConsentRecordsTableTableManager get consentRecords =>
      $$ConsentRecordsTableTableManager(_db, _db.consentRecords);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(_db, _db.lessonProgress);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$GamificationStateTableTableTableManager get gamificationStateTable =>
      $$GamificationStateTableTableTableManager(
        _db,
        _db.gamificationStateTable,
      );
  $$LessonAttemptsTableTableManager get lessonAttempts =>
      $$LessonAttemptsTableTableManager(_db, _db.lessonAttempts);
  $$RewardLedgerTableTableManager get rewardLedger =>
      $$RewardLedgerTableTableManager(_db, _db.rewardLedger);
  $$ExerciseAttemptsTableTableManager get exerciseAttempts =>
      $$ExerciseAttemptsTableTableManager(_db, _db.exerciseAttempts);
  $$ReviewAttemptsTableTableManager get reviewAttempts =>
      $$ReviewAttemptsTableTableManager(_db, _db.reviewAttempts);
  $$ContentReleaseInstallationsTableTableManager
  get contentReleaseInstallations =>
      $$ContentReleaseInstallationsTableTableManager(
        _db,
        _db.contentReleaseInstallations,
      );
  $$ContentReleasePacksTableTableManager get contentReleasePacks =>
      $$ContentReleasePacksTableTableManager(_db, _db.contentReleasePacks);
  $$LearningEvidenceEventsTableTableManager get learningEvidenceEvents =>
      $$LearningEvidenceEventsTableTableManager(
        _db,
        _db.learningEvidenceEvents,
      );
  $$PlacementProfilesTableTableManager get placementProfiles =>
      $$PlacementProfilesTableTableManager(_db, _db.placementProfiles);
  $$DelayedTransferAssignmentsTableTableManager
  get delayedTransferAssignments =>
      $$DelayedTransferAssignmentsTableTableManager(
        _db,
        _db.delayedTransferAssignments,
      );
}
