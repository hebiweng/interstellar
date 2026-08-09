import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const packageDirectory = path.resolve(process.argv[2] ?? "");
if (!packageDirectory || !fs.existsSync(packageDirectory)) throw new Error("Pass the extracted Synastry v3 package directory");

const presets = ["modern", "classical"];
const locales = ["en", "zh-Hans", "es", "fr"];
const cardIDs = ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"];
const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));

const registries = Object.fromEntries(presets.map((preset) => [
  preset,
  read(path.join(root, "artifacts", `${preset}-synastry`, `${preset}-synastry-copy-registry.json`)),
]));
const patches = {};
for (const preset of presets) {
  patches[preset] = {
    en: read(path.join(packageDirectory, `${preset}-synastry-copy-en.patch.json`)),
    "zh-Hans": read(path.join(packageDirectory, `${preset}-synastry-copy-zh-Hans.patch.json`)),
  };
  validatePatch(preset, patches[preset].en, registries[preset], "en");
  validatePatch(preset, patches[preset]["zh-Hans"], registries[preset], "zh-Hans");
}

for (const locale of locales) {
  const sourceFile = path.join(root, "ios", "PrivateContent", "copy-catalog-v2", `Interstellar_Copy_Catalog_${locale}_v2_three-layers.json`);
  const source = read(sourceFile);
  source.version = "2.0.1";
  for (const preset of presets) {
    const patch = locale === "zh-Hans" ? patches[preset]["zh-Hans"] : patches[preset].en;
    for (const [baseKey, fields] of Object.entries(patch.entries)) {
      for (const [field, value] of Object.entries(fields)) setPath(source, `${baseKey}.${field}`.split("."), value);
    }
  }
  source.contracts.synastry = synastryContracts();
  fs.writeFileSync(sourceFile, `${JSON.stringify(source, null, 2)}\n`);
}

console.log("Imported approved Synastry v3 copy into en/zh-Hans with English fallback for es/fr");

function validatePatch(preset, patch, registry, locale) {
  if (patch.chartID !== `${preset}.synastry` || patch.cardStructureRevision !== "synastry-eight-cards-v3" || patch.status !== "approved") {
    throw new Error(`${preset} patch envelope is invalid`);
  }
  const expected = new Map(registry.entries.map((entry) => [entry.key, entry]));
  const actualKeys = Object.keys(patch.entries).sort();
  if (actualKeys.length !== expected.size || actualKeys.some((key) => !expected.has(key))) throw new Error(`${preset} patch key set differs from Registry`);
  for (const [key, fields] of Object.entries(patch.entries)) {
    const contract = expected.get(key);
    const expectedFields = contract.fields.slice().sort();
    const actualFields = Object.keys(fields).sort();
    if (expectedFields.join("|") !== actualFields.join("|")) throw new Error(`${key} field contract differs from Registry`);
    const variables = new Set();
    for (const value of Object.values(fields)) {
      if (typeof value !== "string" || !value.trim()) throw new Error(`${key} contains empty copy`);
      for (const match of value.matchAll(/\{\{([A-Za-z][A-Za-z0-9]*)\}\}/g)) variables.add(match[1]);
      if (value.replace(/\{\{[A-Za-z][A-Za-z0-9]*\}\}/g, "").match(/\{\{|\}\}/)) throw new Error(`${key} has malformed placeholders`);
    }
    if (key.includes(".synastry.communication.")) validateCommunicationSteps(key, fields, locale);
    if ([...variables].sort().join("|") !== contract.variables.slice().sort().join("|")) throw new Error(`${key} placeholder contract differs from Registry`);
  }
}

function validateCommunicationSteps(key, fields, locale) {
  for (const field of ["step1", "step2", "step3"]) {
    const value = fields[field]?.trim();
    if (!value) throw new Error(`${key}.${field} must be a compact communication node`);
    if (/\byou\b/i.test(value) || value.includes("你")) throw new Error(`${key}.${field} must not use a directional second-person voice`);
    const isCompact = locale === "zh-Hans"
      ? value.length <= 10
      : value.length <= 28 && value.split(/\s+/).length <= 4;
    if (!isCompact) throw new Error(`${key}.${field} exceeds the compact communication-node contract`);
  }
}

function setPath(target, segments, value) {
  let cursor = target;
  for (const segment of segments.slice(0, -1)) {
    if (!cursor[segment] || typeof cursor[segment] !== "object" || Array.isArray(cursor[segment])) cursor[segment] = {};
    cursor = cursor[segment];
  }
  cursor[segments.at(-1)] = value;
}

function synastryContracts() {
  const factsByCard = {
    "relationship-overview": {
      modern: ["rankedCrossAspects", "overviewDimensions"],
      classical: ["rankedTraditionalCrossAspects", "classicalPlanetConditions", "crossChartReceptions", "overviewDimensions"],
    },
    perspectives: { modern: ["directionalHouseOverlays"], classical: ["directionalTraditionalHouseOverlays"] },
    "emotional-connection": { modern: ["rankedMoonCrossAspects"], classical: ["rankedTraditionalMoonCrossAspects", "moonReception"] },
    communication: { modern: ["rankedMercuryCrossAspects"], classical: ["rankedTraditionalMercuryCrossAspects", "mercuryReception"] },
    chemistry: { modern: ["rankedVenusMarsPlutoCrossAspects"], classical: ["rankedVenusMarsCrossAspects", "venusMarsReception"] },
    commitment: { modern: ["rankedSaturnJupiterCrossAspects"], classical: ["rankedSaturnJupiterCrossAspects", "saturnJupiterReception", "classicalPlanetConditions"] },
    "house-overlays": { modern: ["bidirectionalHouseOverlays"], classical: ["bidirectionalTraditionalHouseOverlays"] },
    "key-inter-aspects": { modern: ["rankedCrossAspects"], classical: ["rankedTraditionalCrossAspects", "crossChartReceptions"] },
  };
  return Object.fromEntries(cardIDs.map((cardID) => [cardID, {
    evidenceByPreset: factsByCard[cardID],
    textFields: ["headline", "body"],
    copySourceByPreset: { modern: `modern.synastry.${cardID}`, classical: `classical.synastry.${cardID}` },
    facts: [],
  }]));
}
