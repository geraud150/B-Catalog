// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<double> costPrice = GeneratedColumn<double>(
    'cost_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sellPriceMeta = const VerificationMeta(
    'sellPrice',
  );
  @override
  late final GeneratedColumn<double> sellPrice = GeneratedColumn<double>(
    'sell_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
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
    defaultValue: currentDateAndTime,
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
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedToLoyverseMeta = const VerificationMeta(
    'syncedToLoyverse',
  );
  @override
  late final GeneratedColumn<bool> syncedToLoyverse = GeneratedColumn<bool>(
    'synced_to_loyverse',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced_to_loyverse" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _optionNameMeta = const VerificationMeta(
    'optionName',
  );
  @override
  late final GeneratedColumn<String> optionName = GeneratedColumn<String>(
    'option_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionValueMeta = const VerificationMeta(
    'optionValue',
  );
  @override
  late final GeneratedColumn<String> optionValue = GeneratedColumn<String>(
    'option_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loyverseItemIdMeta = const VerificationMeta(
    'loyverseItemId',
  );
  @override
  late final GeneratedColumn<String> loyverseItemId = GeneratedColumn<String>(
    'loyverse_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loyverseVariantIdMeta = const VerificationMeta(
    'loyverseVariantId',
  );
  @override
  late final GeneratedColumn<String> loyverseVariantId =
      GeneratedColumn<String>(
        'loyverse_variant_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importSourceMeta = const VerificationMeta(
    'importSource',
  );
  @override
  late final GeneratedColumn<String> importSource = GeneratedColumn<String>(
    'import_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importBatchIdMeta = const VerificationMeta(
    'importBatchId',
  );
  @override
  late final GeneratedColumn<String> importBatchId = GeneratedColumn<String>(
    'import_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    barcode,
    sku,
    name,
    category,
    description,
    costPrice,
    sellPrice,
    quantity,
    photoPath,
    createdAt,
    updatedAt,
    syncedToLoyverse,
    optionName,
    optionValue,
    loyverseItemId,
    loyverseVariantId,
    groupId,
    importSource,
    importBatchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
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
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    }
    if (data.containsKey('sell_price')) {
      context.handle(
        _sellPriceMeta,
        sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
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
    if (data.containsKey('synced_to_loyverse')) {
      context.handle(
        _syncedToLoyverseMeta,
        syncedToLoyverse.isAcceptableOrUnknown(
          data['synced_to_loyverse']!,
          _syncedToLoyverseMeta,
        ),
      );
    }
    if (data.containsKey('option_name')) {
      context.handle(
        _optionNameMeta,
        optionName.isAcceptableOrUnknown(data['option_name']!, _optionNameMeta),
      );
    }
    if (data.containsKey('option_value')) {
      context.handle(
        _optionValueMeta,
        optionValue.isAcceptableOrUnknown(
          data['option_value']!,
          _optionValueMeta,
        ),
      );
    }
    if (data.containsKey('loyverse_item_id')) {
      context.handle(
        _loyverseItemIdMeta,
        loyverseItemId.isAcceptableOrUnknown(
          data['loyverse_item_id']!,
          _loyverseItemIdMeta,
        ),
      );
    }
    if (data.containsKey('loyverse_variant_id')) {
      context.handle(
        _loyverseVariantIdMeta,
        loyverseVariantId.isAcceptableOrUnknown(
          data['loyverse_variant_id']!,
          _loyverseVariantIdMeta,
        ),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('import_source')) {
      context.handle(
        _importSourceMeta,
        importSource.isAcceptableOrUnknown(
          data['import_source']!,
          _importSourceMeta,
        ),
      );
    }
    if (data.containsKey('import_batch_id')) {
      context.handle(
        _importBatchIdMeta,
        importBatchId.isAcceptableOrUnknown(
          data['import_batch_id']!,
          _importBatchIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_price'],
      ),
      sellPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sell_price'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncedToLoyverse: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced_to_loyverse'],
      )!,
      optionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_name'],
      ),
      optionValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_value'],
      ),
      loyverseItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loyverse_item_id'],
      ),
      loyverseVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loyverse_variant_id'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      importSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source'],
      ),
      importBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_batch_id'],
      ),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final int id;
  final String? barcode;
  final String? sku;
  final String name;
  final String? category;
  final String? description;
  final double? costPrice;
  final double? sellPrice;
  final int quantity;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncedToLoyverse;
  final String? optionName;
  final String? optionValue;
  final String? loyverseItemId;
  final String? loyverseVariantId;

  /// Identifiant partagé par tous les produits locaux qui représentent les
  /// variantes d'un même article Loyverse (voir generateHandle() dans
  /// core/utils/).
  final String? groupId;

  /// Origine du produit lorsqu'il n'a pas été saisi à la main dans l'app
  /// (ex. `"docx_import"`, voir features/import/). Null pour une saisie
  /// manuelle.
  final String? importSource;

  /// Identifiant (UUID) partagé par tous les produits créés lors d'un même
  /// import en masse, pour retrouver ou tracer un lot dans son ensemble.
  final String? importBatchId;
  const Product({
    required this.id,
    this.barcode,
    this.sku,
    required this.name,
    this.category,
    this.description,
    this.costPrice,
    this.sellPrice,
    required this.quantity,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
    required this.syncedToLoyverse,
    this.optionName,
    this.optionValue,
    this.loyverseItemId,
    this.loyverseVariantId,
    this.groupId,
    this.importSource,
    this.importBatchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || costPrice != null) {
      map['cost_price'] = Variable<double>(costPrice);
    }
    if (!nullToAbsent || sellPrice != null) {
      map['sell_price'] = Variable<double>(sellPrice);
    }
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['synced_to_loyverse'] = Variable<bool>(syncedToLoyverse);
    if (!nullToAbsent || optionName != null) {
      map['option_name'] = Variable<String>(optionName);
    }
    if (!nullToAbsent || optionValue != null) {
      map['option_value'] = Variable<String>(optionValue);
    }
    if (!nullToAbsent || loyverseItemId != null) {
      map['loyverse_item_id'] = Variable<String>(loyverseItemId);
    }
    if (!nullToAbsent || loyverseVariantId != null) {
      map['loyverse_variant_id'] = Variable<String>(loyverseVariantId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || importSource != null) {
      map['import_source'] = Variable<String>(importSource);
    }
    if (!nullToAbsent || importBatchId != null) {
      map['import_batch_id'] = Variable<String>(importBatchId);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      costPrice: costPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(costPrice),
      sellPrice: sellPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(sellPrice),
      quantity: Value(quantity),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncedToLoyverse: Value(syncedToLoyverse),
      optionName: optionName == null && nullToAbsent
          ? const Value.absent()
          : Value(optionName),
      optionValue: optionValue == null && nullToAbsent
          ? const Value.absent()
          : Value(optionValue),
      loyverseItemId: loyverseItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(loyverseItemId),
      loyverseVariantId: loyverseVariantId == null && nullToAbsent
          ? const Value.absent()
          : Value(loyverseVariantId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      importSource: importSource == null && nullToAbsent
          ? const Value.absent()
          : Value(importSource),
      importBatchId: importBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(importBatchId),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<int>(json['id']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      sku: serializer.fromJson<String?>(json['sku']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      description: serializer.fromJson<String?>(json['description']),
      costPrice: serializer.fromJson<double?>(json['costPrice']),
      sellPrice: serializer.fromJson<double?>(json['sellPrice']),
      quantity: serializer.fromJson<int>(json['quantity']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedToLoyverse: serializer.fromJson<bool>(json['syncedToLoyverse']),
      optionName: serializer.fromJson<String?>(json['optionName']),
      optionValue: serializer.fromJson<String?>(json['optionValue']),
      loyverseItemId: serializer.fromJson<String?>(json['loyverseItemId']),
      loyverseVariantId: serializer.fromJson<String?>(
        json['loyverseVariantId'],
      ),
      groupId: serializer.fromJson<String?>(json['groupId']),
      importSource: serializer.fromJson<String?>(json['importSource']),
      importBatchId: serializer.fromJson<String?>(json['importBatchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'barcode': serializer.toJson<String?>(barcode),
      'sku': serializer.toJson<String?>(sku),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'description': serializer.toJson<String?>(description),
      'costPrice': serializer.toJson<double?>(costPrice),
      'sellPrice': serializer.toJson<double?>(sellPrice),
      'quantity': serializer.toJson<int>(quantity),
      'photoPath': serializer.toJson<String?>(photoPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedToLoyverse': serializer.toJson<bool>(syncedToLoyverse),
      'optionName': serializer.toJson<String?>(optionName),
      'optionValue': serializer.toJson<String?>(optionValue),
      'loyverseItemId': serializer.toJson<String?>(loyverseItemId),
      'loyverseVariantId': serializer.toJson<String?>(loyverseVariantId),
      'groupId': serializer.toJson<String?>(groupId),
      'importSource': serializer.toJson<String?>(importSource),
      'importBatchId': serializer.toJson<String?>(importBatchId),
    };
  }

  Product copyWith({
    int? id,
    Value<String?> barcode = const Value.absent(),
    Value<String?> sku = const Value.absent(),
    String? name,
    Value<String?> category = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<double?> costPrice = const Value.absent(),
    Value<double?> sellPrice = const Value.absent(),
    int? quantity,
    Value<String?> photoPath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncedToLoyverse,
    Value<String?> optionName = const Value.absent(),
    Value<String?> optionValue = const Value.absent(),
    Value<String?> loyverseItemId = const Value.absent(),
    Value<String?> loyverseVariantId = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    Value<String?> importSource = const Value.absent(),
    Value<String?> importBatchId = const Value.absent(),
  }) => Product(
    id: id ?? this.id,
    barcode: barcode.present ? barcode.value : this.barcode,
    sku: sku.present ? sku.value : this.sku,
    name: name ?? this.name,
    category: category.present ? category.value : this.category,
    description: description.present ? description.value : this.description,
    costPrice: costPrice.present ? costPrice.value : this.costPrice,
    sellPrice: sellPrice.present ? sellPrice.value : this.sellPrice,
    quantity: quantity ?? this.quantity,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncedToLoyverse: syncedToLoyverse ?? this.syncedToLoyverse,
    optionName: optionName.present ? optionName.value : this.optionName,
    optionValue: optionValue.present ? optionValue.value : this.optionValue,
    loyverseItemId: loyverseItemId.present
        ? loyverseItemId.value
        : this.loyverseItemId,
    loyverseVariantId: loyverseVariantId.present
        ? loyverseVariantId.value
        : this.loyverseVariantId,
    groupId: groupId.present ? groupId.value : this.groupId,
    importSource: importSource.present ? importSource.value : this.importSource,
    importBatchId: importBatchId.present
        ? importBatchId.value
        : this.importBatchId,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      sku: data.sku.present ? data.sku.value : this.sku,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedToLoyverse: data.syncedToLoyverse.present
          ? data.syncedToLoyverse.value
          : this.syncedToLoyverse,
      optionName: data.optionName.present
          ? data.optionName.value
          : this.optionName,
      optionValue: data.optionValue.present
          ? data.optionValue.value
          : this.optionValue,
      loyverseItemId: data.loyverseItemId.present
          ? data.loyverseItemId.value
          : this.loyverseItemId,
      loyverseVariantId: data.loyverseVariantId.present
          ? data.loyverseVariantId.value
          : this.loyverseVariantId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      importSource: data.importSource.present
          ? data.importSource.value
          : this.importSource,
      importBatchId: data.importBatchId.present
          ? data.importBatchId.value
          : this.importBatchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('barcode: $barcode, ')
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('costPrice: $costPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('quantity: $quantity, ')
          ..write('photoPath: $photoPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedToLoyverse: $syncedToLoyverse, ')
          ..write('optionName: $optionName, ')
          ..write('optionValue: $optionValue, ')
          ..write('loyverseItemId: $loyverseItemId, ')
          ..write('loyverseVariantId: $loyverseVariantId, ')
          ..write('groupId: $groupId, ')
          ..write('importSource: $importSource, ')
          ..write('importBatchId: $importBatchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    barcode,
    sku,
    name,
    category,
    description,
    costPrice,
    sellPrice,
    quantity,
    photoPath,
    createdAt,
    updatedAt,
    syncedToLoyverse,
    optionName,
    optionValue,
    loyverseItemId,
    loyverseVariantId,
    groupId,
    importSource,
    importBatchId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.barcode == this.barcode &&
          other.sku == this.sku &&
          other.name == this.name &&
          other.category == this.category &&
          other.description == this.description &&
          other.costPrice == this.costPrice &&
          other.sellPrice == this.sellPrice &&
          other.quantity == this.quantity &&
          other.photoPath == this.photoPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedToLoyverse == this.syncedToLoyverse &&
          other.optionName == this.optionName &&
          other.optionValue == this.optionValue &&
          other.loyverseItemId == this.loyverseItemId &&
          other.loyverseVariantId == this.loyverseVariantId &&
          other.groupId == this.groupId &&
          other.importSource == this.importSource &&
          other.importBatchId == this.importBatchId);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> id;
  final Value<String?> barcode;
  final Value<String?> sku;
  final Value<String> name;
  final Value<String?> category;
  final Value<String?> description;
  final Value<double?> costPrice;
  final Value<double?> sellPrice;
  final Value<int> quantity;
  final Value<String?> photoPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> syncedToLoyverse;
  final Value<String?> optionName;
  final Value<String?> optionValue;
  final Value<String?> loyverseItemId;
  final Value<String?> loyverseVariantId;
  final Value<String?> groupId;
  final Value<String?> importSource;
  final Value<String?> importBatchId;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.barcode = const Value.absent(),
    this.sku = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.quantity = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedToLoyverse = const Value.absent(),
    this.optionName = const Value.absent(),
    this.optionValue = const Value.absent(),
    this.loyverseItemId = const Value.absent(),
    this.loyverseVariantId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.importSource = const Value.absent(),
    this.importBatchId = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.id = const Value.absent(),
    this.barcode = const Value.absent(),
    this.sku = const Value.absent(),
    required String name,
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.quantity = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedToLoyverse = const Value.absent(),
    this.optionName = const Value.absent(),
    this.optionValue = const Value.absent(),
    this.loyverseItemId = const Value.absent(),
    this.loyverseVariantId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.importSource = const Value.absent(),
    this.importBatchId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Product> custom({
    Expression<int>? id,
    Expression<String>? barcode,
    Expression<String>? sku,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? description,
    Expression<double>? costPrice,
    Expression<double>? sellPrice,
    Expression<int>? quantity,
    Expression<String>? photoPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? syncedToLoyverse,
    Expression<String>? optionName,
    Expression<String>? optionValue,
    Expression<String>? loyverseItemId,
    Expression<String>? loyverseVariantId,
    Expression<String>? groupId,
    Expression<String>? importSource,
    Expression<String>? importBatchId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (barcode != null) 'barcode': barcode,
      if (sku != null) 'sku': sku,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (costPrice != null) 'cost_price': costPrice,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (quantity != null) 'quantity': quantity,
      if (photoPath != null) 'photo_path': photoPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedToLoyverse != null) 'synced_to_loyverse': syncedToLoyverse,
      if (optionName != null) 'option_name': optionName,
      if (optionValue != null) 'option_value': optionValue,
      if (loyverseItemId != null) 'loyverse_item_id': loyverseItemId,
      if (loyverseVariantId != null) 'loyverse_variant_id': loyverseVariantId,
      if (groupId != null) 'group_id': groupId,
      if (importSource != null) 'import_source': importSource,
      if (importBatchId != null) 'import_batch_id': importBatchId,
    });
  }

  ProductsCompanion copyWith({
    Value<int>? id,
    Value<String?>? barcode,
    Value<String?>? sku,
    Value<String>? name,
    Value<String?>? category,
    Value<String?>? description,
    Value<double?>? costPrice,
    Value<double?>? sellPrice,
    Value<int>? quantity,
    Value<String?>? photoPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? syncedToLoyverse,
    Value<String?>? optionName,
    Value<String?>? optionValue,
    Value<String?>? loyverseItemId,
    Value<String?>? loyverseVariantId,
    Value<String?>? groupId,
    Value<String?>? importSource,
    Value<String?>? importBatchId,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      quantity: quantity ?? this.quantity,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedToLoyverse: syncedToLoyverse ?? this.syncedToLoyverse,
      optionName: optionName ?? this.optionName,
      optionValue: optionValue ?? this.optionValue,
      loyverseItemId: loyverseItemId ?? this.loyverseItemId,
      loyverseVariantId: loyverseVariantId ?? this.loyverseVariantId,
      groupId: groupId ?? this.groupId,
      importSource: importSource ?? this.importSource,
      importBatchId: importBatchId ?? this.importBatchId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<double>(costPrice.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<double>(sellPrice.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedToLoyverse.present) {
      map['synced_to_loyverse'] = Variable<bool>(syncedToLoyverse.value);
    }
    if (optionName.present) {
      map['option_name'] = Variable<String>(optionName.value);
    }
    if (optionValue.present) {
      map['option_value'] = Variable<String>(optionValue.value);
    }
    if (loyverseItemId.present) {
      map['loyverse_item_id'] = Variable<String>(loyverseItemId.value);
    }
    if (loyverseVariantId.present) {
      map['loyverse_variant_id'] = Variable<String>(loyverseVariantId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (importSource.present) {
      map['import_source'] = Variable<String>(importSource.value);
    }
    if (importBatchId.present) {
      map['import_batch_id'] = Variable<String>(importBatchId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('barcode: $barcode, ')
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('costPrice: $costPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('quantity: $quantity, ')
          ..write('photoPath: $photoPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedToLoyverse: $syncedToLoyverse, ')
          ..write('optionName: $optionName, ')
          ..write('optionValue: $optionValue, ')
          ..write('loyverseItemId: $loyverseItemId, ')
          ..write('loyverseVariantId: $loyverseVariantId, ')
          ..write('groupId: $groupId, ')
          ..write('importSource: $importSource, ')
          ..write('importBatchId: $importBatchId')
          ..write(')'))
        .toString();
  }
}

class $BarcodeLookupCacheTable extends BarcodeLookupCache
    with TableInfo<$BarcodeLookupCacheTable, BarcodeLookupCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BarcodeLookupCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
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
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionCapaciteMeta = const VerificationMeta(
    'optionCapacite',
  );
  @override
  late final GeneratedColumn<String> optionCapacite = GeneratedColumn<String>(
    'option_capacite',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    barcode,
    source,
    name,
    category,
    description,
    sku,
    optionCapacite,
    imageUrl,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'barcode_lookup_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<BarcodeLookupCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    } else if (isInserting) {
      context.missing(_barcodeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
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
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('option_capacite')) {
      context.handle(
        _optionCapaciteMeta,
        optionCapacite.isAcceptableOrUnknown(
          data['option_capacite']!,
          _optionCapaciteMeta,
        ),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {barcode};
  @override
  BarcodeLookupCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BarcodeLookupCacheData(
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      optionCapacite: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_capacite'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $BarcodeLookupCacheTable createAlias(String alias) {
    return $BarcodeLookupCacheTable(attachedDatabase, alias);
  }
}

class BarcodeLookupCacheData extends DataClass
    implements Insertable<BarcodeLookupCacheData> {
  final String barcode;
  final String source;
  final String? name;
  final String? category;
  final String? description;
  final String? sku;
  final String? optionCapacite;
  final String? imageUrl;
  final DateTime fetchedAt;
  const BarcodeLookupCacheData({
    required this.barcode,
    required this.source,
    this.name,
    this.category,
    this.description,
    this.sku,
    this.optionCapacite,
    this.imageUrl,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['barcode'] = Variable<String>(barcode);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    if (!nullToAbsent || optionCapacite != null) {
      map['option_capacite'] = Variable<String>(optionCapacite);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  BarcodeLookupCacheCompanion toCompanion(bool nullToAbsent) {
    return BarcodeLookupCacheCompanion(
      barcode: Value(barcode),
      source: Value(source),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      optionCapacite: optionCapacite == null && nullToAbsent
          ? const Value.absent()
          : Value(optionCapacite),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory BarcodeLookupCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BarcodeLookupCacheData(
      barcode: serializer.fromJson<String>(json['barcode']),
      source: serializer.fromJson<String>(json['source']),
      name: serializer.fromJson<String?>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      description: serializer.fromJson<String?>(json['description']),
      sku: serializer.fromJson<String?>(json['sku']),
      optionCapacite: serializer.fromJson<String?>(json['optionCapacite']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'barcode': serializer.toJson<String>(barcode),
      'source': serializer.toJson<String>(source),
      'name': serializer.toJson<String?>(name),
      'category': serializer.toJson<String?>(category),
      'description': serializer.toJson<String?>(description),
      'sku': serializer.toJson<String?>(sku),
      'optionCapacite': serializer.toJson<String?>(optionCapacite),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  BarcodeLookupCacheData copyWith({
    String? barcode,
    String? source,
    Value<String?> name = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> sku = const Value.absent(),
    Value<String?> optionCapacite = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    DateTime? fetchedAt,
  }) => BarcodeLookupCacheData(
    barcode: barcode ?? this.barcode,
    source: source ?? this.source,
    name: name.present ? name.value : this.name,
    category: category.present ? category.value : this.category,
    description: description.present ? description.value : this.description,
    sku: sku.present ? sku.value : this.sku,
    optionCapacite: optionCapacite.present
        ? optionCapacite.value
        : this.optionCapacite,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  BarcodeLookupCacheData copyWithCompanion(BarcodeLookupCacheCompanion data) {
    return BarcodeLookupCacheData(
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      source: data.source.present ? data.source.value : this.source,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      sku: data.sku.present ? data.sku.value : this.sku,
      optionCapacite: data.optionCapacite.present
          ? data.optionCapacite.value
          : this.optionCapacite,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeLookupCacheData(')
          ..write('barcode: $barcode, ')
          ..write('source: $source, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('sku: $sku, ')
          ..write('optionCapacite: $optionCapacite, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    barcode,
    source,
    name,
    category,
    description,
    sku,
    optionCapacite,
    imageUrl,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BarcodeLookupCacheData &&
          other.barcode == this.barcode &&
          other.source == this.source &&
          other.name == this.name &&
          other.category == this.category &&
          other.description == this.description &&
          other.sku == this.sku &&
          other.optionCapacite == this.optionCapacite &&
          other.imageUrl == this.imageUrl &&
          other.fetchedAt == this.fetchedAt);
}

class BarcodeLookupCacheCompanion
    extends UpdateCompanion<BarcodeLookupCacheData> {
  final Value<String> barcode;
  final Value<String> source;
  final Value<String?> name;
  final Value<String?> category;
  final Value<String?> description;
  final Value<String?> sku;
  final Value<String?> optionCapacite;
  final Value<String?> imageUrl;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const BarcodeLookupCacheCompanion({
    this.barcode = const Value.absent(),
    this.source = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.sku = const Value.absent(),
    this.optionCapacite = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BarcodeLookupCacheCompanion.insert({
    required String barcode,
    required String source,
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.sku = const Value.absent(),
    this.optionCapacite = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : barcode = Value(barcode),
       source = Value(source);
  static Insertable<BarcodeLookupCacheData> custom({
    Expression<String>? barcode,
    Expression<String>? source,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? description,
    Expression<String>? sku,
    Expression<String>? optionCapacite,
    Expression<String>? imageUrl,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (barcode != null) 'barcode': barcode,
      if (source != null) 'source': source,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (sku != null) 'sku': sku,
      if (optionCapacite != null) 'option_capacite': optionCapacite,
      if (imageUrl != null) 'image_url': imageUrl,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BarcodeLookupCacheCompanion copyWith({
    Value<String>? barcode,
    Value<String>? source,
    Value<String?>? name,
    Value<String?>? category,
    Value<String?>? description,
    Value<String?>? sku,
    Value<String?>? optionCapacite,
    Value<String?>? imageUrl,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return BarcodeLookupCacheCompanion(
      barcode: barcode ?? this.barcode,
      source: source ?? this.source,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      optionCapacite: optionCapacite ?? this.optionCapacite,
      imageUrl: imageUrl ?? this.imageUrl,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (optionCapacite.present) {
      map['option_capacite'] = Variable<String>(optionCapacite.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeLookupCacheCompanion(')
          ..write('barcode: $barcode, ')
          ..write('source: $source, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('sku: $sku, ')
          ..write('optionCapacite: $optionCapacite, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LoyverseCacheTable extends LoyverseCache
    with TableInfo<$LoyverseCacheTable, LoyverseCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LoyverseCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cacheValueMeta = const VerificationMeta(
    'cacheValue',
  );
  @override
  late final GeneratedColumn<String> cacheValue = GeneratedColumn<String>(
    'cache_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, cacheValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'loyverse_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<LoyverseCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('cache_value')) {
      context.handle(
        _cacheValueMeta,
        cacheValue.isAcceptableOrUnknown(data['cache_value']!, _cacheValueMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  LoyverseCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LoyverseCacheData(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      cacheValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_value'],
      )!,
    );
  }

  @override
  $LoyverseCacheTable createAlias(String alias) {
    return $LoyverseCacheTable(attachedDatabase, alias);
  }
}

class LoyverseCacheData extends DataClass
    implements Insertable<LoyverseCacheData> {
  final String cacheKey;
  final String cacheValue;
  const LoyverseCacheData({required this.cacheKey, required this.cacheValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['cache_value'] = Variable<String>(cacheValue);
    return map;
  }

  LoyverseCacheCompanion toCompanion(bool nullToAbsent) {
    return LoyverseCacheCompanion(
      cacheKey: Value(cacheKey),
      cacheValue: Value(cacheValue),
    );
  }

  factory LoyverseCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LoyverseCacheData(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      cacheValue: serializer.fromJson<String>(json['cacheValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'cacheValue': serializer.toJson<String>(cacheValue),
    };
  }

  LoyverseCacheData copyWith({String? cacheKey, String? cacheValue}) =>
      LoyverseCacheData(
        cacheKey: cacheKey ?? this.cacheKey,
        cacheValue: cacheValue ?? this.cacheValue,
      );
  LoyverseCacheData copyWithCompanion(LoyverseCacheCompanion data) {
    return LoyverseCacheData(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      cacheValue: data.cacheValue.present
          ? data.cacheValue.value
          : this.cacheValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LoyverseCacheData(')
          ..write('cacheKey: $cacheKey, ')
          ..write('cacheValue: $cacheValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, cacheValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoyverseCacheData &&
          other.cacheKey == this.cacheKey &&
          other.cacheValue == this.cacheValue);
}

class LoyverseCacheCompanion extends UpdateCompanion<LoyverseCacheData> {
  final Value<String> cacheKey;
  final Value<String> cacheValue;
  final Value<int> rowid;
  const LoyverseCacheCompanion({
    this.cacheKey = const Value.absent(),
    this.cacheValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LoyverseCacheCompanion.insert({
    required String cacheKey,
    required String cacheValue,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       cacheValue = Value(cacheValue);
  static Insertable<LoyverseCacheData> custom({
    Expression<String>? cacheKey,
    Expression<String>? cacheValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (cacheValue != null) 'cache_value': cacheValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LoyverseCacheCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? cacheValue,
    Value<int>? rowid,
  }) {
    return LoyverseCacheCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      cacheValue: cacheValue ?? this.cacheValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (cacheValue.present) {
      map['cache_value'] = Variable<String>(cacheValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LoyverseCacheCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('cacheValue: $cacheValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $BarcodeLookupCacheTable barcodeLookupCache =
      $BarcodeLookupCacheTable(this);
  late final $LoyverseCacheTable loyverseCache = $LoyverseCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    products,
    barcodeLookupCache,
    loyverseCache,
  ];
}

typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      Value<String?> barcode,
      Value<String?> sku,
      required String name,
      Value<String?> category,
      Value<String?> description,
      Value<double?> costPrice,
      Value<double?> sellPrice,
      Value<int> quantity,
      Value<String?> photoPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> syncedToLoyverse,
      Value<String?> optionName,
      Value<String?> optionValue,
      Value<String?> loyverseItemId,
      Value<String?> loyverseVariantId,
      Value<String?> groupId,
      Value<String?> importSource,
      Value<String?> importBatchId,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      Value<String?> barcode,
      Value<String?> sku,
      Value<String> name,
      Value<String?> category,
      Value<String?> description,
      Value<double?> costPrice,
      Value<double?> sellPrice,
      Value<int> quantity,
      Value<String?> photoPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> syncedToLoyverse,
      Value<String?> optionName,
      Value<String?> optionValue,
      Value<String?> loyverseItemId,
      Value<String?> loyverseVariantId,
      Value<String?> groupId,
      Value<String?> importSource,
      Value<String?> importBatchId,
    });

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
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

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncedToLoyverse => $composableBuilder(
    column: $table.syncedToLoyverse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionValue => $composableBuilder(
    column: $table.optionValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loyverseItemId => $composableBuilder(
    column: $table.loyverseItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loyverseVariantId => $composableBuilder(
    column: $table.loyverseVariantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importSource => $composableBuilder(
    column: $table.importSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importBatchId => $composableBuilder(
    column: $table.importBatchId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
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

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncedToLoyverse => $composableBuilder(
    column: $table.syncedToLoyverse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionValue => $composableBuilder(
    column: $table.optionValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loyverseItemId => $composableBuilder(
    column: $table.loyverseItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loyverseVariantId => $composableBuilder(
    column: $table.loyverseVariantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSource => $composableBuilder(
    column: $table.importSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importBatchId => $composableBuilder(
    column: $table.importBatchId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<double> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get syncedToLoyverse => $composableBuilder(
    column: $table.syncedToLoyverse,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionValue => $composableBuilder(
    column: $table.optionValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loyverseItemId => $composableBuilder(
    column: $table.loyverseItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loyverseVariantId => $composableBuilder(
    column: $table.loyverseVariantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get importSource => $composableBuilder(
    column: $table.importSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importBatchId => $composableBuilder(
    column: $table.importBatchId,
    builder: (column) => column,
  );
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
          Product,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> costPrice = const Value.absent(),
                Value<double?> sellPrice = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> syncedToLoyverse = const Value.absent(),
                Value<String?> optionName = const Value.absent(),
                Value<String?> optionValue = const Value.absent(),
                Value<String?> loyverseItemId = const Value.absent(),
                Value<String?> loyverseVariantId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> importSource = const Value.absent(),
                Value<String?> importBatchId = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                barcode: barcode,
                sku: sku,
                name: name,
                category: category,
                description: description,
                costPrice: costPrice,
                sellPrice: sellPrice,
                quantity: quantity,
                photoPath: photoPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedToLoyverse: syncedToLoyverse,
                optionName: optionName,
                optionValue: optionValue,
                loyverseItemId: loyverseItemId,
                loyverseVariantId: loyverseVariantId,
                groupId: groupId,
                importSource: importSource,
                importBatchId: importBatchId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                required String name,
                Value<String?> category = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> costPrice = const Value.absent(),
                Value<double?> sellPrice = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> syncedToLoyverse = const Value.absent(),
                Value<String?> optionName = const Value.absent(),
                Value<String?> optionValue = const Value.absent(),
                Value<String?> loyverseItemId = const Value.absent(),
                Value<String?> loyverseVariantId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> importSource = const Value.absent(),
                Value<String?> importBatchId = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                barcode: barcode,
                sku: sku,
                name: name,
                category: category,
                description: description,
                costPrice: costPrice,
                sellPrice: sellPrice,
                quantity: quantity,
                photoPath: photoPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedToLoyverse: syncedToLoyverse,
                optionName: optionName,
                optionValue: optionValue,
                loyverseItemId: loyverseItemId,
                loyverseVariantId: loyverseVariantId,
                groupId: groupId,
                importSource: importSource,
                importBatchId: importBatchId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductsTable, Product>(table),
                  BaseReferences<_$AppDatabase, $ProductsTable, Product>(
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

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
      Product,
      PrefetchHooks Function()
    >;
typedef $$BarcodeLookupCacheTableCreateCompanionBuilder =
    BarcodeLookupCacheCompanion Function({
      required String barcode,
      required String source,
      Value<String?> name,
      Value<String?> category,
      Value<String?> description,
      Value<String?> sku,
      Value<String?> optionCapacite,
      Value<String?> imageUrl,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });
typedef $$BarcodeLookupCacheTableUpdateCompanionBuilder =
    BarcodeLookupCacheCompanion Function({
      Value<String> barcode,
      Value<String> source,
      Value<String?> name,
      Value<String?> category,
      Value<String?> description,
      Value<String?> sku,
      Value<String?> optionCapacite,
      Value<String?> imageUrl,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$BarcodeLookupCacheTableFilterComposer
    extends Composer<_$AppDatabase, $BarcodeLookupCacheTable> {
  $$BarcodeLookupCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionCapacite => $composableBuilder(
    column: $table.optionCapacite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BarcodeLookupCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $BarcodeLookupCacheTable> {
  $$BarcodeLookupCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionCapacite => $composableBuilder(
    column: $table.optionCapacite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BarcodeLookupCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $BarcodeLookupCacheTable> {
  $$BarcodeLookupCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get optionCapacite => $composableBuilder(
    column: $table.optionCapacite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$BarcodeLookupCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BarcodeLookupCacheTable,
          BarcodeLookupCacheData,
          $$BarcodeLookupCacheTableFilterComposer,
          $$BarcodeLookupCacheTableOrderingComposer,
          $$BarcodeLookupCacheTableAnnotationComposer,
          $$BarcodeLookupCacheTableCreateCompanionBuilder,
          $$BarcodeLookupCacheTableUpdateCompanionBuilder,
          (
            BarcodeLookupCacheData,
            BaseReferences<
              _$AppDatabase,
              $BarcodeLookupCacheTable,
              BarcodeLookupCacheData
            >,
          ),
          BarcodeLookupCacheData,
          PrefetchHooks Function()
        > {
  $$BarcodeLookupCacheTableTableManager(
    _$AppDatabase db,
    $BarcodeLookupCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BarcodeLookupCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BarcodeLookupCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BarcodeLookupCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> barcode = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String?> optionCapacite = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BarcodeLookupCacheCompanion(
                barcode: barcode,
                source: source,
                name: name,
                category: category,
                description: description,
                sku: sku,
                optionCapacite: optionCapacite,
                imageUrl: imageUrl,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String barcode,
                required String source,
                Value<String?> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String?> optionCapacite = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BarcodeLookupCacheCompanion.insert(
                barcode: barcode,
                source: source,
                name: name,
                category: category,
                description: description,
                sku: sku,
                optionCapacite: optionCapacite,
                imageUrl: imageUrl,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BarcodeLookupCacheTable, BarcodeLookupCacheData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $BarcodeLookupCacheTable,
                    BarcodeLookupCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BarcodeLookupCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BarcodeLookupCacheTable,
      BarcodeLookupCacheData,
      $$BarcodeLookupCacheTableFilterComposer,
      $$BarcodeLookupCacheTableOrderingComposer,
      $$BarcodeLookupCacheTableAnnotationComposer,
      $$BarcodeLookupCacheTableCreateCompanionBuilder,
      $$BarcodeLookupCacheTableUpdateCompanionBuilder,
      (
        BarcodeLookupCacheData,
        BaseReferences<
          _$AppDatabase,
          $BarcodeLookupCacheTable,
          BarcodeLookupCacheData
        >,
      ),
      BarcodeLookupCacheData,
      PrefetchHooks Function()
    >;
typedef $$LoyverseCacheTableCreateCompanionBuilder =
    LoyverseCacheCompanion Function({
      required String cacheKey,
      required String cacheValue,
      Value<int> rowid,
    });
typedef $$LoyverseCacheTableUpdateCompanionBuilder =
    LoyverseCacheCompanion Function({
      Value<String> cacheKey,
      Value<String> cacheValue,
      Value<int> rowid,
    });

class $$LoyverseCacheTableFilterComposer
    extends Composer<_$AppDatabase, $LoyverseCacheTable> {
  $$LoyverseCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cacheValue => $composableBuilder(
    column: $table.cacheValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LoyverseCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $LoyverseCacheTable> {
  $$LoyverseCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cacheValue => $composableBuilder(
    column: $table.cacheValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LoyverseCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $LoyverseCacheTable> {
  $$LoyverseCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get cacheValue => $composableBuilder(
    column: $table.cacheValue,
    builder: (column) => column,
  );
}

class $$LoyverseCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LoyverseCacheTable,
          LoyverseCacheData,
          $$LoyverseCacheTableFilterComposer,
          $$LoyverseCacheTableOrderingComposer,
          $$LoyverseCacheTableAnnotationComposer,
          $$LoyverseCacheTableCreateCompanionBuilder,
          $$LoyverseCacheTableUpdateCompanionBuilder,
          (
            LoyverseCacheData,
            BaseReferences<
              _$AppDatabase,
              $LoyverseCacheTable,
              LoyverseCacheData
            >,
          ),
          LoyverseCacheData,
          PrefetchHooks Function()
        > {
  $$LoyverseCacheTableTableManager(_$AppDatabase db, $LoyverseCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LoyverseCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LoyverseCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LoyverseCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> cacheValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LoyverseCacheCompanion(
                cacheKey: cacheKey,
                cacheValue: cacheValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String cacheValue,
                Value<int> rowid = const Value.absent(),
              }) => LoyverseCacheCompanion.insert(
                cacheKey: cacheKey,
                cacheValue: cacheValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LoyverseCacheTable, LoyverseCacheData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LoyverseCacheTable,
                    LoyverseCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LoyverseCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LoyverseCacheTable,
      LoyverseCacheData,
      $$LoyverseCacheTableFilterComposer,
      $$LoyverseCacheTableOrderingComposer,
      $$LoyverseCacheTableAnnotationComposer,
      $$LoyverseCacheTableCreateCompanionBuilder,
      $$LoyverseCacheTableUpdateCompanionBuilder,
      (
        LoyverseCacheData,
        BaseReferences<_$AppDatabase, $LoyverseCacheTable, LoyverseCacheData>,
      ),
      LoyverseCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$BarcodeLookupCacheTableTableManager get barcodeLookupCache =>
      $$BarcodeLookupCacheTableTableManager(_db, _db.barcodeLookupCache);
  $$LoyverseCacheTableTableManager get loyverseCache =>
      $$LoyverseCacheTableTableManager(_db, _db.loyverseCache);
}
