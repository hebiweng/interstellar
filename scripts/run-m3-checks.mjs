import { spawnSync } from "node:child_process";

const databaseUrl = process.env.INTERSTELLAR_TEST_DATABASE_URL;
if (!databaseUrl) {
  console.error(
    "[M3] INTERSTELLAR_TEST_DATABASE_URL is required; inherited M2 and persistence gates may not be skipped.",
  );
  process.exit(2);
}

const checks = [
  ["Inherited M2 gate", "npm", ["run", "m2:check"]],
  ["Houses, aspects, distributions, snapshot and table exports", "npm", ["run", "m3:domain:test"]],
  ["M3 Python lint and formatting surface", "npm", ["run", "m3:lint"]],
];

for (const [label, command, args] of checks) {
  process.stdout.write(`\n[M3] ${label}\n`);
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: "inherit",
  });
  if (result.error) {
    console.error(`[M3] could not run ${label}: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    console.error(`[M3] ${label} failed with exit code ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

console.log("\n[M3] all executable M3 gates passed");
