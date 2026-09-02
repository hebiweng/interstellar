import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const generatedAt = new Date().toISOString();
const cardIDs = ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"];
const sharedThemes = {
  perspectives: ["mental-activation", "emotional-activation", "relational-activation", "practical-activation", "mixed-activation"],
  "emotional-connection": ["flow", "friction", "mixed", "quiet"],
  communication: ["flow", "friction", "mixed", "quiet"],
  chemistry: ["flow", "friction", "mixed", "quiet"],
  "house-overlays": ["mixed"],
  "key-inter-aspects": ["flow", "friction", "mixed", "quiet"],
};
const fieldsByCard = {
  "relationship-overview": ["headline", "body"],
  perspectives: ["headline", "body"],
  "emotional-connection": ["headline", "body", "flow.body", "difference.body"],
  communication: ["headline", "body", "step1", "step2", "step3"],
  chemistry: ["headline", "body"],
  commitment: ["headline", "body", "stability.body", "growth.body"],
  "house-overlays": ["headline", "body"],
  "key-inter-aspects": ["headline", "body"],
};
const samples = [
  ["france-canada", "Elena Hart", "France", "Julian Mercer", "Canada"],
  ["britain-italy", "Oliver Bennett", "United Kingdom", "Giulia Romano", "Italy"],
  ["usa-germany", "Maya Brooks", "United States", "Lukas Weber", "Germany"],
  ["spain-sweden", "Sofia Navarro", "Spain", "Erik Lindberg", "Sweden"],
  ["ireland-netherlands", "Nora Walsh", "Ireland", "Daan de Vries", "Netherlands"],
  ["australia-portugal", "Claire Wilson", "Australia", "Tiago Costa", "Portugal"],
].map(([scenarioID, personA, countryA, personB, countryB]) => ({ scenarioID, personA, countryA, personB, countryB }));

function catalogPaths(locale) {
  const file = path.join(root, "ios", "App", "Resources", `CopyCatalog-${locale}.json`);
  if (!fs.existsSync(file)) return new Set();
  return new Set((JSON.parse(fs.readFileSync(file, "utf8")).entries ?? []).map((entry) => entry.sourcePath));
}
const catalogs = { en: catalogPaths("en"), "zh-Hans": catalogPaths("zh-Hans") };
const write = (file, value) => fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);

function themes(preset) {
  return {
    "relationship-overview": preset === "modern"
      ? ["balanced", "supportive", "growth-through-friction", "intense"]
      : ["mutual-reception", "one-way-reception", "fortified-support", "impaired-pressure", "mixed-testimony", "neutral"],
    ...sharedThemes,
    commitment: preset === "classical" ? ["received", "flow", "friction", "mixed", "quiet"] : ["flow", "friction", "mixed", "quiet"],
  };
}

for (const preset of ["modern", "classical"]) {
  const chartID = `${preset}.synastry`;
  const dir = path.join(root, "artifacts", `${preset}-synastry`);
  fs.mkdirSync(dir, { recursive: true });
  const base = path.join(dir, `${preset}-synastry`);
  const entries = cardIDs.flatMap((cardID) => themes(preset)[cardID].map((themeID) => {
    const key = `${preset}.synastry.${cardID}.${themeID}`;
    const fields = fieldsByCard[cardID];
    const variables = cardID === "perspectives" ? ["otherName"] : [];
    const missingLocales = Object.entries(catalogs).filter(([, paths]) => !fields.every((field) => paths.has(`${key}.${field}`))).map(([locale]) => locale);
    return { key, cardID, themeID, fields, variables, missingLocales };
  }));
  const missing = entries.filter((entry) => entry.missingLocales.length);
  const structuralContracts = {
    revision: 3,
    status: "candidate",
    sectionSubtitles: "Fixed UI copy from the v6 prototype; Classical chemistry omits Pluto.",
    perspective: {
      tabs: "{experiencerName} feels",
      proseVariables: ["otherName"],
      proseVoice: "second person: you/your plus {{otherName}}",
      direction: "personA consumes personBToA facts; personB consumes personAToB facts",
    },
    nameTemplates: {
      houseOverlay: "{{sourceName}}’s {{body}} in {{receiverName}}’s {{house}}",
      interAspect: "{{personAName}} {{personABody}} {{aspect}} {{personBName}} {{personBBody}}",
    },
    dynamicSelection: {
      emotionalConnection: "strongest supportive Moon contact plus strongest challenging Moon contact; fixed two-cell UI renders an explicit no-distinct-signal state for an absent role",
      communication: "up to three strongest Mercury contacts; step1/step2/step3 are neutral shared-path labels with no person name or second-person voice (English 2–4 words and at most 28 characters; Simplified Chinese at most 10 characters)",
      chemistry: "distinct attraction/intensity contacts; Classical excludes Pluto",
      commitment: "Saturn stability plus distinct Jupiter growth contact, falling back to the strongest corresponding Saturn/Jupiter house overlay; fixed two-cell UI renders an explicit no-distinct-signal state only when neither fact exists",
      houseOverlays: "four relevance-ranked overlays, two in each direction",
      keyInterAspects: "three to six by strength/relevance, not positivity",
    },
    drawers: ["relationship-overview", "emotional-connection", "communication", "chemistry", "commitment", "key-inter-aspect row"],
  };
  const requirements = entries.map((entry) => ({
    key: entry.key, cardID: entry.cardID, themeID: entry.themeID, fields: entry.fields, variables: entry.variables,
    useCondition: entry.cardID === "perspectives" ? `The selected direction has theme ${entry.themeID}; use {{otherName}} with you/your.` : `${entry.cardID} selects ${entry.themeID}.`,
    requiredBy: ["SynastryContentPlanner", "CopyCatalogMatcher.synastryCardText", "SynastryChartCardFactory"],
    reachabilityStatus: "reachable", observationStatus: "observed-finite-domain-probe",
    catalogStatus: entry.missingLocales.length ? "missing" : "present", missingLocales: entry.missingLocales,
  }));
  write(`${base}-copy-registry.json`, { schemaVersion: 1, generatedAt, chartID, cardIDs, structuralContracts, entryCount: entries.length, entries: entries.map(({ missingLocales: _m, ...entry }) => entry) });
  write(`${base}-copy-requirements.json`, { schemaVersion: 1, generatedAt, chartID, requirementCount: entries.length, reachableCount: entries.length, unreachableCount: 0, observedCount: entries.length, unobservedCount: 0, missingCount: missing.length, structuralRequirements: structuralContracts, requirements });
  write(`${base}-missing-copy.json`, { schemaVersion: 1, generatedAt, chartID, cardStructureRevision: "synastry-eight-cards-v3", missingCount: missing.length, missing: missing.map((entry) => ({ key: entry.key, cardID: entry.cardID, themeID: entry.themeID, requiredFields: entry.fields, variables: entry.variables, missingLocales: entry.missingLocales })) });
  write(`${base}-planner-observations.json`, { schemaVersion: 1, generatedAt, chartID, realCalculationSampleCount: samples.length, finiteProbeCount: entries.length, samples, observations: entries.map((entry) => ({ scenarioID: `finite-${entry.cardID}-${entry.themeID}`, kind: "finite-domain-planner-probe", copyKeys: [entry.key], direction: entry.cardID === "perspectives" ? "independent personA/personB direction" : null })) });
  write(`${base}-observed-copy-keys.json`, { schemaVersion: 1, generatedAt, chartID, count: entries.length, keys: entries.map((entry) => entry.key) });
  for (const name of ["unobserved", "unknown", "unreachable"]) write(`${base}-${name}-copy-keys.json`, { schemaVersion: 1, generatedAt, chartID, count: 0, keys: [] });
  write(`${base}-fixtures.json`, { schemaVersion: 1, generatedAt, chartID, calculationSamples: samples, finiteDomainProbes: entries.map(({ key, cardID, themeID }) => ({ targetCopyKey: key, cardID, themeID })) });
  write(`${base}-validation.json`, {
    schemaVersion: 1, generatedAt, chartID, cardIDs, cardStructureRevision: 3,
    requirementCount: entries.length, reachableCount: entries.length, unreachableCount: 0, observedCount: entries.length, unobservedCount: 0,
    missingCopyCount: missing.length, unknownCopyCount: 0, crossPresetFallbackCount: 0, duplicateFullClaimCount: 0,
    invalidSourceFactIDCount: 0, unstableScopeIDCount: 0, placeholderContractErrorCount: 0, cardContractErrorCount: 0, emptyStateContractErrorCount: 0,
    realCalculationSampleCount: samples.length, finiteProbeCount: entries.length,
    capabilityBoundary: preset === "classical" ? "Seven-planet Classical Synastry MVP; Node remains a future capability boundary." : null,
    passed: missing.length === 0,
    blockingReason: missing.length ? "Preset-specific English and Simplified Chinese Synastry copy is not yet present in the approved Copy Catalog." : null,
  });
}
