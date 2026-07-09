// Copies the shared Mustache templates (repo-root assets/templates) into the
// package so the published npm tarball is self-contained. Run as part of the
// build; the resulting `templates/` dir is gitignored (it is a build artifact).
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = path.resolve(here, '../../../assets/templates');
const dest = path.resolve(here, '../templates');

if (!fs.existsSync(src)) {
  console.error(`copy-templates: source not found: ${src}`);
  process.exit(1);
}

fs.rmSync(dest, { recursive: true, force: true });
fs.cpSync(src, dest, { recursive: true });
console.log(`copy-templates: ${src} -> ${dest}`);
