      
#!/usr/bin/env python3
"""
将 Claude 主会话 JSONL 与同 session 的 subagents JSONL 按时序合并为 trajectory.json。

参数说明（简版）:
- -r / --root: 输入目录。可选；传了就先扫该目录。
- -s / --session-id: 只处理指定 sessionId。可选。
- -o / --output-dir: 输出目录。可选；默认当前运行目录。

回退路径定位（重点）:
- 回退根目录固定为: ~/.claude/projects/-<路径编码>
- 路径编码规则: 把“基准路径”的绝对路径按 / 切分，再用 - 拼接，并在最前面加一个 -
- 基准路径:
  - 传了 -r: 基准路径就是 -r 的绝对路径
  - 没传 -r: 基准路径就是当前运行工作目录(Path.cwd())
- 示例:
  - -r /Users/mind/data/code/TASK-20260323-381236
  - 回退目录 = ~/.claude/projects/-Users-mind-data-code-TASK-20260323-381236

执行逻辑（简版）:
- subagents 可选：有则合并，没有则只转换主 session。
- 传了 -r: 先用 -r，再按 sessionId 级别用回退目录补充/兜底。
- 没传 -r: 只扫描回退目录。
- 多 session 输出为 trajectory-N.json（按源 jsonl 创建时间排序）。
- 单 session 输出为 trajectory.json。
"""

from __future__ import annotations

import argparse
import json
from copy import deepcopy
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

@dataclass
class ClaudeConverterOptions:
    """Claude 转换器选项配置"""
    include_thinking: bool = True
    include_toolcall_content: bool = True
    include_token_count: bool = True
    messages_only: bool = False


@dataclass
class ClaudeConverterState:
    """Claude 转换器状态"""
    session_id: str | None = None
    token_counts: list = field(default_factory=list)
    session_meta: dict = field(default_factory=dict)
    skipped_events: list = field(default_factory=list)


def convert_claude_jsonl_to_messages(
    events: list[dict[str, Any]],
    *,
    options: ClaudeConverterOptions,
) -> dict:
    """将 Claude session JSONL 转换为 OpenAI 消息格式"""
    state = ClaudeConverterState()
    messages: list = []

    for obj in events:
        event_type = obj.get("type")
        timestamp = obj.get("timestamp")

        # 提取 session 元数据
        if event_type == "user" and state.session_id is None:
            state.session_id = obj.get("sessionId")
            state.session_meta = {
                "session_id": obj.get("sessionId"),
                "version": obj.get("version"),
                "git_branch": obj.get("gitBranch"),
                "cwd": obj.get("cwd"),
            }

        # 处理用户消息
        if event_type == "user":
            message = obj.get("message", {})
            role = message.get("role")
            content = message.get("content")

            if role == "user" and isinstance(content, str):
                user_msg = {
                    "role": "user",
                    "content": [{"type": "text", "text": content}],
                }
                if timestamp:
                    user_msg["_metadata"] = {"timestamp": timestamp}
                messages.append(user_msg)
            elif role == "user" and isinstance(content, list):
                # 处理工具结果
                user_msg = {
                    "role": "user",
                    "content": []
                }
                for item in content:
                    if isinstance(item, dict):
                        if item.get("type") == "tool_result":
                            tool_msg = {
                                "role": "tool",
                                "tool_call_id": item.get("tool_use_id", ""),
                                "content": [{"type": "tool_output", "text": item.get("content", "")}]
                            }
                            if timestamp:
                                tool_msg["_metadata"] = {"timestamp": timestamp}
                            messages.append(tool_msg)
                        else:
                            user_msg["content"].append(item)

                # 如果有非工具结果的内容，添加用户消息
                if user_msg["content"]:
                    if timestamp:
                        user_msg["_metadata"] = {"timestamp": timestamp}
                    messages.append(user_msg)

        # 处理助手消息
        elif event_type == "assistant":
            message = obj.get("message", {})
            role = message.get("role")
            content = message.get("content")
            usage = message.get("usage")

            if role == "assistant" and isinstance(content, list):
                assistant_msg = {
                    "role": "assistant",
                    "content": [],
                }

                tool_calls = []

                for item in content:
                    if not isinstance(item, dict):
                        continue

                    item_type = item.get("type")

                    # 处理思考过程
                    if item_type == "thinking" and options.include_thinking:
                        thinking_text = item.get("thinking", "")
                        if thinking_text:
                            assistant_msg["content"].append({
                                "type": "reasoning",
                                "text": thinking_text
                            })

                    # 处理文本内容
                    elif item_type == "text":
                        text_part = item.get("text", "")
                        if text_part:
                            assistant_msg["content"].append({
                                "type": "text",
                                "text": text_part
                            })

                    # 处理工具调用
                    elif item_type == "tool_use":
                        tool_id = item.get("id", "")
                        tool_name = item.get("name", "")
                        tool_input = item.get("input", {})

                        tool_call = {
                            "id": tool_id,
                            "type": "function",
                            "function": {
                                "name": tool_name,
                                "arguments": json.dumps(tool_input, ensure_ascii=False)
                            }
                        }
                        tool_calls.append(tool_call)

                        # 可选：在 content 中也包含工具调用信息
                        if options.include_toolcall_content:
                            assistant_msg["content"].append({
                                "type": "tool_call",
                                "tool_call_id": tool_id,
                                "name": tool_name,
                                "arguments": json.dumps(tool_input, ensure_ascii=False)
                            })

                # 添加工具调用字段
                if tool_calls:
                    assistant_msg["tool_calls"] = tool_calls

                # 添加时间戳和元数据
                if timestamp:
                    assistant_msg["_metadata"] = {"timestamp": timestamp}

                # 只有当消息有内容或工具调用时才添加
                if assistant_msg["content"] or tool_calls:
                    messages.append(assistant_msg)

                # 收集 token 统计信息
                if usage and options.include_token_count:
                    token_entry = {
                        "type": "token_count",
                        "info": {
                            "total_token_usage": {
                                "input_tokens": usage.get("input_tokens", 0),
                                "cached_input_tokens": usage.get("cache_read_input_tokens", 0),
                                "output_tokens": usage.get("output_tokens", 0),
                                "total_tokens": usage.get("input_tokens", 0) + usage.get("output_tokens", 0)
                            },
                            "last_token_usage": {
                                "input_tokens": usage.get("input_tokens", 0),
                                "cached_input_tokens": usage.get("cache_read_input_tokens", 0),
                                "output_tokens": usage.get("output_tokens", 0),
                                "total_tokens": usage.get("input_tokens", 0) + usage.get("output_tokens", 0)
                            }
                        },
                        "rate_limits": {
                            "primary": None,
                            "secondary": None,
                            "credits": None,
                            "plan_type": None
                        }
                    }
                    if timestamp:
                        token_entry["_timestamp"] = timestamp
                    state.token_counts.append(token_entry)

        # 记录其他类型的事件
        elif event_type in ("progress", "system", "file-history-snapshot"):
            if options.include_token_count:
                state.skipped_events.append({
                    "type": event_type,
                    "timestamp": timestamp,
                    "data": obj.get("data") or obj.get("subtype")
                })

    result: dict = {"messages": messages}
    if not options.messages_only:
        result["meta"] = {
            "session_meta": state.session_meta,
            "token_counts": state.token_counts if options.include_token_count else None,
            "skipped_events_count": len(state.skipped_events),
            "skipped_events": state.skipped_events[:10] if state.skipped_events else []
        }

    return result


@dataclass
class AgentMapping:
    agent_id: str
    meta: dict[str, Any]
    subagent_prompt: str | None
    subagent_start_timestamp: str | None
    mapped_tool_use_id: str | None
    mapped_by: str | None
    verification: dict[str, Any]


@dataclass
class SessionSource:
    session_id: str
    session_jsonl: Path
    session_dir: Path
    source_root: Path
    has_subagents: bool


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"Invalid JSON at {path}:{line_no}") from exc
            if not isinstance(obj, dict):
                raise ValueError(f"Expected object at {path}:{line_no}")
            events.append(obj)
    return events


def parse_iso8601(ts: str | None) -> datetime | None:
    if not ts or not isinstance(ts, str):
        return None
    try:
        if ts.endswith("Z"):
            return datetime.fromisoformat(ts[:-1] + "+00:00")
        dt = datetime.fromisoformat(ts)
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def message_timestamp(msg: dict[str, Any]) -> str | None:
    meta = msg.get("_metadata")
    if isinstance(meta, dict) and isinstance(meta.get("timestamp"), str):
        return meta.get("timestamp")
    return None


def sort_messages_by_timestamp(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    decorated: list[tuple[int, datetime, int, dict[str, Any]]] = []
    far_future = datetime.max.replace(tzinfo=timezone.utc)

    for idx, msg in enumerate(messages):
        ts = message_timestamp(msg)
        dt = parse_iso8601(ts)
        if dt is None:
            decorated.append((1, far_future, idx, msg))
        else:
            decorated.append((0, dt, idx, msg))

    decorated.sort(key=lambda x: (x[0], x[1], x[2]))
    return [item[3] for item in decorated]


def encode_abs_path_for_claude_projects(input_path: Path) -> str:
    abs_posix = input_path.resolve().as_posix()
    parts = [p for p in abs_posix.split("/") if p]
    return "-" + "-".join(parts) if parts else "-"


def fallback_root_for_input(input_root: Path) -> Path:
    encoded = encode_abs_path_for_claude_projects(input_root)
    return Path.home() / ".claude" / "projects" / encoded


def _candidate_jsonl_files(root: Path, session_id: str | None) -> list[Path]:
    if session_id:
        p = root / f"{session_id}.jsonl"
        return [p] if p.exists() else []
    return sorted(root.glob("*.jsonl"))


def list_session_sources(root: Path, session_id: str | None = None) -> dict[str, SessionSource]:
    if not root.exists() or not root.is_dir():
        return {}

    out: dict[str, SessionSource] = {}
    for session_jsonl in _candidate_jsonl_files(root, session_id):
        sid = session_jsonl.stem
        session_dir = root / sid
        subagents_dir = session_dir / "subagents"
        has_subagents = subagents_dir.is_dir() and any(subagents_dir.glob("agent-*.jsonl"))
        out[sid] = SessionSource(
            session_id=sid,
            session_jsonl=session_jsonl,
            session_dir=session_dir,
            source_root=root,
            has_subagents=bool(has_subagents),
        )
    return out


def choose_session_source(primary: SessionSource | None, fallback: SessionSource | None) -> SessionSource | None:
    """
    选择优先级:
    1) primary 且有 subagents
    2) fallback 且有 subagents
    3) primary (仅主会话)
    4) fallback (仅主会话)
    """
    if primary and primary.has_subagents:
        return primary
    if fallback and fallback.has_subagents:
        return fallback
    if primary:
        return primary
    if fallback:
        return fallback
    return None


def resolve_session_sources(
    root_arg: Path | None,
    session_id: str | None,
) -> tuple[list[SessionSource], Path | None, Path, bool]:
    """
    返回:
    - 选定会话列表
    - primary_root
    - fallback_root
    - 是否使用了 fallback 作为至少一个会话来源
    """
    primary_root = root_arg.resolve() if root_arg else None
    base_for_fallback = primary_root if primary_root else Path.cwd().resolve()
    fallback_root = fallback_root_for_input(base_for_fallback)

    primary_map = list_session_sources(primary_root, session_id=session_id) if primary_root else {}
    fallback_map = list_session_sources(fallback_root, session_id=session_id)

    all_ids = sorted(set(primary_map.keys()) | set(fallback_map.keys()))
    chosen: list[SessionSource] = []
    used_fallback = False

    for sid in all_ids:
        source = choose_session_source(primary_map.get(sid), fallback_map.get(sid))
        if source is None:
            continue
        if source.source_root == fallback_root:
            used_fallback = True
        chosen.append(source)

    return chosen, primary_root, fallback_root, used_fallback


def _file_create_time(path: Path) -> float:
    try:
        return path.stat().st_ctime
    except Exception:
        return float("inf")


def assign_output_paths(
    sessions: list[SessionSource],
    output_dir: Path,
    force_single_name: bool = False,
) -> list[tuple[SessionSource, Path]]:
    ordered = sorted(sessions, key=lambda s: (_file_create_time(s.session_jsonl), s.session_jsonl.name))

    output_dir.mkdir(parents=True, exist_ok=True)
    multiple = len(ordered) > 1 and not force_single_name

    out: list[tuple[SessionSource, Path]] = []
    for idx, session in enumerate(ordered, start=1):
        filename = f"trajectory-{idx}.json" if multiple else "trajectory.json"
        out.append((session, output_dir / filename))
    return out


def extract_main_agent_link_data(
    main_events: list[dict[str, Any]],
) -> tuple[
    dict[str, dict[str, Any]],
    dict[str, dict[str, Any]],
    dict[str, dict[str, Any]],
]:
    tool_use_by_id: dict[str, dict[str, Any]] = {}
    progress_by_agent: dict[str, dict[str, Any]] = {}
    tool_result_by_agent: dict[str, dict[str, Any]] = {}

    for event in main_events:
        etype = event.get("type")

        if etype == "assistant":
            message = event.get("message", {})
            content = message.get("content")
            if not isinstance(content, list):
                continue

            for item in content:
                if not isinstance(item, dict):
                    continue
                if item.get("type") != "tool_use" or item.get("name") != "Agent":
                    continue
                tool_use_id = item.get("id")
                if not isinstance(tool_use_id, str) or not tool_use_id:
                    continue
                tool_use_by_id[tool_use_id] = {
                    "tool_use_id": tool_use_id,
                    "assistant_uuid": event.get("uuid"),
                    "assistant_timestamp": event.get("timestamp"),
                    "input": item.get("input") if isinstance(item.get("input"), dict) else {},
                }

        elif etype == "progress":
            data = event.get("data")
            if not isinstance(data, dict) or data.get("type") != "agent_progress":
                continue
            agent_id = data.get("agentId")
            if not isinstance(agent_id, str) or not agent_id:
                continue
            progress_by_agent[agent_id] = {
                "agent_id": agent_id,
                "progress_timestamp": event.get("timestamp"),
                "parent_tool_use_id": event.get("parentToolUseID"),
                "tool_use_id": event.get("toolUseID"),
                "embedded_message": data.get("message") if isinstance(data.get("message"), dict) else {},
            }

        elif etype == "user":
            tool_result = event.get("toolUseResult")
            if not isinstance(tool_result, dict):
                continue
            agent_id = tool_result.get("agentId")
            if not isinstance(agent_id, str) or not agent_id:
                continue

            tool_use_id = None
            message = event.get("message")
            if isinstance(message, dict) and isinstance(message.get("content"), list):
                for item in message["content"]:
                    if isinstance(item, dict) and item.get("type") == "tool_result":
                        tool_use_id = item.get("tool_use_id")
                        break

            tool_result_by_agent[agent_id] = {
                "agent_id": agent_id,
                "user_timestamp": event.get("timestamp"),
                "status": tool_result.get("status"),
                "duration_ms": tool_result.get("totalDurationMs"),
                "tool_use_id": tool_use_id,
            }

    return tool_use_by_id, progress_by_agent, tool_result_by_agent


def parse_subagent_prompt_and_start(sub_events: list[dict[str, Any]]) -> tuple[str | None, str | None]:
    for event in sub_events:
        if event.get("type") != "user":
            continue
        message = event.get("message")
        if not isinstance(message, dict):
            continue
        if message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, str):
            return content, event.get("timestamp")
    return None, None


def map_subagents(
    main_events: list[dict[str, Any]],
    subagents_dir: Path,
) -> tuple[list[AgentMapping], list[str]]:
    tool_use_by_id, progress_by_agent, tool_result_by_agent = extract_main_agent_link_data(main_events)
    mappings: list[AgentMapping] = []
    warnings: list[str] = []

    for sub_jsonl in sorted(subagents_dir.glob("agent-*.jsonl")):
        agent_id = sub_jsonl.stem.replace("agent-", "")
        meta_path = sub_jsonl.with_suffix(".meta.json")
        meta_obj: dict[str, Any] = {}
        if meta_path.exists():
            try:
                raw_meta = json.loads(meta_path.read_text(encoding="utf-8"))
                if isinstance(raw_meta, dict):
                    meta_obj = raw_meta
            except Exception as exc:
                warnings.append(f"{agent_id}: failed to read meta file ({exc})")

        sub_events = read_jsonl(sub_jsonl)
        sub_prompt, sub_start_ts = parse_subagent_prompt_and_start(sub_events)

        mapped_tool_use_id = None
        mapped_by = None

        progress = progress_by_agent.get(agent_id)
        if progress and isinstance(progress.get("parent_tool_use_id"), str):
            mapped_tool_use_id = progress["parent_tool_use_id"]
            mapped_by = "agent_progress.parentToolUseID"

        if mapped_tool_use_id is None:
            result_info = tool_result_by_agent.get(agent_id)
            if result_info and isinstance(result_info.get("tool_use_id"), str):
                mapped_tool_use_id = result_info["tool_use_id"]
                mapped_by = "tool_result.tool_use_id"

        if mapped_tool_use_id is None and sub_prompt:
            for tool_id, info in tool_use_by_id.items():
                prompt = (info.get("input") or {}).get("prompt")
                if isinstance(prompt, str) and prompt.strip() == sub_prompt.strip():
                    mapped_tool_use_id = tool_id
                    mapped_by = "prompt_text_match"
                    break

        tool_input = (tool_use_by_id.get(mapped_tool_use_id) or {}).get("input") or {}
        main_description = tool_input.get("description")
        main_prompt = tool_input.get("prompt")
        verification = {
            "description_match": bool(
                isinstance(main_description, str)
                and isinstance(meta_obj.get("description"), str)
                and main_description == meta_obj.get("description")
            ),
            "prompt_match": bool(
                isinstance(main_prompt, str)
                and isinstance(sub_prompt, str)
                and main_prompt.strip() == sub_prompt.strip()
            ),
            "result_tool_use_match": bool(
                mapped_tool_use_id is not None
                and tool_result_by_agent.get(agent_id, {}).get("tool_use_id") == mapped_tool_use_id
            ),
        }

        mappings.append(
            AgentMapping(
                agent_id=agent_id,
                meta=meta_obj,
                subagent_prompt=sub_prompt,
                subagent_start_timestamp=sub_start_ts,
                mapped_tool_use_id=mapped_tool_use_id,
                mapped_by=mapped_by,
                verification=verification,
            )
        )

    return mappings, warnings


def convert_main_messages(main_events: list[dict[str, Any]]) -> dict[str, Any]:
    options = ClaudeConverterOptions(messages_only=False)
    return convert_claude_jsonl_to_messages(main_events, options=options)


def convert_subagent_messages(sub_events: list[dict[str, Any]], role_name: str) -> list[dict[str, Any]]:
    options = ClaudeConverterOptions(messages_only=False)
    converted = convert_claude_jsonl_to_messages(sub_events, options=options)
    out: list[dict[str, Any]] = []

    for msg in converted.get("messages", []):
        if not isinstance(msg, dict):
            continue
        if msg.get("role") not in {"assistant", "tool", "user"}:
            continue

        mapped = deepcopy(msg)
        original_role = mapped.get("role")
        mapped["role"] = role_name

        metadata = mapped.get("_metadata")
        if not isinstance(metadata, dict):
            metadata = {}
            mapped["_metadata"] = metadata
        metadata["source"] = "subagent"
        metadata["original_role"] = original_role

        out.append(mapped)

    return out


def merge_single_session(source: SessionSource, output_path: Path) -> None:
    main_events = read_jsonl(source.session_jsonl)
    main_result = convert_main_messages(main_events)
    main_messages = main_result.get("messages", [])

    warnings: list[str] = []
    mappings: list[AgentMapping] = []
    subagent_messages: list[dict[str, Any]] = []

    subagents_dir = source.session_dir / "subagents"
    if subagents_dir.is_dir() and any(subagents_dir.glob("agent-*.jsonl")):
        mappings, sub_warnings = map_subagents(main_events, subagents_dir)
        warnings.extend(sub_warnings)

        for mapping in mappings:
            sub_jsonl = subagents_dir / f"agent-{mapping.agent_id}.jsonl"
            if not sub_jsonl.exists():
                continue
            sub_events = read_jsonl(sub_jsonl)
            role_name = f"assistant-subagent-{mapping.agent_id}"
            subagent_messages.extend(convert_subagent_messages(sub_events, role_name=role_name))

    merged_messages = sort_messages_by_timestamp([*main_messages, *subagent_messages])

    meta = main_result.get("meta") if isinstance(main_result.get("meta"), dict) else {}
    mapping_dicts = [
        {
            "agent_id": m.agent_id,
            "agent_type": m.meta.get("agentType"),
            "description": m.meta.get("description"),
            "subagent_prompt": m.subagent_prompt,
            "subagent_start_timestamp": m.subagent_start_timestamp,
            "mapped_tool_use_id": m.mapped_tool_use_id,
            "mapped_by": m.mapped_by,
            "verification": m.verification,
        }
        for m in mappings
    ]
    meta["subagents"] = mapping_dicts
    meta["merge_warnings"] = warnings
    meta["merge_stats"] = {
        "main_messages": len(main_messages),
        "subagent_messages": len(subagent_messages),
        "merged_messages": len(merged_messages),
        "subagent_count": len(mappings),
        "has_subagents": source.has_subagents,
        "source_root": str(source.source_root),
    }

    result = {"messages": merged_messages, "meta": meta}
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge Claude main session + optional subagents into trajectory.json"
    )
    parser.add_argument(
        "-r",
        "--root",
        type=Path,
        default=None,
        help="输入目录：包含 <sessionId>.jsonl（subagents 可选）",
    )
    parser.add_argument(
        "-s",
        "--session-id",
        type=str,
        default=None,
        help="仅处理指定 session id",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=None,
        help="输出目录（默认当前运行目录）",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root_arg = args.root.expanduser() if args.root else None

    sessions, primary_root, fallback_root, used_fallback = resolve_session_sources(
        root_arg=root_arg,
        session_id=args.session_id,
    )

    if args.root is None:
        print(f"[INFO] --root not provided, scanning fallback path: {fallback_root}")

    if used_fallback:
        print(f"[INFO] fallback source used: {fallback_root}")

    if not sessions:
        if primary_root:
            print(f"[WARN] no session jsonl found under: {primary_root}")
        print(f"[WARN] no session jsonl found under fallback: {fallback_root}")
        return 1

    output_dir = args.output_dir.expanduser().resolve() if args.output_dir else Path.cwd()

    if args.session_id:
        job = sessions[0]
        output_file = output_dir / "trajectory.json"
        merge_single_session(job, output_file)
        print(f"[OK] {job.session_id} -> {output_file}")
        return 0

    jobs = assign_output_paths(sessions, output_dir)
    ok = 0
    failed = 0

    for source, output_file in jobs:
        try:
            merge_single_session(source, output_file)
            print(
                f"[OK] {source.session_id} -> {output_file} "
                f"(subagents={'yes' if source.has_subagents else 'no'})"
            )
            ok += 1
        except Exception as exc:
            print(f"[FAIL] {source.session_id}: {exc}")
            failed += 1

    print(f"done: ok={ok}, failed={failed}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())

    