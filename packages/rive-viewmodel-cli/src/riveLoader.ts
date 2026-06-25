/**
 * Loads the Rive WASM runtime and a .riv file for introspection.
 *
 * @rive-app/canvas-advanced is a browser-first package. To use it in Node.js
 * for file parsing only (no rendering), we stub the DOM/window globals that
 * the Emscripten-generated JS wrapper accesses during initialization.
 */

import { createRequire } from 'module';
import path from 'path';
import fs from 'fs';

const require = createRequire(import.meta.url);

/**
 * Install minimal browser-global stubs required by the Rive WASM wrapper.
 * Only the APIs touched during module init / file loading are stubbed.
 * Canvas getContext() always returns null, which makes the WebGL mesh-image
 * initializer log "No WebGL support" and gracefully fall back — that is fine
 * for introspection-only use.
 */
function installBrowserPolyfills(): void {
  const g = globalThis as Record<string, unknown>;

  if (!g['document']) {
    const fakeElement = {
      style: {} as Record<string, string>,
      innerHTML: '',
      appendChild: () => fakeElement,
      remove: () => undefined,
      setAttribute: () => undefined,
      addEventListener: () => undefined,
      removeEventListener: () => undefined,
    };

    g['document'] = {
      createElement: (_tag: string) => ({
        ...fakeElement,
        // Canvas.getContext always returns null → WebGL unavailable → graceful fallback
        getContext: () => null,
      }),
      body: {
        appendChild: () => undefined,
        remove: () => undefined,
      },
      addEventListener: () => undefined,
      removeEventListener: () => undefined,
      currentScript: null,
    };
  }

  if (!g['navigator']) {
    g['navigator'] = {
      userAgent: 'Node.js',
      mediaDevices: undefined,
    };
  }

  if (!g['window']) {
    // Many Emscripten modules use `window` as a global object store
    g['window'] = g;
  }

  // Files with embedded raster image assets make the Rive wrapper call
  // `new Image()` / `new Blob()` / `URL.createObjectURL()` during decode
  // (CanvasRenderImage.decode). We don't render, but the wrapper's load()
  // promise only resolves once every image's `onload` has fired (it counts
  // loaded vs. total assets), so the stub MUST invoke `onload` — otherwise
  // load() hangs forever. The onload handler is safe without WebGL: texture
  // upload (na.Jb) returns null early and size() just records 0x0, neither
  // of which affects view-model / artboard introspection.
  if (!g['Image']) {
    g['Image'] = class {
      onload: (() => void) | null = null;
      onerror: (() => void) | null = null;
      width = 0;
      height = 0;
      private _src = '';
      get src(): string {
        return this._src;
      }
      set src(value: string) {
        this._src = value;
        // Assigning src kicks off the (real-browser) async decode; mirror
        // that by firing onload on the next microtask so the runtime's
        // asset counter completes and load() resolves.
        queueMicrotask(() => this.onload?.());
      }
    };
  }

  // Node 18+ provides global Blob and URL; createObjectURL/revokeObjectURL
  // are not always present, so stub them defensively.
  if (typeof (g['URL'] as { createObjectURL?: unknown })?.createObjectURL !==
    'function') {
    const urlCtor = (g['URL'] ?? {}) as Record<string, unknown>;
    urlCtor['createObjectURL'] = () => 'blob:rive-introspection';
    urlCtor['revokeObjectURL'] = () => undefined;
    g['URL'] = urlCtor;
  }

  if (!g['Blob']) {
    g['Blob'] = class {
      constructor(_parts?: unknown[], _opts?: unknown) {}
    };
  }
}

function resolveWasmPath(): string {
  const packageJsonPath = require.resolve(
    '@rive-app/canvas-advanced/package.json',
  ) as string;
  const packageDir = path.dirname(packageJsonPath);
  return path.join(packageDir, 'rive.wasm');
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function loadRiveWasm(): Promise<any> {
  const wasmPath = resolveWasmPath();
  if (!fs.existsSync(wasmPath)) {
    throw new Error(`Rive WASM file not found at: ${wasmPath}`);
  }

  // Stubs must be in place before the module runs its top-level initializers
  installBrowserPolyfills();

  // Dynamic import. We use `any` to bypass the incomplete type declaration in
  // @rive-app/canvas-advanced (its .d.ts returns `Promise` without a type
  // parameter, which confuses tsc with moduleResolution NodeNext).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const mod = await import('@rive-app/canvas-advanced');
  const RiveCanvas = mod.default as unknown as (opts: {
    locateFile: (file: string) => string;
    wasmBinary?: Buffer;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  }) => Promise<any>;

  // Pass the WASM binary directly to avoid the Emscripten fetch/XHR loader,
  // which requires browser APIs not available in Node.js.
  const wasmBinary = fs.readFileSync(wasmPath);
  return RiveCanvas({
    locateFile: () => wasmPath,
    wasmBinary,
  });
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function loadRiveFile(rive: any, filePath: string): Promise<any> {
  const buffer = fs.readFileSync(filePath);
  const bytes = new Uint8Array(buffer);
  return rive.load(bytes);
}
