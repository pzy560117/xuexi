# Spec: keyword-report

## ADDED Requirements

### Requirement: 支持 report 爬取模式

用户可以通过 `--type report` 参数启动报告生成模式，系统自动完成搜索、文案提取（含视频口播转文字）、评论爬取，并输出为结构化 Markdown 文档。

#### Scenario: 使用关键词生成包含口播文案的小红书报告

```
GIVEN 用户配置平台为 xhs，关键词为 "美食推荐"，启用视频转录
WHEN 用户执行 `uv run main.py --platform xhs --lt qrcode --type report --keywords "美食推荐"`
THEN 系统搜索小红书中 "美食推荐" 相关笔记
AND 遍历每个搜索结果，提取标题和正文文案
AND 对视频类内容，下载视频并使用 faster-whisper 转录口播文案
AND 爬取每个笔记的评论
AND 在 data/xhs/reports/ 目录生成一份 Markdown 报告文件
AND 报告中每个视频条目包含：标题文案、正文描述、口播文案（如有）、评论列表
```

#### Scenario: 关闭转录的轻量模式

```
GIVEN 用户设置 REPORT_ENABLE_TRANSCRIPTION = False
WHEN 用户执行报告模式
THEN 系统仅提取标题和描述文案，不下载视频、不进行语音转文字
AND 报告中不包含「视频口播文案」段落
AND 不需要 GPU/ffmpeg 环境依赖
```

#### Scenario: 使用关键词生成抖音报告

```
GIVEN 用户配置平台为 dy，关键词为 "Python教程"
WHEN 用户执行 `uv run main.py --platform dy --lt qrcode --type report --keywords "Python教程"`
THEN 系统搜索抖音中 "Python教程" 相关视频
AND 下载每个视频并转录口播文案
AND 爬取每个视频的评论
AND 在 data/dy/reports/ 目录生成一份 Markdown 报告文件
```

#### Scenario: 多关键词生成报告

```
GIVEN 用户提供多个关键词 "编程副业,编程兼职"
WHEN 用户执行 `uv run main.py --platform xhs --lt qrcode --type report --keywords "编程副业,编程兼职"`
THEN 系统依次搜索每个关键词
AND 将所有结果合并到一份报告中
AND 每个关键词作为报告中的独立章节
```

---

### Requirement: VideoTranscriber 视频口播文案提取

系统能够从视频 URL 下载视频、提取音频、转录为文字。

#### Scenario: 正常转录视频口播

```
GIVEN 一个有效的视频下载 URL
WHEN VideoTranscriber.transcribe(video_url) 被调用
THEN 系统下载视频到临时目录
AND 使用 ffmpeg 从视频中提取音频 (WAV 16kHz mono)
AND 使用 faster-whisper 将音频转为中文文本
AND 清理临时的视频和音频文件
AND 返回转录文本字符串
```

#### Scenario: 视频下载失败时优雅降级

```
GIVEN 一个无效或已过期的视频 URL
WHEN VideoTranscriber.transcribe(video_url) 被调用
THEN 系统记录错误日志
AND 返回空字符串
AND 不中断主报告生成流程
```

#### Scenario: 支持可配置的 Whisper 模型大小

```
GIVEN 用户设置 WHISPER_MODEL_SIZE = "small"
WHEN VideoTranscriber 初始化
THEN 加载 small 模型（244M）
AND 使用该模型进行后续转录
```

---

### Requirement: 报告文档格式规范

生成的报告遵循统一 Markdown 格式，包含口播文案段落。

#### Scenario: 报告包含完整的元信息头

```
GIVEN 报告生成完成
THEN 报告顶部包含：搜索关键词、平台名称、生成时间、内容总数、评论总数
```

#### Scenario: 视频类内容包含口播文案段落

```
GIVEN 一个视频内容成功转录了口播文案
THEN 报告中该条目在「文案」之后包含独立的「视频口播文案」段落
AND 该段落展示完整的转录文本
```

#### Scenario: 无口播文案时不显示该段落

```
GIVEN 一个内容没有视频（图文类）或转录失败
THEN 报告中该条目不包含「视频口播文案」段落
```

#### Scenario: 报告末尾包含统计摘要

```
GIVEN 报告生成完成
THEN 报告末尾包含数据统计表格：关键词、平台、内容总数、评论总数、平均评论数、爬取耗时
```

---

### Requirement: 报告输出路径可配置

#### Scenario: 使用默认输出目录

```
GIVEN 用户未指定 REPORT_OUTPUT_DIR
WHEN 报告生成完成
THEN 报告保存到 data/{platform}/reports/ 目录
AND 文件名格式为 report_{keyword}_{YYYYMMDD_HHmmss}.md
```

---

## MODIFIED Requirements

### Requirement: CrawlerTypeEnum 扩展

在现有 `search | detail | creator` 基础上新增 `report` 枚举值。

#### Scenario: CLI 帮助信息包含 report 类型

```
GIVEN 用户执行 `uv run main.py --help`
THEN --type 参数说明中包含 report 选项
```

### Requirement: 依赖管理

#### Scenario: 新增 faster-whisper 到项目依赖

```
GIVEN 项目 requirements.txt 和 pyproject.toml
WHEN 用户执行 uv sync
THEN faster-whisper 被正确安装
AND 可通过 python 导入 faster_whisper 模块
```
