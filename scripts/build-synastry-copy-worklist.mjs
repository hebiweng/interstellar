import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const inputPath = process.argv[2];
const outputPath = process.argv[3] ?? path.join(
  root,
  "ios",
  "TranslationExports",
  "synastry-fact-copy-generation-worklist-v4.json",
);

if (!inputPath) {
  throw new Error("Usage: node scripts/build-synastry-copy-worklist.mjs <xcode-test-log> [output-json]");
}

const log = fs.readFileSync(inputPath, "utf8");
const match = log.match(/SYNASTRY_PLANNER_OBSERVATIONS_BASE64:([A-Za-z0-9+/=]+)/);
if (!match) {
  throw new Error(`No synastry planner observations found in ${inputPath}`);
}

const payload = JSON.parse(Buffer.from(match[1], "base64").toString("utf8"));
const work = new Map();

function normalizedRole(role) {
  return role || "general";
}

function patternFor(fact) {
  if (fact.kind === "aspect") {
    return `${fact.firstBody}.${fact.aspectKind}.${fact.secondBody}`;
  }
  if (fact.kind === "overlay") {
    return `${fact.direction}.${fact.body}.house-${fact.house}`;
  }
  const polarity = Number(fact.score) >= 0 ? "supportive" : "challenging";
  return `${fact.person}.${fact.body}.${polarity}`;
}

function contextFor(fact) {
  if (fact.kind === "aspect") {
    return `${fact.firstBody} ${fact.aspectKind} ${fact.secondBody}; the UI separately shows the calculated orb and phase.`;
  }
  if (fact.kind === "overlay") {
    return `${fact.direction}: ${fact.body} falls in house ${fact.house}; the UI separately shows sign and exact degree.`;
  }
  return `${fact.person} ${fact.body} condition score is ${fact.score}; the UI separately shows the calculated score and conditions.`;
}

for (const observation of payload.observations ?? []) {
  for (const card of observation.cards ?? []) {
    for (const fact of card.facts ?? []) {
      const role = normalizedRole(fact.role);
      const pattern = patternFor(fact);
      const key = `${observation.preset}.synastry.fact.${card.cardID}.${role}.${fact.kind}.${pattern}`;
      const existing = work.get(key) ?? {
        key,
        preset: observation.preset,
        cardID: card.cardID,
        role: role === "general" ? null : role,
        factType: fact.kind,
        factPattern: pattern,
        context: contextFor(fact),
        observedScenarios: [],
        en: "",
        "zh-Hans": "",
      };
      if (!existing.observedScenarios.includes(observation.scenarioID)) {
        existing.observedScenarios.push(observation.scenarioID);
      }
      work.set(key, existing);
    }
  }
}

const entries = [...work.values()]
  .map((entry) => ({ ...entry, observedScenarios: entry.observedScenarios.sort() }))
  .sort((a, b) => a.key.localeCompare(b.key));
const scenarioCount = new Set((payload.observations ?? []).map((item) => item.scenarioID)).size;

const result = {
  schemaVersion: 1,
  purpose: "Private reviewed fact-level Synastry copy generation worklist",
  source: {
    calculation: "Swiss Ephemeris on a connected physical iPhone",
    scenarioCount,
    presetCount: new Set((payload.observations ?? []).map((item) => item.preset)).size,
    calculatedPlanCount: (payload.observations ?? []).length,
  },
  instructions: [
    "Fill en and zh-Hans only. Spanish and French consumer copy deliberately fall back to reviewed English for now.",
    "Write one natural interpretation of the stated calculated pattern; do not repeat the technical label, orb, phase, score, house, sign, or degree.",
    "Do not invent dates, outcomes, compatibility scores, events, motives, guarantees, or facts absent from context.",
    "Keep entries card-specific and role-specific so Emotional Connection, Communication, Chemistry, Commitment, House Overlays, and Key Inter-Aspects do not repeat the same claim.",
    "English should normally be 10–28 words; Simplified Chinese should normally be 12–42 Chinese characters.",
  ],
  entryCount: entries.length,
  entries,
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({ outputPath, entryCount: entries.length, calculatedPlanCount: result.source.calculatedPlanCount }));
