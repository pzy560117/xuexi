#### **测试使用 codex-cli  (windows cmd/linux/wsl2) + 提供的 gpt-5.3-codex-bak模型测试 **

![](https://j0t9xglvod.feishu.cn/space/api/box/stream/download/asynccode/?code=MWQ4OGNhYTc0OGQwMjdiMDhkMjgwZTA4YjJkZmRlYmJfeFU5d1pva2lPWktuOUIxTWE1RDVoQ1FNa1VMUGdLZXpfVG9rZW46UVdMQ2JKalRSb3Q4ZnJ4cEVoUmNGc3RqbkxoXzE3NzQ2MjYwNzM6MTc3NDYyOTY3M19WNA)

说明 ： 有使用codex 的标注员可以在 自测指令 末尾加入 不允许 执行docker 命令 和执行测试，只读静态文件作报告，就不会有需要授权执行命令的情况发生了

# 非前端测试提示词

### **中文提示词**

```Markdown
你是“交付验收 / 项目架构核查”审查员。请在【当前工作目录】对项目进行逐条验证与判定，严格以验收标准为准绳输出结果。

【业务/题目 Prompt】
{prompt}

【验收/评分标准（唯一口径）】
{1. 硬性门槛

1.1 交付产物是否能够实际运行和验证
- 是否提供明确的启动或运行方式说明
- 是否能够在不修改核心代码的前提下完成启动或运行
- 实际运行结果是否与交付说明基本一致
1.2 交付产物是否严重偏离 Prompt 主题
- 交付内容是否围绕 Prompt 所描述的业务目标或使用场景展开
- 是否存在实现内容与 Prompt 主题强相关或无关的情况
- 是否擅自替换、弱化或忽略 Prompt 中的核心问题定义
2. 交付完整性

2.1 交付产物是否完整覆盖 Prompt 中明确提出的核心需求
- 是否实现了 Prompt 中明确列出的所有核心功能点
2.2 交付产物是否具备从 0 到 1 的基本交付形态，而非仅提供局部功能、示意性实现或片段代码。
- 是否存在以 mock / hardcode 形式替代真实逻辑但未作说明的情况
- 是否提供完整的项目结构，而非零散代码或单文件示例
- 是否提供基本的项目说明（如 README 或等效文档）
3. 工程与架构质量

3.1 交付产物在当前问题规模下是否采用了合理的工程结构与模块划分
- 项目结构是否清晰，模块职责是否相对明确
- 项目是否存在冗余且不必要的文件
- 项目是否存在在单一文件下进行代码堆叠的情况
3.2 交付产物是否体现出基本的可维护性与可扩展性意识，而非临时性或堆叠式实现。
- 是否存在明显其混乱高耦合的情况
- 核心逻辑是否具备基本的扩展空间，而非完全写死
4. 工程细节与专业度

4.1 交付产物在工程细节与整体形态上是否体现出专业工程实践水准，包括但不限于错误处理、日志、校验、接口设计
- 错误处理是否具备基本的可靠性与友好性
- 日志是否用于辅助问题定位，而非随意打印或完全缺失
- 是否在关键输入或边界条件处提供必要校验
4.2 交付产物是否具备真实产品或服务应有的功能组织形态，而非停留在示例或演示级实现。
- 交付产物整体是否呈现为真实应用形态，而非教学示例或演示型 Demo
5. Prompt 需求理解与适配度

5.1 交付产物是否准确理解并响应了 Prompt 所描述的业务目标、使用场景与隐含约束，而非仅仅机械实现表现层技术需求
- 是否准确实现 Prompt 的核心业务目标
- 是否存在明显误解需求语义或偏离问题核心的实现
- 是否擅自更改或忽略 Prompt 中的关键约束条件且未作说明
6. 美观度（仅限全栈、纯前端题目）

6.1 交付产物视觉 / 交互是否互贴合场景，且设计美观
- 页面不同功能区域是否具备明确的视觉区分（如背景色、分隔、留白或层级结构）
- 页面整体布局是否合理，元素对齐、间距与比例是否保持基本一致性
- 界面元素（包括文字、图像、图标等）是否能够正常渲染与显示
- 视觉元素是否符合其主题及文字内容保持一致，是否存在图片、插图或装饰元素与实际内容明显不匹配的情况
- 是否提供基本的交互反馈机制（如悬停、点击、过渡效果等），以支持用户理解当前操作状态
- 字体、字号、颜色及图标样式是否具备基本统一性，是否存在风格混杂或规范不一致的问题}

====================
硬性规则（必须遵守）
1) 逐点输出（plan规划+勾选推进）：你必须先调用 update_plan 一次性创建包含所有验收大项的计划清单（每个大项=一个step），并将大项 1 设为 in_progress、其余为 pending；随后严格按计划顺序执行，当执行完所以大项的验收之后，将报告内容汇总写入./.tmp/**.md

2) 不遗漏：在当前大项下，必须覆盖该大项包含的所有二级/三级条目；如遇“不适用”，也要明确标注“不适用”并说明原因与判定边界。

3) 可追溯证据：所有关键结论必须给出可定位证据（文件路径 + 行号，例如 `README.md:10`、`app/main.py:42`），不允许仅凭推断。

4) 可运行优先：能实际启动/运行/测试就按项目说明执行验证；若受环境/权限/依赖限制无法运行，必须：
   - 明确说明阻塞点是什么
   - 给出用户在本地可复现的完整命令
   - 基于静态证据（代码/配置/文档）给出“当前可确认/不可确认”的边界
   - 因沙盒环境权限限制导致的执行失败（如端口、Docker/socket、网络、系统权限、只读文件系统等）可写入“环境限制说明/验证边界”，但不作为项目问题说明，不纳入缺陷定级

5) 不擅自改代码：本任务是验证与评审，不要为了让项目“看起来通过”而修改核心代码；如确需修改才能验证，写入“问题/建议”，仅在用户明确要求后再改。

6) 理论支撑：每个“合理/不合理/通过/不通过”的判断都必须说明依据与推理链路（例如：与标准条款逐条对齐、与常见工程实践/架构原则对齐、或与运行结果对齐），并给出对应证据。

7) 支付相关能力如采用 mock/stub/fake 实现，在题目或文档未明确要求真实第三方联调的前提下，不作为问题报告；但仍需说明其实现方式、启用条件及是否存在误上线风险（例如生产默认启用 mock、可绕过校验逻辑）。

8) 验收时需重点关注结构鉴权与越权安全问题，优先于一般代码风格问题；应重点核查认证入口、路由级鉴权、对象级授权（如基于资源归属校验而非仅凭ID读写）、功能级授权、租户/用户数据隔离、管理/调试接口保护情况，并给出证据与判定依据。

9) 单元测试、API接口功能测试、日志打印分类应作为验收标准的一部分进行核查与判定；需明确说明其是否存在、是否可执行、覆盖范围是否满足核心流程与基本异常路径、日志分类是否清晰且是否存在敏感信息泄露风险。

10) 测试覆盖度静态审计（必做，且必须写入报告）
10.1 目标：不是“跑一遍测试看绿不绿”，而是基于 Prompt + 代码结构，静态审阅项目提供的【单元测试】与【API/集成测试】是否覆盖“绝大部分应检查的核心逻辑与主要风险面”。
10.2 方法（必须执行）：
- 先抽取 Prompt 的核心需求点 + 隐含约束（鉴权/越权/数据隔离/边界条件/错误处理/幂等/分页/并发/数据一致性等），形成“需求点清单”；
- 再逐个定位测试文件与用例，建立映射：`需求点 -> 对应测试用例/断言`；
- 对每个需求点给出覆盖判定：充分/基本覆盖/不足/缺失/不适用/无法确认，并说明判定依据；
- 覆盖判定必须提供可追溯证据（测试文件路径+行号、被测代码路径+行号、关键断言/fixture/mock位置）。
10.3 覆盖要求（最低审查基线，必须逐条核查并判定）：
- 核心业务 happy path 是否覆盖（关键流程至少一条端到端或多步骤串联用例）；
- 核心异常路径是否覆盖（输入校验失败、未认证401、越权403、资源不存在404、冲突409/重复提交等，按项目特性选取）；
- 安全重点：认证入口、路由级鉴权、对象级授权（资源归属校验）、租户/用户数据隔离是否有对应测试或等效验证；
- 关键边界：分页/排序/过滤、空数据、极值、时间字段、并发/重复请求（如存在）、事务/回滚（如存在）；
- 日志与敏感信息：测试或代码是否暴露 token/密码/密钥到日志/响应（可静态判定）。
10.4 Mock/Stub 的处理：
- 允许使用 mock/stub/fake（不作为问题），但必须说明 mock 范围、启用条件、是否存在“生产默认启用 mock”导致误上线风险，并给出证据。
10.5 结论呈现：
- 必须在报告中单独输出《测试覆盖度评估》章节，明确说明：测试是否“足以排查绝大部分问题”的结论与边界；如不足，按问题分级给出最小改进建议（补哪些测试、覆盖哪些风险面）。
====================
输出要求（不限制具体模板）
- 对当前大项下的二级/三级条目逐条给出：结论（通过/部分通过/不通过/不适用/无法确认）+ 理由（理论支撑）+ 证据（`path:line`）+ 可复现验证方式（命令/步骤/预期结果）。
- 问题需分级（阻塞/高/中/低），每条问题都要有证据与影响说明，并给出最小可执行的改进建议。
- 不得将“沙盒环境权限问题”作为项目问题报告。
- 不得将“支付 mock（在符合题目/文档前提下）”作为项目问题报告。
- 对鉴权、越权、对象级授权缺失、角色权限绕过、数据隔离失效等安全问题，应优先报告并给出复现路径或最小验证步骤。
- 对单元测试、API接口功能测试、日志打印分类的核查结果，应单独列出结论与依据。
- 必须增加单独章节：《测试覆盖度评估（静态审计）》
  1) 测试概览：
     - 是否存在单元测试、API/集成测试；测试框架与入口；README 是否提供可执行命令（仅说明，不强制执行）
     - 证据：测试目录/文件列表与关键配置（path:line）
  2) 覆盖映射表（必填）：
     - 以 Prompt 需求点为行，列出：
       [需求点/风险点] [对应测试用例(文件:行)] [关键断言/fixture/mock(文件:行)] [覆盖判定] [缺口] [最小补测建议]
  3) 安全覆盖审计（必填，优先级高于风格问题）：
     - 认证（登录/令牌/会话）、路由鉴权、对象级授权、数据隔离：逐条给覆盖结论 + 复现思路（即使不跑）
  4) “是否足以排查绝大部分问题”的总判定（必填）：
     - 结论只能在：通过/部分通过/不通过/无法确认 中选一
     - 必须说明判定边界：哪些关键风险被覆盖、哪些未覆盖会导致“测试通过但仍可能严重缺陷”
  5) 不启动docker和相关命令
```

### 英文提示词

```JSON
You are the reviewer responsible for Delivery Acceptance and Project Architecture Audit. In the current working directory, verify and assess the project item by item. Your review must strictly follow the acceptance criteria below as the only source of truth.

[Business / Task Prompt]
{prompt}

[Acceptance / Scoring Criteria (the only authority)]
{
1. Hard Gates

1.1 Whether the delivered project can actually be run and verified
- Whether clear startup or run instructions are provided
- Whether the project can be started or run without modifying core code
- Whether the actual runtime behavior is broadly consistent with the delivery documentation

1.2 Whether the delivered project materially deviates from the Prompt
- Whether the implementation is centered on the business goal or usage scenario described in the Prompt
- Whether there are major parts of the implementation that are only loosely related, or unrelated, to the Prompt
- Whether the project replaces, weakens, or ignores the core problem definition in the Prompt without justification

2. Delivery Completeness

2.1 Whether the delivered project fully covers the core requirements explicitly stated in the Prompt
- Whether all explicitly stated core functional requirements in the Prompt are implemented

2.2 Whether the delivered project represents a basic end-to-end deliverable from 0 to 1, rather than a partial feature, illustrative implementation, or code fragment
- Whether mock / hardcoded behavior is used in place of real logic without explanation
- Whether the project includes a complete project structure rather than scattered code or a single-file example
- Whether basic project documentation is provided, such as a README or equivalent

3. Engineering and Architecture Quality

3.1 Whether the project adopts a reasonable engineering structure and module decomposition for the scale of the problem
- Whether the project structure is clear and module responsibilities are reasonably defined
- Whether the project contains redundant or unnecessary files
- Whether the implementation is excessively piled into a single file

3.2 Whether the project shows basic maintainability and extensibility, rather than being a temporary or stacked implementation
- Whether there are obvious signs of chaotic structure or tight coupling
- Whether the core logic leaves room for extension rather than being completely hard-coded

4. Engineering Details and Professionalism

4.1 Whether the engineering details and overall shape reflect professional software practice, including but not limited to error handling, logging, validation, and API design
- Whether error handling is basically reliable and user-friendly
- Whether logs support troubleshooting rather than being random print statements or completely absent
- Whether necessary validation is present for key inputs and boundary conditions

4.2 Whether the project is organized like a real product or service, rather than remaining at the level of an example or demo
- Whether the overall deliverable resembles a real application instead of a teaching sample or demonstration-only project

5. Prompt Understanding and Requirement Fit

5.1 Whether the project accurately understands and responds to the business goal, usage scenario, and implicit constraints described in the Prompt, rather than merely implementing surface-level technical features
- Whether the core business objective in the Prompt is implemented correctly
- Whether there are obvious misunderstandings of the requirement semantics or deviations from the actual problem
- Whether key constraints in the Prompt are changed or ignored without explanation

6. Aesthetics (frontend-only / full-stack tasks only)

6.1 Whether the visual and interaction design fits the scenario and demonstrates reasonable visual quality
- Whether different functional areas of the page are visually distinguishable through background, spacing, separation, or hierarchy
- Whether the overall layout is reasonable, and whether alignment, spacing, and proportions are broadly consistent
- Whether UI elements, including text, images, and icons, render and display correctly
- Whether visual elements are consistent with the page theme and textual content, and whether there are obvious mismatches between images, illustrations, decorative elements, and the actual content
- Whether basic interaction feedback is provided, such as hover states, click states, or transitions, so users can understand the current interaction state
- Whether fonts, font sizes, colors, and icon styles are generally consistent, without obvious visual inconsistency or mixed design language
}

====================
Hard Rules (must follow)

1) Output the review step by step, with a plan and checklist-style progression:
You must first call update_plan once to create a plan covering all major acceptance sections, with one step per major section. Mark section 1 as in_progress and all remaining sections as pending. Then execute the review strictly in plan order. After all sections have been reviewed, write the consolidated report to ./.tmp/**.md.

2) Do not omit anything:
Within each major section, you must cover every included secondary and tertiary requirement. If an item is not applicable, you must still explicitly mark it as "Not applicable" and explain why it is out of scope and where the applicability boundary lies.

3) Evidence must be traceable:
Every key conclusion must include evidence that can be located precisely, using file path + line number, such as `README.md:10` or `app/main.py:42`. Do not make unsupported judgments.

4) Prefer runnable verification:
If the project can realistically be started, run, or tested, verify it according to the project documentation.
If runtime verification is blocked by environment, permissions, or dependencies, you must:
- clearly state the blocker
- provide the full local reproduction command(s) the user can run
- state what can and cannot be confirmed based on static evidence only
- if the failure is caused by sandbox limitations such as ports, Docker/socket access, networking, system permissions, or a read-only filesystem, record it under "Environment Limitations / Verification Boundary"; do not treat it as a project defect and do not include it in defect severity

5) Do not modify code on your own:
This task is for verification and review only. Do not modify core code just to make the project appear to pass. If changes would be required in order to verify something, record them under "Issues / Suggestions" and only modify code if the user explicitly asks you to do so.

6) Every judgment must be justified:
For every judgment such as reasonable / unreasonable / pass / fail, you must explain the basis and reasoning chain. The basis may come from:
- alignment against the acceptance criteria
- alignment against common engineering / architectural practice
- alignment against actual runtime or test results
You must also provide supporting evidence.

7) Mocked payment behavior:
If payment-related functionality is implemented with mock / stub / fake behavior, this is not a defect unless the Prompt or documentation explicitly requires real third-party payment integration.
However, you must still explain:
- how the mock behavior is implemented
- under what conditions it is enabled
- whether there is any risk of accidental production use, such as mock mode being enabled by default or validation logic being bypassable

8) Security review has priority:
During acceptance, pay special attention to authentication, authorization, and privilege-boundary flaws, and prioritize them over general style issues.
You must specifically examine and assess, with evidence:
- authentication entry points
- route-level authorization
- object-level authorization (for example, ownership checks based on resource ownership rather than ID-only access)
- function-level authorization
- tenant / user data isolation
- protection of admin / internal / debug endpoints

9) Unit tests, API / integration tests, and logging categories are mandatory review dimensions:
You must explicitly assess whether they exist, whether they are executable, whether their coverage includes core flows and basic failure paths, and whether logging categories are clear and free of sensitive-data leakage risk.

10) Static audit of test coverage (mandatory; must be included in the report)

10.1 Objective:
The goal is not merely to run the tests and see whether they pass. You must statically review whether the provided unit tests and API / integration tests cover most of the core logic and major risk areas that should be validated, based on the Prompt and the code structure.

10.2 Required method:
- First extract the core requirements and implicit constraints from the Prompt, including authentication, authorization bypass, data isolation, boundary conditions, error handling, idempotency, pagination, concurrency, data consistency, and similar concerns, and turn them into a checklist of requirement points
- Then locate the test files and cases one by one and build a mapping:
  `Requirement point -> corresponding test case / assertion`
- For each requirement point, provide a coverage assessment:
  sufficient / basically covered / insufficient / missing / not applicable / cannot confirm
- Every coverage judgment must include traceable evidence, including test file path + line number, implementation file path + line number, and the location of key assertions / fixtures / mocks

10.3 Minimum coverage baseline that must be audited item by item:
- Whether the core business happy path is covered, with at least one end-to-end or multi-step test case for the key flow
- Whether core failure paths are covered, such as input validation failure, unauthenticated 401, unauthorized 403, not found 404, conflict 409, duplicate submission, depending on the project characteristics
- Security-critical areas: authentication entry, route-level authorization, object-level authorization, and tenant / user isolation must have corresponding tests or equivalent verification
- Key boundaries: pagination / sorting / filtering, empty data, extreme values, time fields, concurrency / repeated requests if relevant, and transaction / rollback if relevant
- Logging and sensitive data: whether code or tests expose tokens, passwords, or secrets in logs or responses, based on static review

10.4 Handling of mocks / stubs:
- mock / stub / fake is allowed and should not be reported as a defect by itself
- but you must explain the mock scope, the conditions under which it is enabled, and whether there is any risk of accidental production rollout caused by mock behavior being enabled by default

10.5 Required conclusion format:
You must include a dedicated section titled "Test Coverage Assessment" in the report.
This section must clearly state whether the test suite is sufficient to rule out most major issues, and where the boundary lies.
If coverage is insufficient, provide minimum actionable recommendations, prioritized by severity, describing which tests should be added and which risk surfaces they should cover.

====================
Output Requirements (template is flexible)

- For every secondary and tertiary item under the current major section, provide:
  conclusion (Pass / Partial Pass / Fail / Not Applicable / Cannot Confirm)
  + rationale (with reasoning)
  + evidence (`path:line`)
  + reproducible verification method (commands / steps / expected result)

- Every issue must be severity-rated as:
  Blocker / High / Medium / Low
  and each issue must include evidence, impact, and the minimum actionable fix

- Do not treat sandbox permission limitations as project defects

- Do not report payment mocks as defects when they are acceptable under the Prompt / documentation assumptions

- For missing authentication, authorization bypass, missing object-level authorization, broken role restrictions, failed data isolation, and similar security issues, report them with priority and include either a concrete reproduction path or a minimal verification procedure

- The review results for unit tests, API / integration tests, and logging categorization must be listed separately with conclusions and supporting evidence

- You must include a dedicated section:
  "Test Coverage Assessment (Static Audit)"
  It must contain all of the following:

  1) Test Overview:
     - Whether unit tests and API / integration tests exist
     - The test framework and test entry points
     - Whether the README provides executable test commands
     - This section is descriptive only; actual execution is not mandatory
     - Evidence: test directories / files and key configuration locations (`path:line`)

  2) Coverage Mapping Table (mandatory):
     For each Prompt requirement / risk point, provide:
     [Requirement / Risk Point]
     [Mapped Test Case(s) (`file:line`)]
     [Key Assertion / Fixture / Mock (`file:line`)]
     [Coverage Assessment]
     [Gap]
     [Minimum Test Addition]

  3) Security Coverage Audit (mandatory; higher priority than style issues):
     - For authentication, route authorization, object-level authorization, and data isolation, provide a coverage conclusion for each plus a reproduction strategy, even if you do not execute it

  4) Final judgment on whether the tests are sufficient to rule out most major issues (mandatory):
     - The conclusion must be exactly one of:
       Pass / Partial Pass / Fail / Cannot Confirm
     - You must clearly explain the judgment boundary:
       which key risks are covered, and which uncovered risks mean the tests could still pass while severe defects remain

  5) Do not start Docker or run Docker-related commands
```

# 前端测试提示词

### 中文提示词

```Markdown
你是“交付验收 / 项目架构核查”审查员。请在【当前工作目录】对前端项目进行逐条验证与判定，严格以验收标准为准绳输出结果。

【业务/题目 Prompt】
{prompt}

【验收/评分标准（唯一口径）】
{
1. 硬性门槛

1.1 交付产物是否能够实际运行和验证
- 是否提供明确的启动、运行、构建或预览方式说明
- 是否能够在不修改核心代码的前提下完成启动、构建或本地验证
- 实际运行结果是否与交付说明基本一致

1.2 交付产物是否严重偏离 Prompt 主题
- 交付内容是否围绕 Prompt 所描述的业务目标、页面场景或用户流程展开
- 是否存在实现内容与 Prompt 主题弱相关或无关的情况
- 是否擅自替换、弱化或忽略 Prompt 中的核心问题定义

2. 交付完整性

2.1 交付产物是否完整覆盖 Prompt 中明确提出的核心需求
- 是否实现 Prompt 中明确列出的核心页面、核心功能、核心交互与关键状态
- 是否覆盖主要用户流程，而非只实现静态界面或局部片段

2.2 交付产物是否具备从 0 到 1 的基本交付形态，而非仅提供局部功能、示意性实现或片段代码
- 是否存在以 mock / hardcode 形式替代真实逻辑但未作说明的情况
- 是否提供完整的项目结构，而非零散代码或单文件示例
- 是否提供基本的项目说明（如 README 或等效文档）
- 是否具备基础的页面组织、路由组织、状态管理或数据流组织，而非纯展示型拼接

3. 工程与架构质量

3.1 交付产物在当前问题规模下是否采用了合理的工程结构与模块划分
- 项目结构是否清晰，模块职责是否相对明确
- 页面、组件、状态、服务请求、工具函数等是否有基本分层
- 项目是否存在冗余且不必要的文件
- 项目是否存在在单一文件下进行代码堆叠的情况

3.2 交付产物是否体现出基本的可维护性与可扩展性意识，而非临时性或堆叠式实现
- 是否存在明显混乱、高耦合的情况
- 核心逻辑是否具备基本扩展空间，而非完全写死
- 组件复用、状态管理、接口封装、常量管理等是否具备基本可维护性

4. 工程细节与专业度

4.1 交付产物在工程细节与整体形态上是否体现出专业工程实践水准，包括但不限于错误处理、日志、校验、状态反馈、交互设计
- 错误处理是否具备基本可靠性与友好性
- 是否在关键输入、关键交互、边界条件处提供必要校验
- 是否提供加载态、空态、异常态、提交中态、成功/失败反馈等基本状态反馈
- 日志是否用于辅助问题定位，而非随意打印或完全缺失
- 是否存在在 console、埋点、页面可见区域中输出敏感信息的风险

4.2 交付产物是否具备真实产品应有的功能组织形态，而非停留在示例或演示级实现
- 交付产物整体是否呈现为真实应用形态，而非教学示例或演示型 Demo
- 页面之间是否有基本连贯关系
- 交互流程是否完整，而非仅能展示静态结果

5. Prompt 需求理解与适配度

5.1 交付产物是否准确理解并响应了 Prompt 所描述的业务目标、使用场景与隐含约束，而非仅仅机械实现表现层技术需求
- 是否准确实现 Prompt 的核心业务目标
- 是否存在明显误解需求语义或偏离问题核心的实现
- 是否擅自更改或忽略 Prompt 中的关键约束条件且未作说明
- 是否仅完成“页面长得像”，但未完成实际交互、状态流转或用户任务闭环

6. 美观度（前端项目适用）

6.1 交付产物视觉 / 交互是否贴合场景，且设计美观
- 页面不同功能区域是否具备明确的视觉区分（如背景色、分隔、留白或层级结构）
- 页面整体布局是否合理，元素对齐、间距与比例是否保持基本一致性
- 界面元素（包括文字、图像、图标等）是否能够正常渲染与显示
- 视觉元素是否符合其主题及文字内容保持一致，是否存在图片、插图或装饰元素与实际内容明显不匹配的情况
- 是否提供基本的交互反馈机制（如悬停、点击、禁用、过渡效果、当前状态提示等），以支持用户理解当前操作状态
- 字体、字号、颜色及图标样式是否具备基本统一性，是否存在风格混杂或规范不一致的问题
}

====================
硬性规则（必须遵守）

1) 逐点输出（plan 规划 + 勾选推进）
你必须先调用 update_plan 一次性创建包含所有验收大项的计划清单（每个大项 = 一个 step），并将大项 1 设为 in_progress、其余为 pending；随后严格按计划顺序执行，当执行完所有大项的验收之后，将报告内容汇总写入 ./.tmp/**.md

2) 不遗漏
在当前大项下，必须覆盖该大项包含的所有二级 / 三级条目；如遇“不适用”，也要明确标注“不适用”并说明原因与判定边界。

3) 可追溯证据
所有关键结论必须给出可定位证据（文件路径 + 行号，例如 README.md:10、src/App.tsx:42），不允许仅凭推断。

4) 可运行优先
能实际启动 / 运行 / 测试就按项目说明执行验证；若受环境 / 权限 / 依赖限制无法运行，必须：
- 明确说明阻塞点是什么
- 给出用户在本地可复现的完整命令
- 基于静态证据（代码 / 配置 / 文档）给出“当前可确认 / 不可确认”的边界
- 因沙盒环境权限限制导致的执行失败（如端口、网络、系统权限、只读文件系统等）可写入“环境限制说明 / 验证边界”，但不作为项目问题说明，不纳入缺陷定级

5) 不擅自改代码
本任务是验证与评审，不要为了让项目“看起来通过”而修改核心代码；如确需修改才能验证，写入“问题 / 建议”，仅在用户明确要求后再改。

6) 理论支撑
每个“合理 / 不合理 / 通过 / 不通过”的判断都必须说明依据与推理链路（例如：与标准条款逐条对齐、与常见前端工程实践 / 架构原则对齐、或与运行结果对齐），并给出对应证据。

7) 使用 mock / stub / fake 数据源不自动视为问题
如题目或文档未明确要求真实后端联调，前端项目中采用 mock / stub / fake 实现不作为问题报告；但仍需说明其实现方式、启用条件及是否存在误上线风险（例如生产默认启用 mock、请求被静默劫持、绕过真实错误处理逻辑）。

8) 验收时需重点关注前端安全与权限控制问题，优先于一般代码风格问题；应重点核查：
- 认证入口与登录态处理
- 前端路由级鉴权 / 路由守卫
- 页面级 / 功能级权限控制
- 管理页、调试页、配置页、隐藏菜单是否存在直接访问风险
- token、用户信息、密钥、环境变量、调试信息是否泄露到前端代码、日志、埋点、localStorage、sessionStorage、页面响应或 console
- 多用户切换时缓存、状态、页面残留是否存在串数据风险

9) 单元测试、组件测试、页面/路由集成测试、E2E 测试、日志打印分类应作为验收标准的一部分进行核查与判定；需明确说明其是否存在、是否可执行、覆盖范围是否满足核心流程与基本异常路径、日志分类是否清晰且是否存在敏感信息泄露风险。

10) 测试覆盖度静态审计（必做，且必须写入报告）

10.1 目标
不是“跑一遍测试看绿不绿”，而是基于 Prompt + 代码结构，静态审阅项目提供的【单元测试】、【组件测试】、【页面/路由集成测试】、【E2E 测试】是否覆盖“绝大部分应检查的核心逻辑与主要风险面”。

10.2 方法（必须执行）
- 先抽取 Prompt 的核心需求点 + 隐含约束（鉴权 / 越权 / 边界条件 / 错误处理 / 表单校验 / 加载态 / 空态 / 异常态 / 分页 / 排序 / 过滤 / 路由守卫 / 重复点击 / 重复请求 / 状态恢复 / 敏感信息展示等），形成“需求点清单”
- 再逐个定位测试文件与用例，建立映射：需求点 -> 对应测试用例 / 断言
- 对每个需求点给出覆盖判定：充分 / 基本覆盖 / 不足 / 缺失 / 不适用 / 无法确认，并说明判定依据
- 覆盖判定必须提供可追溯证据（测试文件路径 + 行号、被测代码路径 + 行号、关键断言 / fixture / mock 位置）

10.3 覆盖要求（最低审查基线，必须逐条核查并判定）
- 核心业务 happy path 是否覆盖（关键流程至少一条端到端或多步骤串联用例）
- 核心异常路径是否覆盖（输入校验失败、未登录跳转 / 拦截、无权限提示、资源不存在空态 / 错误态、请求失败、重复提交防护等，按项目特性选取）
- 安全重点：认证入口、路由鉴权、页面 / 功能级权限控制是否有对应测试或等效验证
- 关键边界：分页 / 排序 / 过滤、空数据、极值、时间字段、重复点击 / 重复请求、异步竞态、状态恢复 / 回滚（如存在）
- 日志与敏感信息：测试或代码是否暴露 token / 密码 / 密钥 / 用户隐私信息到日志、页面、埋点或前端可见输出

10.4 Mock / Stub 的处理
- 允许使用 mock / stub / fake（不作为问题），但必须说明 mock 范围、启用条件、是否存在“生产默认启用 mock”导致误上线风险，并给出证据。

10.5 结论呈现
- 必须在报告中单独输出《测试覆盖度评估》章节，明确说明：测试是否“足以排查绝大部分问题”的结论与边界；如不足，按问题分级给出最小改进建议（补哪些测试、覆盖哪些风险面）。

====================
输出要求（不限制具体模板）

- 对当前大项下的二级 / 三级条目逐条给出：
  结论（通过 / 部分通过 / 不通过 / 不适用 / 无法确认）
  + 理由（理论支撑）
  + 证据（path:line）
  + 可复现验证方式（命令 / 步骤 / 预期结果）

- 问题需分级（阻塞 / 高 / 中 / 低），每条问题都要有证据与影响说明，并给出最小可执行的改进建议

- 不得将“沙盒环境权限问题”作为项目问题报告

- 对下列前端安全问题，应优先报告并给出复现路径或最小验证步骤：
  - 登录态校验缺失
  - 未登录可访问受限页面
  - 路由守卫缺失或可绕过
  - 仅隐藏按钮但页面 / 功能仍可直接进入
  - 管理页、调试页、配置页直接暴露
  - token / 用户信息 / 调试信息泄露
  - 用户切换后缓存未清理导致串数据
  - 前端对权限的表达与真实访问能力明显不一致

- 对单元测试、组件测试、页面 / 路由集成测试、E2E 测试、日志打印分类的核查结果，应单独列出结论与依据

- 必须增加单独章节：《测试覆盖度评估（静态审计）》
  1) 测试概览：
     - 是否存在单元测试、组件测试、页面 / 路由集成测试、E2E 测试；测试框架与入口；README 是否提供可执行命令（仅说明，不强制执行）
     - 证据：测试目录 / 文件列表与关键配置（path:line）

  2) 覆盖映射表（必填）：
     - 以 Prompt 需求点为行，列出：
       [需求点 / 风险点]
       [对应测试用例（文件:行）]
       [关键断言 / fixture / mock（文件:行）]
       [覆盖判定]
       [缺口]
       [最小补测建议]

  3) 安全覆盖审计（必填，优先级高于风格问题）：
     - 认证（登录 / 令牌 / 会话处理）
     - 前端路由鉴权 / 路由守卫
     - 页面级 / 功能级权限控制
     - 敏感信息暴露
     - 用户切换后的缓存 / 状态隔离
     以上逐条给覆盖结论 + 复现思路（即使不跑）

  4) “是否足以排查绝大部分问题”的总判定（必填）：
     - 结论只能在：通过 / 部分通过 / 不通过 / 无法确认 中选一
     - 必须说明判定边界：哪些关键风险已覆盖，哪些未覆盖会导致“测试通过但仍可能存在严重缺陷”

  5) 不启动 docker 和相关命令
  6) 禁止查看docs / sessions / trajectory.json文件
```

### 英文提示词

```SQL
You are the reviewer for “Delivery Acceptance / Project Architecture Inspection.” In the [current working directory], perform a point-by-point review and determination for the frontend project. Use the acceptance criteria as the sole standard for judgment.

[Business / Task Prompt]
{prompt}

[Acceptance / Scoring Criteria (single source of truth)]
{
1. Mandatory Gate Checks

1.1 Can the delivered project actually be run and verified?
- Is there a clear explanation of how to start, run, build, or preview the project?
- Can it be started, built, or verified locally without modifying core code?
- Do the actual results generally match the delivery documentation?

1.2 Does the deliverable materially deviate from the Prompt?
- Does the implementation stay aligned with the business goal, page scenarios, and user flows described in the Prompt?
- Is there functionality that is only weakly related or unrelated to the Prompt?
- Has the implementation replaced, weakened, or ignored the core problem definition in the Prompt without explanation?

2. Completeness of Delivery

2.1 Does the deliverable fully cover the core requirements explicitly stated in the Prompt?
- Are the required pages, core features, core interactions, and key UI states implemented?
- Are the main user flows covered, rather than only static UI or isolated fragments?

2.2 Does the deliverable have the shape of a real end-to-end project rather than a partial sample, demo fragment, or illustrative code snippet?
- Is mock / hardcoded behavior used in place of real logic without being disclosed?
- Is there a complete project structure rather than scattered code or a single-file example?
- Is there basic project documentation such as a README or equivalent?
- Does the project have a basic organization for pages, routing, state, or data flow, rather than just stitched-together display code?

3. Engineering and Architecture Quality

3.1 Does the deliverable use a reasonable structure and module split for the scope of the problem?
- Is the project structure clear, with reasonably separated responsibilities?
- Is there basic separation across pages, components, state, service calls, and utility functions?
- Are there unnecessary or redundant files?
- Is too much logic stacked into a single file?

3.2 Does the deliverable show basic maintainability and extensibility rather than being a temporary or piled-up implementation?
- Is there obvious confusion or tight coupling?
- Does the core logic leave room for extension, or is everything hardcoded?
- Are component reuse, state management, API abstraction, and constant/config organization handled in a maintainable way?

4. Engineering Detail and Professionalism

4.1 Does the deliverable reflect sound frontend engineering practice in terms of details and overall shape, including but not limited to error handling, logging, validation, state feedback, and interaction design?
- Is error handling basically reliable and user-friendly?
- Is necessary validation present for important inputs, key interactions, and boundary cases?
- Are essential UI states handled, such as loading, empty, error, submitting, and success/failure feedback?
- Is logging used to support troubleshooting rather than being random, excessive, or entirely absent?
- Is there any risk of sensitive data being exposed through console output, analytics, visible UI content, or similar surfaces?

4.2 Does the deliverable resemble a real product rather than a demo or tutorial artifact?
- Does the project look like a real application rather than a teaching sample or showcase demo?
- Are the pages meaningfully connected to each other?
- Are the interaction flows complete, rather than only displaying static outcomes?

5. Prompt Understanding and Fit

5.1 Does the deliverable correctly understand and respond to the business goal, usage scenario, and implied constraints in the Prompt, rather than merely implementing surface-level UI requirements?
- Does it correctly fulfill the Prompt’s core business objective?
- Is there any clear misunderstanding of the requirement or deviation from the real problem being solved?
- Have key constraints in the Prompt been changed or ignored without explanation?
- Does the project only “look right” visually while failing to complete the actual interaction flow, state transitions, or user task closure?

6. Visual and Interaction Quality (frontend projects only)

6.1 Are the visuals and interactions appropriate to the scenario, and is the design reasonably polished?
- Are different functional areas visually distinguishable through background, separation, spacing, hierarchy, or similar means?
- Is the overall layout coherent, with consistent alignment, spacing, and proportions?
- Do UI elements such as text, images, and icons render correctly?
- Do the visual elements match the theme and content, or are there images / illustrations / decorative assets that clearly do not fit?
- Is there basic interaction feedback such as hover states, click states, disabled states, transitions, or current-state indications to help users understand what is happening?
- Are fonts, font sizes, colors, and icon styles basically consistent, or is the visual language mixed and inconsistent?
}

====================
Mandatory Rules (must be followed)

1) Output by checklist item (plan first, then execute in order)
You must first call update_plan once to create a plan containing all major acceptance sections, with one step per major section. Set section 1 to in_progress and all remaining sections to pending. Then execute the review strictly in plan order. After all sections have been completed, write the consolidated report to ./.tmp/**.md

2) Do not omit sub-items
Within each major section, every secondary and tertiary criterion must be reviewed. If something is “Not Applicable,” you must still state that explicitly and explain why it is out of scope and where the judgment boundary lies.

3) All key conclusions must be traceable
Every key conclusion must include verifiable evidence with file path + line number, for example README.md:10 or src/App.tsx:42. Do not rely on unsupported inference.

4) Prefer runnable verification when possible
If the project can be started, run, or tested, verify it by following the project’s own documentation. If execution is blocked by environment, permissions, dependencies, or similar constraints, you must:
- clearly state what the blocker is
- provide complete commands the user can run locally to reproduce the verification
- define what can and cannot be confirmed based on static evidence from code, config, and docs
- treat sandbox-related execution failures (for example port issues, network restrictions, system permissions, read-only filesystem, and similar constraints) as environment limitations, not project defects

5) Do not modify code on your own
This task is for verification and review. Do not change core code just to make the project appear to pass. If code changes would be required for further verification, record that under issues / recommendations, and only modify code if the user explicitly asks later.

6) Every judgment must be explained
For every conclusion such as reasonable / unreasonable / pass / fail, explain the reasoning basis. Align it with the review criteria, common frontend engineering practice / architecture principles, or actual run results, and provide supporting evidence.

7) Mock / stub / fake data is not automatically a defect
If the Prompt or documentation does not explicitly require real backend integration, the use of mock / stub / fake data sources in a frontend project should not automatically be reported as a problem. However, you must still explain:
- how it is implemented
- how it is enabled
- whether there is any risk of shipping with mock behavior unintentionally enabled, such as production-default mock mode, silent request interception, or bypassed real error handling

8) Prioritize frontend security and access-control findings over style issues
The review must pay special attention to:
- authentication entry points and login-state handling
- frontend route protection / route guards
- page-level and feature-level access control
- whether admin pages, debug pages, config pages, or hidden menus can be accessed directly
- whether tokens, user information, secrets, environment variables, or debug data are exposed in frontend code, logs, analytics, localStorage, sessionStorage, visible responses, or console output
- whether switching between users can leave behind cached data, stale state, or leaked page content

9) Tests and logging review are part of the acceptance scope
Unit tests, component tests, page/route integration tests, E2E tests, and log categorization must all be checked as part of the acceptance review. You must state whether they exist, whether they are runnable, whether their coverage is sufficient for the core flows and basic failure paths, whether logging is clearly categorized, and whether there is any risk of leaking sensitive information.

10) Static test coverage audit (mandatory, must appear in the report)

10.1 Objective
The goal is not merely to run the tests and see whether they pass. Based on the Prompt and the code structure, you must statically audit whether the provided unit tests, component tests, page/route integration tests, and E2E tests cover most of the core logic and major risk areas that should be examined.

10.2 Required method
- First extract the Prompt’s core requirements and implied constraints, such as authentication / authorization risk, boundary cases, error handling, form validation, loading states, empty states, error states, pagination, sorting, filtering, route guards, repeat clicks, duplicate requests, state recovery, sensitive information display, and similar concerns, and turn them into a “requirement checklist”
- Then locate the test files and test cases and build a mapping from requirement -> corresponding test case / assertion
- For each requirement, assign a coverage judgment: fully covered / basically covered / insufficient / missing / not applicable / cannot confirm, and explain why
- Every coverage judgment must include traceable evidence, including test file path + line number, code-under-test path + line number, and the location of key assertions / fixtures / mocks

10.3 Minimum coverage baseline (must be checked item by item)
- Is the happy path for the core business flow covered, with at least one end-to-end or multi-step linked test case for the key workflow?
- Are key failure paths covered, such as validation failure, unauthenticated redirect / interception, insufficient permission feedback, missing-resource empty/error states, request failure handling, duplicate submission protection, and similar project-relevant cases?
- For security-sensitive areas, are authentication entry points, route protection, and page-level / feature-level access control covered by tests or equivalent verification?
- Are important edge cases covered, such as pagination / sorting / filtering, empty data, extreme values, time-related fields, repeat click / repeat request behavior, async race conditions, and state recovery / rollback if relevant?
- Do the tests or the code reveal any tokens, passwords, secrets, or user-private data through logs, UI output, analytics, or other frontend-visible channels?

10.4 How to treat mock / stub usage
- Mock / stub / fake usage is allowed and should not automatically be treated as a defect, but you must explain the scope of the mock, how it is enabled, and whether there is any risk of shipping with production mock mode still active, with evidence.

10.5 How the conclusion must be presented
- The report must include a dedicated section titled “Test Coverage Evaluation” and clearly state whether the current tests are sufficient to uncover most issues, together with the boundary of that judgment. If coverage is insufficient, provide the smallest actionable improvement suggestions by issue severity, including which tests should be added and what risk areas they should cover.

11) Rule for “Not Applicable” judgments on conditional frontend checks
The following items should only be reviewed when the project actually includes the corresponding feature, page, state, or business meaning. If the project does not include them, mark them explicitly as “Not Applicable,” explain why, and define the judgment boundary. Do not treat the absence of an irrelevant capability as a defect:
- login / session / multi-user switching
- route guards / permission pages / admin pages / debug pages
- pagination / sorting / filtering / search
- time-based fields / polling / periodic refresh / async race conditions
- duplicate submission / debouncing / idempotent interaction behavior
- E2E tests
- mock / stub / fake data sources
- file upload / download / rich text / charts / maps / third-party SDKs

====================
Output Requirements (no fixed template required)

- For every secondary and tertiary criterion under the current major section, provide:
  conclusion (Pass / Partial Pass / Fail / Not Applicable / Cannot Confirm)
  + reasoning
  + evidence (path:line)
  + reproducible verification steps (commands / steps / expected results)

- Issues must be severity-ranked as Blocker / High / Medium / Low. Every issue must include evidence, impact, and the smallest executable improvement suggestion.

- Do not report sandbox-environment limitations as project defects.

- The following frontend security issues must be prioritized and reported with either a reproduction path or the smallest validation steps:
  - missing login-state validation
  - restricted pages accessible without login
  - missing or bypassable route guards
  - buttons hidden while the page / feature remains directly accessible
  - exposed admin pages, debug pages, or config pages
  - leaked tokens, user information, or debug data
  - stale cache after user switching causing cross-user data leakage
  - frontend permission presentation that clearly does not match actual accessibility

- The review results for unit tests, component tests, page/route integration tests, E2E tests, and log categorization must be listed separately with conclusions and supporting evidence.

- The report must include a dedicated section: “Test Coverage Evaluation (Static Audit)”
  1) Test Overview:
     - whether unit tests, component tests, page/route integration tests, and E2E tests exist
     - test frameworks and entry points
     - whether the README provides executable commands (state only; execution is not mandatory)
     - evidence: test directories / file listings and key configuration (path:line)

  2) Coverage Mapping Table (mandatory):
     - use each Prompt requirement / risk item as a row, and list:
       [requirement / risk item]
       [corresponding test case (file:line)]
       [key assertion / fixture / mock (file:line)]
       [coverage judgment]
       [gap]
       [smallest test addition recommendation]

  3) Security Coverage Audit (mandatory; higher priority than style issues):
     - authentication (login / token / session handling)
     - frontend route protection / route guards
     - page-level / feature-level access control
     - sensitive information exposure
     - cache / state isolation after switching users
     For each item above, provide the coverage conclusion and a reproduction idea, even if not executed.

  4) Overall judgment: “Are the tests sufficient to uncover most issues?” (mandatory)
     - the conclusion must be one of: Pass / Partial Pass / Fail / Cannot Confirm
     - you must define the judgment boundary: which key risks are already covered, and which uncovered risks mean the project could still contain serious defects even if tests pass

  5) Do not start Docker or run Docker-related commands
```
