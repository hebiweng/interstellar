import { OPERATIONS, type OperationId } from "./operations";

export interface RequestOptions {
  path?: Record<string, string | number>;
  query?: Record<string, string | number | boolean | ReadonlyArray<string | number> | null>;
  body?: unknown;
  headers?: Record<string, string>;
  signal?: AbortSignal;
}

export interface InterstellarClientOptions {
  bearerToken?: string;
  fetchImpl?: typeof fetch;
}

export class InterstellarApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly payload: unknown,
  ) {
    super(`Interstellar API returned HTTP ${status}`);
    this.name = "InterstellarApiError";
  }
}

export class InterstellarClient {
  private readonly fetchImpl: typeof fetch;

  constructor(
    private readonly baseUrl: string,
    private readonly options: InterstellarClientOptions = {},
  ) {
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async request<T>(operationId: OperationId, options: RequestOptions = {}): Promise<T> {
    const definition = OPERATIONS[operationId];
    const url = this.url(definition.path, options.path ?? {}, options.query ?? {});
    const headers = new Headers(options.headers);
    headers.set("Accept", "application/json");
    if (this.options.bearerToken) {
      headers.set("Authorization", `Bearer ${this.options.bearerToken}`);
    }
    let body: BodyInit | undefined;
    if (options.body !== undefined) {
      headers.set("Content-Type", "application/json");
      body = JSON.stringify(options.body);
    }
    const response = await this.fetchImpl(url, {
      method: definition.method,
      headers,
      body,
      signal: options.signal,
    });
    const contentType = response.headers.get("content-type") ?? "";
    const payload = response.status === 204
      ? undefined
      : contentType.includes("json")
        ? await response.json()
        : await response.text();
    if (!response.ok) {
      throw new InterstellarApiError(response.status, payload);
    }
    return payload as T;
  }

  private url(
    route: string,
    path: Record<string, string | number>,
    query: NonNullable<RequestOptions["query"]>,
  ): string {
    let rendered = route;
    for (const [key, value] of Object.entries(path)) {
      rendered = rendered.replace(`{${key}}`, encodeURIComponent(String(value)));
    }
    if (rendered.includes("{") || rendered.includes("}")) {
      throw new Error(`Missing path parameter for ${route}`);
    }
    const url = new URL(`${this.baseUrl.replace(/\/$/, "")}${rendered}`);
    for (const [key, value] of Object.entries(query)) {
      if (value === null) continue;
      const values = Array.isArray(value) ? value : [value];
      for (const item of values) url.searchParams.append(key, String(item));
    }
    return url.toString();
  }
}
