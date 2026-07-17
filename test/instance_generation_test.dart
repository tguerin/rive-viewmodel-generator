import 'package:flutter_test/flutter_test.dart';
import 'package:rive_viewmodel_generator/ir_models.dart';
import 'package:rive_viewmodel_generator/supported_language.dart';
import 'package:rive_viewmodel_generator/template_generator.dart';

/// Verifies that the generator emits named view-model instance support:
/// a typed instance enum plus `fromInstance` / `fromDefaultInstance` factories.
/// Feeds a synthetic IR straight into the template layer, so it needs no Rive
/// file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ViewModelModel widgetViewModel({List<InstanceModel> instances = const []}) {
    return ViewModelModel(
      name: 'WidgetViewModel',
      className: 'WidgetViewModel',
      properties: [
        PropertyModel(
          name: 'tint',
          originalName: 'tint',
          type: PropertyType.color,
        ),
      ],
      instances: instances,
      runtimeName: 'Widget',
    );
  }

  Future<String> generate(ViewModelModel viewModel) {
    final model = RiveFileModel(
      fileName: 'widget.riv',
      fileNameBase: 'Widget',
      artboards: const [],
      viewModels: [viewModel],
    );
    return TemplateGenerator(Language.dart).generate(model);
  }

  test('emits an instance enum and factories when instances exist', () async {
    final code = await generate(
      widgetViewModel(
        instances: [
          InstanceModel(name: 'primary', value: 'primary'),
          InstanceModel(name: 'darkMode', value: 'dark_mode'),
        ],
      ),
    );

    // Typed enum of the authored presets.
    expect(code, contains('enum WidgetInstance {'));
    expect(code, contains("primary('primary')"));
    expect(code, contains("darkMode('dark_mode')"));
    expect(code, contains('final String instanceName;'));

    // Factories that resolve the instance from the file at runtime.
    expect(code, contains("static const String viewModelName = 'Widget';"));
    expect(
      code,
      contains(
        'factory WidgetViewModel.fromInstance(File file, WidgetInstance instance)',
      ),
    );
    expect(
      code,
      contains('factory WidgetViewModel.fromDefaultInstance(File file)'),
    );
    expect(code, contains('createInstanceByName'));
    expect(code, contains('createDefaultInstance'));
  });

  test('emits no instance support when there are no instances', () async {
    final code = await generate(widgetViewModel());

    expect(code, isNot(contains('WidgetInstance')));
    expect(code, isNot(contains('fromInstance')));
    expect(code, isNot(contains('fromDefaultInstance')));
    // The plain view-model wrapper is still generated.
    expect(code, contains('class WidgetViewModel'));
    expect(code, contains('fromViewModel'));
  });
}
