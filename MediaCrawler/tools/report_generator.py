# -*- coding: utf-8 -*-
# Copyright (c) 2025 relakkes@gmail.com
#
# This file is part of MediaCrawler project.
# Licensed under NON-COMMERCIAL LEARNING LICENSE 1.1

"""
关键词内容报告生成器模块

功能：将搜索到的视频/帖子的文案和评论整理为结构化 Markdown 文档。
用于 --type report 模式下的文档输出。
"""

import os
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional

import config
from tools import utils


@dataclass
class ReportContentItem:
    """
    报告中的单个内容条目（一个视频/帖子）

    Attributes:
        content_id: 内容唯一标识
        title: 标题
        desc: 文案/描述
        url: 原始链接
        nickname: 作者昵称
        liked_count: 点赞数
        comment_count: 评论数
        share_count: 分享数
        create_time: 发布时间
        extra_metadata: 额外元数据
        transcript: 视频口播转录文案（来自字幕 API 或 Whisper）
        comments: 该内容下的评论列表
    """
    content_id: str
    title: str
    desc: str
    url: str = ""
    nickname: str = ""
    liked_count: str = "0"
    comment_count: str = "0"
    share_count: str = "0"
    create_time: str = ""
    transcript: str = ""
    extra_metadata: Dict = field(default_factory=dict)
    comments: List[Dict] = field(default_factory=list)


class ReportGenerator:
    """
    关键词内容报告生成器

    将搜索到的内容（文案）和评论整理为一份结构化 Markdown 文档。

    Args:
        keyword: 搜索关键词
        platform: 平台代号（如 xhs, dy, bili）
    """

    def __init__(self, keyword: str, platform: str):
        self.keyword = keyword
        self.platform = platform
        self.contents: List[ReportContentItem] = []
        self.start_time = datetime.now()

    def add_content(
        self,
        content_id: str,
        title: str,
        desc: str,
        url: str = "",
        nickname: str = "",
        liked_count: str = "0",
        comment_count: str = "0",
        share_count: str = "0",
        create_time: str = "",
        transcript: str = "",
        extra_metadata: Optional[Dict] = None,
    ) -> None:
        """
        添加一个视频/帖子的文案信息

        Args:
            content_id: 内容唯一标识
            title: 标题
            desc: 文案/描述正文
            url: 原始链接
            nickname: 作者昵称
            liked_count: 点赞数
            comment_count: 评论数
            share_count: 分享数
            create_time: 发布时间（字符串）
            transcript: 视频口播转录文案
            extra_metadata: 额外元数据字典
        """
        item = ReportContentItem(
            content_id=content_id,
            title=title,
            desc=desc,
            url=url,
            nickname=nickname,
            liked_count=str(liked_count),
            comment_count=str(comment_count),
            share_count=str(share_count),
            create_time=str(create_time),
            transcript=transcript,
            extra_metadata=extra_metadata or {},
        )
        self.contents.append(item)
        utils.logger.info(
            f"[ReportGenerator.add_content] Added content: {content_id}, title: {title[:50]}"
        )

    def add_comments(self, content_id: str, comments: List[Dict]) -> None:
        """
        添加一个视频/帖子的评论列表

        Args:
            content_id: 内容唯一标识，必须与之前 add_content 的 content_id 匹配
            comments: 评论字典列表，每项应包含 nickname, content, like_count 等字段
        """
        target_item = self._find_content_by_id(content_id)
        if target_item is None:
            utils.logger.warning(
                f"[ReportGenerator.add_comments] Content {content_id} not found, skipping comments"
            )
            return

        # 控制单帖最大评论数（0=不限制）
        max_comments = config.REPORT_MAX_COMMENTS_PER_NOTE
        limited_comments = comments[:max_comments] if max_comments > 0 else comments
        target_item.comments.extend(limited_comments)
        utils.logger.info(
            f"[ReportGenerator.add_comments] Added {len(limited_comments)} comments to content {content_id}"
        )

    async def generate(self, output_dir: str = "") -> str:
        """
        生成 Markdown 报告文件

        Args:
            output_dir: 输出目录，为空则使用默认路径 data/{platform}/reports/

        Returns:
            生成的报告文件绝对路径
        """
        # 确定输出目录
        final_output_dir = self._resolve_output_dir(output_dir)
        os.makedirs(final_output_dir, exist_ok=True)

        # 生成文件名
        safe_keyword = self.keyword.replace(",", "_").replace(" ", "_")[:50]
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"report_{safe_keyword}_{timestamp}.md"
        filepath = os.path.join(final_output_dir, filename)

        # 构建报告内容
        report_content = self._build_report()

        # 写入文件
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(report_content)

        utils.logger.info(
            f"[ReportGenerator.generate] Report generated: {filepath}"
        )
        return filepath

    def _find_content_by_id(self, content_id: str) -> Optional[ReportContentItem]:
        """
        根据 content_id 查找内容条目

        Args:
            content_id: 内容唯一标识

        Returns:
            匹配的 ReportContentItem 或 None
        """
        for item in self.contents:
            if item.content_id == content_id:
                return item
        return None

    def _resolve_output_dir(self, output_dir: str) -> str:
        """
        解析输出目录

        Args:
            output_dir: 用户指定的输出目录

        Returns:
            最终的输出目录路径
        """
        if output_dir:
            return output_dir
        if config.REPORT_OUTPUT_DIR:
            return config.REPORT_OUTPUT_DIR

        # 默认路径
        base_path = config.SAVE_DATA_PATH or "data"
        return os.path.join(base_path, self.platform, "reports")

    def _build_report(self) -> str:
        """
        构建完整的 Markdown 报告内容

        Returns:
            Markdown 格式的报告字符串
        """
        total_comments = sum(len(item.comments) for item in self.contents)
        duration = datetime.now() - self.start_time
        duration_str = f"{duration.total_seconds():.1f} 秒"

        platform_names = {
            "xhs": "小红书",
            "dy": "抖音",
            "ks": "快手",
            "bili": "B站",
            "wb": "微博",
            "tieba": "百度贴吧",
            "zhihu": "知乎",
        }
        platform_display = platform_names.get(self.platform, self.platform)

        sections: List[str] = []

        # 标题和元信息
        sections.append(f"# 关键词内容报告：「{self.keyword}」\n")
        sections.append(
            f"> 平台：{platform_display} | "
            f"时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | "
            f"共 {len(self.contents)} 条内容 | "
            f"共 {total_comments} 条评论\n"
        )
        sections.append("---\n")

        # 各内容条目
        if not self.contents:
            sections.append("*未搜索到相关内容*\n")
        else:
            for idx, item in enumerate(self.contents, 1):
                sections.append(self._build_content_section(idx, item))

        # 统计摘要
        sections.append(self._build_summary_section(total_comments, duration_str))

        return "\n".join(sections)

    def _build_content_section(self, index: int, item: ReportContentItem) -> str:
        """
        构建单个内容条目的 Markdown 段落

        Args:
            index: 序号（从 1 开始）
            item: 内容条目

        Returns:
            该条目的 Markdown 字符串
        """
        lines: List[str] = []
        display_title = item.title.strip() if item.title.strip() else "(无标题)"
        lines.append(f"## {index}. {display_title}\n")

        # 元信息
        if item.nickname:
            lines.append(f"- **作者**：{item.nickname}")
        lines.append(
            f"- **点赞**：{item.liked_count} | **评论**：{item.comment_count} | **分享**：{item.share_count}"
        )
        if item.create_time:
            lines.append(f"- **发布时间**：{item.create_time}")
        if item.url:
            lines.append(f"- **链接**：{item.url}")
        lines.append("")

        # 文案
        lines.append("### 文案\n")
        desc_text = item.desc.strip() if item.desc.strip() else "(无文案内容)"
        lines.append(f"{desc_text}\n")

        # 视频口播文案（仅在有内容时显示）
        if item.transcript and item.transcript.strip():
            lines.append("### 视频口播文案\n")
            lines.append(f"{item.transcript.strip()}\n")

        # 评论
        lines.append(f"### 评论 ({len(item.comments)} 条)\n")
        if not item.comments:
            lines.append("*暂无评论数据*\n")
        else:
            lines.append(self._build_comments_table(item.comments))

        lines.append("---\n")
        return "\n".join(lines)

    def _build_comments_table(self, comments: List[Dict]) -> str:
        """
        构建评论的 Markdown 表格

        Args:
            comments: 评论字典列表

        Returns:
            Markdown 表格字符串
        """
        include_avatar = config.REPORT_INCLUDE_AVATAR

        # 表头
        if include_avatar:
            header = "| # | 用户 | 头像 | 内容 | 点赞 | 时间 |"
            separator = "|---|------|------|------|------|------|"
        else:
            header = "| # | 用户 | 内容 | 点赞 | 时间 |"
            separator = "|---|------|------|------|------|"

        rows = [header, separator]

        for idx, comment in enumerate(comments, 1):
            nickname = self._escape_md(
                str(comment.get("nickname", comment.get("user_nickname", "")))
            )
            content = self._escape_md(
                str(comment.get("content", comment.get("text", "")))
            )
            # 截断过长的评论内容
            if len(content) > 100:
                content = content[:100] + "..."
            like_count = comment.get("like_count", comment.get("digg_count", 0))
            create_time = comment.get("create_time", comment.get("publish_time", ""))

            # 尝试将时间戳转为可读格式
            if isinstance(create_time, (int, float)) and create_time > 0:
                try:
                    create_time = datetime.fromtimestamp(create_time).strftime(
                        "%Y-%m-%d %H:%M"
                    )
                except (OSError, ValueError):
                    create_time = str(create_time)

            if include_avatar:
                avatar = comment.get("avatar", comment.get("user_avatar", ""))
                rows.append(
                    f"| {idx} | {nickname} | {avatar} | {content} | {like_count} | {create_time} |"
                )
            else:
                rows.append(
                    f"| {idx} | {nickname} | {content} | {like_count} | {create_time} |"
                )

        rows.append("")
        return "\n".join(rows)

    def _build_summary_section(self, total_comments: int, duration_str: str) -> str:
        """
        构建统计摘要部分

        Args:
            total_comments: 总评论数
            duration_str: 耗时字符串

        Returns:
            Markdown 摘要段落
        """
        avg_comments = (
            f"{total_comments / len(self.contents):.1f}"
            if self.contents
            else "0"
        )

        platform_names = {
            "xhs": "小红书",
            "dy": "抖音",
            "ks": "快手",
            "bili": "B站",
            "wb": "微博",
            "tieba": "百度贴吧",
            "zhihu": "知乎",
        }

        lines = [
            "## 数据统计摘要\n",
            "| 指标 | 数值 |",
            "|------|------|",
            f"| 搜索关键词 | {self.keyword} |",
            f"| 目标平台 | {platform_names.get(self.platform, self.platform)} |",
            f"| 内容总数 | {len(self.contents)} |",
            f"| 评论总数 | {total_comments} |",
            f"| 平均评论数 | {avg_comments} |",
            f"| 爬取耗时 | {duration_str} |",
            "",
        ]
        return "\n".join(lines)

    @staticmethod
    def _escape_md(text: str) -> str:
        """
        转义 Markdown 表格中的特殊字符

        Args:
            text: 原始文本

        Returns:
            转义后的文本
        """
        # 替换管道符和换行符以避免破坏表格
        return text.replace("|", "\\|").replace("\n", " ").replace("\r", "")
