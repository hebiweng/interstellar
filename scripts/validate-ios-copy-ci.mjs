#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

const required = {
  en: process.env.INTERSTELLAR_COPY_CATALOG_EN_B64,
  "zh-Hans": process.env.INTERSTELLAR_COPY_CATALOG_ZH_HANS_B64,
};
const missing = Object.entries(required).filter(([, value]) => !value).map(([locale]) => locale);
if (missing.length) {
  console.error(`Private copy catalog CI secrets are missing: ${missing.join(", ")}`);
  process.exit(1);
}

const directory = fs.mkdtempSync(path.join(os.tmpdir(), "interstellar-copy-ci-"));
try {
  for (const [locale, encoded] of Object.entries(required)) {
    const catalogPath = path.join(directory, `CopyCatalog-${locale}.json`);
    fs.writeFileSync(catalogPath, Buffer.from(encoded, "base64"), { mode: 0o600 });
    validate(catalogPath, true);

    // Prove that approval alone cannot bypass structural validation.
    const mutated = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
    mutated.entries[0].variables = [
      { name: "planet", type: "body" },
      { name: "sign", type: "sign" },
      { name: "houseLabel", type: "house" },
    ];
    mutated.entries[0].kind = "consumer";
    const invalidPath = path.join(directory, `invalid-${locale}.json`);
    fs.writeFileSync(invalidPath, JSON.stringify(mutated), { mode: 0o600 });
    validate(invalidPath, false);
  }
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}

function validate(catalogPath, shouldPass) {
  const result = spawnSync(
    process.execPath,
    ["scripts/build-ios-copy-catalog.mjs", "--validate-runtime", catalogPath],
    { cwd: process.cwd(), encoding: "utf8" },
  );
  if ((result.status === 0) !== shouldPass) {
    process.stderr.write(result.stderr || result.stdout);
    process.exit(1);
  }
}

console.log("Private English and Simplified Chinese copy catalogs passed CI validation and negative gate tests.");
