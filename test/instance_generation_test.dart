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

  ViewModelModel coinViewModel({List<InstanceModel> instances = const []}) {
    return ViewModelModel(
      name: 'CoinViewModel',
      className: 'CoinViewModel',
      properties: [
        PropertyModel(
          name: 'colorInt',
          originalName: 'colorInt',
          type: PropertyType.color,
        ),
      ],
      instances: instances,
      runtimeName: 'Coin',
    );
  }

  Future<String> generate(ViewModelModel viewModel) {
    final model = RiveFileModel(
      fileName: 'coin.riv',
      fileNameBase: 'Coin',
      artboards: const [],
      viewModels: [viewModel],
    );
    return TemplateGenerator(Language.dart).generate(model);
  }

  test('emits an instance enum and factories when instances exist', () async {
    final code = await generate(
      coinViewModel(
        instances: [
          InstanceModel(name: 'cashEuros', value: 'cash_euros'),
          InstanceModel(name: 'freeRace', value: 'free_race'),
        ],
      ),
    );

    // Typed enum of the authored presets.
    expect(code, contains('enum CoinInstance {'));
    expect(code, contains("cashEuros('cash_euros')"));
    expect(code, contains("freeRace('free_race')"));
    expect(code, contains('final String instanceName;'));

    // Factories that resolve the instance from the file at runtime.
    expect(code, contains("static const String viewModelName = 'Coin';"));
    expect(
      code,
      contains('factory CoinViewModel.fromInstance(File file, CoinInstance instance)'),
    );
    expect(
      code,
      contains('factory CoinViewModel.fromDefaultInstance(File file)'),
    );
    expect(code, contains('createInstanceByName'));
    expect(code, contains('createDefaultInstance'));
  });

  test('emits no instance support when there are no instances', () async {
    final code = await generate(coinViewModel());

    expect(code, isNot(contains('CoinInstance')));
    expect(code, isNot(contains('fromInstance')));
    expect(code, isNot(contains('fromDefaultInstance')));
    // The plain view-model wrapper is still generated.
    expect(code, contains('class CoinViewModel'));
    expect(code, contains('fromViewModel'));
  });
}
