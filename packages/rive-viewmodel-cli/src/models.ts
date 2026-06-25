export enum PropertyType {
  boolean = 'boolean',
  number = 'number',
  string = 'string',
  color = 'color',
  enumType = 'enumType',
  viewModel = 'viewModel',
  trigger = 'trigger',
  list = 'list',
  none = 'none',
  integer = 'integer',
  symbolListIndex = 'symbolListIndex',
  image = 'image',
}

export interface PropertyModel {
  name: string;
  originalName: string;
  type: PropertyType;
  metadata: Record<string, string>;
}

export interface ListPropertyModel {
  name: string;
  baseName: string;
  itemType: PropertyType;
  items: PropertyModel[];
  metadata: Record<string, string>;
}

export interface EnumValueModel {
  /** Sanitized, Dart-legal enum value identifier (e.g. `staticProperty`). */
  name: string;
  /** Original Rive enum value string used for runtime round-tripping (e.g. `static`). */
  value: string;
}

export interface EnumModel {
  name: string;
  values: EnumValueModel[];
}

export interface ViewModelModel {
  name: string;
  className: string;
  properties: PropertyModel[];
  listProperties: ListPropertyModel[];
  nestedViewModels: ViewModelModel[];
  enums: EnumModel[];
}

export interface StateMachineModel {
  name: string;
  enumValue: string;
}

export interface ArtboardModel {
  name: string;
  className: string;
  stateMachines: StateMachineModel[];
}

export interface RiveFileModel {
  fileName: string;
  fileNameBase: string;
  artboards: ArtboardModel[];
  viewModels: ViewModelModel[];
}
