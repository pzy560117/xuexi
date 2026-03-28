# Superpowers + Ralph-Loop：内外双循环组合让 Claude Code 编程效率翻倍

**原创** 暴走的xiao松鼠 [暴走的xiao松鼠](javascript:void(0);)

 *2026年3月22日 23:58* *上海* **12人**

![](http://mmbiz.qpic.cn/sz_mmbiz_png/j9VJVb2KvqnUGPNfmdYd2xia2cRhaWvMqicmIaYTbTozefGibm4JQWZTncX57B56dj9LbhFpQVQT5yZTa5zImrysA/300?wx_fmt=png&wxfrom=19)

**暴走的xiao松鼠**

🐿️ 我是小松鼠，探索AIGC，学习AI编程，喜欢分享AI知识与个人感悟 ✨

**60篇原创内容**

公众号

大家好，我是小松鼠。

一名AI时代的学习者，专注探索个体在新时代的生存模式。

这是我的 第 58 篇 AIGC 文章。

最近我发现了一个让 Claude Code 编程效率翻倍的组合——Superpowers + Ralph-Loop。

今天小松鼠带你搞明白这两玩意儿到底是什么，怎么结合使用的。

## 一、先搞清楚基本概念

### Superpowers 是什么

Superpowers 是 Claude Code 的一个插件。

它本质上是一套工程化的开发工作流。

以前用 Claude Code 写代码，AI 想怎么写怎么写，容易写成"屎山"。Superpowers 把一整套专业工程团队的开发方法论固化下来，让 AI 编程时自动遵循最佳实践。

核心就三板斧：

1. Brainstorming（头脑风暴）

AI 和你苏格拉底式对话，帮你理清真正的需求。不是你说什么它就写什么，而是会追问一堆问题确保你真的想清楚了。

2. Writing Plans（写计划）

把需求拆成 2-5 分钟的小任务，每个任务包含：

* 精确的文件路径
* 完整的代码片段
* 明确的验证步骤

3. Executing Plans（执行计划）

AI 按照计划分批执行，每个任务都有检查点。不是一上来就闷头写代码，而是先写测试，再写实现。

### Ralph-Loop 是什么

Ralph-Loop 是一个会话循环机制。

它的核心价值就两点：

1. 解决上下文污染问题

长对话中，AI 会变得"越来越笨"。错误尝试、冗余信息都堆在上下文窗口里，AI 注意力分散。Ralph-Loop 每次循环强制 AI 重新开始，让 AI 通过读取文件（日志、待办列表）来获取状态，而不是靠记忆。

2. 防死循环

内置智能退出检测，当任务真正完成时才退出，否则一直跑。还支持设置最大迭代次数，防止失控。

实现方式很有意思：通过一个 stop-hook（停止钩子）拦截退出操作，把上一次 AI 的输出作为下一次输入塞回去，形成"自我引用循环"。

## 二、BDD 和 TDD 的区别

补充个知识点：

之前我们提到过spec-kit，规范驱动开发。

其中提到了TDD的思想。而这里Superpowers用的是BDD，两者有区别。

TDD = Test-Driven Development（测试驱动开发）

先写测试，再写实现。测试用例是技术层面的验证。

BDD = Behavior-Driven Development（行为驱动开发）

先设计行为，再用测试用例描述行为。行为描述用的是自然语言，更贴近业务需求。

### 举个例子：实现"用户发布笔记"功能

TDD 方式（传统测试驱动）：

直接写技术测试用例，验证函数是否正常工作：

```
// user.test.js
test('publishNote函数应该返回包含id和timestamp的对象', () => {
  const result = publishNote({ userId: '123', content: 'Hello' });
  expect(result).toHaveProperty('id');
  expect(result).toHaveProperty('timestamp');
});
```

```
// user.js
function publishNote({ userId, content }) {
  return {
    id: generateId(),
    timestamp: Date.now(),
    userId,
    content
  };
}
```

BDD 方式（Superpowers 采用）：

先用自然语言描述行为，再写测试验证行为：

```
# bdd-specs.md

功能：用户发布笔记

场景：用户成功发布笔记
  Given 用户已登录
  And 用户在笔记输入框输入了内容
  When 用户点击发布按钮
  Then 笔记显示在时间线顶部
  And 笔记包含发布的时间和内容
  And 输入框被清空

场景：用户未登录
  Given 用户未登录
  When 用户尝试发布笔记
  Then 显示登录提示
  And 笔记不被发布
```

### 两者区别在哪

TDD 写的是"函数应该返回什么"，BDD 写的是"系统应该做什么"。

TDD 的测试用例只有开发者能看懂，PM 看不懂。

BDD 的场景用自然语言写，PM、设计师、开发者都能看懂。

但这不意味着 BDD 不定义数据结构。

实际上，完整的 BDD 场景，在Then 阶段不仅要描述行为，还要明确返回的数据结构。

尤其是前后端分离的场景，数据结构类型必须对齐。

比如

```
场景：用户未登录
  Given 用户未登录
  When 用户尝试发布笔记
  Then 返回状态码 401
  And 返回数据结构：
      ```json
      {
        "error": "UNAUTHORIZED",
        "message": "用户未登录，请先进行登录",
        "code": 401
      }
      ```
```

这种叙事化的描述，更关心流程中的数据对齐，而不是单独拆开前后端接口文档。

## 三、两者是怎么结合的

分开看都有局限：

* Superpowers ：擅长结构化开发，把大任务拆成 BDD 驱动的小任务，Agent Team 并行执行。

但长时间运行后上下文会污染

* Ralph-Loop ：每次循环强制 AI 重置大脑，通过读取文件获取状态（每次循环不依赖上下文）

但没有清晰的任务结构和质量把控

这两者是完全互补的

😀Ralph-Loop 是外层循环，驱动会话持续运行。

Superpowers 是内层循环，负责执行具体的开发任务。

### Ralph-Loop 的核心机制

Ralph-Loop 的循环是通过 stop-hook（停止钩子） 实现的。

![Image](https://mmbiz.qpic.cn/mmbiz_png/aggHiadswE00ANKmRZlkLOs7bp5yicfymry8teYlggokkNEhD0jenTT5NE97nhIoTwv46KT7kdGicargCJCvEyxZH4IZLzX08hv2AGI2jZiacV4/640?wx_fmt=png&from=appmsg)

关键文件在 superpowers/hooks/stop-hook.sh：

```
# 每次退出时检查是否存在状态文件
for candidate in .claude/superpower-loop*.local.md; do
  # 读取状态：迭代次数、最大迭代、completion_promise
done

# 如果没达到上限，就继续循环
NEXT_ITERATION=$((ITERATION + 1))
# 把上一次 AI 输出塞回去作为新输入
```

### 状态文件追踪进度

状态文件 .claude/superpower-loop.local.md 是 Ralph 的"记忆"：

```
---
active: true
iteration: 1
session_id: xxx
max_iterations: 100
completion_promise: "EXECUTION_COMPLETE"
started_at: "2026-03-22T10:00:00Z"
---

# 这里的任务是 AI 第一次执行的输入
```

每次循环，AI 不再依赖对话上下文，而是读取这个文件获取进度。

### Superpowers 如何触发 Ralph

关键在 executing-plans skill 的第一行：

```
# executing-plans/SKILL.md
**THIS MUST BE YOUR FIRST ACTION. Do NOT resolve the plan path,
do NOT read files, do NOT do anything else until you have started the Superpower Loop.**

1. Resolve the plan path
2. Immediately run:
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-superpower-loop.sh" \
  "Execute the plan at <resolved-plan-path>..." \
  --completion-promise "EXECUTION_COMPLETE" \
  --max-iterations 100
```

所以结合方式是：

Superpowers 在执行计划时，

自动调用 setup-superpower-loop.sh 创建状态文件，

stop-hook 接管退出动作，实现循环。

完整工作流程：

![Image](https://mmbiz.qpic.cn/sz_mmbiz_png/aggHiadswE03pd5XM2orQT6D8CDQyRHVJVUj1QRk2v4vkJKwLBu70xkB4lCMdCFbdGgkf7MHziaP7IsPo5VdvVsPSibpJicERIzibg3UwjnqSM3Y/640?wx_fmt=png&from=appmsg)

## 四、能完成什么事情

Ralph-Loop 擅长的是大循环任务：

场景一：通宵跑任务

你下班前启动一个复杂任务，AI 通宵跑，第二天来查看结果。所有进度存在文件系统里，不依赖对话上下文。

场景二：多轮迭代优化

AI 写完初版 → 你提出反馈 → AI 迭代 → 再反馈 → 再迭代。循环一直跑，直到达到你的要求。

场景三：PRD 文档转项目

Ralph for Claude Code 支持直接导入 PRD 文档，AI 自动拆解成任务清单，然后循环执行开发。

结合 Superpowers 之后，这些场景的开发质量更高：

* 每一步都有 BDD 行为验证
* Agent Team 支持多人协作（Red Agent 写测试，Green Agent 写实现）
* 两阶段审查（规格符合性 + 代码质量）

## 五、怎么使用

### 基本使用:

从规划到执行

```
1️⃣ /superpowers:brainstorming
   输入你的需求，AI 和你对话理清需求
   ↓
2️⃣ /superpowers:writing-plans [design-folder]
   AI 生成任务计划
   ↓
3️⃣ /superpowers:executing-plans [plan-folder]
   AI 执行计划，Ralph-Loop 自动激活
```

或者直接执行任务

```
# 不用三板斧，直接给任务
./scripts/setup-superpower-loop.sh "实现用户认证模块" --completion-promise "DONE" --max-iterations 50
```

#### Ralph 配置详解

Ralph 的配置在调用 setup-superpower-loop.sh时通过参数传入：

直接改这个脚本即可。

```
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-superpower-loop.sh" \
  "Brainstorm: $ARGUMENTS..." \
  --completion-promise "BRAINSTORMING_COMPLETE" \
  --max-iterations 50
```

关键参数说明：

设置退出条件：用 `--completion-promise` 设置一个完成标记，比如 `--completion-promise "ALL_TASKS_DONE"`，AI 完成任务后会自动退出

设置迭代上限：用 `--max-iterations 50` 防止失控，跑到 50 次自动停

## 六、实战测试指南

想亲手跑一跑？跟着下面步骤来。

### 第一步：安装插件

在 Claude Code 中执行：

```
# 添加插件市场
claude plugin marketplace add FradSer/dotclaude

# 安装 superpowers 插件
claude plugin install superpowers@frad-dotclaude
```

完成后重启 Claude Code 或刷新会话。

### 第二步：开启 Brainstorming

在 Claude Code 中输入：

```
/superpowers:brainstorming
```

然后输入你的需求，比如：

```
开发一个简单的待办事项命令行工具
```

AI 会开始和你苏格拉底式对话，追问你各种问题。

### 第三步：检查生成的文件

Brainstorming 完成后，会在项目根目录生成 docs/designs/ 文件夹：

这是所有的设计文档，可以在这里面手动调整

```
docs/designs/
├── _index.md                    # 设计文档索引
├── bdd-specs.md                # BDD 行为描述
├── architecture.md              # 架构设计
└── best-practices.md           # 最佳实践
```

实际生成的文件如下

![Image](https://mmbiz.qpic.cn/sz_mmbiz_png/aggHiadswE02ZH2P5VYNK6XlCxXKWjYRfUgJEib66fqy8zZI0lxUKk2rNkk6xmibjvmO3yXeSg109ibCXiaSzUL619S99OnL7Mq0Bs0d7XBgsM54/640?wx_fmt=png&from=appmsg)

bdd-specs.md 每一条的结构都类似

这个时期，可以很方便的调整想法，没有涉及到复杂的执行输出

```
### 场景：用户添加新任务
**Given** 用户在命令行输入 `todo add "完成项目报告" --priority=high`
**When** 命令执行
**Then** 返回成功消息，包含任务 ID
**And** 任务保存到 `~/.todo/tasks.json`

### 场景：用户列出所有待办任务
**Given** 任务列表中存在多个任务
**When** 用户执行 `todo list`
**Then** 显示所有 pending 状态的任务

### 场景：用户完成任务
**Given** 存在 ID 为 `abc123` 的待办任务
**When** 用户执行 `todo done abc123`
**Then** 任务状态变为 `done`
**And** 记录完成时间 `doneAt`
```

architecture.md包含系统架构：

```
├── src/
│   ├── index.js          # 入口文件
│   ├── commands/         # 命令处理器 (add/list/done/delete/clear)
│   ├── services/         # 业务逻辑 (TaskService/StorageService)
│   └── utils/            # 工具函数 (logger/validator)
└── tests/
    ├── unit/             # 单元测试
    └── integration/       # 集成测试
```

### 第四步：Writing Plans

这一步是把designs变成可用的plans

执行：

```
/superpowers:writing-plans docs/designs/2026-03-22-todo-cli-design/
```

实际生成的计划任务：

![Image](https://mmbiz.qpic.cn/sz_mmbiz_png/aggHiadswE02ia2gMuVaibkESjy5rRuKsDngMia1tqZymDrZ9ciczdI9Znl1AJwibShib1pV63hk1w3umhcBW3Ym9SnqYX8bLh8trZ3tklwSGgmOdQ/640?wx_fmt=png&from=appmsg)

```
docs/plans/
├── _index.md                    # 计划索引
├── task-001-setup.md           # 项目初始化
├── task-002-storage-impl.md    # StorageService 实现
├── task-002-storage-test.md    # StorageService 测试
├── task-003-task-service-impl.md # TaskService 实现
├── task-003-task-service-test.md # TaskService 测试
├── task-004-commands-impl.md   # 命令实现 (add/list/done/delete/clear)
├── task-004-commands-test.md   # 命令测试
├── task-005-logger.md          # Logger 工具
└── task-005-storage-helper.md   # StorageService 工厂函数
```

### 第五步：执行计划（触发 Ralph-Loop）

执行：

```
/superpowers:executing-plans docs/plans/
```

这一步会自动触发 Ralph-Loop，你会看到终端显示：

```
Superpower loop activated in this session!

State file: .claude/superpower-loop.local.md
Iteration: 1
```

![](https://mmbiz.qpic.cn/mmbiz_gif/aggHiadswE01ankibyLicS1DOccBS7C4sA2TItlC6G2Nm4PSdjhxygqWaG7fSkhzVTHfYsZ1TUGlwQGmCSHriaREUd6m5Va9FUib5boVZDuZW6Hg/640?wx_fmt=gif&from=appmsg)

然后 AI 开始自动执行任务

AI 开始循环后会自己跑，你只需要观察就行，或者你去睡觉也行

### 观察 Loop 运行

看日志：

```
# 查看当前迭代次数
grep '^iteration:' .claude/superpower-loop.local.md

# 查看状态文件内容
head -10 .claude/superpower-loop.local.md
```

你会看到任务进度被记录在文件系统里，而不是依赖 Agent 的上下文。

状态文件结构（.claude/superpower-loop.local.md）：

```
---
active: true
iteration: 1
session_id: xxx
max_iterations: 50
completion_promise: "BRAINSTORMING_COMPLETE"
started_at: "2026-03-22T10:00:00Z"
---

# 这里是初始 prompt
```

状态文件会实时更新，进度一目了然

### 尾声

好了，到这里，我们结合源码和实际示例。

带大家完整的演示了一遍Superpowers+Ralph-Loop的流程。

个人体验下来，可以放心交给他去迭代一些简单的任务。

后续小松鼠会去尝试下前后端分离，以及需要调用复杂skill的流程。

![](http://mmbiz.qpic.cn/sz_mmbiz_png/j9VJVb2KvqnUGPNfmdYd2xia2cRhaWvMqicmIaYTbTozefGibm4JQWZTncX57B56dj9LbhFpQVQT5yZTa5zImrysA/300?wx_fmt=png&wxfrom=19)

**暴走的xiao松鼠**

🐿️ 我是小松鼠，探索AIGC，学习AI编程，喜欢分享AI知识与个人感悟 ✨

**60篇原创内容**

公众号

看到这里了，如果觉得不错：

* 点个「赞」，让我知道你在看
* 点个「在看」，分享给更多朋友
* 点个「转发」，帮助更多人
* 加个「星标⭐」，第一时间收到推送

也可以加我的个人微信围观学习：archerqc

![](https://mmbiz.qpic.cn/sz_mmbiz_jpg/aggHiadswE02UcNz79kib6DpZKuIuCEGW5du0OwB1qspEymQBFEusVE3Q6PtBk6H5J0xbLPnopkb13dqRuEcWgXOvawCFc1xVJmmKoeaVLOIE/640?wx_fmt=jpeg&from=appmsg)

小松鼠爱你们！

**AI编程开发 · 目录**

**上一篇**浏览器自动化测试太耗token？vercel官方神器agent-browser，小白也能自然语言操作**下一篇**龙虾时代，提示词更加重要：Dspy框架详解-MIPROv2-让AI自己优化提示词

阅读 3580

[]()


[](javascript:)[](javascript:)

[](javacript:;)

![](https://mmbiz.qpic.cn/sz_mmbiz_png/j9VJVb2KvqnUGPNfmdYd2xia2cRhaWvMqicmIaYTbTozefGibm4JQWZTncX57B56dj9LbhFpQVQT5yZTa5zImrysA/300?wx_fmt=png&wxfrom=18)

**暴走的xiao松鼠**

关注

**88**

**919**

**63**

**14**

![](https://wx.qlogo.cn/mmopen/dx4Y70y9XcthFHKIgib6zibGN4kbepTCfWiaGnvIXzCsV6ozpQMChc0GAOTozh8SPyaQEDYBtv0w14SFgsSNdppu04nrdt0dbrZBtcj6F9SzGbJBh3j4glTibPuvumkxmOVW/96)

**复制**搜一搜

**复制**搜一搜

**暂无评论**
