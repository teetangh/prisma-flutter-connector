/// Shared string utilities for code generators
library;

/// Convert PascalCase to snake_case
String toSnakeCase(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      )
      .replaceFirst(RegExp(r'^_'), ''); // Remove leading underscore safely
}

/// Convert SCREAMING_CASE to camelCase
String toCamelCase(String input) {
  final parts = input.toLowerCase().split('_');
  if (parts.isEmpty) return input;

  return parts.first +
      parts.skip(1).map((part) {
        if (part.isEmpty) return part;
        return part[0].toUpperCase() + part.substring(1);
      }).join();
}

/// Convert PascalCase to lowerCamelCase
String toLowerCamelCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toLowerCase() + input.substring(1);
}
