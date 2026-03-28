## **一、 项目简介与须知**

### **1.1 项目目标**

本项目旨在构建高质量的代码仓库数据。任务核心是基于给定的 Prompt（需求描述），**从 0 到 1 构建完整的、结构规范的、可运行的代码项目。**

提交产物

### **1.2 基本要求**

* **人员资质** ：需具备2年以上开发经验，**熟练掌握 Vibe Coding（AI辅助编程）**。
* **工具使用** ：
* **开发作业模型统一用：****ClaudeCli****➕ Claude-opus-4-6【最新】**
* **自测校验统一用：Codex cli➕ gpt-5.3-codex-bak**
* **保密原则** ：**严禁泄露题目内容、Prompt 数据及产出结果，违者将追究法律责任。**

## **二、 作业全流程指南**

### **Step0** **： ** **前提条件** **（如尚未通过准入考试，则先参加准入考试）**

**通过准入测试****，注册平台并在平台上领取和提交任务【平台上必须在****云电脑操作****】**

### **Step1：领题与判断** **（如尚未通过准入考试，则先参加准入考试）**

1. **领取任务** ：领取 Prompt，填写领题人姓名及开始时间。
2. **题目筛选（废弃标准）** ： 拿到题目后先进行评估，若遇到以下情况， **请勿做题** ，直接按“废弃/不可做”处理并备注原因：
3. **依赖外部不可控 API** ：核心功能必须调用第三方 SaaS 或无 Mock 的外部接口。
4. **环境限制** ：桌面程序外强制要求 Windows 系统才能运行。
5. **题目残缺** ：Prompt 缺失核心主题（如“请写个网站”无具体内容）或缺失必要的图片/链接素材。

### **Step2：开发与生成**

安装方式：[Codex/Opencode安装教程](https://j0t9xglvod.feishu.cn/wiki/QCX8wnWrmi6Wpmkd3XzcMPRQnWc?from=from_copylink)

* **核心目标** ：产出必须是一个 **完整的工程** 。
* **技术栈选择** ：严格遵循 Prompt 中的技术栈要求。如未指定，请参考附录中的《推荐技术版本》。

### **Step3：标准化交付（demo：** **demo.zip****）**

**静态产物标准检测脚本参考****[交付物产物须知](https://j0t9xglvod.feishu.cn/wiki/EMSSwfJtniDeSokRG33cjtVyn5c)**

**⚠️**** 重要：除纯前端（Pure Frontend）及部分移动端/桌面项目外，所有后端及全栈项目必须符合以下容器化交付标准：**

| 项目类型         | 容器化要求 | 启动方式                                                                                                                                                     | 依赖声明               | 端口暴露                   | README文档                           | 模型轨迹文件                        |
| ---------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------- | -------------------------- | ------------------------------------ | ----------------------------------- |
| Web前端          | 不要求     | 说明启动命令即可                                                                                                                                             | 说明依赖安装方式       | 说明访问端口               | 必须包含启动命令、访问地址、验证方法 | 必须提供（JSON、session、说明文档） |
| 移动端 (iOS)     | 不要求     | 说明构建/运行方式                                                                                                                                            | 说明依赖管理           | 说明调试方式               | 必须包含构建命令、运行方式、验证方法 | 必须提供（JSON、session、说明文档） |
| 移动端 (Android) | 不要求     | 说明构建/运行方式                                                                                                                                            | 说明依赖管理           | 说明调试方式               | 必须包含构建命令、运行方式、验证方法 | 必须提供（JSON、session、说明文档） |
| 移动端 (鸿蒙OS)  | 不要求     | 说明构建/运行方式                                                                                                                                            | 说明依赖管理           | 说明调试方式               | 必须包含构建命令、运行方式、验证方法 | 必须提供（JSON、session、说明文档） |
| 桌面端 (Desktop) | 部分不要求 | 说明启动方式                                                                                                                                                 | 说明依赖安装           | 说明访问方式               | 必须包含启动命令、服务地址、验证方法 | 必须提供（JSON、session、说明文档） |
| 桌面端 (macOS)   | 部分不要求 | 说明启动方式                                                                                                                                                 | 说明依赖安装           | 说明访问方式               | 必须包含启动命令、服务地址、验证方法 | 必须提供（JSON、session、说明文档） |
| 后端项目         | 必须       | docker compose up                                                                                                                                            | docker-compose.yml声明 | docker-compose.yml显式暴露 | 必须包含启动命令、服务地址、验证方法 | 必须提供（JSON、session、说明文档） |
| 全栈项目         | 必须       | docker compose up                                                                                                                                            | docker-compose.yml声明 | docker-compose.yml显式暴露 | 必须包含启动命令、服务地址、验证方法 | 必须提供（JSON、session、说明文档） |
| 小程序           | 部份不要求 | 后端使用docker启动，前端说明启动方式：1. 安装微信开发者工具。``2. 交付经过混淆处理的代码压缩包。``3. 导入项目后,即便没有AppID,也可以选择"测试号"模式运``行。 | 说明依赖管理安装       | 说明前后端调试方式         | 必须包含启动命令、服务地址、验证方法 | 必须提供（JSON、session、说明文档） |

1. **启动命令** ：项目必须能通过且仅通过 `docker compose up` 一键启动。
2. **运行依赖** ：运行依赖必须通过docker-comepose 声明
3. **零****私有** **依赖** ：不得依赖本机环境，不得依赖内网或私有库g。
4. **服务暴露** ：在 `docker-compose.yml` 中显式暴露端口。
5. **README 规范** ：必须包含 Markdown 格式文档，明确说明：
6. 启动命令（How to Run）
7. 服务地址（Services List）
8. 验证方法（Verification）
9. **模型轨迹文件(openai格式 **  **，转换后的JSON文件、转换前的session文件、readme（说明文档）**  **)** **：**
10. 请大家使用ClaudeCli进行开发，并通过我们提供的脚本进行JSON转换，
11. 转换后结果例：[example.json](https://mf-dev.obs.cn-east-3.myhuaweicloud.com/llm/code/repo_gen/example.json)
12. 脚本：[convert_ai_session.py](https://mf-test.obs.cn-east-3.myhuaweicloud.com:443/Prompt2RepoTest/convert_ai_session.py?AccessKeyId=LWHINVH46A6T23FU2DFB&Expires=1804935440&Signature=Xpkuc7twyWg3HLBabEjIIkdGQVk%3D)
    Claude code 转换脚本**merge_claude_subagents_trajectory.py**

    示例: python merge_claude_subagents_trajectory.py -r ~/.claude/projects/`<project>` -o .../sessions/

    1. 本脚本支持自动识别并转换以下格式的 AI 对话历史为 OpenAI 标准格式:
       1. Claude JSONL
    2. 调取session文件遵循以下方法：
       ```Plain
       claude cli：
            macOS / Linux: ~/.claude/projects/
            Windows (PowerShell/CMD):  C:\Users\用户目录\.claude\projects\   
            sessions-index.json 是所有对话的索引文件里面有对话对应的session_id ，找到对应session_id的完整日志文件   
       ```
13. **产物附件结构规范**

**提交的压缩包必须严格遵循以下目录结构：**

```Bash
压缩包根目录/
├── [项目类型名称]/          # 如：pure_backend、pure_frontend、fullstack 等
│   └── [项目文件...]        # 清理后的项目代码
├── prompt.md                # 原始 Prompt 文件
├── trajectory.json          # 转换完毕的 OpenAI 格式轨迹文件 
│                            # 多个轨迹文件的情况下改为sessions文件夹，trajectory-1.json 加编号
├── questions.md             # （必需）对原始 Prompt 的疑问问题记录
└── docs/                # 文档产物
    └──design.md        # 设计文档              
    └──api-spec.md     # API 规格说明
    └── ...         
```

**必需文件说明：**

* questions.md：记录你在理解 Prompt 过程中的所有疑问
  * questions.md：记录你在理解 Prompt 中**业务逻辑**时的所有疑问
  * 重点：业务流程、业务规则、数据关系、边界条件等业务层面的不明确之处
  * 格式：问题 + 你的理解/假设 + 解决方式
  * 示例：
    ```Markdown
    必需文件说明：

         业务逻辑疑问记录

         1. 订单取消后的库存回退逻辑
         - 问题：Prompt 提到"用户可以取消订单"，但未说明已支付订单取消后库存如何处理
         - 我的理解：已支付订单取消应立即回退库存，未支付订单超时自动取消
         - 解决方式：实现了订单状态机，取消时触发库存回退事件

        2. 用户权限的继承关系
         - 问题：Prompt 中有"管理员"和"超级管理员"，但未明确权限范围差异
         - 我的理解：超级管理员可管理所有数据，普通管理员只能管理自己创建的数据
         - 解决方式：在权限表中增加 scope 字段区分权限范围

        3. 数据删除是物理删除还是逻辑删除
         - 问题：Prompt 未说明"删除用户"是真删除还是标记删除
         - 我的理解：考虑到数据审计需求，采用逻辑删除（soft delete）
         - 解决方式：所有表增加 deleted_at 字段
    ```

 **注：建议大家尽可能地先使用目前给出转换脚本的几种开发工具）。尽可能地使用AI工具辅助开发** ，如果需要手改，应把手改后的内容按照json格式上传：大致格式如下：

```JSON
{
    "messages": [
        {
            "role": "str",
            "content": [
                {
                    "type": "str",
                    "text": "str"
                }
            ]
        },
        {
            "role": "str",
            "content": [
                {
                    "type": "str",
                    "text": "str"
                },
                {
                    "type": "str",
                    "tool_call_id": "str",
                    "name": "str",
                    "arguments": "str"
                }
            ],
            "tool_calls": [
                {
                    "id": "str",
                    "type": "str",
                    "function": {
                        "name": "str",
                        "arguments": "str"
                    }
                }
            ]
        },
        {
            "role": "str",
            "tool_call_id": "str",
            "content": [
                {
                    "type": "str",
                    "text": "str"
                }
            ]
        },
        {
            "role": "str",
            "content": [
                {
                    "type": "str",
                    "tool_call_id": "str",
                    "name": "str",
                    "arguments": "str"
                }
            ],
            "tool_calls": [
                {
                    "id": "str",
                    "type": "str",
                    "function": {
                        "name": "str",
                        "arguments": "str"
                    }
                }
            ]
        },
        {
            "role": "str",
            "tool_call_id": "str",
            "content": [
                {
                    "type": "str",
                    "text": "str"
                }
            ],
            "metadata": {
                "exit_code": "int",
                "duration_seconds": "float"
            }
        },
        {
            "role": "str",
            "tool_call_id": "str",
            "content": [
                {
                    "type": "str",
                    "text": "str"
                }
            ],
            "metadata": {
                "duration_seconds": "float"
            }
        }
    ],
    "meta": {
        "session_meta": {
            "id": "str",
            "timestamp": "str",
            "cwd": "str",
            "originator": "str",
            "cli_version": "str",
            "source": "str",
            "model_provider": "str",
            "base_instructions": {
                "text": "str"
            },
            "git": {}
        },
        "turn_contexts": [
            {
                "cwd": "str",
                "approval_policy": "str",
                "sandbox_policy": {
                    "type": "str",
                    "network_access": "bool"
                },
                "model": "str",
                "personality": "str",
                "collaboration_mode": {
                    "mode": "str",
                    "settings": {
                        "model": "str",
                        "reasoning_effort": "str",
                        "developer_instructions": "str"
                    }
                },
                "effort": "str",
                "summary": "str",
                "user_instructions": "str",
                "truncation_policy": {
                    "mode": "str",
                    "limit": "int"
                },
                "_timestamp": "str"
            },
            {
                "cwd": "str",
                "approval_policy": "str",
                "sandbox_policy": {
                    "type": "str"
                },
                "model": "str",
                "personality": "str",
                "collaboration_mode": {
                    "mode": "str",
                    "settings": {
                        "model": "str",
                        "reasoning_effort": "str",
                        "developer_instructions": "str"
                    }
                },
                "effort": "str",
                "summary": "str",
                "user_instructions": "str",
                "truncation_policy": {
                    "mode": "str",
                    "limit": "int"
                },
                "_timestamp": "str"
            }
        ],
        "token_counts": "NoneType"
    }
}
```

#### 字段解释：

##### `messages` 消息数组

每个对象根据 `role` 不同有不同结构：

| 字段                                | 说明                                      |
| ----------------------------------- | ----------------------------------------- |
| `role`                            | 消息角色：`user`/`assistant`/`tool` |
| `content`                         | 内容数组，包含文本或工具调用              |
| `content[].type`                  | 内容类型：`text`/`tool_use`           |
| `content[].text`                  | 文本内容                                  |
| `content[].tool_call_id`          | 工具调用ID                                |
| `content[].name`                  | 函数名                                    |
| `content[].arguments`             | JSON参数字符串                            |
| `tool_calls`                      | 工具调用列表                              |
| `tool_calls[].id`                 | 工具调用唯一标识                          |
| `tool_calls[].type`               | 固定为 `function`                       |
| `tool_calls[].function.name`      | 函数名                                    |
| `tool_calls[].function.arguments` | JSON参数                                  |
| `tool_call_id`                    | 关联的工具调用ID                          |
| `metadata.exit_code`              | 进程退出码（0=成功）                      |
| `metadata.duration_seconds`       | 执行耗时                                  |

##### `meta` 会话元数据

`session_meta` 会话级信息

| 字段                       | 说明                      |
| -------------------------- | ------------------------- |
| `id`                     | 会话唯一ID                |
| `timestamp`              | 会话创建时间（ISO8601）   |
| `cwd`                    | 当前工作目录              |
| `originator`             | 会话发起方（cli/ide/web） |
| `cli_version`            | CLI版本号                 |
| `source`                 | 客户端来源（如vscode）    |
| `model_provider`         | 模型提供商                |
| `base_instructions.text` | 系统基础指令/提示词       |
| `git`                    | Git仓库信息               |

`turn_contexts` 轮次上下文

| 字段                                                   | 说明                              |
| ------------------------------------------------------ | --------------------------------- |
| `cwd`                                                | 该轮次工作目录                    |
| `approval_policy`                                    | 工具审批策略（auto/always/never） |
| `sandbox_policy.type`                                | 沙箱类型                          |
| `sandbox_policy.network_access`                      | 是否允许网络访问``                |
| `model`                                              | 使用的模型名称                    |
| `personality`                                        | 助手人格设定                      |
| `collaboration_mode.mode`                            | 协作模式（single/multi）``        |
| `collaboration_mode.settings.model`                  | 协作模型``                        |
| `collaboration_mode.settings.reasoning_effort`       | 推理努力程度``                    |
| `collaboration_mode.settings.developer_instructions` | 开发者指令``                      |
| `effort`                                             | 当前轮次努力程度                  |
| `summary`                                            | 轮次摘要                          |
| `user_instructions`                                  | 该轮次用户指令                    |
| `truncation_policy.mode`                             | 上下文截断策略                    |
| `truncation_policy.limit`                            | 上下文长度限制                    |
| `_timestamp`                                         | 该轮次时间戳                      |

#### 其他

| 字段             | 说明                        |
| ---------------- | --------------------------- |
| `token_counts` | Token消耗统计（当前为null） |

### **Step 4：自测与存证**

在提交前，必须按照质量验收标准（见第三节）进行自测，并保留：

1. **运行截图** ：对产物实际运行效果进行截图。
2. **填写说明** ：在[交付物连接](https://j0t9xglvod.feishu.cn/share/base/form/shrcnkujHjF5FsWRw1vRIQvGefg)的“自测情况”栏填写简要说明，并将产物代码包与自测截图、自测视频一并上传（详见 **Step3的demo文件** ）。
3. **在自测时，可以利用****codex cli+****gpt-5.3-codex-bak****进行自测，降低返修率，并遵循以下原则：**
   1. **另开一个session**
   2. **大模型自测得到的结果仅用于项目主线session的多轮交互用，自测session无需提交**
   3. **大模型自测的各个维度提示词：****[AI report prompt ](https://j0t9xglvod.feishu.cn/wiki/JLHnwDgoriFP54kyShtcMKyzncb)**

### **Step 5：提交与质检**

* 提交后将进入 QA 质检流程。
* **返修规则：不合格产物将打回，最多允许3次返修。超过3次仍不合格，该题不予结算。**

## 三、 质量验收标准

 **重要提示** ：在提交任务前，请务必对照以下六大维度进行逐项自测。

**第一优先级 如果提示词是英文必须保证交付代码里不能有任何中文，轨迹文档里也必须保证全英文，此为最高优先级红线指标**

 **3.1 和 3.2 为红线指标** ：一旦违反将直接判定为“不合格”，原则上不进入返修流程，直接废弃。

 **3.3 至 3.6 为质量指标** ：影响评分及返修次数，多次不达标将影响后续任务派发。

**提交时必须提交自测报告：****用codex****新开session 将题目prompt 拼接填入****[AI report prompt ](https://j0t9xglvod.feishu.cn/wiki/JLHnwDgoriFP54kyShtcMKyzncb)****中的测试指令中，自测项目合格度并提交报告，否则直接打回**

#### 3.1 硬性门槛（One-Vote Veto / 一票否决）

**核心原则：代码必须能跑，且必须跑的是题目要求的内容。**

##### **3.1.1 绝对的可性**

 **一键启动** ：交付物必须严格支持docker compose up启动。若启动过程中报错（如依赖缺失、端口冲突、配置错误），直接不合格。

 **环境隔离** ：严禁出现“在我本地能跑”的情况。代码不得依赖你本地的绝对路径、特定的全局环境变量或未在 Dockerfile 中声明的系统库。

 **文档一致** ：README 中的启动步骤必须真实有效，验证者无需自行猜测或修改源码即可运行。

##### **3.1.2 严格的切题性**

 **核心目标一致** ：必须严格围绕 Prompt 描述的业务目标开发。例如 Prompt 要求“实现一个支持多轮对话的客服系统”，仅实现“单次问答”即视为偏题。

 **禁止擅自简化** ：严禁通过大幅削减功能、替换核心需求（如将“实时WebSocket通信”简化为“HTTP轮询”）来降低开发难度。

#### **3.2 交付完整性**

**核心原则：交付的是产品雏形，而不是代码片段**

##### **3.2.1 具备工程化结构（0-1 完整度）**

 **项目形态** ：交付物必须是一个完整的工程项目，具备清晰的目录结构（如 src, config, public, tests 等）与代码结构层级。

 **拒绝片段** ：严禁提交单文件代码（如一个几千行的 main.py或 index.html）或仅提供核心函数的代码片段。必须包含完整的配置文件（package.json, pom.xml, requirements.txt 等）。

##### **3.2.2 真实逻辑实现（拒绝 Mock 欺骗）**

 **逻辑真实** ：除非 Prompt 明确要求使用 Mock 数据（或涉及无法调用的外部昂贵 API），否则核心业务逻辑必须真实实现。

 **严禁硬编码** ：例如，登录接口不能直接返回 `return "Login Success"`，必须包含校验逻辑；查询接口不能直接返回写死的 JSON 列表，需包含数据查询或处理逻辑。

#### **3.3 工程与架构质量**

 **核心原则：代码需具备可维护性，符合行业通用规范**  **，满足最佳实践** **。**

##### **3.3.1 架构分层合理**

 **职责分离** ：代码结构应体现“高内聚、低耦合”。

 **后端** ：推荐采用标准分层架构，严禁将数据库操作、业务逻辑和 API 定义混杂在同一个函数中。

 **前端** ：组件应合理拆分，避免出现数千行的“上帝组件”。

 **文件组织** ：目录命名应具有语义化，让人一目了然（如 /utils, /components, /api）。

##### **3.3.2 代码整洁度（无垃圾文件）**

* 清理冗余：提交前必须清理所有依赖目录、缓存文件和构建产物（详见 Step 3 产物附件结构规范）。
* 配置脱敏：确保配置文件中不包含你个人的密钥（AK/SK）、内网 IP 或敏感信息。
* 代码质量：删除被注释掉的大段废弃代码、调试用的 print/console.log 语句。
* API接口整洁：若项目中存在API接口，在接收API接口返回时，须进行API接口的内容的美化，防止返回一些结构不清晰的json，详见如下例：
  **Example：**    **不整洁示例：（仅可靠猜，可读性差）：                                      整洁示例：（做分页，保证可读）：**

  ![](https://j0t9xglvod.feishu.cn/space/api/box/stream/download/asynccode/?code=MzAzODdjNzVlNWQ1Nzk3MDAxMDAyODI4YzIyZDRkMWJfRjgzZ2ptSW4wNVFBOHFlNmRMcE1mZWplTGtUeFZSOUFfVG9rZW46TnhpSmJMdFo5b2FHMFJ4M3pXUGNidmU4blNlXzE3NzQ2MjUzNTk6MTc3NDYyODk1OV9WNA)![](https://j0t9xglvod.feishu.cn/space/api/box/stream/download/asynccode/?code=ZDY5ZmQ4MTJiNWNhNDc2NGQ3OTE3N2MzZDkwOGRiYWZfclZQM3JyalRJUXZWbjVWWUJ4cXo2ZGM1aXgyVldZeThfVG9rZW46SFlrWmJxMXN5b09WaXN4WGp5dmNYWVJiblRuXzE3NzQ2MjUzNTk6MTc3NDYyODk1OV9WNA)

##### **3.3.3 可维护性与扩展性**

 **拒绝一次性代码** ：逻辑设计应考虑扩展性，避免大量的 Magic Number（魔术数字）或深层嵌套的 `if-else`。

##### **3.3.4 测试标准**

项目须提供完整、可执行的测试验证方案及相关测试材料，作为系统验收的必要组成部分。测试目标在于验证系统核心功能、关键业务逻辑及异常处理机制的正确性、稳定性和健壮性。

测试验证必须同时包含**单元测试**与 **API 接口功能测试** ，两类测试均为验收必备内容，不得缺失。测试要求及示例如下：

###### **3.3.4.1 单元测试要求及示例**

单元测试应覆盖系统的主要功能模块、核心逻辑处理流程以及关键边界场景，重点验证内部逻辑实现的正确性。

 **示例说明** ：

* 针对核心业务计算逻辑，需提供对应的单元测试用例，验证正常输入、边界输入及非法输入情况下的处理结果是否符合预期；
* 对关键状态转换逻辑（如任务创建、执行、失败、重试等流程）应分别编写单元测试用例，验证各状态下的行为正确性；
* 对异常处理逻辑，应通过构造异常场景（如空值、超范围参数等）验证系统能够正确返回错误信息并保持稳定运行。

###### **3.3.4.2 API 接口功能测试要求及示例**

API 接口功能测试应覆盖系统对外提供的主要接口，验证接口在不同输入条件下的功能完整性和稳定性。

 **示例说明** ：

* 对核心业务接口，需提供接口调用测试，验证接口在正常请求参数下能够返回正确响应结果；
* 针对参数缺失、参数格式错误、权限不足等异常场景，应提供对应的接口测试用例，验证接口返回的错误码和错误信息符合接口设计规范；
* 对涉及数据变更的接口，应验证接口调用前后系统状态或数据结果的正确性。

###### **3.3.4.3 测试执行方式与结果输出要求**

项目根目录下**必须包含**以下测试目录结构，作为验收时的必检项：

* `unit_tests/`：用于存放单元测试脚本及相关测试资源；
* `API_tests/`：用于存放 API 接口功能测试脚本及相关测试资源。

所有测试须通过 **Shell 脚本**方式统一组织和执行，测试脚本应支持一键执行，且具备可重复运行能力。

 **示例说明** ：

* 可在项目根目录中提供统一的测试执行脚本（如 `run_tests.sh`），脚本执行后可自动调用 `unit_tests/` 和 `API_tests/` 目录下的全部测试用例；
* 测试执行过程中，应在终端或日志文件中输出清晰、可读的测试结果信息，包括每个测试用例的执行状态（成功 / 失败）、失败原因及必要的错误日志；
* 测试执行完成后，应输出测试结果汇总信息（如测试用例总数、通过数、失败数），便于验收人员快速判断测试覆盖范围和执行情况。

###### **3.3.4.4验收判定要求**

测试用例需覆盖 **绝大多数功能点和主要业务逻辑路径** 。验收时，验收方可通过执行测试脚本并检查测试输出结果，确认测试是否完整执行且结果符合预期。

如缺少单元测试或 API 接口测试、测试覆盖明显不足、测试脚本无法执行或测试结果输出不清晰，均视为 **不满足验收要求** 。

#### **3.4 工程细节与专业度**

**核心原则：按生产级代码的标准要求自己。**

##### **3.4.1 健壮的错误处理**

 **优雅降级** ：接口报错时，应返回标准的 HTTP 状态码及清晰的 JSON 错误提示（如 `{"code": 400, "msg": "Invalid email format"}`），严禁直接抛出原本的 Stack Trace（堆栈信息）或导致服务崩溃无响应。

 **前端容错** ：接口请求失败时，UI 应有相应的 Toast 提示或缺省页，不能白屏或无反应。

##### **3.4.2 规范的日志记录**

 **有效日志** ：关键业务流程（如登录、支付、数据变更）必须有日志输出。

 **日志质量** ：日志应包含必要上下文，方便排查问题。拒绝毫无意义的日志（如print("here"), console.log("111")）。

##### **3.4.3 安全与参数校验**

 **输入防御** ：对前端传入的所有参数（Body, Query, Path）进行合法性校验（判空、格式、长度限制）。

 **基本安全** ：避免明显的安全漏洞（如直接拼接 SQL 字符串、在前端明文存储密码等）。

#### **3.5 需求理解深度**

 **核心原则：做完、做对**  **、做好** **。**

##### **3.5.1 识别隐含约束**

    **业务闭环** ：不仅要实现字面上的功能，还要思考业务场景的合理性。例如：

  电商系统：库存扣减不能为负数。

  预定系统：同一时间段不能重复预定。

   **逻辑自洽** ：数据流转必须逻辑通顺，不能出现前台显示成功但后台未存储的情况。

**3.5.2 拒绝机械式翻译**

 **场景适配** ：代码实现应贴合 Prompt 设定的用户规模和使用场景，而非生搬硬套通用的模板。

#### **3.6 美观度（仅限前端/全栈/移动端题目）**

**核心原则：界面应整洁、现代，具备基本的交互可用性。**

##### **3.6.1 视觉规范**

 **布局整齐** ：元素对齐、间距统一（Margin/Padding 合理），无内容溢出、错位或乱码。

 **配色和谐** ：色彩搭配符合主色调，对比度适宜，不刺眼。

 **现代化** ：推荐使用主流 UI 框架（如 Ant Design, Material UI, Tailwind CSS, Bootstrap 等）提升美观度。

##### **3.6.2 交互体验**

 **操作反馈** ：按钮点击应有反馈（Loading 状态、禁用状态），鼠标悬停应有样式变化。

 **流程顺畅** ：页面跳转逻辑清晰，没有死链，用户能够顺畅完成核心业务操作。

#### **3.7 不可验收情况**

Docker 交付的目的是为了确保“环境一致性”和“验证低成本”。若出现以下任一情况，视为交付物不可用， **直接判定为不合格（不可验收），不进入代码细节评审阶段** 。

* **3.7.1 自动化启动失败**
  * **命令报错** ：在标准 Docker 环境下执行 `docker compose up` 时，构建（Build）过程报错或启动（Run）过程报错。
  * **容器崩溃** ：容器启动后无法保持运行状态（如陷入 CrashLoopBackOff 重启循环），或启动后立即退出。
  * **私有资源限制** ：Dockerfile 中引用了 **私有镜像仓库** （需鉴权）或无法在公网访问的基础镜像，导致拉取失败。
* **3.7.2 依赖人工干预或隐式操作**
  * **拒绝手动配置** ：需要验收人员手动创建文件（如手动创建 `.env`、手动复制 `config.example.js` 为 `config.js`）、手动创建文件夹或手动导入 SQL 脚本才能运行。
  * **拒绝交互式输入** ：启动脚本卡在命令行等待用户输入（如等待输入密码、确认 `y/n`），无法无人值守启动。
  * **依赖口头沟通** ：README 未写明，需要验收人员通过聊天工具询问“怎么跑”、“缺什么配置”才能启动。
* **3.7.3 环境隔离失效（在我本地能跑）**
  * **路径依赖** ：代码或配置中包含开发者的 **本地绝对路径** （如 `C:/Users/Admin/...` 或 `/Users/name/project/...`），导致在容器内无法找到文件。
  * **宿主依赖** ：容器内的服务尝试连接宿主机（Host）上的数据库、Redis 或其他并未在 docker-compose 中声明的服务。
  * **全局环境依赖** ：代码依赖了并未在 Dockerfile 中安装，而是依赖开发者本地全局环境安装的库或工具（如全局的 `npm` 包、全局 `python` 库）。
* **3.7.4 文档与实际行为不一致**
  * **虚假文档** ：README 中声明的验证步骤（URL、API 路径、测试账号）与实际代码行为不符。
  * **端口欺骗** ：文档声称服务运行在 `8080` 端口，实际 docker-compose 暴露的是 `3000` 端口，且未做说明。
  * **验证不可达** ：按照文档操作，无法看到预期的服务界面或接收到正确的 API 响应。
* **3.7.5 依赖污染**
  * 项目目录中包含 `node_modules/`、`.venv/` 等依赖目录，导致镜像构建时体积过大或出现版本冲突。

---

## **四、 附录：参考技术标准**

### **1. 任务类型分类参考**

在填写表格时，请按以下逻辑归类任务：

| 任务类型 (Task Type) | 定义特征                                                          |
| -------------------- | ----------------------------------------------------------------- |
| pure_frontend        | 纯 Web 页面，无真实后端（可用 Mock/LocalStorage），关注 UI/交互。 |
| pure_backend         | 无 UI 或 UI 极简，核心是 API、数据处理、逻辑算法。                |
| full_stack           | 既有 Web 页面 又有 真实后端服务 + 数据库。                        |
| mobile_app           | Android / iOS 原生开发，或 Flutter / RN 等移动端应用。            |
| cross_platform_app   | uni-app / Taro / Electron / 小程序等跨端框架。                    |

### **2. 推荐运行环境版本**

为确保兼容性，建议在以下基线版本上进行开发和测试：

#### 前端

* **Node.js** : 18.x LTS 及以上( ≥18.16.0)
* Npm 9.x 或 pnpm 8.x

#### 后端

* **Node.js** : 18.x LTS
* **Python** : 3.10.x
* **Java** : 17.x LTS

#### 外部

* **MySQL** :  ≥ 8.0.x
* **SQLite** ： ≥ 3.39
* **PostgreSQL**  ≥ 14
* **Chrome** : 版本 ≥ 120
