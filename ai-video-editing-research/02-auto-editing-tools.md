# AI 自动剪辑工具大全

## 第一梯队：功能完整的自动剪辑工具

### 1. ViralCutter ⭐ 240（推荐）

| 属性 | 值 |
|------|-----|
| **仓库** | [RafaelGodoyEbert/ViralCutter](https://github.com/RafaelGodoyEbert/ViralCutter) |
| **语言** | Python |
| **功能** | YouTube → TikTok/IG 短视频自动生成 |
| **Tags** | ai, clips, clipper, opus-clip-free, reels, shorts, tiktok |

**核心流水线**：
```
YouTube URL → 下载 → AI 转录 → 高光片段识别 → 9:16 裁剪 → 字幕叠加 → 输出
```

> **评价**: 目前开源中最接近 Opus Clip 的免费替代品。

---

### 2. AI-Automated-Short-Video-Generator ⭐ 11

| 属性 | 值 |
|------|-----|
| **仓库** | [YoussefBechara/AI-Automated-Short-Video-Generator-Editor-Uploader-For-Views](https://github.com/YoussefBechara/AI-Automated-Short-Video-Generator-Editor-Uploader-For-Views) |
| **语言** | Python |
| **流水线** | 脚本生成 → TTS → 字幕 → 视觉素材 → 发布 |
| **平台** | TikTok, Instagram Reels, YouTube Shorts |

**核心流水线**：
```
AI 生成创意 → 脚本撰写 → TTS 配音 → 字幕生成 → 素材匹配 → 自动上传
```

---

### 3. VideoAutoClip ⭐ 3

| 属性 | 值 |
|------|-----|
| **仓库** | [azoyang/VideoAutoClip](https://github.com/azoyang/VideoAutoClip) |
| **语言** | Python |
| **定位** | 短剧推广视频自动生成 |
| **技术栈** | ASR + LLM 内容分析 + 自动剪辑 |

**核心流水线**：
```
云存储视频 → ASR 语音识别 → LLM 内容分析 → 高光提取 → 推广视频生成
```

---

## 第二梯队：专项功能工具

### 4. BeatSync-Engine ⭐ 7 — 音乐节拍同步

| 属性 | 值 |
|------|-----|
| **仓库** | [Merserk/BeatSync-Engine](https://github.com/Merserk/BeatSync-Engine) |
| **特色** | 自动将视频片段与音乐节拍对齐 |
| **技术** | 音频分析 + CUDA 加速 + Gradio UI |

**适用场景**: 音乐视频 (MV)、Vlog 卡点视频。

---

### 5. AI-Speed-Ramping ⭐ 7 — 智能变速

| 属性 | 值 |
|------|-----|
| **仓库** | [ibrahimjspy/AI-Speed-Ramping](https://github.com/ibrahimjspy/AI-Speed-Ramping) |
| **特色** | AI 光流分析 + 自动变速过渡 |
| **技术** | OpenCV 光流 + FFmpeg + Flask |

**适用场景**: 运动视频、Cinematic 风格变速。

---

### 6. Turn_Movie_Clips_to_Narration_Videos ⭐ 3 — 影视解说

| 属性 | 值 |
|------|-----|
| **仓库** | [JollyToday/Turn_Movie_Clips_to_Narration_Videos](https://github.com/JollyToday/Turn_Movie_Clips_to_Narration_Videos) |
| **特色** | 影视片段 → 解说视频自动生成 |
| **流水线** | 对白提取 → 角色识别 → 解说生成 → 背景音分离 → 音视频对齐 |

**效率提升**: 1 小时编辑 → 3 分钟 (提速 95%)。

---

### 7. ClipFlow-AI ⭐ 1 — 浏览器 AI 编辑

| 属性 | 值 |
|------|-----|
| **仓库** | [Sudhir-web20/ClipFlow-AI](https://github.com/Sudhir-web20/ClipFlow-AI---Smart-Video-Snippet-Editor) |
| **语言** | TypeScript |
| **特色** | 浏览器端运行，使用 Gemini 3.0 Pro |
| **功能** | 自动识别病毒钩子 + 高光片段提取 |

---

### 8. autotube ⭐ 8 — YouTube 全自动化

| 属性 | 值 |
|------|-----|
| **仓库** | [RorriMaesu/autotube](https://github.com/RorriMaesu/autotube) |
| **语言** | Python |
| **流水线** | 输入话题 → ChatGPT 写脚本 → Ideogram.ai 生图 → 动画化 → Movavi 合成 |

---

## 第三梯队：早期/实验性项目

| 项目 | Stars | 说明 |
|------|-------|------|
| [Cursor-For-TikTok](https://github.com/ArvinAIEngineer/Cursor-For-Tiktok-Videos--Open-Source) | 1⭐ | Gemini AI + Whisper，TikTok 病毒内容提取 |
| [auto-video-editor (kiy0ni)](https://github.com/kiy0ni/auto-video-editor) | 2⭐ | Tkinter GUI + Whisper + FFmpeg 高光生成 |
| [python-auto-video-editor](https://github.com/youssof20/python-auto-video-editor) | 0⭐ | 自动去除静音段 + 填充词 |
| [AI-in-film-editing](https://github.com/HerimathNandita/AI-in-film-editing) | 0⭐ | 基于脚本的影视自动剪辑 |
| [video-maker](https://github.com/nkovalcin/video-maker) | 1⭐ | 场景检测+运动分析+音频峰值高光 |
| [smartscene-cutter](https://github.com/hovanlong443-beep/smartscene-cutter) | 1⭐ | 场景检测→高光选取→音频同步 |
| [short-generator](https://github.com/udithsandaruwan2/short-generator) | 3⭐ | Pexels素材+Whisper+gTTS+MoviePy |

---

## 项目对比矩阵

| 项目 | 端到端 | 字幕 | 高光检测 | 自动发布 | GUI | 中文友好 |
|------|--------|------|----------|----------|-----|----------|
| ViralCutter | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AI-Short-Video | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| VideoAutoClip | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| BeatSync-Engine | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| AI-Speed-Ramping | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| ClipFlow-AI | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
