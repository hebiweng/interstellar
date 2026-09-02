#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceRoot = path.join(root, "ios", "PrivateContent");
const defaultOutput = path.join(root, "ios", "App", "Resources", "PrivateContent");
const copyCatalogBuilder = path.join(root, "scripts", "build-ios-copy-catalog.mjs");
const localeOrder = ["en", "zh-Hans", "es", "fr", "de", "it", "pt-BR", "tr", "ko"];

function fail(message) {
  console.error(`Private content error: ${message}`);
  process.exit(1);
}

function parseArguments(values) {
  let command;
  let output = defaultOutput;
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (value === "--build" || value === "--validate") {
      if (command) fail("Choose exactly one of --build or --validate");
      command = value;
    } else if (value === "--output") {
      const next = values[index + 1];
      if (!next) fail("--output requires a directory");
      output = path.resolve(next);
      index += 1;
    } else {
      fail(`Unknown argument: ${value}`);
    }
  }
  if (!command) fail("Usage: build-ios-private-content.mjs --build|--validate [--output <dir>]");
  return { command, output };
}

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function placeholderNames(value) {
  return [...new Set([...String(value).matchAll(/\{\{([A-Za-z][A-Za-z0-9]*)\}\}/g)].map((match) => match[1]))].sort();
}

function validateAreaPack(file, area, locale, referenceKeys) {
  const pack = readJSON(file);
  if (pack.schemaVersion !== 1) throw new Error(`${file}: schemaVersion must be 1`);
  if (pack.area !== area) throw new Error(`${file}: area must be ${area}`);
  if (pack.locale !== locale) throw new Error(`${file}: locale must be ${locale}`);
  if (!Array.isArray(pack.entries) || pack.entries.length === 0) throw new Error(`${file}: entries must be non-empty`);
  const keys = new Set();
  for (const entry of pack.entries) {
    if (!entry.contentKey || keys.has(entry.contentKey)) throw new Error(`${file}: duplicate or empty contentKey ${entry.contentKey}`);
    if (entry.translationStatus !== "approved") throw new Error(`${file}: ${entry.contentKey} is not approved`);
    keys.add(entry.contentKey);
  }
  if (referenceKeys && (keys.size !== referenceKeys.size || [...referenceKeys].some((key) => !keys.has(key)))) {
    throw new Error(`${file}: contentKey coverage differs from English authoritative pack`);
  }
  return pack;
}

function validatePlaceholderParity(reference, target, file) {
  const targetByKey = new Map(target.entries.map((entry) => [entry.contentKey, entry]));
  for (const sourceEntry of reference.entries) {
    const translated = targetByKey.get(sourceEntry.contentKey);
    for (const field of ["summary", "detail"]) {
      const expected = placeholderNames(sourceEntry[field]);
      const actual = placeholderNames(translated?.[field]);
      if (JSON.stringify(expected) !== JSON.stringify(actual)) {
        throw new Error(`${file}: placeholder mismatch ${sourceEntry.contentKey}.${field}`);
      }
    }
  }
}

function processArea(area, output, write) {
  const directory = path.join(sourceRoot, area);
  if (!fs.existsSync(directory)) return [];
  const englishFile = path.join(directory, "Content-en.json");
  if (!fs.existsSync(englishFile)) throw new Error(`${area}: missing Content-en.json`);
  const english = validateAreaPack(englishFile, area, "en");
  const englishKeys = new Set(english.entries.map((entry) => entry.contentKey));
  const generated = [];
  for (const locale of localeOrder) {
    const source = path.join(directory, `Content-${locale}.json`);
    if (!fs.existsSync(source)) continue;
    const pack = validateAreaPack(source, area, locale, englishKeys);
    validatePlaceholderParity(english, pack, source);
    const destination = path.join(output, `PrivateContent-${area}-${locale}.json`);
    if (write) fs.copyFileSync(source, destination);
    generated.push(destination);
  }
  return generated;
}

function processChartCatalogs(output, write) {
  const directory = path.join(sourceRoot, "copy-catalog-v2");
  if (!fs.existsSync(directory)) return [];
  const generated = [];
  for (const locale of localeOrder) {
    const source = path.join(directory, `Interstellar_Copy_Catalog_${locale}_v2_three-layers.json`);
    if (!fs.existsSync(source)) continue;
    const destination = path.join(output, `CopyCatalog-${locale}.json`);
    const validationDestination = write ? destination : path.join(output, `.validate-CopyCatalog-${locale}.json`);
    execFileSync(process.execPath, [
      copyCatalogBuilder,
      "--input", source,
      "--output", validationDestination,
    ], { stdio: "pipe" });
    execFileSync(process.execPath, [
      copyCatalogBuilder,
      "--validate-runtime", validationDestination,
    ], { stdio: "pipe" });
    if (!write) fs.rmSync(validationDestination, { force: true });
    generated.push(destination);
  }
  return generated;
}

const { command, output } = parseArguments(process.argv.slice(2));
try {
  fs.mkdirSync(output, { recursive: true });
  if (command === "--build") {
    for (const file of fs.readdirSync(output)) {
      if (/^(PrivateContent-(today|week|ask)-|CopyCatalog-).*\.json$/.test(file)) {
        fs.rmSync(path.join(output, file));
      }
    }
  }
  const write = command === "--build";
  const generated = [
    ...processArea("today", output, write),
    ...processArea("week", output, write),
    ...processArea("ask", output, write),
    ...processChartCatalogs(output, write),
  ];
  console.log(JSON.stringify({ valid: true, generated: generated.length, output }));
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
