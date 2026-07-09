const dartReservedKeywords = new Set([
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
  'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
  'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
  'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide',
  'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
  'mixin', 'native', 'new', 'null', 'of', 'on', 'operator', 'part',
  'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
  'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'type',
  'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
]);

const dartBuiltInTypes = new Set([
  'type', 'string', 'int', 'double', 'bool', 'num', 'object', 'dynamic',
  'void', 'function', 'list', 'map', 'set', 'future', 'stream', 'iterable',
  'iterator', 'duration', 'datetime', 'uri', 'pattern', 'regexp', 'match',
  'symbol', 'stacktrace', 'error', 'exception', 'null',
]);

export function sanitizePropertyName(name: string): string {
  if (dartReservedKeywords.has(name.toLowerCase())) {
    return `${name}Property`;
  }
  // Dart identifiers cannot start with a digit (e.g. enum values "10", "20").
  // Prefix such generated names with '$' so they compile.
  if (/^[0-9]/.test(name)) {
    return `$${name}`;
  }
  return name;
}

export function sanitizeClassName(name: string): string {
  if (dartBuiltInTypes.has(name.toLowerCase())) {
    return `${name}Enum`;
  }
  return name;
}

export function capitalize(str: string): string {
  if (!str) return '';
  return str[0].toUpperCase() + str.slice(1);
}

export function uncapitalize(str: string): string {
  if (!str) return '';
  return str[0].toLowerCase() + str.slice(1);
}

export function toCamelCase(str: string): string {
  if (!str) return '';
  if (/^[a-zA-Z0-9]*$/.test(str)) return str;
  const normalized = str.replace(/[^a-zA-Z0-9]/g, ' ');
  const words = normalized.split(/\s+/).filter((w) => w.length > 0);
  if (words.length === 0) return '';
  return (
    words[0].toLowerCase() +
    words
      .slice(1)
      .map((w) => capitalize(w.toLowerCase()))
      .join('')
  );
}

export function toClassName(str: string): string {
  return capitalize(toCamelCase(str));
}

export function appendSuffix(str: string, suffix: string): string {
  if (!str.endsWith(suffix)) return `${str}${suffix}`;
  return str;
}
