/**
 * Catch-all API proxy: forwards /api/v1/* requests to the FastAPI backend.
 *
 * This route acts as a safety net when the Vite dev server proxy or the
 * production Caddy reverse-proxy are not available (e.g. standalone Next.js
 * in Docker). It reads `INTERSTELLAR_API_PROXY_TARGET` at runtime and proxies
 * every HTTP method to the backend service.
 *
 * Priority chain:
 *   1. Vite dev server proxy  (INTERSTELLAR_API_PROXY_TARGET is set + Vite dev)
 *   2. Caddy reverse-proxy    (production)
 *   3. This catch-all route   (standalone Next.js without reverse-proxy)
 */

const DEFAULT_PROXY_TARGET = "http://127.0.0.1:8018";

function proxyTarget(): string {
  return process.env.INTERSTELLAR_API_PROXY_TARGET?.trim() || DEFAULT_PROXY_TARGET;
}

/** Headers that must not be forwarded because they are hop-by-hop or would
 *  confuse the backend (e.g. host from the browser). */
const HOP_BY_HOP = new Set([
  "host",
  "connection",
  "keep-alive",
  "transfer-encoding",
  "te",
  "upgrade",
  "proxy-connection",
  "proxy-authorization",
]);

function forwardHeaders(request: Request): Headers {
  const out = new Headers();
  for (const [key, value] of request.headers.entries()) {
    if (!HOP_BY_HOP.has(key.toLowerCase())) {
      out.set(key, value);
    }
  }
  return out;
}

async function proxyRequest(request: Request, pathSegments: string[]): Promise<Response> {
  const target = proxyTarget();
  const path = pathSegments.join("/");
  // The backend routers use prefix="/api/v1", so their routes are
  // e.g. /api/v1/subjects, /api/v1/calculations. The Next.js catch-all
  // strips the /api/v1/ prefix, so we must re-add it when forwarding.
  const url = `${target}/api/v1/${path}`;

  try {
    const headers = forwardHeaders(request);
    // Let fetch set the correct content-length for the body.
    headers.delete("content-length");

    const init: RequestInit = {
      method: request.method,
      headers,
    };

    // Only include a body for methods that carry one.
    if (request.method !== "GET" && request.method !== "HEAD") {
      init.body = request.body;
      // @ts-expect-error duplex is required for streaming request bodies in
      // Node.js fetch but not yet in the TypeScript DOM types.
      init.duplex = "half";
    }

    const upstream = await fetch(url, init);

    // Build a new response, filtering out problematic response headers.
    const resHeaders = new Headers();
    for (const [key, value] of upstream.headers.entries()) {
      const lower = key.toLowerCase();
      if (!HOP_BY_HOP.has(lower) && lower !== "content-encoding") {
        resHeaders.set(key, value);
      }
    }

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: resHeaders,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({
        detail: `API proxy failed: ${message}`,
        proxy_target: target,
        path: `/${path}`,
      }),
      {
        status: 502,
        headers: { "content-type": "application/json" },
      },
    );
  }
}

// Next.js App Router route handlers receive params as a Promise in newer
// versions. We accept both shapes for compatibility.
type RouteContext = { params: Promise<{ path: string[] }> | { path: string[] } };

async function resolvePath(ctx: RouteContext): Promise<string[]> {
  const params = await ctx.params;
  return params.path;
}

export async function GET(request: Request, ctx: RouteContext) {
  return proxyRequest(request, await resolvePath(ctx));
}

export async function POST(request: Request, ctx: RouteContext) {
  return proxyRequest(request, await resolvePath(ctx));
}

export async function PUT(request: Request, ctx: RouteContext) {
  return proxyRequest(request, await resolvePath(ctx));
}

export async function PATCH(request: Request, ctx: RouteContext) {
  return proxyRequest(request, await resolvePath(ctx));
}

export async function DELETE(request: Request, ctx: RouteContext) {
  return proxyRequest(request, await resolvePath(ctx));
}

export async function OPTIONS(request: Request, ctx: RouteContext) {
  return proxyRequest(request, await resolvePath(ctx));
}
