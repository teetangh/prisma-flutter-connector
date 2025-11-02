/// Prisma schema parser
///
/// Parses `.prisma` schema files and extracts models, fields, relations, and enums.
/// Validates schema against Dart reserved keywords and naming conventions.
library;

/// Dart reserved keywords that cannot be used as identifiers
/// Must match Dart language specification
const dartReservedKeywords = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case',
  'catch', 'class', 'const', 'continue', 'covariant', 'default',
  'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends',
  'extension', 'external', 'factory', 'false', 'final', 'finally',
  'for', 'Function', 'get', 'hide', 'if', 'implements', 'import',
  'in', 'interface', 'is', 'late', 'library', 'mixin', 'new', 'null',
  'on', 'operator', 'part', 'rethrow', 'return', 'set', 'show',
  'static', 'super', 'switch', 'sync', 'this', 'throw', 'true',
  'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
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
  final List<PrismaField> fields;
  final List<PrismaRelation> relations;

  const PrismaModel({
    required this.name,
    required this.fields,
    required this.relations,
  });
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

/// Parse a Prisma schema file
class PrismaParser {
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

  /// Validate that name is not a reserved Dart keyword
  void _validateIdentifier(String name, String type) {
    if (dartReservedKeywords.contains(name.toLowerCase())) {
      final suggestions = _getSuggestionForReservedKeyword(name, type);
      throw GeneratorError(
        'Reserved Dart keyword "$name" cannot be used as $type name',
        suggestion: suggestions,
      );
    }
  }

  /// Get context-specific suggestions for reserved keyword violations
  String _getSuggestionForReservedKeyword(String name, String type) {
    if (type == 'model') {
      // Common model name alternatives
      final alternatives = _getModelAlternatives(name);
      return '''
Prisma follows strict naming rules to ensure generated code compiles.

Option 1 (Recommended): Rename the model in your schema
  ${alternatives.map((alt) => '→ model $alt { ... }').join('\n  ')}

Option 2: Use @map to keep the original database table name
  → model ${alternatives.first} {
      ...
      @@map("$name")  // Maps to "$name" table in database
    }

Learn more: https://pris.ly/d/naming-models''';
    } else {
      // Field name alternatives
      final alternatives = _getFieldAlternatives(name);
      return '''
Prisma follows strict naming rules to ensure generated code compiles.

Option 1 (Recommended): Rename the field in your schema
  ${alternatives.map((alt) => '→ $alt: Type').join('\n  ')}

Option 2: Use @map to keep the original database column name
  → ${alternatives.first} Type @map("$name")  // Maps to "$name" column

Note: Unlike TypeScript, Dart does not allow reserved keywords as identifiers.''';
    }
  }

  /// Get alternative model names for a reserved keyword
  List<String> _getModelAlternatives(String name) {
    final capitalized = name[0].toUpperCase() + name.substring(1);

    // Common patterns based on the keyword
    final commonAlternatives = <String, List<String>>{
      'class': ['Lesson', 'Course', 'ClassModel'],
      'enum': ['Enumeration', 'EnumType', 'EnumModel'],
      'interface': ['Contract', 'InterfaceType', 'InterfaceModel'],
      'default': ['DefaultValue', 'DefaultConfig', 'DefaultModel'],
      'void': ['Empty', 'VoidType', 'VoidModel'],
      'static': ['StaticData', 'StaticConfig', 'StaticModel'],
      'final': ['FinalData', 'FinalValue', 'FinalModel'],
      'const': ['Constant', 'ConstValue', 'ConstModel'],
    };

    if (commonAlternatives.containsKey(name.toLowerCase())) {
      return commonAlternatives[name.toLowerCase()]!;
    }

    // Generic alternatives
    return ['${capitalized}Model', '${capitalized}Entity', '${capitalized}Data'];
  }

  /// Get alternative field names for a reserved keyword
  List<String> _getFieldAlternatives(String name) {
    // Common patterns based on the keyword
    final commonAlternatives = <String, List<String>>{
      'class': ['lesson', 'course', 'classRef'],
      'enum': ['enumeration', 'enumType', 'enumValue'],
      'type': ['dataType', 'kind', 'category'],
      'default': ['defaultValue', 'defaultConfig', 'isDefault'],
      'static': ['isStatic', 'staticValue', 'staticData'],
      'final': ['isFinal', 'finalValue', 'finalData'],
      'const': ['constant', 'constValue', 'isConst'],
      'void': ['isEmpty', 'voidValue', 'voidType'],
      'return': ['returnValue', 'result', 'output'],
      'continue': ['shouldContinue', 'continueFlag', 'nextStep'],
      'break': ['shouldBreak', 'breakPoint', 'stop'],
    };

    if (commonAlternatives.containsKey(name.toLowerCase())) {
      return commonAlternatives[name.toLowerCase()]!;
    }

    // Generic alternatives
    return ['${name}Value', '${name}Data', '${name}Field'];
  }

  /// Parse schema content from a string
  PrismaSchema parse(String schemaContent) {
    final models = <PrismaModel>[];
    final enums = <PrismaEnum>[];
    String datasourceProvider = 'postgresql'; // default

    // Extract datasource provider
    final datasourceMatch = RegExp(r'datasource\s+\w+\s*\{[^}]*provider\s*=\s*"([^"]+)"')
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

    // Extract models
    final modelPattern = RegExp(r'model\s+(\w+)\s*\{([^}]+)\}', multiLine: true);
    for (final match in modelPattern.allMatches(schemaContent)) {
      final modelName = match.group(1)!;
      final modelBody = match.group(2)!;

      // Validate model name
      _validateIdentifier(modelName, 'model');

      final fields = <PrismaField>[];
      final relations = <PrismaRelation>[];

      // Parse each line in the model
      for (final line in modelBody.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('//') || trimmed.startsWith('@@')) {
          continue;
        }

        // Parse field
        final fieldMatch = RegExp(r'^(\w+)\s+([\w\[\]?]+)(.*)$').firstMatch(trimmed);
        if (fieldMatch != null) {
          final originalFieldName = fieldMatch.group(1)!;
          var fieldType = fieldMatch.group(2)!;
          final attributes = fieldMatch.group(3) ?? '';

          // Validate field name against reserved keywords
          _validateIdentifier(originalFieldName, 'field');

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

          // Extract default value
          String? defaultValue;
          bool hasEmptyListDefault = false;
          final defaultMatch = RegExp(r'@default\(([^)]+)\)').firstMatch(attributes);
          if (defaultMatch != null) {
            final defaultStr = defaultMatch.group(1)!;
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
            final relationMatch = RegExp(r'@relation\(([^)]*)\)').firstMatch(attributes);
            if (relationMatch != null) {
              final relationContent = relationMatch.group(1)!;

              // Extract relation name (first unnamed string in quotes)
              final nameMatch = RegExp(r'^"([^"]+)"').firstMatch(relationContent.trim());
              if (nameMatch != null) {
                relationName = nameMatch.group(1);
              }

              // Extract fields: [field1, field2]
              final fieldsMatch = RegExp(r'fields:\s*\[([^\]]*)\]').firstMatch(relationContent);
              if (fieldsMatch != null) {
                relationFromFields = fieldsMatch.group(1)!
                    .split(',')
                    .map((f) => f.trim().replaceAll(RegExp(r'["\[\]]'), ''))
                    .where((f) => f.isNotEmpty)
                    .toList();
              }

              // Extract references: [field1, field2]
              final referencesMatch = RegExp(r'references:\s*\[([^\]]*)\]').firstMatch(relationContent);
              if (referencesMatch != null) {
                relationToFields = referencesMatch.group(1)!
                    .split(',')
                    .map((f) => f.trim().replaceAll(RegExp(r'["\[\]]'), ''))
                    .where((f) => f.isNotEmpty)
                    .toList();
              }

              // Add to relations list (for backward compatibility)
              relations.add(PrismaRelation(
                name: originalFieldName,
                targetModel: fieldType,
                relationName: relationName ?? '',
                fields: relationFromFields ?? [],
                references: relationToFields ?? [],
              ));
            }
          }

          // Normalize field name (PascalCase → camelCase)
          final normalizedName = _normalizeFieldName(originalFieldName);
          final dbName = (normalizedName != originalFieldName) ? originalFieldName : null;

          // Add field (including relation fields for generator access)
          fields.add(PrismaField(
            name: normalizedName,
            type: fieldType,
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
}
