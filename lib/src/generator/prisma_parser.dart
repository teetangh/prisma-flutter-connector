/// Prisma schema parser
///
/// Parses `.prisma` schema files and extracts models, fields, relations, and enums.
/// Validates schema against Dart reserved keywords and naming conventions.
library;

/// Dart reserved keywords that cannot be used as identifiers
/// Must match Dart language specification
const dartReservedKeywords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'rethrow',
  'return',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

/// Generator error for schema validation failures
class GeneratorError implements Exception {
  final String message;
  final String? suggestion;
  final int? line;

  GeneratorError(this.message, {this.suggestion, this.line});

  @override
  String toString() {
    final buffer = StringBuffer('❌ Generator Error: $message');
    if (line != null) buffer.write('\n   Location: line $line');
    if (suggestion != null) buffer.write('\n   Suggestion: $suggestion');
    return buffer.toString();
  }
}

class PrismaSchema {
  final List<PrismaModel> models;
  final List<PrismaEnum> enums;
  final String datasourceProvider;

  const PrismaSchema({
    required this.models,
    required this.enums,
    required this.datasourceProvider,
  });
}

class PrismaModel {
  final String name;
  final String?
      dbName; // Original table name if renamed due to reserved keyword
  final List<PrismaField> fields;
  final List<PrismaRelation> relations;

  const PrismaModel({
    required this.name,
    this.dbName,
    required this.fields,
    required this.relations,
  });

  /// Get the database table name (original name if renamed, otherwise model name)
  String get tableName => dbName ?? name;
}

class PrismaField {
  final String name;
  final String type;
  final bool isRequired;
  final bool isList;
  final bool isId;
  final bool isUnique;
  final String? defaultValue;
  final bool isUpdatedAt;
  final bool isCreatedAt;
  final bool isRelation;
  final String? dbName;
  final bool hasEmptyListDefault;
  final String? relationName;
  final List<String>? relationFromFields;
  final List<String>? relationToFields;

  const PrismaField({
    required this.name,
    required this.type,
    this.isRequired = false,
    this.isList = false,
    this.isId = false,
    this.isUnique = false,
    this.defaultValue,
    this.isUpdatedAt = false,
    this.isCreatedAt = false,
    this.isRelation = false,
    this.dbName,
    this.hasEmptyListDefault = false,
    this.relationName,
    this.relationFromFields,
    this.relationToFields,
  });

  /// Get the Dart type for this field
  String get dartType {
    String baseType;

    switch (type) {
      case 'String':
        baseType = 'String';
        break;
      case 'Int':
        baseType = 'int';
        break;
      case 'Float':
      case 'Decimal':
        baseType = 'double';
        break;
      case 'Boolean':
        baseType = 'bool';
        break;
      case 'DateTime':
        baseType = 'DateTime';
        break;
      case 'Json':
        baseType = 'Map<String, dynamic>';
        break;
      case 'Bytes':
        baseType = 'List<int>';
        break;
      default:
        // Enum or relation type
        baseType = type;
    }

    if (isList) {
      baseType = 'List<$baseType>';
    }

    if (!isRequired && !isList) {
      baseType = '$baseType?';
    }

    return baseType;
  }

  /// Get the GraphQL type for this field
  String get graphQLType {
    String baseType;

    switch (type) {
      case 'String':
        baseType = 'String';
        break;
      case 'Int':
        baseType = 'Int';
        break;
      case 'Float':
      case 'Decimal':
        baseType = 'Float';
        break;
      case 'Boolean':
        baseType = 'Boolean';
        break;
      case 'DateTime':
        baseType = 'DateTime';
        break;
      case 'Json':
        baseType = 'JSON';
        break;
      default:
        baseType = type;
    }

    if (isList) {
      baseType = '[$baseType!]';
    }

    if (isRequired && !isList) {
      baseType = '$baseType!';
    }

    return baseType;
  }
}

class PrismaRelation {
  final String name;
  final String targetModel;
  final String relationName;
  final List<String> fields;
  final List<String> references;

  const PrismaRelation({
    required this.name,
    required this.targetModel,
    required this.relationName,
    required this.fields,
    required this.references,
  });
}

class PrismaEnum {
  final String name;
  final List<String> values;

  const PrismaEnum({
    required this.name,
    required this.values,
  });
}

/// Result of handling a reserved keyword
class ReservedKeywordResult {
  final String dartName;
  final String? dbName; // Original name if renamed
  final String? warning; // Warning message if renamed

  const ReservedKeywordResult({
    required this.dartName,
    this.dbName,
    this.warning,
  });

  bool get wasRenamed => dbName != null;
}

/// Parse a Prisma schema file
class PrismaParser {
  /// Warnings generated during parsing (e.g., reserved keyword renames)
  final List<String> warnings = [];

  /// Field name mappings for reserved keywords (static const for performance)
  static const Map<String, String> _fieldMappings = {
    'class': 'classRef',
    'enum': 'enumValue',
    'type': 'typeValue',
    'default': 'defaultValue',
    'static': 'staticValue',
    'final': 'finalValue',
    'const': 'constValue',
    'void': 'voidValue',
    'return': 'returnValue',
    'continue': 'continueFlag',
    'break': 'breakFlag',
    'switch': 'switchValue',
    'case': 'caseValue',
    'new': 'newValue',
    'null': 'nullValue',
    'true': 'trueValue',
    'false': 'falseValue',
    'is': 'isValue',
    'in': 'inValue',
    'as': 'asValue',
    'if': 'ifValue',
    'else': 'elseValue',
    'for': 'forValue',
    'do': 'doValue',
    'while': 'whileValue',
    'try': 'tryValue',
    'catch': 'catchValue',
    'throw': 'throwValue',
    'this': 'thisRef',
    'super': 'superRef',
    'with': 'withValue',
    'get': 'getValue',
    'set': 'setValue',
    'var': 'varValue',
    'late': 'lateValue',
    'import': 'importValue',
    'export': 'exportValue',
    'part': 'partValue',
    'library': 'libraryValue',
    'abstract': 'abstractValue',
    'extends': 'extendsValue',
    'implements': 'implementsValue',
    'mixin': 'mixinValue',
    'interface': 'interfaceValue',
    'factory': 'factoryValue',
    'operator': 'operatorValue',
    'typedef': 'typedefValue',
    'dynamic': 'dynamicValue',
    'covariant': 'covariantValue',
    'function': 'functionValue',
    'async': 'asyncValue',
    'await': 'awaitValue',
    'sync': 'syncValue',
    'yield': 'yieldValue',
    'assert': 'assertValue',
    'rethrow': 'rethrowValue',
    'required': 'requiredValue',
    'on': 'onValue',
    'show': 'showValue',
    'hide': 'hideValue',
    'deferred': 'deferredValue',
    'external': 'externalValue',
    'extension': 'extensionValue',
  };

  /// Normalize field name to Dart camelCase convention
  /// If field starts with uppercase, convert to camelCase and return dbName
  String _normalizeFieldName(String fieldName) {
    if (fieldName.isEmpty) return fieldName;
    // Check if first character is uppercase
    if (fieldName[0] == fieldName[0].toUpperCase() &&
        fieldName[0] != fieldName[0].toLowerCase()) {
      // PascalCase → camelCase
      return fieldName[0].toLowerCase() + fieldName.substring(1);
    }
    return fieldName;
  }

  /// Check if name is a reserved Dart keyword and auto-rename if needed
  /// Returns the (possibly renamed) identifier and original name for @map
  ReservedKeywordResult _handleReservedKeyword(String name, String type) {
    if (!dartReservedKeywords.contains(name.toLowerCase())) {
      return ReservedKeywordResult(dartName: name);
    }

    // Auto-rename based on type
    String renamedName;
    if (type == 'model') {
      renamedName = _getAutoRenamedModel(name);
    } else {
      renamedName = _getAutoRenamedField(name);
    }

    final warning =
        '⚠️  Reserved keyword "$name" auto-renamed to "$renamedName" '
        '(database mapping preserved via ${type == 'model' ? '@@map' : '@map'}("$name"))';

    return ReservedKeywordResult(
      dartName: renamedName,
      dbName: name,
      warning: warning,
    );
  }

  /// Get auto-renamed model name for a reserved keyword
  /// Uses "Model" suffix as the standard pattern
  String _getAutoRenamedModel(String name) {
    final capitalized = name[0].toUpperCase() + name.substring(1);
    return '${capitalized}Model';
  }

  /// Get auto-renamed field name for a reserved keyword
  /// Uses "Ref" suffix for relation-like fields, "Value" for others
  String _getAutoRenamedField(String name) {
    final lowerName = name.toLowerCase();

    if (_fieldMappings.containsKey(lowerName)) {
      return _fieldMappings[lowerName]!;
    }

    // Generic fallback: append "Value"
    return '${name}Value';
  }

  /// Parse schema content from a string
  PrismaSchema parse(String schemaContent) {
    final models = <PrismaModel>[];
    final enums = <PrismaEnum>[];
    String datasourceProvider = 'postgresql'; // default

    // Extract datasource provider
    final datasourceMatch =
        RegExp(r'datasource\s+\w+\s*\{[^}]*provider\s*=\s*"([^"]+)"')
            .firstMatch(schemaContent);
    if (datasourceMatch != null) {
      datasourceProvider = datasourceMatch.group(1)!;
    }

    // Extract enums
    final enumPattern = RegExp(r'enum\s+(\w+)\s*\{([^}]+)\}', multiLine: true);
    for (final match in enumPattern.allMatches(schemaContent)) {
      final name = match.group(1)!;
      final body = match.group(2)!;
      final values = body
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('//'))
          .toList();

      enums.add(PrismaEnum(name: name, values: values));
    }

    // Track model name mappings for relation type resolution
    final modelNameMap = <String, String>{}; // originalName -> dartName

    // First pass: collect all model name mappings
    final modelPattern =
        RegExp(r'model\s+(\w+)\s*\{([^}]+)\}', multiLine: true);
    for (final match in modelPattern.allMatches(schemaContent)) {
      final originalModelName = match.group(1)!;
      final modelResult = _handleReservedKeyword(originalModelName, 'model');
      modelNameMap[originalModelName] = modelResult.dartName;
    }

    // Second pass: parse models with resolved type names
    for (final match in modelPattern.allMatches(schemaContent)) {
      final originalModelName = match.group(1)!;
      final modelBody = match.group(2)!;

      // Handle reserved keywords - auto-rename if needed
      final modelResult = _handleReservedKeyword(originalModelName, 'model');
      final modelName = modelResult.dartName;
      final modelDbName = modelResult.dbName;

      if (modelResult.warning != null) {
        warnings.add(modelResult.warning!);
      }

      final fields = <PrismaField>[];
      final relations = <PrismaRelation>[];

      // Parse each line in the model
      for (final line in modelBody.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('//') ||
            trimmed.startsWith('@@')) {
          continue;
        }

        // Parse field
        final fieldMatch =
            RegExp(r'^(\w+)\s+([\w\[\]?]+)(.*)$').firstMatch(trimmed);
        if (fieldMatch != null) {
          final schemaFieldName = fieldMatch.group(1)!;
          var fieldType = fieldMatch.group(2)!;
          final attributes = fieldMatch.group(3) ?? '';

          // Handle reserved keywords - auto-rename if needed
          final fieldResult = _handleReservedKeyword(schemaFieldName, 'field');
          final dartFieldName = fieldResult.dartName;
          final fieldDbName = fieldResult.dbName;

          if (fieldResult.warning != null) {
            warnings.add(fieldResult.warning!);
          }

          // Detect list type
          final isList = fieldType.contains('[]');
          if (isList) {
            fieldType = fieldType.replaceAll('[]', '');
          }

          // Detect optional type
          final isRequired = !fieldType.endsWith('?');
          if (fieldType.endsWith('?')) {
            fieldType = fieldType.substring(0, fieldType.length - 1);
          }

          final isId = attributes.contains('@id');
          final isUnique = attributes.contains('@unique');
          final isUpdatedAt = attributes.contains('@updatedAt');
          final isCreatedAt = attributes.contains('@default(now())');

          // Extract default value using balanced parentheses parser
          String? defaultValue;
          bool hasEmptyListDefault = false;
          final defaultStr = _extractDefaultValue(attributes);
          if (defaultStr != null) {
            if (defaultStr == '[]') {
              hasEmptyListDefault = true;
            } else {
              defaultValue = defaultStr;
            }
          }

          // Check if it's a relation
          final isRelation = attributes.contains('@relation');
          String? relationName;
          List<String>? relationFromFields;
          List<String>? relationToFields;

          if (isRelation) {
            // Parse relation metadata
            final relationMatch =
                RegExp(r'@relation\(([^)]*)\)').firstMatch(attributes);
            if (relationMatch != null) {
              final relationContent = relationMatch.group(1)!;

              // Extract relation name (first unnamed string in quotes)
              final nameMatch =
                  RegExp(r'^"([^"]+)"').firstMatch(relationContent.trim());
              if (nameMatch != null) {
                relationName = nameMatch.group(1);
              }

              // Extract fields: [field1, field2]
              final fieldsMatch =
                  RegExp(r'fields:\s*\[([^\]]*)\]').firstMatch(relationContent);
              if (fieldsMatch != null) {
                relationFromFields = fieldsMatch
                    .group(1)!
                    .split(',')
                    .map((f) => f.trim().replaceAll(RegExp(r'["\[\]]'), ''))
                    .where((f) => f.isNotEmpty)
                    .toList();
              }

              // Extract references: [field1, field2]
              final referencesMatch = RegExp(r'references:\s*\[([^\]]*)\]')
                  .firstMatch(relationContent);
              if (referencesMatch != null) {
                relationToFields = referencesMatch
                    .group(1)!
                    .split(',')
                    .map((f) => f.trim().replaceAll(RegExp(r'["\[\]]'), ''))
                    .where((f) => f.isNotEmpty)
                    .toList();
              }

              // Resolve target model type to potentially renamed type
              final resolvedTargetModel = modelNameMap[fieldType] ?? fieldType;

              // Add to relations list (for backward compatibility)
              relations.add(PrismaRelation(
                name: dartFieldName,
                targetModel: resolvedTargetModel,
                relationName: relationName ?? '',
                fields: relationFromFields ?? [],
                references: relationToFields ?? [],
              ));
            }
          }

          // Resolve field type to potentially renamed model type
          final resolvedFieldType = modelNameMap[fieldType] ?? fieldType;

          // Normalize field name (PascalCase → camelCase)
          final normalizedName = _normalizeFieldName(dartFieldName);

          // Determine dbName: prioritize reserved keyword rename, then PascalCase normalization
          String? dbName;
          if (fieldDbName != null) {
            // Field was renamed due to reserved keyword
            dbName = fieldDbName;
          } else if (normalizedName != dartFieldName) {
            // Field was normalized from PascalCase
            dbName = schemaFieldName;
          }

          // Add field (including relation fields for generator access)
          fields.add(PrismaField(
            name: normalizedName,
            type: resolvedFieldType,
            isRequired: isRequired,
            isList: isList,
            isId: isId,
            isUnique: isUnique,
            defaultValue: defaultValue,
            isUpdatedAt: isUpdatedAt,
            isCreatedAt: isCreatedAt,
            isRelation: isRelation,
            dbName: dbName,
            hasEmptyListDefault: hasEmptyListDefault,
            relationName: relationName,
            relationFromFields: relationFromFields,
            relationToFields: relationToFields,
          ));
        }
      }

      models.add(PrismaModel(
        name: modelName,
        dbName: modelDbName,
        fields: fields,
        relations: relations,
      ));
    }

    return PrismaSchema(
      models: models,
      enums: enums,
      datasourceProvider: datasourceProvider,
    );
  }

  /// Extracts content inside @default(...) handling nested parentheses.
  ///
  /// For example:
  /// - `@default(now())` returns `now()`
  /// - `@default(uuid())` returns `uuid()`
  /// - `@default(dbgenerated("gen_random_uuid()"))` returns `dbgenerated("gen_random_uuid()")`
  /// - `@default(true)` returns `true`
  static String? _extractDefaultValue(String attributes) {
    const prefix = '@default(';
    final startIndex = attributes.indexOf(prefix);
    if (startIndex == -1) return null;

    final contentStart = startIndex + prefix.length;
    var depth = 1;
    var i = contentStart;

    while (i < attributes.length && depth > 0) {
      final char = attributes[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }
      i++;
    }

    if (depth != 0) return null; // Unbalanced parentheses

    // i now points to the character after the closing paren
    // Content is from contentStart to i-1 (excluding closing paren)
    return attributes.substring(contentStart, i - 1);
  }
}
