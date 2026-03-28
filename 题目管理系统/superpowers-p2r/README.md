# Superpowers Plugin

Advanced development superpowers for orchestrating complex workflows from idea to execution.

**Version**: 2.1.0

## Installation

```bash
claude plugin install superpowers@xuexi-local
```

## Git Bash 使用（全自动）

在 Windows 上建议使用 **Git Bash** 执行以下步骤。

1) 进入插件目录

```bash
cd /e/2026/xianyu/xuexi/题目管理系统/superpowers-p2r
```

2) 写入需求提示词到 `prompt.md`

```bash
cat > prompt.md << 'EOF'
Design a "Medical Operations and Process Governance Middle Platform API Service" that provides unified domain interface capabilities for hospital operation administrators, department reviewers, general business personnel, and auditors. The identity domain supports user registration/login/logout and password recovery, with usernames as unique identifiers and passwords requiring at least 8 characters, including both letters and numbers. Users can create/join organizations, with data isolated at the organizational level. Roles follow a four-tier model: administrator, reviewer, general user, and auditor, with permissions controlled by resource domains and operational semantics. 

The operations analysis domain offers key indicator dashboards and customizable reporting capabilities, covering metrics such as activity, message reach, attendance anomalies, work order SLA, and multi-criteria searches with advanced filtering for appointments/patients/doctors/expenses. The export domain supports field whitelist-based exports with desensitization policies, requiring traceability of export task records. 

The process domain includes two types of workflows: resource application-approval-allocation and credit change approval. It supports conditional branching, joint/parallel signing, SLA time limits (default 48 hours), and reminders. Application materials can be uploaded and retained with approval comments, with final results written back to form a full-chain audit trail. 

The backend, in a single offline environment, uses FastAPI to handle resource-level interface categorization and permission boundaries, with SQLAlchemy+PostgreSQL for persistence and transaction consistency. Core data models include users, organizations, role authorizations, approval process definitions, approval instances, task assignments, attachment metadata, operational metric snapshots, and data dictionaries. Key constraints include unique indexes for usernames/organization codes, idempotent keys for approval instances (duplicate submissions with the same business number within 24 hours must return the same processing result), status enumerations, and time field indexing. 

The data governance domain provides coding rules and quality validation (missing, duplicate, out-of-bounds data), with errors written back to batch details during imports. It supports data versioning/snapshots/rollbacks and lineage tracing, complemented by daily full backups, 30-day archiving, and task scheduling failure compensation (maximum 3 retries). 

The security and compliance domain requires encrypted storage of sensitive fields (ID numbers, contact information) and role-based desensitization in responses. Transmission is restricted to HTTPS only, with all changes logged in immutable operation logs and audit trails. Abnormal login attempts are risk-controlled based on failure counts (5 consecutive failures within 10 minutes trigger a 30-minute lockout). File uploads are validated locally for format and size (single file ≤20MB) and deduplicated via fingerprints. Attachment access requires validation of organizational and business ownership, with unauthorized reads prohibited.

EOF
```

3) 全自动执行（含打包，需提供 TASK-ID）

```bash
claude --print "/superpowers:prompt2repo prompt.md --task-id TASK-20260328-001"
```

4) 仅执行到实现/自测（不打包）

```bash
claude --print "/superpowers:prompt2repo prompt.md --skip-package"
```

可选：如果需要跳过 Phase 3 自测审查，可额外加 `--skip-review`。

## 跨项目一键使用（Git Bash）

已配置全局别名 `p2r-auto`，在任意新项目目录可直接执行：

```bash
p2r-auto
```

然后按提示粘贴需求提示词（结束输入按 `Ctrl+D`），脚本会自动：

- 写入 `prompt.md`
- 生成 `TASK-ID`
- 执行 `/superpowers:prompt2repo` 全流程

## Overview

The superpowers plugin provides a comprehensive framework for collaborative software development, enabling teams to move from rough ideas through structured planning to coordinated execution. It combines strategic planning tools with behavior-driven development practices.

## User-Invocable Skills

### `/superpowers:brainstorming`

Turn rough ideas into implementation-ready designs through structured collaborative dialogue.

- Clarifies ambiguous requirements through focused questioning
- Explores design alternatives grounded in codebase reality
- Produces design documents with BDD specifications (Given-When-Then)
- Prepares the project for planning and implementation

**Workflow:** Discovery → Option Analysis → Design & Commit → Transition to Writing Plans

**Output:** Design folder with `_index.md` and `bdd-specs.md` ready for planning

### `/superpowers:writing-plans [design-folder-path]`

Create executable implementation plans that reduce ambiguity for execution.

- Decomposes designs into granular, testable tasks
- Maps each task to specific BDD scenarios
- Enforces Test-First (Red-Green) ordering
- Ensures compatibility with behavior-driven development practices

**Prerequisites:** Output from `superpowers:brainstorming` skill (design folder with `bdd-specs.md`)

**Output:** Plan folder with `_index.md` and task files ready for execution

### `/superpowers:executing-plans [plan-folder-path]`

Execute written implementation plans in predictable batches.

- Validates plans before execution begins
- Supports both serial (single agent) and parallel (Agent Team) execution
- Tracks task completion and captures evidence
- Provides closure and verification loops

**Prerequisites:** Output from `superpowers:writing-plans` skill (plan folder with `_index.md`)

**Modes:**

- **Serial Execution:** Single agent executes tasks sequentially
- **Parallel Execution:** Coordinates an Agent Team for independent tasks

**Output:** Executed tasks with verification evidence and completion confirmation

## Internal Skills (Loaded Automatically)

### Behavior-Driven Development

Loaded when implementing features or bugfixes during execution. Enforces the Red-Green-Refactor cycle driven by BDD scenarios in Gherkin format (Given-When-Then).

### Agent Team Driven Development

Loaded when orchestrating complex multi-step tasks across specialized agents. Provides guidance on creating and managing Agent Teams with specialized roles:

- **Implementer:** Focuses on BDD, testing, and isolated implementation
- **Reviewer:** Focuses on spec compliance and strict code quality
- **Architect:** Focuses on high-level design and breaking down complex plans

### Build Like iPhone Team

Loaded when the user wants to challenge industry conventions or approach open-ended problems requiring disruptive thinking. Applies Apple's Project Purple design philosophy for radical innovation, including first-principles thinking, internal competition, and breakthrough research techniques. The `superpowers:brainstorming` skill loads this automatically for problems that benefit from unconventional approaches.

### Systematic Debugging

Loaded when diagnosing bugs or unexpected behavior. Provides a 4-phase methodology: root cause investigation, pattern analysis, hypothesis testing, and implementation.

## End-to-End Workflow

```
1. User has an idea or feature request
   ↓
2. /superpowers:brainstorming
   Clarify requirements, explore options, design solution
   Output: Design folder with BDD specs
   ↓
3. /superpowers:writing-plans [design-folder]
   Break design into testable tasks, map to BDD scenarios
   Output: Plan folder with task definitions
   ↓
4. /superpowers:executing-plans [plan-folder]
   Execute tasks using behavior-driven development
   - Serial: Single agent executes sequentially
   - Parallel: Agent Team with Implementer, Reviewer, Architect
   Output: Implemented, tested, verified code
   ↓
5. Code is merged and shipped
```

## Core Principles

- **Test-First:** Every implementation starts with a failing test
- **Explicit over Implicit:** Tasks are detailed and context-independent
- **Collaborative:** Built on structured dialogue and user approval
- **Incremental:** Validate each phase before proceeding
- **Verification-Driven:** Every task includes verification steps
- **BDD-Centric:** All specifications use Given-When-Then format
- **Team-Aware:** Supports both solo and parallel Agent Team execution

## File Structure

```
superpowers-p2r/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest with skill registration
├── skills/
│   ├── brainstorming/
│   │   ├── SKILL.md             # Skill definition and phases
│   │   └── references/          # Detailed guidance for each phase
│   ├── writing-plans/
│   │   ├── SKILL.md             # Skill definition and phases
│   │   └── references/          # Task decomposition patterns
│   ├── executing-plans/
│   │   ├── SKILL.md             # Skill definition and phases
│   │   └── references/          # Batch execution and blocker handling
│   ├── agent-team-driven-development/
│   │   ├── SKILL.md             # Team orchestration guidance
│   │   └── references/          # Role descriptions and team workflows
│   ├── behavior-driven-development/
│   │   ├── SKILL.md             # BDD cycle guidance
│   │   └── references/          # Gherkin reference, phase guides, anti-patterns
│   ├── build-like-iphone-team/
│   │   ├── SKILL.md             # Project Purple design philosophy
│   │   └── references/          # First-principles, breakthrough research, experience specs
│   ├── systematic-debugging/
│   │   ├── SKILL.md             # Debugging methodology
│   │   ├── find-polluter.sh     # Script to isolate test polluters
│   │   └── references/          # Phase-specific debugging guides
│   └── references/
│       └── git-commit.md        # Shared git commit patterns (used by 3 skills)
├── tests/
│   └── systematic-debugging/    # Evaluation scenarios for systematic-debugging skill
│       ├── test-academic.md     # Comprehension test: verify skill adherence
│       ├── test-pressure-1.md   # Pressure: emergency production fix
│       ├── test-pressure-2.md   # Pressure: sunk cost + exhaustion
│       └── test-pressure-3.md   # Pressure: authority + social pressure
└── README.md
```

## Integration with Claude Code

- **Skill Tool:** Load skills dynamically during workflows
- **Task Management:** Create and track tasks during execution
- **Agent Teams:** Spawn specialized agents for parallel work
- **Git Integration:** Automatic commit messages with proper attribution

## Author

Frad LEE (fradser@gmail.com)

## License

MIT
