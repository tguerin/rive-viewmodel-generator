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

/** A named view model instance (a preset authored in the Rive editor). */
export interface InstanceModel {
  /** Sanitized, Dart-legal enum value identifier (e.g. `cashEuros`). */
  name: string;
  /** Original instance name used with `createInstanceByName` (e.g. `cash_euros`). */
  value: string;
}

export interface ViewModelModel {
  name: string;
  className: string;
  properties: PropertyModel[];
  listProperties: ListPropertyModel[];
  nestedViewModels: ViewModelModel[];
  enums: EnumModel[];
  /** Named instances; only populated for top-level view models. */
  instances: InstanceModel[];
  /** The view model's original name in the file (e.g. `VmCoin`), used with
   * `viewModelByName`. Only meaningful when `instances` is non-empty. */
  runtimeName?: string;
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
