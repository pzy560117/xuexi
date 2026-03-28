# 视频摘要与关键帧提取

## 核心项目

### 1. Video-Summarization-using-Keyframe-Extraction ⭐ 143

| 属性 | 值 |
|------|-----|
| **仓库** | [shruti-jadon/Video-Summarization-using-Keyframe-Extraction-and-Video-Skimming](https://github.com/shruti-jadon/Video-Summarization-using-Keyframe-Extraction-and-Video-Skimming) |
| **数据集** | SumMe |
| **技术** | 多种摘要算法对比实验 |

---

### 2. Keyframe-Extraction-for-video-summarization ⭐ 62

| 属性 | 值 |
|------|-----|
| **仓库** | [ttharden/Keyframe-Extraction-for-video-summarization](https://github.com/ttharden/Keyframe-Extraction-for-video-summarization) |
| **技术** | 基于视觉特征的关键帧提取 |

---

### 3. VideoContext-Engine ⭐ 27

| 属性 | 值 |
|------|-----|
| **仓库** | [dolphin-creator/VideoContext-Engine](https://github.com/dolphin-creator/VideoContext-Engine) |
| **定位** | 本地视频 RAG 引擎 |
| **技术** | 场景检测 + Whisper ASR + Qwen3-VL |
| **特点** | 支持 Apple Silicon (MLX) + Windows/Linux (Llama.cpp) |

---

### 4. Timecode-Generator ⭐ 12

| 属性 | 值 |
|------|-----|
| **仓库** | [NotTwist/Timecode-Generator](https://github.com/NotTwist/Timecode-Generator) |
| **功能** | YouTube 视频时间码/章节自动生成 |
| **技术** | 场景检测 + CLIPxGPT 字幕生成 |

---

## 更多项目

| 项目 | 说明 |
|------|------|
| [Video-Analyzer](https://github.com/WeezyF0/Video-Analyzer) | LLaVA + T5 + OpenCV → 视频摘要 |
| [Video-Summarizer](https://github.com/Prerak-Sanghvi/Video-Summarizer) | 场景分割 + Whisper + NLP → HTML 报告 |
| [VideoSceneSummarizer](https://github.com/farimahJl/VideoSceneSummarizer) | FFmpeg + OpenCV → 分析可视化 |
| [Visual-Attention-Transformer](https://github.com/AMjhagan/Video-summarization-using-keyframe-extraction-and-visual-attention-based-transformer-) | 视觉注意力 Transformer 关键帧提取 |
| [LSTM-NLP 关键帧](https://github.com/praveenkspk/A-DRIVEN-VIDEO-KEYFRAME-EXTRACTION-SYSTEM-USING-LSTM-AND-NLP) | LSTM 时序分析 + NLP 字幕内容分析 |

---

## 关键帧提取方法对比

| 方法 | 原理 | 适用场景 |
|------|------|----------|
| **均匀采样** | 等间距抽帧 | 简单快速 |
| **SSIM 差异** | 结构相似度阈值 | 通用场景 |
| **直方图差异** | 颜色分布变化 | 快速预处理 |
| **K-Means 聚类** | 视觉特征聚类选代表帧 | 多样性保证 |
| **VAE 特征** | 变分自编码器降维 | 语义级别 |
| **Transformer 注意力** | 自注意力权重选帧 | 最先进 |
| **CLIP 语义** | 语义嵌入覆盖度 | 内容理解最强 |
