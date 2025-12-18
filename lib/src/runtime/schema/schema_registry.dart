/// Schema Registry for Prisma models and relations.
///
/// This module stores metadata about Prisma models, their fields, and relations.
/// The code generator produces a populated SchemaRegistry that the runtime uses
/// to compile JOIN queries and deserialize nested results.
///
/// Example generated code:
/// ```dart
/// final registry = SchemaRegistry()
///   ..registerModel(ModelSchema(
///     name: 'User',
///     tableName: 'users',
///     fields: {
///       'id': FieldInfo(name: 'id', columnName: 'id', type: 'String', isId: true),
///       'email': FieldInfo(name: 'email', columnName: 'email', type: 'String'),
///     },
///     relations: {
///       'posts': RelationInfo(
///         name: 'posts',
///         type: RelationType.oneToMany,
///         targetModel: 'Post',
///         foreignKey: 'author_id',
///         references: ['id'],
///       ),
///     },
///   ));
/// ```
library;

/// Global schema registry instance.
///
/// This is populated by generated code at startup.
final schemaRegistry = SchemaRegistry();

/// Registry that stores model schemas and provides lookup methods.
class SchemaRegistry {
  final Map<String, ModelSchema> _models = {};

  /// Register a model schema.
  void registerModel(ModelSchema schema) {
    _models[schema.name] = schema;
  }

  /// Get a model schema by name.
  ModelSchema? getModel(String name) => _models[name];

  /// Get relation info for a model's field.
  RelationInfo? getRelation(String modelName, String fieldName) {
    return _models[modelName]?.relations[fieldName];
  }

  /// Get all relations for a model.
  Map<String, RelationInfo> getRelations(String modelName) {
    return _models[modelName]?.relations ?? {};
  }

  /// Get field info for a model's field.
  FieldInfo? getField(String modelName, String fieldName) {
    return _models[modelName]?.fields[fieldName];
  }

  /// Get the primary key field(s) for a model.
  List<FieldInfo> getPrimaryKeys(String modelName) {
    final model = _models[modelName];
    if (model == null) return [];

    return model.fields.values.where((f) => f.isId).toList();
  }

  /// Get table name for a model.
  String? getTableName(String modelName) {
    return _models[modelName]?.tableName;
  }

  /// Check if a model exists.
  bool hasModel(String name) => _models.containsKey(name);

  /// Get all registered model names.
  List<String> get modelNames => _models.keys.toList();

  /// Clear all registered models (useful for testing).
  void clear() => _models.clear();
}

/// Schema definition for a Prisma model.
class ModelSchema {
  /// The model name (e.g., 'User', 'Post').
  final String name;

  /// The database table name (e.g., 'users', 'posts').
  final String tableName;

  /// Field definitions mapped by field name.
  final Map<String, FieldInfo> fields;

  /// Relation definitions mapped by relation field name.
  final Map<String, RelationInfo> relations;

  const ModelSchema({
    required this.name,
    required this.tableName,
    required this.fields,
    this.relations = const {},
  });

  /// Get the primary key field(s).
  List<FieldInfo> get primaryKeys =>
      fields.values.where((f) => f.isId).toList();

  /// Get all scalar (non-relation) fields.
  List<FieldInfo> get scalarFields =>
      fields.values.where((f) => !f.isRelation).toList();

  /// Get all column names for SELECT.
  List<String> get columnNames =>
      scalarFields.map((f) => f.columnName).toList();
}

/// Information about a model field.
class FieldInfo {
  /// The field name in Dart (e.g., 'userId').
  final String name;

  /// The column name in the database (e.g., 'user_id').
  final String columnName;

  /// The Dart type (e.g., 'String', 'int', 'DateTime').
  final String type;

  /// Whether this field is a primary key.
  final bool isId;

  /// Whether this field is a unique key.
  final bool isUnique;

  /// Whether this field is nullable.
  final bool isNullable;

  /// Whether this field is a relation (not stored in DB).
  final bool isRelation;

  /// Default value expression (if any).
  final String? defaultValue;

  const FieldInfo({
    required this.name,
    required this.columnName,
    required this.type,
    this.isId = false,
    this.isUnique = false,
    this.isNullable = false,
    this.isRelation = false,
    this.defaultValue,
  });

  /// Create a field for the primary key.
  factory FieldInfo.id({
    required String name,
    String? columnName,
    String type = 'String',
  }) {
    return FieldInfo(
      name: name,
      columnName: columnName ?? name,
      type: type,
      isId: true,
    );
  }
}

/// Types of relations between models.
enum RelationType {
  /// One record relates to exactly one other record (1:1).
  oneToOne,

  /// One record relates to many other records (1:N).
  oneToMany,

  /// Many records relate to one other record (N:1).
  manyToOne,

  /// Many records relate to many other records (M:N).
  manyToMany,
}

/// Information about a relation between models.
class RelationInfo {
  /// The relation field name (e.g., 'posts', 'author').
  final String name;

  /// The type of relation.
  final RelationType type;

  /// The target model name (e.g., 'Post', 'User').
  final String targetModel;

  /// The foreign key field(s) on the relation side.
  /// For oneToMany: FK is on the target model (e.g., 'author_id' on Post).
  /// For manyToOne: FK is on this model (e.g., 'author_id' on Post).
  final String foreignKey;

  /// The field(s) that the foreign key references (usually the primary key).
  final List<String> references;

  /// For many-to-many: the join table name.
  final String? joinTable;

  /// For many-to-many: the column in join table referencing this model.
  final String? joinColumn;

  /// For many-to-many: the column in join table referencing target model.
  final String? inverseJoinColumn;

  /// The inverse relation name on the target model (if defined).
  final String? inverseRelation;

  /// Whether this is the "owner" side of the relation.
  /// The owner side holds the foreign key or is the side specified in @relation.
  final bool isOwner;

  const RelationInfo({
    required this.name,
    required this.type,
    required this.targetModel,
    required this.foreignKey,
    this.references = const ['id'],
    this.joinTable,
    this.joinColumn,
    this.inverseJoinColumn,
    this.inverseRelation,
    this.isOwner = false,
  });

  /// Create a one-to-one relation.
  factory RelationInfo.oneToOne({
    required String name,
    required String targetModel,
    required String foreignKey,
    List<String> references = const ['id'],
    String? inverseRelation,
    bool isOwner = false,
  }) {
    return RelationInfo(
      name: name,
      type: RelationType.oneToOne,
      targetModel: targetModel,
      foreignKey: foreignKey,
      references: references,
      inverseRelation: inverseRelation,
      isOwner: isOwner,
    );
  }

  /// Create a one-to-many relation (this model has many of target).
  factory RelationInfo.oneToMany({
    required String name,
    required String targetModel,
    required String foreignKey,
    List<String> references = const ['id'],
    String? inverseRelation,
  }) {
    return RelationInfo(
      name: name,
      type: RelationType.oneToMany,
      targetModel: targetModel,
      foreignKey: foreignKey,
      references: references,
      inverseRelation: inverseRelation,
      isOwner: false, // One side doesn't own FK
    );
  }

  /// Create a many-to-one relation (this model belongs to target).
  factory RelationInfo.manyToOne({
    required String name,
    required String targetModel,
    required String foreignKey,
    List<String> references = const ['id'],
    String? inverseRelation,
  }) {
    return RelationInfo(
      name: name,
      type: RelationType.manyToOne,
      targetModel: targetModel,
      foreignKey: foreignKey,
      references: references,
      inverseRelation: inverseRelation,
      isOwner: true, // Many side owns the FK
    );
  }

  /// Create a many-to-many relation.
  factory RelationInfo.manyToMany({
    required String name,
    required String targetModel,
    required String joinTable,
    required String joinColumn,
    required String inverseJoinColumn,
    String? inverseRelation,
    bool isOwner = false,
  }) {
    return RelationInfo(
      name: name,
      type: RelationType.manyToMany,
      targetModel: targetModel,
      foreignKey: '', // Not applicable for M:N
      joinTable: joinTable,
      joinColumn: joinColumn,
      inverseJoinColumn: inverseJoinColumn,
      inverseRelation: inverseRelation,
      isOwner: isOwner,
    );
  }

  /// Whether this relation requires a JOIN to fetch.
  bool get requiresJoin =>
      type == RelationType.oneToMany ||
      type == RelationType.manyToMany ||
      type == RelationType.oneToOne;

  /// Whether this is a "to-many" relation.
  bool get isToMany =>
      type == RelationType.oneToMany || type == RelationType.manyToMany;

  /// Whether this is a "to-one" relation.
  bool get isToOne =>
      type == RelationType.oneToOne || type == RelationType.manyToOne;
}

/// Extension methods for building relation metadata.
extension SchemaRegistryBuilder on SchemaRegistry {
  /// Fluent API for registering a model.
  SchemaRegistry model(
    String name, {
    String? tableName,
    required Map<String, FieldInfo> fields,
    Map<String, RelationInfo> relations = const {},
  }) {
    registerModel(ModelSchema(
      name: name,
      tableName: tableName ?? _toSnakeCase(name),
      fields: fields,
      relations: relations,
    ));
    return this;
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }
}
