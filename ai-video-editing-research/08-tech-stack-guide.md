# AI 剪辑技术栈选型指南

## 一、完整技术栈图谱

```
┌─────────────────────────────────────────────────────────────────┐
│                        应用层                                    │
│  ViralCutter │ VideoAutoClip │ BeatSync │ AI-Short-Video        │
├─────────────────────────────────────────────────────────────────┤
│                        决策层                                    │
│  LLM (GPT/Gemini/Qwen) — 高光判断 + 脚本生成 + 内容分析          │
├─────────────────────────────────────────────────────────────────┤
│                        理解层                                    │
│  OpenCLIP (语义) │ Whisper (ASR) │ PySceneDetect (场景)         │
├─────────────────────────────────────────────────────────────────┤
│                        处理层                                    │
│  FFmpeg (核心) │ MoviePy (Python封装) │ OpenCV (图像处理)         │
├─────────────────────────────────────────────────────────────────┤
│                        存储/检索层                                │
│  FAISS (向量) │ LanceDB (嵌入式) │ SQLite (元数据)               │
├─────────────────────────────────────────────────────────────────┤
│                        输出/发布层                                │
│  gTTS/Edge-TTS (配音) │ PIL/Pillow (缩略图) │ API (自动发布)      │
└─────────────────────────────────────────────────────────────────┘
```

## 二、最小可行产品 (MVP) 技术栈

构建一个 AI 自动剪辑工具的最小技术栈：

```python
# requirements.txt
open-clip-torch>=2.24.0   # 语义理解
faster-whisper>=1.0.0     # 语音转录 (比官方快4x)
scenedetect>=0.6.4        # 场景检测
ffmpeg-python>=0.2.0      # 视频处理
moviepy>=1.0.3            # Python 视频编辑
openai>=1.0.0             # LLM API (高光判断)
```

## 三、按场景推荐

### 场景 1：短视频自动切片（类 Opus Clip）

| 环节 | 推荐方案 | 替代方案 |
|------|----------|----------|
| 语音转录 | faster-whisper | whisperx (带说话人分离) |
| 高光识别 | GPT-4o / Gemini | 本地 Qwen |
| 场景分割 | PySceneDetect | OpenCV 自实现 |
| 视频处理 | FFmpeg | MoviePy |
| 字幕渲染 | FFmpeg drawtext | Pillow + MoviePy |

### 场景 2：语义视频搜索引擎

| 环节 | 推荐方案 | 替代方案 |
|------|----------|----------|
| 帧编码 | OpenCLIP ViT-L-14 | UForm |
| 向量存储 | FAISS | LanceDB / Milvus |
| 查询接口 | FastAPI + Gradio | Streamlit |

### 场景 3：影视解说自动化

| 环节 | 推荐方案 | 替代方案 |
|------|----------|----------|
| 对白提取 | faster-whisper | whisper.cpp |
| 角色识别 | 说话人分离 (pyannote) | 手动标注 |
| 解说生成 | GPT-4o | Claude |
| 配音 | Edge-TTS | gTTS |
| 合成 | FFmpeg | MoviePy |

### 场景 4：音乐节拍视频

| 环节 | 推荐方案 |
|------|----------|
| 节拍检测 | librosa |
| 视频分割 | PySceneDetect |
| 节拍同步 | FFmpeg 精确切割 |

## 四、关键依赖版本锁定

```toml
[project]
dependencies = [
    "open-clip-torch>=2.24.0,<3.0",
    "faster-whisper>=1.0.0,<2.0",
    "scenedetect[opencv]>=0.6.4",
    "ffmpeg-python>=0.2.0",
    "moviepy>=1.0.3,<2.0",
    "faiss-cpu>=1.7.4",      # GPU: faiss-gpu
    "torch>=2.0",
    "numpy>=1.24,<2.0",
    "Pillow>=10.0",
]

[project.optional-dependencies]
llm = ["openai>=1.0", "anthropic>=0.25"]
tts = ["edge-tts>=6.1", "gTTS>=2.3"]
gpu = ["faiss-gpu>=1.7.4"]
```

## 五、硬件需求

| 场景 | CPU | GPU | RAM | 存储 |
|------|-----|-----|-----|------|
| 开发/测试 | 8核+ | 不需要 | 16GB | 50GB |
| 实时处理 | 8核+ | RTX 3060+ | 16GB | 100GB |
| 批量生产 | 16核+ | RTX 4090+ | 32GB | 500GB |
| 训练模型 | 32核+ | A100 40GB+ | 64GB | 1TB+ |

## 六、值得深入研究的项目优先级

| 优先级 | 项目 | 理由 |
|--------|------|------|
| 🔴 P0 | [mlfoundations/open_clip](https://github.com/mlfoundations/open_clip) | CLIP 基础设施 |
| 🔴 P0 | [Breakthrough/PySceneDetect](https://github.com/Breakthrough/PySceneDetect) | 场景检测标准库 |
| 🔴 P0 | [ViralCutter](https://github.com/RafaelGodoyEbert/ViralCutter) | 最完整的端到端参考 |
| 🟡 P1 | [VideoContext-Engine](https://github.com/dolphin-creator/VideoContext-Engine) | 本地视频 RAG |
| 🟡 P1 | [open-mmlab/mmagic](https://github.com/open-mmlab/mmagic) | AIGC 工具箱 |
| 🟡 P1 | [UForm](https://github.com/unum-cloud/UForm) | 轻量 CLIP 替代 |
| 🟢 P2 | [Tune-A-Video](https://github.com/showlab/Tune-A-Video) | 视频生成前沿 |
| 🟢 P2 | [Timecode-Generator](https://github.com/NotTwist/Timecode-Generator) | CLIP+GPT 时间码 |
| 🟢 P2 | [whisper_autosrt](https://github.com/botbahlul/whisper_autosrt) | 字幕自动化 |
