#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const appDir = path.join(root, "ios", "App");
const translationPath = path.join(root, "ios", "Localization", "ui-translations.json");
const outputPath = path.join(appDir, "Localizable.xcstrings");
const validateOnly = process.argv.includes("--validate");
const termKeys = {
  bodies: ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto", "trueNode"],
  zodiac: ["aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"],
  aspects: ["conjunction", "sextile", "square", "trine", "opposition"],
  aspectPhases: ["applying", "exact", "separating"],
  motions: ["direct", "retrograde", "stationary"],
  elements: ["fire", "earth", "air", "water"],
  modalities: ["cardinal", "fixed", "mutable"],
  angles: ["ascendant", "descendant", "midheaven", "imumCoeli"],
  moonPhases: ["new-moon", "waxing-crescent", "first-quarter", "waxing-gibbous", "full-moon", "waning-gibbous", "last-quarter", "waning-crescent"],
  chartKinds: ["natal", "currentSky", "transit", "secondary", "solarReturn", "synastry"],
  formats: ["house"],
};

for (const locale of ["en", "zh-Hans", "es", "fr"]) {
  const termPath = path.join(appDir, "Resources", `AstroTerms-${locale}.json`);
  const catalog = JSON.parse(fs.readFileSync(termPath, "utf8"));
  if (catalog.version !== 1 || catalog.locale !== locale) throw new Error(`Invalid AstroTerms header: ${locale}`);
  const actualCategories = Object.keys(catalog).filter((key) => !["version", "locale"].includes(key)).sort();
  const expectedCategories = Object.keys(termKeys).sort();
  if (JSON.stringify(actualCategories) !== JSON.stringify(expectedCategories)) {
    throw new Error(`AstroTerms category mismatch: ${locale}`);
  }
  for (const [category, expectedKeys] of Object.entries(termKeys)) {
    const values = catalog[category];
    const actualKeys = values && typeof values === "object" ? Object.keys(values).sort() : [];
    if (JSON.stringify(actualKeys) !== JSON.stringify([...expectedKeys].sort())) {
      throw new Error(`AstroTerms ${category} keys mismatch: ${locale}`);
    }
    if (Object.values(values).some((value) => typeof value !== "string" || !value.trim())) {
      throw new Error(`AstroTerms ${category} contains an empty/non-string value: ${locale}`);
    }
  }
}

const swiftFiles = fs.readdirSync(appDir)
  .filter((name) => name.endsWith(".swift"))
  .map((name) => path.join(appDir, name));
const translations = JSON.parse(fs.readFileSync(translationPath, "utf8"));
const pattern = /localized\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"/gs;
const keyedPattern = /localized\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*default:\s*"((?:[^"\\]|\\.)*)"\s*,\s*chinese:\s*"((?:[^"\\]|\\.)*)"/gs;

function decodeSwiftLiteral(value) {
  return value
    .replaceAll("\\\"", "\"")
    .replaceAll("\\n", "\n")
    .replaceAll("\\t", "\t")
    .replaceAll("\\\\", "\\");
}

const candidates = new Map();
const conflicts = new Set();
for (const file of swiftFiles) {
  const source = fs.readFileSync(file, "utf8");
  for (const match of source.matchAll(pattern)) {
    if (match[1].includes("\\(") || match[2].includes("\\(")) continue;
    const english = decodeSwiftLiteral(match[1]);
    const chinese = decodeSwiftLiteral(match[2]);
    if (candidates.has(english) && candidates.get(english).chinese !== chinese) {
      conflicts.add(english);
      continue;
    }
    candidates.set(english, { english, chinese });
  }
  for (const match of source.matchAll(keyedPattern)) {
    if (match[1].includes("\\(") || match[2].includes("\\(") || match[3].includes("\\(")) continue;
    const key = decodeSwiftLiteral(match[1]);
    const english = decodeSwiftLiteral(match[2]);
    const chinese = decodeSwiftLiteral(match[3]);
    if (candidates.has(key)) throw new Error(`Duplicate localization key: ${key}`);
    candidates.set(key, { english, chinese });
  }
}
for (const key of conflicts) candidates.delete(key);

const strings = {};
for (const [key, { english, chinese }] of [...candidates].sort(([a], [b]) => a.localeCompare(b))) {
  const localizations = {
    en: { stringUnit: { state: "translated", value: english } },
    "zh-Hans": { stringUnit: { state: "translated", value: chinese } },
  };
  const extra = translations[key] ?? translations[english];
  if (extra?.es) localizations.es = { stringUnit: { state: "translated", value: extra.es } };
  if (extra?.fr) localizations.fr = { stringUnit: { state: "translated", value: extra.fr } };
  strings[key] = { extractionState: "manual", localizations };
}

const catalog = { sourceLanguage: "en", strings, version: "1.0" };
const serialized = `${JSON.stringify(catalog, null, 2)}\n`;

if (validateOnly) {
  if (!fs.existsSync(outputPath)) throw new Error(`Missing ${path.relative(root, outputPath)}`);
  const current = fs.readFileSync(outputPath, "utf8");
  if (current !== serialized) throw new Error("Localizable.xcstrings is stale; run npm run ios:localization:build");
} else {
  fs.writeFileSync(outputPath, serialized);
}

const stats = {
  fixedStrings: candidates.size,
  ambiguousLegacyKeys: conflicts.size,
  spanishStrings: Object.values(translations).filter((item) => item.es).length,
  frenchStrings: Object.values(translations).filter((item) => item.fr).length,
};
process.stdout.write(`${JSON.stringify(stats)}\n`);
