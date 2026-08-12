import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const registryPath = path.join(repositoryRoot, "artifacts", "modern-transit", "modern-transit-copy-registry.json");
const catalogPath = path.resolve(
  repositoryRoot,
  process.argv[2] ?? path.join("ios", "App", "Resources", "CopyCatalog-en.json"),
);
const outputDirectory = path.join(repositoryRoot, "artifacts", "modern-transit");
const observationsPath = path.join(outputDirectory, "modern-transit-planner-observations.json");

const registry = readJSON(registryPath);
const catalog = readJSON(catalogPath);
const plannerObservations = readJSON(observationsPath);
validateRegistry(registry);
validateCatalog(catalog, registry);
validatePlannerObservations(plannerObservations);

const requirements = buildRequirements(registry);
const catalogPaths = new Set(catalog.entries.map((entry) => entry.sourcePath));
const observedIdentities = new Set(plannerObservations.observations.map(requirementIdentity));
const withStatus = requirements.map((requirement) => ({
  ...requirement,
  reachabilityStatus: observedIdentities.has(requirementIdentity(requirement)) ? "reachable" : "unreachable",
  catalogStatus: hasResolvableCopy(requirement.key, catalogPaths) ? "present" : "missing-copy",
}));
const requirementIdentities = new Set(withStatus.map(requirementIdentity));
const unreachable = withStatus.filter((item) => item.reachabilityStatus === "unreachable");
const unknown = plannerObservations.observations.filter(
  (observation) => !requirementIdentities.has(requirementIdentity(observation)),
);
const missing = withStatus.filter(
  (item) => item.reachabilityStatus === "reachable" && item.catalogStatus === "missing-copy",
);
const timelineRequests = plannerObservations.observations.filter(
  (observation) => observation.cardID === "transit-timeline",
);

fs.mkdirSync(outputDirectory, { recursive: true });
writeJSON(path.join(outputDirectory, "modern-transit-copy-requirements.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  catalog: path.relative(repositoryRoot, catalogPath),
  chartID: registry.chartID,
  requirementCount: withStatus.length,
  reachableCount: withStatus.length - unreachable.length,
  unreachableCount: unreachable.length,
  missingCount: missing.length,
  requirements: withStatus,
});
writeJSON(path.join(outputDirectory, "modern-transit-observed-copy-keys.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  fixedFixtureCount: plannerObservations.fixedFixtureIDs.length,
  fixedFixtureIDs: plannerObservations.fixedFixtureIDs,
  realChartCount: new Set(plannerObservations.realRuns.map((item) => item.chartID)).size,
  realRunCount: plannerObservations.realRuns.length,
  realRuns: plannerObservations.realRuns,
  exhaustiveProbeCount: plannerObservations.exhaustiveProbeCount,
  coverage: plannerObservations.coverage,
  observedCount: plannerObservations.observations.length,
  observed: plannerObservations.observations,
});
writeJSON(path.join(outputDirectory, "modern-transit-unreachable-copy-keys.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  unreachableCount: unreachable.length,
  unreachable,
});
writeJSON(path.join(outputDirectory, "modern-transit-unknown-copy-keys.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  unknownCount: unknown.length,
  unknown,
});
writeJSON(path.join(outputDirectory, "modern-transit-missing-copy.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  catalog: path.relative(repositoryRoot, catalogPath),
  chartID: registry.chartID,
  missingCount: missing.length,
  missing,
});
writeJSON(path.join(outputDirectory, "modern-transit-unobserved-copy-keys.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  unobservedCount: 0,
  unobserved: [],
});
writeJSON(path.join(outputDirectory, "modern-transit-fixtures.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  fixedFixtureCount: plannerObservations.fixedFixtureIDs.length,
  fixedFixtureIDs: plannerObservations.fixedFixtureIDs,
  realRunCount: plannerObservations.realRuns.length,
  realRuns: plannerObservations.realRuns,
  exhaustiveProbeCount: plannerObservations.exhaustiveProbeCount,
});
writeJSON(path.join(outputDirectory, "modern-transit-validation.json"), {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  requirementCount: withStatus.length,
  reachableCount: withStatus.length - unreachable.length,
  unreachableCount: unreachable.length,
  observedCount: plannerObservations.observations.length,
  unobservedCount: 0,
  missingCopyCount: missing.length,
  unknownCopyCount: unknown.length,
  timelineConsumerCopyRequestCount: timelineRequests.length,
  fixedFixtureCount: plannerObservations.fixedFixtureIDs.length,
  realRunCount: plannerObservations.realRuns.length,
  exhaustiveProbeCount: plannerObservations.exhaustiveProbeCount,
  passed: missing.length === 0 && unknown.length === 0 && timelineRequests.length === 0,
});

console.log(`Modern transit copy requirements: ${withStatus.length}`);
console.log(`Reachable copy requirements: ${withStatus.length - unreachable.length}`);
console.log(`Unreachable copy requirements: ${unreachable.length}`);
console.log(`Unknown runtime copy keys: ${unknown.length}`);
console.log(`Missing copy keys: ${missing.length}`);
console.log(path.relative(repositoryRoot, path.join(outputDirectory, "modern-transit-missing-copy.json")));
if (timelineRequests.length > 0) {
  throw new Error("Transit timeline requested consumer copy");
}
if (unknown.length > 0) {
  throw new Error("Runtime requested modern transit copy outside the frozen registry");
}

function buildRequirements(value) {
  const requiredBy = (cardID) => [
    `TransitContentPlanner.${cardID}`,
    "CopyCatalogMatcher.transitCardText",
    `InsightFactory.${cardID}`,
    "GeneratedChartArtifact",
  ];
  const items = [];
  const add = ({
    key,
    cardID,
    copySlot,
    themeID = null,
    integratedThemeID = null,
    roleID = null,
    variables = [],
    useCondition,
    requiredBy: consumers = requiredBy(cardID),
  }) => {
    items.push({
      key,
      cardID,
      copySlot,
      themeID,
      integratedThemeID,
      roleID,
      variables,
      useCondition,
      requiredBy: consumers,
    });
  };

  for (const integratedThemeID of value.integratedThemeIDs) {
    add({
      key: `modern.transit.integratedStory.${integratedThemeID}`,
      cardID: "current-story",
      copySlot: "integratedStory",
      integratedThemeID,
      useCondition: integratedStoryCondition(integratedThemeID),
    });
  }

  for (const roleID of value.storySignalRoleIDs) {
    add({
      key: `modern.transit.signalRole.${roleID}`,
      cardID: "current-story",
      copySlot: "signalRole",
      roleID,
      variables: value.storySignalRoleVariables,
      useCondition: storySignalRoleCondition(roleID),
      requiredBy: [
        "TransitContentPlanner.current-story.signalRoles",
        "CopyCatalogMatcher.transitStorySignalRoleText",
        "InsightFactory.current-story",
        "GeneratedChartArtifact",
      ],
    });
  }

  for (const roleID of value.cycleRoleIDs) {
    for (const themeID of value.themeIDs) {
      add({
        key: `modern.transit.cycleChapter.${roleID}.${themeID}`,
        cardID: "current-cycles",
        copySlot: "cycleChapter",
        themeID,
        roleID,
        useCondition: `The first available ${roleID} aggregate signal maps to ${themeID}.`,
      });
    }
  }

  for (const [bodyID, states] of Object.entries(value.motionStatesByBody)) {
    for (const state of states) {
      add({
        key: `shared.bodyMotion.${bodyID}.${state}`,
        cardID: "planet-paths",
        copySlot: "planetPathShort",
        roleID: "path",
        useCondition: `The primary planned path is ${bodyID} in ${state} motion.`,
      });
    }
  }

  for (let house = 1; house <= 12; house += 1) {
    add({
      key: `shared.lifeAreas.${house}`,
      cardID: "planet-paths",
      copySlot: "planetPathShort",
      roleID: "path",
      useCondition: `The primary planned path occupies natal house ${house}.`,
    });
    add({
      key: `shared.lifeAreas.${house}`,
      cardID: "life-areas",
      copySlot: "lifeAreaShort",
      roleID: "lifeArea",
      useCondition: `Natal house ${house} is the highest-ranked complete life-area aggregate.`,
    });
  }

  for (const themeID of value.themeIDs) {
    add({
      key: `modern.transit.activeTransitShort.active.${themeID}`,
      cardID: "active-transits",
      copySlot: "activeTransitShort",
      themeID,
      roleID: "active",
      useCondition: `The first active evidence is a transit aspect mapped to ${themeID}.`,
    });
  }

  addActiveEventRequirement(add, "activeSignIngress", "structure.building", "The first active evidence is a sign-ingress event.");
  const housesByTheme = new Map();
  for (const [house, tones] of Object.entries(value.houseThemeFallbacks)) {
    const themeID = tones.neutral;
    housesByTheme.set(themeID, [...(housesByTheme.get(themeID) ?? []), Number(house)]);
  }
  for (const [themeID, houses] of [...housesByTheme.entries()].sort(([left], [right]) => left.localeCompare(right))) {
    addActiveEventRequirement(
      add,
      "activeHouseIngress",
      themeID,
      `The first active evidence is a house-ingress event entering natal house ${houses.join(" or ")}.`,
    );
  }
  addActiveEventRequirement(add, "activeStationRetrograde", "structure.building", "The first active evidence is a station-retrograde event.");
  addActiveEventRequirement(add, "activeStationDirect", "structure.building", "The first active evidence is a station-direct event.");

  return items.sort((left, right) => {
    const keyOrder = left.key.localeCompare(right.key);
    return keyOrder !== 0 ? keyOrder : left.cardID.localeCompare(right.cardID);
  });
}

function addActiveEventRequirement(add, roleID, themeID, useCondition) {
  add({
    key: `modern.transit.activeTransitShort.${roleID}.${themeID}`,
    cardID: "active-transits",
    copySlot: "activeTransitShort",
    themeID,
    roleID,
    useCondition,
  });
}

function integratedStoryCondition(integratedThemeID) {
  switch (integratedThemeID) {
    case "expansion-structure":
      return "Current Story contains at least one supportive and one challenging aspect signal.";
    case "focused-expansion":
      return "Current Story contains supportive aspect signals and no challenging signal.";
    case "durable-structure":
      return "Current Story contains challenging aspect signals and no supportive signal.";
    case "steady-realignment":
      return "Current Story contains only neutral aspect signals.";
    default:
      throw new Error(`Unknown integrated theme ${integratedThemeID}`);
  }
}

function storySignalRoleCondition(roleID) {
  return `A Current Story signal is assigned the ${roleID} role; interpolate its transit planet and localized life-area list.`;
}

function hasResolvableCopy(basePath, paths) {
  return [basePath, `${basePath}.headline`, `${basePath}.label`, `${basePath}.body`]
    .some((candidate) => paths.has(candidate));
}

function requirementIdentity(value) {
  return [value.key, value.cardID, value.copySlot].join("|");
}

function validatePlannerObservations(value) {
  if (value.schemaVersion !== 1 || !Array.isArray(value.observations)) {
    throw new Error("Unsupported modern transit Planner observations");
  }
  if (!Array.isArray(value.fixedFixtureIDs) || value.fixedFixtureIDs.length < 12) {
    throw new Error("At least 12 fixed transit fixtures are required");
  }
  const runsByChart = new Map();
  for (const run of value.realRuns ?? []) {
    runsByChart.set(run.chartID, (runsByChart.get(run.chartID) ?? 0) + 1);
  }
  if (runsByChart.size !== 5 || [...runsByChart.values()].some((count) => count !== 4)) {
    throw new Error("Exactly five real charts with four transit dates each are required");
  }
  const expectedCoverage = {
    integratedStory: ["durable-structure", "expansion-structure", "focused-expansion", "steady-realignment"],
    signalRole: ["disrupting", "expanding", "stabilizing", "structuring", "supporting"],
    cycleRole: ["currentCycle", "dailyCycle", "longCycle"],
    planetEvent: ["houseIngress", "signIngress", "stationDirect", "stationRetrograde"],
    houseIngress: Array.from({ length: 12 }, (_, index) => String(index + 1)),
  };
  for (const [name, expected] of Object.entries(expectedCoverage)) {
    const actual = [...(value.coverage?.[name] ?? [])].sort();
    if (actual.join("|") !== [...expected].sort().join("|")) {
      throw new Error(`Planner observations do not cover ${name}`);
    }
  }
}

function validateRegistry(value) {
  if (value.schemaVersion !== 1 || value.chartID !== "modern.transit") {
    throw new Error("Unsupported modern transit registry");
  }
  for (const [name, entries] of Object.entries({
    cardIDs: value.cardIDs,
    copySlots: value.copySlots,
    integratedThemeIDs: value.integratedThemeIDs,
    storySignalRoleIDs: value.storySignalRoleIDs,
    cycleRoleIDs: value.cycleRoleIDs,
    activeRoleIDs: value.activeRoleIDs,
    themeIDs: value.themeIDs,
  })) {
    if (!Array.isArray(entries) || entries.length === 0 || new Set(entries).size !== entries.length) {
      throw new Error(`${name} must be a non-empty unique array`);
    }
  }
  if (!Array.isArray(value.storySignalRoleVariables)
      || value.storySignalRoleVariables.length !== 2
      || value.storySignalRoleVariables[0]?.name !== "transitPlanet"
      || value.storySignalRoleVariables[0]?.type !== "body"
      || value.storySignalRoleVariables[1]?.name !== "lifeAreas"
      || value.storySignalRoleVariables[1]?.type !== "houseList") {
    throw new Error("Story signal-role variables must be transitPlanet:body and lifeAreas:houseList");
  }
  const expectedCopySlots = new Set([
    "integratedStory",
    "signalRole",
    "cycleChapter",
    "planetPathShort",
    "lifeAreaShort",
    "activeTransitShort",
  ]);
  if (value.copySlots.some((slot) => !expectedCopySlots.has(slot))
      || [...expectedCopySlots].some((slot) => !value.copySlots.includes(slot))) {
    throw new Error("Modern transit copy slots differ from the frozen registry");
  }
  const requiredStoryRoles = ["expanding", "structuring", "disrupting", "stabilizing", "supporting"];
  if (requiredStoryRoles.some((roleID) => !value.storySignalRoleIDs.includes(roleID))) {
    throw new Error("Modern transit story signal roles are incomplete");
  }
  if (value.cardIDs.length !== 6 || value.copySlots.length !== 6 || value.themeIDs.length !== 38) {
    throw new Error("Frozen modern transit registry counts changed");
  }
  const allowedThemes = new Set(value.themeIDs);
  for (const tones of Object.values(value.houseThemeFallbacks)) {
    for (const themeID of Object.values(tones)) {
      if (!allowedThemes.has(themeID)) throw new Error(`Unknown house fallback theme ${themeID}`);
    }
  }
}

function validateCatalog(value, registryValue) {
  if (value.schemaVersion !== 2 || value.status !== "approved" || !Array.isArray(value.entries)) {
    throw new Error("Runtime Copy Catalog must be an approved schema v2 pack");
  }
  const allowedThemes = new Set(registryValue.themeIDs);
  for (const rule of value.themeRulesByPreset?.modern ?? []) {
    if (!allowedThemes.has(rule.themeID)) {
      throw new Error(`Modern theme rule ${rule.id} uses unfrozen theme ${rule.themeID}`);
    }
  }
  const entriesByPath = new Map(value.entries.map((entry) => [entry.sourcePath, entry]));
  for (const [house, tones] of Object.entries(registryValue.houseThemeFallbacks)) {
    for (const [tone, themeID] of Object.entries(tones)) {
      const sourcePath = `shared.transit.houseFallback.${house}.${tone}`;
      if (entriesByPath.get(sourcePath)?.value !== themeID) {
        throw new Error(`Catalog house fallback differs from frozen registry at ${sourcePath}`);
      }
    }
  }
}

function readJSON(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function writeJSON(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}
