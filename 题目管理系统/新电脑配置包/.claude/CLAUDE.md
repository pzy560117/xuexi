# CLAUDE.md — 全局通用配置

## 通用原则

- 代码质量：函数 < 50 行，文件 < 800 行
- 结构化日志，禁止裸 console.log / print
- 输入校验 + 错误处理 + 统一错误响应
- 不暴露 token/密码/密钥到日志或前端

## Superpowers 插件已安装

开发复杂项目时使用 Superpowers 三板斧：
1. `/superpowers:brainstorming` — 需求澄清 + 设计方案
2. `/superpowers:writing-plans` — 任务拆分 + BDD 规划
3. `/superpowers:executing-plans` — 代码生成 + 验证

> 如果项目目录下存在独立的 CLAUDE.md，以项目级配置为准。

## Prompt2Repo 自动模式（跨项目）

当用户在**新项目会话**里直接输入“功能开发需求/题目需求”时，默认进入 Prompt2Repo 全自动流程，不额外等待确认：

1. 将用户需求原文写入当前目录 `prompt.md`（UTF-8）。
2. 自动生成 `TASK-ID`（格式：`TASK-YYYYMMDD-HHMMSS`）。
3. 立即执行：`/superpowers:prompt2repo prompt.md --task-id <TASK-ID>`。
4. 若用户明确要求“先不打包”，则追加 `--skip-package`。
5. 若用户明确要求“跳过自测”，则追加 `--skip-review`。

执行约束：
- 必须遵循当前项目目录下 `AGENTS.md` / `CLAUDE.md` 的规范优先级。
- 不得使用 mock 数据替代真实逻辑（除非需求明确允许）。
- 关键结论需给出可追溯证据（文件路径 + 行号）。

强制触发规则（高优先级）：
- 当用户输入的是“业务需求/功能需求/题目描述”，且未明确要求“先讨论方案”，必须直接执行自动流程，不先输出长解释。
- 允许一句确认，但随后必须立即落地执行：
  1. 写入 `prompt.md`
  2. 生成 `TASK-ID`
  3. 执行 `/superpowers:prompt2repo prompt.md --task-id <TASK-ID>`
- 禁止在流程中弹出“A/B/C 选择菜单”阻塞用户；若出现可选方案，默认自动选择推荐项并继续执行，同时记录选择理由。
