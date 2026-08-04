import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDirectory = path.join(repositoryRoot, "artifacts", "classical-transit");
const destination = process.env.TRANSIT_COPY_TEST_DESTINATION
  ?? "platform=iOS Simulator,name=iPhone 12 mini";
const result = spawnSync(
  "xcodebuild",
  [
    "-project", "ios/Interstellar.xcodeproj",
    "-scheme", "Interstellar",
    "-destination", destination,
    "-only-testing:InterstellarTests/ClassicalTransitPlanningTests/testExportClassicalTransitCopyReachability",
    "test",
  ],
  {
    cwd: repositoryRoot,
    encoding: "utf8",
    maxBuffer: 100 * 1024 * 1024,
  },
);
const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
if (result.status !== 0) {
  process.stderr.write(output);
  process.exit(result.status ?? 1);
}
const marker = output.match(/CLASSICAL_TRANSIT_COPY_OBSERVATIONS_BASE64:([A-Za-z0-9+/=]+)/);
if (!marker) {
  throw new Error("Classical Transit Planner observations were not emitted");
}
const payload = JSON.parse(Buffer.from(marker[1], "base64").toString("utf8"));
fs.mkdirSync(outputDirectory, { recursive: true });
writeJSON("classical-transit-planner-observations.json", {
  generatedAt: new Date().toISOString(),
  ...payload,
});

console.log(`Classical Transit fixtures: ${payload.fixtureCount}`);
console.log(`Classical Transit real runs: ${payload.realRunCount}`);
console.log(`Classical Transit finite probes: ${payload.finiteProbeCount}`);
console.log(`Classical Transit observed requests: ${payload.observations.length}`);

function writeJSON(filename, value) {
  fs.writeFileSync(path.join(outputDirectory, filename), `${JSON.stringify(value, null, 2)}\n`);
}
