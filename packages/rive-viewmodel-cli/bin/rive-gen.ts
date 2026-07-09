#!/usr/bin/env node
/**
 * rive-gen CLI entry point.
 *
 * Usage:
 *   rive-gen --input path/to/file.riv [--output ./generated] [--name myFile]
 *            [--modern] [--interface] [--templates path/to/templates]
 */

import { Command } from 'commander';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { loadRiveWasm, loadRiveFile } from '../src/riveLoader.js';
import { buildIR } from '../src/irBuilder.js';
import { generate } from '../src/generator.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Resolve the templates directory across every run context:
//   1. Bundled inside the published package (dist/bin -> <pkg>/templates/dart).
//      `templates/` is copied from the repo's shared assets at build time.
//   2. Compiled from the repo (dist/bin -> repo-root/assets/templates/dart).
//   3. Source via tsx (bin -> repo-root/assets/templates/dart).
// The first candidate that exists on disk wins.
const TEMPLATE_CANDIDATES = [
  path.resolve(__dirname, '../../templates/dart'),
  path.resolve(__dirname, '../../../../assets/templates/dart'),
  path.resolve(__dirname, '../../assets/templates/dart'),
];
const DEFAULT_TEMPLATES_DIR =
  TEMPLATE_CANDIDATES.find((dir) => fs.existsSync(dir)) ??
  TEMPLATE_CANDIDATES[0];

const program = new Command();

program
  .name('rive-gen')
  .description('Generate ViewModel code from Rive (.riv) files')
  .version('0.1.0')
  .requiredOption('-i, --input <file>', 'Path to the input .riv file')
  .option(
    '-o, --output <dir>',
    'Output directory (defaults to the same directory as the input file)',
  )
  .option(
    '-n, --name <name>',
    'Output file base name without extension (defaults to input file name)',
  )
  .option(
    '--modern',
    "Use modern Rive import 'package:rive/rive.dart' instead of rive_native",
    false,
  )
  .option('--interface', 'Implement the RiveViewModel interface', false)
  .option(
    '--templates <dir>',
    `Path to Mustache templates directory (default: ${DEFAULT_TEMPLATES_DIR})`,
  )
  .action(async (options) => {
    const inputPath = path.resolve(options.input as string);

    if (!fs.existsSync(inputPath)) {
      console.error(`Error: input file not found: ${inputPath}`);
      process.exit(1);
    }

    if (!inputPath.endsWith('.riv')) {
      console.error('Error: input file must have a .riv extension');
      process.exit(1);
    }

    const inputFileName = path.basename(inputPath);
    const outputDir = options.output
      ? path.resolve(options.output as string)
      : path.dirname(inputPath);
    const outputBaseName =
      (options.name as string | undefined) ?? path.basename(inputPath, '.riv');
    const outputPath = path.join(outputDir, `${outputBaseName}.dart`);

    const templatesDir = options.templates
      ? path.resolve(options.templates as string)
      : DEFAULT_TEMPLATES_DIR;

    if (!fs.existsSync(templatesDir)) {
      console.error(
        `Error: templates directory not found: ${templatesDir}\n` +
          'Tip: run the CLI from the repo root, or pass --templates explicitly.',
      );
      process.exit(1);
    }

    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    console.log(`Parsing: ${inputPath}`);

    // 1. Load the Rive WASM runtime
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let rive: any;
    try {
      process.stdout.write('Loading Rive WASM...');
      rive = await loadRiveWasm();
      process.stdout.write(' done\n');
    } catch (err) {
      process.stdout.write('\n');
      console.error('Failed to load Rive WASM:', (err as Error).message);
      process.exit(1);
    }

    // 2. Load the .riv file
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let riveFile: any;
    try {
      riveFile = await loadRiveFile(rive, inputPath);
    } catch (err) {
      console.error('Failed to load .riv file:', (err as Error).message);
      process.exit(1);
    }

    // 3. Build the intermediate representation
    let model;
    try {
      model = buildIR(riveFile, inputFileName);
    } catch (err) {
      console.error('Failed to parse Rive file:', (err as Error).message);
      try { riveFile.unref?.(); } catch { /* ignore */ }
      process.exit(1);
    }

    console.log(
      `Found ${model.artboards.length} artboard(s), ` +
        `${model.viewModels.length} view model(s)`,
    );

    // 4. Generate code from Mustache templates
    let code: string;
    try {
      code = generate(model, templatesDir, {
        useInterface: options.interface as boolean,
        useModernRive: options.modern as boolean,
      });
    } catch (err) {
      console.error('Failed to generate code:', (err as Error).message);
      try { riveFile.unref?.(); } catch { /* ignore */ }
      process.exit(1);
    }

    // 5. Write output
    fs.writeFileSync(outputPath, code, 'utf-8');
    console.log(`Generated: ${outputPath}`);

    // Best-effort cleanup — the WASM object may not support unref in all versions
    try { riveFile.unref?.(); } catch { /* ignore */ }
  });

program.parse();
