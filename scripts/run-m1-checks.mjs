import { spawnSync } from "node:child_process";

const databaseUrl = process.env.INTERSTELLAR_TEST_DATABASE_URL;
if (!databaseUrl) {
  console.error(
    "[M1] INTERSTELLAR_TEST_DATABASE_URL is required; database tests may not be skipped at the M1 gate.",
  );
  process.exit(2);
}

const checks = [
  ["Foundation repository gate", "npm", ["run", "foundation:check"]],
  ["Time, location, dataset, migration, RLS, and immutability", "npm", ["run", "m1:domain:test"]],
];

for (const [label, command, args] of checks) {
  process.stdout.write(`\n[M1] ${label}\n`);
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: "inherit",
  });
  if (result.error) {
    console.error(`[M1] could not run ${label}: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    console.error(`[M1] ${label} failed with exit code ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

console.log("\n[M1] all executable Foundation gates passed");
