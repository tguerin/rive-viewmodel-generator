/**
 * Code generator: transforms the IR model into source code using Mustache
 * templates. The templates are shared with the Flutter web app
 * (assets/templates/dart/).
 */

import Mustache from 'mustache';
import fs from 'fs';
import path from 'path';
import {
  EnumModel,
  ListPropertyModel,
  PropertyModel,
  PropertyType,
  RiveFileModel,
  ViewModelModel,
} from './models.js';
import { capitalize, toCamelCase, uncapitalize } from './stringUtils.js';

// Disable Mustache's HTML escaping — output is Dart source code, not HTML
Mustache.escape = (text: string) => text;

export interface GeneratorOptions {
  useInterface?: boolean;
  useModernRive?: boolean;
}

function extractIndex(propertyName: string): number {
  const match = propertyName.match(/^(.+?)_(\d+)$/);
  return match ? (parseInt(match[2], 10) || 0) : 0;
}

function collectNestedEnums(
  viewModel: ViewModelModel,
  allEnums: EnumModel[],
): void {
  for (const nested of viewModel.nestedViewModels) {
    allEnums.push(...nested.enums);
    collectNestedEnums(nested, allEnums);
  }
}

function buildEnums(model: RiveFileModel): object[] {
  const allEnums: EnumModel[] = [];
  for (const vm of model.viewModels) {
    allEnums.push(...vm.enums);
    collectNestedEnums(vm, allEnums);
  }
  return allEnums.map((e) => ({
    name: e.name,
    enumName: e.name,
    hasConstructor: true,
    values: e.values.map((v, i) => ({
      name: v.name,
      argument: v.value,
      last: i === e.values.length - 1,
    })),
  }));
}

function buildArtboards(model: RiveFileModel): object[] {
  if (model.artboards.length === 0) return [];

  const sealedClassName = `${model.fileNameBase}Artboard`;

  const seenSmEnums = new Set<string>();
  const stateMachineEnums: object[] = [];
  for (const ab of model.artboards) {
    if (ab.stateMachines.length === 0) continue;
    const enumName = `${ab.className}StateMachine`;
    if (seenSmEnums.has(enumName)) continue;
    seenSmEnums.add(enumName);
    stateMachineEnums.push({
      name: enumName,
      enumName,
      values: ab.stateMachines.map((sm, i) => ({
        name: sm.enumValue,
        argument: sm.name,
        last: i === ab.stateMachines.length - 1,
      })),
    });
  }

  const seenImplementations = new Set<string>();
  const implementations: object[] = [];
  const lastArtboard = model.artboards[model.artboards.length - 1];
  for (const ab of model.artboards) {
    if (seenImplementations.has(ab.className)) continue;
    seenImplementations.add(ab.className);
    implementations.push({
      className: ab.className,
      sealedClassName,
      originalName: ab.name,
      enumName: uncapitalize(toCamelCase(ab.name)),
      last: ab === lastArtboard,
      stateMachineGetters: ab.stateMachines.map((sm) => ({
        returnType: `${ab.className}StateMachine`,
        name: sm.enumValue,
        enumType: `${ab.className}StateMachine`,
        enumValue: sm.enumValue,
      })),
    });
  }

  return [
    {
      hasSealedClass: model.artboards.length > 0,
      name: sealedClassName,
      stateMachineEnums,
      implementations,
    },
  ];
}

function buildProperties(properties: PropertyModel[]): object[] {
  return properties.map((p) => ({
    name: p.name,
    originalName: p.originalName,
    capitalizedName: capitalize(p.name),
    streamName: `${p.name}Stream`,
    isBoolean: p.type === PropertyType.boolean,
    isNumberInt: p.type === PropertyType.integer,
    isNumberDouble: p.type === PropertyType.number,
    isString: p.type === PropertyType.string,
    isColor: p.type === PropertyType.color,
    isEnum: p.type === PropertyType.enumType,
    isViewModel: p.type === PropertyType.viewModel,
    isTrigger: p.type === PropertyType.trigger,
    isImage: p.type === PropertyType.image,
    enumType: p.metadata['enumType'] ?? '',
    returnType: p.metadata['returnType'] ?? '',
  }));
}

function buildListProperties(listProperties: ListPropertyModel[]): object[] {
  return listProperties.map((lp) => ({
    name: lp.name,
    baseName: lp.baseName,
    items: lp.items.map((item) => ({
      name: item.name,
      originalName: item.originalName,
      index: extractIndex(item.originalName),
    })),
    count: lp.items.length,
    isBoolean: lp.itemType === PropertyType.boolean,
    isNumberInt: lp.itemType === PropertyType.integer,
    isNumberDouble: lp.itemType === PropertyType.number,
    isString: lp.itemType === PropertyType.string,
    isColor: lp.itemType === PropertyType.color,
    isEnum: lp.itemType === PropertyType.enumType,
    isViewModel: lp.itemType === PropertyType.viewModel,
    isTrigger: lp.itemType === PropertyType.trigger,
    isImage: lp.itemType === PropertyType.image,
    enumType: lp.metadata['enumType'] ?? '',
    returnType: lp.metadata['returnType'] ?? '',
  }));
}

function buildViewModelEntry(
  vm: ViewModelModel,
  useInterface: boolean,
): object {
  return {
    className: vm.className,
    hasImages:
      vm.properties.some((p) => p.type === PropertyType.image) ||
      vm.listProperties.some((lp) => lp.itemType === PropertyType.image),
    properties: buildProperties(vm.properties),
    listProperties: buildListProperties(vm.listProperties),
    useInterface,
  };
}

function collectViewModelsFlat(
  vm: ViewModelModel,
  useInterface: boolean,
  result: object[],
): void {
  // Nested view models must be emitted before their parent (matching Dart behavior)
  for (const nested of vm.nestedViewModels) {
    collectViewModelsFlat(nested, useInterface, result);
  }
  result.push(buildViewModelEntry(vm, useInterface));
}

function buildViewModels(
  model: RiveFileModel,
  useInterface: boolean,
): object[] {
  const result: object[] = [];
  for (const vm of model.viewModels) {
    collectViewModelsFlat(vm, useInterface, result);
  }
  return result;
}

function loadTemplates(
  templatesDir: string,
): { mainTemplate: string; partials: Record<string, string> } {
  const partialNames = [
    'enum',
    'state_machine_enum',
    'sealed_artboard_class',
    'artboard_class',
    'view_model_class',
    'artboard_enum',
  ];

  const partials: Record<string, string> = {};
  for (const name of partialNames) {
    const filePath = path.join(templatesDir, `${name}.mustache`);
    if (fs.existsSync(filePath)) {
      partials[name] = fs.readFileSync(filePath, 'utf-8');
    }
  }

  const mainPath = path.join(templatesDir, 'main.mustache');
  if (!fs.existsSync(mainPath)) {
    throw new Error(`main.mustache not found in templates directory: ${templatesDir}`);
  }

  return { mainTemplate: fs.readFileSync(mainPath, 'utf-8'), partials };
}

export function generate(
  model: RiveFileModel,
  templatesDir: string,
  options: GeneratorOptions = {},
): string {
  const { useInterface = false, useModernRive = false } = options;

  const { mainTemplate, partials } = loadTemplates(templatesDir);

  const enums = buildEnums(model);
  const artboards = buildArtboards(model);
  const viewModels = buildViewModels(model, useInterface);
  const needPaintingImport = (viewModels as { hasImages?: boolean }[]).some(
    (vm) => vm.hasImages,
  );

  const context = {
    enums,
    artboards,
    viewModels,
    needPaintingImport,
    useModernRive,
    useLegacyRive: !useModernRive,
    useInterface,
  };

  return Mustache.render(mainTemplate, context, partials);
}
