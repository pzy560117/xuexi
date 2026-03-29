#!/usr/bin/env node
/**
 * SessionStart Hook：
 * 在新会话启动时注入最小上下文提示，帮助模型识别 loop 状态文件是否存在。
 */

"use strict";

const fs = require("fs");
const path = require("path");

/**
 * 读取 SessionStart 输入并返回 hookSpecificOutput。
 */
function run(rawInput) {
  const runtimeDir = path.join(process.cwd(), "docs", "runtime");
  const stateFile = path.join(runtimeDir, "superpower-loop.local.md");
  const bootstrapFile = path.join(runtimeDir, "superpower-loop.bootstrap.md");

  const hints = [];
  if (fs.existsSync(bootstrapFile) && !fs.existsSync(stateFile)) {
    hints.push(
      "检测到 docs/runtime/superpower-loop.bootstrap.md 存在但 superpower-loop.local.md 缺失，进入流水线前需先修复 loop 状态文件。"
    );
  }

  if (hints.length === 0) {
    hints.push("SessionStart: superpowers-p2r hook 已加载。");
  }

  const payload = JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: hints.join("\n")
    }
  });

  return { stdout: payload, exitCode: 0 };
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
    process.exit(Number.isInteger(output.exitCode) ? output.exitCode : 0);
  });
}

