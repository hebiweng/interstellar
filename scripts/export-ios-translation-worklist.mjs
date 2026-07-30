#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const techniques = ["natal", "current-sky", "transit", "secondary"];
const chineseCorpus = techniques.flatMap((technique) =>
  readJSON(`ios/PrivateContent/${technique}/Corpus-zh-Hans.json`).entries ?? []
);
const englishCorpus = techniques.flatMap((technique) =>
  readJSON(`ios/PrivateContent/${technique}/Corpus-en.json`).entries ?? []
);
const chineseConsumer = readJSON("ios/App/Resources/PrivateContent-zh-Hans.json").entries ?? [];
const englishConsumer = readJSON("ios/App/Resources/PrivateContent-en.json").entries ?? [];
const englishCorpusByID = new Map(englishCorpus.map((entry) => [entry.id, entry]));
const englishConsumerByID = new Map(
  englishConsumer.map((entry) => [entry.contentKey, entry]),
);

const corpusRows = chineseCorpus.map((entry) => {
  const english = englishCorpusByID.get(entry.id);
  return {
    id: entry.id,
    type: "interpretation-corpus",
    priority: priorityForCorpus(entry),
    technique: first(entry.selector?.techniques),
    cardIDs: entry.selector?.cardIDs ?? [],
    layer: entry.layer,
    sourceRevision: entry.sourceRevision,
    chineseSummary: entry.summary,
    chineseDetail: entry.detail,
    englishSummary: english?.summary ?? "",
    englishDetail: english?.detail ?? "",
    translationStatus: english?.status ?? "missing",
    summaryGuidance: "One natural sentence; lead with the consumer-facing conclusion.",
    detailGuidance: "About 45–90 English words; plain language; preserve placeholders exactly.",
    placeholders: placeholders(`${entry.summary}\n${entry.detail}`),
  };
});

const consumerRows = chineseConsumer
  .filter((entry) => /^(today|week)\./.test(entry.contentKey))
  .map((entry) => {
    const english = englishConsumerByID.get(entry.contentKey);
    return {
      id: entry.contentKey,
      type: entry.contentKey.startsWith("week.")
        ? "weekly-consumer-copy"
        : "today-consumer-copy",
      priority: 1,
      technique: "today",
      cardIDs: [],
      layer: entry.contentKey.includes(".event.") ? "event" : "domain",
      sourceRevision: entry.sourceRevision,
      chineseSummary: entry.summary,
      chineseDetail: entry.detail,
      englishSummary: english?.summary ?? "",
      englishDetail: english?.detail ?? "",
      translationStatus: english?.translationStatus ?? "missing",
      summaryGuidance: "Short, direct, and understandable at a glance.",
      detailGuidance: "One or two concise consumer sentences; no astrology terminology.",
      placeholders: placeholders(`${entry.summary}\n${entry.detail}`),
    };
  });

const rows = [...consumerRows, ...corpusRows].sort((left, right) => {
  if (left.priority !== right.priority) {
    return left.priority - right.priority;
  }
  return left.id.localeCompare(right.id);
});
const exportDirectory = path.join(repositoryRoot, "ios", "TranslationExports");
fs.mkdirSync(exportDirectory, { recursive: true });
const jsonPath = path.join(exportDirectory, "ios-v1-translation-worklist.json");
const csvPath = path.join(exportDirectory, "ios-v1-translation-worklist.csv");
fs.writeFileSync(
  jsonPath,
  `${JSON.stringify({
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    instructions: {
      targetLocale: "en",
      preservePlaceholders: true,
      defaultLanguage: "en",
      tone: "Natural consumer English; concrete, concise, and free of AI or report-like phrasing.",
      forbiddenInConsumerCopy: [
        "orb",
        "applying",
        "separating",
        "exact aspect",
        "natal house",
        "technical disclaimers",
      ],
    },
    counts: {
      total: rows.length,
      todayAndWeek: consumerRows.length,
      interpretationCorpus: corpusRows.length,
    },
    entries: rows,
  }, null, 2)}\n`,
);
fs.writeFileSync(csvPath, toCSV(rows));
console.log(`Exported ${rows.length} translation rows`);
console.log(path.relative(repositoryRoot, jsonPath));
console.log(path.relative(repositoryRoot, csvPath));

function priorityForCorpus(entry) {
  const techniques = entry.selector?.techniques ?? [];
  if (techniques.includes("natal")) return 2;
  if (techniques.includes("transit")) return 3;
  if (techniques.includes("current-sky")) return 4;
  return 5;
}

function placeholders(value) {
  return [...new Set([...value.matchAll(/\{\{[^}]+\}\}/g)].map((match) => match[0]))];
}

function first(values) {
  return Array.isArray(values) ? values[0] ?? "" : "";
}

function readJSON(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8"));
}

function toCSV(entries) {
  const columns = [
    "id",
    "type",
    "priority",
    "technique",
    "layer",
    "sourceRevision",
    "chineseSummary",
    "chineseDetail",
    "englishSummary",
    "englishDetail",
    "translationStatus",
    "summaryGuidance",
    "detailGuidance",
    "placeholders",
  ];
  const lines = [columns.join(",")];
  for (const entry of entries) {
    lines.push(columns.map((column) => csvCell(
      Array.isArray(entry[column]) ? entry[column].join(" | ") : entry[column],
    )).join(","));
  }
  return `${lines.join("\n")}\n`;
}

function csvCell(value) {
  const text = value == null ? "" : String(value);
  return `"${text.replaceAll('"', '""')}"`;
}
