import 'package:dart_style/dart_style.dart';
import 'package:flutter/services.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:rive_viewmodel_generator/rive_parser.dart';
import 'package:rive_viewmodel_generator/supported_language.dart';

import 'ir_models.dart';

class TemplateGenerator {
  final Language language;
  Template? _mainTemplate;
  final Map<String, Template> _partialTemplates = {};

  TemplateGenerator(this.language);

  Future<void> _loadTemplates() async {
    final templatePath = 'assets/templates/${language.name}';

    final templateNames = [
      'enum',
      'state_machine_enum',
      'sealed_artboard_class',
      'artboard_class',
      'view_model_class',
      'artboard_enum',
    ];

    for (final name in templateNames) {
      try {
        final content = await rootBundle.loadString('$templatePath/$name.mustache');
        _partialTemplates[name] = Template(content);
      } catch (e) {
        // Template doesn't exist for this language, that's ok
      }
    }

    try {
      final mainContent = await rootBundle.loadString('$templatePath/main.mustache');
      _mainTemplate = Template(mainContent, partialResolver: (name) => _partialTemplates[name]);
    } catch (e) {
      throw Exception('Main template not found for language: ${language.displayName}');
    }
  }

  Future<String> generate(RiveFileModel model) async {
    if (_mainTemplate == null) {
      await _loadTemplates();
    }
    final context = _buildContext(model);
    return _formatCode(_mainTemplate!.renderString(context));
  }

  String _formatCode(String code) {
    if (language != Language.dart) return code;
    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(code);
  }

  Map<String, dynamic> _buildContext(RiveFileModel model) {
    final enums = _buildEnums(model);
    final artboards = _buildArtboards(model);
    final viewModels = _buildViewModels(model);
    final needPaintingImport = viewModels.any((vm) => vm['hasImages'] == true);
    return {'enums': enums, 'artboards': artboards, 'viewModels': viewModels, 'needPaintingImport': needPaintingImport};
  }

  List<Map<String, dynamic>> _buildEnums(RiveFileModel model) {
    final allEnums = <EnumModel>[];

    for (final viewModel in model.viewModels) {
      allEnums.addAll(viewModel.enums);
      _collectNestedEnums(viewModel, allEnums);
    }

    return allEnums
        .map(
          (enumModel) => {
            'name': enumModel.name,
            'values': enumModel.values.map((value) => {'name': value, 'last': value == enumModel.values.last}).toList(),
            'hasConstructor': false,
            'enumName': enumModel.name,
          },
        )
        .toList();
  }

  void _collectNestedEnums(ViewModelModel viewModel, List<EnumModel> allEnums) {
    for (final nested in viewModel.nestedViewModels) {
      allEnums.addAll(nested.enums);
      _collectNestedEnums(nested, allEnums);
    }
  }

  List<Map<String, dynamic>> _buildArtboards(RiveFileModel model) {
    if (model.artboards.isEmpty) return [];

    final sealedClassName = '${model.fileNameBase}Artboard';

    return [
      {
        'hasSealedClass': model.artboards.isNotEmpty,
        'name': sealedClassName,
        'stateMachineEnums':
            model.artboards
                .where((a) => a.stateMachines.isNotEmpty)
                .map(
                  (artboard) => {
                    'name': '${artboard.className}StateMachine',
                    'enumName': '${artboard.className}StateMachine',
                    'values':
                        artboard.stateMachines
                            .map(
                              (sm) => {
                                'name': sm.enumValue,
                                'argument': sm.name,
                                'last': sm == artboard.stateMachines.last,
                              },
                            )
                            .toList(),
                  },
                )
                .toList(),
        'implementations':
            model.artboards
                .map(
                  (artboard) => {
                    'className': artboard.className,
                    'sealedClassName': sealedClassName,
                    'originalName': artboard.name,
                    'enumName': artboard.name.toCamelCase().uncapitalize(),
                    'last': artboard == model.artboards.last,
                    'stateMachineGetters':
                        artboard.stateMachines
                            .map(
                              (sm) => {
                                'returnType': '${artboard.className}StateMachine',
                                'name': sm.enumValue,
                                'enumType': '${artboard.className}StateMachine',
                                'enumValue': sm.enumValue,
                              },
                            )
                            .toList(),
                  },
                )
                .toList(),
      },
    ];
  }

  List<Map<String, dynamic>> _buildViewModels(RiveFileModel model) {
    final result = <Map<String, dynamic>>[];

    for (final viewModel in model.viewModels) {
      result.addAll(_buildViewModelWithNested(viewModel));
    }

    return result;
  }

  List<Map<String, dynamic>> _buildViewModelWithNested(ViewModelModel viewModel) {
    final result = <Map<String, dynamic>>[];

    for (final nested in viewModel.nestedViewModels) {
      result.addAll(_buildViewModelWithNested(nested));
    }

    result.add({
      'className': viewModel.className,
      'hasImages': viewModel.properties.any((p) => p.type == PropertyType.image),
      'properties': _buildProperties(viewModel.properties),
    });

    return result;
  }

  List<Map<String, dynamic>> _buildProperties(List<PropertyModel> properties) {
    return properties
        .map(
          (prop) => {
            'name': prop.name,
            'originalName': prop.originalName,
            'streamName': '${prop.name}Stream',
            'isBoolean': prop.type == PropertyType.boolean,
            'isNumberInt': prop.type == PropertyType.integer,
            'isNumberDouble': prop.type == PropertyType.number,
            'isString': prop.type == PropertyType.string,
            'isColor': prop.type == PropertyType.color,
            'isEnum': prop.type == PropertyType.enumType,
            'isViewModel': prop.type == PropertyType.viewModel,
            'isTrigger': prop.type == PropertyType.trigger,
            'isImage': prop.type == PropertyType.image,
            'enumType': prop.metadata['enumType'] ?? '',
            'returnType': prop.metadata['returnType'] ?? '',
          },
        )
        .toList();
  }
}
