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

  // Release builds (`--obfuscate` / minification) can rename the identifiers
  // behind an enum's implicit `.name` and `.toString()`, which would break any
  // round-trip that relies on them. The generator must round-trip enums and
  // instances through explicit string-literal fields instead.
  test('enums round-trip via string literals, not .name/.toString()', () async {
    final model = RiveFileModel(
      fileName: 'widget.riv',
      fileNameBase: 'Widget',
      artboards: const [],
      viewModels: [
        ViewModelModel(
          name: 'WidgetViewModel',
          className: 'WidgetViewModel',
          properties: [
            PropertyModel(
              name: 'mode',
              originalName: 'mode',
              type: PropertyType.enumType,
              metadata: {'enumType': 'Mode'},
            ),
          ],
          enums: [
            EnumModel(
              name: 'Mode',
              values: [
                EnumValueModel(name: 'light', value: 'light'),
                EnumValueModel(name: 'dark', value: 'dark'),
              ],
            ),
          ],
          instances: [InstanceModel(name: 'primary', value: 'primary')],
          runtimeName: 'Widget',
        ),
      ],
    );
    final code = await TemplateGenerator(Language.dart).generate(model);

    // Data enum carries the original Rive string as a `value` field literal…
    expect(code, contains("light('light')"));
    expect(code, contains('final String value;'));
    // …and round-trips through it, never through the implicit `.name`.
    expect(
      code,
      contains("e.value == _viewModel.enumerator('mode')!.value"),
    );
    expect(code, contains("_viewModel.enumerator('mode')!.value = value.value"));

    // The instance enum round-trips through its `instanceName` field literal.
    expect(code, contains("primary('primary')"));
    expect(code, contains('instance.instanceName'));

    // Obfuscation-unsafe patterns must never appear for enum round-tripping.
    expect(code, isNot(contains('.toString()')));
    expect(code, isNot(contains("e.name == _viewModel.enumerator")));
    expect(code, isNot(contains("!.value = value.name")));
  });
}
