#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const argumentsMap = parseArguments(process.argv.slice(2));
const locale = argumentsMap.locale;
const contentVersion = argumentsMap.version;

if (!["en", "zh-Hans"].includes(locale)) {
  fail("--locale must be en or zh-Hans");
}
if (!contentVersion) {
  fail("--version is required");
}

const contractsPath = path.join(repositoryRoot, "ios", "ContentSchema", "card-contracts.json");
const outputPath = path.join(
  repositoryRoot,
  "ios",
  "App",
  "Resources",
  `PrivateCorpus-${locale}.json`,
);

const corpus = readPrivateFragments(
  path.join(repositoryRoot, "ios", "PrivateContent"),
  "Corpus",
  "entries"
);
const rules = readPrivateFragments(
  path.join(repositoryRoot, "ios", "PrivateRules"),
  "Composition",
  "rules"
);
const contracts = readJSON(contractsPath, "card contracts");
const sourceEntries = corpus.entries ?? [];
const entries = sourceEntries.map(consumerizeEntry);
const compositionRules = (rules.rules ?? []).map(consumerizeRule);

validateEntries(entries, locale);
validateRules(compositionRules, locale, contracts.cards);
validateTranslationParity(entries, locale);

const acceptedStatuses = new Set([
  "approved",
  ...(argumentsMap["include-sample"] ? ["sample"] : []),
]);
const approvedEntries = entries.filter((entry) => acceptedStatuses.has(entry.status));
if (approvedEntries.length === 0) {
  fail(`No approved ${locale} corpus entries are available`);
}
validateRuleCorpusCoverage(compositionRules, approvedEntries);

const pack = {
  schemaVersion: 1,
  contentVersion,
  locale,
  entries: approvedEntries,
  rules: compositionRules,
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(pack, null, 2)}\n`);
console.log(`Built ${path.relative(repositoryRoot, outputPath)}`);
console.log(`${approvedEntries.length} accepted entries, ${compositionRules.length} card rules`);

if (argumentsMap["export-missing"]) {
  exportMissingTranslations(sourceEntries, locale);
}

function consumerizeEntry(entry) {
  return {
    ...entry,
    summary: consumerizeTemplate(entry.summary),
    detail: consumerizeTemplate(entry.detail),
  };
}

function consumerizeRule(rule) {
  return {
    ...rule,
    summaryTemplate: consumerizeTemplate(rule.summaryTemplate),
    detailTemplate: consumerizeTemplate(rule.detailTemplate),
  };
}

function consumerizeTemplate(value) {
  if (typeof value !== "string") {
    return value;
  }
  const usesReferencePoint = value.includes("{{signal.referencePointName}}");
  const replacements = [
    [
      "{{signal.signName}}{{signal.houseName}}",
      "{{signal.consumerStyle}}，重点在{{signal.consumerArea}}",
    ],
    [
      "{{signal.signName}} {{signal.houseName}}",
      "{{signal.consumerStyle}}, focused on {{signal.consumerArea}}",
    ],
    ["{{signal.movingHouseName}}", "{{signal.consumerArea}}"],
    ["{{signal.houseName}}", "{{signal.consumerArea}}"],
    ["{{signal.signName}}", "{{signal.consumerStyle}}"],
    ["{{signal.referencePointName}}", "{{signal.consumerSecond}}"],
    [
      "{{signal.pointName}}",
      usesReferencePoint ? "{{signal.consumerFirst}}" : "{{signal.consumerTheme}}",
    ],
    ["{{signal.motionName}}", "{{signal.consumerMotion}}"],
    ["{{signal.phaseName}}", "{{signal.consumerTiming}}"],
    ["{{signal.aspectName}}", "{{signal.consumerLink}}"],
    ["{{signal.title}}", "{{signal.consumerTitle}}"],
    ["{{signal.orb}}", "{{signal.consumerIntensity}}"],
    ["{{signal.angle}}", "{{signal.consumerStage}}"],
  ];
  const withConsumerVariables = replacements.reduce(
    (result, [source, target]) => result.split(source).join(target),
    value,
  );
  const languageReplacements = locale === "zh-Hans"
    ? [
        ["处于入相阶段，这股影响仍在增强", "正在逐渐增强"],
        ["当前处于入相阶段", "这个主题正在增强"],
        ["处于精确阶段，当前接近影响最集中的阶段", "此刻表现最集中"],
        ["相位已接近精确", "这个主题正处在最明显的节点"],
        ["处于出相阶段，最强阶段正在过去", "最忙的阶段正在过去"],
        ["当前处于出相阶段", "这个主题正在缓和"],
        ["目前处于{{signal.consumerTiming}}阶段", "目前{{signal.consumerTiming}}"],
        ["当前容许度为{{signal.consumerIntensity}}", "当前表现{{signal.consumerIntensity}}"],
        ["当前紧密度为{{signal.consumerIntensity}}", "当前表现{{signal.consumerIntensity}}"],
        ["合相会", "这种连接会"],
        ["六合带来", "这种配合带来"],
        ["刑相会", "这种拉扯会"],
        ["拱相让", "这种配合让"],
        ["冲相常", "这种对照常"],
        ["入相", "正在增强"],
        ["出相", "正在缓和"],
        ["精确相位", "最集中的连接"],
        ["容许度", "明显程度"],
        ["相位", "连接"],
        ["行运", "近期变化"],
        ["次限", "长期变化"],
        ["逆行", "回顾调整"],
        ["宫位", "生活领域"],
      ]
    : [
        ["an orb", "a closeness"],
        ["An orb", "A closeness"],
        ["exact aspect", "clearest point"],
        ["Exact aspect", "Clearest point"],
        ["applying", "building"],
        ["Applying", "Building"],
        ["separating", "easing"],
        ["Separating", "Easing"],
        ["retrograde", "review cycle"],
        ["Retrograde", "Review cycle"],
        ["progressed", "long-term"],
        ["Progressed", "Long-term"],
        ["transit", "current change"],
        ["Transit", "Current change"],
        ["aspects", "connections"],
        ["Aspects", "Connections"],
        ["aspect", "connection"],
        ["Aspect", "Connection"],
        ["houses", "life areas"],
        ["Houses", "Life areas"],
        ["house", "life area"],
        ["House", "Life area"],
        ["orb", "closeness"],
        ["Orb", "Closeness"],
      ];
  return replaceWordBoundary(withConsumerVariables, languageReplacements);
}

function replaceWordBoundary(text, pairs) {
  let result = text;
  for (const [source, target] of pairs) {
    const escaped = source.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    result = result.replace(new RegExp(`\\b${escaped}\\b`, "g"), target);
  }
  return result;
}

function parseArguments(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 1) {
    const argument = values[index];
    if (!argument.startsWith("--")) {
      fail(`Unexpected argument: ${argument}`);
    }
    const key = argument.slice(2);
    if (key === "export-missing" || key === "include-sample") {
      result[key] = true;
      continue;
    }
    const value = values[index + 1];
    if (!value || value.startsWith("--")) {
      fail(`Missing value for ${argument}`);
    }
    result[key] = value;
    index += 1;
  }
  return result;
}

function readJSON(filePath, label) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing ${label}: ${path.relative(repositoryRoot, filePath)}`);
  }
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    fail(`Invalid ${label}: ${error.message}`);
  }
}

function readPrivateFragments(
  baseDirectory,
  filePrefix,
  collectionKey,
  fragmentLocale = locale
) {
  const techniques = ["natal", "current-sky", "transit", "secondary", "solar-return", "synastry"];
  const fragmentPaths = techniques.map((technique) =>
    path.join(baseDirectory, technique, `${filePrefix}-${fragmentLocale}.json`)
  );
  if (fragmentPaths.every((filePath) => fs.existsSync(filePath))) {
    return {
      [collectionKey]: fragmentPaths.flatMap((filePath) =>
        readJSON(filePath, `private ${filePrefix.toLowerCase()} fragment`)[collectionKey] ?? []
      ),
    };
  }
  return readJSON(
    path.join(baseDirectory, `${filePrefix}-${fragmentLocale}.json`),
    `private ${filePrefix.toLowerCase()}`
  );
}

function validateEntries(entries, expectedLocale) {
  if (!Array.isArray(entries)) {
    fail("Corpus entries must be an array");
  }
  const ids = new Set();
  const validLayers = new Set([
    "core",
    "supportive",
    "pressure",
    "advice",
    "timing",
    "transition",
    "atmosphere",
    "empty",
  ]);
  for (const entry of entries) {
    if (!entry.id || ids.has(entry.id)) {
      fail(`Duplicate or empty corpus ID: ${entry.id ?? "<empty>"}`);
    }
    ids.add(entry.id);
    if (entry.locale !== expectedLocale) {
      fail(`Corpus ${entry.id} has locale ${entry.locale}; expected ${expectedLocale}`);
    }
    if (!validLayers.has(entry.layer)) {
      fail(`Corpus ${entry.id} has invalid layer ${entry.layer}`);
    }
    if (!entry.selector || Object.keys(entry.selector).length === 0) {
      fail(`Corpus ${entry.id} must have a non-empty selector`);
    }
    if (!["draft", "sample", "review", "approved"].includes(entry.status)) {
      fail(`Corpus ${entry.id} has invalid status ${entry.status}`);
    }
    if (!entry.summary?.trim() || !entry.detail?.trim()) {
      fail(`Corpus ${entry.id} is missing summary or detail`);
    }
    if (!entry.sourceRevision?.trim()) {
      fail(`Corpus ${entry.id} is missing sourceRevision`);
    }
    validateCompositionQuality(entry.id, entry.summary, expectedLocale);
    validateCompositionQuality(entry.id, entry.detail, expectedLocale);
    ensureNoConsumerForbiddenLanguage(entry);
  }
}

function validateRules(rules, expectedLocale, cardsByTechnique) {
  if (!Array.isArray(rules)) {
    fail("Composition rules must be an array");
  }
  const expected = new Set();
  for (const [technique, cards] of Object.entries(cardsByTechnique)) {
    for (const card of cards) {
      expected.add(`${technique}.${card}`);
    }
  }
  const seen = new Set();
  for (const rule of rules) {
    const key = `${rule.technique}.${rule.cardID}`;
    if (seen.has(key)) {
      fail(`Duplicate card rule ${key}`);
    }
    seen.add(key);
    if (!expected.has(key)) {
      fail(`Unknown card rule ${key}`);
    }
    if (!rule.id || !rule.summaryTemplate?.trim() || !rule.detailTemplate?.trim()) {
      fail(`Rule ${key} is missing ID or templates`);
    }
    if (!Array.isArray(rule.bindings) || rule.bindings.length === 0) {
      fail(`Rule ${key} must contain at least one binding`);
    }
    const bindingNames = new Set();
    for (const binding of rule.bindings) {
      if (!binding.name || bindingNames.has(binding.name)) {
        fail(`Rule ${key} has duplicate or empty binding name`);
      }
      bindingNames.add(binding.name);
      if (!Array.isArray(binding.query?.layers) || binding.query.layers.length === 0) {
        fail(`Rule ${key}.${binding.name} has no layers`);
      }
      if (!Number.isInteger(binding.query.limit) || binding.query.limit < 1) {
        fail(`Rule ${key}.${binding.name} has invalid limit`);
      }
      if (binding.required !== true && binding.required !== false) {
        fail(`Rule ${key}.${binding.name} must declare required`);
      }
    }
    validateTemplateBindings(rule, bindingNames);
    validateCompositionQuality(rule.id, rule.summaryTemplate, expectedLocale);
    validateCompositionQuality(rule.id, rule.detailTemplate, expectedLocale);
    ensureNoConsumerForbiddenLanguage(rule);
  }
  const missing = [...expected].filter((key) => !seen.has(key));
  if (missing.length > 0) {
    fail(`Missing ${missing.length} ${expectedLocale} card rules: ${missing.join(", ")}`);
  }
}

function validateTemplateBindings(rule, bindingNames) {
  const joined = `${rule.summaryTemplate} ${rule.detailTemplate}`;
  const placeholders = [...joined.matchAll(/\{\{([a-zA-Z0-9.]+)\}\}/g)].map((match) => match[1]);
  for (const placeholder of placeholders) {
    if (placeholder.startsWith("context.")) {
      continue;
    }
    const binding = placeholder.split(".")[0];
    if (!bindingNames.has(binding)) {
      fail(`Rule ${rule.id} references undeclared binding ${binding}`);
    }
  }
}

function validateRuleCorpusCoverage(rules, entries) {
  const archetypesByTechnique = {
    natal: [
      ["point", "luminary", "personal", "direct"],
      ["point", "personal", "direct"],
      ["aspect", "single-chart", "supportive", "sextile", "applying", "personal"],
      ["aspect", "single-chart", "supportive", "trine", "exact", "personal"],
      ["aspect", "single-chart", "challenging", "square", "applying", "personal"],
      ["aspect", "single-chart", "challenging", "opposition", "separating", "personal"],
      ["aspect", "single-chart", "neutral", "conjunction", "exact", "personal"],
      ["house", "active-domain", "leading-domain"],
    ],
    "current-sky": [
      ["point", "luminary", "personal", "direct"],
      ["point", "outer", "retrograde"],
      ["aspect", "single-chart", "supportive", "trine", "applying", "outer"],
      ["aspect", "single-chart", "challenging", "square", "exact", "social"],
      ["aspect", "single-chart", "neutral", "conjunction", "separating", "personal"],
      ["lunar-phase", "phase", "full-moon"],
      ["calendar", "calendar-peak"],
      ["calendar", "calendar-active"],
    ],
    transit: [
      ["point", "moving-point", "personal", "direct"],
      ["point", "moving-point", "outer", "retrograde"],
      ["aspect", "cross-chart", "moving-transit", "supportive", "trine", "applying"],
      ["aspect", "cross-chart", "moving-transit", "challenging", "square", "exact"],
      ["aspect", "cross-chart", "moving-transit", "neutral", "conjunction", "separating"],
      ["house", "active-domain", "leading-domain"],
      ["calendar", "calendar-peak"],
    ],
    secondary: [
      ["point", "moving-point", "luminary", "personal", "direct"],
      ["aspect", "cross-chart", "moving-progressed", "supportive", "trine", "applying"],
      ["aspect", "cross-chart", "moving-progressed", "challenging", "square", "exact"],
      ["aspect", "cross-chart", "moving-progressed", "neutral", "conjunction", "separating"],
      ["house", "active-domain", "leading-domain"],
      ["lunar-phase", "phase", "first-quarter"],
    ],
    "solar-return": [
      ["point", "single-chart", "personal", "direct"],
      ["point", "single-chart", "outer", "retrograde"],
      ["aspect", "single-chart", "supportive", "trine", "applying", "personal"],
      ["aspect", "single-chart", "challenging", "square", "exact", "personal"],
      ["aspect", "single-chart", "neutral", "conjunction", "separating", "personal"],
      ["aspect", "cross-chart", "supportive", "trine", "applying", "personal"],
      ["aspect", "cross-chart", "challenging", "square", "exact", "personal"],
      ["aspect", "cross-chart", "neutral", "conjunction", "separating", "personal"],
      ["house", "active-domain", "leading-domain"],
      ["calendar", "calendar-peak"],
    ],
    synastry: [
      ["point", "cross-chart", "personal", "direct"],
      ["point", "cross-chart", "outer", "retrograde"],
      ["aspect", "cross-chart", "supportive", "trine", "applying", "personal"],
      ["aspect", "cross-chart", "challenging", "square", "exact", "personal"],
      ["aspect", "cross-chart", "neutral", "conjunction", "separating", "personal"],
      ["house", "active-domain", "leading-domain"],
      ["lunar-phase", "phase", "full-moon"],
    ],
  };

  for (const rule of rules) {
    const archetypes = archetypesByTechnique[rule.technique].map((tags) => new Set(tags));
    for (const binding of rule.bindings.filter((candidate) => candidate.required)) {
      const queryTags = new Set(binding.query.requiredTags ?? []);
      const viableSignals = archetypes.filter((tags) => isSubset(queryTags, tags));
      const candidate = entries.find((entry) => {
        if (!binding.query.layers.includes(entry.layer)) {
          return false;
        }
        if (entry.selector.techniques && !entry.selector.techniques.includes(rule.technique)) {
          return false;
        }
        if (entry.selector.cardIDs && !entry.selector.cardIDs.includes(rule.cardID)) {
          return false;
        }
        const selectorTags = new Set(entry.selector.requiredTags ?? []);
        return viableSignals.some((tags) => isSubset(selectorTags, tags));
      });
      if (!candidate) {
        fail(`Rule ${rule.technique}.${rule.cardID} has no corpus candidate for ${binding.name}`);
      }
    }
  }
}

function isSubset(required, available) {
  return [...required].every((value) => available.has(value));
}

function validateTranslationParity(entries, expectedLocale) {
  if (expectedLocale !== "en") {
    return;
  }
  const sourceLocale = "zh-Hans";
  const sourceEntries = readPrivateFragments(
    path.join(repositoryRoot, "ios", "PrivateContent"),
    "Corpus",
    "entries",
    sourceLocale
  ).entries ?? [];
  const sourceIDs = new Set(sourceEntries.map((entry) => entry.id));
  const currentIDs = new Set(entries.map((entry) => entry.id));
  const unknown = [...currentIDs].filter((id) => !sourceIDs.has(id));
  if (unknown.length > 0) {
    fail(`${expectedLocale} corpus contains IDs absent from ${sourceLocale}: ${unknown.join(", ")}`);
  }
}

function exportMissingTranslations(entries, expectedLocale) {
  if (expectedLocale !== "en") {
    fail("--export-missing is only valid with --locale en");
  }
  const chineseEntries = readPrivateFragments(
    path.join(repositoryRoot, "ios", "PrivateContent"),
    "Corpus",
    "entries",
    "zh-Hans"
  ).entries ?? [];
  const englishByID = new Map(entries.map((entry) => [entry.id, entry]));
  const missing = chineseEntries
    .filter((entry) => englishByID.get(entry.id)?.status !== "approved")
    .map((entry) => ({
      id: entry.id,
      layer: entry.layer,
      selector: entry.selector,
      sourceRevision: entry.sourceRevision,
      chineseSummary: entry.summary,
      chineseDetail: entry.detail,
      englishSummary: englishByID.get(entry.id)?.summary ?? "",
      englishDetail: englishByID.get(entry.id)?.detail ?? "",
      translationStatus: englishByID.get(entry.id)?.status ?? "missing",
    }));
  const exportPath = path.join(
    repositoryRoot,
    "ios",
    "TranslationExports",
    "missing-en.json",
  );
  fs.mkdirSync(path.dirname(exportPath), { recursive: true });
  fs.writeFileSync(exportPath, `${JSON.stringify({ entries: missing }, null, 2)}\n`);
  console.log(`Exported ${missing.length} rows to ${path.relative(repositoryRoot, exportPath)}`);
}

function ensureNoConsumerForbiddenLanguage(value) {
  const text = typeof value === "string"
    ? value
    : [
        value.summary,
        value.detail,
        value.summaryTemplate,
        value.detailTemplate,
      ].filter(Boolean).join(" ");
  const forbidden = [
    "先看卡片中最突出的结构",
    "本卡片",
    "模板回答",
    "语料",
    "AI",
    "概率值",
    "不能预测",
    "仅供",
  ];
  const found = forbidden.find((term) => text.includes(term));
  if (found) {
    fail(`Consumer content contains forbidden internal phrase: ${found}`);
  }
}

function validateCompositionQuality(id, text, expectedLocale) {
  if (/\{\{[^}]+\}\}/.test(text.replaceAll(/{{[a-zA-Z0-9.]+}}/g, ""))) {
    fail(`${id} contains an invalid or nested placeholder`);
  }
  if (expectedLocale === "en" && /\ban\s+(?:closeness|strength|support|pressure|timing|connection)\b/i.test(text)) {
    fail(`${id} contains an invalid English article`);
  }
  const normalizedSentences = text
    .split(/(?<=[.!?。！？])\s*/)
    .map((sentence) => sentence.toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, ""))
    .filter(Boolean);
  for (let index = 1; index < normalizedSentences.length; index += 1) {
    if (normalizedSentences[index] === normalizedSentences[index - 1]) {
      fail(`${id} contains a consecutive duplicate sentence`);
    }
  }
  const repeatedPair = /{{signal\.([a-zA-Z0-9]+)}}\s*(?:and|&|与|和)\s*{{signal\.\1}}/i;
  if (repeatedPair.test(text)) {
    fail(`${id} joins the same semantic placeholder to itself`);
  }
}

function fail(message) {
  console.error(`Content pack error: ${message}`);
  process.exit(1);
}
