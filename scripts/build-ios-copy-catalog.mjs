#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = parseArguments(process.argv.slice(2));

const v2Locales = ["en", "zh-Hans", "es", "fr"];
const sourceRoots = ["shared", "modern", "classical"];
const expectedTechniques = {
  natal: ["natal-interpretation", "emotional-needs", "love-connection", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"],
  "current-sky": ["sky-overview", "moon-now", "aspect-pattern", "planetary-motion", "sign-changes", "element-climate", "upcoming-7-days"],
  transit: ["current-story", "current-cycles", "transit-timeline", "planet-paths", "life-areas", "active-transits"],
  secondary: ["developmental-chapter", "progressed-moon", "identity-development", "turning-points", "areas-maturing", "timeline"],
  "solar-return": ["year-theme", "year-anchors", "priority-areas", "year-dynamics", "year-timeline", "natal-overlay", "year-aspects"],
  synastry: ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"],
  today: ["current-chapter", "active-today", "coming-next", "moon-today", "today-timeline", "upcoming-sky-events", "retrogrades"],
};

if (args["validate-runtime"]) {
  const runtimePath = path.resolve(args["validate-runtime"]);
  const runtimePack = readJSON(runtimePath, "runtime copy catalog");
  validateRuntimePack(runtimePack);
  console.log(`Validated ${path.relative(repositoryRoot, runtimePath)} (${runtimePack.contracts.length} contracts, ${runtimePack.entries.length} entries)`);
  process.exit(0);
}

const inputPath = path.resolve(args.input ?? "");
const outputPath = path.resolve(args.output ?? "");
const trustApproved = Boolean(args["trust-approved"]);

if (!inputPath || !outputPath) fail("--input and --output are required");
const source = readJSON(inputPath, "source copy catalog");
validateSourceEnvelope(source, trustApproved);
const runtimePack = buildRuntimePack(source);

validateRuntimePack(runtimePack);
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(runtimePack, null, 2)}\n`);
console.log(`Built ${path.relative(repositoryRoot, outputPath)}`);
console.log(`${runtimePack.contracts.length} contracts, ${runtimePack.entries.length} copy entries, ${runtimePack.themeRulesByPreset.modern.length} modern theme rules, ${runtimePack.themeRulesByPreset.classical.length} classical theme rules`);

function validateSourceEnvelope(value, bypassReview) {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail("Catalog must be an object");
  if (!value.version || !v2Locales.includes(value.locale)) fail("Catalog version or locale is invalid");
  if (!bypassReview && value.status !== "approved") fail(`Catalog ${value.locale} is not approved`);
  for (const key of sourceRoots) {
    if (!value[key] || typeof value[key] !== "object") fail(`Catalog is missing ${key}`);
  }
  if (!value.contracts || typeof value.contracts !== "object") fail("Catalog is missing contracts");
}

function buildRuntimePack(source) {
  return {
    schemaVersion: 2,
    contentVersion: source.version,
    locale: source.locale,
    status: source.status === "approved" ? "approved" : "needs-fix",
    contracts: normalizeContracts(source.contracts),
    entries: flattenCopyEntries(source),
    themeRulesByPreset: normalizeThemeRulesByPreset(source),
  };
}

function normalizeContracts(sourceContracts) {
  const contracts = [];
  for (const [technique, cardIDs] of Object.entries(expectedTechniques)) {
    const techniqueContracts = sourceContracts?.[technique];
    if (!techniqueContracts || typeof techniqueContracts !== "object") fail(`Missing contracts.${technique}`);
    const unknown = Object.keys(techniqueContracts).filter((cardID) => !cardIDs.includes(cardID));
    if (unknown.length) fail(`Unknown ${technique} card contracts: ${unknown.join(", ")}`);
    for (const cardID of cardIDs) {
      const contract = techniqueContracts[cardID];
      if (!contract) fail(`Missing contract ${technique}.${cardID}`);
      const evidenceByPreset = {};
      const copySourceByPreset = {};
      for (const preset of ["modern", "classical"]) {
        if (contract.evidenceByPreset?.[preset]) {
          evidenceByPreset[preset] = uniqueStrings(
            [...(Array.isArray(contract.evidenceByPreset[preset]) ? contract.evidenceByPreset[preset] : [])],
            `${technique}.${cardID}.evidenceByPreset.${preset}`,
          );
        }
        if (contract.copySourceByPreset?.[preset]) {
          copySourceByPreset[preset] = uniqueStrings(
            String(contract.copySourceByPreset[preset]).split("+").filter(Boolean).map((s) => normalizeCopySource(s, technique)),
            `${technique}.${cardID}.copySourceByPreset.${preset}`,
          );
        }
      }
      if (Object.keys(evidenceByPreset).length === 0) fail(`${technique}.${cardID} has no evidenceByPreset`);
      if (Object.keys(copySourceByPreset).length === 0) fail(`${technique}.${cardID} has no copySourceByPreset`);
      contracts.push({
        id: `${technique}.${cardID}`,
        technique,
        cardID,
        selector: `${technique}.${cardID}.v2`,
        facts: uniqueStringsAllowEmpty(
          [...(Array.isArray(contract.facts) ? contract.facts : [])],
          `${technique}.${cardID}.facts`,
        ),
        evidenceByPreset,
        textFields: uniqueStrings(contract.textFields, `${technique}.${cardID}.textFields`),
        copySourceByPreset,
      });
    }
  }
  return contracts;
}

function normalizeCopySource(sourceName, technique) {
  if (sourceName === "themePacks" || sourceName.startsWith("themePacks.")) return "shared.transit.themePacks";
  if (sourceName === "shared.transit.themePacks" || sourceName.startsWith("shared.transit.themePacks.")) return "shared.transit.themePacks";
  return sourceName;
}

function flattenCopyEntries(sourceCatalog) {
  const result = [];
  for (const root of sourceRoots) visit(sourceCatalog[root], [root], result, sourceCatalog.locale);
  const seen = new Set();
  for (const entry of result) {
    if (seen.has(entry.sourcePath)) fail(`Duplicate copy sourcePath ${entry.sourcePath}`);
    seen.add(entry.sourcePath);
  }
  return result;
}

function visit(value, segments, output, locale) {
  if (segments.at(-1) === "themeRules") return;
  if (typeof value === "string") {
    if (!value.trim() || segments.at(-1) === "status") return;
    const sourcePath = segments.join(".");
    if (sourcePath.startsWith("shared.transit.themeRules.")) return;
    const kind = sourcePath.startsWith("shared.technical.templates.") ? "technical" : "consumer";
    const variables = declaredVariables(value);
    const maximum = kind === "technical" ? 3 : 2;
    if (variables.length > maximum) fail(`${sourcePath} declares ${variables.length} variables; ${kind} maximum is ${maximum}`);
    output.push({
      id: `copy.${segments.map(normalizeIDSegment).join(".")}`,
      locale,
      status: "approved",
      kind,
      sourcePath,
      value,
      variables,
    });
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => visit(item, [...segments, String(index + 1).padStart(3, "0")], output, locale));
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const key of Object.keys(value).sort()) visit(value[key], [...segments, key], output, locale);
}

function declaredVariables(template) {
  const names = [...template.matchAll(/\{\{([A-Za-z][A-Za-z0-9]*)\}\}/g)].map((match) => match[1]);
  const invalid = template.replace(/\{\{[A-Za-z][A-Za-z0-9]*\}\}/g, "").match(/\{\{|\}\}/);
  if (invalid) fail(`Invalid or unresolved variable syntax in ${template}`);
  return [...new Set(names)].map((name) => ({ name, type: variableType(name) }));
}

function variableType(name) {
  const types = {
    planet: "body", first: "body", second: "body", sign: "sign", houseLabel: "house",
    aspect: "aspect", phase: "phase", intensity: "intensity", orb: "intensity",
    percent: "percentage", count: "count", date: "date", day: "date", start: "date",
    end: "date", time: "time", duration: "duration",
  };
  if (!types[name]) fail(`Unknown template variable ${name}`);
  return types[name];
}

function normalizeThemeRulesByPreset(sourceCatalog) {
  const result = { modern: [], classical: [] };
  for (const preset of ["modern", "classical"]) {
    const rules = sourceCatalog[preset]?.transit?.themeRules;
    if (!Array.isArray(rules)) fail(`${preset}.transit.themeRules must be an array`);
    result[preset] = rules.map((rule, index) => {
      if (!Array.isArray(rule.pair) || rule.pair.length !== 2) fail(`Invalid theme rule at ${preset}.${index}`);
      return {
        id: `theme-rule.${String(index + 1).padStart(3, "0")}`,
        pair: rule.pair.map(String),
        tone: rule.tone,
        themeID: rule.themeID,
      };
    });
  }
  return result;
}

function validateRuntimePack(pack) {
  const schemaPath = path.join(repositoryRoot, "ios", "ContentSchema", "copy-catalog.schema.json");
  const schema = readJSON(schemaPath, "copy catalog schema");
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  const validate = ajv.compile(schema);
  if (!validate(pack)) fail(`Schema validation failed:\n${ajv.errorsText(validate.errors, { separator: "\n" })}`);
  if (pack.status !== "approved") fail("Catalog status is not approved");
  assertUnique(pack.contracts.map((item) => item.id), "contract ID");
  assertUnique(pack.contracts.map((item) => item.selector), "selector");
  assertUnique(pack.entries.map((item) => item.id), "copy ID");
  assertUnique(pack.entries.map((item) => item.sourcePath), "copy sourcePath");
  const expectedContractIDs = new Set(
    Object.entries(expectedTechniques).flatMap(([technique, cardIDs]) => cardIDs.map((cardID) => `${technique}.${cardID}`)),
  );
  const actualContractIDs = new Set(pack.contracts.map((item) => item.id));
  if (expectedContractIDs.size !== actualContractIDs.size || [...expectedContractIDs].some((id) => !actualContractIDs.has(id))) {
    fail("Catalog does not contain the exact 51 chart and Today contracts");
  }
  for (const contract of pack.contracts) {
    if (contract.selector !== `${contract.technique}.${contract.cardID}.v2`) {
      fail(`Illegal selector ${contract.selector}`);
    }
    if (contract.id !== `${contract.technique}.${contract.cardID}`) {
      fail(`Contract ID does not match technique/cardID: ${contract.id}`);
    }
  }
  for (const entry of pack.entries) {
    if (entry.locale !== pack.locale) fail(`Copy ${entry.id} locale does not match catalog locale`);
    if (entry.status !== "approved") fail(`Copy ${entry.id} is not approved`);
    const declaredNames = entry.variables.map((item) => item.name);
    assertUnique(declaredNames, `variable declaration in ${entry.id}`);
    const actualVariables = declaredVariables(entry.value);
    const actualNames = actualVariables.map((item) => item.name).sort();
    if (declaredNames.slice().sort().join("|") !== actualNames.join("|")) {
      fail(`Copy ${entry.id} variable declarations do not match its placeholders`);
    }
    for (const variable of entry.variables) {
      if (variable.type !== variableType(variable.name)) {
        fail(`Copy ${entry.id} has an invalid strong type for ${variable.name}`);
      }
    }
    const maximum = entry.kind === "technical" ? 3 : 2;
    if (entry.variables.length > maximum) fail(`Copy ${entry.id} exceeds its ${entry.kind} variable limit`);
  }
  const entryPaths = new Set(pack.entries.map((entry) => entry.sourcePath));
  for (const contract of pack.contracts) {
    for (const [preset, sources] of Object.entries(contract.copySourceByPreset)) {
      for (const sourceName of sources) {
        if (![...entryPaths].some((entryPath) => entryPath.startsWith(sourceName))) {
          fail(`Contract ${contract.id} preset ${preset} references missing copy source ${sourceName}`);
        }
      }
    }
  }
}

function uniqueStringsAllowEmpty(value, label) {
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string" || !item.trim())) fail(`${label} must be a string array`);
  const unique = [...new Set(value)];
  if (unique.length !== value.length) fail(`${label} contains duplicates`);
  return unique;
}

function uniqueStrings(value, label) {
  if (!Array.isArray(value) || !value.length || value.some((item) => typeof item !== "string" || !item.trim())) fail(`${label} must be a non-empty string array`);
  const unique = [...new Set(value)];
  if (unique.length !== value.length) fail(`${label} contains duplicates`);
  return unique;
}

function normalizeIDSegment(value) {
  return String(value).replace(/([a-z0-9])([A-Z])/g, "$1-$2").replace(/_/g, "-").toLowerCase();
}

function assertUnique(values, label) {
  const seen = new Set();
  for (const value of values) {
    if (seen.has(value)) fail(`Duplicate ${label}: ${value}`);
    seen.add(value);
  }
}

function parseArguments(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index += 1) {
    const argument = values[index];
    if (!argument.startsWith("--")) fail(`Unexpected argument ${argument}`);
    const key = argument.slice(2);
    if (key === "trust-approved") { parsed[key] = true; continue; }
    const value = values[index + 1];
    if (!value || value.startsWith("--")) fail(`Missing value for ${argument}`);
    parsed[key] = value;
    index += 1;
  }
  return parsed;
}

function readJSON(filePath, label) {
  try { return JSON.parse(fs.readFileSync(filePath, "utf8")); }
  catch (error) { fail(`Cannot read ${label}: ${error.message}`); }
}

function fail(message) {
  console.error(`Copy catalog error: ${message}`);
  process.exit(1);
}
