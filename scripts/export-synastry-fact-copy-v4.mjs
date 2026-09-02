import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const inputPath = path.resolve(
  process.argv[2] ?? path.join(root, "ios", "TranslationExports", "synastry-fact-copy-generation-worklist-v4.json"),
);
const worklist = JSON.parse(fs.readFileSync(inputPath, "utf8"));
const generatedAt = new Date().toISOString();
const locales = ["en", "zh-Hans"];
const cardIDs = [
  "relationship-overview",
  "perspectives",
  "emotional-connection",
  "communication",
  "chemistry",
  "commitment",
  "house-overlays",
  "key-inter-aspects",
];

for (const preset of ["modern", "classical"]) {
  const entries = worklist.entries.filter((entry) => entry.preset === preset);
  const keys = entries.map((entry) => entry.key).sort();
  const scenarioIDs = [...new Set(entries.flatMap((entry) => entry.observedScenarios))].sort();
  const chartID = `${preset}.synastry`;
  const revision = "synastry-fact-copy-v4";
  const directory = path.join(root, "artifacts", `${preset}-synastry-fact-copy-v4`);
  const base = path.join(directory, `${preset}-synastry`);
  const structuralContracts = {
    revision: 4,
    status: "candidate",
    source: "Observed Swiss Ephemeris calculation plans from a connected physical iPhone",
    locales,
    fields: ["interpretation"],
    runtimeBoundary: "The calculated label/value remains UI-owned; generated copy interprets only the declared fact pattern.",
    prohibitedClaims: ["invented dates", "outcomes", "compatibility scores", "motives", "guarantees", "unobserved facts"],
  };
  const registryEntries = entries.map((entry) => ({
    key: entry.key,
    cardID: entry.cardID,
    role: entry.role,
    factType: entry.factType,
    factPattern: entry.factPattern,
    fields: ["interpretation"],
    variables: [],
  }));
  const requirements = entries.map((entry) => ({
    key: entry.key,
    cardID: entry.cardID,
    role: entry.role,
    factType: entry.factType,
    factPattern: entry.factPattern,
    context: entry.context,
    fields: ["interpretation"],
    variables: [],
    useCondition: `Use only when ${entry.factPattern} is selected for ${entry.cardID}${entry.role ? ` role ${entry.role}` : ""}.`,
    requiredBy: ["SynastryContentPlanner", "CopyCatalogMatcher", "SynastryChartCardFactory"],
    reachabilityStatus: "reachable",
    observationStatus: "observed-real-calculation",
    catalogStatus: "missing",
    missingLocales: locales,
    observedScenarios: entry.observedScenarios,
  }));
  const observations = scenarioIDs.map((scenarioID) => ({
    scenarioID,
    kind: "real-calculation-on-physical-device",
    copyKeys: entries.filter((entry) => entry.observedScenarios.includes(scenarioID)).map((entry) => entry.key).sort(),
  }));
  const missing = requirements.map((entry) => ({
    key: entry.key,
    cardID: entry.cardID,
    role: entry.role,
    factType: entry.factType,
    factPattern: entry.factPattern,
    requiredFields: entry.fields,
    variables: entry.variables,
    missingLocales: entry.missingLocales,
  }));

  fs.mkdirSync(directory, { recursive: true });
  write(`${base}-copy-registry.json`, {
    schemaVersion: 1, generatedAt, chartID, cardStructureRevision: revision,
    cardIDs, entryCount: registryEntries.length, structuralContracts, entries: registryEntries,
  });
  write(`${base}-copy-requirements.json`, {
    schemaVersion: 1, generatedAt, chartID, requirementCount: requirements.length,
    reachableCount: requirements.length, unreachableCount: 0, observedCount: requirements.length,
    unobservedCount: 0, missingCount: missing.length, structuralRequirements: structuralContracts, requirements,
  });
  write(`${base}-missing-copy.json`, {
    schemaVersion: 1, generatedAt, chartID, cardStructureRevision: revision,
    missingCount: missing.length, missing,
  });
  write(`${base}-planner-observations.json`, {
    schemaVersion: 1, generatedAt, chartID,
    realCalculationSampleCount: scenarioIDs.length,
    calculatedPlanCount: worklist.source.calculatedPlanCount / 2,
    samples: scenarioIDs.map((scenarioID) => ({ scenarioID })), observations,
  });
  write(`${base}-observed-copy-keys.json`, { schemaVersion: 1, generatedAt, chartID, count: keys.length, keys });
  for (const name of ["unobserved", "unknown", "unreachable"]) {
    write(`${base}-${name}-copy-keys.json`, { schemaVersion: 1, generatedAt, chartID, count: 0, keys: [] });
  }
  write(`${base}-fixtures.json`, {
    schemaVersion: 1, generatedAt, chartID,
    calculationSamples: scenarioIDs.map((scenarioID) => ({ scenarioID })),
    observedFactPatterns: registryEntries.map(({ key, cardID, role, factType, factPattern }) => ({ key, cardID, role, factType, factPattern })),
  });
  write(`${base}-validation.json`, {
    schemaVersion: 1, generatedAt, chartID, cardIDs, cardStructureRevision: revision,
    requirementCount: requirements.length, reachableCount: requirements.length, unreachableCount: 0,
    observedCount: requirements.length, unobservedCount: 0, missingCopyCount: missing.length,
    unknownCopyCount: 0, crossPresetFallbackCount: 0, duplicateFullClaimCount: 0,
    invalidSourceFactIDCount: 0, unstableScopeIDCount: 0, placeholderContractErrorCount: 0,
    cardContractErrorCount: 0, emptyStateContractErrorCount: 0,
    realCalculationSampleCount: scenarioIDs.length,
    calculatedPlanCount: worklist.source.calculatedPlanCount / 2,
    capabilityBoundary: preset === "classical" ? "Seven-planet Classical Synastry MVP; Node remains a future capability boundary." : null,
    runtimeCoveragePolicy: "Use reviewed v4 exact fact copy when present; otherwise use the declared reviewed shared planet-role or house-overlay selector.",
    passed: false,
    blockingReason: `Generate and approve ${missing.length} English and Simplified Chinese fact-level interpretations.`,
  });
  console.log(JSON.stringify({ preset, directory, files: 10, requirements: requirements.length, scenarios: scenarioIDs.length }));
}

function write(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}
