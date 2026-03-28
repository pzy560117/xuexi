# AI 视频剪辑生态研究

> 研究时间：2026-03-20 | 数据来源：GitHub 全站搜索

## 目录结构

```
ai-video-editing-research/
├── README.md                        # 本文件 - 总览
├── 01-openclip-ecosystem.md         # OpenCLIP 核心生态分析
├── 02-auto-editing-tools.md         # AI 自动剪辑工具大全
├── 03-scene-detection.md            # 场景检测与视频分割
├── 04-text-to-video.md              # 文本生成视频（扩散模型）
├── 05-video-search-retrieval.md     # 语义视频检索
├── 06-subtitle-caption.md           # 自动字幕与语音转录
├── 07-video-summarization.md        # 视频摘要与关键帧提取
└── 08-tech-stack-guide.md           # 技术栈选型指南
```

## 搜索覆盖维度

| 维度 | 关键词 | 发现项目数 |
|------|--------|-----------|
| OpenCLIP 生态 | open_clip, CLIP, contrastive learning | 5+ |
| 自动剪辑工具 | AI video editing, auto clip, viral cutter | 15+ |
| 场景检测 | scene detection, PySceneDetect, shot transition | 10+ |
| 文本生成视频 | text-to-video, diffusion model, video generation | 15+ |
| 语义检索 | CLIP video search, semantic retrieval, FAISS | 7+ |
| 字幕生成 | whisper subtitle, auto caption, ASR | 5+ |
| 视频摘要 | video summarization, keyframe extraction | 10+ |

## 核心发现

- **基础模型层**: OpenCLIP (10K⭐), mmagic (7.4K⭐) 是基石
- **工具层**: PySceneDetect (4.6K⭐) 是场景检测标准库
- **应用层**: ViralCutter (240⭐) 是最成熟的开源 AI 剪辑工具
- **前沿研究**: Tune-A-Video (4.3K⭐), Show-1 (1.1K⭐) 代表视频生成前沿
