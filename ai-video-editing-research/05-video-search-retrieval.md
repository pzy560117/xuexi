# 语义视频检索

## 概述

利用 CLIP 等多模态模型实现"自然语言 → 视频片段"的语义搜索，是 AI 剪辑的核心赋能技术。

## 项目列表

### 1. Semantic-Video-Retrieval-System ⭐ 1

| 属性 | 值 |
|------|-----|
| **仓库** | [jayanthkonanki/Semantic-Video-Retrieval-System](https://github.com/jayanthkonanki/Semantic-Video-Retrieval-System) |
| **技术** | CLIP + FAISS（多模态向量搜索） |
| **功能** | 帧级视频分析 → 自然语言查询 → 精确定位 |

---

### 2. semantic-search ⭐ 1

| 属性 | 值 |
|------|-----|
| **仓库** | [tamchamchi/semantic-search](https://github.com/tamchamchi/semantic-search) |
| **技术** | CLIP 嵌入 + FAISS |
| **特点** | 支持图像/文本双查询方式 |

---

### 3. video-moment-retrieval-system

| 属性 | 值 |
|------|-----|
| **仓库** | [linalek/video-moment-retrieval-system](https://github.com/linalek/video-moment-retrieval-system) |
| **技术** | CLIP + LLaVA + OpenSearch |
| **特点** | 多模态搜索 + RAG 视频问答 |
| **Topics** | clip, llava, opensearch, transformers, video-retrieval, vqa |

---

### 4. CLIP-MultiSearch

| 属性 | 值 |
|------|-----|
| **仓库** | [KJHkong/CLIP-MultiSearch](https://github.com/KJHkong/CLIP-MultiSearch) |
| **技术** | OpenAI CLIP + FAISS + Gradio |
| **功能** | 文本→图像、图像→图像、视频帧检索 + 查询扩展 |

---

### 5. Multimodel_Search

| 属性 | 值 |
|------|-----|
| **仓库** | [Meghanna-N/Multimodel_Search](https://github.com/Meghanna-N/Multimodel_Search) |
| **技术** | CLIP + LanceDB |
| **功能** | 文本 → 图像/视频/音频跨模态搜索 |

---

### 6. rag-teaching-assistant

| 属性 | 值 |
|------|-----|
| **仓库** | [002meet/rag-teaching-assistant](https://github.com/002meet/rag-teaching-assistant) |
| **技术** | BGE-M3 + Ollama/GPT-4o-mini |
| **功能** | 视频讲座语义搜索 + 带时间戳的问答 |

---

## 技术架构

```
视频输入
  ↓
帧采样 (1-5 fps)
  ↓
CLIP 编码 → 帧嵌入向量
  ↓
存入向量数据库 (FAISS / LanceDB / OpenSearch)
  ↓
用户自然语言查询
  ↓
CLIP 文本编码 → 查询向量
  ↓
向量相似度搜索
  ↓
返回匹配帧/片段 + 时间戳
```

## 向量数据库选型

| 数据库 | 特点 | 适用场景 |
|--------|------|----------|
| **FAISS** | Facebook 出品，纯内存，速度极快 | 中小规模离线检索 |
| **LanceDB** | 嵌入式，无需服务器 | 轻量级应用 |
| **OpenSearch** | 分布式，功能全 | 大规模生产系统 |
| **Milvus** | 专业向量数据库 | 企业级部署 |
