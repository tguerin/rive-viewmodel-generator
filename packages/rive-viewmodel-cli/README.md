# rive-gen CLI

A Node.js CLI that generates Dart ViewModel wrapper code from Rive (`.riv`) files.

It uses `@rive-app/canvas-advanced` (the Rive JS/WASM runtime) to introspect `.riv` files and produces the same Dart output as the [web app](https://tguerin.github.io/rive-viewmodel-generator/).

## Prerequisites

- Node.js 18+
- npm 9+

## Usage

### From the repo root (development)

Build the CLI first:

```bash
cd packages/rive-viewmodel-cli
npm install
npm run build
```

Then run it:

```bash
node packages/rive-viewmodel-cli/dist/bin/rive-gen.js --input path/to/file.riv
```

### Install globally via npm link

```bash
cd packages/rive-viewmodel-cli
npm install
npm run build
npm link
```

Then use it from anywhere:

```bash
rive-gen --input path/to/MyAnimation.riv
```

## Options

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--input <file>` | `-i` | Path to the `.riv` file | **required** |
| `--output <dir>` | `-o` | Output directory | Same as input file |
| `--name <name>` | `-n` | Output file base name (no extension) | Input file name |
| `--modern` | | Use `package:rive/rive.dart` import | `package:rive_native/rive_native.dart` |
| `--interface` | | Implement `RiveViewModel` interface | false |
| `--templates <dir>` | | Custom Mustache templates directory | `assets/templates/dart/` |
| `--help` | `-h` | Display help | |
| `--version` | `-V` | Display version | |

## Examples

Generate with the legacy Rive import (default):

```bash
rive-gen -i assets/hero.riv -o lib/generated
```

Generate using the modern `package:rive` import:

```bash
rive-gen -i assets/hero.riv -o lib/generated --modern
```

Generate with the `RiveViewModel` interface implemented:

```bash
rive-gen -i assets/hero.riv -o lib/generated --modern --interface
```

Custom output file name:

```bash
rive-gen -i assets/hero_animation.riv -o lib/generated -n hero_view_model
```

## Implementation notes

The WASM runtime is browser-first. For Node.js introspection (no rendering needed),
minimal DOM stubs (`document`, `navigator`, `window`) are installed before loading the
WASM. The Canvas/WebGL renderer is not used — only the `File` / `ViewModel` / `DataEnum`
APIs are called to read the `.riv` file structure.

## Shared templates

The Mustache templates in `assets/templates/dart/` are shared between this CLI and
the Flutter web app. Pass `--templates` to use a custom template directory.
