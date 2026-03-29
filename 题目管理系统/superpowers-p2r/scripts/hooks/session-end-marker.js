#!/usr/bin/env node
/**
 * SessionEnd Hook：
 * 在会话结束时写入轻量标记，便于追踪流水线会话边界。
 */

"use strict";

const fs = require("fs");
const path = require("path");

/**
 * 写入 SessionEnd 事件标记并透传输入。
 */
function run(rawInput) {
  try {
    const runtimeDir = path.join(process.cwd(), "docs", "runtime");
    fs.mkdirSync(runtimeDir, { recursive: true });
    const markerFile = path.join(runtimeDir, "superpower-loop.session-end.log");
    const stamp = new Date().toISOString();
    fs.appendFileSync(markerFile, `[${stamp}] session-end\n`, "utf8");
  } catch (error) {
    return {
      stdout: rawInput,
      stderr: `[session-end] warn: ${error.message}`,
      exitCode: 0
    };
  }

  return { stdout: rawInput, exitCode: 0 };
}

module.exports = { run };

if (require.main === module) {
  let raw = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", chunk => {
    raw += chunk;
  });
  process.stdin.on("end", () => {
    const output = run(raw);
    if (output && output.stdout) {
      process.stdout.write(output.stdout);
    } else {
      process.stdout.write(raw);
    }
    if (output && output.stderr) {
      process.stderr.write(`${output.stderr}\n`);
    }
    process.exit(Number.isInteger(output.exitCode) ? output.exitCode : 0);
  });
}

