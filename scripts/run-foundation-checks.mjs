import { spawnSync } from "node:child_process";

const checks = [
  ["Catalog contracts", "npm", ["run", "docs:validate"]],
  ["OpenAPI and JSON Schema", "npm", ["run", "contracts:validate"]],
  ["Generated contract drift", "npm", ["run", "contracts:check"]],
  ["Contract tests", "npm", ["run", "contracts:test"]],
  ["Python lint", "npm", ["run", "backend:lint"]],
  ["Backend and worker tests", "npm", ["run", "backend:test"]],
  ["Web lint", "npm", ["run", "lint"]],
  ["Web build and tests", "npm", ["run", "test:web"]],
];

for (const [label, command, args] of checks) {
  process.stdout.write(`\n[foundation] ${label}\n`);
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: "inherit",
  });

  if (result.error) {
    console.error(`[foundation] could not run ${label}: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    console.error(`[foundation] ${label} failed with exit code ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

console.log("\n[foundation] all executable repository checks passed");
