# 自动字幕与语音转录

## 核心技术：OpenAI Whisper

几乎所有 AI 剪辑项目都依赖 Whisper 实现 ASR（自动语音识别）。

## 项目列表

### 1. whisper_autosrt ⭐ 29

| 属性 | 值 |
|------|-----|
| **仓库** | [botbahlul/whisper_autosrt](https://github.com/botbahlul/whisper_autosrt) |
| **技术** | faster_whisper + Google Translate |
| **功能** | 视频/音频 → SRT 字幕 + 自动翻译 |
| **特点** | CLI 工具，支持多语言 |

---

### 2. Auto_Subtitle_generation_using_AI ⭐ 2

| 属性 | 值 |
|------|-----|
| **仓库** | [mtnvdsk/Auto_Subtitle_generation_using_AI](https://github.com/mtnvdsk/Auto_Subtitle_generation_using_AI) |
| **技术** | Whisper ASR + 字幕覆盖 |
| **功能** | 文本分割 + 字幕样式定制 + 视频叠加 |

---

### 3. AutoCaption-Pro

| 属性 | 值 |
|------|-----|
| **仓库** | [mosesdev777/AutoCaption-Pro](https://github.com/mosesdev777/AutoCaption-Pro) |
| **技术** | moviepy + stable-whisper |
| **功能** | 提取音频 → 转录 → Reels 风格 SRT 字幕 |

---

### 4. WhisperSRTube

| 属性 | 值 |
|------|-----|
| **仓库** | [AliceYangAC/WhisperSRTube](https://github.com/AliceYangAC/WhisperSRTube) |
| **功能** | YouTube 视频下载 → Whisper 转录 → 自动翻译 → 字幕嵌入 |

---

## Whisper 变体对比

| 库 | 速度 | 精度 | 特点 |
|----|------|------|------|
| **openai-whisper** | 基准 | ★★★★★ | 官方实现 |
| **faster-whisper** | 4x 更快 | ★★★★★ | CTranslate2 加速 |
| **stable-whisper** | 中等 | ★★★★★ | 更精确的时间戳 |
| **whisperx** | 3x 更快 | ★★★★★ | 说话人分离 |
| **whisper.cpp** | 10x+ 更快 | ★★★★ | C++ 实现，支持 CPU |

## 在 AI 剪辑中的角色

字幕/转录是 AI 剪辑流水线中的**必要环节**：
1. **内容理解** — LLM 分析转录文本，找出高光片段
2. **字幕叠加** — 短视频标配功能
3. **说话人标注** — 多人对话场景的关键
4. **翻译** — 多语言内容生产
