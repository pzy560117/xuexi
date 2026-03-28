      
#!/usr/bin/env python3
"""Static delivery package validator.

Usage:
  python validate_package.py /path/to/TASK-001
  python validate_package.py TASK-001
"""

from __future__ import annotations

import argparse
import difflib
import fnmatch
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Iterable

PROJECT_TYPE_ALIASES = {
    "fullstack": {
        "fullstack",
        "full_stack",
        "full-stack",
        "full stack",
        "fullstack_app",
        "full-stack-app",
        "full_stack_app",
    },
    "pure_backend": {
        "pure_backend",
        "pure-backend",
        "pure backend",
        "purebackend",
        "backend_only",
        "backend-only",
        "backend only",
    },
    "pure_frontend": {
        "pure_frontend",
        "pure-frontend",
        "pure frontend",
        "purefrontend",
        "frontend_only",
        "frontend-only",
        "frontend only",
    },
    "cross_platform_app": {
        "cross_platform_app",
        "cross-platform-app",
        "cross platform app",
        "crossplatformapp",
        "cross_platform",
        "cross-platform",
        "cross platform",
        "crossplatform",
        "multi_platform_app",
        "multiplatform_app",
        "multi-platform-app",
        "multiplatform",
    },
    "mobile_app": {
        "mobile_app",
        "mobile-app",
        "mobile app",
        "mobileapp",
        "mobile",
        "app_mobile",
        "app-mobile",
        "app mobile",
    },
}


def _normalize_project_type_token(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def _build_project_type_lookup() -> dict[str, str]:
    lookup: dict[str, str] = {}
    for canonical, aliases in PROJECT_TYPE_ALIASES.items():
        all_tokens = set(aliases)
        all_tokens.add(canonical)
        for token in all_tokens:
            normalized = _normalize_project_type_token(token)
            existing = lookup.get(normalized)
            if existing is not None and existing != canonical:
                raise ValueError(
                    f"project type alias conflict: '{token}' -> {canonical}, already mapped to {existing}"
                )
            lookup[normalized] = canonical
    return lookup


PROJECT_TYPE_LOOKUP = _build_project_type_lookup()
ALLOWED_PROJECT_TYPES = set(PROJECT_TYPE_ALIASES.keys())

BACKEND_KEYWORDS = ("backend", "server", "api", "service")
BACKEND_MARKER_FILES = {
    "requirements.txt",
    "pyproject.toml",
    "pom.xml",
    "build.gradle",
    "go.mod",
    "composer.json",
    "cargo.toml",
}

CHINESE_RE = re.compile(r"[\u4e00-\u9fff]")
TRAJECTORY_MULTI_RE = re.compile(r"trajectory[-_]\d+\.json$", re.IGNORECASE)
PROMPT_ENGLISH_RATIO_THRESHOLD = 0.70

SKIP_LANGUAGE_CHECK_EXTS = {
    ".zip",
    ".rar",
    ".7z",
    ".tar",
    ".gz",
    ".db",
    ".sqlite",
    ".sqlite3",
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".ico",
    ".pdf",
    ".docx",
    ".xlsx",
    ".pptx",
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".class",
    ".jar",
    ".o",
    ".obj",
    ".a",
}

ROOT_ALLOWED_FILES = {
    "prompt.md",
    "questions.md",
    "metadata.json",
    ".gitignore",
}

ROOT_REQUIRED_FILES = (
    "prompt.md",
    "questions.md",
    "metadata.json",
)

ROOT_REQUIRED_FILE_TYPO_ALIASES = {
    "prompt.md": {
        "prompts.md",
        "prompt.mdown",
        "prompts.mdown",
        "prompt.markdown",
        "promts.md",
        "promot.md",
    },
    "questions.md": {
        "question.md",
        "questions.mdown",
        "question.markdown",
        "quesitons.md",
        "questionn.md",
        "questionss.md",
    },
    "metadata.json": {
        "metadatas.json",
        "meta-data.json",
        "meta.json",
        "metainfo.json",
    },
    "trajectory.json": {
        "session.json",
        "sessions.json",
        "trajectorys.json",
        "trajectories.json",
        "trajactory.json",
        "trajectroy.json",
    },
}

ROOT_REQUIRED_DIR_TYPO_ALIASES = {
    "sessions": {
        "session",
        "sesions",
        "sessionss",
    }
}

ROOT_COMMON_FILE_TYPOS = {
    "prompts.md": "prompt.md",
    "prompts.mdown": "prompt.md",
    "prompt.markdown": "prompt.md",
    "question.md": "questions.md",
    "questions.mdown": "questions.md",
    "question.markdown": "questions.md",
    "metadatas.json": "metadata.json",
    "meta-data.json": "metadata.json",
    "meta.json": "metadata.json",
}

REPO_DIR_NAME = "repo"
METADATA_REQUIRED_KEYS = (
    "project_type",
    "frontend_tech",
    "backend_tech",
    "database",
)

PROJECT_TYPE_MISNAME_HINTS = {
    "backend": "pure_backend",
    "server": "pure_backend",
    "api": "pure_backend",
    "service": "pure_backend",
    "frontend": "pure_frontend",
    "web": "pure_frontend",
    "client": "pure_frontend",
    "crossplatform": "cross_platform_app",
    "crossplatformapp": "cross_platform_app",
    "mobile": "mobile_app",
    "appmobile": "mobile_app",
}

ENGLISH_CHECK_EXCLUDED_DIRS = {
    ".tmp",
    ".backup",
    ".git",
}

ENGLISH_CHECK_EXCLUDED_FILES = {
    ".gitignore",
    ".gitattributes",
    ".gitmodules",
}

ROOT_REPAIR_EXEMPT_ARCHIVE_EXTS = {
    ".zip",
    ".rar",
    ".7z",
    ".tar",
    ".gz",
}

REPAIR_GITIGNORE_HEADER = "# Added by validate_package --repair (exemptions)"
REPAIR_GITIGNORE_EXEMPT_PATTERNS = [
    ".tmp/",
    ".backup/",
    "*.zip",
    "*.rar",
    "*.7z",
    "*.tar",
    "*.gz",
]

UNIVERSAL_GITIGNORE_PATTERNS = [
    ".vscode/",
    ".idea/",
    ".codex/",
    ".opencode/",
]

LANGUAGE_GITIGNORE_PATTERNS = {
    "python": [
        "__pycache__/",
        "*.pyc",
        ".pytest_cache/",
        ".venv/",
        "venv/",
        ".mypy_cache/",
        ".ruff_cache/",
        ".coverage",
        "htmlcov/",
    ],
    "js_ts": [
        "node_modules/",
        "dist/",
        "build/",
        "coverage/",
        "*.tsbuildinfo",
        ".npm/",
        ".pnpm-store/",
        ".yarn/",
        ".next/",
    ],
    "java_kotlin": [
        "target/",
        "build/",
        ".gradle/",
        ".kotlin/",
        "out/",
        "*.class",
        "*.jar",
        "*.war",
    ],
    "go": [
        "bin/",
        "dist/",
        "coverage.out",
        "*.test",
    ],
    "php": ["vendor/"],
    "csharp": [
        "bin/",
        "obj/",
        "Debug/",
        "Release/",
        ".vs/",
        "TestResults/",
    ],
    "c_cpp": [
        "build/",
        "build-*/",
        "CMakeFiles/",
        "CMakeCache.txt",
        "cmake_install.cmake",
        "compile_commands.json",
        "*.o",
        "*.obj",
        "*.exe",
        "*.pdb",
    ],
    "rust": ["target/", "debug/", "*.pdb"],
    "dart_flutter": [
        ".dart_tool/",
        ".flutter-plugins",
        ".flutter-plugins-dependencies",
        "build/",
        ".gradle/",
        "android/local.properties",
    ],
    "ruby": [".bundle/", "vendor/bundle/", "vendor/cache/"],
}

DIR_VIOLATION_REASONS = {
    ".vscode": "为本地 IDE 配置目录",
    ".idea": "为本地 IDE 配置目录",
    ".codex": "为本地工具目录",
    ".opencode": "为本地工具目录",
    "__pycache__": "为 Python 缓存目录",
    "__pychache__": "为 Python 缓存目录（疑似 __pycache__ 拼写错误）",
    ".pytest_cache": "为 Python 缓存目录",
    ".venv": "为 Python 虚拟环境目录",
    "venv": "为 Python 虚拟环境目录",
    ".mypy_cache": "为 Python 缓存目录",
    ".ruff_cache": "为 Python 缓存目录",
    "htmlcov": "为 Python 覆盖率目录",
    "node_modules": "位于 Node 依赖目录",
    ".npm": "为 Node 本地缓存目录",
    ".pnpm-store": "为 Node 本地缓存目录",
    ".yarn": "为 Node 本地缓存目录",
    ".next": "为 Node 构建目录",
    "coverage": "为覆盖率产物目录",
    "dist": "为构建产物目录",
    "build": "为构建产物目录",
    "target": "为构建产物目录",
    ".gradle": "为 Gradle 本地目录",
    ".kotlin": "为 Kotlin 本地目录",
    "out": "为构建产物目录",
    "bin": "为构建产物目录",
    "obj": "为构建产物目录",
    "debug": "为构建产物目录",
    "release": "为构建产物目录",
    ".vs": "为 .NET 本地目录",
    "testresults": "为测试结果目录",
    "cmakefiles": "为 C/C++ 构建目录",
    ".dart_tool": "为 Dart/Flutter 本地缓存目录",
    ".bundle": "为 Ruby 本地依赖目录",
    "vendor": "为依赖目录",
}

COMPILE_EXEMPT_DIR_NAMES = {
    ".next",
    "dist",
    "build",
    "target",
    "out",
    "bin",
    "obj",
    "debug",
    "release",
    "cmakefiles",
}

COMPILE_EXEMPT_FILE_SUFFIXES = {
    ".class",
    ".jar",
    ".war",
    ".o",
    ".obj",
    ".exe",
    ".pdb",
    ".test",
    ".tsbuildinfo",
}

COMPILE_EXEMPT_FILE_NAMES = {
    "cmakecache.txt",
    "cmake_install.cmake",
    "compile_commands.json",
}

FILE_VIOLATION_RULES = [
    (lambda p: p.suffix.lower() == ".pyc", "为 Python 缓存文件"),
    (lambda p: p.name.lower() == ".coverage", "为覆盖率文件"),
    (lambda p: p.name.lower() == "coverage.out", "为覆盖率文件"),
    (lambda p: p.suffix.lower() == ".test", "为测试二进制文件"),
    (lambda p: p.suffix.lower() in {".class", ".jar", ".war"}, "为 Java/Kotlin 构建产物"),
    (
        lambda p: p.name.lower() in {"cmakecache.txt", "cmake_install.cmake", "compile_commands.json"},
        "为 C/C++ 构建文件",
    ),
    (lambda p: p.suffix.lower() in {".o", ".obj", ".exe", ".pdb"}, "为二进制/构建产物文件"),
    (
        lambda p: p.name.lower() in {".flutter-plugins", ".flutter-plugins-dependencies"},
        "为 Flutter 本地工具文件",
    ),
    (
        lambda p: p.as_posix().lower().endswith("android/local.properties"),
        "为 Android 本地配置文件",
    ),
    (lambda p: p.suffix.lower() in {".db", ".sqlite", ".sqlite3"}, "为本地数据库文件"),
    (lambda p: p.suffix.lower() == ".tsbuildinfo", "为 TypeScript 构建缓存文件"),
    (lambda p: p.name.lower() == "session.json", "为不应交付文件（session.json）"),
    (
        lambda p: re.fullmatch(r"rollout-.*\.jsonl", p.name.lower()) is not None,
        "为不应交付文件（rollout-*.jsonl）",
    ),
]


@dataclass
class CheckItem:
    status: str
    message: str
    rel_path: str


@dataclass
class CheckSection:
    title: str
    items: list[CheckItem] = field(default_factory=list)

    def add_pass(self, message: str, rel_path: str) -> None:
        self.items.append(CheckItem("PASS", message, rel_path))

    def add_fail(self, message: str, rel_path: str) -> None:
        self.items.append(CheckItem("FAIL", message, rel_path))

    def add_warn(self, message: str, rel_path: str) -> None:
        self.items.append(CheckItem("WARN", message, rel_path))


@dataclass
class RepairAction:
    kind: str
    src: Path
    dst: Path | None
    reason: str


class PackageValidator:
    def __init__(self, input_identifier: str) -> None:
        self.input_identifier = input_identifier
        self.root: Path | None = None
        self.report_path: Path | None = None

        self.sections: list[CheckSection] = []
        self.error_count = 0

        self.project_type_name: str | None = None
        self.project_type_dir: Path | None = None
        self.metadata: dict[str, object] = {}
        self.legacy_project_dirs: list[tuple[str, Path]] = []

        self.backend_content: bool | None = None
        self.backend_reason: str = ""

        self.english_mode: bool = False
        self.languages: set[str] = set()
        self._gitignore_scopes_cache: list[tuple[Path, list[str]]] | None = None
        self._candidate_entries_cache: list[tuple[Path, bool, bool, str]] | None = None
        self._dirty_findings_cache: list[tuple[Path, str, str]] | None = None

    def _reset_run_state(self) -> None:
        self.sections = []
        self.error_count = 0
        self.project_type_name = None
        self.project_type_dir = None
        self.metadata = {}
        self.legacy_project_dirs = []
        self.backend_content = None
        self.backend_reason = ""
        self.english_mode = False
        self.languages = set()
        self._gitignore_scopes_cache = None
        self._candidate_entries_cache = None
        self._dirty_findings_cache = None

    def run(self) -> tuple[bool, int, Path]:
        self._reset_run_state()
        self._check_input_directory()
        if self.root is None:
            fallback_report = Path.cwd() / ".tmp" / "validation_report.md"
            self.report_path = fallback_report
            self._write_report()
            return False, self.error_count, fallback_report

        self.report_path = self.root / ".tmp" / "validation_report.md"

        self._check_root_fixed_files()
        self._check_repo_directory()
        self._check_trajectory_organization()
        self._check_metadata_file()
        self._check_docs_directory()
        self._check_prompt_english_mode()
        self._check_english_consistency()
        self._check_backend_content_recognition()
        self._check_backend_project_requirements()

        self._check_gitignore_exists()
        self._detect_languages()
        self._check_gitignore_coverage()
        self._check_local_dirty_files()

        self._write_report()
        return self.error_count == 0, self.error_count, self.report_path

    def run_repair(self) -> tuple[int, int, int, Path | None]:
        if self.root is None:
            print("REPAIR | 输入目录无效，跳过修复")
            return 0, 0, 0, None

        print("REPAIR | 正在生成修复计划（目录较大时可能耗时）...", flush=True)
        actions = self._plan_repair_actions()
        print(f"REPAIR | 修复计划生成完成，共 {len(actions)} 项", flush=True)
        if not actions:
            print("REPAIR | 无可执行修复操作")
            return 0, 0, 0, None

        print("REPAIR | 以下为拟执行操作（报告已先生成）:")
        self._print_repair_plan(actions)

        try:
            confirmation = input("确认执行以上修复操作吗？输入 YES 继续，其它任意输入取消: ").strip()
        except EOFError:
            confirmation = ""

        if confirmation.upper() != "YES":
            print("REPAIR | 已取消，未修改任何文件")
            return 0, len(actions), 0, None

        executed, skipped, failed, backup_dir = self._execute_repair_actions(actions)
        if backup_dir is None:
            print(f"REPAIR | executed={executed} skipped={skipped} failed={failed} | 未生成备份（无删除操作）")
        else:
            print(
                f"REPAIR | executed={executed} skipped={skipped} failed={failed} | backup={self._rel(backup_dir)}"
            )
        return executed, skipped, failed, backup_dir

    def run_convert_legacy(self) -> tuple[int, int, int, Path | None]:
        if self.root is None:
            print("CONVERT | 输入目录无效，跳过转换")
            return 0, 0, 0, None

        print("CONVERT | 正在生成旧结构迁移计划...", flush=True)
        actions = self._plan_convert_legacy_actions()
        print(f"CONVERT | 迁移计划生成完成，共 {len(actions)} 项", flush=True)
        if not actions:
            print("CONVERT | 无需迁移（未检测到可转换的旧结构）")
            return 0, 0, 0, None

        print("CONVERT | 以下为拟执行操作:")
        self._print_repair_plan(actions)

        try:
            confirmation = input("确认执行以上迁移操作吗？输入 YES 继续，其它任意输入取消: ").strip()
        except EOFError:
            confirmation = ""

        if confirmation.upper() != "YES":
            print("CONVERT | 已取消，未修改任何文件")
            return 0, len(actions), 0, None

        executed, skipped, failed, backup_dir = self._execute_repair_actions(actions, backup_on_move=True)
        if backup_dir is None:
            print(f"CONVERT | executed={executed} skipped={skipped} failed={failed} | 未生成备份")
        else:
            print(
                f"CONVERT | executed={executed} skipped={skipped} failed={failed} | backup={self._rel(backup_dir)}"
            )
        return executed, skipped, failed, backup_dir

    def _plan_repair_actions(self) -> list[RepairAction]:
        assert self.root is not None
        root = self.root
        actions: list[RepairAction] = []
        move_sources: set[Path] = set()
        delete_paths: set[Path] = set()
        move_dests: set[Path] = set()

        def _abs(path: Path) -> Path:
            try:
                return path.resolve()
            except OSError:
                return path.absolute()

        def _add_move(src: Path, dst: Path, reason: str) -> None:
            src_abs = _abs(src)
            dst_abs = _abs(dst)
            if src_abs == dst_abs:
                return
            if src_abs in move_sources or src_abs in delete_paths:
                return
            if dst_abs in move_dests:
                return

            kind = "rename" if src_abs.parent == dst_abs.parent else "move"
            action = RepairAction(kind=kind, src=src_abs, dst=dst_abs, reason=reason)
            actions.append(action)
            move_sources.add(src_abs)
            move_dests.add(dst_abs)

        def _add_delete(path: Path, reason: str) -> None:
            path_abs = _abs(path)
            if path_abs == root:
                return
            if path_abs in move_sources or path_abs in delete_paths:
                return
            actions.append(RepairAction(kind="delete", src=path_abs, dst=None, reason=reason))
            delete_paths.add(path_abs)

        # 0) 根目录 .gitignore：写入豁免规则（.tmp/.backup/压缩包类型）。
        actions.append(
            RepairAction(
                kind="update_gitignore",
                src=_abs(root / ".gitignore"),
                dst=None,
                reason="在根目录 .gitignore 写入豁免规则（.tmp/.backup/压缩包）",
            )
        )

        # 0.1) 代码目录下 .tmp 合并到根目录 .tmp，并删除源目录。
        if self.project_type_dir is not None:
            scoped_tmp = self.project_type_dir / ".tmp"
            if scoped_tmp.is_dir():
                actions.append(
                    RepairAction(
                        kind="merge_tmp_dir",
                        src=_abs(scoped_tmp),
                        dst=_abs(root / ".tmp"),
                        reason="将代码目录下 .tmp 内容迁移到根目录 .tmp，并删除原目录",
                    )
                )
                _add_delete(
                    scoped_tmp,
                    "清理代码目录下 .tmp 残留（合并后；若不存在将自动跳过）",
                )

        # 1) 根目录必要文件：位置/命名修复，重复与错位删除。
        for required in ROOT_REQUIRED_FILES:
            correct, misplaced, typos = self._collect_required_file_candidates(
                required,
                ROOT_REQUIRED_FILE_TYPO_ALIASES.get(required, set()),
            )
            destination = root / required

            if correct:
                for duplicate in correct[1:]:
                    _add_delete(duplicate, f"{required} 根目录重复，保留一份")
                for wrong in misplaced:
                    _add_delete(wrong, f"{required} 位置错误，根目录已有正确文件")
                for typo in typos:
                    _add_delete(typo, f"{typo.name} 命名错误，根目录已有正确 {required}")
            else:
                candidates = misplaced + typos
                if candidates:
                    selected = candidates[0]
                    _add_move(selected, destination, f"修复 {required} 的位置/命名")
                    for redundant in candidates[1:]:
                        _add_delete(redundant, f"{required} 候选重复，保留首个修复来源")

        # 1.1) metadata.json 字段补齐（缺失时创建，已有时补全空字段）。
        actions.append(
            RepairAction(
                kind="upsert_metadata",
                src=_abs(root / "metadata.json"),
                dst=None,
                reason="补齐 metadata.json 必需字段",
            )
        )

        # 2) 代码目录 repo 修复（兼容旧结构目录）。
        repo_dir = root / REPO_DIR_NAME
        legacy_dirs = list(self.legacy_project_dirs)
        if not repo_dir.is_dir():
            repo_candidates: list[Path] = [path for _, path in legacy_dirs]
            if self.project_type_dir is not None and self.project_type_dir not in repo_candidates:
                repo_candidates.append(self.project_type_dir)
            repo_candidates = sorted(repo_candidates, key=lambda p: p.name.lower())
            if repo_candidates:
                selected = repo_candidates[0]
                _add_move(selected, repo_dir, "修复代码目录命名/位置为 repo/")
                for redundant in repo_candidates[1:]:
                    _add_delete(redundant, "多余旧结构代码目录，保留一份迁移来源")
        else:
            for _, legacy_dir in legacy_dirs:
                _add_delete(legacy_dir, "旧结构代码目录冗余，已存在 repo/")

        # 3) trajectory 组织修复（统一迁移到 sessions/）。
        traj_root, traj_misplaced, traj_typos = self._collect_required_file_candidates(
            "trajectory.json",
            ROOT_REQUIRED_FILE_TYPO_ALIASES.get("trajectory.json", set()),
        )
        sessions_correct, sessions_misplaced, sessions_typos = self._collect_required_dir_candidates(
            "sessions",
            ROOT_REQUIRED_DIR_TYPO_ALIASES.get("sessions", set()),
        )
        sessions_dir = root / "sessions"

        if sessions_correct:
            for duplicate in sessions_correct[1:]:
                _add_delete(duplicate, "sessions/ 根目录重复，保留一份")
            for wrong in sessions_misplaced:
                _add_delete(wrong, "sessions/ 位置错误，根目录已有正确目录")
            for typo in sessions_typos:
                _add_delete(typo, f"{typo.name}/ 命名错误，根目录已有正确 sessions/")
        else:
            candidates = sessions_misplaced + sessions_typos
            if candidates:
                selected = candidates[0]
                _add_move(selected, sessions_dir, "修复 sessions/ 到根目录")
                for redundant in candidates[1:]:
                    _add_delete(redundant, "sessions/ 候选重复，保留首个修复来源")

        def _next_sessions_trajectory_target(prefer_single: bool = False) -> Path:
            if prefer_single:
                preferred = sessions_dir / "trajectory.json"
                if _abs(preferred) not in move_dests and not preferred.exists():
                    return preferred

            used_numbers: set[int] = set()
            if sessions_dir.is_dir():
                for entry in sessions_dir.iterdir():
                    if not entry.is_file():
                        continue
                    name_lower = entry.name.lower()
                    m = re.fullmatch(r"trajectory[-_](\d+)\.json", name_lower)
                    if m:
                        used_numbers.add(int(m.group(1)))
                if (sessions_dir / "trajectory.json").is_file() or _abs(sessions_dir / "trajectory.json") in move_dests:
                    used_numbers.add(0)
            for dst in move_dests:
                try:
                    rel = dst.relative_to(sessions_dir)
                except ValueError:
                    continue
                name_lower = rel.name.lower()
                if name_lower == "trajectory.json":
                    used_numbers.add(0)
                m = re.fullmatch(r"trajectory[-_](\d+)\.json", name_lower)
                if m:
                    used_numbers.add(int(m.group(1)))

            if 0 not in used_numbers:
                return sessions_dir / "trajectory.json"
            idx = 1
            while idx in used_numbers:
                idx += 1
            return sessions_dir / f"trajectory-{idx}.json"

        root_multi = [
            p
            for p in root.iterdir()
            if p.is_file() and TRAJECTORY_MULTI_RE.fullmatch(p.name.lower()) is not None
        ]
        root_multi.sort(key=lambda p: p.name.lower())

        trajectory_sources: list[tuple[Path, str]] = []
        trajectory_sources.extend((p, "根目录 trajectory.json 应迁移到 sessions/") for p in traj_root)
        trajectory_sources.extend((p, "错位 trajectory.json 应迁移到 sessions/") for p in traj_misplaced)
        trajectory_sources.extend((p, f"{p.name} 命名错误，修复为 sessions/trajectory*.json") for p in traj_typos)
        trajectory_sources.extend((p, "根目录 trajectory-N/trajectory_N 应迁移到 sessions/") for p in root_multi)

        for src, reason in trajectory_sources:
            prefer_single = src.name.lower() == "trajectory.json"
            target = _next_sessions_trajectory_target(prefer_single=prefer_single)
            _add_move(src, target, reason)

        # 4) docs 目录位置修复。
        docs_dir = root / "docs"
        _, misplaced_docs, typo_docs = self._collect_required_dir_candidates(
            "docs",
            {"doc", "document", "documents"},
        )
        if docs_dir.is_dir():
            for wrong in misplaced_docs:
                _add_delete(wrong, "docs/ 错位重复，根目录已有正确 docs/")
            for typo in typo_docs:
                _add_delete(typo, f"{typo.name}/ 命名错误，应为 docs/")
        else:
            if misplaced_docs:
                selected = misplaced_docs[0]
                _add_move(selected, docs_dir, "修复 docs/ 到根目录")
                for redundant in misplaced_docs[1:]:
                    _add_delete(redundant, "docs/ 候选重复，保留首个修复来源")
                for typo in typo_docs:
                    _add_delete(typo, f"{typo.name}/ 命名错误，已使用 docs/ 候选修复")
            elif typo_docs:
                selected = typo_docs[0]
                _add_move(selected, docs_dir, "修复 docs/ 命名并移动到根目录")
                for redundant in typo_docs[1:]:
                    _add_delete(redundant, "docs/ 命名候选重复，保留首个修复来源")

        # 5) repo/readme.md 位置/命名修复。
        project_dir_for_plan = repo_dir if repo_dir.exists() or _abs(repo_dir) in move_dests else self.project_type_dir
        repo_dir_move_src: Path | None = None
        repo_abs = _abs(repo_dir)
        for action in actions:
            if action.kind not in {"move", "rename"} or action.dst is None:
                continue
            if action.dst == repo_abs:
                repo_dir_move_src = action.src
                break

        skip_readme_relocate = (
            repo_dir_move_src is not None
            and self.project_type_dir is not None
            and repo_dir_move_src == _abs(self.project_type_dir)
        )

        if project_dir_for_plan is not None and not skip_readme_relocate:
            readmes_in_project = self._find_readme_files_in_project_dir(project_dir_for_plan)
            misplaced_readmes = self._find_readme_files_outside_project_dir(project_dir_for_plan, max_items=9999)
            typo_readmes = self._find_readme_typo_candidates(project_dir_for_plan, max_items=9999)
            readme_destination = project_dir_for_plan / "readme.md"

            if readmes_in_project:
                for duplicate in readmes_in_project[1:]:
                    _add_delete(duplicate, "readme.md 在代码目录下重复，保留一份")
                for wrong in misplaced_readmes:
                    _add_delete(wrong, "readme.md 位置错误，应位于 repo 目录")
                for typo in typo_readmes:
                    _add_delete(typo, f"{typo.name} 命名错误，repo 目录已有 readme.md")
            else:
                candidates = misplaced_readmes + typo_readmes
                if candidates:
                    selected = candidates[0]
                    _add_move(selected, readme_destination, "修复 readme.md 到 repo 目录")
                    for redundant in candidates[1:]:
                        _add_delete(redundant, "readme.md 候选重复，保留首个修复来源")

        # 6) 根目录额外文件清理（豁免仅影响执行，不影响提醒/计划）。
        for entry in root.iterdir():
            if not entry.is_file():
                continue
            if entry.name == "validation_report.md":
                continue
            if entry.name in ROOT_ALLOWED_FILES:
                continue
            _add_delete(entry, "删除根目录规范外文件")

        # 7) 修复模式下清理本地脏目录/文件（优先复用校验阶段结果，避免重复全盘扫描）。
        if self._dirty_findings_cache is not None:
            for path, reason, status in self._dirty_findings_cache:
                if status != "FAIL":
                    continue
                if path.is_dir():
                    _add_delete(path, f"删除本地脏目录：{reason}")
                else:
                    _add_delete(path, f"删除本地脏文件：{reason}")
        else:
            for current_root, dirs, files in os.walk(root, topdown=True):
                current_path = Path(current_root)
                pruned_dirs: list[str] = []

                for dirname in dirs:
                    lower_dir = dirname.lower()
                    if lower_dir in {".git", ".backup", ".tmp"}:
                        continue
                    dir_path = current_path / dirname
                    if self._is_ignored_by_any_gitignore(dir_path, treat_as_dir=True):
                        continue
                    reason = self._dir_violation_reason(dirname)
                    if reason:
                        if not self._is_compile_exempt_dir(dirname):
                            _add_delete(dir_path, f"删除本地脏目录：{reason}")
                    else:
                        pruned_dirs.append(dirname)
                dirs[:] = pruned_dirs

                for filename in files:
                    file_path = current_path / filename
                    if file_path.name == "validation_report.md":
                        continue
                    if self._is_ignored_by_any_gitignore(file_path):
                        continue
                    reason = self._file_violation_reason(file_path)
                    if reason and not self._is_compile_exempt_file(file_path):
                        _add_delete(file_path, f"删除本地脏文件：{reason}")

        # 删除动作去重：若父目录已删除，则子路径删除动作可省略。
        delete_roots: list[Path] = []
        normalized_actions: list[RepairAction] = []
        for action in actions:
            if action.kind != "delete":
                normalized_actions.append(action)
                continue

            skip = False
            for parent in delete_roots:
                try:
                    action.src.relative_to(parent)
                    skip = True
                    break
                except ValueError:
                    continue
            if skip:
                continue

            delete_roots.append(action.src)
            normalized_actions.append(action)

        return normalized_actions

    def _plan_convert_legacy_actions(self) -> list[RepairAction]:
        assert self.root is not None
        root = self.root
        actions: list[RepairAction] = []
        move_sources: set[Path] = set()
        move_dests: set[Path] = set()
        delete_paths: set[Path] = set()

        def _abs(path: Path) -> Path:
            try:
                return path.resolve()
            except OSError:
                return path.absolute()

        def _add_move(src: Path, dst: Path, reason: str) -> None:
            src_abs = _abs(src)
            dst_abs = _abs(dst)
            if src_abs == dst_abs:
                return
            if src_abs in move_sources or src_abs in delete_paths:
                return
            if dst_abs in move_dests:
                return
            kind = "rename" if src_abs.parent == dst_abs.parent else "move"
            actions.append(RepairAction(kind=kind, src=src_abs, dst=dst_abs, reason=reason))
            move_sources.add(src_abs)
            move_dests.add(dst_abs)

        def _add_delete(path: Path, reason: str) -> None:
            path_abs = _abs(path)
            if path_abs == root:
                return
            if path_abs in move_sources or path_abs in delete_paths:
                return
            actions.append(RepairAction(kind="delete", src=path_abs, dst=None, reason=reason))
            delete_paths.add(path_abs)

        def _add_upsert_metadata(path: Path, reason: str) -> None:
            actions.append(RepairAction(kind="upsert_metadata", src=_abs(path), dst=None, reason=reason))

        # A) 修复 prompt/questions 到根目录（旧结构兼容）。
        for required in ("prompt.md", "questions.md"):
            correct, misplaced, typos = self._collect_required_file_candidates(
                required,
                ROOT_REQUIRED_FILE_TYPO_ALIASES.get(required, set()),
            )
            destination = root / required
            if correct:
                for duplicate in correct[1:]:
                    _add_delete(duplicate, f"{required} 根目录重复，保留一份")
                for wrong in misplaced:
                    _add_delete(wrong, f"{required} 位置错误，根目录已有正确文件")
                for typo in typos:
                    _add_delete(typo, f"{typo.name} 命名错误，根目录已有正确 {required}")
            else:
                candidates = misplaced + typos
                if candidates:
                    _add_move(candidates[0], destination, f"修复 {required} 的位置/命名")
                    for redundant in candidates[1:]:
                        _add_delete(redundant, f"{required} 候选重复，保留首个修复来源")

        # B) 旧项目类型目录迁移到 repo。
        repo_dir = root / REPO_DIR_NAME
        legacy_dirs = self._collect_legacy_project_directories(root)
        source_dir: Path | None = None
        if repo_dir.is_dir():
            source_dir = repo_dir
        elif legacy_dirs:
            source_dir = legacy_dirs[0][1]
        else:
            inferred = self._infer_repo_candidate_from_common_dir()
            if inferred is not None:
                source_dir = inferred

        if not repo_dir.is_dir() and source_dir is not None and source_dir != repo_dir:
            _add_move(source_dir, repo_dir, "旧结构代码目录迁移为 repo/")

        for _, legacy_dir in legacy_dirs:
            if source_dir is not None and legacy_dir == source_dir and not repo_dir.is_dir():
                continue
            if repo_dir.is_dir():
                nested_dst = repo_dir / legacy_dir.name
                if not nested_dst.exists():
                    _add_move(legacy_dir, nested_dst, "将残留旧结构目录并入 repo/")
                else:
                    _add_delete(legacy_dir, "残留旧结构目录与 repo 内容冲突，删除冗余目录")
            else:
                _add_delete(legacy_dir, "多余旧结构代码目录，保留单一迁移来源")

        # C) sessions/ 与 trajectory 文件迁移。
        sessions_dir = root / "sessions"
        sessions_correct, sessions_misplaced, sessions_typos = self._collect_required_dir_candidates(
            "sessions",
            ROOT_REQUIRED_DIR_TYPO_ALIASES.get("sessions", set()),
        )
        if sessions_correct:
            for duplicate in sessions_correct[1:]:
                _add_delete(duplicate, "sessions/ 根目录重复，保留一份")
            for wrong in sessions_misplaced:
                _add_delete(wrong, "sessions/ 位置错误，根目录已有正确目录")
            for typo in sessions_typos:
                _add_delete(typo, f"{typo.name}/ 命名错误，根目录已有正确 sessions/")
        else:
            candidates = sessions_misplaced + sessions_typos
            if candidates:
                _add_move(candidates[0], sessions_dir, "修复 sessions/ 到根目录")
                for redundant in candidates[1:]:
                    _add_delete(redundant, "sessions/ 候选重复，保留首个修复来源")

        traj_root, traj_misplaced, traj_typos = self._collect_required_file_candidates(
            "trajectory.json",
            ROOT_REQUIRED_FILE_TYPO_ALIASES.get("trajectory.json", set()),
        )
        root_multi = [
            p
            for p in root.iterdir()
            if p.is_file() and TRAJECTORY_MULTI_RE.fullmatch(p.name.lower()) is not None
        ]
        root_multi.sort(key=lambda p: p.name.lower())

        def _next_sessions_trajectory_target(prefer_single: bool = False) -> Path:
            if prefer_single:
                preferred = sessions_dir / "trajectory.json"
                if _abs(preferred) not in move_dests and not preferred.exists():
                    return preferred

            used_numbers: set[int] = set()
            if sessions_dir.is_dir():
                for entry in sessions_dir.iterdir():
                    if not entry.is_file():
                        continue
                    name_lower = entry.name.lower()
                    if name_lower == "trajectory.json":
                        used_numbers.add(0)
                        continue
                    m = re.fullmatch(r"trajectory[-_](\d+)\.json", name_lower)
                    if m:
                        used_numbers.add(int(m.group(1)))

            for dst in move_dests:
                try:
                    rel = dst.relative_to(sessions_dir)
                except ValueError:
                    continue
                name_lower = rel.name.lower()
                if name_lower == "trajectory.json":
                    used_numbers.add(0)
                    continue
                m = re.fullmatch(r"trajectory[-_](\d+)\.json", name_lower)
                if m:
                    used_numbers.add(int(m.group(1)))

            if 0 not in used_numbers:
                return sessions_dir / "trajectory.json"

            idx = 1
            while idx in used_numbers:
                idx += 1
            return sessions_dir / f"trajectory-{idx}.json"

        seen_src: set[Path] = set()
        sources: list[tuple[Path, str]] = []
        for p in traj_root:
            if p not in seen_src:
                seen_src.add(p)
                sources.append((p, "根目录 trajectory.json 迁移到 sessions/"))
        for p in traj_misplaced:
            if p not in seen_src:
                seen_src.add(p)
                sources.append((p, "错位 trajectory.json 迁移到 sessions/"))
        for p in traj_typos:
            if p not in seen_src:
                seen_src.add(p)
                sources.append((p, f"{p.name} 命名错误，迁移并规范为 trajectory*.json"))
        for p in root_multi:
            if p not in seen_src:
                seen_src.add(p)
                sources.append((p, "根目录 trajectory-N/trajectory_N 迁移到 sessions/"))

        for src, reason in sources:
            target = _next_sessions_trajectory_target(prefer_single=(src.name.lower() == "trajectory.json"))
            _add_move(src, target, reason)

        # D) metadata.json 迁移/补齐。
        metadata_correct, metadata_misplaced, metadata_typos = self._collect_required_file_candidates(
            "metadata.json",
            ROOT_REQUIRED_FILE_TYPO_ALIASES.get("metadata.json", set()),
        )
        metadata_path = root / "metadata.json"

        if metadata_correct:
            for duplicate in metadata_correct[1:]:
                _add_delete(duplicate, "metadata.json 根目录重复，保留一份")
            for wrong in metadata_misplaced:
                _add_delete(wrong, "metadata.json 位置错误，根目录已有正确文件")
            for typo in metadata_typos:
                _add_delete(typo, f"{typo.name} 命名错误，根目录已有 metadata.json")
        else:
            candidates = metadata_misplaced + metadata_typos
            if candidates:
                _add_move(candidates[0], metadata_path, "修复 metadata.json 到根目录")
                for redundant in candidates[1:]:
                    _add_delete(redundant, "metadata.json 候选重复，保留首个修复来源")

        _add_upsert_metadata(metadata_path, "补齐 metadata.json 必需字段")

        # 删除动作去重：若父目录已删除，则子路径删除动作可省略。
        delete_roots: list[Path] = []
        normalized_actions: list[RepairAction] = []
        for action in actions:
            if action.kind != "delete":
                normalized_actions.append(action)
                continue

            skip = False
            for parent in delete_roots:
                try:
                    action.src.relative_to(parent)
                    skip = True
                    break
                except ValueError:
                    continue
            if skip:
                continue

            delete_roots.append(action.src)
            normalized_actions.append(action)

        return normalized_actions

    def _is_repair_delete_exempt(self, path: Path) -> tuple[bool, str]:
        assert self.root is not None
        root = self.root
        backup_dir = root / ".backup"
        tmp_dir = root / ".tmp"

        try:
            path.relative_to(tmp_dir)
            return True, "位于 .tmp 目录（豁免删除）"
        except ValueError:
            pass

        try:
            path.relative_to(backup_dir)
            return True, "位于 .backup 目录（豁免删除）"
        except ValueError:
            pass

        if path == tmp_dir:
            return True, ".tmp 目录（豁免删除）"
        if path == backup_dir:
            return True, ".backup 目录（豁免删除）"

        path_maybe_dir = path.is_dir() or (not path.exists() and path.suffix == "")
        if path_maybe_dir and self._is_compile_exempt_dir(path.name):
            return True, "编译产物目录（豁免删除，仅提醒）"
        if self._is_compile_exempt_file(path):
            return True, "编译产物文件（豁免删除，仅提醒）"

        if path.parent == root and path.suffix.lower() in ROOT_REPAIR_EXEMPT_ARCHIVE_EXTS:
            return True, "根目录压缩包（豁免删除）"

        return False, ""

    def _print_repair_plan(self, actions: list[RepairAction]) -> None:
        for idx, action in enumerate(actions, start=1):
            src = self._rel(action.src)
            if action.kind == "update_gitignore":
                print(f"{idx:03d}. [UPDATE] {src} | {action.reason}")
                continue
            if action.kind == "merge_tmp_dir":
                dst = self._rel(action.dst) if action.dst is not None else ".tmp"
                print(f"{idx:03d}. [MERGE_TMP] {src} -> {dst} | {action.reason}")
                continue
            if action.kind == "upsert_metadata":
                print(f"{idx:03d}. [UPSERT_METADATA] {src} | {action.reason}")
                continue
            if action.kind in {"move", "rename"} and action.dst is not None:
                dst = self._rel(action.dst)
                verb = "RENAME" if action.kind == "rename" else "MOVE"
                print(f"{idx:03d}. [{verb}] {src} -> {dst} | {action.reason}")
                continue

            exempt, exempt_reason = self._is_repair_delete_exempt(action.src)
            if exempt:
                print(
                    f"{idx:03d}. [DELETE-SKIP] {src} | {action.reason} | {exempt_reason}"
                )
            else:
                print(f"{idx:03d}. [DELETE] {src} | {action.reason}")

    def _backup_original_path(self, path: Path, backup_root_dir: Path) -> None:
        assert self.root is not None
        try:
            rel = path.relative_to(self.root)
        except ValueError:
            rel = Path(path.name)
        dest = backup_root_dir / rel

        if dest.exists():
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            idx = 1
            while True:
                candidate = dest.with_name(f"{dest.name}.bak-{stamp}-{idx}")
                if not candidate.exists():
                    dest = candidate
                    break
                idx += 1

        if path.is_dir():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(path, dest)
            return

        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)

    def _build_gitignore_content_with_exemptions(self, existing_content: str) -> tuple[str, list[str]]:
        lines = existing_content.splitlines()
        stripped_set = {line.strip() for line in lines if line.strip()}

        additions: list[str] = []
        if REPAIR_GITIGNORE_HEADER not in stripped_set:
            additions.append(REPAIR_GITIGNORE_HEADER)

        for pattern in REPAIR_GITIGNORE_EXEMPT_PATTERNS:
            if pattern not in stripped_set:
                additions.append(pattern)

        if not additions:
            normalized = "\n".join(lines)
            if normalized and not normalized.endswith("\n"):
                normalized += "\n"
            return normalized, []

        out_lines = list(lines)
        if out_lines and out_lines[-1].strip():
            out_lines.append("")
        out_lines.extend(additions)
        return "\n".join(out_lines).rstrip("\n") + "\n", additions

    def _build_metadata_defaults(self, current: dict[str, object]) -> dict[str, str]:
        languages = set(self.languages)
        if not languages and self.project_type_dir is not None:
            self._detect_languages()
            languages = set(self.languages)

        backend_priority = [
            ("java_kotlin", "java"),
            ("go", "go"),
            ("python", "python"),
            ("php", "php"),
            ("rust", "rust"),
            ("csharp", "csharp"),
            ("ruby", "ruby"),
            ("c_cpp", "cpp"),
            ("js_ts", "node"),
            ("dart_flutter", "dart"),
        ]
        frontend_priority = [
            ("js_ts", "javascript"),
            ("dart_flutter", "flutter"),
        ]

        backend_tech = "none"
        frontend_tech = "none"
        for key, value in backend_priority:
            if key in languages:
                backend_tech = value
                break
        for key, value in frontend_priority:
            if key in languages:
                frontend_tech = value
                break

        if backend_tech != "none" and frontend_tech != "none":
            project_type = "fullstack"
        elif backend_tech != "none":
            project_type = "server"
        elif frontend_tech != "none":
            project_type = "frontend"
        else:
            project_type = "unknown"

        database_value = str(current.get("database", "")).strip() if isinstance(current.get("database"), str) else ""
        if not database_value:
            database_value = "none"

        return {
            "project_type": project_type,
            "frontend_tech": frontend_tech,
            "backend_tech": backend_tech,
            "database": database_value,
        }

    def _upsert_metadata_file(self, path: Path) -> tuple[str, str]:
        current: dict[str, object] = {}
        if path.exists():
            if path.is_dir():
                return "FAIL", "metadata.json 路径为目录，无法写入"
            content = self._read_text(path)
            if content is None:
                return "FAIL", "metadata.json 非可读文本，无法自动补齐"
            try:
                parsed = json.loads(content)
            except json.JSONDecodeError as exc:
                return "FAIL", f"metadata.json 非法 JSON: {exc.msg}"
            if not isinstance(parsed, dict):
                return "FAIL", "metadata.json 顶层不是对象，无法自动补齐"
            current = dict(parsed)

        defaults = self._build_metadata_defaults(current)
        changed_keys: list[str] = []
        for key in METADATA_REQUIRED_KEYS:
            value = current.get(key)
            if value is None:
                current[key] = defaults[key]
                changed_keys.append(key)
                continue
            if isinstance(value, str) and not value.strip():
                current[key] = defaults[key]
                changed_keys.append(key)

        if not changed_keys and path.exists():
            return "SKIP", "metadata.json 必需字段已完整"

        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        except OSError as exc:
            return "FAIL", str(exc)

        if changed_keys:
            return "DONE", "补齐字段: " + ", ".join(changed_keys)
        return "DONE", "创建 metadata.json"

    def _execute_repair_actions(
        self,
        actions: list[RepairAction],
        backup_on_move: bool = False,
    ) -> tuple[int, int, int, Path | None]:
        assert self.root is not None
        root = self.root

        executed = 0
        skipped = 0
        failed = 0
        backup_run_dir: Path | None = None

        def _ensure_backup_dir() -> Path:
            nonlocal backup_run_dir
            if backup_run_dir is None:
                backup_run_dir = root / ".backup"
                backup_run_dir.mkdir(parents=True, exist_ok=True)
            return backup_run_dir

        def _unique_merge_target(base_dir: Path, name: str, scope_label: str) -> Path:
            candidate = base_dir / name
            if not candidate.exists():
                return candidate

            stem = Path(name).stem
            suffix = Path(name).suffix
            prefixed = f"{scope_label}-{stem}" if stem else f"{scope_label}-{name}"
            idx = 1
            while True:
                alt_name = f"{prefixed}{suffix}" if idx == 1 else f"{prefixed}-{idx}{suffix}"
                alt = base_dir / alt_name
                if not alt.exists():
                    return alt
                idx += 1

        for action in actions:
            src = action.src
            dst = action.dst

            if action.kind == "upsert_metadata":
                status, detail = self._upsert_metadata_file(src)
                if status == "DONE":
                    print(f"[DONE] UPSERT_METADATA {self._rel(src)} | {detail}")
                    executed += 1
                elif status == "SKIP":
                    print(f"[SKIP] UPSERT_METADATA {self._rel(src)} | {detail}")
                    skipped += 1
                else:
                    print(f"[FAIL] UPSERT_METADATA {self._rel(src)} | {detail}")
                    failed += 1
                continue

            if action.kind == "update_gitignore":
                if src.exists() and src.is_dir():
                    print(f"[FAIL] UPDATE {self._rel(src)} | 目标是目录，无法写入 .gitignore")
                    failed += 1
                    continue

                if src.exists():
                    content = self._read_text(src)
                    if content is None:
                        print(f"[FAIL] UPDATE {self._rel(src)} | .gitignore 非可读文本，无法自动更新")
                        failed += 1
                        continue
                else:
                    content = ""

                updated_content, additions = self._build_gitignore_content_with_exemptions(content)
                if not additions:
                    print(f"[SKIP] UPDATE {self._rel(src)} | 豁免规则已存在")
                    skipped += 1
                    continue

                try:
                    src.parent.mkdir(parents=True, exist_ok=True)
                    src.write_text(updated_content, encoding="utf-8")
                    print(
                        f"[DONE] UPDATE {self._rel(src)} | 新增规则: {', '.join(additions)}"
                    )
                    executed += 1
                except OSError as exc:
                    print(f"[FAIL] UPDATE {self._rel(src)} | {exc}")
                    failed += 1
                continue

            if action.kind == "merge_tmp_dir":
                merge_src = src
                merge_dst = dst if dst is not None else (root / ".tmp")
                if not merge_src.exists():
                    print(f"[SKIP] MERGE_TMP {self._rel(merge_src)} -> {self._rel(merge_dst)} | 源目录不存在")
                    skipped += 1
                    continue
                if not merge_src.is_dir():
                    print(f"[FAIL] MERGE_TMP {self._rel(merge_src)} | 源路径不是目录")
                    failed += 1
                    continue

                try:
                    merge_dst.mkdir(parents=True, exist_ok=True)

                    moved_count = 0
                    renamed_count = 0
                    scope_label = merge_src.parent.name or "scope"
                    children = sorted(merge_src.iterdir(), key=lambda p: p.name.lower())
                    for child in children:
                        target = merge_dst / child.name
                        if target.exists():
                            target = _unique_merge_target(merge_dst, child.name, scope_label)
                            renamed_count += 1
                        shutil.move(str(child), str(target))
                        moved_count += 1

                    residual_kept = False
                    if merge_src.exists():
                        try:
                            merge_src.rmdir()
                        except OSError:
                            # Avoid deleting residual content in merge flow.
                            # Content deletion must go through delete action (with backup).
                            residual_kept = True

                    if residual_kept:
                        print(
                            f"[DONE] MERGE_TMP {self._rel(merge_src)} -> {self._rel(merge_dst)} | moved={moved_count} renamed={renamed_count} residual_kept=true"
                        )
                    else:
                        print(
                            f"[DONE] MERGE_TMP {self._rel(merge_src)} -> {self._rel(merge_dst)} | moved={moved_count} renamed={renamed_count}"
                        )
                    executed += 1
                except OSError as exc:
                    print(f"[FAIL] MERGE_TMP {self._rel(merge_src)} -> {self._rel(merge_dst)} | {exc}")
                    failed += 1
                continue

            if action.kind == "delete":
                exempt, exempt_reason = self._is_repair_delete_exempt(src)
                if exempt:
                    print(f"[SKIP][EXEMPT] DELETE {self._rel(src)} | {exempt_reason}")
                    skipped += 1
                    continue

                if not src.exists():
                    print(f"[SKIP] DELETE {self._rel(src)} | 源路径不存在")
                    skipped += 1
                    continue

                try:
                    self._backup_original_path(src, _ensure_backup_dir())
                    if src.is_dir():
                        shutil.rmtree(src)
                    else:
                        src.unlink()
                    print(f"[DONE] DELETE {self._rel(src)}")
                    executed += 1
                except OSError as exc:
                    print(f"[FAIL] DELETE {self._rel(src)} | {exc}")
                    failed += 1
                continue

            if dst is None:
                print(f"[SKIP] {action.kind.upper()} {self._rel(src)} | 目标路径为空")
                skipped += 1
                continue

            if not src.exists():
                print(f"[SKIP] {action.kind.upper()} {self._rel(src)} -> {self._rel(dst)} | 源路径不存在")
                skipped += 1
                continue

            if dst.exists():
                print(f"[SKIP] {action.kind.upper()} {self._rel(src)} -> {self._rel(dst)} | 目标已存在")
                skipped += 1
                continue

            try:
                if backup_on_move:
                    self._backup_original_path(src, _ensure_backup_dir())
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(src), str(dst))
                verb = "RENAME" if action.kind == "rename" else "MOVE"
                print(f"[DONE] {verb} {self._rel(src)} -> {self._rel(dst)}")
                executed += 1
            except OSError as exc:
                verb = "RENAME" if action.kind == "rename" else "MOVE"
                print(f"[FAIL] {verb} {self._rel(src)} -> {self._rel(dst)} | {exc}")
                failed += 1

        return executed, skipped, failed, backup_run_dir

    def _new_section(self, title: str) -> CheckSection:
        section = CheckSection(title=title)
        self.sections.append(section)
        return section

    def _rel(self, path: Path | str) -> str:
        if isinstance(path, str):
            return path.replace("\\", "/")
        if self.root is None:
            return path.as_posix()
        try:
            rel = path.relative_to(self.root)
            text = rel.as_posix()
            return text if text else "."
        except ValueError:
            return path.as_posix()

    def _record_failures(self) -> None:
        self.error_count = sum(1 for section in self.sections for item in section.items if item.status == "FAIL")

    def _resolve_input_directory(self) -> Path | None:
        candidate = Path(self.input_identifier).expanduser()
        if candidate.is_dir():
            return candidate.resolve()
        if not candidate.is_absolute():
            local_candidate = (Path.cwd() / self.input_identifier).resolve()
            if local_candidate.is_dir():
                return local_candidate
        return None

    def _check_input_directory(self) -> None:
        section = self._new_section("1. 输入目录检查")
        resolved = self._resolve_input_directory()
        if resolved is None:
            section.add_fail(
                f"输入目录不存在或不可访问: {self.input_identifier}",
                self.input_identifier,
            )
            self._record_failures()
            return

        self.root = resolved
        self._gitignore_scopes_cache = None
        self._candidate_entries_cache = None
        self._dirty_findings_cache = None
        section.add_pass("输入目录合法", self._rel(resolved))
        self._record_failures()

    def _is_similar_filename(self, candidate_name: str, expected_name: str) -> bool:
        c = candidate_name.lower()
        e = expected_name.lower()
        if Path(c).suffix.lower() != Path(e).suffix.lower():
            return False
        score_name = difflib.SequenceMatcher(None, c, e).ratio()
        score_stem = difflib.SequenceMatcher(None, Path(c).stem, Path(e).stem).ratio()
        return max(score_name, score_stem) >= 0.84

    def _iter_candidate_paths_for_root_requirements(self) -> Iterable[Path]:
        for path, _, _, _ in self._iter_candidate_entries_for_root_requirements():
            yield path

    def _iter_candidate_entries_for_root_requirements(self) -> Iterable[tuple[Path, bool, bool, str]]:
        assert self.root is not None
        if self._candidate_entries_cache is None:
            excluded = {".git", ".tmp", ".backup"}
            entries: list[tuple[Path, bool, bool, str]] = []
            for current_root, dirs, files in os.walk(self.root, topdown=True):
                dirs[:] = [d for d in dirs if d.lower() not in excluded]
                current_path = Path(current_root)
                for dirname in dirs:
                    path = current_path / dirname
                    entries.append((path, False, True, dirname.lower()))
                for filename in files:
                    path = current_path / filename
                    entries.append((path, True, False, filename.lower()))
            entries.sort(key=lambda item: item[0].as_posix().lower())
            self._candidate_entries_cache = entries

        for entry in self._candidate_entries_cache:
            yield entry

    def _collect_required_file_candidates(
        self,
        expected_name: str,
        typo_aliases: set[str],
    ) -> tuple[list[Path], list[Path], list[Path]]:
        assert self.root is not None
        expected_lower = expected_name.lower()

        correct_at_root: list[Path] = []
        exact_wrong_location: list[Path] = []
        typo_candidates: list[Path] = []

        normalized_aliases = {alias.lower() for alias in typo_aliases}
        sessions_dir = self.root / "sessions"

        for path, is_file, _, name_lower in self._iter_candidate_entries_for_root_requirements():
            if not is_file:
                continue

            if expected_lower == "trajectory.json":
                try:
                    path.relative_to(sessions_dir)
                    # Files under root/sessions belong to multi-trajectory mode
                    # and should not be treated as misplaced/typo trajectory.json.
                    continue
                except ValueError:
                    pass

            if name_lower == expected_lower:
                if path.parent == self.root:
                    correct_at_root.append(path)
                else:
                    exact_wrong_location.append(path)
                continue

            # trajectory-N.json is a valid multi-trajectory filename and should
            # not be treated as a typo of trajectory.json.
            if expected_lower == "trajectory.json" and TRAJECTORY_MULTI_RE.fullmatch(name_lower):
                continue

            if name_lower in normalized_aliases or self._is_similar_filename(name_lower, expected_lower):
                typo_candidates.append(path)

        correct_at_root.sort(key=lambda p: p.as_posix().lower())
        exact_wrong_location.sort(key=lambda p: p.as_posix().lower())
        typo_candidates.sort(key=lambda p: p.as_posix().lower())
        return correct_at_root, exact_wrong_location, typo_candidates

    def _collect_required_dir_candidates(
        self,
        expected_dir_name: str,
        typo_aliases: set[str],
    ) -> tuple[list[Path], list[Path], list[Path]]:
        assert self.root is not None
        expected_lower = expected_dir_name.lower()
        normalized_aliases = {alias.lower() for alias in typo_aliases}

        correct_at_root: list[Path] = []
        exact_wrong_location: list[Path] = []
        typo_candidates: list[Path] = []

        for path, _, is_dir, name_lower in self._iter_candidate_entries_for_root_requirements():
            if not is_dir:
                continue

            if name_lower == expected_lower:
                if path.parent == self.root:
                    correct_at_root.append(path)
                else:
                    exact_wrong_location.append(path)
                continue

            score = difflib.SequenceMatcher(None, name_lower, expected_lower).ratio()
            if name_lower in normalized_aliases or score >= 0.78:
                typo_candidates.append(path)

        correct_at_root.sort(key=lambda p: p.as_posix().lower())
        exact_wrong_location.sort(key=lambda p: p.as_posix().lower())
        typo_candidates.sort(key=lambda p: p.as_posix().lower())
        return correct_at_root, exact_wrong_location, typo_candidates

    def _report_root_required_file(
        self,
        section: CheckSection,
        expected_name: str,
        typo_aliases: set[str],
        max_items: int = 6,
    ) -> set[Path]:
        assert self.root is not None
        explained_paths: set[Path] = set()

        correct, misplaced, typo_candidates = self._collect_required_file_candidates(expected_name, typo_aliases)

        if len(correct) == 1:
            section.add_pass(f"根目录存在 {expected_name}", self._rel(correct[0]))
        elif len(correct) > 1:
            section.add_fail(f"{expected_name} 在根目录出现多份，仅允许 1 份", self._rel(correct[0]))
            for dup in correct[1:max_items]:
                section.add_fail(f"{expected_name} 重复出现（根目录不应有多份）", self._rel(dup))
                explained_paths.add(dup)

        if misplaced:
            for path in misplaced[:max_items]:
                parent = self._rel(path.parent)
                if correct:
                    section.add_fail(
                        f"{expected_name} 位置错误：根目录已存在正确文件，该文件不应再放在 {parent}/",
                        self._rel(path),
                    )
                else:
                    section.add_fail(
                        f"{expected_name} 放置位置错误，应放在 TASK 根目录而不是 {parent}/",
                        self._rel(path),
                    )
                explained_paths.add(path)

        if typo_candidates:
            for path in typo_candidates[:max_items]:
                parent = self._rel(path.parent)
                if path.parent == self.root:
                    section.add_fail(
                        f"{path.name} 命名错误，应命名为 {expected_name}（应位于 TASK 根目录）",
                        self._rel(path),
                    )
                else:
                    section.add_fail(
                        f"{path.name} 命名错误，应命名为 {expected_name}，并应放在 TASK 根目录而不是 {parent}/",
                        self._rel(path),
                    )
                explained_paths.add(path)

        if not correct and not misplaced and not typo_candidates:
            section.add_fail(f"缺少 {expected_name}", expected_name)

        return explained_paths

    def _report_root_trajectory_presence(self, section: CheckSection) -> set[Path]:
        explained_paths: set[Path] = set()
        assert self.root is not None
        sessions_dir = self.root / "sessions"

        traj_root, traj_misplaced, traj_typos = self._collect_required_file_candidates(
            "trajectory.json",
            ROOT_REQUIRED_FILE_TYPO_ALIASES.get("trajectory.json", set()),
        )
        sessions_correct, sessions_misplaced, sessions_typos = self._collect_required_dir_candidates(
            "sessions",
            ROOT_REQUIRED_DIR_TYPO_ALIASES.get("sessions", set()),
        )

        if sessions_correct:
            section.add_pass("根目录存在 sessions/ 目录", self._rel(sessions_correct[0]))
        if len(sessions_correct) > 1:
            section.add_fail("sessions/ 在根目录出现多份，仅允许 1 份", self._rel(sessions_correct[0]))
            for path in sessions_correct[1:6]:
                section.add_fail("sessions/ 重复出现（根目录不应有多份）", self._rel(path))
                explained_paths.add(path)

        if traj_root:
            for path in traj_root[:6]:
                section.add_fail(
                    "根目录不应存在 trajectory.json，应迁移到 sessions/trajectory.json",
                    self._rel(path),
                )
                explained_paths.add(path)

        for path in traj_misplaced[:6]:
            parent = self._rel(path.parent)
            section.add_fail(
                f"trajectory.json 位置错误，应放在根目录 sessions/ 下（当前位于 {parent}/）",
                self._rel(path),
            )
            explained_paths.add(path)

        for path in traj_typos[:6]:
            parent = self._rel(path.parent)
            section.add_fail(
                f"{path.name} 命名错误，应命名为 trajectory.json 并放在 sessions/ 下（当前位于 {parent}/）",
                self._rel(path),
            )
            explained_paths.add(path)

        for path in sessions_misplaced[:6]:
            parent = self._rel(path.parent)
            section.add_fail(
                f"sessions/ 位置错误，应放在 TASK 根目录而不是 {parent}/",
                self._rel(path),
            )
            explained_paths.add(path)

        for path in sessions_typos[:6]:
            parent = self._rel(path.parent)
            section.add_fail(
                f"{path.name}/ 命名错误，应命名为 sessions/，并放在 TASK 根目录（当前位于 {parent}/）",
                self._rel(path),
            )
            explained_paths.add(path)

        multi_traj_out_of_place: list[Path] = []
        for path, is_file, _, _ in self._iter_candidate_entries_for_root_requirements():
            if not is_file:
                continue
            if not TRAJECTORY_MULTI_RE.fullmatch(path.name):
                continue
            if path.parent == sessions_dir:
                continue
            multi_traj_out_of_place.append(path)
        multi_traj_out_of_place.sort(key=lambda p: p.as_posix().lower())

        for path in multi_traj_out_of_place[:6]:
            parent = self._rel(path.parent)
            if path.parent == self.root:
                section.add_fail(
                    "检测到 trajectory-N/trajectory_N 文件位于根目录，应迁移到 sessions/ 下",
                    self._rel(path),
                )
            else:
                section.add_fail(
                    f"检测到 trajectory-N/trajectory_N 文件位置错误，应位于 sessions/ 下（当前位于 {parent}/）",
                    self._rel(path),
                )
            explained_paths.add(path)

        if not sessions_correct and not sessions_misplaced and not sessions_typos:
            section.add_fail("缺少 sessions/ 目录（trajectory 文件必须统一放在 sessions/ 下）", "sessions/")

        return explained_paths

    def _root_extra_file_issue_message(self, path: Path) -> str:
        name_lower = path.name.lower()

        typo_target = ROOT_COMMON_FILE_TYPOS.get(name_lower)
        if typo_target:
            return f"根目录文件名疑似错误，建议重命名为 {typo_target}"

        if name_lower == "trajectory.json":
            return "根目录不应存在 trajectory.json，应迁移到 sessions/trajectory.json"

        if name_lower == "readme.md":
            return "readme.md 位置错误，应放在 repo 目录下"

        return "根目录存在不允许的额外文件"

    def _check_root_fixed_files(self) -> None:
        section = self._new_section("2. 根目录固定文件检查")
        assert self.root is not None

        explained_root_files: set[Path] = set()

        for required in ROOT_REQUIRED_FILES:
            explained_root_files.update(
                self._report_root_required_file(
                    section,
                    required,
                    ROOT_REQUIRED_FILE_TYPO_ALIASES.get(required, set()),
                )
            )

        explained_root_files.update(self._report_root_trajectory_presence(section))

        extra_root_files = []
        for entry in self.root.iterdir():
            if not entry.is_file():
                continue
            if entry.name == "validation_report.md":
                continue
            if entry.name in ROOT_ALLOWED_FILES:
                continue
            if entry in explained_root_files:
                continue
            extra_root_files.append(entry)

        if extra_root_files:
            for path in sorted(extra_root_files, key=lambda p: p.name.lower()):
                section.add_fail(self._root_extra_file_issue_message(path), self._rel(path))
        elif not any(item.status == "FAIL" for item in section.items):
            section.add_pass("根目录不存在规范外额外文件", ".")

        self._record_failures()

    def _check_repo_directory(self) -> None:
        section = self._new_section("3. 代码目录检查")
        assert self.root is not None

        repo_dir = self.root / REPO_DIR_NAME
        self.legacy_project_dirs = self._collect_legacy_project_directories(self.root)
        report_hints = True

        if repo_dir.is_dir():
            self.project_type_dir = repo_dir
            section.add_pass("代码目录存在且命名合规: repo/", self._rel(repo_dir))
            if self.legacy_project_dirs:
                legacy_desc = ", ".join(path.name for _, path in self.legacy_project_dirs[:5])
                section.add_warn(
                    "检测到旧版项目类型目录，建议执行 --convert-legacy 迁移为 repo 结构",
                    legacy_desc,
                )
        else:
            if len(self.legacy_project_dirs) == 1:
                legacy_type, legacy_dir = self.legacy_project_dirs[0]
                self.project_type_dir = legacy_dir
                self.project_type_name = legacy_type
                section.add_fail(
                    f"代码目录命名不合规：应使用 repo/，当前为旧结构目录 {legacy_dir.name}（已按该目录继续后续检查）",
                    self._rel(legacy_dir),
                )
                report_hints = False
            elif len(self.legacy_project_dirs) > 1:
                self.project_type_dir = self.legacy_project_dirs[0][1]
                self.project_type_name = self.legacy_project_dirs[0][0]
                found_desc = ", ".join(f"{path.name} -> {canonical}" for canonical, path in self.legacy_project_dirs)
                section.add_fail(
                    f"缺少 repo/，且检测到多个旧结构代码目录，不合规: {found_desc}",
                    ".",
                )
                report_hints = False
            else:
                inferred = self._infer_repo_candidate_from_common_dir()
                if inferred is not None:
                    self.project_type_dir = inferred
                    section.add_fail(
                        f"代码目录命名不合规：应使用 repo/，当前目录为 {inferred.name}（已按该目录继续后续检查）",
                        self._rel(inferred),
                    )
                else:
                    section.add_fail("缺少代码目录 repo/", "repo/")

        if report_hints:
            for message, path in self._collect_repo_root_hints():
                section.add_fail(message, self._rel(path))

        if self.project_type_dir is not None:
            self._report_repo_readme(section, self.project_type_dir)

        self._record_failures()

    def _report_repo_readme(self, section: CheckSection, project_dir: Path) -> None:
        root_readmes = self._find_readme_files_in_project_dir(project_dir)
        misplaced_readmes = self._find_readme_files_outside_project_dir(project_dir)
        typo_readmes = self._find_readme_typo_candidates(project_dir)

        if len(root_readmes) == 1:
            section.add_pass("代码目录存在 readme.md", self._rel(root_readmes[0]))
        elif len(root_readmes) > 1:
            section.add_fail("repo 目录下 readme.md 出现多份，仅允许 1 份", self._rel(root_readmes[0]))
            for path in root_readmes[1:6]:
                section.add_fail("readme.md 重复出现（repo 目录下不应有多份）", self._rel(path))

        if misplaced_readmes:
            for path in misplaced_readmes[:6]:
                section.add_fail(
                    "检测到 readme.md 放错位置，应位于 repo 目录下",
                    self._rel(path),
                )

        if typo_readmes:
            for path in typo_readmes[:6]:
                parent = self._rel(path.parent)
                section.add_fail(
                    f"{path.name} 命名错误，应命名为 readme.md，且应位于 repo 目录（当前位于 {parent}/）",
                    self._rel(path),
                )

        if not root_readmes and not misplaced_readmes and not typo_readmes:
            section.add_fail("代码目录缺少 readme.md", self._rel(project_dir / "readme.md"))

    def _collect_legacy_project_directories(self, root: Path) -> list[tuple[str, Path]]:
        matches: list[tuple[str, Path]] = []
        for entry in root.iterdir():
            if not entry.is_dir():
                continue
            if entry.name.lower() in {"docs", "sessions", ".tmp", ".backup", ".git", REPO_DIR_NAME}:
                continue
            normalized = _normalize_project_type_token(entry.name)
            canonical = PROJECT_TYPE_LOOKUP.get(normalized)
            if canonical is None:
                continue
            matches.append((canonical, entry))
        matches.sort(key=lambda x: x[1].name.lower())
        return matches

    def _collect_repo_root_hints(self) -> list[tuple[str, Path]]:
        assert self.root is not None
        hints: list[tuple[str, Path]] = []
        seen_paths: set[Path] = set()

        def _add_hint(message: str, path: Path) -> None:
            if path in seen_paths:
                return
            seen_paths.add(path)
            hints.append((message, path))

        for entry in self.root.iterdir():
            if not entry.is_dir():
                continue
            if entry.name.lower() in {"docs", "sessions", ".tmp", ".backup", ".git", REPO_DIR_NAME}:
                continue

            normalized = _normalize_project_type_token(entry.name)
            if normalized in PROJECT_TYPE_LOOKUP:
                _add_hint(
                    f"检测到旧结构目录 {entry.name}，新规范应统一为 repo/ 代码目录",
                    entry,
                )
                continue
            suggested = PROJECT_TYPE_MISNAME_HINTS.get(normalized)
            if suggested is not None:
                _add_hint(
                    f"检测到目录 {entry.name} 疑似代码目录，建议迁移到 repo/（旧结构建议名: {suggested}）",
                    entry,
                )
                continue

            if normalized in {"backend", "server", "api", "service", "frontend", "web", "client", "ui"}:
                _add_hint(
                    f"检测到 {entry.name} 位于根目录，代码目录应统一为 repo/，该目录应位于 repo/ 内",
                    entry,
                )

        return hints

    def _infer_repo_candidate_from_common_dir(self) -> Path | None:
        assert self.root is not None

        candidates: list[Path] = []

        for entry in self.root.iterdir():
            if not entry.is_dir():
                continue
            if entry.name.lower() in {"docs", "sessions", ".tmp", ".backup", ".git", REPO_DIR_NAME}:
                continue

            if entry.name.startswith("."):
                continue
            candidates.append(entry)

        candidates.sort(key=lambda p: p.name.lower())
        if len(candidates) == 1:
            return candidates[0]
        return None

    def _find_readme_files_outside_project_dir(self, project_dir: Path, max_items: int = 5) -> list[Path]:
        assert self.root is not None
        matches: list[Path] = []
        for path, is_file, _, name_lower in self._iter_candidate_entries_for_root_requirements():
            if not is_file:
                continue
            if name_lower != "readme.md":
                continue
            try:
                path.relative_to(project_dir)
                continue
            except ValueError:
                pass
            matches.append(path)
        matches.sort(key=lambda p: p.as_posix().lower())
        return matches[:max_items]

    def _find_readme_files_in_project_dir(self, project_dir: Path) -> list[Path]:
        matches: list[Path] = []
        if not project_dir.is_dir():
            return matches
        for entry in project_dir.iterdir():
            if entry.is_file() and entry.name.lower() == "readme.md":
                matches.append(entry)
        matches.sort(key=lambda p: p.as_posix().lower())
        return matches

    def _find_readme_typo_candidates(self, project_dir: Path, max_items: int = 6) -> list[Path]:
        assert self.root is not None
        candidates: list[Path] = []
        typo_names = {
            "readme.mdown",
            "read_me.md",
            "reademe.md",
            "readmee.md",
            "reamde.md",
            "readme.txt",
        }
        for path, is_file, _, name_lower in self._iter_candidate_entries_for_root_requirements():
            if not is_file:
                continue
            if name_lower == "readme.md":
                continue
            if name_lower in typo_names or self._is_similar_filename(name_lower, "readme.md"):
                candidates.append(path)
        candidates.sort(key=lambda p: p.as_posix().lower())
        return candidates[:max_items]

    def _check_trajectory_organization(self) -> None:
        section = self._new_section("4. trajectory 文件组织检查")
        assert self.root is not None

        sessions_dir = self.root / "sessions"

        root_like_files: list[Path] = []
        for p in self.root.iterdir():
            if p.is_file() and (
                p.name.lower() == "trajectory.json" or TRAJECTORY_MULTI_RE.fullmatch(p.name) is not None
            ):
                root_like_files.append(p)

        has_sessions = sessions_dir.is_dir()

        if not has_sessions:
            section.add_fail("缺少 sessions/ 目录", self._rel(sessions_dir))

        for p in sorted(root_like_files, key=lambda x: x.name.lower()):
            if p.name.lower() == "trajectory.json":
                section.add_fail("根目录不应存在 trajectory.json，应迁移到 sessions/ 下", self._rel(p))
            else:
                section.add_fail("trajectory-N/trajectory_N 文件不应位于根目录，应迁移到 sessions/ 下", self._rel(p))

        if has_sessions:
            entries = list(sessions_dir.iterdir())
            if not entries:
                section.add_fail("sessions/ 目录为空", self._rel(sessions_dir))
            valid_count = 0
            for entry in entries:
                if entry.is_dir():
                    section.add_fail("sessions/ 下不允许子目录", self._rel(entry))
                    continue
                entry_name_lower = entry.name.lower()
                if entry_name_lower == "trajectory.json" or TRAJECTORY_MULTI_RE.fullmatch(entry_name_lower):
                    valid_count += 1
                else:
                    section.add_fail(
                        "sessions/ 内文件命名不合规，应为 trajectory.json 或 trajectory-N.json（兼容 trajectory_N.json）",
                        self._rel(entry),
                    )

            if valid_count > 0:
                section.add_pass(
                    f"sessions/ 下检测到 {valid_count} 个合法 trajectory 文件",
                    self._rel(sessions_dir),
                )
            else:
                section.add_fail("sessions/ 下未检测到合法 trajectory 文件", self._rel(sessions_dir))

        self._record_failures()

    def _detect_backend_content(self) -> None:
        if self.backend_content is not None:
            return

        project_type_value = str(self.metadata.get("project_type", "")).strip().lower()
        backend_tech_value = str(self.metadata.get("backend_tech", "")).strip().lower()

        if project_type_value in {"server", "backend", "pure_backend", "fullstack", "service", "api"}:
            self.backend_content = True
            self.backend_reason = f"metadata.project_type={project_type_value}"
            return

        if backend_tech_value and backend_tech_value not in {"none", "null", "n/a", "na", "-", "no"}:
            self.backend_content = True
            self.backend_reason = f"metadata.backend_tech={backend_tech_value}"
            return

        if self.project_type_name in {"pure_backend", "fullstack"}:
            self.backend_content = True
            self.backend_reason = f"旧结构项目类型为 {self.project_type_name}"
            return

        project_dir = self.project_type_dir
        if project_dir is None:
            self.backend_content = False
            self.backend_reason = "代码目录不可用"
            return

        for current_root, dirs, files in os.walk(project_dir, topdown=True):
            current_path = Path(current_root)
            for dirname in dirs:
                name = dirname.lower()
                if any(keyword in name for keyword in BACKEND_KEYWORDS):
                    path = current_path / dirname
                    self.backend_content = True
                    self.backend_reason = f"检测到后端关键字目录: {self._rel(path)}"
                    return
            for filename in files:
                lower = filename.lower()
                if lower in BACKEND_MARKER_FILES or lower.endswith(".csproj"):
                    path = current_path / filename
                    self.backend_content = True
                    self.backend_reason = f"检测到后端标志文件: {self._rel(path)}"
                    return

        self.backend_content = False
        self.backend_reason = "未检测到后端关键字目录或后端标志文件"

    def _check_docs_directory(self) -> None:
        section = self._new_section("6. docs 目录及设计文档检查")
        assert self.root is not None

        docs_dir = self.root / "docs"
        if docs_dir.is_dir():
            section.add_pass("docs/ 目录存在", self._rel(docs_dir))
        else:
            _, misplaced_docs, typo_docs = self._collect_required_dir_candidates("docs", {"doc", "document", "documents"})
            if misplaced_docs or typo_docs:
                for path in misplaced_docs[:5]:
                    section.add_fail(
                        f"docs/ 目录放置位置错误，应位于 TASK 根目录而不是 {self._rel(path.parent)}/",
                        self._rel(path),
                    )
                for path in typo_docs[:5]:
                    section.add_fail(
                        f"{path.name}/ 目录命名错误，应命名为 docs/ 并位于 TASK 根目录",
                        self._rel(path),
                    )
            else:
                section.add_fail("缺少 docs/ 目录", "docs/")
            self._record_failures()
            return

        design_doc = docs_dir / "design.md"
        if design_doc.is_file():
            section.add_pass("存在 docs/design.md", self._rel(design_doc))
        else:
            section.add_fail("缺少 docs/design.md", self._rel(design_doc))

        self._detect_backend_content()
        api_spec = docs_dir / "api-spec.md"
        if self.backend_content:
            if api_spec.is_file():
                section.add_pass("后端内容项目存在 docs/api-spec.md", self._rel(api_spec))
            else:
                section.add_fail("检测到后端内容，缺少 docs/api-spec.md", self._rel(api_spec))
        else:
            section.add_pass("未检测到后端内容，docs/api-spec.md 非必需", self._rel(api_spec))

        self._record_failures()

    def _check_metadata_file(self) -> None:
        section = self._new_section("5. metadata.json 检查")
        assert self.root is not None

        metadata_path = self.root / "metadata.json"
        source_path: Path | None = None
        from_nonstandard = False

        if metadata_path.is_file():
            source_path = metadata_path
        else:
            _, misplaced, typos = self._collect_required_file_candidates(
                "metadata.json",
                ROOT_REQUIRED_FILE_TYPO_ALIASES.get("metadata.json", set()),
            )
            if misplaced:
                source_path = misplaced[0]
                from_nonstandard = True
            elif typos:
                source_path = typos[0]
                from_nonstandard = True
            else:
                section.add_fail("缺少 metadata.json，无法执行元数据字段检查", "metadata.json")
                self.metadata = {}
                self._record_failures()
                return

        assert source_path is not None
        content = self._read_text(source_path)
        if content is None:
            section.add_fail("metadata.json 非可读文本", self._rel(source_path))
            self.metadata = {}
            self._record_failures()
            return

        try:
            parsed = json.loads(content)
        except json.JSONDecodeError as exc:
            section.add_fail(f"metadata.json 不是合法 JSON: {exc.msg}", self._rel(source_path))
            self.metadata = {}
            self._record_failures()
            return

        if not isinstance(parsed, dict):
            section.add_fail("metadata.json 顶层必须为 JSON 对象", self._rel(source_path))
            self.metadata = {}
            self._record_failures()
            return

        self.metadata = parsed

        if from_nonstandard:
            section.add_warn(
                "根目录 metadata.json 缺失，已使用错位/命名错误文件继续字段检查（请先修复第2项）",
                self._rel(source_path),
            )
        else:
            section.add_pass("根目录存在 metadata.json", self._rel(source_path))

        for key in METADATA_REQUIRED_KEYS:
            if key not in parsed:
                section.add_fail(f"metadata.json 缺少必需字段: {key}", self._rel(source_path))
                continue
            value = parsed.get(key)
            if value is None:
                section.add_fail(f"metadata.json 字段为空: {key}", self._rel(source_path))
                continue
            if isinstance(value, str) and not value.strip():
                section.add_fail(f"metadata.json 字段为空字符串: {key}", self._rel(source_path))
                continue
            section.add_pass(f"metadata.json 字段存在: {key}", self._rel(source_path))

        self._record_failures()

    def _read_text(self, path: Path) -> str | None:
        if not path.is_file():
            return None
        try:
            data = path.read_bytes()
        except OSError:
            return None

        if b"\x00" in data:
            return None

        for enc in ("utf-8", "utf-8-sig", "gb18030"):
            try:
                return data.decode(enc)
            except UnicodeDecodeError:
                continue

        return None

    def _calc_prompt_english_ratio(self, content: str) -> float:
        english_letters = 0
        total_letters = 0

        for ch in content:
            if not ch.isalpha():
                continue
            total_letters += 1
            if ch.isascii():
                english_letters += 1

        if total_letters == 0:
            return 0.0
        return english_letters / total_letters

    def _check_prompt_english_mode(self) -> None:
        section = self._new_section("7. prompt 英文模式判定")
        assert self.root is not None

        prompt_path = self.root / "prompt.md"
        prompt_source: Path | None = None
        from_nonstandard = False

        if prompt_path.is_file():
            prompt_source = prompt_path
        else:
            _, misplaced_prompt, typo_prompt = self._collect_required_file_candidates(
                "prompt.md",
                ROOT_REQUIRED_FILE_TYPO_ALIASES.get("prompt.md", set()),
            )
            if misplaced_prompt:
                prompt_source = misplaced_prompt[0]
                from_nonstandard = True
            elif typo_prompt:
                prompt_source = typo_prompt[0]
                from_nonstandard = True
            else:
                section.add_fail("缺少 prompt.md，无法判定英文一致性模式", "prompt.md")
                self.english_mode = False
                self._record_failures()
                return

        assert prompt_source is not None
        content = self._read_text(prompt_source)
        if content is None:
            if from_nonstandard:
                section.add_fail(
                    "prompt 英文模式无法判定：候选 prompt 文件非可读文本",
                    self._rel(prompt_source),
                )
            else:
                section.add_fail("prompt.md 非可读文本，无法判定英文一致性模式", self._rel(prompt_source))
            self.english_mode = False
            self._record_failures()
            return

        english_ratio = self._calc_prompt_english_ratio(content)
        self.english_mode = english_ratio > PROMPT_ENGLISH_RATIO_THRESHOLD
        if from_nonstandard:
            section.add_warn(
                "根目录 prompt.md 缺失，已使用错位/命名错误文件进行英文模式判定（请修正第2项）",
                self._rel(prompt_source),
            )

        if self.english_mode:
            section.add_pass(
                f"英文字符占比 {english_ratio:.2%} > 70%，启用英文一致性模式",
                self._rel(prompt_source),
            )
        else:
            section.add_pass(
                f"英文字符占比 {english_ratio:.2%} <= 70%，不启用英文一致性模式",
                self._rel(prompt_source),
            )

        self._record_failures()

    def _iter_readable_text_files(self) -> Iterable[tuple[Path, str]]:
        assert self.root is not None

        for path in self.root.rglob("*"):
            if not path.is_file():
                continue
            try:
                rel_parts = path.relative_to(self.root).parts
            except ValueError:
                rel_parts = path.parts
            if any(part.lower() in ENGLISH_CHECK_EXCLUDED_DIRS for part in rel_parts[:-1]):
                continue
            if path.name.lower() in ENGLISH_CHECK_EXCLUDED_FILES:
                continue
            if self._is_ignored_by_any_gitignore(path):
                continue
            if path.name == "validation_report.md":
                continue
            if path.suffix.lower() in SKIP_LANGUAGE_CHECK_EXTS:
                continue

            text = self._read_text(path)
            if text is None:
                continue

            yield path, text

    def _find_chinese_line_numbers(self, content: str) -> list[int]:
        line_numbers: list[int] = []
        for idx, line in enumerate(content.splitlines(), start=1):
            if CHINESE_RE.search(line):
                line_numbers.append(idx)
        return line_numbers

    def _format_line_numbers(self, line_numbers: list[int]) -> str:
        if not line_numbers:
            return ""
        if len(line_numbers) <= 20:
            return ", ".join(str(n) for n in line_numbers)
        head = ", ".join(str(n) for n in line_numbers[:20])
        return f"{head} ... 共{len(line_numbers)}行"

    def _check_english_consistency(self) -> None:
        section = self._new_section("8. 文本文件中文字符检查")
        assert self.root is not None

        if not self.english_mode:
            section.add_pass("未启用英文一致性模式，跳过中文字符检查", ".")
            self._record_failures()
            return

        failures = 0
        for path, content in self._iter_readable_text_files():
            line_numbers = self._find_chinese_line_numbers(content)
            if line_numbers:
                failures += 1
                formatted = self._format_line_numbers(line_numbers)
                section.add_fail(
                    f"检测到中文字符（英文一致性模式不允许，行号: {formatted}）",
                    self._rel(path),
                )

        if failures == 0:
            section.add_pass("未检测到中文字符", ".")

        self._record_failures()

    def _check_backend_content_recognition(self) -> None:
        section = self._new_section("9. 后端内容识别")
        assert self.root is not None

        self._detect_backend_content()
        if self.project_type_dir is None:
            section.add_fail("无法判定后端内容：代码目录不可用", ".")
            self._record_failures()
            return

        if self.backend_content:
            section.add_pass(f"检测到后端内容: {self.backend_reason}", self._rel(self.project_type_dir))
        else:
            section.add_pass(f"未检测到后端内容: {self.backend_reason}", self._rel(self.project_type_dir))

        self._record_failures()

    def _check_backend_project_requirements(self) -> None:
        section = self._new_section("10. 后端类项目附加检查")
        assert self.root is not None

        self._detect_backend_content()
        if self.project_type_dir is None:
            section.add_fail("代码目录不可用，无法执行后端附加检查", ".")
            self._record_failures()
            return

        if not self.backend_content:
            section.add_pass("非后端内容项目，跳过 Docker/Compose/测试脚本检查", self._rel(self.project_type_dir))
            self._record_failures()
            return

        compose_candidates = [
            "compose.yaml",
            "compose.yml",
            "docker-compose.yaml",
            "docker-compose.yml",
        ]
        run_tests_candidates = ["run_tests.sh", "run_tests.bat", "run_tests.ps1"]
        dockerfiles, compose_paths, test_paths = self._scan_backend_requirement_files(
            self.project_type_dir,
            compose_candidates,
            run_tests_candidates,
        )

        if dockerfiles:
            display_paths = ", ".join(self._rel(p) for p in dockerfiles[:3])
            if len(dockerfiles) > 3:
                display_paths += f" 等{len(dockerfiles)}处"
            section.add_pass(f"后端项目存在 Dockerfile（位置可在子目录）: {display_paths}", self._rel(dockerfiles[0]))
        else:
            section.add_fail(
                "后端项目缺少 Dockerfile（允许位于 repo 目录或其子目录）",
                self._rel(self.project_type_dir),
            )

        compose_found = [p.name for p in compose_paths]
        if compose_found:
            section.add_pass(
                f"后端项目存在 Compose 文件: {compose_found[0]}",
                self._rel(compose_paths[0]),
            )
        else:
            section.add_fail(
                "后端项目缺少 Compose 文件（compose.yaml/compose.yml/docker-compose.yaml/docker-compose.yml）",
                self._rel(self.project_type_dir),
            )

        tests_found = [p.name for p in test_paths]
        if tests_found:
            section.add_pass(
                f"后端项目存在统一测试启动脚本: {tests_found[0]}",
                self._rel(test_paths[0]),
            )
        else:
            section.add_fail(
                "后端项目缺少统一测试启动脚本（run_tests.sh/run_tests.bat/run_tests.ps1）",
                self._rel(self.project_type_dir),
            )

        api_spec = self.root / "docs" / "api-spec.md"
        if api_spec.is_file():
            section.add_pass("后端项目存在 docs/api-spec.md", self._rel(api_spec))
        else:
            section.add_fail("后端项目缺少 docs/api-spec.md", self._rel(api_spec))

        self._record_failures()

    def _scan_backend_requirement_files(
        self,
        base_dir: Path,
        compose_candidates: list[str],
        run_tests_candidates: list[str],
    ) -> tuple[list[Path], list[Path], list[Path]]:
        dockerfiles: list[Path] = []
        compose_files: list[Path] = []
        test_files: list[Path] = []

        compose_set = {name.lower() for name in compose_candidates}
        test_set = {name.lower() for name in run_tests_candidates}

        for current_root, _, files in os.walk(base_dir, topdown=True):
            current_path = Path(current_root)
            for filename in files:
                lower = filename.lower()
                path = current_path / filename
                if lower == "dockerfile":
                    dockerfiles.append(path)
                if lower in compose_set:
                    compose_files.append(path)
                if lower in test_set:
                    test_files.append(path)

        dockerfiles.sort(key=lambda p: p.as_posix().lower())
        compose_files.sort(key=lambda p: p.as_posix().lower())
        test_files.sort(key=lambda p: p.as_posix().lower())
        return dockerfiles, compose_files, test_files

    def _check_gitignore_exists(self) -> None:
        section = self._new_section("11. .gitignore 存在性检查")
        assert self.root is not None

        root_gitignore = self.root / ".gitignore"
        repo_gitignore = (self.project_type_dir / ".gitignore") if self.project_type_dir is not None else None

        found_count = 0
        if root_gitignore.is_file():
            section.add_pass("根目录存在 .gitignore", self._rel(root_gitignore))
            found_count += 1
        if repo_gitignore is not None and repo_gitignore.is_file():
            section.add_pass("代码目录存在 .gitignore", self._rel(repo_gitignore))
            found_count += 1

        if found_count == 0:
            rel = self._rel(repo_gitignore) if repo_gitignore is not None else ".gitignore"
            section.add_warn("未检测到 .gitignore（可在根目录或 repo 目录中提供）", rel)

        self._record_failures()

    def _detect_languages(self) -> None:
        self.languages = set()
        if self.project_type_dir is None:
            return

        seen_names: set[str] = set()
        has_csharp = False

        for path in self.project_type_dir.rglob("*"):
            if not path.is_file():
                continue
            name = path.name
            lower = name.lower()
            seen_names.add(lower)
            if lower.endswith(".csproj") or lower.endswith(".sln"):
                has_csharp = True

        if "pyproject.toml" in seen_names or "requirements.txt" in seen_names:
            self.languages.add("python")
        if "package.json" in seen_names:
            self.languages.add("js_ts")
        if any(x in seen_names for x in ("pom.xml", "build.gradle", "build.gradle.kts")):
            self.languages.add("java_kotlin")
        if "go.mod" in seen_names:
            self.languages.add("go")
        if "composer.json" in seen_names:
            self.languages.add("php")
        if "cargo.toml" in seen_names:
            self.languages.add("rust")
        if "pubspec.yaml" in seen_names:
            self.languages.add("dart_flutter")
        if "gemfile" in seen_names:
            self.languages.add("ruby")
        if has_csharp:
            self.languages.add("csharp")
        if "cmakelists.txt" in seen_names or "makefile" in seen_names:
            self.languages.add("c_cpp")

    def _read_gitignore_entries(self, gitignore_path: Path) -> list[str]:
        content = self._read_text(gitignore_path)
        if content is None:
            return []

        entries: list[str] = []
        for raw in content.splitlines():
            line = raw.strip()
            if not line:
                continue
            if line.startswith("#"):
                continue
            if line.startswith("!"):
                continue
            entries.append(line)
        return entries

    def _get_gitignore_scopes(self) -> list[tuple[Path, list[str]]]:
        if self._gitignore_scopes_cache is not None:
            return self._gitignore_scopes_cache

        scopes: list[tuple[Path, list[str]]] = []
        seen_gitignores: set[Path] = set()

        candidates: list[Path] = []
        if self.root is not None:
            candidates.append(self.root / ".gitignore")
        if self.project_type_dir is not None:
            candidates.append(self.project_type_dir / ".gitignore")

        for gitignore_path in candidates:
            gitignore_path = gitignore_path.resolve()
            if gitignore_path in seen_gitignores:
                continue
            seen_gitignores.add(gitignore_path)
            if not gitignore_path.is_file():
                continue
            entries = self._read_gitignore_entries(gitignore_path)
            if not entries:
                continue
            scopes.append((gitignore_path.parent, entries))

        self._gitignore_scopes_cache = scopes
        return self._gitignore_scopes_cache

    def _gitignore_pattern_matches_path(self, pattern: str, rel_posix_path: str) -> bool:
        pat = pattern.strip().replace("\\", "/")
        if not pat:
            return False

        anchored = pat.startswith("/")
        if anchored:
            pat = pat.lstrip("/")
        dir_only = pat.endswith("/")
        if dir_only:
            pat = pat.rstrip("/")
        if not pat:
            return False

        path_parts = rel_posix_path.split("/")
        file_name = path_parts[-1]
        dir_prefixes = ["/".join(path_parts[:idx]) for idx in range(1, len(path_parts))]

        if dir_only:
            if anchored:
                return any(fnmatch.fnmatch(prefix, pat) for prefix in dir_prefixes)
            if "/" in pat:
                return any(
                    fnmatch.fnmatch(prefix, pat) or fnmatch.fnmatch(prefix, f"**/{pat}")
                    for prefix in dir_prefixes
                )
            return any(any(fnmatch.fnmatch(seg, pat) for seg in prefix.split("/")) for prefix in dir_prefixes)

        if anchored:
            return fnmatch.fnmatch(rel_posix_path, pat)
        if "/" in pat:
            return fnmatch.fnmatch(rel_posix_path, pat) or fnmatch.fnmatch(rel_posix_path, f"**/{pat}")
        return any(fnmatch.fnmatch(seg, pat) for seg in path_parts) or fnmatch.fnmatch(file_name, pat)

    def _is_ignored_by_any_gitignore(self, path: Path, treat_as_dir: bool = False) -> bool:
        scopes = self._get_gitignore_scopes()
        if not scopes:
            return False

        for base_dir, entries in scopes:
            try:
                rel = path.relative_to(base_dir).as_posix()
            except ValueError:
                continue

            # .gitignore only governs descendants in its own domain.
            # A scoped .gitignore (e.g. pure_backend/.gitignore) should not
            # make the scope root directory itself disappear in outer traversal.
            if rel in {"", "."}:
                continue

            rel_to_match = rel
            if treat_as_dir:
                rel_to_match = f"{rel}/.codex_ignore_probe"

            if any(self._gitignore_pattern_matches_path(pattern, rel_to_match) for pattern in entries):
                return True

        return False

    def _pattern_variants(self, required: str) -> set[str]:
        req = required.strip()
        variants = {req}

        if req.endswith("/"):
            base = req.rstrip("/")
            variants.update(
                {
                    base,
                    f"/{req}",
                    f"/{base}",
                    f"**/{req}",
                    f"**/{base}",
                    f"{base}/**",
                    f"**/{base}/**",
                }
            )
        elif req.startswith("*."):
            variants.update({f"**/{req}"})
        elif "/" in req:
            variants.update({f"/{req}", f"**/{req}"})
        else:
            variants.update({f"/{req}", f"**/{req}"})

        return variants

    def _is_pattern_covered(self, required: str, gitignore_entries: list[str]) -> bool:
        variants = {v.lower() for v in self._pattern_variants(required)}

        normalized_entries: set[str] = set()
        for entry in gitignore_entries:
            e = entry.strip().lower()
            if not e:
                continue
            normalized_entries.add(e)
            normalized_entries.add(e.rstrip("/"))

        for variant in variants:
            if variant in normalized_entries:
                return True
            if variant.rstrip("/") in normalized_entries:
                return True

        return False

    def _check_gitignore_coverage(self) -> None:
        section = self._new_section("12. .gitignore 覆盖检查")
        scopes = self._get_gitignore_scopes()
        if not scopes:
            section.add_warn("未检测到可读 .gitignore，无法进行覆盖检查（提醒项）", ".")
            self._record_failures()
            return

        all_entries: list[str] = []
        scoped_desc = ", ".join(self._rel(base / ".gitignore") for base, _ in scopes)
        for _, entries in scopes:
            all_entries.extend(entries)

        if not all_entries:
            section.add_warn(".gitignore 内容为空或不可读，无法覆盖必要规则（提醒项）", scoped_desc)
            self._record_failures()
            return

        if not self.languages:
            section.add_pass("未识别到语言标志文件，跳过语言规则覆盖检查", scoped_desc)
            self._record_failures()
            return

        section.add_pass(
            "识别到语言类型: " + ", ".join(sorted(self.languages)),
            scoped_desc,
        )

        required_patterns: list[str] = list(UNIVERSAL_GITIGNORE_PATTERNS)
        for language in sorted(self.languages):
            required_patterns.extend(LANGUAGE_GITIGNORE_PATTERNS.get(language, []))

        missing_patterns = []
        for required in required_patterns:
            if not self._is_pattern_covered(required, all_entries):
                missing_patterns.append(required)

        if not missing_patterns:
            section.add_pass(".gitignore 已覆盖当前语言和通用目录的常见产物规则", scoped_desc)
        else:
            for pattern in missing_patterns:
                section.add_warn(f".gitignore 未覆盖 {pattern}", scoped_desc)

        self._record_failures()

    def _dir_violation_reason(self, dirname: str) -> str | None:
        lower = dirname.lower()
        if re.fullmatch(r"build-.*", lower):
            return "为构建产物目录"
        return DIR_VIOLATION_REASONS.get(lower)

    def _is_compile_exempt_dir(self, dirname: str) -> bool:
        lower = dirname.lower()
        if re.fullmatch(r"build-.*", lower):
            return True
        return lower in COMPILE_EXEMPT_DIR_NAMES

    def _is_compile_exempt_file(self, path: Path) -> bool:
        lower_name = path.name.lower()
        if lower_name in COMPILE_EXEMPT_FILE_NAMES:
            return True
        return path.suffix.lower() in COMPILE_EXEMPT_FILE_SUFFIXES

    def _file_violation_reason(self, path: Path) -> str | None:
        for rule, reason in FILE_VIOLATION_RULES:
            if rule(path):
                return reason
        return None

    def _check_local_dirty_files(self) -> None:
        section = self._new_section("13. 本地脏文件检查")
        assert self.root is not None

        violations: list[tuple[Path, str, str]] = []

        for current_root, dirs, files in os.walk(self.root, topdown=True):
            current_path = Path(current_root)

            pruned_dirs: list[str] = []
            for dirname in dirs:
                if dirname in {".git", ".backup"}:
                    continue
                dir_path = current_path / dirname
                if self._is_ignored_by_any_gitignore(dir_path, treat_as_dir=True):
                    continue
                reason = self._dir_violation_reason(dirname)
                if reason:
                    if self._is_compile_exempt_dir(dirname):
                        violations.append((dir_path, reason, "WARN"))
                    else:
                        violations.append((dir_path, reason, "FAIL"))
                else:
                    pruned_dirs.append(dirname)
            dirs[:] = pruned_dirs

            for filename in files:
                file_path = current_path / filename
                if file_path.name == "validation_report.md":
                    continue
                if self._is_ignored_by_any_gitignore(file_path):
                    continue
                reason = self._file_violation_reason(file_path)
                if reason:
                    if self._is_compile_exempt_file(file_path):
                        violations.append((file_path, reason, "WARN"))
                    else:
                        violations.append((file_path, reason, "FAIL"))

        deduped: dict[tuple[str, str, str], tuple[Path, str, str]] = {}
        for path, reason, status in violations:
            rel = self._rel(path)
            if path.is_dir():
                rel = rel + "/"
            key = (rel.lower(), status, reason)
            if key not in deduped:
                deduped[key] = (path, reason, status)

        ordered = sorted(deduped.values(), key=lambda x: (self._rel(x[0]).lower(), x[2], x[1]))
        self._dirty_findings_cache = ordered

        if not ordered:
            section.add_pass("未检测到缓存/依赖/构建产物/数据库等本地脏文件", ".")
        else:
            for path, reason, status in ordered:
                rel_path = self._rel(path)
                if path.is_dir():
                    rel_path = rel_path + "/"
                if status == "WARN":
                    reason_msg = f"{reason}（编译产物，豁免删除，仅提醒）"
                    section.add_warn(f"{rel_path} {reason_msg}", rel_path)
                else:
                    section.add_fail(f"{rel_path} {reason}", rel_path)

        self._record_failures()

    def _write_report(self) -> None:
        if self.report_path is None:
            self.report_path = Path.cwd() / ".tmp" / "validation_report.md"

        self._record_failures()
        lines = ["# 静态质检报告", ""]

        for section in self.sections:
            lines.append(f"## {section.title}")
            if not section.items:
                lines.append("- [PASS] 无检查项（.）")
            else:
                for item in section.items:
                    lines.append(f"- [{item.status}] {item.message} ({item.rel_path})")
            lines.append("")

        content = "\n".join(lines).rstrip() + "\n"

        try:
            self.report_path.parent.mkdir(parents=True, exist_ok=True)
            self.report_path.write_text(content, encoding="utf-8")
        except OSError:
            fallback = Path.cwd() / ".tmp" / "validation_report.md"
            fallback.parent.mkdir(parents=True, exist_ok=True)
            fallback.write_text(content, encoding="utf-8")
            self.report_path = fallback


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="对项目交付目录进行静态合规检查")
    parser.add_argument("target", help="目录路径或目录名")
    parser.add_argument(
        "--convert-legacy",
        action="store_true",
        help="将旧结构迁移到新结构（repo/sessions/metadata），执行前会进行终端确认并备份",
    )
    parser.add_argument(
        "--repair",
        action="store_true",
        help="输出报告后执行修复（转移/重命名/删除），执行前会进行终端确认，并在根目录 .backup 备份",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    validator = PackageValidator(args.target)
    passed, errors, report = validator.run()

    status = "PASS" if passed else "FAIL"
    print(f"{status} | errors={errors} | report={report}")

    if args.convert_legacy:
        if report.is_file():
            print("CONVERT | 当前报告内容如下:")
            try:
                print(report.read_text(encoding="utf-8"))
            except OSError as exc:
                print(f"CONVERT | 读取报告失败: {exc}")
        validator.run_convert_legacy()
        passed, errors, report = validator.run()
        status = "PASS" if passed else "FAIL"
        print(f"POST-CONVERT {status} | errors={errors} | report={report}")

    if args.repair:
        if report.is_file():
            print("REPAIR | 当前报告内容如下:")
            try:
                print(report.read_text(encoding="utf-8"))
            except OSError as exc:
                print(f"REPAIR | 读取报告失败: {exc}")
        validator.run_repair()

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

    