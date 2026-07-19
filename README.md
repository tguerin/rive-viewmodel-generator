<div align="center">

# Rive ViewModel Generator

**Generate type-safe Dart view models from your Rive files — in the browser or from your terminal.**

[![npm version](https://img.shields.io/npm/v/@rive-viewmodel/cli?logo=npm&label=%40rive-viewmodel%2Fcli)](https://www.npmjs.com/package/@rive-viewmodel/cli)
[![pub package](https://img.shields.io/pub/v/rive_viewmodel?logo=dart&label=rive_viewmodel)](https://pub.dev/packages/rive_viewmodel)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.41.6-02569B?logo=flutter)](https://flutter.dev)
[![Live demo](https://img.shields.io/badge/demo-live-brightgreen)](https://tguerin.github.io/rive-viewmodel-generator)

</div>

Stop hand-writing string lookups against your Rive state machines. Point this
tool at a `.riv` file and it emits a typed Dart wrapper with getters, setters,
reactive streams, and proper lifecycle management — so your animations become a
compile-checked API instead of a bag of stringly-typed keys.

You can generate in two ways that produce **identical output**: a drag-and-drop
**web app** and a **command-line tool** (`rive-gen`) for scripting and CI.

## Demo

https://github.com/user-attachments/assets/d68f36da-c244-4274-aa08-ed38528e6555

▶️ **[Try the live demo](https://tguerin.github.io/rive-viewmodel-generator)**

## Contents

- [Features](#features)
- [Getting started](#getting-started)
  - [Web app](#web-app)
  - [CLI (`rive-gen`)](#cli-rive-gen)
  - [A note on defaults](#a-note-on-defaults)
- [Generated code](#generated-code)
- [Using the generated view model](#using-the-generated-view-model)
- [Project layout](#project-layout)
- [Requirements](#requirements)
- [Development](#development)
- [License](#license)

## Features

- **Type-safe view models** — typed getters and setters for every Rive property
- **Every property type** — boolean, number, string, color, trigger, enum, and
  nested view models
- **Reactive streams** — a `Stream` getter per property for reactive UI
- **Artboards & state machines** — typed accessors for both
- **Named instances (presets)** — a typed instance enum plus `fromInstance` /
  `fromDefaultInstance` factories, so presets need no string lookups
- **Lifecycle management** — a `dispose()` that cleans up every stream controller
- **Web _and_ CLI** — identical output from a shared template set, so both paths
  stay in sync

## Getting started

### Web app

1. Open the [live demo](https://tguerin.github.io/rive-viewmodel-generator) (or
   run it locally — see [Development](#development)).
2. Drag and drop one or more `.riv` files onto the drop zone.
3. A Dart view model is generated for each file — download it with the button
   next to each entry.
4. Drop the generated file into your Flutter project and use it.

The web UI also exposes the same options as the CLI: the target language, the
**Rive package version** (Legacy `rive_native` vs. Modern `rive` 0.14+), and a
**Use RiveViewModel Interface** toggle.

### CLI (`rive-gen`)

A companion CLI, [`@rive-viewmodel/cli`](https://www.npmjs.com/package/@rive-viewmodel/cli),
generates the same Dart code from the terminal — handy for scripting and CI.

**Install (or update) globally:**

```bash
npm install -g @rive-viewmodel/cli          # first install
npm install -g @rive-viewmodel/cli@latest   # update to newest
```

**Generate:**

```bash
rive-gen --input path/to/MyAnimation.riv --output lib/generated
```

**Options:**

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--input <file>` | `-i` | Path to the `.riv` file | **required** |
| `--output <dir>` | `-o` | Output directory | Same directory as the input file |
| `--name <name>` | `-n` | Output file base name (no extension) | Input file name |
| `--modern` | | Use the `package:rive/rive.dart` import | `package:rive_native/rive_native.dart` |
| `--interface` | | Implement the `RiveViewModel` interface | `false` |
| `--templates <dir>` | | Custom Mustache templates directory | `assets/templates/dart/` |
| `--help` | `-h` | Display help | |
| `--version` | `-V` | Display version | |

**Examples:**

```bash
# Legacy rive_native import (default)
rive-gen -i assets/hero.riv -o lib/generated

# Modern package:rive import
rive-gen -i assets/hero.riv -o lib/generated --modern

# Modern import + implement the RiveViewModel interface
rive-gen -i assets/hero.riv -o lib/generated --modern --interface

# Custom output file name
rive-gen -i assets/hero_animation.riv -o lib/generated -n hero_view_model
```

See the [CLI README](packages/rive-viewmodel-cli/README.md) for local
development, the WASM implementation notes, and publishing.

### A note on defaults

The two paths ship with different defaults, so pick the flags that match your
setup:

| | Rive import | `RiveViewModel` interface |
|---|---|---|
| **Web app** | Modern (`package:rive`) | on |
| **CLI** | Legacy (`package:rive_native`) | off (`--interface` to enable) |

## Generated code

Every property becomes a typed getter/setter plus a broadcast `Stream`. For a
number property named `numberProperty`, the generator emits:

```dart
double get numberProperty => _viewModel.number('numberProperty')!.value;

set numberProperty(double value) =>
    _viewModel.number('numberProperty')!.value = value;

Stream<double> get numberPropertyStream { /* broadcast stream over the property */ }
```

<details>
<summary><strong>Show a full generated example</strong></summary>

```dart
// This file was generated by rive_viewmodel_generator
// Do not edit this file manually
// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: unused_import
import 'dart:async';
import 'dart:ui';
import 'package:rive_native/rive_native.dart';

enum Orientation {
  portrait('portrait'),
  landscape('landscape');

  const Orientation(this.value);

  final String value;
}

enum ArtboardStateMachine {
  stateMachine1('State Machine 1');

  const ArtboardStateMachine(this.name);
  final String name;
}

sealed class _SealedArtboard {
  String get name;
}

abstract interface class TestArtboard {
  static const artboard = _Artboard();
}

class _Artboard implements _SealedArtboard {
  const _Artboard();

  @override
  String get name => 'Artboard';

  ArtboardStateMachine get stateMachine1 => ArtboardStateMachine.stateMachine1;
}

class NestedViewModel {
  NestedViewModel._(this._viewModel);

  factory NestedViewModel.fromViewModel(ViewModelInstance viewModel) =
      NestedViewModel._;

  final ViewModelInstance _viewModel;

  final Map<String, StreamController<dynamic>> _streamControllers = {};

  double get numberProperty => _viewModel.number('numberProperty')!.value;

  set numberProperty(double value) =>
      _viewModel.number('numberProperty')!.value = value;

  Stream<double> get numberPropertyStream {
    return (_streamControllers['numberProperty'] ??= () {
          final controller = StreamController<double>.broadcast();
          _streamControllers['numberProperty'] = controller;
          final property = _viewModel.number('numberProperty')!;
          void valueListener(double value) => controller.add(value);
          void onListen() => property.addListener(valueListener);
          void onCancel() => property.removeListener(valueListener);
          controller
            ..onListen = onListen
            ..onCancel = onCancel;
          return controller;
        }()).stream
        as Stream<double>;
  }

  void bind(StateMachine stateMachine) =>
      stateMachine.bindViewModelInstance(_viewModel);

  void dispose() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _viewModel.dispose();
  }
}

class TestViewModel {
  TestViewModel._(this._viewModel);

  factory TestViewModel.fromViewModel(ViewModelInstance viewModel) =
      TestViewModel._;

  final ViewModelInstance _viewModel;

  final Map<String, StreamController<dynamic>> _streamControllers = {};

  NestedViewModel get nestedViewModel {
    return NestedViewModel.fromViewModel(
      _viewModel.viewModel('nestedViewModel')!,
    );
  }

  double get numberProperty => _viewModel.number('numberProperty')!.value;

  set numberProperty(double value) =>
      _viewModel.number('numberProperty')!.value = value;

  Stream<double> get numberPropertyStream {
    return (_streamControllers['numberProperty'] ??= () {
          final controller = StreamController<double>.broadcast();
          _streamControllers['numberProperty'] = controller;
          final property = _viewModel.number('numberProperty')!;
          void valueListener(double value) => controller.add(value);
          void onListen() => property.addListener(valueListener);
          void onCancel() => property.removeListener(valueListener);
          controller
            ..onListen = onListen
            ..onCancel = onCancel;
          return controller;
        }()).stream
        as Stream<double>;
  }

  void triggerProperty() => _viewModel.trigger('triggerProperty')!.trigger();

  Color get colorProperty => _viewModel.color('colorProperty')!.value;

  set colorProperty(Color value) =>
      _viewModel.color('colorProperty')!.value = value;

  Stream<Color> get colorPropertyStream {
    return (_streamControllers['colorProperty'] ??= () {
          final controller = StreamController<Color>.broadcast();
          _streamControllers['colorProperty'] = controller;
          final property = _viewModel.color('colorProperty')!;
          void valueListener(Color value) => controller.add(value);
          void onListen() => property.addListener(valueListener);
          void onCancel() => property.removeListener(valueListener);
          controller
            ..onListen = onListen
            ..onCancel = onCancel;
          return controller;
        }()).stream
        as Stream<Color>;
  }

  bool get booleanProperty => _viewModel.boolean('booleanProperty')!.value;

  set booleanProperty(bool value) =>
      _viewModel.boolean('booleanProperty')!.value = value;

  Stream<bool> get booleanPropertyStream {
    return (_streamControllers['booleanProperty'] ??= () {
          final controller = StreamController<bool>.broadcast();
          _streamControllers['booleanProperty'] = controller;
          final property = _viewModel.boolean('booleanProperty')!;
          void valueListener(bool value) => controller.add(value);
          void onListen() => property.addListener(valueListener);
          void onCancel() => property.removeListener(valueListener);
          controller
            ..onListen = onListen
            ..onCancel = onCancel;
          return controller;
        }()).stream
        as Stream<bool>;
  }

  String get stringProperty => _viewModel.string('stringProperty')!.value;

  set stringProperty(String value) =>
      _viewModel.string('stringProperty')!.value = value;

  Stream<String> get stringPropertyStream {
    return (_streamControllers['stringProperty'] ??= () {
          final controller = StreamController<String>.broadcast();
          _streamControllers['stringProperty'] = controller;
          final property = _viewModel.string('stringProperty')!;
          void valueListener(String value) => controller.add(value);
          void onListen() => property.addListener(valueListener);
          void onCancel() => property.removeListener(valueListener);
          controller
            ..onListen = onListen
            ..onCancel = onCancel;
          return controller;
        }()).stream
        as Stream<String>;
  }

  Orientation get orientation => Orientation.values.firstWhere(
    (e) => e.value == _viewModel.enumerator('orientation')!.value,
  );

  set orientation(Orientation value) =>
      _viewModel.enumerator('orientation')!.value = value.value;

  Stream<Orientation> get orientationStream {
    return (_streamControllers['orientation'] ??= () {
          final controller = StreamController<Orientation>.broadcast();
          _streamControllers['orientation'] = controller;
          final property = _viewModel.enumerator('orientation')!;
          void valueListener(String value) => controller.add(
            Orientation.values.firstWhere((e) => e.value == value),
          );
          void onListen() => property.addListener(valueListener);
          void onCancel() => property.removeListener(valueListener);
          controller
            ..onListen = onListen
            ..onCancel = onCancel;
          return controller;
        }()).stream
        as Stream<Orientation>;
  }

  void bind(StateMachine stateMachine) =>
      stateMachine.bindViewModelInstance(_viewModel);

  void dispose() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _viewModel.dispose();
  }
}
```

</details>

## Using the generated view model

**Read and write properties, and listen for changes:**

```dart
final viewModel = TestViewModel.fromViewModel(stateMachine.viewModel('Test'));

// Getters and setters
viewModel.orientation = Orientation.portrait;

// Reactive streams
viewModel.orientationStream.listen((orientation) {
  print('Orientation changed to: $orientation');
});

// Always dispose when done
viewModel.dispose();
```

**Named instances (presets):** when a view model declares named instances in the
Rive editor, the generator emits a typed enum and factories so you can select a
preset without string lookups:

```dart
// enum WidgetInstance { primary, secondary, compact }
final widget = WidgetViewModel.fromInstance(file, WidgetInstance.primary);
widget.bind(controller.stateMachine);

// Or the default instance:
final defaultWidget = WidgetViewModel.fromDefaultInstance(file);
```

View models with no named instances are generated exactly as before.

**Enum properties:** each enum property is matched to its enum type directly from
the Rive runtime (by exact type name in the Flutter app, by value set in the
CLI), so the property can be named anything. Only if the runtime cannot resolve
it does the generator fall back to matching the property name against an enum
name (e.g. `playerOrientation` → `Orientation`).

## Project layout

This is a monorepo wired together with local path dependencies. Both generators
render from the **same Mustache templates**, which keeps their output identical.

| Path | What it is |
|------|------------|
| `lib/`, `web/`, `macos/` | The Flutter **web demo** & desktop generator UI (`rive_viewmodel_generator`) |
| `packages/rive-viewmodel-cli/` | The Node/WASM **CLI** — [`@rive-viewmodel/cli`](https://www.npmjs.com/package/@rive-viewmodel/cli) (`rive-gen`) |
| `packages/rive_viewmodel/` | The pure-Dart [`rive_viewmodel`](https://pub.dev/packages/rive_viewmodel) package — the optional `RiveViewModel` interface |
| `assets/templates/dart/` | Shared Mustache templates — the single source of truth for generated Dart |

## Requirements

**App / web demo**

- Flutter `>=3.41.6`
- Dart SDK `>=3.7.0 <4.0.0`

The pinned development toolchain (`.mise.toml`) is Flutter 3.44.4 / Dart 3.12.2;
CI builds the web demo on Flutter 3.41.6.

**CLI**

- Node.js `>=18`

## Development

**Run the web app locally:**

```bash
flutter pub get
flutter run -d chrome        # or -d macos for the desktop build
```

**Build the CLI from source:**

```bash
cd packages/rive-viewmodel-cli
npm install
npm run build
node dist/bin/rive-gen.js --input path/to/file.riv
```

The live demo is rebuilt and published to GitHub Pages on every push to `main`
via [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml).

## License

Licensed under the BSD 3-Clause License — see [LICENSE](LICENSE) for details.
