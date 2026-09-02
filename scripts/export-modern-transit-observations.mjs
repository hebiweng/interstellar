import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDirectory = path.join(repositoryRoot, "artifacts", "modern-transit");
const destination = process.env.TRANSIT_COPY_TEST_DESTINATION?.trim();
if (!destination || /simulator/i.test(destination)) {
  throw new Error("Set TRANSIT_COPY_TEST_DESTINATION to a connected physical iPhone destination; Simulator is not allowed.");
}
const result = spawnSync(
  "xcodebuild",
  [
    "-project", "ios/Interstellar.xcodeproj",
    "-scheme", "Interstellar",
    "-destination", destination,
    "-only-testing:InterstellarTests/TransitContentPlannerTests/testExportModernTransitCopyReachability",
    "test",
  ],
  {
    cwd: repositoryRoot,
    encoding: "utf8",
    env: { ...process.env, TRANSIT_COPY_EXPORT: "1" },
    maxBuffer: 100 * 1024 * 1024,
  },
);
const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
if (result.status !== 0) {
  process.stderr.write(output);
  process.exit(result.status ?? 1);
}
const marker = output.match(/TRANSIT_COPY_OBSERVATIONS_BASE64:([A-Za-z0-9+/=]+)/);
if (!marker) {
  throw new Error("Planner reachability test did not emit transit copy observations");
}
const payload = JSON.parse(Buffer.from(marker[1], "base64").toString("utf8"));
fs.mkdirSync(outputDirectory, { recursive: true });
fs.writeFileSync(
  path.join(outputDirectory, "modern-transit-planner-observations.json"),
  `${JSON.stringify({ generatedAt: new Date().toISOString(), ...payload }, null, 2)}\n`,
);

console.log(`Fixed transit fixtures: ${payload.fixedFixtureIDs.length}`);
console.log(`Real transit runs: ${payload.realRuns.length}`);
console.log(`Exhaustive planner probes: ${payload.exhaustiveProbeCount}`);
console.log(`Observed request identities: ${payload.observations.length}`);
