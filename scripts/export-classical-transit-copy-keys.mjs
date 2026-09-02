import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDirectory = path.join(repositoryRoot, "artifacts", "classical-transit");
const sourceRegistryPath = path.join(repositoryRoot, "ios", "ContentSchema", "classical-transit-copy-registry.json");
const observationsPath = path.join(outputDirectory, "classical-transit-planner-observations.json");
const catalogPath = path.join(repositoryRoot, "ios", "App", "Resources", "CopyCatalog-en.json");
const registry = readJSON(sourceRegistryPath);
const observations = readJSON(observationsPath);
const catalog = readJSON(catalogPath);
const requirements = buildRequirements(registry);
const observedByIdentity = new Map(observations.observations.map((item) => [identity(item), item]));
const catalogPaths = new Set(catalog.entries.map((entry) => entry.sourcePath));
const withStatus = requirements.map((item) => ({
  ...item,
  reachabilityStatus: "reachable",
  observationStatus: observedByIdentity.has(identity(item)) ? "observed" : "unobserved",
  catalogStatus: hasCopy(item.key, catalogPaths) ? "present" : "missing-copy",
}));
const requirementIdentities = new Set(withStatus.map(identity));
const unknown = observations.observations.filter((item) => !requirementIdentities.has(identity(item)));
const unobserved = withStatus.filter((item) => item.observationStatus === "unobserved");
const unreachable = [];
const missing = withStatus.filter((item) => item.catalogStatus === "missing-copy");
const observed = observations.observations;
const modernFallbacks = observed.filter((item) => item.key.startsWith("modern.transit."));
const timelineRequests = observed.filter((item) => item.cardID === "transit-timeline");
const invalidSourceFactIDs = observed.filter((item) => item.sourceFactIDs.some((id) => !id.startsWith("transit.")));
const reusedApprovedClassical = withStatus.filter((item) => item.reachabilityStatus === "reachable" && item.catalogStatus === "present");
const placeholderContractErrors = observed.filter((item) => {
  const allowed = new Set(registry.variableContracts[item.copySlot] ?? []);
  return Object.keys(item.variables).some((name) => !allowed.has(name));
});
const contractMetrics = observations.contractMetrics;

fs.mkdirSync(outputDirectory, { recursive: true });
writeJSON("classical-transit-copy-registry.json", registry);
writeJSON("classical-transit-copy-requirements.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  requirementCount: withStatus.length,
  reachableCount: withStatus.length,
  unreachableCount: unreachable.length,
  observedCount: withStatus.length - unobserved.length,
  unobservedCount: unobserved.length,
  missingCount: missing.length,
  requirements: withStatus,
});
writeJSON("classical-transit-missing-copy.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  missingCount: missing.length,
  missing,
});
writeJSON("classical-transit-observed-copy-keys.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  observedCount: observed.length,
  observed,
});
writeJSON("classical-transit-unobserved-copy-keys.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  unobservedCount: unobserved.length,
  unobserved,
});
writeJSON("classical-transit-unknown-copy-keys.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  unknownCount: unknown.length,
  unknown,
});
writeJSON("classical-transit-unreachable-copy-keys.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  unreachableCount: unreachable.length,
  unreachable,
});
writeJSON("classical-transit-fixtures.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  fixtureCount: observations.fixtureCount,
  fixtures: observations.fixtures,
  realRunCount: observations.realRunCount,
  realRuns: observations.realRuns,
  capabilityGaps: observations.capabilityGaps,
});
writeJSON("classical-transit-validation.json", {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  chartID: registry.chartID,
  cardIDs: registry.cardIDs,
  requirementCount: withStatus.length,
  reachableCount: withStatus.length,
  unreachableCount: unreachable.length,
  observedCount: withStatus.length - unobserved.length,
  unobservedCount: unobserved.length,
  missingCopyCount: missing.length,
  unknownCopyCount: unknown.length,
  approvedClassicalReuseCount: reusedApprovedClassical.length,
  classicalToModernFallbackCount: modernFallbacks.length,
  timelineConsumerCopyRequestCount: timelineRequests.length,
  invalidSourceFactIDCount: invalidSourceFactIDs.length,
  duplicateFullClaimCount: contractMetrics.duplicateFullClaimCount,
  unstableScopeIDCount: contractMetrics.unstableScopeIDCount,
  cardContractErrorCount: contractMetrics.cardContractErrorCount,
  emptyStateContractErrorCount: contractMetrics.emptyStateContractErrorCount,
  placeholderContractErrorCount: placeholderContractErrors.length,
  fixtureCount: observations.fixtureCount,
  realRunCount: observations.realRunCount,
  finiteProbeCount: observations.finiteProbeCount,
  capabilityGaps: observations.capabilityGaps,
  passed: unknown.length === 0
    && modernFallbacks.length === 0
    && timelineRequests.length === 0
    && invalidSourceFactIDs.length === 0
    && contractMetrics.duplicateFullClaimCount === 0
    && contractMetrics.unstableScopeIDCount === 0
    && contractMetrics.cardContractErrorCount === 0
    && contractMetrics.emptyStateContractErrorCount === 0
    && placeholderContractErrors.length === 0
    && unobserved.length === 0,
});

console.log(`Classical Transit requirements: ${withStatus.length}`);
console.log(`Reachable: ${withStatus.length}`);
console.log(`Unreachable: ${unreachable.length}`);
console.log(`Observed: ${withStatus.length - unobserved.length}`);
console.log(`Unobserved: ${unobserved.length}`);
console.log(`Missing copy: ${missing.length}`);
console.log(`Unknown copy: ${unknown.length}`);
console.log(`Approved Classical reuse: ${reusedApprovedClassical.length}`);
console.log(`Classical to Modern fallback: ${modernFallbacks.length}`);

if (unknown.length > 0) throw new Error("Classical Transit emitted Copy keys outside its Registry");
if (modernFallbacks.length > 0) throw new Error("Classical Transit fell back to Modern Copy");
if (timelineRequests.length > 0) throw new Error("Classical Transit timeline requested consumer Copy");
if (invalidSourceFactIDs.length > 0) throw new Error("Classical Transit emitted invalid sourceFactIDs");
if (contractMetrics.duplicateFullClaimCount > 0) throw new Error("Classical Transit emitted duplicate full claims");
if (contractMetrics.unstableScopeIDCount > 0) throw new Error("Classical Transit emitted unstable scope IDs");
if (contractMetrics.cardContractErrorCount > 0) throw new Error("Classical Transit changed its frozen card contract");
if (contractMetrics.emptyStateContractErrorCount > 0) throw new Error("Classical Transit changed its empty-state contract");
if (placeholderContractErrors.length > 0) throw new Error("Classical Transit emitted invalid Copy placeholders");
if (unobserved.length > 0) throw new Error("Classical Transit finite-domain probes did not cover every reachable Registry key");

function buildRequirements(value) {
  const result = [];
  const add = ({ key, cardID, copySlot, themeID = null, integratedThemeID = null, roleID = null, variables = [], useCondition }) => {
    result.push({
      key,
      cardID,
      copySlot,
      themeID,
      integratedThemeID,
      roleID,
      variables,
      useCondition,
      requiredBy: ["ClassicalTransitPlanningStrategy", "CopyCatalogMatcher.classicalTransitCopyRequests", `TransitCardFactory.${cardID}`],
    });
  };
  for (const integratedThemeID of value.integratedThemeIDs) {
    add({ key: `classical.transit.integratedStory.${integratedThemeID}`, cardID: "current-story", copySlot: "integratedStory", integratedThemeID, useCondition: `Current Story resolves to ${integratedThemeID}.` });
  }
  for (const roleID of value.signalRoleIDs) {
    add({ key: `classical.transit.signalRole.${roleID}`, cardID: "current-story", copySlot: "signalRole", roleID, useCondition: `A selected Classical testimony has role ${roleID}.` });
  }
  for (const [roleID, themes] of Object.entries(value.cycleThemesByRole)) {
    for (const themeID of themes) add({ key: `classical.transit.cycleChapter.${roleID}.${themeID}`, cardID: "current-cycles", copySlot: "cycleChapter", themeID, roleID, useCondition: `${roleID} aggregate maps to ${themeID}.` });
  }
  for (const themeID of value.planetPathThemeIDs) {
    add({ key: `classical.transit.planetPathShort.${themeID}`, cardID: "planet-paths", copySlot: "planetPathShort", themeID, roleID: "path", useCondition: `Primary planned path has ${themeID}.` });
  }
  for (const house of value.lifeAreaIDs) {
    add({ key: `classical.transit.lifeAreaShort.house-${house}`, cardID: "life-areas", copySlot: "lifeAreaShort", themeID: "house-activation", roleID: "lifeArea", useCondition: `House ${house} is the leading activity aggregate.` });
  }
  for (const [roleID, themes] of Object.entries(value.activeThemesByRole)) {
    for (const themeID of themes) add({ key: `classical.transit.activeTransitShort.${roleID}.${themeID}`, cardID: "active-transits", copySlot: "activeTransitShort", themeID, roleID, useCondition: `Primary active evidence has role ${roleID} and theme ${themeID}.` });
  }
  return result.sort((left, right) => left.key.localeCompare(right.key));
}

function identity(value) {
  return [value.key, value.cardID, value.copySlot].join("|");
}

function hasCopy(key, paths) {
  return [key, `${key}.headline`, `${key}.body`, `${key}.label`].some((candidate) => paths.has(candidate));
}

function readJSON(filename) {
  return JSON.parse(fs.readFileSync(filename, "utf8"));
}

function writeJSON(filename, value) {
  fs.writeFileSync(path.join(outputDirectory, filename), `${JSON.stringify(value, null, 2)}\n`);
}
