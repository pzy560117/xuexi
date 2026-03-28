# Proposal: add-keyword-report

## 概要

新增「关键词内容报告」功能：用户提供一个关键词，系统自动在指定平台搜索相关视频/帖子，遍历每个结果，**提取视频文案**（标题+描述+视频内口播文案），并**爬取所有评论**，最终将全部数据整理为一份结构化的 Markdown 文档。

## 动机

当前项目已具备：
- ✅ 7 大平台的关键词搜索能力
- ✅ 内容详情爬取（含标题/描述文案）
- ✅ 一级和二级评论爬取
- ✅ 视频下载 URL 提取（`video_download_url` 字段）
- ✅ 8 种数据存储方式

**缺漏**：
1. 无法提取视频中的口播文案（语音转文字）
2. 无法一键生成「文案 + 评论」汇总文档，用户需手动拼接数据

## 目标

1. 新增 `report` 爬取模式（`--type report`）
2. 搜索关键词 → 遍历每个视频/帖子 → 提取完整文案（标题 + 描述 + **视频口播转文字**）
3. 爬取每个视频/帖子的全部评论
4. 自动生成结构化 Markdown 文档

## 核心技术选型（胶水编程）

采用成熟开源库组合，不重复造轮子：

| 能力 | 选用库 | Stars | 理由 |
|------|--------|-------|------|
| 视频语音转文字 | **faster-whisper** | 21.6k | 比 OpenAI Whisper 快 4x，内存占用更低，支持 GPU/CPU，中文效果好 |
| 视频→音频提取 | **ffmpeg** (subprocess) | - | 行业标准，项目 opencv-python 已隐式依赖 |
| 视频下载 | **httpx** (已有) | - | MediaCrawler 现有依赖，直接复用 |
| 报告生成 | 自研 `ReportGenerator` | - | 简单的 Markdown 模板拼接，无需第三方库 |

## 非目标

- 不修改现有 `search`/`detail`/`creator` 模式的行为
- 不新增平台支持
- 不支持实时流式转录

## 影响范围

| 模块 | 影响 |
|------|------|
| `cmd_arg/arg.py` | 新增 `report` 到 `CrawlerTypeEnum` |
| `config/base_config.py` | 新增报告+转录相关配置项 |
| `tools/video_transcriber.py` | **新文件** - 视频口播转文字适配器 |
| `tools/report_generator.py` | **新文件** - Markdown 文档生成器 |
| `media_platform/*/core.py` | 各平台新增 `generate_report()` 方法 |
| `main.py` | 处理 `report` 模式 |
| `requirements.txt` / `pyproject.toml` | 新增 `faster-whisper` 依赖 |

## 风险与约束

- **GPU 依赖**：faster-whisper 在 GPU 下性能最佳，CPU 模式也可运行但较慢
- **ffmpeg 依赖**：需要系统级安装 ffmpeg（或通过 ffmpeg-python 自动管理）
- **磁盘/网络**：视频下载会占用临时磁盘空间，处理完后自动清理
- **请求频率**：复用现有的间隔/并发控制，避免触发平台风控
- **大文件**：单个报告内容数量受 `CRAWLER_MAX_NOTES_COUNT` 限制
