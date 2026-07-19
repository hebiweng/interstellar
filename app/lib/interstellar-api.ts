export type NatalPoint = {
  point_id: string;
  kind: string;
  sign: string;
  degree_in_sign: number;
  house: number | null;
  retrograde: boolean | null;
  motion_interpretation: string;
  solar_relation?: string | null;
  solar_elongation_deg?: number | null;
  out_of_bounds?: boolean | null;
  distance_from_previous_cusp_deg?: number | null;
  distance_to_next_cusp_deg?: number | null;
  house_position_fraction?: number | null;
  visibility_state?: string | null;
  oriental_occidental?: string | null;
  formula_ref?: string | null;
  catalog_object_ref?: string | null;
  status_refs?: string[];
  position: {
    ecliptic: { longitude_deg: number; latitude_deg?: number | null };
    equatorial?: { right_ascension_deg?: number | null; declination_deg?: number | null };
    distance_au?: number | null;
    velocity?: {
      longitude_deg_per_day?: number | null;
      latitude_deg_per_day?: number | null;
      right_ascension_deg_per_day?: number | null;
      declination_deg_per_day?: number | null;
      distance_au_per_day?: number | null;
    };
    motion_state?: string;
    frame?: string;
    center?: string;
    epoch?: string;
    uncertainty_arcsec?: number | null;
  };
};

export type NatalHouse = {
  number: number;
  cusp_longitude_deg: number;
  sign: string;
  degree_in_sign: number;
  span_deg: number;
  traditional_ruler_ids: string[];
  modern_ruler_ids: string[];
  point_ids: string[];
  intercepted_signs: string[];
  repeated_cusp_sign: boolean;
};

export type NatalAspect = {
  aspect_id: string;
  point_a: string;
  point_b: string;
  type: string;
  exact_angle_deg: number;
  actual_angle_deg: number;
  orb_deg: number;
  applying_state: string;
  strength: number;
  rule_refs?: string[];
};

export type NatalSnapshot = {
  id: string;
  status: string;
  maturity: string;
  input_fingerprint: string;
  engine: { name: string; version: string };
  datasets?: Array<{ id?: string; version?: string }> | Record<string, string>;
  warnings: Array<{ code: string; message: string }>;
  request?: Record<string, unknown>;
  result: {
    points: NatalPoint[];
    houses: NatalHouse[];
    aspects: NatalAspect[];
    distributions?: Array<{
      dimension: string;
      categories: Array<{ category_id: string; count: number; percentage?: number }>;
    }>;
    structure?: Record<string, unknown>;
    classical?: Record<string, unknown>;
    dignities?: Array<Record<string, unknown>>;
    lots?: Array<Record<string, unknown>>;
    receptions?: Array<Record<string, unknown>>;
    dispositors?: Record<string, unknown>;
    astronomical_context?: Record<string, unknown>;
    output_manifest?: Array<Record<string, unknown>>;
  };
};

export type NatalPersonInput = {
  displayName: string;
  relation: "self" | "family" | "partner" | "friend" | "client" | "other";
  localDate: string;
  localTime: string;
  timezoneId: string;
  placeName: string;
  countryCode: string;
  latitude: number;
  longitude: number;
  timeConfidence: "high" | "medium" | "low";
};

export type NatalCalculationSettings = {
  houseSystem:
    | "placidus"
    | "whole_sign"
    | "koch"
    | "porphyry"
    | "regiomontanus"
    | "campanus"
    | "equal"
    | "alcabitius"
    | "topocentric"
    | "morinus"
    | "krusinski"
    | "vehlow";
  nodeType: "true" | "mean" | "both";
  pointIds: string[];
  aspectIds: string[];
  orbOverrides: Record<string, number>;
};

export type AiProvider = {
  provider_id: "openai" | "moonshot";
  label: string;
  configured: boolean;
  availability: string;
  blocking_reason?: string;
  models: Array<{ model_id: "gpt" | "kimi"; label: string; configured: boolean }>;
};

export type ItemInterpretation = {
  status: "available" | "unavailable";
  title?: string;
  facts?: string[];
  meaning?: string;
  synthesis?: string;
  rule_refs?: string[];
  source_refs?: string[];
  template_version?: string;
  maturity?: string;
  unavailable_reason?: string;
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
      "尚未配置计算服务地址。当前可浏览虚拟验收样例，新增人物与真实排盘需连接 Interstellar API。",
      "API_NOT_CONFIGURED",
    );
  }
  return configured.replace(/\/$/, "");
}

async function requestJson<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${apiBase()}${path}`, {
    ...init,
    headers: {
      Accept: "application/json, application/problem+json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...init.headers,
    },
  });
  const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.includes("json")) {
    throw new InterstellarApiError(
      `计算服务返回了 ${contentType || "未知格式"}。当前地址可能误指向了前端网页，而不是 /api/v1。`,
      "INVALID_API_CONTENT_TYPE",
      response.status,
    );
  }
  const body = await response.json() as Record<string, unknown>;
  if (!response.ok) {
    const fields = body.fields && typeof body.fields === "object"
      ? ` ${JSON.stringify(body.fields)}`
      : "";
    const detail = typeof body.detail === "string" ? body.detail : `API 请求失败（${response.status}）`;
    const code = typeof body.code === "string" ? body.code : "API_REQUEST_FAILED";
    throw new InterstellarApiError(`${detail}${fields}`, code, response.status);
  }
  return body as T;
}

async function requestText(path: string): Promise<string> {
  const response = await fetch(`${apiBase()}${path}`, {
    headers: { Accept: "text/markdown, text/plain" },
  });
  if (!response.ok) {
    throw new InterstellarApiError(`技术推演导出失败（${response.status}）`, "EXPORT_FAILED", response.status);
  }
  return response.text();
}

export async function createPersonAndNatalCalculation(
  person: NatalPersonInput,
  settings: NatalCalculationSettings,
): Promise<{ subjectId: string; subjectVersionId: string; snapshot: NatalSnapshot }> {
  const subject = await requestJson<{
    subject: { id: string };
    version: { id: string };
  }>("/subjects", {
    method: "POST",
    body: JSON.stringify({
      workspace_id: "workspace-browser-local",
      version: {
        kind: "person",
        display_name: person.displayName,
        time_spec: {
          calendar: "gregorian",
          local_value: `${person.localDate}T${person.localTime}`,
          precision: "minute",
          timezone_id: person.timezoneId,
          utc_candidates: [],
          selected_utc: null,
          confidence: person.timeConfidence,
          source: { kind: "user_input", description: "Browser natal calculation form" },
          warnings: [],
        },
        location: {
          name: person.placeName,
          country_code: person.countryCode || undefined,
          latitude: person.latitude,
          longitude: person.longitude,
          timezone_id: person.timezoneId,
          source: "user_input",
          warnings: [],
        },
        attributes: { relation: person.relation },
        source: { kind: "user_input", description: "Created with natal calculation" },
      },
    }),
  });

  const orbOverrides = Object.entries(settings.orbOverrides).map(([aspect_id, orb_deg]) => ({
    scope: "aspect",
    aspect_id,
    orb_deg,
  }));
  const snapshot = await requestJson<NatalSnapshot>("/calculations", {
    method: "POST",
    body: JSON.stringify({
      subject: { subject_version_id: subject.version.id },
      chart: { family: "natal", technique: "natal.standard_chart" },
      settings: {
        calculation_profile_id: "professional.natal.v1",
        analysis_system_id: "natal.integrated.v1",
        zodiac: "tropical",
        ayanamsa: null,
        house_system: settings.houseSystem,
        center: "geocentric",
        coordinate_frame: "ecliptic",
        node_type: settings.nodeType,
        high_latitude_policy: "block",
        aspect_set_id: "official.aspects.professional_natal.v1",
        orb_profile_id: "official.orbs.professional_natal.v1",
        point_set_ids: settings.pointIds.length ? [] : ["points.professional.default.v1"],
        included_points: settings.pointIds,
        minor_body_ids: [],
        fixed_star_ids: [],
        lot_formula_ids: ["fortune", "spirit", "lot_eros", "lot_necessity", "lot_courage", "lot_victory", "lot_nemesis", "lot_exaltation"],
        hypothetical_point_ids: ["cupido", "hades", "zeus", "kronos", "apollon", "admetos", "vulkanus", "poseidon"],
        included_aspect_ids: settings.aspectIds,
        orb_overrides: orbOverrides,
        classical_settings: {
          rulership_system: "traditional_and_modern",
          dignity_table: "traditional.dignities.v1",
          triplicity_table: "dorothean.v1",
          terms_table: "egyptian.v1",
          decan_or_face_table: "chaldean.v1",
          sect_rules: "classical.sect.explicit.v1",
          lot_formula_set: "hellenistic_lots_extended.v1",
        },
        custom_parameters: {},
      },
      rule_pack_hash: `sha256:${"a".repeat(64)}`,
      dataset_versions: {},
      outputs: ["snapshot", "json", "markdown_technical", "plaintext_technical"],
    }),
  });
  return {
    subjectId: subject.subject.id,
    subjectVersionId: subject.version.id,
    snapshot,
  };
}

export function getNatalTechnicalDocument(snapshotId: string, format: "markdown" | "plaintext") {
  return requestText(`/calculations/${encodeURIComponent(snapshotId)}/exports/natal-technical?format=${format}`);
}

export async function getAiProviders(): Promise<AiProvider[]> {
  const result = await requestJson<{ providers: AiProvider[] }>("/ai/providers");
  return result.providers;
}

export async function submitNatalToAi(input: {
  snapshotId: string;
  providerId: "openai" | "moonshot";
  modelId: "gpt" | "kimi";
  focus?: string;
  consent: boolean;
}) {
  return requestJson<Record<string, unknown>>("/ai/analyses", {
    method: "POST",
    body: JSON.stringify({
      snapshot_id: input.snapshotId,
      provider_id: input.providerId,
      model_id: input.modelId,
      document_format: "markdown",
      analysis_focus: input.focus || null,
      consent_to_send_snapshot: input.consent,
      store_response: true,
    }),
  });
}

export async function getNatalItemInterpretation(
  snapshotId: string,
  itemType: string,
  resultPath: string,
): Promise<ItemInterpretation> {
  const itemKinds = itemType === "point"
    ? ["point_intrinsic", "point_in_sign", "point_in_house", "motion"]
    : itemType === "house"
      ? ["house_cusp_ruler"]
      : itemType === "aspect"
        ? ["natal_aspect"]
        : itemType === "structure"
          ? ["structure_indicator"]
          : ["classical_condition"];
  const response = await requestJson<{
    interpretations: Array<{
      status: string;
      fact: Record<string, unknown>;
      meaning: { text?: string; statement_key?: string } | null;
      unavailable_reason: string | null;
      provenance: {
        rule?: { id?: string; version?: string };
        template?: { version?: string };
        sources?: Array<{ source_id?: string; title?: string }>;
        maturity?: string;
      };
    }>;
  }>(`/calculations/${encodeURIComponent(snapshotId)}/interpretations/contextual`, {
    method: "POST",
    body: JSON.stringify({
      items: itemKinds.map((item_kind) => ({ item_kind, result_path: resultPath, locale: "zh-CN" })),
    }),
  });
  const published = response.interpretations.filter((item) => item.status === "published" && item.meaning?.text);
  if (!published.length) {
    return {
      status: "unavailable",
      unavailable_reason: response.interpretations.map((item) => item.unavailable_reason).filter(Boolean).join(" · ") || "没有已发布的逐项解释。",
    };
  }
  return {
    status: "available",
    facts: published.map((item) => JSON.stringify(item.fact, null, 2)),
    meaning: published.map((item) => item.meaning?.text).filter(Boolean).join("\n\n"),
    synthesis: "以上各层均来自同一不可变快照。逐项解释不自动升级为整盘结论。",
    rule_refs: published.map((item) => [item.provenance.rule?.id, item.provenance.rule?.version].filter(Boolean).join("@")).filter(Boolean),
    source_refs: published.flatMap((item) => item.provenance.sources?.map((source) => source.title ?? source.source_id ?? "") ?? []).filter(Boolean),
    template_version: published[0]?.provenance.template?.version,
    maturity: published[0]?.provenance.maturity,
  };
}
