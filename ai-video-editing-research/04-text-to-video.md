# 文本生成视频（扩散模型）

## 核心项目

### mmagic (OpenMMLab) ⭐ 7,407

| 属性 | 值 |
|------|-----|
| **仓库** | [open-mmlab/mmagic](https://github.com/open-mmlab/mmagic) |
| **定位** | 多模态 AIGC 工具箱 |
| **能力** | 图像生成、视频超分、帧插值、修复、文本生成图像 |
| **Topics** | aigc, diffusion, video-super-resolution, video-interpolation |

---

### Tune-A-Video ⭐ 4,380

| 属性 | 值 |
|------|-----|
| **仓库** | [showlab/Tune-A-Video](https://github.com/showlab/Tune-A-Video) |
| **会议** | ICCV 2023 |
| **突破** | 仅用一个视频即可微调图像扩散模型生成新视频 |

---

### Show-1 ⭐ 1,150

| 属性 | 值 |
|------|-----|
| **仓库** | [showlab/Show-1](https://github.com/showlab/Show-1) |
| **期刊** | IJCV |
| **突破** | 融合像素级和潜空间扩散模型实现高质量文本生成视频 |

---

## 完整项目列表

| 项目 | Stars | 会议/期刊 | 核心贡献 |
|------|-------|-----------|----------|
| [mmagic](https://github.com/open-mmlab/mmagic) | 7,407⭐ | — | AIGC 工具箱（生成/超分/插帧） |
| [Tune-A-Video](https://github.com/showlab/Tune-A-Video) | 4,380⭐ | ICCV 2023 | 单视频微调→文本生成视频 |
| [Show-1](https://github.com/showlab/Show-1) | 1,150⭐ | IJCV | 像素+潜空间双扩散 |
| [control-a-video](https://github.com/Weifeng-Chen/control-a-video) | 405⭐ | — | 可控文本生成视频 |
| [VideoElevator](https://github.com/YBYBZhang/VideoElevator) | 162⭐ | AAAI 2025 | 文本→图像模型提升视频质量 |
| [TI2V-Zero](https://github.com/merlresearch/TI2V-Zero) | 55⭐ | MERL | 文本条件图像→视频生成 |
| [LUMIERE](https://github.com/kyegomez/LUMIERE) | 52⭐ | Google | 时空扩散模型 |
| [catlvdm](https://github.com/chikap421/catlvdm) | 10⭐ | ICLR 2026 | 鲁棒文本→视频生成 |
| [awesome-video-diffusions](https://github.com/longxiang-ai/awesome-video-diffusions) | 5⭐ | — | 视频扩散论文集（自动更新） |

---

## Awesome Lists

| 仓库 | 说明 |
|------|------|
| [awesome-video-generation](https://github.com/backblaze-b2-samples/awesome-video-generation) | AI 视频生成 API/SDK/工具列表 |
| [awesome-video-diffusions](https://github.com/longxiang-ai/awesome-video-diffusions) | arXiv 视频扩散论文合集（16+ 分类） |

---

## 与 AI 剪辑的关系

文本生成视频技术是 AI 剪辑的**素材生成**环节：
- **B-Roll 生成**: 根据脚本自动生成配合画面
- **转场生成**: AI 生成过渡片段
- **补帧/超分**: 提升低质量素材
- **风格迁移**: 统一视频视觉风格
