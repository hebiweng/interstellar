import { spawnSync } from "node:child_process";

const databaseUrl = process.env.INTERSTELLAR_TEST_DATABASE_URL;
if (!databaseUrl) {
  console.error(
    "[M2] INTERSTELLAR_TEST_DATABASE_URL is required; inherited M1 database gates may not be skipped.",
  );
  process.exit(2);
}

const checks = [
  ["Inherited M1 gate", "npm", ["run", "m1:check"]],
  ["Astronomy core, adapter, differential and API tests", "npm", ["run", "m2:domain:test"]],
  ["M2 Python lint and formatting surface", "npm", ["run", "m2:lint"]],
];

for (const [label, command, args] of checks) {
  process.stdout.write(`\n[M2] ${label}\n`);
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: "inherit",
  });
  if (result.error) {
    console.error(`[M2] could not run ${label}: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    console.error(`[M2] ${label} failed with exit code ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

console.log("\n[M2] all executable M2 gates passed");
