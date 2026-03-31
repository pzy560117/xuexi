#!/usr/bin/env bash
# enforce-paths.sh — PreToolUse Hook
# 按 Agent 角色强制文件路径写入权限，防止并行 Agent 间文件冲突
# 灵感来源: atelier-pipeline/source/hooks/enforce-paths.sh (Apache-2.0)
#
# 角色权限矩阵:
#   Implementer → 源码目录（排除 docs/hooks/skills/等）
#   Reviewer    → 仅 .tmp/ 报告 + docs/runtime/ 状态
#   主线程(编排) → 仅 docs/runtime/ 状态文件
#   Ellis(提交) → 完全权限
set -euo pipefail

INPUT=$(cat)

# 依赖 jq 解析 JSON 输入
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for enforce-paths hook. Install: apt install jq / brew install jq" >&2
  exit 2
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')

# 仅检查写入类工具
case "$TOOL_NAME" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

# 无文件路径则跳过检查
[ -z "$FILE_PATH" ] && exit 0

# 加载配置 — 配置不存在则跳过（尚未 setup）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/enforcement-config.json"
[ ! -f "$CONFIG" ] && exit 0

# 路径归一化（兼容 Windows 盘符与反斜杠）
normalize_path() {
  local p="$1"
  p="${p%\"}"
  p="${p#\"}"
  p="${p//\\//}"
  if [[ "$p" =~ ^([A-Za-z]):/(.*)$ ]]; then
    local drive="${BASH_REMATCH[1],,}"
    p="/${drive}/${BASH_REMATCH[2]}"
  fi
  while [[ "$p" == *"//"* ]]; do
    p="${p//\/\//\/}"
  done
  p="${p#./}"
  echo "$p"
}

# 从 Hook 输入中推断当前会话项目根目录
detect_project_root() {
  local candidate=""
  candidate=$(echo "$INPUT" | jq -r '.cwd // .working_directory // .tool_input.cwd // .tool_input.working_directory // empty')
  if [ -n "$candidate" ] && [ -d "$candidate" ]; then
    echo "$candidate"
    return
  fi

  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return
  fi

  echo "$(pwd)"
}

# 绝对路径转相对路径（若无法转换则返回原路径）
to_relative_path() {
  local file="$1"
  local root="$2"
  case "$file" in
    "$root") echo "" ;;
    "$root"/*) echo "${file#"$root"/}" ;;
    *) echo "$file" ;;
  esac
}

PROJECT_ROOT="$(detect_project_root)"
PROJECT_ROOT_NORM="$(normalize_path "$PROJECT_ROOT")"
FILE_PATH_NORM="$(normalize_path "$FILE_PATH")"
FILE_PATH_REL="$(to_relative_path "$FILE_PATH_NORM" "$PROJECT_ROOT_NORM")"

PIPELINE_DIR="$(jq -r '.pipeline_state_dir' "$CONFIG" | tr -d '\r')"
ARCH_DIR="$(jq -r '.architecture_dir' "$CONFIG" | tr -d '\r')"
SPEC_DIR="$(jq -r '.product_specs_dir' "$CONFIG" | tr -d '\r')"

# 检查文件路径是否匹配任一前缀
path_matches() {
  local file="$1"
  shift
  for prefix in "$@"; do
    case "$file" in
      "$prefix"*) return 0 ;;
    esac
  done
  return 1
}

# 绝对路径兜底匹配（允许 /x/project/docs/runtime/* 这类路径）
path_matches_abs() {
  local file="$1"
  shift
  for prefix in "$@"; do
    local clean_prefix="${prefix%/}"
    case "$file" in
      "$clean_prefix"|"$clean_prefix"/*|*/"$clean_prefix"|*/"$clean_prefix"/*) return 0 ;;
    esac
  done
  return 1
}

# 检查是否为测试文件
is_test_file() {
  local file="$1"
  while IFS= read -r pattern; do
    pattern="${pattern//$'\r'/}"
    local normalized_pattern="$pattern"
    normalized_pattern="${normalized_pattern//\\//}"
    case "$file" in
      *"$normalized_pattern"*) return 0 ;;
    esac
    # 处理根路径: /tests/ 也匹配 tests/
    if [[ "$normalized_pattern" == /* ]]; then
      local stripped="${normalized_pattern#/}"
      case "$file" in
        "$stripped"*) return 0 ;;
      esac
    fi
  done < <(jq -r '.test_patterns[]' "$CONFIG" 2>/dev/null)
  return 1
}

# 检查是否在 Implementer 禁写路径中
is_implementer_blocked() {
  local file="$1"
  while IFS= read -r prefix; do
    prefix="${prefix//$'\r'/}"
    case "$file" in
      "$prefix"*) return 0 ;;
    esac
  done < <(jq -r '.implementer_blocked_paths[]' "$CONFIG" 2>/dev/null)
  return 1
}

# 检查是否在 Reviewer 允许路径中
is_reviewer_allowed() {
  local file="$1"
  while IFS= read -r prefix; do
    prefix="${prefix//$'\r'/}"
    case "$file" in
      "$prefix"*) return 0 ;;
    esac
  done < <(jq -r '.reviewer_allowed_paths[]' "$CONFIG" 2>/dev/null)
  return 1
}

# 检查是否在主线程(编排器)允许路径中（支持配置扩展）
is_orchestrator_allowed() {
  local file_rel="$1"
  local file_abs="$2"
  local has_config=0

  while IFS= read -r prefix; do
    prefix="${prefix//$'\r'/}"
    has_config=1
    [ -z "$prefix" ] && continue

    case "$file_rel" in
      "$prefix"|"$prefix"*) return 0 ;;
    esac

    if path_matches_abs "$file_abs" "$prefix"; then
      return 0
    fi
  done < <(jq -r '.orchestrator_allowed_paths[]?' "$CONFIG" 2>/dev/null)

  # 向后兼容：旧配置未提供 orchestrator_allowed_paths 时，回退到默认规则
  if [ "$has_config" -eq 0 ]; then
    if path_matches "$file_rel" "$PIPELINE_DIR" "$SPEC_DIR" ".tmp/" || path_matches_abs "$file_abs" "$PIPELINE_DIR" "$SPEC_DIR" ".tmp"; then
      return 0
    fi
  fi

  return 1
}

# 判断指定 phase 是否处于 in_progress（用于主线程串行降级兜底）
is_phase_in_progress() {
  local target_phase="$1"
  local state_file="${SUPERPOWER_STATE_FILE:-docs/runtime/superpower-loop.local.md}"

  # 相对路径按项目根解析
  case "$state_file" in
    /*) ;;
    *) state_file="$PROJECT_ROOT_NORM/$state_file" ;;
  esac

  [ -f "$state_file" ] || return 1

  # 快速路径：当前 phase 索引（executing-plans-p2r 通常为 4）
  if grep -Eq '^current_phase:[[:space:]]*4([[:space:]]|$)' "$state_file"; then
    return 0
  fi

  awk -v target="$target_phase" '
    BEGIN { name=""; found=0 }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      name=line
      next
    }
    /^[[:space:]]*status:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*status:[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      if (name == target && line == "in_progress") {
        found=1
        exit 0
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$state_file"
}

# 按 Agent 角色分发权限检查
case "$AGENT_TYPE" in
  # Implementer: 可写源码，不可写 docs/hooks/skills/等管理文件
  # 兼容当前环境可用子代理类型（general-purpose / Explore / Plan / worker / default）
  implementer|Implementer|implementer-*|general-purpose|default|worker|Worker|explore|Explore|plan|Plan)
    if is_implementer_blocked "$FILE_PATH_REL"; then
      echo "BLOCKED: Implementer 不能写入管理目录。文档变更路由到文档 Agent，Hook 变更路由到编排器。尝试写入: $FILE_PATH_NORM" >&2
      exit 2
    fi
    ;;

  # Reviewer: 仅可写 .tmp/ 报告和 docs/runtime/ 状态
  reviewer|Reviewer|reviewer-*|security-reviewer|blind-reviewer)
    if is_reviewer_allowed "$FILE_PATH_REL" || path_matches_abs "$FILE_PATH_NORM" ".tmp" "docs/runtime"; then
      exit 0
    fi
    if is_test_file "$FILE_PATH_REL"; then
      exit 0
    fi
    echo "BLOCKED: Reviewer 仅能写入 .tmp/ 报告和测试文件。源码修改路由到 Implementer。尝试写入: $FILE_PATH_NORM" >&2
    exit 2
    ;;

  # Ellis (提交 Agent): 完全写入权限
  ellis|Ellis|commit-agent)
    exit 0
    ;;

  # Architect (架构 Agent): 仅可写架构目录
  architect|Architect|cal)
    path_matches "$FILE_PATH_REL" "$ARCH_DIR" || path_matches_abs "$FILE_PATH_NORM" "$ARCH_DIR" || {
      echo "BLOCKED: Architect 仅能写入 $ARCH_DIR/。源码路由到 Implementer。尝试写入: $FILE_PATH_NORM" >&2
      exit 2
    }
    ;;

  # Doc Agent (文档 Agent): 仅可写 docs/
  doc-agent|Agatha|agatha)
    path_matches "$FILE_PATH_REL" "docs/" || path_matches_abs "$FILE_PATH_NORM" "docs" || {
      echo "BLOCKED: 文档 Agent 仅能写入 docs/。源码路由到 Implementer。尝试写入: $FILE_PATH_NORM" >&2
      exit 2
    }
    ;;

  # 主线程 (编排器): 仅可写 pipeline 状态文件和 spec 目录
  "")
    # executing-plans-p2r 串行降级兜底：
    # 当子代理不可用时，主线程允许按 Implementer 规则写源码（但仍禁止管理目录）。
    if is_phase_in_progress "executing-plans-p2r"; then
      if is_orchestrator_allowed "$FILE_PATH_REL" "$FILE_PATH_NORM"; then
        exit 0
      fi
      if ! is_implementer_blocked "$FILE_PATH_REL"; then
        exit 0
      fi
      echo "BLOCKED: executing-plans-p2r 串行降级模式下，主线程仍禁止写入管理目录（docs/.claude/hooks/scripts/skills）。尝试写入: $FILE_PATH_NORM" >&2
      exit 2
    fi

    is_orchestrator_allowed "$FILE_PATH_REL" "$FILE_PATH_NORM" || {
      echo "BLOCKED: 编排器(主线程) 仅能写入编排白名单路径（docs/*、.tmp、prompt.md、metadata.draft.json、questions.md）。源码路由到 Implementer。尝试写入: $FILE_PATH_NORM" >&2
      exit 2
    }
    ;;

  # 未知角色: 只读
  *)
    echo "BLOCKED: Agent '$AGENT_TYPE' 没有写入权限。尝试写入: $FILE_PATH_NORM" >&2
    exit 2
    ;;
esac

exit 0
