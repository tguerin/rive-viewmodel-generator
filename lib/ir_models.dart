enum PropertyType {
  boolean,
  number,
  string,
  color,
  enumType,
  viewModel,
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

  PropertyModel({required this.name, required this.originalName, required this.type, Map<String, dynamic>? metadata})
    : metadata = metadata ?? {};
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

class EnumModel {
  final String name;
  final List<String> values;

  EnumModel({required this.name, required this.values});
}

class ViewModelModel {
  final String name;
  final String className;
  final List<PropertyModel> properties;
  final List<ListPropertyModel> listProperties;
  final List<ViewModelModel> nestedViewModels;
  final List<EnumModel> enums;

  ViewModelModel({
    required this.name,
    required this.className,
    required this.properties,
    List<ListPropertyModel>? listProperties,
    List<ViewModelModel>? nestedViewModels,
    List<EnumModel>? enums,
  }) : listProperties = listProperties ?? [],
       nestedViewModels = nestedViewModels ?? [],
       enums = enums ?? [];
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

  ArtboardModel({required this.name, required this.className, required this.stateMachines});
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
