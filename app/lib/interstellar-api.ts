export type CatalogKind = "techniques" | "topics" | "intents";

export type RecipeNode = {
  node_id: string;
  calculation_id: string;
  tier: "required" | "recommended" | "optional";
  selected: boolean;
  locked: boolean;
  availability: "available" | "degraded" | "blocked";
  blocking_reasons: Array<{ code: string; message?: string }>;
  output_ids: string[];
};

export type RecipeDocument = {
  recipe_id: string;
  entry_point_id: string;
  content_hash: string;
  status: string;
  nodes: RecipeNode[];
  warnings: Array<{ code: string; message?: string; detail?: string }>;
  outputs: {
    view_ids: string[];
    report_profile_ids: string[];
    exports: string[];
  };
  resource_estimate: {
    execution_mode: "sync" | "async";
    duration_ms_p50: number;
    search_points: number;
    class: string;
  };
};

export type ConfirmedRun = {
  status: string;
  id?: string;
  job_id?: string;
  links?: { self?: string; events?: string };
};

export class InterstellarApiError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = "InterstellarApiError";
  }
}

function apiBase(): string {
  const configured = process.env.NEXT_PUBLIC_INTERSTELLAR_API_URL?.trim();
  if (!configured) {
    throw new InterstellarApiError(
      "尚未配置 NEXT_PUBLIC_INTERSTELLAR_API_URL；当前页面只能浏览目录，不能生成真实预检。",
      "API_NOT_CONFIGURED",
    );
  }
  return configured.replace(/\/$/, "");
}

async function requestJson<T>(path: string, init: RequestInit): Promise<T> {
  const response = await fetch(`${apiBase()}${path}`, {
    ...init,
    headers: {
      Accept: "application/json, application/problem+json",
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
  const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.includes("json")) {
    throw new InterstellarApiError(
      `API 返回了 ${contentType || "未知格式"}，请检查 API 地址是否误指向前端页面。`,
      "INVALID_API_CONTENT_TYPE",
      response.status,
    );
  }
  const body = await response.json() as Record<string, unknown>;
  if (!response.ok) {
    const detail = typeof body.detail === "string" ? body.detail : `API 请求失败（${response.status}）`;
    const code = typeof body.code === "string" ? body.code : "API_REQUEST_FAILED";
    throw new InterstellarApiError(detail, code, response.status);
  }
  return body as T;
}

function selectionFor(kind: CatalogKind, selectedItem: string): Record<string, string> {
  if (kind === "techniques") return { technique_id: selectedItem };
  if (kind === "intents") return { analysis_intent_id: selectedItem };
  return { topic_model_id: selectedItem };
}

export async function resolveSampleRecipe(input: {
  entryPointId: string;
  catalogKind: CatalogKind;
  selectedItem: string;
}): Promise<RecipeDocument> {
  const subject = await requestJson<{ version: { id: string } }>("/subjects", {
    method: "POST",
    body: JSON.stringify({
      workspace_id: "workspace-browser-demo",
      version: {
        kind: "person",
        display_name: "阿斯特拉（虚拟示例）",
        time_spec: {
          calendar: "gregorian",
          local_value: "1992-03-28T21:16",
          precision: "minute",
          timezone_id: "Asia/Shanghai",
          utc_candidates: [],
          selected_utc: null,
          confidence: "high",
          source: { kind: "bundled_virtual_fixture", description: "Interstellar M4 UI fixture" },
          warnings: [],
        },
        location: {
          name: "Hangzhou",
          country_code: "CN",
          latitude: 30.2741,
          longitude: 120.1551,
          timezone_id: "Asia/Shanghai",
          source: "bundled_virtual_fixture",
          warnings: [],
        },
        attributes: { virtual_fixture: true },
        source: { kind: "bundled_virtual_fixture", description: "Not a real person" },
      },
    }),
  });

  const draft = await requestJson<{ draft_id: string; revision: number }>("/analysis-drafts", {
    method: "POST",
    body: JSON.stringify({
      workspace_id: "workspace-browser-demo",
      entry_point_id: input.entryPointId,
      selection: selectionFor(input.catalogKind, input.selectedItem),
      subject_roles: [{ role: "primary", subject_version_id: subject.version.id }],
      time_context: input.entryPointId === "entry.personal_dashboard" ? { mode: "current" } : null,
      requested_outputs: { exports: ["json", "svg"] },
    }),
  });

  return requestJson<RecipeDocument>("/analysis-recipes/resolve", {
    method: "POST",
    body: JSON.stringify({ draft_id: draft.draft_id, draft_revision: draft.revision }),
  });
}

export async function confirmRecipe(recipe: RecipeDocument): Promise<ConfirmedRun> {
  return requestJson<ConfirmedRun>(`/analysis-recipes/${recipe.recipe_id}/confirm`, {
    method: "POST",
    headers: { Prefer: "respond-async" },
    body: JSON.stringify({
      recipe_content_hash: recipe.content_hash,
      outputs: ["snapshot"],
      report_requests: [],
    }),
  });
}
