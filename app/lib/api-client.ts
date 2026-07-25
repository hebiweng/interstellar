/**
 * 统一 API 基础设施。
 *
 * 设计目标：
 * - 消除 5 个 API 模块中重复的 apiBase() 实现
 * - 统一超时控制（默认 30s，占星计算/AI 可覆盖）
 * - 统一 credentials（"include"，修复 interstellar-api 的缺失）
 * - 统一重试（仅 502/503/504，最多 2 次）
 * - 支持请求取消（AbortSignal）
 * - 提供通用 ApiError，但各业务模块仍可抛自己的 error 子类以保持 instanceof 兼容
 */

const DEFAULT_TIMEOUT_MS = 30_000;
const MAX_RETRIES = 2;
const RETRYABLE_STATUS = new Set([502, 503, 504]);
const RETRY_DELAY_MS = 500;

/** 返回去尾斜杠的 API 基地址（统一替代 5 处重复的 apiBase）。 */
export function apiBase(): string {
  const configured = process.env.NEXT_PUBLIC_INTERSTELLAR_API_URL?.trim();
  return configured ? configured.replace(/\/$/, "") : "/api/v1";
}

/** 通用 API 错误。各业务模块可继承此类以保持 instanceof 兼容。 */
export class ApiError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/** 超时错误，code 固定为 REQUEST_TIMEOUT。 */
export class ApiTimeoutError extends ApiError {
  constructor(timeoutMs: number) {
    super(`请求超时（${timeoutMs}ms）`, "REQUEST_TIMEOUT", undefined);
    this.name = "ApiTimeoutError";
  }
}

/** 中止错误，code 固定为 REQUEST_ABORTED。 */
export class ApiAbortError extends ApiError {
  constructor() {
    super("请求已被取消", "REQUEST_ABORTED", undefined);
    this.name = "ApiAbortError";
  }
}

export type FetchOptions = {
  method?: string;
  body?: string;
  headers?: Record<string, string>;
  /** 超时毫秒数，默认 30000。 */
  timeoutMs?: number;
  /** 外部传入的 AbortSignal，与内部超时 signal 合并。 */
  signal?: AbortSignal;
  /** 是否禁用重试（默认 false，即启用）。 */
  noRetry?: boolean;
  /** 是否发送 credentials，默认 "include"。 */
  credentials?: RequestCredentials;
  /** 自定义 Accept 头。 */
  accept?: string;
  /** 是否有 body（决定是否设置 Content-Type）。 */
  hasBody?: boolean;
};

/**
 * 合并外部 signal 与内部超时 signal。
 * 任一触发都会中止 fetch。
 */
function mergeSignals(external: AbortSignal | undefined, internal: AbortSignal): AbortSignal {
  if (!external) return internal;
  if (external.aborted) return external;
  const controller = new AbortController();
  const onAbort = () => controller.abort();
  external.addEventListener("abort", onAbort, { once: true });
  internal.addEventListener("abort", onAbort, { once: true });
  return controller.signal;
}

function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, ms);
    signal?.addEventListener("abort", () => {
      clearTimeout(timer);
      reject(new ApiAbortError());
    }, { once: true });
  });
}

/**
 * 带超时、重试、取消的 fetch 封装。
 *
 * 返回原始 Response，由调用方决定如何解析 body 和构造业务 error。
 * 超时抛 ApiTimeoutError，外部 abort 抛 ApiAbortError。
 * 502/503/504 自动重试（最多 MAX_RETRIES 次），除非 noRetry=true。
 */
export async function fetchWithTimeout(
  path: string,
  options: FetchOptions = {},
): Promise<Response> {
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const url = `${apiBase()}${path}`;
  const credentials = options.credentials ?? "include";
  const hasBody = options.hasBody ?? Boolean(options.body);

  const headers: Record<string, string> = {
    Accept: options.accept ?? "application/json, application/problem+json",
    ...(hasBody ? { "Content-Type": "application/json" } : {}),
    ...(options.headers ?? {}),
  };

  let lastError: Error | undefined;
  const maxAttempts = options.noRetry ? 1 : MAX_RETRIES + 1;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const timeoutController = new AbortController();
    const timeoutId = setTimeout(() => timeoutController.abort(), timeoutMs);
    const signal = mergeSignals(options.signal, timeoutController.signal);

    try {
      const response = await fetch(url, {
        method: options.method,
        body: options.body,
        headers,
        credentials,
        signal,
      });

      clearTimeout(timeoutId);

      if (RETRYABLE_STATUS.has(response.status) && attempt < maxAttempts - 1) {
        await sleep(RETRY_DELAY_MS * (attempt + 1), options.signal);
        continue;
      }

      return response;
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof DOMException && error.name === "AbortError") {
        if (options.signal?.aborted) throw new ApiAbortError();
        if (timeoutController.signal.aborted) throw new ApiTimeoutError(timeoutMs);
        throw new ApiAbortError();
      }

      if (error instanceof ApiAbortError || error instanceof ApiTimeoutError) throw error;

      lastError = error instanceof Error ? error : new Error(String(error));

      if (attempt < maxAttempts - 1) {
        await sleep(RETRY_DELAY_MS * (attempt + 1), options.signal);
        continue;
      }
    }
  }

  throw lastError ?? new ApiError("请求失败且未捕获具体错误", "REQUEST_FAILED", undefined);
}

/**
 * 解析 JSON 错误响应体。
 * 返回 { message, detail, code, fields } 或 null（body 非 JSON / 为空）。
 */
export async function parseJsonErrorBody(
  response: Response,
): Promise<{
  message?: string;
  detail?: string;
  code?: string;
  fields?: unknown;
  raw: Record<string, unknown> | null;
} | null> {
  const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.includes("json")) return null;
  const body = await response.json().catch(() => null) as Record<string, unknown> | null;
  if (!body) return null;
  return {
    message: typeof body.message === "string" ? body.message : undefined,
    detail: typeof body.detail === "string" ? body.detail : undefined,
    code: typeof body.code === "string" ? body.code : undefined,
    fields: body.fields,
    raw: body,
  };
}

/**
 * 请求并解析 JSON。
 *
 * 成功返回 parsed body；失败时调用 errorFactory 构造业务 error。
 * errorFactory 接收 (status, errorBody, fallbackMessage)，返回 Error 子类。
 * 这样各业务模块可以抛自己的 error 类，保持 instanceof 兼容。
 */
export async function requestJson<T>(
  path: string,
  options: FetchOptions = {},
  errorFactory: (status: number, errorBody: Awaited<ReturnType<typeof parseJsonErrorBody>>, fallbackMessage: string) => Error,
): Promise<T> {
  const response = await fetchWithTimeout(path, options);
  const errorBody = await parseJsonErrorBody(response);

  if (!response.ok) {
    const fallback = `API 请求失败（${response.status}）`;
    throw errorFactory(response.status, errorBody, fallback);
  }

  if (errorBody?.raw == null) {
    throw errorFactory(response.status, null, "计算服务返回了空响应。");
  }

  return errorBody.raw as T;
}

/**
 * 请求文本类制品（如 markdown 技术文档）。
 *
 * errorFactory 用于构造业务 error。
 * headerExtractor 从 response 提取自定义 header。
 */
export async function requestText(
  path: string,
  options: FetchOptions = {},
  errorFactory: (status: number, fallbackMessage: string) => Error,
): Promise<{ text: string; response: Response }> {
  const response = await fetchWithTimeout(path, options);
  if (!response.ok) {
    throw errorFactory(response.status, `请求失败（${response.status}）`);
  }
  const text = await response.text();
  return { text, response };
}

/**
 * 请求二进制文件（Blob）。
 */
export async function requestBlob(
  path: string,
  options: FetchOptions = {},
  errorFactory: (status: number, fallbackMessage: string) => Error,
): Promise<Blob> {
  const response = await fetchWithTimeout(path, options);
  if (!response.ok) {
    throw errorFactory(response.status, `导出失败（${response.status}）`);
  }
  return response.blob();
}
