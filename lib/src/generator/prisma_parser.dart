/// Prisma schema parser
///
/// Parses `.prisma` schema files and extracts models, fields, relations, and enums.
library;

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

      final fields = <PrismaField>[];
      final relations = <PrismaRelation>[];

      // Parse each line in the model
      for (final line in modelBody.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('//') || trimmed.startsWith('@@')) {
          continue;
        }

        // Parse field
        final fieldMatch = RegExp(r'^(\w+)\s+([\w\[\]]+)(.*)$').firstMatch(trimmed);
        if (fieldMatch != null) {
          final fieldName = fieldMatch.group(1)!;
          var fieldType = fieldMatch.group(2)!;
          final attributes = fieldMatch.group(3) ?? '';

          final isList = fieldType.endsWith('[]');
          if (isList) {
            fieldType = fieldType.substring(0, fieldType.length - 2);
          }

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
          final defaultMatch = RegExp(r'@default\(([^)]+)\)').firstMatch(attributes);
          if (defaultMatch != null) {
            defaultValue = defaultMatch.group(1);
          }

          // Check if it's a relation
          if (attributes.contains('@relation')) {
            // Parse relation
            final relationMatch = RegExp(r'@relation\([^)]*\)').firstMatch(attributes);
            if (relationMatch != null) {
              // This is a relation field
              relations.add(PrismaRelation(
                name: fieldName,
                targetModel: fieldType,
                relationName: '', // Extract from @relation if needed
                fields: [],
                references: [],
              ));
            }
          } else {
            // Regular field
            fields.add(PrismaField(
              name: fieldName,
              type: fieldType,
              isRequired: isRequired,
              isList: isList,
              isId: isId,
              isUnique: isUnique,
              defaultValue: defaultValue,
              isUpdatedAt: isUpdatedAt,
              isCreatedAt: isCreatedAt,
            ));
          }
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
