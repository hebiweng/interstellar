#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const options = parseArguments(process.argv.slice(2));
const locale = options.locale;
const version = options.version;

if (!["en", "zh-Hans"].includes(locale)) {
  fail("--locale must be en or zh-Hans");
}
if (!version) {
  fail("--version is required");
}

const entries = ["today", "week", "ask"].flatMap((area) => {
  const filePath = path.join(
    root,
    "ios",
    "PrivateContent",
    area,
    `Content-${locale}.json`
  );
  if (!fs.existsSync(filePath)) {
    fail(`Missing private consumer content: ${path.relative(root, filePath)}`);
  }
  return readJSON(filePath).entries ?? [];
});

validate(entries);
const accepted = entries.filter((entry) => entry.translationStatus === "approved");
if (accepted.length !== entries.length) {
  fail(`${entries.length - accepted.length} entries are not approved`);
}
validateRequiredKeys(new Set(accepted.map((entry) => entry.contentKey)));

const outputPath = path.join(
  root,
  "ios",
  "App",
  "Resources",
  `PrivateContent-${locale}.json`
);
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(
  outputPath,
  `${JSON.stringify({ version, locale, entries: accepted }, null, 2)}\n`
);
console.log(`Built ${path.relative(root, outputPath)} with ${accepted.length} approved entries.`);

function validate(entriesToValidate) {
  const ids = new Set();
  for (const entry of entriesToValidate) {
    if (!entry.contentKey || ids.has(entry.contentKey)) {
      fail(`Duplicate or missing content key: ${entry.contentKey ?? "<missing>"}`);
    }
    ids.add(entry.contentKey);
    if (!entry.summary?.trim() || !entry.detail?.trim()) {
      fail(`Missing summary/detail for ${entry.contentKey}`);
    }
    if (!entry.sourceRevision?.trim()) {
      fail(`Missing source revision for ${entry.contentKey}`);
    }
    for (const text of [entry.summary, entry.detail]) {
      if (/(\b\w+\b)(?:\s+\1){1,}/iu.test(text)) {
        fail(`Repeated adjacent phrase in ${entry.contentKey}`);
      }
      if (/\{\{[^}]+\}\}/.test(text)) {
        const allowed = [
          "first", "second", "theme", "style", "area",
          "choice", "option", "probability", "date", "score",
        ];
        const placeholders = [...text.matchAll(/\{\{([^}]+)\}\}/g)].map((match) => match[1]);
        for (const placeholder of placeholders) {
          if (!allowed.includes(placeholder)) {
            fail(`Unknown placeholder {{${placeholder}}} in ${entry.contentKey}`);
          }
        }
      }
    }
  }
}

function validateRequiredKeys(keys) {
  const required = [];
  for (const domain of ["love", "work", "money", "energy"]) {
    for (const tone of ["supportive", "challenging", "transition", "neutral"]) {
      required.push(`today.domain.${domain}.${tone}`);
      required.push(`week.domain.${domain}.${tone}`);
    }
  }
  for (const source of ["sky", "transit", "secondary"]) {
    for (const tone of ["supportive", "challenging", "transition", "neutral"]) {
      required.push(`today.rhythm.${source}.${tone}`);
    }
  }
  required.push(
    "week.peak.ahead",
    "week.peak.current",
    "week.peak.passed",
    "today.event.connection.peak",
    "today.event.connection.building",
    "today.event.connection.easing",
    "today.event.style.change",
    "today.event.area.change",
    "today.event.motion.review",
    "today.event.motion.forward"
  );
  const missing = required.filter((key) => !keys.has(key));
  if (missing.length > 0) {
    fail(`Missing required consumer content: ${missing.join(", ")}`);
  }
}

function parseArguments(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 1) {
    const key = values[index];
    const value = values[index + 1];
    if (!key.startsWith("--") || !value || value.startsWith("--")) {
      fail(`Invalid argument near ${key}`);
    }
    result[key.slice(2)] = value;
    index += 1;
  }
  return result;
}

function readJSON(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
