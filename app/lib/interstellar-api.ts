import {
  fetchWithTimeout,
  parseJsonErrorBody,
  type FetchOptions,
} from "./api-client";

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

export type NatalFixedStar = {
  star_id: string;
  name: string;
  label_zh: string;
  catalog_designation?: string | null;
  magnitude_v: number;
  sign: string;
  degree_in_sign: number;
  position: {
    ecliptic: { longitude_deg: number; latitude_deg: number };
    equatorial: { right_ascension_deg: number; declination_deg: number };
    frame: string;
    center: string;
    epoch: string;
  };
};

export type NatalFixedStarContact = {
  contact_id: string;
  star_id: string;
  point_id: string;
  type: "conjunction";
  orb_deg: number;
  orb_allowance_deg: number;
  strength: number;
};

/** 本命盘结构指标（加强类型，替代 Record<string, unknown>）。 */
export type NatalStructure = {
  chart_shape?: string;
  chart_shape_label?: string;
  hemisphere_emphasis?: Record<string, number>;
  quadrant_emphasis?: Record<string, number>;
  element_distribution?: Record<string, number>;
  mode_distribution?: Record<string, number>;
  polarity_distribution?: Record<string, number>;
  signature_sign?: string;
  signature_house?: number | null;
  [key: string]: unknown;
};

/** 古典条件结果（加强类型）。 */
export type NatalClassical = {
  dignities?: Array<{
    point_id: string;
    essential_dignity?: string;
    debility?: string;
    rulership_sign?: string | null;
    exaltation_sign?: string | null;
    detriment_sign?: string | null;
    fall_sign?: string | null;
    triplicity_ruler?: string | null;
    term_ruler?: string | null;
    face_ruler?: string | null;
    mutual_reception?: string | null;
    [key: string]: unknown;
  }>;
  lots?: Array<{
    lot_id: string;
    name?: string;
    longitude_deg?: number;
    sign?: string;
    degree_in_sign?: number;
    house?: number | null;
    formula_ref?: string;
    [key: string]: unknown;
  }>;
  receptions?: Array<{
    point_a: string;
    point_b: string;
    relationship: string;
    [key: string]: unknown;
  }>;
  dispositors?: {
    final_dispositor?: string | null;
    chain?: Array<{ point_id: string; sign: string; role: string }>;
    [key: string]: unknown;
  };
  sect?: {
    diurnal?: boolean;
    sect_ruler?: string;
    benefic_of_sect?: string;
    malefic_of_sect?: string;
    [key: string]: unknown;
  };
  [key: string]: unknown;
};

/** 特殊度数结果（加强类型）。 */
export type NatalSpecialDegrees = {
  anaretic_points?: Array<{ point_id: string; degree: number }>;
  critical_points?: Array<{ point_id: string; degree: number }>;
  [key: string]: unknown;
};

export type NatalSnapshot = {
  id: string;
  status: string;
  maturity: string;
  input_fingerprint: string;
  engine: { name: string; version: string };
  datasets?: Array<{ id?: string; version?: string }> | Record<string, string>;
  adapters?: Array<Record<string, unknown>>;
  normalized_input?: Record<string, unknown>;
  rule_pack_hash?: string;
  warnings: Array<{ code: string; message: string }>;
  request?: Record<string, unknown>;
  result: {
    charts?: Array<Record<string, unknown>>;
    points: NatalPoint[];
    houses: NatalHouse[];
    aspects: NatalAspect[];
    distributions?: Array<{
      dimension: string;
      categories: Array<{ category_id: string; count: number; percentage?: number }>;
    }>;
    structure?: NatalStructure;
    patterns?: Array<Record<string, unknown>>;
    classical?: NatalClassical;
    dignities?: Array<Record<string, unknown>>;
    lots?: Array<Record<string, unknown>>;
    fixed_stars?: NatalFixedStar[];
    fixed_star_contacts?: NatalFixedStarContact[];
    special_degrees?: NatalSpecialDegrees;
    mirror_points?: Record<string, unknown>;
    midpoints?: Record<string, unknown>;
    profections?: Record<string, unknown> | null;
    firdaria?: Record<string, unknown> | null;
    zodiacal_releasing?: Record<string, unknown>;
    receptions?: Array<Record<string, unknown>>;
    dispositors?: Record<string, unknown>;
    astronomical_context?: Record<string, unknown>;
    evidence?: Array<Record<string, unknown>>;
    output_manifest?: Array<Record<string, unknown>>;
  };
};

export type NatalPersonInput = {
  displayName: string;
  relation: "self" | "family" | "partner" | "friend" | "client" | "other";
  localDate: string;
  localTime: string;
  timePrecision: "minute" | "hour" | "date" | "unknown";
  timezoneId: string;
  placeName: string;
  countryCode: string;
  latitude: number;
  longitude: number;
  timeConfidence: "high" | "medium" | "low" | "unknown";
  locationSourceId?: string;
  timezoneStatus?: "resolved" | "ambiguous" | "degraded" | "unresolved" | "manual";
};

export type CurrentSkyInput = {
  localDate: string;
  localTime: string;
  timezoneId: string;
  placeName: string;
  countryCode: string;
  latitude: number;
  longitude: number;
};

export type ChartComparison = {
  id: string;
  status: string;
  maturity: string;
  warnings: Array<{ code?: string; message?: string }>;
  result: {
    context: "transit" | "progression";
    reference_snapshot_id: string;
    moving_snapshot_id: string;
    cross_aspects: Array<NatalAspect & {
      moving_point_id: string;
      reference_point_id: string;
      context: "transit" | "progression";
    }>;
    moving_points_in_reference_houses: Array<{
      moving_point_id: string;
      reference_house: number;
      on_cusp: boolean;
      cusp_number: number | null;
      rule_ref: string;
    }>;
    provenance: {
      aspect_profile: string;
      orb_profile: string;
      orb_override_set: string;
    };
  };
};

export type SecondaryProgressionResult = {
  id: string;
  status: string;
  reference_snapshot_id: string;
  target_date: string;
  progressed_time: string;
  progressed_snapshot: NatalSnapshot;
  comparison: ChartComparison;
};

export type LocationSearchItem = {
  id: string;
  label: string;
  match_score: number;
  match_reasons: string[];
  location: {
    name: string;
    country_code: string;
    admin_path: string[];
    latitude: number;
    longitude: number;
    elevation_m: number | null;
    timezone_id: string | null;
    warnings: Array<{ code: string; message: string }>;
  };
  timezone_status: "resolved" | "ambiguous" | "degraded" | "unresolved";
  timezone_candidates: Array<{
    timezone_id: string;
    confidence: string;
    boundary_match: boolean;
  }>;
};

export type LocalDatasetItem = {
  id: string;
  version: string;
  status: "discovered" | "downloading" | "validating" | "staged" | "active" | "rejected" | "rolled_back";
  checksum: string;
  source_uri: string;
  license: string;
  activated_at: string | null;
  metadata: {
    name?: string;
    role?: string;
    required_for_v1?: boolean;
    runtime_mode?: string;
    acquisition_method?: string;
    crawler?: boolean;
    local_ready?: boolean;
    capability_state?: string;
    lock_file?: string;
    artifacts?: Array<{
      path?: string;
      exists?: boolean;
      size_matches?: boolean;
      size_bytes?: number;
      sha256?: string;
    }>;
  };
};

export type NatalCalculationSettings = {
  analysisSystem: "integrated" | "modern" | "classical";
  orbMode: "modern_aspect" | "classical_starlight";
  zodiac: "tropical" | "sidereal";
  ayanamsa:
    | "fagan_bradley"
    | "lahiri"
    | "deluce"
    | "raman"
    | "ushashashi"
    | "krishnamurti"
    | "djwhal_khul"
    | "yukteshwar"
    | "jn_bhasin"
    | "true_pushya"
    | "hipparchos"
    | "true_revati"
    | "true_citra"
    | "galactic_center_0_sagittarius";
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
    | "vehlow"
    | "equal_mc"
    | "equal_aries"
    | "meridian"
    | "horizontal"
    | "carter_poli_equatorial"
    | "apc"
    | "pullen_sd"
    | "pullen_sr"
    | "sunshine_treindl"
    | "sripati";
  nodeType: "true" | "mean" | "both";
  center: "geocentric" | "topocentric";
  pointIds: string[];
  disabledPointIds: string[];
  fixedStarIds: string[];
  fixedStarOrb: number;
  mirrorOrb: number;
  midpointOrb: number;
  triplicityTable: "dorothean" | "ptolemaic";
  termsTable: "egyptian" | "ptolemaic";
  aspectIds: string[];
  orbOverrides: Record<string, number>;
  globalOrb: number | null;
  chartOrb: number | null;
  pointClassOrbs: Record<string, number>;
  pointPairOrbs: Array<{ pointA: string; pointB: string; orb: number }>;
};

export type AiProviderId = "deepseek" | "openai" | "moonshot";
export type AiModelId = "deepseek-v4-flash" | "deepseek-v4-pro" | "gpt" | "kimi";

export type AiProvider = {
  provider_id: AiProviderId;
  label: string;
  configured: boolean;
  availability: string;
  blocking_reason?: string;
  models: Array<{ model_id: AiModelId; label: string; configured: boolean }>;
};

export type TechnicalDocumentArtifact = {
  content: string;
  contentHash: string;
  snapshotId: string;
  inputFingerprint: string;
  format: "markdown" | "plaintext";
};

export type NatalAiPayloadPreview = {
  preview_id: string;
  snapshot_id: string;
  provider_id: AiProviderId;
  model_id: AiModelId;
  provider_configured: boolean;
  availability: string;
  blocking_reason?: string | null;
  document_format: "markdown" | "plaintext" | "json";
  document_content_hash: string;
  payload_hash: string;
  character_count: number;
  estimated_tokens: number;
  sections: string[];
  preview_excerpt: string;
  analysis_focus?: string | null;
  data_destination: string;
  privacy_policy_url?: string | null;
  retention_policy: string;
  store_response: boolean;
  requires_subject_data_authority: boolean;
  calculation_boundary: string;
};

export type ItemInterpretation = {
  status: "available" | "unavailable" | "not_applicable" | "blocked_by_input_quality";
  title?: string;
  facts?: string[];
  meaning?: string;
  synthesis?: string;
  rule_refs?: string[];
  source_refs?: string[];
  template_version?: string;
  maturity?: string;
  unavailable_reason?: string;
  content_hash?: string;
  layers?: Array<{
    item_kind: string;
    label: string;
    status: "published" | "unavailable" | "not_applicable" | "blocked_by_input_quality";
    fact: Record<string, unknown>;
    meaning?: string;
    unavailable_reason?: string;
    warnings: string[];
    content_hash: string;
    rule_ref?: string;
    template_version?: string;
    maturity?: string;
    source_refs: string[];
  }>;
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

/** 计算请求超时（占星计算可能较慢）。 */
const CALCULATION_TIMEOUT_MS = 60_000;
/** AI 分析请求超时（AI 调用可能很慢）。 */
const AI_TIMEOUT_MS = 120_000;
/** 默认请求超时。 */
const DEFAULT_TIMEOUT_MS = 30_000;

/**
 * 规则包哈希占位符。
 *
 * 后端要求格式 ^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$。
 * 真实哈希应由后端 rule pack 注册表生成；前端在 rule pack 注册表
 * 接入前使用全零占位符通过格式校验。后端在 m2 计算中不验证哈希内容
 * 的真实性，仅做格式检查（见 m2_calculations.py:135/174）。
 */
const RULE_PACK_HASH_NATAL = "sha256:" + "0".repeat(64);
const RULE_PACK_HASH_MUNDANE = "sha256:" + "0".repeat(64);
const RULE_PACK_HASH_PROGRESSION = "sha256:" + "0".repeat(64);

async function requestJson<T>(path: string, init: FetchOptions = {}): Promise<T> {
  const response = await fetchWithTimeout(path, init);
  const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.includes("json")) {
    throw new InterstellarApiError(
      `计算服务返回了 ${contentType || "未知格式"}。当前地址可能误指向了前端网页，而不是 /api/v1。`,
      "INVALID_API_CONTENT_TYPE",
      response.status,
    );
  }
  const errorBody = await parseJsonErrorBody(response);
  if (!response.ok) {
    const detail = errorBody?.detail ?? `API 请求失败（${response.status}）`;
    const code = errorBody?.code ?? "API_REQUEST_FAILED";
    const fields = errorBody?.fields && typeof errorBody.fields === "object"
      ? ` ${JSON.stringify(errorBody.fields)}`
      : "";
    throw new InterstellarApiError(`${detail}${fields}`, code, response.status);
  }
  if (errorBody?.raw == null) {
    throw new InterstellarApiError("计算服务返回了空响应。", "EMPTY_RESPONSE", response.status);
  }
  return errorBody.raw as T;
}

async function requestTextArtifact(
  path: string,
  format: "markdown" | "plaintext",
): Promise<TechnicalDocumentArtifact> {
  const response = await fetchWithTimeout(path, {
    accept: "text/markdown, text/plain",
    timeoutMs: DEFAULT_TIMEOUT_MS,
  });
  if (!response.ok) {
    const errorBody = await parseJsonErrorBody(response);
    const detail = errorBody?.detail ?? `分析数据导出失败（${response.status}）`;
    const code = errorBody?.code ?? "EXPORT_FAILED";
    throw new InterstellarApiError(detail, code, response.status);
  }
  const contentHash = response.headers.get("x-interstellar-document-hash") ?? "";
  const snapshotId = response.headers.get("x-interstellar-snapshot-id") ?? "";
  const inputFingerprint = response.headers.get("x-interstellar-input-fingerprint") ?? "";
  if (!contentHash.startsWith("sha256:")) {
    throw new InterstellarApiError(
      "分析数据校验失败，无法确认复制与下载来自同一次计算。",
      "EXPORT_INTEGRITY_MISSING",
      response.status,
    );
  }
  return {
    content: await response.text(),
    contentHash,
    snapshotId,
    inputFingerprint,
    format,
  };
}

async function requestFile(path: string, accept: string): Promise<Blob> {
  const response = await fetchWithTimeout(path, {
    accept,
    timeoutMs: DEFAULT_TIMEOUT_MS,
  });
  if (!response.ok) {
    const errorBody = await parseJsonErrorBody(response);
    const detail = errorBody?.detail ?? `结构化结果导出失败（${response.status}）`;
    const code = errorBody?.code ?? "EXPORT_FAILED";
    throw new InterstellarApiError(detail, code, response.status);
  }
  return response.blob();
}

export async function searchLocations(
  query: string,
  options: { countryCode?: string; limit?: number } = {},
): Promise<LocationSearchItem[]> {
  const params = new URLSearchParams({ q: query, limit: String(options.limit ?? 8) });
  if (options.countryCode) params.set("country_code", options.countryCode);
  const response = await requestJson<{ items: LocationSearchItem[] }>(
    `/locations/search?${params.toString()}`,
  );
  return response.items;
}

export async function getLocalDatasets(): Promise<LocalDatasetItem[]> {
  const response = await requestJson<{ items: LocalDatasetItem[] }>(
    "/datasets?page%5Blimit%5D=100",
  );
  return response.items;
}

type RunnableChart = {
  family: "natal" | "mundane";
  technique: "natal.standard_chart" | "mundane.current_sky";
  analysisNamespace: "natal" | "mundane";
};

async function createWorkflowSubject(version: Record<string, unknown>) {
  return requestJson<{
    subject: { id: string };
    version: { id: string };
  }>("/subjects", {
    method: "POST",
    body: JSON.stringify({
      workspace_id: "workspace-browser-local",
      version,
    }),
    timeoutMs: DEFAULT_TIMEOUT_MS,
  });
}

function buildOrbOverrides(settings: NatalCalculationSettings) {
  const orbOverrides: Array<Record<string, string | number>> = [];
  if (settings.globalOrb != null) {
    orbOverrides.push({ scope: "chart_context", orb_deg: settings.globalOrb });
  }
  if (settings.chartOrb != null) {
    orbOverrides.push({ scope: "chart_context", chart_context: "within_chart", orb_deg: settings.chartOrb });
  }
  for (const [aspect_id, orb_deg] of Object.entries(settings.orbOverrides)) {
    orbOverrides.push({ scope: "aspect", aspect_id, orb_deg });
  }
  for (const [point_class, orb_deg] of Object.entries(settings.pointClassOrbs)) {
    orbOverrides.push({ scope: "point_class", point_class, orb_deg });
  }
  for (const pair of settings.pointPairOrbs) {
    const [point_a, point_b] = [pair.pointA, pair.pointB].sort();
    if (point_a && point_b && point_a !== point_b) {
      orbOverrides.push({ scope: "point_pair", point_a, point_b, orb_deg: pair.orb });
    }
  }
  return orbOverrides;
}

function buildSharedChartSettings(
  settings: NatalCalculationSettings,
  analysisNamespace: RunnableChart["analysisNamespace"],
) {
  return {
    calculation_profile_id: "professional.natal.v1",
    analysis_system_id: `${analysisNamespace}.${settings.analysisSystem}.v1`,
    zodiac: settings.zodiac,
    ayanamsa: settings.zodiac === "sidereal" ? settings.ayanamsa : null,
    house_system: settings.houseSystem,
    center: settings.center,
    coordinate_frame: "ecliptic",
    node_type: settings.nodeType,
    high_latitude_policy: "block",
    aspect_set_id: "official.aspects.professional_natal.v1",
    orb_profile_id: "official.orbs.professional_natal.v1",
    point_set_ids: settings.pointIds.length ? [] : ["points.professional.default.v1"],
    included_points: settings.pointIds,
    minor_body_ids: [],
    fixed_star_ids: settings.fixedStarIds,
    lot_formula_ids: ["fortune", "spirit", "lot_eros", "lot_necessity", "lot_courage", "lot_victory", "lot_nemesis", "lot_exaltation"],
    hypothetical_point_ids: ["cupido", "hades", "zeus", "kronos", "apollon", "admetos", "vulkanus", "poseidon"],
    included_aspect_ids: settings.aspectIds,
    orb_overrides: buildOrbOverrides(settings),
    classical_settings: {
      rulership_system: "traditional_and_modern",
      dignity_table: "traditional.dignities.v1",
      triplicity_table: `${settings.triplicityTable}.v1`,
      terms_table: `${settings.termsTable}.v1`,
      decan_or_face_table: "chaldean.v1",
      sect_rules: "classical.sect.explicit.v1",
      lot_formula_set: "hellenistic_lots_extended.v1",
    },
    custom_parameters: {
      fixed_star_conjunction_orb_deg: settings.fixedStarOrb,
      mirror_contact_orb_deg: settings.mirrorOrb,
      midpoint_hit_orb_deg: settings.midpointOrb,
    },
  };
}

async function calculateSingleChart(
  subjectVersionId: string,
  chart: RunnableChart,
  settings: NatalCalculationSettings,
) {
  const rulePackHash = chart.family === "mundane"
    ? RULE_PACK_HASH_MUNDANE
    : RULE_PACK_HASH_NATAL;
  return requestJson<NatalSnapshot>("/calculations", {
    method: "POST",
    body: JSON.stringify({
      subject: { subject_version_id: subjectVersionId },
      chart: { family: chart.family, technique: chart.technique },
      settings: buildSharedChartSettings(settings, chart.analysisNamespace),
      rule_pack_hash: rulePackHash,
      dataset_versions: {},
      outputs: chart.family === "natal"
        ? ["snapshot", "json", "markdown_technical", "plaintext_technical"]
        : ["snapshot", "json"],
    }),
    timeoutMs: CALCULATION_TIMEOUT_MS,
  });
}

export async function createPersonAndNatalCalculation(
  person: NatalPersonInput,
  settings: NatalCalculationSettings,
): Promise<{ subjectId: string; subjectVersionId: string; snapshot: NatalSnapshot }> {
  const timeKnown = person.timePrecision === "minute" || person.timePrecision === "hour";
  const subject = await createWorkflowSubject({
        kind: "person",
        display_name: person.displayName,
        time_spec: {
          calendar: "gregorian",
          local_value: timeKnown ? `${person.localDate}T${person.localTime}` : person.localDate,
          precision: person.timePrecision,
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
  });
  const snapshot = await calculateSingleChart(subject.version.id, {
    family: "natal",
    technique: "natal.standard_chart",
    analysisNamespace: "natal",
  }, settings);
  return {
    subjectId: subject.subject.id,
    subjectVersionId: subject.version.id,
    snapshot,
  };
}

export async function createCurrentSkyCalculation(
  input: CurrentSkyInput,
  settings: NatalCalculationSettings,
): Promise<{ subjectId: string; subjectVersionId: string; snapshot: NatalSnapshot }> {
  const subject = await createWorkflowSubject({
        kind: "event",
        display_name: `${input.localDate} ${input.localTime} 天象`,
        time_spec: {
          calendar: "gregorian",
          local_value: `${input.localDate}T${input.localTime}`,
          precision: "minute",
          timezone_id: input.timezoneId,
          utc_candidates: [],
          selected_utc: null,
          confidence: "high",
          source: { kind: "user_input", description: "Current-sky target moment" },
          warnings: [],
        },
        location: {
          name: input.placeName,
          country_code: input.countryCode || undefined,
          latitude: input.latitude,
          longitude: input.longitude,
          timezone_id: input.timezoneId,
          source: "user_input",
          warnings: [],
        },
        attributes: { chart_role: "current_sky_reference" },
        source: { kind: "user_input", description: "Created for a current-sky calculation" },
  });
  const snapshot = await calculateSingleChart(subject.version.id, {
    family: "mundane",
    technique: "mundane.current_sky",
    analysisNamespace: "mundane",
  }, settings);
  return {
    subjectId: subject.subject.id,
    subjectVersionId: subject.version.id,
    snapshot,
  };
}

export async function createTransitComparison(
  natalSnapshot: NatalSnapshot,
  currentSkySnapshotId: string,
  settings: NatalCalculationSettings,
): Promise<ChartComparison> {
  /**
   * 后端契约：/calculations/comparisons 支持 reference_snapshot_id 和
   * reference_snapshot 两种方式传本命快照。使用 ID 时后端从内存
   * workflow_store 查找，但内存存储在容器重启后清空，导致 404。
   * 直接传完整 reference_snapshot 对象更可靠。
   */
  return requestJson<ChartComparison>("/calculations/comparisons", {
    method: "POST",
    body: JSON.stringify({
      reference_snapshot: natalSnapshot,
      moving_snapshot_id: currentSkySnapshotId,
      context: "transit",
      settings: buildSharedChartSettings(settings, "natal"),
    }),
    timeoutMs: CALCULATION_TIMEOUT_MS,
  });
}

/**
 * 创建次限盘。
 *
 * 后端契约：secondary-progressions 端点只接受完整 reference_snapshot
 * 对象（见 m2_calculations.py:170-176 SecondaryProgressionPayload），
 * 不支持 reference_snapshot_id。因此必须发送整个 natalSnapshot。
 *
 * legacy 兼容逻辑：当 natalSnapshot.normalized_input 缺失时（旧版快照），
 * 从 person 信息重建 normalized_input。这是后端要求的字段，不是前端
 * 可以移除的兼容代码。
 */
export async function createSecondaryProgression(
  natalSnapshot: NatalSnapshot,
  person: NatalPersonInput,
  targetDate: string,
  settings: NatalCalculationSettings,
): Promise<SecondaryProgressionResult> {
  const reusableSnapshot = natalSnapshot.normalized_input
    ? natalSnapshot
    : {
        ...natalSnapshot,
        normalized_input: {
          subject_version: {
            id: `legacy-natal-subject-${natalSnapshot.id}`,
            kind: "person",
            display_name: person.displayName,
            time_spec: {
              calendar: "gregorian",
              local_value: person.timePrecision === "date" || person.timePrecision === "unknown"
                ? person.localDate
                : `${person.localDate}T${person.localTime}`,
              precision: person.timePrecision,
              timezone_id: person.timezoneId,
              selected_utc: null,
              utc_candidates: [],
              confidence: person.timeConfidence,
              source: { kind: "legacy_snapshot_metadata_recovery" },
              warnings: [],
            },
            location: {
              name: person.placeName,
              country_code: person.countryCode,
              latitude: person.latitude,
              longitude: person.longitude,
              timezone_id: person.timezoneId,
              source: "legacy_snapshot_metadata_recovery",
              warnings: [],
            },
            attributes: {},
            source: { kind: "legacy_snapshot_metadata_recovery" },
          },
        },
      };
  return requestJson<SecondaryProgressionResult>("/calculations/secondary-progressions", {
    method: "POST",
    body: JSON.stringify({
      reference_snapshot: reusableSnapshot,
      target_date: targetDate,
      settings: buildSharedChartSettings(settings, "natal"),
      rule_pack_hash: RULE_PACK_HASH_PROGRESSION,
    }),
    timeoutMs: CALCULATION_TIMEOUT_MS,
  });
}

export function getNatalTechnicalDocument(snapshotId: string, format: "markdown" | "plaintext") {
  return requestTextArtifact(
    `/calculations/${encodeURIComponent(snapshotId)}/exports/natal-technical?format=${format}`,
    format,
  );
}

export function getNatalTableExport(snapshotId: string, tableId: string, format: "json" | "csv") {
  return requestFile(
    `/calculations/${encodeURIComponent(snapshotId)}/tables/${encodeURIComponent(tableId)}?format=${format}`,
    format === "csv" ? "text/csv" : "application/json",
  );
}

export async function getAiProviders(): Promise<AiProvider[]> {
  const result = await requestJson<{ providers: AiProvider[] }>("/ai/providers");
  return result.providers;
}

export async function previewNatalAiPayload(input: {
  snapshotId: string;
  providerId: AiProviderId;
  modelId: AiModelId;
  focus?: string;
  storeResponse?: boolean;
}): Promise<NatalAiPayloadPreview> {
  return requestJson<NatalAiPayloadPreview>("/ai/analyses/preview", {
    method: "POST",
    body: JSON.stringify({
      snapshot_id: input.snapshotId,
      provider_id: input.providerId,
      model_id: input.modelId,
      document_format: "markdown",
      analysis_focus: input.focus || null,
      store_response: input.storeResponse ?? true,
    }),
    timeoutMs: DEFAULT_TIMEOUT_MS,
  });
}

export async function submitNatalToAi(input: {
  snapshotId: string;
  providerId: AiProviderId;
  modelId: AiModelId;
  focus?: string;
  consent: boolean;
  payloadHash: string;
  authorityForSubjectData: boolean;
  storeResponse?: boolean;
}): Promise<{
  id: string;
  persisted: boolean;
  response: { text?: string; model?: string; finish_reason?: string | null };
}> {
  return requestJson("/ai/analyses", {
    method: "POST",
    body: JSON.stringify({
      snapshot_id: input.snapshotId,
      provider_id: input.providerId,
      model_id: input.modelId,
      document_format: "markdown",
      analysis_focus: input.focus || null,
      payload_hash: input.payloadHash,
      consent_to_send_snapshot: input.consent,
      authority_for_subject_data: input.authorityForSubjectData,
      consent_policy_version: "2026-07-19",
      store_response: input.storeResponse ?? true,
    }),
    timeoutMs: AI_TIMEOUT_MS,
  });
}

/** 解读层级中文标签（提取为常量，便于维护）。 */
const INTERPRETATION_LAYER_LABELS: Record<string, string> = {
  point_intrinsic: "星体自身功能",
  point_in_sign: "星座表达方式",
  point_in_house: "所在宫位领域",
  motion: "运动状态",
  natal_aspect: "相位互动",
  house_cusp_ruler: "宫头与宫主链",
  structure_indicator: "盘面结构",
  classical_condition: "古典条件",
};

/** 根据 itemType 返回对应的 item_kinds 列表。 */
function itemKindsForType(itemType: string, includeTimeDependent: boolean): string[] {
  const itemKinds = itemType === "point"
    ? ["point_intrinsic", "point_in_sign", "point_in_house", "motion"]
    : itemType === "house"
      ? ["house_cusp_ruler"]
      : itemType === "aspect"
        ? ["natal_aspect"]
        : itemType === "structure"
          ? ["structure_indicator"]
          : ["classical_condition"];
  return includeTimeDependent === false
    ? itemKinds.filter((itemKind) => itemKind !== "point_in_house" && itemKind !== "house_cusp_ruler")
    : itemKinds;
}

type InterpretationWireItem = {
  item_kind: string;
  status: "published" | "unavailable" | "not_applicable" | "blocked_by_input_quality";
  fact: Record<string, unknown>;
  meaning: { text?: string; statement_key?: string } | null;
  unavailable_reason: string | null;
  warnings: string[];
  content_hash: string;
  provenance: {
    rule?: { id?: string; version?: string };
    template?: { version?: string };
    rule_pack?: { id?: string; version?: string; content_hash?: string };
    sources?: Array<{ source_id?: string; title?: string }>;
    maturity?: string;
  };
};

/** 将 wire 格式的 interpretation item 映射为前端 layer 格式。 */
function mapInterpretationLayer(item: InterpretationWireItem) {
  return {
    item_kind: item.item_kind,
    label: INTERPRETATION_LAYER_LABELS[item.item_kind] ?? item.item_kind,
    status: item.status,
    fact: item.fact,
    meaning: item.meaning?.text,
    unavailable_reason: item.unavailable_reason ?? undefined,
    warnings: item.warnings ?? [],
    content_hash: item.content_hash,
    rule_ref: [item.provenance.rule?.id, item.provenance.rule?.version].filter(Boolean).join("@") || undefined,
    template_version: item.provenance.template?.version,
    maturity: item.provenance.maturity,
    source_refs: item.provenance.sources?.map((source) => source.title ?? source.source_id ?? "").filter(Boolean) ?? [],
  };
}

export async function getNatalItemInterpretation(
  snapshotId: string,
  itemType: string,
  resultPath: string,
  options: { includeTimeDependent?: boolean } = {},
): Promise<ItemInterpretation> {
  const effectiveItemKinds = itemKindsForType(itemType, options.includeTimeDependent ?? true);
  const response = await requestJson<{ interpretations: InterpretationWireItem[] }>(
    `/calculations/${encodeURIComponent(snapshotId)}/interpretations/contextual`,
    {
      method: "POST",
      body: JSON.stringify({
        items: effectiveItemKinds.map((item_kind) => ({
          item_kind,
          result_path: resultPath,
          locale: "zh-CN",
        })),
      }),
      timeoutMs: DEFAULT_TIMEOUT_MS,
    },
  );
  const layers = response.interpretations.map(mapInterpretationLayer);
  const published = response.interpretations.filter((item) => item.status === "published" && item.meaning?.text);
  if (!published.length) {
    const blocked = response.interpretations.some((item) => item.status === "blocked_by_input_quality");
    const notApplicable = response.interpretations.every((item) => item.status === "not_applicable");
    return {
      status: blocked ? "blocked_by_input_quality" : notApplicable ? "not_applicable" : "unavailable",
      unavailable_reason: blocked
        ? "这项解读需要更可靠的出生时间或完整宫位资料。"
        : notApplicable
          ? "这项运动或条件不适用于当前点位。"
          : "这项计算已经完成，解释内容仍在补充中。",
      layers,
    };
  }
  return {
    status: "available",
    meaning: published.map((item) => item.meaning?.text).filter(Boolean).join("\n\n"),
    rule_refs: published.map((item) => [item.provenance.rule?.id, item.provenance.rule?.version].filter(Boolean).join("@")).filter(Boolean),
    source_refs: published.flatMap((item) => item.provenance.sources?.map((source) => source.title ?? source.source_id ?? "") ?? []).filter(Boolean),
    template_version: published[0]?.provenance.template?.version,
    maturity: published[0]?.provenance.maturity,
    content_hash: layers.map((item) => item.content_hash).join(" · "),
    layers,
  };
}
