#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceLocales = ["en", "zh-Hans"];
const sourceRoots = ["shared", "modern", "classical"];

const entriesByLocale = Object.fromEntries(
  sourceLocales.map((locale) => [
    locale,
    flattenSource(
      readJSON(`ios/PrivateContent/copy-catalog-v2/Interstellar_Copy_Catalog_${locale}_v2_three-layers.json`),
      locale,
    ),
  ]),
);

const byPath = new Map();
for (const locale of sourceLocales) {
  for (const entry of entriesByLocale[locale]) {
    let existing = byPath.get(entry.sourcePath);
    if (!existing) {
      existing = {
        sourcePath: entry.sourcePath,
        preset: entry.preset,
        kind: entry.kind,
        variables: entry.variables,
      };
      byPath.set(entry.sourcePath, existing);
    }
    existing[locale] = entry.value;
  }
}

const rows = [...byPath.values()].sort((a, b) => a.sourcePath.localeCompare(b.sourcePath));
const consumerRows = rows.filter((row) => row.kind === "consumer");
const technicalRows = rows.filter((row) => row.kind === "technical");

const exportDirectory = path.join(repositoryRoot, "ios", "TranslationExports");
fs.mkdirSync(exportDirectory, { recursive: true });
const jsonPath = path.join(exportDirectory, "ios-v2-translation-worklist.json");
const csvPath = path.join(exportDirectory, "ios-v2-translation-worklist.csv");

fs.writeFileSync(
  jsonPath,
  `${JSON.stringify({
    schemaVersion: 2,
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
      consumer: consumerRows.length,
      technical: technicalRows.length,
    },
    entries: rows,
  }, null, 2)}\n`,
);

fs.writeFileSync(csvPath, toCSV(rows));
console.log(`Exported ${rows.length} translation rows`);
console.log(path.relative(repositoryRoot, jsonPath));
console.log(path.relative(repositoryRoot, csvPath));

function flattenSource(sourceCatalog, locale) {
  const result = [];
  for (const root of sourceRoots) {
    if (!sourceCatalog[root]) continue;
    visit(sourceCatalog[root], [root], result, locale, root);
  }
  return result;
}

function visit(value, segments, output, locale, preset) {
  if (segments.at(-1) === "themeRules") return;
  if (typeof value === "string") {
    if (!value.trim() || segments.at(-1) === "status") return;
    const sourcePath = segments.join(".");
    if (sourcePath.startsWith("shared.transit.themeRules.")) return;
    const kind = sourcePath.startsWith("shared.technical.templates.") ? "technical" : "consumer";
    output.push({
      sourcePath,
      preset,
      locale,
      kind,
      value,
      variables: declaredVariables(value),
    });
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => visit(item, [...segments, String(index + 1).padStart(3, "0")], output, locale, preset));
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const key of Object.keys(value).sort()) visit(value[key], [...segments, key], output, locale, preset);
}

function declaredVariables(template) {
  return [...new Set([...template.matchAll(/\{\{([A-Za-z][A-Za-z0-9]*)\}\}/g)].map((match) => match[1]))];
}

function readJSON(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8"));
}

function toCSV(entries) {
  const columns = ["sourcePath", "preset", "kind", "zh-Hans", "en", "variables"];
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
