#!/usr/bin/env node
/**
 * PreCompact Hook：
 * 在上下文压缩前记录事件，便于后续排查“压缩后断链”问题。
 */

"use strict";

const fs = require("fs");
const path = require("path");

/**
 * 记录压缩事件并原样透传输入。
 */
function run(rawInput) {
  try {
    const runtimeDir = path.join(process.cwd(), "docs", "runtime");
    fs.mkdirSync(runtimeDir, { recursive: true });
    const markerFile = path.join(runtimeDir, "superpower-loop.compact.log");
    const stamp = new Date().toISOString();
    fs.appendFileSync(markerFile, `[${stamp}] pre-compact triggered\n`, "utf8");
  } catch (error) {
    return {
      stdout: rawInput,
      stderr: `[pre-compact] warn: ${error.message}`,
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

