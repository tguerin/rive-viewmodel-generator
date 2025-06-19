import 'dart:core';
import 'dart:typed_data';

import 'package:rive_native/rive_native.dart' as rive;
import 'package:rive_viewmodel_generator/supported_language.dart';
import 'package:rive_viewmodel_generator/template_generator.dart';

import 'ir_models.dart';

class RiveParser {
  final Uint8List _bytes;
  final String _fileName;

  RiveParser(this._bytes, this._fileName);

  Future<String> generateCode(Language language) async {
    await rive.RiveNative.init();
    final riveFile = await rive.File.decode(_bytes, riveFactory: rive.Factory.flutter);

    if (riveFile == null) {
      throw Exception('Failed to decode Rive file');
    }

    final model = await _parseToIR(riveFile);
    final generator = TemplateGenerator(language);
    return await generator.generate(model);
  }

  Future<RiveFileModel> _parseToIR(rive.File riveFile) async {
    final fileNameBase = _fileName.split('.').first.toCamelCase().capitalize();

    final artboards = <ArtboardModel>[];
    var artboardIndex = 0;
    while (true) {
      final artboard = riveFile.artboardAt(artboardIndex);
      if (artboard == null) break;

      final stateMachines = <StateMachineModel>[];
      for (var smIndex = 0; smIndex < artboard.stateMachineCount(); smIndex++) {
        final stateMachine = artboard.stateMachineAt(smIndex);
        if (stateMachine?.name != null) {
          stateMachines.add(StateMachineModel(name: stateMachine!.name, enumValue: stateMachine.name.toCamelCase()));
        }
      }

      artboards.add(
        ArtboardModel(name: artboard.name, className: artboard.name.toClassName(), stateMachines: stateMachines),
      );
      artboardIndex++;
    }

    final viewModels = <ViewModelModel>[];
    final existingClasses = <String>{};
    final generatedClasses = <String>{};
    for (var i = 0; i < riveFile.viewModelCount; i++) {
      final viewModel = riveFile.viewModelByIndex(i);
      if (viewModel != null) {
        existingClasses.add(viewModel.name.toClassName().append('ViewModel'));
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
        );
        if (model != null) {
          viewModels.add(model);
        }
      }
    }

    return RiveFileModel(fileName: _fileName, fileNameBase: fileNameBase, artboards: artboards, viewModels: viewModels);
  }

  ViewModelModel? _parseViewModelToIR(
    String className,
    rive.ViewModelInstance viewModel,
    rive.File riveFile,
    Set<String> existingClasses,
    Set<String> generatedClasses, {
    String? parent,
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
      final sanitizedPropName = property.name.toCamelCase();
      if (sanitizedPropName.isEmpty) continue;

      switch (property.type) {
        case rive.DataType.enumType:
          final enumFromRive = riveFile.enums.firstWhere(
            (e) => property.name.toLowerCase().contains(e.name.toLowerCase()),
            orElse: () => rive.DataEnum(property.name, []),
          );
          final enumName = enumFromRive.name.toClassName();
          final enumValues = enumFromRive.values;

          if (enumValues.isNotEmpty && !generatedClasses.contains(enumName)) {
            generatedClasses.add(enumName);
            enums.add(EnumModel(name: enumName, values: enumValues.map((value) => value.toCamelCase()).toList()));
          }

          allProperties.add(
            PropertyModel(
              name: sanitizedPropName,
              originalName: property.name,
              type: PropertyType.enumType,
              metadata: {'enumType': enumName},
            ),
          );

        case rive.DataType.viewModel:
          final nestedViewModel = viewModel.viewModel(property.name);
          if (nestedViewModel != null) {
            final propertyNameAsClass = property.name.toClassName();
            final nestedClassName = existingClasses.firstWhere(
              (className) => propertyNameAsClass.startsWith(className.replaceAll('ViewModel', '').replaceAll('Vm', '')),
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

        case rive.DataType.boolean:
          allProperties.add(
            PropertyModel(name: sanitizedPropName, originalName: property.name, type: PropertyType.boolean),
          );

        case rive.DataType.number:
        case rive.DataType.integer:
          allProperties.add(
            PropertyModel(name: sanitizedPropName, originalName: property.name, type: PropertyType.number),
          );

        case rive.DataType.string:
          allProperties.add(
            PropertyModel(name: sanitizedPropName, originalName: property.name, type: PropertyType.string),
          );

        case rive.DataType.color:
          allProperties.add(
            PropertyModel(name: sanitizedPropName, originalName: property.name, type: PropertyType.color),
          );

        case rive.DataType.trigger:
          final triggerName =
              sanitizedPropName.startsWith('trigger') ? sanitizedPropName : 'trigger${sanitizedPropName.capitalize()}';
          allProperties.add(PropertyModel(name: triggerName, originalName: property.name, type: PropertyType.trigger));

        case rive.DataType.image:
          allProperties.add(
            PropertyModel(name: sanitizedPropName, originalName: property.name, type: PropertyType.image),
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
    );
  }

  _GroupedProperties _groupPropertiesIntoLists(List<PropertyModel> allProperties) {
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
        groupProperties.sort((a, b) => _extractIndex(a.originalName).compareTo(_extractIndex(b.originalName)));

        final firstProperty = groupProperties.first;
        final listName = baseName.toCamelCase();

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

    return _GroupedProperties(individualProperties: individualProperties, listProperties: listProperties);
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
    final indices = properties.map((p) => _extractIndex(p.originalName)).toList()..sort();
    for (int i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) return false;
    }

    return true;
  }
}

class _GroupedProperties {
  final List<PropertyModel> individualProperties;
  final List<ListPropertyModel> listProperties;

  _GroupedProperties({required this.individualProperties, required this.listProperties});
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

    final words = normalized.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

    if (words.isEmpty) return '';

    return words[0].toLowerCase() + words.skip(1).map((word) => word.toLowerCase().capitalize()).join('');
  }

  String toClassName() {
    return toCamelCase().capitalize();
  }

  String toSnakeCase() {
    if (isEmpty) return '';
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]}_${match[2]}')
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
