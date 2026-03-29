#!/usr/bin/env node
/**
 * 根据 profile/禁用列表执行 Hook 脚本的统一入口。
 *
 * 用法：
 *   node run-with-flags.js <hookId> <scriptRelativePath> [profilesCsv]
 */

"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { isHookEnabled } = require("../lib/hook-flags");

const MAX_STDIN_BYTES = 1024 * 1024;

/**
 * 读取 stdin 原文，超限则截断。
 */
function readStdinRaw() {
  return new Promise(resolve => {
    let raw = "";
    let truncated = false;
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", chunk => {
      if (raw.length < MAX_STDIN_BYTES) {
        const remaining = MAX_STDIN_BYTES - raw.length;
        raw += chunk.substring(0, remaining);
        if (chunk.length > remaining) {
          truncated = true;
        }
      } else {
        truncated = true;
      }
    });
    process.stdin.on("end", () => resolve({ raw, truncated }));
    process.stdin.on("error", () => resolve({ raw, truncated }));
  });
}

/**
 * 获取插件根目录。
 */
function getPluginRoot() {
  if (process.env.CLAUDE_PLUGIN_ROOT && process.env.CLAUDE_PLUGIN_ROOT.trim()) {
    return process.env.CLAUDE_PLUGIN_ROOT;
  }
  return path.resolve(__dirname, "..", "..");
}

/**
 * 将 Hook 返回结果写回标准输出。
 */
function emitHookResult(rawInput, output) {
  if (typeof output === "string" || Buffer.isBuffer(output)) {
    process.stdout.write(String(output));
    return 0;
  }

  if (output && typeof output === "object") {
    if (typeof output.stderr === "string" && output.stderr.length > 0) {
      process.stderr.write(output.stderr.endsWith("\n") ? output.stderr : `${output.stderr}\n`);
    }
    if (Object.prototype.hasOwnProperty.call(output, "stdout")) {
      process.stdout.write(String(output.stdout || ""));
    } else if (!Number.isInteger(output.exitCode) || output.exitCode === 0) {
      process.stdout.write(rawInput);
    }
    return Number.isInteger(output.exitCode) ? output.exitCode : 0;
  }

  process.stdout.write(rawInput);
  return 0;
}

/**
 * 根据脚本类型选择解释器，确保 .sh 在 Windows 也可执行。
 */
function resolveLegacyCommand(scriptPath) {
  if (scriptPath.endsWith(".js")) {
    return { command: process.execPath, args: [scriptPath] };
  }
  if (scriptPath.endsWith(".sh")) {
    const gitBash = process.env.CLAUDE_CODE_GIT_BASH_PATH || "bash";
    return { command: gitBash, args: [scriptPath] };
  }
  return { command: scriptPath, args: [] };
}

/**
 * 使用子进程执行 legacy hook 脚本。
 */
function runLegacyHook(scriptPath, rawInput, truncated) {
  const launcher = resolveLegacyCommand(scriptPath);
  const result = spawnSync(launcher.command, launcher.args, {
    input: rawInput,
    encoding: "utf8",
    env: {
      ...process.env,
      ECC_HOOK_INPUT_TRUNCATED: truncated ? "1" : "0",
      ECC_HOOK_INPUT_MAX_BYTES: String(MAX_STDIN_BYTES)
    },
    cwd: process.cwd(),
    timeout: 30000
  });

  if (typeof result.stdout === "string" && result.stdout.length > 0) {
    process.stdout.write(result.stdout);
  } else if (Number.isInteger(result.status) && result.status === 0) {
    process.stdout.write(rawInput);
  }

  if (typeof result.stderr === "string" && result.stderr.length > 0) {
    process.stderr.write(result.stderr);
  }

  if (result.error || result.signal || result.status === null) {
    const detail = result.error
      ? result.error.message
      : result.signal
        ? `terminated by signal ${result.signal}`
        : "missing exit status";
    process.stderr.write(`[Hook] legacy hook execution failed: ${detail}\n`);
    return 1;
  }
  return Number.isInteger(result.status) ? result.status : 0;
}

/**
 * 主流程：按 profile 判断是否启用，再执行对应 Hook 脚本。
 */
async function main() {
  const [, , hookId, relativeScriptPath, profilesCsv] = process.argv;
  const { raw, truncated } = await readStdinRaw();

  if (!hookId || !relativeScriptPath) {
    process.stdout.write(raw);
    process.exit(0);
  }

  if (!isHookEnabled(hookId, { profiles: profilesCsv })) {
    process.stdout.write(raw);
    process.exit(0);
  }

  const pluginRoot = getPluginRoot();
  const resolvedRoot = path.resolve(pluginRoot);
  const scriptPath = path.resolve(pluginRoot, relativeScriptPath);

  if (!scriptPath.startsWith(`${resolvedRoot}${path.sep}`)) {
    process.stderr.write(`[Hook] path traversal rejected: ${scriptPath}\n`);
    process.stdout.write(raw);
    process.exit(0);
  }

  if (!fs.existsSync(scriptPath)) {
    process.stderr.write(`[Hook] script not found: ${scriptPath}\n`);
    process.stdout.write(raw);
    process.exit(0);
  }

  let loadedModule = null;
  try {
    loadedModule = require(scriptPath);
  } catch {
    loadedModule = null;
  }

  if (loadedModule && typeof loadedModule.run === "function") {
    try {
      const output = loadedModule.run(raw, {
        truncated,
        maxStdinBytes: MAX_STDIN_BYTES
      });
      process.exit(emitHookResult(raw, output));
    } catch (error) {
      process.stderr.write(`[Hook] run() error: ${error.message}\n`);
      process.stdout.write(raw);
      process.exit(0);
    }
  }

  process.exit(runLegacyHook(scriptPath, raw, truncated));
}

main().catch(error => {
  process.stderr.write(`[Hook] run-with-flags fatal: ${error.message}\n`);
  process.exit(0);
});
