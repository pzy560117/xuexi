      
#!/usr/bin/env python3
"""
跨平台配置文件同步脚本
支持从GitLab拉取配置文件到本地
适配 Linux 和 Windows
"""

import os
import sys
import platform
import requests
import urllib3
from pathlib import Path
import json
from urllib.parse import quote

# 抑制跳过SSL验证时的警告
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ==================== 配置区域 ====================
GITLAB_URL = "https://gitlab.mindflow.com.cn"  # 修改为你的GitLab实例地址
PROJECT_ID = "25"  # 项目ID
GITLAB_TOKEN = "glpat-715OYKqh4csG_JXaCKTVjW86MQp1OmQH.01.0w02nysxy"  # 个人访问令牌
BRANCH = "main"  # 分支名称

# GitLab上的文件路径
FILES_TO_SYNC = [
    {
        "gitlab_path": "opencode/opencode.json",  
        "local_path": ".config/opencode/opencode.json"     # 本地相对路径
    },
    {
        "gitlab_path": "opencode/AGENTS.md",
        "local_path": ".config/opencode/AGENTS.md"
    },
    {
        "gitlab_path": "codex/config.toml",  
        "local_path": ".codex/config.toml"
    },
    {
        "gitlab_path": "codex/AGENTS.md",
        "local_path": ".codex/AGENTS.md"
    },
    {
        "gitlab_path": "claude/settings.json",
        "local_path": ".claude/settings.json"
    },
    {
        "gitlab_path": "claude/CLAUDE.md",
        "local_path": ".claude/CLAUDE.md"
    },
    {
        "gitlab_path": "docker/setup_docker_mirror.sh",
        "local_path": "/opt/devenv/setup_docker_mirror.sh",
        "skip_on": ["windows"]
    }
]
    
# ================================================


def get_home_directory():
    """获取用户主目录"""
    return Path.home()


def get_system_type():
    """识别操作系统类型"""
    system = platform.system()
    if system == "Windows":
        return "windows"
    elif system in ["Linux", "Darwin"]:
        return "linux"
    else:
        raise Exception(f"不支持的操作系统: {system}")


def get_local_path(relative_path):
    """根据系统类型获取完整的本地路径"""
    home = get_home_directory()
    system_type = get_system_type()
    
    if system_type == "windows":
        # Windows: C:\Users\{username}\.config\opencode.json
        return home / relative_path.replace("/", "\\")
    else:
        # Linux/Mac: /home/{username}/.config/opencode.json
        return home / relative_path


def load_config():
    """加载配置（支持从环境变量或配置文件读取）"""
    config = {
        "gitlab_url": GITLAB_URL,
        "project_id": PROJECT_ID,
        "token": GITLAB_TOKEN,
        "branch": BRANCH
    }
    
    # 优先从环境变量读取
    config["gitlab_url"] = os.getenv("GITLAB_URL", config["gitlab_url"])
    config["project_id"] = os.getenv("GITLAB_PROJECT_ID", config["project_id"])
    config["token"] = os.getenv("GITLAB_TOKEN", config["token"])
    config["branch"] = os.getenv("GITLAB_BRANCH", config["branch"])
    
    # 验证必需配置
    if not config["project_id"]:
        print("错误: 请设置 PROJECT_ID 或环境变量 GITLAB_PROJECT_ID")
        sys.exit(1)
    
    if not config["token"]:
        print("错误: 请设置 GITLAB_TOKEN 或环境变量 GITLAB_TOKEN")
        sys.exit(1)
    
    return config


def download_file_from_gitlab(gitlab_url, project_id, file_path, token, branch):
    """从GitLab下载文件内容"""
    # URL编码文件路径
    encoded_path = quote(file_path, safe='')
    
    # GitLab API endpoint
    url = f"{gitlab_url}/api/v4/projects/{quote(str(project_id), safe='')}/repository/files/{encoded_path}/raw"
    
    headers = {
        "PRIVATE-TOKEN": token
    }
    
    params = {
        "ref": branch
    }
    
    try:
        response = requests.get(url, headers=headers, params=params, timeout=30)
        response.raise_for_status()
        return response.content
    except requests.exceptions.SSLError:
        # SSL验证失败时（常见于Windows证书吊销检查失败），跳过SSL验证重试
        print(f"  SSL验证失败，跳过SSL验证重试...")
        response = requests.get(url, headers=headers, params=params, timeout=30, verify=False)
        response.raise_for_status()
        return response.content
    except requests.exceptions.RequestException as e:
        raise Exception(f"下载文件失败: {file_path}\n错误: {str(e)}")


def save_file(content, local_path):
    """保存文件到本地"""
    # 确保目录存在
    local_path.parent.mkdir(parents=True, exist_ok=True)
    
    # 写入文件
    with open(local_path, 'wb') as f:
        f.write(content)
    
    print(f"✓ 已保存: {local_path}")


def sync_files():
    """同步所有配置文件"""
    print(f"系统类型: {get_system_type()}")
    print(f"用户主目录: {get_home_directory()}")
    print("-" * 50)
    
    config = load_config()
    
    success_count = 0
    fail_count = 0
    
    system_type = get_system_type()

    for file_info in FILES_TO_SYNC:
        # 检查是否需要跳过当前平台
        skip_on = file_info.get("skip_on", [])
        if system_type in skip_on:
            print(f"⊘ 跳过(不适用于{system_type}): {file_info['gitlab_path']}")
            continue

        gitlab_path = file_info["gitlab_path"]
        local_relative_path = file_info["local_path"]
        local_path = get_local_path(local_relative_path)
        
        try:
            print(f"正在下载: {gitlab_path}")
            content = download_file_from_gitlab(
                config["gitlab_url"],
                config["project_id"],
                gitlab_path,
                config["token"],
                config["branch"]
            )
            
            save_file(content, local_path)
            success_count += 1
            
        except Exception as e:
            print(f"✗ 失败: {gitlab_path}")
            print(f"  {str(e)}")
            fail_count += 1
    
    print("-" * 50)
    print(f"同步完成: 成功 {success_count} 个, 失败 {fail_count} 个")
    
    if fail_count > 0:
        sys.exit(1)


def main():
    """主函数"""
    print("=" * 50)
    print("配置文件同步工具")
    print("=" * 50)
    
    try:
        sync_files()
        print("\n同步成功完成！")
    except KeyboardInterrupt:
        print("\n\n操作已取消")
        input("\n按回车键退出...") if os.name == 'nt' else None
        sys.exit(1)
    except Exception as e:
        print(f"\n错误: {str(e)}")
        input("\n按回车键退出...") if os.name == 'nt' else None
        sys.exit(1)


if __name__ == "__main__":
    main()

    