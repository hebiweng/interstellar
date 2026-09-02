#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const packageDirectory = path.resolve(process.argv[2] ?? "");
const dryRun = process.argv.includes("--dry-run");
const presets = ["modern", "classical"];
const locales = ["en", "zh-Hans", "es", "fr"];
const privateDirectory = path.join(root, "ios", "PrivateContent", "copy-catalog-v2");

if (!packageDirectory || !fs.statSync(packageDirectory, { throwIfNoEntry: false })?.isDirectory()) {
  fail("Usage: node scripts/import-synastry-fact-copy-v4.mjs <extracted-package-directory> [--dry-run]");
}

const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const registries = {};
const patches = {};
const summaries = [];

for (const preset of presets) {
  const artifactDirectory = path.join(root, "artifacts", `${preset}-synastry-fact-copy-v4`);
  const registry = read(path.join(artifactDirectory, `${preset}-synastry-copy-registry.json`));
  const bilingual = read(path.join(packageDirectory, `${preset}-synastry-fact-copy-bilingual.json`));
  const validation = read(path.join(packageDirectory, `${preset}-synastry-fact-copy-validation.json`));
  const en = read(path.join(packageDirectory, `${preset}-synastry-fact-copy-en.patch.json`));
  const zh = read(path.join(packageDirectory, `${preset}-synastry-fact-copy-zh-Hans.patch.json`));

  validateDelivery(preset, registry, bilingual, validation, en, zh);
  registries[preset] = registry;
  patches[preset] = { en, "zh-Hans": zh };
  summaries.push(copyLengthSummary(preset, en, zh));
}

if (!dryRun) {
  for (const locale of locales) {
    const sourceFile = path.join(privateDirectory, `Interstellar_Copy_Catalog_${locale}_v2_three-layers.json`);
    const source = read(sourceFile);
    const localePatches = locale === "zh-Hans" ? "zh-Hans" : "en";
    for (const preset of presets) {
      for (const [baseKey, fields] of Object.entries(patches[preset][localePatches])) {
        setPath(source, [...baseKey.split("."), "interpretation"], fields.interpretation);
      }
    }
    source.version = catalogVersionForV4(source.version);
    fs.writeFileSync(sourceFile, `${JSON.stringify(source, null, 2)}\n`);
  }

  for (const preset of presets) updatePublicValidationArtifacts(preset, registries[preset]);
  writePrivateReceipt();
}

console.log(JSON.stringify({
  validated: true,
  dryRun,
  entries: Object.fromEntries(presets.map((preset) => [preset, registries[preset].entryCount])),
  localePolicy: { en: "en", "zh-Hans": "zh-Hans", es: "reviewed-en-fallback", fr: "reviewed-en-fallback" },
  lengthAdvisories: summaries,
}, null, 2));

function validateDelivery(preset, registry, bilingual, validation, en, zh) {
  const expectedChartID = `${preset}.synastry`;
  if (registry.chartID !== expectedChartID || registry.cardStructureRevision !== "synastry-fact-copy-v4") {
    fail(`${preset} Registry does not describe Synastry fact copy v4`);
  }
  if (bilingual.chartID !== expectedChartID || bilingual.cardStructureRevision !== "synastry-fact-copy-v4") {
    fail(`${preset} bilingual envelope is invalid`);
  }
  if (bilingual.editorialPolicy?.runtimeBoundary !== "Calculated labels and values stay UI-owned; copy interprets only the declared fact pattern.") {
    fail(`${preset} bilingual runtime boundary changed`);
  }
  if (bilingual.entryCount !== registry.entryCount || bilingual.entries?.length !== registry.entryCount) {
    fail(`${preset} bilingual entry count differs from Registry`);
  }
  if (validation.chartID !== expectedChartID || validation.passed !== true) {
    fail(`${preset} delivery static validation did not pass`);
  }

  const expected = new Map(registry.entries.map((entry) => [entry.key, entry]));
  validatePatch(preset, "en", en, expected);
  validatePatch(preset, "zh-Hans", zh, expected);
  const bilingualByKey = new Map(bilingual.entries.map((entry) => [entry.key, entry]));
  if (bilingualByKey.size !== expected.size) fail(`${preset} bilingual keys are not unique`);
  for (const key of expected.keys()) {
    const entry = bilingualByKey.get(key);
    if (!entry || entry.editorialStatus !== "approved") fail(`${key} is not editorially approved`);
    if (entry.en?.interpretation !== en[key].interpretation || entry["zh-Hans"]?.interpretation !== zh[key].interpretation) {
      fail(`${key} patch does not match bilingual delivery`);
    }
  }
}

function validatePatch(preset, locale, patch, expected) {
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) fail(`${preset} ${locale} patch must be an object`);
  const keys = Object.keys(patch).sort();
  if (keys.length !== expected.size || keys.some((key) => !expected.has(key))) {
    fail(`${preset} ${locale} patch key set differs from Registry`);
  }
  const values = new Set();
  for (const key of keys) {
    const fields = patch[key];
    if (!fields || Object.keys(fields).join("|") !== "interpretation") fail(`${key} must contain only interpretation`);
    const value = fields.interpretation;
    if (typeof value !== "string" || !value.trim()) fail(`${key} has empty interpretation`);
    if (/\{\{|\}\}/.test(value)) fail(`${key} must not contain placeholders`);
    if (values.has(value)) fail(`${preset} ${locale} contains duplicate full interpretations`);
    values.add(value);
    const prohibited = locale === "en"
      ? /\b(always|guarantee[ds]?|destin(?:y|ed)|inevitabl(?:e|y)|will)\b/i
      : /(注定|保证|必然|永远|一定会)/;
    if (prohibited.test(value)) fail(`${key} contains deterministic language`);
  }
}

function copyLengthSummary(preset, en, zh) {
  const englishWords = Object.values(en).map(({ interpretation }) => interpretation.trim().split(/\s+/).length);
  const chineseCharacters = Object.values(zh).map(({ interpretation }) => (
    [...interpretation.replace(/[\s，。；、：！？“”‘’（）—·]/g, "")].length
  ));
  return {
    preset,
    englishOver28Words: englishWords.filter((count) => count > 28).length,
    simplifiedChineseOver42Characters: chineseCharacters.filter((count) => count > 42).length,
  };
}

function updatePublicValidationArtifacts(preset, registry) {
  const directory = path.join(root, "artifacts", `${preset}-synastry-fact-copy-v4`);
  const base = path.join(directory, `${preset}-synastry`);
  const requirementsFile = `${base}-copy-requirements.json`;
  const requirements = read(requirementsFile);
  requirements.missingCount = 0;
  requirements.structuralRequirements.status = "approved";
  requirements.requirements = requirements.requirements.map((entry) => ({
    ...entry,
    catalogStatus: "approved-private-runtime",
    missingLocales: [],
  }));
  fs.writeFileSync(requirementsFile, `${JSON.stringify(requirements, null, 2)}\n`);

  const missingFile = `${base}-missing-copy.json`;
  const missing = read(missingFile);
  missing.missingCount = 0;
  missing.missing = [];
  fs.writeFileSync(missingFile, `${JSON.stringify(missing, null, 2)}\n`);

  const validationFile = `${base}-validation.json`;
  const validation = read(validationFile);
  validation.missingCopyCount = 0;
  validation.passed = true;
  validation.blockingReason = null;
  validation.privateRuntimeEntryCount = registry.entryCount;
  validation.localePolicy = { en: "reviewed", "zh-Hans": "reviewed", es: "reviewed-en-fallback", fr: "reviewed-en-fallback" };
  validation.runtimeCoveragePolicy = "Use reviewed v4 exact fact copy when present; otherwise use the declared reviewed shared planet-role or house-overlay selector.";
  fs.writeFileSync(validationFile, `${JSON.stringify(validation, null, 2)}\n`);
}

function writePrivateReceipt() {
  const files = fs.readdirSync(packageDirectory).filter((name) => name.endsWith(".json")).sort();
  const receipt = {
    schemaVersion: 1,
    importedAt: new Date().toISOString(),
    sourcePackage: path.basename(packageDirectory),
    files: files.map((name) => ({
      name,
      sha256: crypto.createHash("sha256").update(fs.readFileSync(path.join(packageDirectory, name))).digest("hex"),
    })),
  };
  fs.writeFileSync(path.join(privateDirectory, "synastry-fact-copy-v4-import-receipt.json"), `${JSON.stringify(receipt, null, 2)}\n`);
}

function setPath(target, segments, value) {
  let cursor = target;
  for (const segment of segments.slice(0, -1)) {
    if (!cursor[segment] || typeof cursor[segment] !== "object" || Array.isArray(cursor[segment])) cursor[segment] = {};
    cursor = cursor[segment];
  }
  cursor[segments.at(-1)] = value;
}

function catalogVersionForV4(version) {
  const match = String(version).match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) fail(`Invalid catalog version ${version}`);
  const current = Number(match[1]) * 1_000_000 + Number(match[2]) * 1_000 + Number(match[3]);
  if (current >= 2_000_002) return version;
  return "2.0.2";
}

function fail(message) {
  console.error(`Synastry fact copy import error: ${message}`);
  process.exit(1);
}
