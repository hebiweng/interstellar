#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const options = parseArguments(process.argv.slice(2));
const techniques = ["natal", "current-sky", "transit", "secondary"];
const locales = ["en", "zh-Hans"];

for (const locale of locales) {
  const corpus = readJSON(
    path.join(root, "ios", "PrivateContent", `Corpus-${locale}.json`)
  );
  const rules = readJSON(
    path.join(root, "ios", "PrivateRules", `Composition-${locale}.json`)
  );
  const consumer = readJSON(
    path.join(root, "ios", "App", "Resources", `PrivateContent-${locale}.json`)
  );

  let entries = corpus.entries ?? [];
  if (locale === "zh-Hans" && options["natal-candidate"]) {
    entries = mergeCompatibleNatalCandidate(
      entries,
      readJSON(path.resolve(options["natal-candidate"]))
    );
  }

  for (const technique of techniques) {
    writeJSON(
      path.join(
        root,
        "ios",
        "PrivateContent",
        technique,
        `Corpus-${locale}.json`
      ),
      {
        schemaVersion: 1,
        locale,
        technique,
        entries: entries.filter((entry) =>
          entry.selector?.techniques?.includes(technique)
        ),
      }
    );
    writeJSON(
      path.join(
        root,
        "ios",
        "PrivateRules",
        technique,
        `Composition-${locale}.json`
      ),
      {
        schemaVersion: 1,
        locale,
        technique,
        rules: (rules.rules ?? []).filter(
          (rule) => rule.technique === technique
        ),
      }
    );
  }

  for (const area of ["today", "week", "ask"]) {
    writeJSON(
      path.join(
        root,
        "ios",
        "PrivateContent",
        area,
        `Content-${locale}.json`
      ),
      {
        schemaVersion: 1,
        locale,
        area,
        entries: (consumer.entries ?? []).filter((entry) =>
          entry.contentKey?.startsWith(`${area}.`)
        ),
      }
    );
  }
}

console.log("Split private corpus, rules, and consumer content by runtime domain.");

function mergeCompatibleNatalCandidate(existing, candidate) {
  if (candidate.locale !== "zh-Hans" || candidate.technique !== "natal") {
    throw new Error("Natal candidate must use locale zh-Hans and technique natal");
  }
  const cardIDs = new Set([
    "core-structure",
    "strongest-themes",
    "core-strengths",
    "blind-spot",
    "growth-direction",
  ]);
  const archetypes = [
    new Set(["point", "luminary", "personal", "direct"]),
    new Set(["point", "personal", "direct"]),
    new Set(["point", "social", "direct"]),
    new Set(["point", "outer", "direct"]),
    new Set(["point", "outer", "retrograde"]),
    new Set(["aspect", "single-chart", "supportive", "sextile", "applying", "personal"]),
    new Set(["aspect", "single-chart", "supportive", "trine", "exact", "personal"]),
    new Set(["aspect", "single-chart", "challenging", "square", "applying", "personal"]),
    new Set(["aspect", "single-chart", "challenging", "opposition", "separating", "personal"]),
    new Set(["aspect", "single-chart", "neutral", "conjunction", "exact", "personal"]),
    new Set(["house", "active-domain", "leading-domain"]),
  ];
  const validPoints = new Set([
    "sun", "moon", "mercury", "venus", "mars",
    "jupiter", "saturn", "uranus", "neptune", "pluto",
  ]);
  const validAspects = new Set([
    "conjunction", "sextile", "square", "trine", "opposition",
  ]);

  const accepted = (candidate.entries ?? []).filter((entry) => {
    if (entry.status !== "approved" || entry.locale !== "zh-Hans") return false;
    if (!entry.selector?.techniques?.includes("natal")) return false;
    if (!(entry.selector.cardIDs ?? []).every((id) => cardIDs.has(id))) return false;
    if (!(entry.selector.pointIDs ?? []).every((id) => validPoints.has(id))) return false;
    if (!(entry.selector.aspectIDs ?? []).every((id) => validAspects.has(id))) return false;
    const tags = new Set(entry.selector.requiredTags ?? []);
    return archetypes.some((archetype) => isSubset(tags, archetype));
  });

  const acceptedByID = new Map(accepted.map((entry) => [entry.id, entry]));
  const merged = existing.map((entry) => acceptedByID.get(entry.id) ?? entry);
  const existingIDs = new Set(existing.map((entry) => entry.id));
  merged.push(...accepted.filter((entry) => !existingIDs.has(entry.id)));
  console.log(
    `Accepted ${accepted.length} of ${(candidate.entries ?? []).length} candidate natal entries.`
  );
  return merged;
}

function isSubset(candidate, source) {
  return [...candidate].every((value) => source.has(value));
}

function readJSON(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function writeJSON(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function parseArguments(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 1) {
    const key = values[index];
    if (!key.startsWith("--")) {
      throw new Error(`Unexpected argument: ${key}`);
    }
    const value = values[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for ${key}`);
    }
    result[key.slice(2)] = value;
    index += 1;
  }
  return result;
}
