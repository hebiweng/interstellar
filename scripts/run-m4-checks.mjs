import { spawnSync } from "node:child_process";

const databaseUrl = process.env.INTERSTELLAR_TEST_DATABASE_URL;
if (!databaseUrl) {
  console.error(
    "[M4] INTERSTELLAR_TEST_DATABASE_URL is required; inherited M3 and persistence gates may not be skipped.",
  );
  process.exit(2);
}

const checks = [
  ["Inherited M3 gate", "npm", ["run", "m3:check"]],
  ["Registries, recipes, jobs, catalog and workflow API", "npm", ["run", "m4:domain:test"]],
  ["M4 Python lint surface", "npm", ["run", "m4:lint"]],
  ["Generated SDK drift", "npm", ["run", "sdk:check"]],
  ["Generated SDK contract tests", "npm", ["run", "sdk:test"]],
  ["TypeScript SDK strict compilation", "npm", ["run", "sdk:tscheck"]],
];

for (const [label, command, args] of checks) {
  process.stdout.write(`\n[M4] ${label}\n`);
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: "inherit",
  });
  if (result.error) {
    console.error(`[M4] could not run ${label}: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    console.error(`[M4] ${label} failed with exit code ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

console.log("\n[M4] all executable M4 gates passed");
