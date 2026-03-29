---
name: test-gate
description: "Prompt2Repo Phase 3.5: 严格测试门禁。执行多轮单元/集成测试、测试质量静态检查、覆盖率阈值校验、失败自动诊断分类，并输出标准报告。"
argument-hint: []
user-invocable: false
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-test-gate.sh:*)"]
---

# Test Gate — Prompt2Repo Phase 3.5

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>TEST_GATE_COMPLETE</promise>` 时必须遵守：
- 所有步骤全部完成
- `.tmp/test-gate-report.md` 和 `.tmp/test-quality-issues.md` 已生成
- 无 FAIL/WARN 级问题

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

**核心概念**: 测试门禁是交付前的最后一道防线。参考 [goldbergyoni/javascript-testing-best-practices](https://github.com/goldbergyoni/javascript-testing-best-practices) 的核心原则。

- **MANDATORY**: 测试行为而非实现（Test behavior, not implementation）
- **MANDATORY**: 遵循 AAA 模式（Arrange-Act-Assert）
- **MANDATORY**: 测试独立性（无共享状态）
- **MANDATORY**: 覆盖率 ≠ 质量（需验证测试有效性）
- **PROHIBITED**: 不得在测试失败时手动标记为 PASS
- **PROHIBITED**: 不得跳过 Step 1.5 测试质量检查

## 概述

本 Skill 用于在打包前执行**硬性测试门禁**，防止"脚本看似通过但实际失败"的交付风险。

参考 [goldbergyoni/javascript-testing-best-practices](https://github.com/goldbergyoni/javascript-testing-best-practices) 的核心原则：
- 测试行为而非实现
- AAA 模式 (Arrange-Act-Assert)
- 测试独立性（无共享状态）
- 覆盖率 ≠ 质量（需验证测试有效性）

**前提条件**:
- Phase 3（Self Review）已完成并输出 `SELF_REVIEW_COMPLETE`
- 项目根目录存在 `unit_tests/`、`API_tests/`、`run_tests.sh`、`run_tests.bat`

## 执行步骤

### Step 1: 执行测试门禁脚本（强制，多轮增强）

执行：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-test-gate.sh" \
  --repo-dir "." \
  --report-file ".tmp/test-gate-report.md" \
  --min-unit-test-files 5 \
  --min-api-test-files 5 \
  --min-unit-test-cases 20 \
  --min-api-test-cases 10 \
  --min-unit-coverage 80 \
  --run-api-tests always \
  --unit-repeat 5 \
  --api-repeat 3 \
  --fail-on-warn true \
  --strict true \
  --randomize-order true \
  --check-test-isolation true
```

**多轮测试说明**：
- `--unit-repeat 5`：单元测试重复执行 5 轮，有效检测 flaky 测试和共享状态问题
- `--api-repeat 3`：API 集成测试重复 3 轮，检测接口幂等性和并发问题
- `--randomize-order true`：随机化测试执行顺序，暴露隐藏的依赖关系
- `--check-test-isolation true`：检测测试间是否存在共享状态污染

### Step 1.5: 测试质量静态检查（强制，新增）

在测试脚本通过后，执行测试代码的质量审查：

**1.5.1 AAA 模式合规检查**
- 扫描所有测试函数，检查是否遵循 Arrange-Act-Assert 结构
- 单个测试函数应只包含一个 Act（核心操作）和相关 Assert
- 标记违规：单个测试中包含多个不相关的断言

**1.5.2 不愉快路径覆盖检查**
- 统计"正向测试"与"异常/边界测试"的比例
- 阈值：不愉快路径测试占比 ≥ 30%（如 20 个测试中至少 6 个测试异常情况）
- 必须覆盖的异常场景：空输入、超长输入、非法类型、权限不足、资源不存在

**1.5.3 边界值覆盖映射**
- 检查数值型参数是否包含边界测试（0, 1, MAX-1, MAX, 负数）
- 检查字符串参数是否包含空字符串、超长字符串测试
- 检查集合参数是否包含空集合、单元素、大量元素测试

**1.5.4 测试独立性检查**
- 检查测试文件中是否存在全局可变状态
- 检查 setUp/tearDown 是否正确清理
- 检查测试间是否有执行顺序依赖

输出发现的问题到 `.tmp/test-quality-issues.md`，WARN 级及以上必须修复。

### Step 2: 处理失败项并复验（增强：自动诊断分类）

若脚本返回失败，**先执行自动诊断分类**，再定向修复：

**失败分类与修复策略**：

| 失败类别 | 识别特征 | 修复策略 |
|:---|:---|:---|
| **编译/导入错误** | `ImportError`, `ModuleNotFoundError`, `SyntaxError` | 修复依赖/语法，优先级最高 |
| **断言失败** | `AssertionError`, `Expected X but got Y` | 分析期望 vs 实际，修复实现代码或更新测试预期 |
| **超时/Flaky** | 多轮执行中偶发失败、`TimeoutError` | 增加超时阈值、隔离共享资源、添加重试机制 |
| **环境问题** | `ConnectionRefusedError`, 端口冲突, Docker 启动失败 | 修复 Docker 配置/端口映射/依赖服务启动顺序 |
| **测试质量不达标** | Step 1.5 检查发现的 WARN/FAIL | 补充缺失的边界/异常测试、重构违规测试 |

**修复流程**：
1. 按上表分类所有失败项
2. 按优先级修复：编译错误 → 断言失败 → 环境问题 → 超时 → 测试质量
3. 重新执行 Step 1 和 Step 1.5
4. 最多复验 5 轮；若仍失败，写入 `questions.md` 并标记阻塞原因及失败分类

### Step 3: 输出结论

回复中必须包含：
- `PASS/WARN/FAIL` 汇总
- 多轮执行统计：每轮通过率、flaky 测试列表
- 测试质量检查结果：AAA 合规率、不愉快路径覆盖率、边界值覆盖情况
- 报告路径：`.tmp/test-gate-report.md`
- 阻塞项修复状态及失败分类

## Exit Criteria

当以下全部满足时，Phase 3.5 完成：
- `verify-test-gate.sh` 执行完成（5 轮单元测试 + 3 轮 API 测试全部通过）
- Step 1.5 测试质量检查无 FAIL 级问题
- `.tmp/test-gate-report.md` 已生成
- `.tmp/test-quality-issues.md` 已生成（即使无问题也输出空报告）
- 无 `FAIL/WARN` 级问题

输出 `<promise>TEST_GATE_COMPLETE</promise>`，且该标签必须是回复最后一行。

## References

- `../../skills/references/completion-promises.md` - Promise 设计规范
- `./scripts/verify-test-gate.sh` - 测试门禁验证脚本
- [goldbergyoni/javascript-testing-best-practices](https://github.com/goldbergyoni/javascript-testing-best-practices) - 测试最佳实践参考
