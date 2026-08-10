#!/bin/zsh

set -euo pipefail

usage_json="$(/usr/bin/expect <<'EXPECT'
set timeout 20
log_user 0
spawn codex app-server --listen stdio://
set initialize {{"id":1,"method":"initialize","params":{"clientInfo":{"name":"interstellar-usage-check","version":"1"},"capabilities":{}}}}
send -- "$initialize\n"
expect -re {"id":1}
set initialized {{"method":"initialized"}}
set request {{"id":2,"method":"account/rateLimits/read","params":null}}
send -- "$initialized\n"
send -- "$request\n"
expect -re {\{"id":2,"result"[^\r\n]*\}}
puts $expect_out(0,string)
flush stdout
close
exit 0
EXPECT
)"

CODEX_USAGE_JSON="$usage_json" node -e '
const response = JSON.parse(process.env.CODEX_USAGE_JSON);
if (response.error) throw new Error(response.error.message || "rate limit query failed");
const snapshot = response.result?.rateLimits;
const windows = [snapshot?.primary, snapshot?.secondary].filter(Boolean);
if (!windows.length) throw new Error("rate limit response has no windows");
const weekly = windows.find((value) => (value.windowDurationMins ?? 0) >= 7 * 24 * 60)
  ?? windows.reduce((longest, value) =>
    (value.windowDurationMins ?? 0) > (longest.windowDurationMins ?? 0) ? value : longest
  );
const remaining = Math.max(0, 100 - weekly.usedPercent);
const reset = weekly.resetsAt
  ? new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short" })
      .format(new Date(weekly.resetsAt * 1000))
  : "unknown";
console.log(`Weekly limit: ${remaining}% left (resets ${reset})`);
'
