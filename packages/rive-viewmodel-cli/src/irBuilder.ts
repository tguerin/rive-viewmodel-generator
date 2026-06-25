/**
 * IR builder: parses a Rive file (via the rive-wasm low-level API) into a
 * language-agnostic intermediate representation that the code generator
 * consumes. This is a TypeScript port of lib/rive_parser.dart.
 */

import {
  ArtboardModel,
  EnumModel,
  ListPropertyModel,
  PropertyModel,
  PropertyType,
  RiveFileModel,
  StateMachineModel,
  ViewModelModel,
} from './models.js';
import {
  appendSuffix,
  capitalize,
  sanitizeClassName,
  sanitizePropertyName,
  toCamelCase,
  toClassName,
} from './stringUtils.js';

// DataType string values from @rive-app/canvas-advanced (string enum in WASM bindings)
const DataType = {
  boolean: 'boolean',
  number: 'number',
  string: 'string',
  color: 'color',
  list: 'list',
  enumType: 'enumType',
  trigger: 'trigger',
  viewModel: 'viewModel',
  integer: 'integer',
  listIndex: 'listIndex',
  image: 'image',
  artboard: 'artboard',
  none: 'none',
} as const;

function extractBaseName(propertyName: string): string {
  const match = propertyName.match(/^(.+?)_(\d+)$/);
  return match ? match[1] : propertyName;
}

function extractIndex(propertyName: string): number {
  const match = propertyName.match(/^(.+?)_(\d+)$/);
  return match ? (parseInt(match[2], 10) || 0) : 0;
}

function isSequentialGroup(properties: PropertyModel[]): boolean {
  if (properties.length < 2) return false;
  const firstType = properties[0].type;
  if (!properties.every((p) => p.type === firstType)) return false;
  const indices = properties
    .map((p) => extractIndex(p.originalName))
    .sort((a, b) => a - b);
  for (let i = 1; i < indices.length; i++) {
    if (indices[i] !== indices[i - 1] + 1) return false;
  }
  return true;
}

function groupPropertiesIntoLists(allProperties: PropertyModel[]): {
  individualProperties: PropertyModel[];
  listProperties: ListPropertyModel[];
} {
  const propertyGroups = new Map<string, PropertyModel[]>();

  for (const property of allProperties) {
    const baseName = extractBaseName(property.originalName);
    if (!propertyGroups.has(baseName)) propertyGroups.set(baseName, []);
    propertyGroups.get(baseName)!.push(property);
  }

  const individualProperties: PropertyModel[] = [];
  const listProperties: ListPropertyModel[] = [];

  for (const [baseName, groupProperties] of propertyGroups) {
    if (groupProperties.length > 1 && isSequentialGroup(groupProperties)) {
      groupProperties.sort(
        (a, b) => extractIndex(a.originalName) - extractIndex(b.originalName),
      );
      const firstProperty = groupProperties[0];
      const listName = sanitizePropertyName(toCamelCase(baseName));
      listProperties.push({
        name: listName,
        baseName,
        itemType: firstProperty.type,
        items: groupProperties,
        metadata: { ...firstProperty.metadata },
      });
    } else {
      individualProperties.push(...groupProperties);
    }
  }

  return { individualProperties, listProperties };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function parseViewModelToIR(
  className: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  viewModelInstance: any,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  riveFile: any,
  existingClasses: Set<string>,
  generatedClasses: Set<string>,
): ViewModelModel | null {
  if (!className) return null;
  if (generatedClasses.has(className)) return null;
  generatedClasses.add(className);

  const enums: EnumModel[] = [];
  const nestedViewModels: ViewModelModel[] = [];
  const allProperties: PropertyModel[] = [];

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const properties: Array<{ name: string; type: string }> =
    viewModelInstance.getProperties();

  for (const property of properties) {
    const sanitizedPropName = sanitizePropertyName(toCamelCase(property.name));
    if (!sanitizedPropName) continue;

    switch (property.type) {
      case DataType.enumType: {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const allEnums: any[] = riveFile.enums();
        const enumFromRive = allEnums.find((e: { name: string }) =>
          property.name.toLowerCase().includes(e.name.toLowerCase()),
        );
        const rawEnumName = enumFromRive ? enumFromRive.name : property.name;
        const enumName = sanitizeClassName(toClassName(rawEnumName));
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const enumValues: string[] = enumFromRive
          ? (enumFromRive.values as string[])
          : [];

        if (enumValues.length > 0 && !generatedClasses.has(enumName)) {
          generatedClasses.add(enumName);
          enums.push({
            name: enumName,
            values: enumValues.map((v) => ({
              name: sanitizePropertyName(toCamelCase(v)),
              value: v,
            })),
          });
        }

        allProperties.push({
          name: sanitizedPropName,
          originalName: property.name,
          type: PropertyType.enumType,
          metadata: { enumType: enumName },
        });
        break;
      }

      case DataType.viewModel: {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const nestedInstance: any = viewModelInstance.viewModel(property.name);
        if (nestedInstance) {
          const propertyNameAsClass = toClassName(property.name);
          let nestedClassName = propertyNameAsClass;

          // Match against known top-level VM class names
          for (const cls of existingClasses) {
            const clsBase = cls.replace('ViewModel', '').replace('Vm', '');
            if (propertyNameAsClass.startsWith(clsBase)) {
              nestedClassName = cls;
              break;
            }
          }

          const nestedModel = parseViewModelToIR(
            nestedClassName,
            nestedInstance,
            riveFile,
            existingClasses,
            generatedClasses,
          );
          if (nestedModel) nestedViewModels.push(nestedModel);

          allProperties.push({
            name: sanitizedPropName,
            originalName: property.name,
            type: PropertyType.viewModel,
            metadata: { returnType: nestedClassName },
          });
        }
        break;
      }

      case DataType.boolean: {
        allProperties.push({
          name: sanitizedPropName,
          originalName: property.name,
          type: PropertyType.boolean,
          metadata: {},
        });
        break;
      }

      case DataType.integer: {
        allProperties.push({
          name: sanitizedPropName,
          originalName: property.name,
          type: PropertyType.integer,
          metadata: {},
        });
        break;
      }

      case DataType.number: {
        allProperties.push({
          name: sanitizedPropName,
          originalName: property.name,
          type: PropertyType.number,
          metadata: {},
        });
        break;
      }

      case DataType.string: {
        allProperties.push({
          name: sanitizedPropName,
          originalName: property.name,
          type: PropertyType.string,
          metadata: {},
        });
        break;
      }

      case DataType.color: {
        allProperties.push({
          name: sanitizedPropName,
          originalName: property.name,
          type: PropertyType.color,
          metadata: {},
        });
        break;
      }

      case DataType.trigger: {
        const triggerName = sanitizedPropName.startsWith('trigger')
          ? sanitizedPropName
          : `trigger${capitalize(sanitizedPropName)}`;
        allProperties.push({
          name: triggerName,
          originalName: property.name,
          type: PropertyType.trigger,
          metadata: {},
        });
        break;
      }

      case DataType.image: {
        allProperties.push({
          name: sanitizedPropName,
          originalName: property.name,
          type: PropertyType.image,
          metadata: {},
        });
        break;
      }

      default:
        // Skip unsupported types (list, listIndex, artboard, none)
        break;
    }
  }

  const { individualProperties, listProperties } =
    groupPropertiesIntoLists(allProperties);

  return {
    name: className,
    className,
    properties: individualProperties,
    listProperties,
    nestedViewModels,
    enums,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function buildIR(riveFile: any, fileName: string): RiveFileModel {
  const fileNameBase = capitalize(toCamelCase(fileName.split('.')[0]));

  // --- Artboards ---
  const artboards: ArtboardModel[] = [];
  const generatedArtboardClasses = new Set<string>();
  const artboardCount: number = riveFile.artboardCount();

  for (let i = 0; i < artboardCount; i++) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const artboard: any = riveFile.artboardByIndex(i);
    const className = toClassName(artboard.name as string);

    if (generatedArtboardClasses.has(className)) {
      continue;
    }
    generatedArtboardClasses.add(className);

    const stateMachines: StateMachineModel[] = [];
    const smCount: number = artboard.stateMachineCount();
    for (let j = 0; j < smCount; j++) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const sm: any = artboard.stateMachineByIndex(j);
      if (sm?.name) {
        stateMachines.push({
          name: sm.name as string,
          enumValue: sanitizePropertyName(toCamelCase(sm.name as string)),
        });
      }
    }

    artboards.push({ name: artboard.name as string, className, stateMachines });
  }

  // --- View models ---
  const existingClasses = new Set<string>();
  const vmCount: number = riveFile.viewModelCount();

  for (let i = 0; i < vmCount; i++) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm: any = riveFile.viewModelByIndex(i);
    if (vm?.name) {
      existingClasses.add(appendSuffix(toClassName(vm.name as string), 'ViewModel'));
    }
  }

  const viewModels: ViewModelModel[] = [];
  const generatedClasses = new Set<string>();

  for (let i = 0; i < vmCount; i++) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm: any = riveFile.viewModelByIndex(i);
    if (!vm?.name) continue;

    const className = appendSuffix(toClassName(vm.name as string), 'ViewModel');

    // Get a default instance for introspection (no rendering needed)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const instance: any = vm.instance?.() ?? vm.defaultInstance?.();
    if (!instance) continue;

    const model = parseViewModelToIR(
      className,
      instance,
      riveFile,
      existingClasses,
      generatedClasses,
    );
    if (model) viewModels.push(model);
  }

  return { fileName, fileNameBase, artboards, viewModels };
}
