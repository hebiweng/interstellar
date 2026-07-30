/**
 * Ambient type declarations for Cloudflare Workers runtime APIs.
 * These types are only needed for TypeScript compilation in the local dev
 * environment. At runtime, Cloudflare provides these globals natively.
 *
 * If @cloudflare/workers-types is installed in the future, this file can be
 * replaced by adding "types": ["@cloudflare/workers-types"] to tsconfig.
 */

// ── Module: cloudflare:workers ──

declare module "cloudflare:workers" {
  export const env: Record<string, unknown>;
}

// ── Cloudflare-specific globals ──

interface Fetcher {
  fetch(request: Request): Promise<Response>;
}

interface D1Database {
  prepare(query: string): D1PreparedStatement;
  dump(): Promise<ArrayBuffer>;
  batch<T extends unknown[]>(statements: D1PreparedStatement[]): Promise<T>;
  exec(query: string): Promise<D1ExecResult>;
}

interface D1PreparedStatement {
  bind(...values: unknown[]): D1PreparedStatement;
  first<T extends Record<string, unknown>>(colName?: string): Promise<T | null>;
  run(): Promise<D1Result<unknown>>;
  all<T extends Record<string, unknown>>(): Promise<D1Result<T>>;
  raw<T extends unknown[]>(): Promise<T>;
}

interface D1Result<T> {
  results: T[];
  success: boolean;
  error?: string;
  meta: {
    changed_db: boolean;
    changes: number;
    duration: number;
    last_row_id: number;
    rows_read: number;
    rows_written: number;
    size_after: number;
  };
}

interface D1ExecResult {
  count: number;
  results: D1Result<unknown>[];
  success: boolean;
  error?: string;
}
