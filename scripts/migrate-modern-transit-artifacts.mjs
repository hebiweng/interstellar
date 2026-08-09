import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceSchema = path.join(root, "ios", "ContentSchema");
const sourceExports = path.join(root, "ios", "TranslationExports");
const destination = path.join(root, "artifacts", "modern-transit");
fs.mkdirSync(destination, { recursive: true });

const copyMap = new Map([
  [path.join(sourceSchema, "modern-transit-copy-registry.json"), "modern-transit-copy-registry.json"],
  [path.join(sourceExports, "modern-transit-copy-requirements.json"), "modern-transit-copy-requirements.json"],
  [path.join(sourceExports, "modern-transit-missing-copy.json"), "modern-transit-missing-copy.json"],
  [path.join(sourceExports, "modern-transit-planner-observations.json"), "modern-transit-planner-observations.json"],
  [path.join(sourceExports, "observed-copy-keys.json"), "modern-transit-observed-copy-keys.json"],
  [path.join(sourceExports, "unknown-copy-keys.json"), "modern-transit-unknown-copy-keys.json"],
  [path.join(sourceExports, "unreachable-copy-keys.json"), "modern-transit-unreachable-copy-keys.json"],
]);

for (const [source, name] of copyMap) {
  if (!fs.existsSync(source)) throw new Error(`Missing completed Modern Transit artifact: ${source}`);
  fs.copyFileSync(source, path.join(destination, name));
}

const read = (name) => JSON.parse(fs.readFileSync(path.join(destination, name), "utf8"));
const write = (name, value) => fs.writeFileSync(path.join(destination, name), `${JSON.stringify(value, null, 2)}\n`);
const requirements = read("modern-transit-copy-requirements.json");
const observations = read("modern-transit-planner-observations.json");
const observed = read("modern-transit-observed-copy-keys.json");
const unknown = read("modern-transit-unknown-copy-keys.json");
const unreachable = read("modern-transit-unreachable-copy-keys.json");
const missing = read("modern-transit-missing-copy.json");

if (requirements.chartID !== "modern.transit" || observed.chartID !== "modern.transit") {
  throw new Error("Refusing to migrate non-Modern-Transit artifacts");
}
if (requirements.reachableCount !== observed.observedCount) {
  throw new Error("Existing completed artifacts disagree on reachable/observed coverage");
}

const generatedAt = observations.generatedAt ?? requirements.generatedAt;
write("modern-transit-unobserved-copy-keys.json", {
  schemaVersion: 1,
  generatedAt,
  chartID: "modern.transit",
  unobservedCount: 0,
  unobserved: [],
  derivedFrom: [
    "modern-transit-copy-requirements.json#reachableCount",
    "modern-transit-observed-copy-keys.json#observedCount",
  ],
});
write("modern-transit-fixtures.json", {
  schemaVersion: 1,
  generatedAt,
  chartID: "modern.transit",
  fixedFixtureCount: observations.fixedFixtureIDs?.length ?? 0,
  fixedFixtureIDs: observations.fixedFixtureIDs ?? [],
  realRunCount: observations.realRuns?.length ?? 0,
  realRuns: observations.realRuns ?? [],
  exhaustiveProbeCount: observations.exhaustiveProbeCount ?? 0,
  coverage: observations.coverage ?? {},
  sourceArtifact: "modern-transit-planner-observations.json",
});
write("modern-transit-validation.json", {
  schemaVersion: 1,
  generatedAt,
  chartID: "modern.transit",
  requirementCount: requirements.requirementCount,
  reachableCount: requirements.reachableCount,
  unreachableCount: unreachable.unreachableCount,
  observedCount: observed.observedCount,
  unobservedCount: 0,
  missingCopyCount: missing.missingCount,
  unknownCopyCount: unknown.unknownCount,
  fixedFixtureCount: observed.fixedFixtureCount,
  realChartCount: observed.realChartCount,
  realRunCount: observed.realRunCount,
  exhaustiveProbeCount: observed.exhaustiveProbeCount,
  passed: missing.missingCount === 0
    && unknown.unknownCount === 0
    && unreachable.unreachableCount === requirements.unreachableCount
    && observed.observedCount === requirements.reachableCount,
  sourceArtifacts: [
    "modern-transit-copy-requirements.json",
    "modern-transit-observed-copy-keys.json",
    "modern-transit-unknown-copy-keys.json",
    "modern-transit-unreachable-copy-keys.json",
    "modern-transit-missing-copy.json",
  ],
});

console.log(`Migrated completed Modern Transit artifacts to ${path.relative(root, destination)}`);
