enum PropertyType {
  boolean,
  number,
  string,
  color,
  enumType,
  viewModel,
  viewModelList,
  trigger,
  list,
  none,
  integer,
  symbolListIndex,
  image,
}

class PropertyModel {
  final String name;
  final String originalName;
  final PropertyType type;
  final Map<String, dynamic> metadata;

  PropertyModel({
    required this.name,
    required this.originalName,
    required this.type,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};
}

class ListPropertyModel {
  final String name;
  final String baseName;
  final PropertyType itemType;
  final List<PropertyModel> items;
  final Map<String, dynamic> metadata;

  ListPropertyModel({
    required this.name,
    required this.baseName,
    required this.itemType,
    required this.items,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};
}

class EnumValueModel {
  /// Sanitized, Dart-legal enum value identifier (e.g. `staticProperty`).
  final String name;

  /// Original Rive enum value string used for runtime round-tripping
  /// (e.g. `static`).
  final String value;

  EnumValueModel({required this.name, required this.value});
}

/// A named view model instance (a preset authored in the Rive editor).
class InstanceModel {
  /// Sanitized, Dart-legal enum value identifier (e.g. `darkMode`).
  final String name;

  /// Original instance name used at runtime with `createInstanceByName`
  /// (e.g. `dark_mode`).
  final String value;

  InstanceModel({required this.name, required this.value});
}

class EnumModel {
  final String name;
  final List<EnumValueModel> values;

  EnumModel({required this.name, required this.values});
}

class ViewModelModel {
  final String name;
  final String className;
  final List<PropertyModel> properties;
  final List<ListPropertyModel> listProperties;
  final List<ViewModelModel> nestedViewModels;
  final List<EnumModel> enums;

  /// Named instances (presets) authored for this view model. Only populated
  /// for top-level view models, which can be resolved from the file by name.
  final List<InstanceModel> instances;

  /// The view model's original name in the Rive file (e.g. `Widget`), used at
  /// runtime with `File.viewModelByName`. Only meaningful when [instances] is
  /// non-empty.
  final String? runtimeName;

  ViewModelModel({
    required this.name,
    required this.className,
    required this.properties,
    List<ListPropertyModel>? listProperties,
    List<ViewModelModel>? nestedViewModels,
    List<EnumModel>? enums,
    List<InstanceModel>? instances,
    this.runtimeName,
  }) : listProperties = listProperties ?? [],
       nestedViewModels = nestedViewModels ?? [],
       enums = enums ?? [],
       instances = instances ?? [];
}

class StateMachineModel {
  final String name;
  final String enumValue;

  StateMachineModel({required this.name, required this.enumValue});
}

class ArtboardModel {
  final String name;
  final String className;
  final List<StateMachineModel> stateMachines;

  ArtboardModel({
    required this.name,
    required this.className,
    required this.stateMachines,
  });
}

class RiveFileModel {
  final String fileName;
  final String fileNameBase;
  final List<ArtboardModel> artboards;
  final List<ViewModelModel> viewModels;

  RiveFileModel({
    required this.fileName,
    required this.fileNameBase,
    required this.artboards,
    required this.viewModels,
  });
}
