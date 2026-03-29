#!/usr/bin/env node
/**
 * Hook 开关控制。
 * - ECC_HOOK_PROFILE=minimal|standard|strict（默认 standard）
 * - ECC_DISABLED_HOOKS=hook-id-1,hook-id-2
 */

"use strict";

const VALID_PROFILES = new Set(["minimal", "standard", "strict"]);

/**
 * 统一归一化 Hook ID，避免大小写与空格导致误判。
 */
function normalizeId(value) {
  return String(value || "").trim().toLowerCase();
}

/**
 * 读取当前 Hook profile；非法值会回退到 standard。
 */
function getHookProfile() {
  const raw = String(process.env.ECC_HOOK_PROFILE || "standard")
    .trim()
    .toLowerCase();
  return VALID_PROFILES.has(raw) ? raw : "standard";
}

/**
 * 读取禁用 Hook 列表。
 */
function getDisabledHookIds() {
  const raw = String(process.env.ECC_DISABLED_HOOKS || "");
  if (!raw.trim()) {
    return new Set();
  }
  return new Set(
    raw
      .split(",")
      .map(item => normalizeId(item))
      .filter(Boolean)
  );
}

/**
 * 解析允许 profile 列表；为空时使用默认值。
 */
function parseProfiles(rawProfiles, fallback = ["standard", "strict"]) {
  if (!rawProfiles) {
    return [...fallback];
  }
  if (Array.isArray(rawProfiles)) {
    const parsed = rawProfiles
      .map(item => String(item || "").trim().toLowerCase())
      .filter(item => VALID_PROFILES.has(item));
    return parsed.length > 0 ? parsed : [...fallback];
  }
  const parsed = String(rawProfiles)
    .split(",")
    .map(item => item.trim().toLowerCase())
    .filter(item => VALID_PROFILES.has(item));
  return parsed.length > 0 ? parsed : [...fallback];
}

/**
 * 判断某个 Hook 是否应执行。
 */
function isHookEnabled(hookId, options = {}) {
  const id = normalizeId(hookId);
  if (!id) {
    return true;
  }

  const disabledSet = getDisabledHookIds();
  if (disabledSet.has(id)) {
    return false;
  }

  const profile = getHookProfile();
  const allowedProfiles = parseProfiles(options.profiles);
  return allowedProfiles.includes(profile);
}

module.exports = {
  VALID_PROFILES,
  normalizeId,
  getHookProfile,
  getDisabledHookIds,
  parseProfiles,
  isHookEnabled
};

