# Changelog

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

- Enum-typed properties are now matched to their enum by the Rive runtime — the
  exact enum type name (`ViewModelInstanceEnum.enumType`) in the Flutter app, and
  the property's value set in the CLI — instead of guessing from the property
  name. Enum properties no longer need to be named after their enum; the old
  name-based match remains only as a fallback.
- Nested `viewModel`-typed properties now resolve to their real top-level class
  (matched by property shape) instead of generating a duplicate class named
  after the property. A view model embedded in another (used as a library) now
  returns the shared class — with its instance enum and factories — and the
  singular/plural property-name mismatches the old name heuristic missed are
  handled too.

## 0.1.0

- Initial release.
