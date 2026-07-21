# Changelog

## 0.4.0

### Added

- **Trigger streams.** Each trigger property now generates a broadcast
  `Stream<void>` in addition to the existing fire method, so you can react to a
  trigger with `.listen(...)` instead of polling. Named triggers expose an
  `on<Name>Triggered` getter (a leading `trigger` prefix is stripped, e.g.
  `triggerJump` → `onJumpTriggered`); indexed trigger collections expose a
  `<name>Stream(int index)` method. The stream attaches a listener to the
  underlying Rive trigger on first subscribe and removes it on cancel.

  Thanks to [@cbacouelle](https://github.com/cbacouelle) (Clément Bacouelle) for
  contributing this feature (#15).

## 0.3.1

### Fixed

- `rive-gen --version` now reports the installed package version. It was
  hardcoded to `0.1.0` in the CLI entry point and never updated, so every
  published release printed `0.1.0` regardless of the real version. The version
  is now read from `package.json` at runtime.

## 0.3.0

### Fixed

- Enum-typed properties are now matched to their enum by the Rive runtime — the
  exact enum type name (`ViewModelInstanceEnum.enumType`) in the Flutter app, and
  the property's value set in the CLI — instead of guessing from the property
  name. Enum properties no longer need to be named after their enum; the old
  name-based match remains only as a fallback.

### Docs

- Corrected the README's generated-code example, which showed an enum round-trip
  via the identifier-based `.name` (renamed by `--obfuscate` / minified release
  builds). Generated enums round-trip through explicit string-literal fields
  (`value` / `instanceName`) and are safe under obfuscation; added a regression
  test that locks this in.

## 0.2.0

### Added

- **Named view-model instance support.** When a view model declares named
  instances (presets) in the Rive editor, the generator now emits:
  - a typed `<ViewModel>Instance` enum of the preset names, and
  - `<ViewModel>.fromInstance(File file, <ViewModel>Instance instance)` and
    `<ViewModel>.fromDefaultInstance(File file)` factory constructors.

  This lets you select a preset type-safely instead of calling
  `createInstanceByName` with a raw string. View models without named instances
  generate exactly as before.

### Fixed

- Nested `viewModel`-typed properties now resolve to their real top-level class
  (matched by property shape) instead of generating a duplicate class named
  after the property. A view model embedded in another (used as a library) now
  returns the shared class — with its instance enum and factories — and the
  singular/plural property-name mismatches the old name heuristic missed are
  handled too.

## 0.1.0

- Initial release.
