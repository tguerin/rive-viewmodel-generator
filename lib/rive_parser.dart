import 'dart:core';
import 'dart:typed_data';

import 'package:rive/rive.dart';
import 'package:rive_viewmodel_generator/supported_language.dart';
import 'package:rive_viewmodel_generator/template_generator.dart';

import 'ir_models.dart';

const Set<String> _dartReservedKeywords = {
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
  'function',
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
  'native',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
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
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

// Dart built-in types and common class names that should be avoided for enum/class names
const Set<String> _dartBuiltInTypes = {
  'type',
  'string',
  'int',
  'double',
  'bool',
  'num',
  'object',
  'dynamic',
  'void',
  'function',
  'list',
  'map',
  'set',
  'future',
  'stream',
  'iterable',
  'iterator',
  'duration',
  'datetime',
  'uri',
  'pattern',
  'regexp',
  'match',
  'symbol',
  'stacktrace',
  'error',
  'exception',
  'null',
};

/// Sanitizes a property name to avoid Dart reserved keywords
String _sanitizePropertyName(String name) {
  if (_dartReservedKeywords.contains(name.toLowerCase())) {
    return '${name}Property';
  }
  // Dart identifiers cannot start with a digit (e.g. enum values "10", "20").
  // Prefix such generated names with '$' so they compile.
  if (RegExp(r'^[0-9]').hasMatch(name)) {
    return '\$$name';
  }
  return name;
}

/// Sanitizes a class/enum name to avoid Dart built-in types
String _sanitizeClassName(String name) {
  if (_dartBuiltInTypes.contains(name.toLowerCase())) {
    return '${name}Enum';
  }
  return name;
}

class RiveParser {
  final Uint8List _bytes;
  final String _fileName;

  /// Property signature (`name:type`) of every top-level view model, keyed by
  /// its generated class name. Used to resolve a nested `viewModel`-typed
  /// property back to its top-level definition by shape, since the Rive API
  /// does not expose a nested instance's view-model type name.
  final Map<String, Set<String>> _viewModelShapes = {};

  RiveParser(this._bytes, this._fileName);

  Future<String> generateCode(
    Language language, {
    RiveVersion riveVersion = RiveVersion.legacy,
    bool useInterface = false,
  }) async {
    await RiveNative.init();
    final riveFile = await File.decode(_bytes, riveFactory: Factory.flutter);

    if (riveFile == null) {
      throw Exception('Failed to decode Rive file');
    }

    final model = await _parseToIR(riveFile);
    final generator = TemplateGenerator(
      language,
      riveVersion: riveVersion,
      useInterface: useInterface,
    );
    return await generator.generate(model);
  }

  Future<RiveFileModel> _parseToIR(File riveFile) async {
    final fileNameBase = _fileName.split('.').first.toCamelCase().capitalize();

    final artboards = <ArtboardModel>[];
    final generatedArtboardClasses = <String>{};
    var artboardIndex = 0;
    while (true) {
      final artboard = riveFile.artboardAt(artboardIndex);
      if (artboard == null) break;

      final className = artboard.name.toClassName();
      
      // Skip if we've already generated this artboard class
      if (generatedArtboardClasses.contains(className)) {
        artboardIndex++;
        continue;
      }
      generatedArtboardClasses.add(className);

      final stateMachines = <StateMachineModel>[];
      for (var smIndex = 0; smIndex < artboard.stateMachineCount(); smIndex++) {
        final stateMachine = artboard.stateMachineAt(smIndex);
        if (stateMachine?.name != null) {
          stateMachines.add(
            StateMachineModel(
              name: stateMachine!.name,
              enumValue: _sanitizePropertyName(stateMachine.name.toCamelCase()),
            ),
          );
        }
      }

      artboards.add(
        ArtboardModel(
          name: artboard.name,
          className: className,
          stateMachines: stateMachines,
        ),
      );
      artboardIndex++;
    }

    final viewModels = <ViewModelModel>[];
    final existingClasses = <String>{};
    final generatedClasses = <String>{};
    _viewModelShapes.clear();
    for (var i = 0; i < riveFile.viewModelCount; i++) {
      final viewModel = riveFile.viewModelByIndex(i);
      if (viewModel != null) {
        final className = viewModel.name.toClassName().append('ViewModel');
        existingClasses.add(className);
        final instance = viewModel.createDefaultInstance();
        if (instance != null) {
          _viewModelShapes[className] = _shapeOf(instance);
          instance.dispose();
        }
      }
    }

    for (var i = 0; i < riveFile.viewModelCount; i++) {
      final viewModel = riveFile.viewModelByIndex(i);
      if (viewModel != null) {
        final model = _parseViewModelToIR(
          viewModel.name.toClassName().append('ViewModel'),
          viewModel.createDefaultInstance()!,
          riveFile,
          existingClasses,
          generatedClasses,
          instances: _parseInstances(viewModel),
          runtimeName: viewModel.name,
        );
        if (model != null) {
          viewModels.add(model);
        }
      }
    }

    return RiveFileModel(
      fileName: _fileName,
      fileNameBase: fileNameBase,
      artboards: artboards,
      viewModels: viewModels,
    );
  }

  /// The property signature (`name:type`) of a view model instance.
  Set<String> _shapeOf(ViewModelInstance instance) =>
      instance.properties.map((p) => '${p.name}:${p.type}').toSet();

  /// Resolves a nested `viewModel`-typed property to a top-level view model
  /// class by matching property shapes. Returns the class name only when
  /// exactly one top-level view model has the same shape (avoids guessing when
  /// two definitions are structurally identical); otherwise returns null so the
  /// caller falls back to the name-based heuristic.
  String? _matchNestedClassByShape(ViewModelInstance nested) {
    final shape = _shapeOf(nested);
    String? match;
    for (final entry in _viewModelShapes.entries) {
      final candidate = entry.value;
      if (candidate.length == shape.length && candidate.containsAll(shape)) {
        if (match != null) return null; // ambiguous
        match = entry.key;
      }
    }
    return match;
  }

  /// Enumerates the named instances (presets) of a top-level [viewModel],
  /// deduplicating any that sanitize to the same Dart identifier.
  List<InstanceModel> _parseInstances(ViewModel viewModel) {
    final instances = <InstanceModel>[];
    final seenIds = <String>{};
    for (var k = 0; k < viewModel.instanceCount; k++) {
      final instance = viewModel.createInstanceByIndex(k);
      final rawName = instance?.name;
      instance?.dispose();
      if (rawName == null || rawName.isEmpty) continue;
      final id = _sanitizePropertyName(rawName.toCamelCase());
      if (id.isEmpty || !seenIds.add(id)) continue;
      instances.add(InstanceModel(name: id, value: rawName));
    }
    return instances;
  }

  ViewModelModel? _parseViewModelToIR(
    String className,
    ViewModelInstance viewModel,
    File riveFile,
    Set<String> existingClasses,
    Set<String> generatedClasses, {
    String? parent,
    List<InstanceModel> instances = const [],
    String? runtimeName,
  }) {
    if (className.isEmpty) return null;
    if (generatedClasses.contains(className)) return null;
    generatedClasses.add(className);

    final enums = <EnumModel>[];
    final nestedViewModels = <ViewModelModel>[];
    final properties = <PropertyModel>[];
    final listProperties = <ListPropertyModel>[];

    // First pass: collect all properties
    final allProperties = <PropertyModel>[];
    for (final property in viewModel.properties) {
      final sanitizedPropName = _sanitizePropertyName(
        property.name.toCamelCase(),
      );
      if (sanitizedPropName.isEmpty) continue;

      switch (property.type) {
        case DataType.enumType:
          final enumFromRive = riveFile.enums.firstWhere(
            (e) => property.name.toLowerCase().contains(e.name.toLowerCase()),
            orElse: () => DataEnum(property.name, []),
          );
          final enumName = _sanitizeClassName(enumFromRive.name.toClassName());
          final enumValues = enumFromRive.values;

          if (enumValues.isNotEmpty && !generatedClasses.contains(enumName)) {
            generatedClasses.add(enumName);
            enums.add(
              EnumModel(
                name: enumName,
                values:
                    enumValues
                        .map(
                          (value) => EnumValueModel(
                            name: _sanitizePropertyName(value.toCamelCase()),
                            value: value,
                          ),
                        )
                        .toList(),
              ),
            );
          }

          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.enumType,
              metadata: {'enumType': enumName},
            ),
          );

        case DataType.viewModel:
          final nestedViewModel = viewModel.viewModel(property.name);
          if (nestedViewModel != null) {
            final propertyNameAsClass = property.name.toClassName();
            // Prefer a shape match to the real top-level definition (so the
            // nested property reuses e.g. CoinViewModel and its instance
            // support); fall back to the name-based heuristic otherwise.
            final nestedClassName =
                _matchNestedClassByShape(nestedViewModel) ??
                existingClasses.firstWhere(
                  (className) => propertyNameAsClass.startsWith(
                    className.replaceAll('ViewModel', '').replaceAll('Vm', ''),
                  ),
                  orElse: () => propertyNameAsClass,
                );
            final nestedModel = _parseViewModelToIR(
              nestedClassName,
              nestedViewModel,
              riveFile,
              existingClasses,
              generatedClasses,
              parent: className,
            );
            if (nestedModel != null) {
              nestedViewModels.add(nestedModel);
            }

            allProperties.add(
              PropertyModel(
                name: sanitizedPropName,
                originalName: property.name,
                type: PropertyType.viewModel,
                metadata: {'returnType': nestedClassName},
              ),
            );
          }

        case DataType.boolean:
          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.boolean,
            ),
          );

        case DataType.number:
        case DataType.integer:
          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.number,
            ),
          );

        case DataType.string:
          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.string,
            ),
          );

        case DataType.color:
          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.color,
            ),
          );

        case DataType.trigger:
          final triggerName =
              sanitizedPropName.startsWith('trigger')
                  ? sanitizedPropName
                  : 'trigger${sanitizedPropName.capitalize()}';
          allProperties.add(
            PropertyModel(
              name: triggerName,
              originalName: property.name,
              type: PropertyType.trigger,
            ),
          );

        case DataType.image:
          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.image,
            ),
          );

        case DataType.list:
          final propertyNameAsClass = property.name.toClassName();
          final itemClassName = existingClasses.firstWhere(
            (className) => propertyNameAsClass.startsWith(
              className.replaceAll('ViewModel', '').replaceAll('Vm', ''),
            ),
            orElse: () => propertyNameAsClass.append('ViewModel'),
          );

          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.viewModelList,
              metadata: {'returnType': itemClassName},
            ),
          );

        default:
          // Skip unsupported types
          break;
      }
    }

    // Second pass: group similar properties into lists
    final groupedProperties = _groupPropertiesIntoLists(allProperties);
    properties.addAll(groupedProperties.individualProperties);
    listProperties.addAll(groupedProperties.listProperties);

    return ViewModelModel(
      name: className,
      className: className,
      properties: properties,
      listProperties: listProperties,
      nestedViewModels: nestedViewModels,
      enums: enums,
      instances: instances,
      runtimeName: runtimeName,
    );
  }

  _GroupedProperties _groupPropertiesIntoLists(
    List<PropertyModel> allProperties,
  ) {
    final individualProperties = <PropertyModel>[];
    final listProperties = <ListPropertyModel>[];

    // Group properties by their base name (e.g., "blason_1", "blason_2" -> "blason")
    final propertyGroups = <String, List<PropertyModel>>{};

    for (final property in allProperties) {
      final baseName = _extractBaseName(property.originalName);
      propertyGroups.putIfAbsent(baseName, () => []).add(property);
    }

    for (final entry in propertyGroups.entries) {
      final baseName = entry.key;
      final groupProperties = entry.value;

      // If we have multiple properties with the same base name and they follow a pattern
      if (groupProperties.length > 1 && _isSequentialGroup(groupProperties)) {
        // Sort by index to ensure proper order
        groupProperties.sort(
          (a, b) => _extractIndex(
            a.originalName,
          ).compareTo(_extractIndex(b.originalName)),
        );

        final firstProperty = groupProperties.first;
        final listName = _sanitizePropertyName(baseName.toCamelCase());

        listProperties.add(
          ListPropertyModel(
            name: listName,
            baseName: baseName,
            itemType: firstProperty.type,
            items: groupProperties,
            metadata: firstProperty.metadata,
          ),
        );
      } else {
        // Add as individual properties
        individualProperties.addAll(groupProperties);
      }
    }

    return _GroupedProperties(
      individualProperties: individualProperties,
      listProperties: listProperties,
    );
  }

  String _extractBaseName(String propertyName) {
    // Extract base name from patterns like "blason_1", "blason_2", etc.
    final regex = RegExp(r'^(.+?)_(\d+)$');
    final match = regex.firstMatch(propertyName);
    if (match != null) {
      return match.group(1)!;
    }
    return propertyName;
  }

  int _extractIndex(String propertyName) {
    // Extract index from patterns like "blason_1", "blason_2", etc.
    final regex = RegExp(r'^(.+?)_(\d+)$');
    final match = regex.firstMatch(propertyName);
    if (match != null) {
      return int.tryParse(match.group(2)!) ?? 0;
    }
    return 0;
  }

  bool _isSequentialGroup(List<PropertyModel> properties) {
    if (properties.length < 2) return false;

    // Check if all properties have the same type
    final firstType = properties.first.type;
    if (!properties.every((p) => p.type == firstType)) return false;

    // Check if they follow a sequential naming pattern
    final indices =
        properties.map((p) => _extractIndex(p.originalName)).toList()..sort();
    for (int i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) return false;
    }

    return true;
  }
}

class _GroupedProperties {
  final List<PropertyModel> individualProperties;
  final List<ListPropertyModel> listProperties;

  _GroupedProperties({
    required this.individualProperties,
    required this.listProperties,
  });
}

extension StringExtensions on String {
  String capitalize() {
    return isEmpty ? '' : this[0].toUpperCase() + substring(1);
  }

  String uncapitalize() {
    return isEmpty ? '' : this[0].toLowerCase() + substring(1);
  }

  String toCamelCase() {
    if (isEmpty) return '';

    if (RegExp(r'^[a-zA-Z0-9]*$').hasMatch(this)) {
      return this;
    }

    var normalized = replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ');

    final words =
        normalized
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();

    if (words.isEmpty) return '';

    return words[0].toLowerCase() +
        words.skip(1).map((word) => word.toLowerCase().capitalize()).join('');
  }

  String toClassName() {
    return toCamelCase().capitalize();
  }

  String toSnakeCase() {
    if (isEmpty) return '';
    return replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]}_${match[2]}',
        )
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase()
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String append(String s) {
    if (!endsWith(s)) return '$this$s';
    return this;
  }
}
