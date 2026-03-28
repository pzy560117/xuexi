# 场景检测与视频分割

## 核心项目

### PySceneDetect ⭐ 4,631（行业标准）

| 属性 | 值 |
|------|-----|
| **仓库** | [Breakthrough/PySceneDetect](https://github.com/Breakthrough/PySceneDetect) |
| **语言** | Python |
| **依赖** | OpenCV |
| **创建时间** | 2014-06 |
| **维护状态** | 🟢 持续活跃 (2026年仍有更新) |

**核心功能**：
- 视频场景切换 / 转场检测
- 支持内容感知 (ContentDetector) 和阈值 (ThresholdDetector) 两种策略
- CLI + Python API 双入口
- 可导出场景列表、缩略图、元数据
- 与 FFmpeg 深度集成

**使用示例**：
```python
from scenedetect import SceneManager, open_video, ContentDetector

video = open_video("input.mp4")
scene_manager = SceneManager()
scene_manager.add_detector(ContentDetector(threshold=27.0))
scene_manager.detect_scenes(video)

scene_list = scene_manager.get_scene_list()
for i, scene in enumerate(scene_list):
    print(f"Scene {i+1}: {scene[0].get_timecode()} - {scene[1].get_timecode()}")
```

**在 AI 剪辑中的角色**: 几乎所有自动剪辑工具的第一步都是场景分割。

---

## 辅助项目

| 项目 | Stars | 说明 |
|------|-------|------|
| [python-scene-detection-tutorial](https://github.com/Breakthrough/python-scene-detection-tutorial) | 53⭐ | 官方教程：Python + OpenCV 场景检测 |
| [VideoContext-Engine](https://github.com/dolphin-creator/VideoContext-Engine) | 27⭐ | 本地视频 RAG：场景检测 + Whisper + Qwen-VL |
| [Timecode-Generator](https://github.com/NotTwist/Timecode-Generator) | 12⭐ | YouTube 章节自动生成 (场景检测 + CLIP) |
| [vhstools](https://github.com/MoeFwacky/vhstools) | 10⭐ | 自动场景分割 + 社交媒体发布 |
| [video-maker](https://github.com/nkovalcin/video-maker) | 1⭐ | 场景检测+运动分析+音频峰值 → 高光剪辑 |
| [smartscene-cutter](https://github.com/hovanlong443-beep/smartscene-cutter) | 1⭐ | 自动场景检测 + 高光选取 + 音频同步 |

---

## 场景检测技术对比

| 方法 | 原理 | 优点 | 缺点 |
|------|------|------|------|
| **阈值法** | 像素/直方图差异 | 速度快 | 对渐变转场不敏感 |
| **内容感知** | 图像特征差异 | 通用性好 | 需调参 |
| **深度学习** | CNN/Transformer | 精度最高 | 计算量大 |
| **CLIP 语义** | 语义嵌入距离 | 理解内容变化 | 开销大 |
