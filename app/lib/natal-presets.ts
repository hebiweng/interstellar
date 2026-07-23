import type { NatalCalculationSettings } from "./interstellar-api";

export type NatalPresetId = "modern" | "classical" | "special" | "custom";
export type NatalPointGroupId = "core" | "angles" | "lunar" | "asteroids" | "lots" | "hamburg";
export type NatalPointGroups = Record<NatalPointGroupId, boolean>;

export type NatalCalculationPreset = {
  id: Exclude<NatalPresetId, "custom">;
  version: "2026.07.22";
  label: string;
  badge: string;
  description: string;
  basis: string;
  settings: NatalCalculationSettings;
  groups: NatalPointGroups;
};

const majorAspectIds = ["conjunction", "opposition", "trine", "square", "sextile"];

const competitorNatalAspectOrbs = {
  conjunction: 7,
  opposition: 6,
  trine: 6,
  square: 6,
  sextile: 6,
  semisextile: 3,
  quincunx: 3,
  semisquare: 3,
  sesquisquare: 3,
  quintile: 3,
} satisfies Record<string, number>;

const competitorTimingAspectOrbs = {
  conjunction: 2,
  opposition: 1,
  trine: 1,
  square: 1,
  sextile: 1,
  semisextile: 1,
  quincunx: 1,
  semisquare: 1,
  sesquisquare: 1,
  quintile: 1,
} satisfies Record<string, number>;

const sharedSettings: Omit<
  NatalCalculationSettings,
  "analysisSystem" | "houseSystem" | "orbMode" | "disabledPointIds"
> = {
  zodiac: "tropical",
  ayanamsa: "fagan_bradley",
  nodeType: "true",
  center: "geocentric",
  pointIds: [],
  fixedStarIds: [],
  fixedStarOrb: 1,
  mirrorOrb: 1,
  midpointOrb: 1,
  triplicityTable: "dorothean",
  termsTable: "egyptian",
  aspectIds: majorAspectIds,
  orbOverrides: competitorNatalAspectOrbs,
  globalOrb: null,
  chartOrb: null,
  pointClassOrbs: {},
  pointPairOrbs: [],
};

const hiddenCommonVirtualPoints = [
  "true_south_node",
  "spirit",
  "ic",
  "dsc",
  "vertex",
  "east_point",
];

const modernDisabledPointIds = [
  ...hiddenCommonVirtualPoints,
  "chiron",
  "ceres",
  "pallas",
  "vesta",
  "pholus",
  "nessus",
  "chariklo",
  "asteroid_eros",
  "psyche",
  "eris",
  "sedna",
  "haumea",
  "makemake",
  "quaoar",
  "orcus",
  "ixion",
  "varuna",
  "astraea",
  "hygiea",
];

const traditionalDisabledPointIds = [
  ...hiddenCommonVirtualPoints,
  "uranus",
  "neptune",
  "pluto",
  "mean_lilith",
];

export const natalCalculationPresets: readonly NatalCalculationPreset[] = [
  {
    id: "modern",
    version: "2026.07.22",
    label: "现代",
    badge: "回归黄道 · Placidus",
    description: "十大行星、上升、中天、真北交点、平均莉莉丝、福点、婚神星与五大相位。",
    basis: "逐项复现 Obsidian 竞品实测预设；额外专业点位、固定星与扩展相位保留为手动能力。",
    settings: {
      ...sharedSettings,
      analysisSystem: "modern",
      houseSystem: "placidus",
      orbMode: "modern_aspect",
      disabledPointIds: modernDisabledPointIds,
    },
    groups: { core: true, angles: true, lunar: false, asteroids: true, lots: false, hamburg: false },
  },
  {
    id: "classical",
    version: "2026.07.22",
    label: "古典",
    badge: "七曜 · Alcabitius",
    description: "七曜、上升、中天、真北交点、福点、Alcabitius 宫位与古典星光容许度。",
    basis: "逐项复现 Obsidian 竞品实测预设；传统表采用多罗修斯三分主星与埃及界。",
    settings: {
      ...sharedSettings,
      analysisSystem: "classical",
      houseSystem: "alcabitius",
      orbMode: "classical_starlight",
      disabledPointIds: traditionalDisabledPointIds,
    },
    groups: { core: true, angles: true, lunar: false, asteroids: false, lots: false, hamburg: false },
  },
  {
    id: "special",
    version: "2026.07.22",
    label: "特殊",
    badge: "七曜 · Whole Sign",
    description: "七曜、上升、中天、真北交点、福点、整宫制与五大现代相位。",
    basis: "逐项复现 Obsidian 竞品实测预设；映点、特殊度数和中点继续使用平台已发布规则。",
    settings: {
      ...sharedSettings,
      analysisSystem: "integrated",
      houseSystem: "whole_sign",
      orbMode: "modern_aspect",
      disabledPointIds: traditionalDisabledPointIds,
    },
    groups: { core: true, angles: true, lunar: false, asteroids: false, lots: false, hamburg: false },
  },
] as const;

export const timingCalculationPresets: readonly NatalCalculationPreset[] =
  natalCalculationPresets.map((preset) => ({
    ...preset,
    badge: `${preset.badge} · B族`,
    description: preset.id === "modern"
      ? "十大行星、上升、中天与真北交点；合相 2°，其余主要相位 1°。"
      : `${preset.description} 合相 2°，其余主要相位 1°。`,
    basis: "逐项复现 Obsidian 行运盘与次限盘竞品实测预设；变化层使用 B 族容许度。",
    settings: {
      ...preset.settings,
      aspectIds: [...majorAspectIds],
      orbOverrides: { ...competitorTimingAspectOrbs },
      disabledPointIds: preset.id === "modern"
        ? [...preset.settings.disabledPointIds, "mean_lilith", "fortune", "juno"]
        : [...preset.settings.disabledPointIds],
    },
    groups: {
      ...preset.groups,
      asteroids: false,
    },
  }));

export function cloneNatalSettings(settings: NatalCalculationSettings): NatalCalculationSettings {
  return {
    ...settings,
    pointIds: [...settings.pointIds],
    disabledPointIds: [...settings.disabledPointIds],
    fixedStarIds: [...settings.fixedStarIds],
    aspectIds: [...settings.aspectIds],
    orbOverrides: { ...settings.orbOverrides },
    pointClassOrbs: { ...settings.pointClassOrbs },
    pointPairOrbs: settings.pointPairOrbs.map((pair) => ({ ...pair })),
  };
}

export function cloneNatalPointGroups(groups: NatalPointGroups): NatalPointGroups {
  return { ...groups };
}

export function normalizeNatalSettings(
  value: Partial<NatalCalculationSettings> | null | undefined,
): NatalCalculationSettings {
  const fallback = natalCalculationPresets[0].settings;
  return cloneNatalSettings({
    ...fallback,
    ...value,
    pointIds: value?.pointIds ?? fallback.pointIds,
    disabledPointIds: value?.disabledPointIds ?? fallback.disabledPointIds,
    fixedStarIds: value?.fixedStarIds ?? fallback.fixedStarIds,
    aspectIds: value?.aspectIds ?? fallback.aspectIds,
    orbOverrides: value?.orbOverrides ?? fallback.orbOverrides,
    pointClassOrbs: value?.pointClassOrbs ?? fallback.pointClassOrbs,
    pointPairOrbs: value?.pointPairOrbs ?? fallback.pointPairOrbs,
  });
}

export function identifyNatalPreset(
  settings: NatalCalculationSettings,
  groups: NatalPointGroups,
): NatalPresetId {
  const serializedSettings = JSON.stringify(settings);
  const serializedGroups = JSON.stringify(groups);
  return natalCalculationPresets.find((preset) =>
    JSON.stringify(preset.settings) === serializedSettings
    && JSON.stringify(preset.groups) === serializedGroups
  )?.id ?? "custom";
}

export function identifyTimingPreset(
  settings: NatalCalculationSettings,
  groups: NatalPointGroups,
): NatalPresetId {
  const serializedSettings = JSON.stringify(settings);
  const serializedGroups = JSON.stringify(groups);
  return timingCalculationPresets.find((preset) =>
    JSON.stringify(preset.settings) === serializedSettings
    && JSON.stringify(preset.groups) === serializedGroups
  )?.id ?? "custom";
}

const classicalStarlightOrbs: Record<string, number> = {
  sun: 15,
  moon: 12,
  mercury: 7,
  venus: 7,
  mars: 8,
  jupiter: 9,
  saturn: 9,
  uranus: 5,
  neptune: 5,
  pluto: 5,
  true_north_node: 5,
  mean_north_node: 5,
  asc: 5,
  mc: 5,
};

export function classicalStarlightPairOrbs(
  pointIds: readonly string[],
  explicitPairs: NatalCalculationSettings["pointPairOrbs"],
): NatalCalculationSettings["pointPairOrbs"] {
  const explicitKeys = new Set(
    explicitPairs.map((pair) => [pair.pointA, pair.pointB].sort().join(":")),
  );
  const generated: NatalCalculationSettings["pointPairOrbs"] = [];
  for (let leftIndex = 0; leftIndex < pointIds.length; leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < pointIds.length; rightIndex += 1) {
      const pointA = pointIds[leftIndex];
      const pointB = pointIds[rightIndex];
      const key = [pointA, pointB].sort().join(":");
      if (explicitKeys.has(key)) continue;
      generated.push({
        pointA,
        pointB,
        orb: Math.min(classicalStarlightOrbs[pointA] ?? 5, classicalStarlightOrbs[pointB] ?? 5),
      });
    }
  }
  return [...generated, ...explicitPairs.map((pair) => ({ ...pair }))];
}
