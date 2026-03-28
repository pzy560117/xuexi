由于近期opencode在处理Claude模型的返回内容时出现诸多错误，这可能导致模型无法正常工作，特为此引入Claude CLI，以解决因模型类型不兼容导致无法正常工作的问题。

## 安装教程

在继续本教程前，请务必先替换一次同步脚本**sync_config.py**本脚本是最新脚本，请替换到对应位置并且运行。以确保配置文件是最新的（Windows：打开此电脑-C盘-app目录下，直接双击执行run_sync.bat；Ubuntu：在终端中：cd /opt/devenv，在终端中执行./run_sync.sh）

1. Ubuntu
   1. 下载脚本**install.sh**，然后拖到云电脑里，确保脚本在~/Downloads下；
   2. 下载二进制安装文件claude，然后拖到云电脑里，确保文件在~/Downloads下；
      [claude下载文件 ](https://mf-test.obs.cn-east-3.myhuaweicloud.com:443/test/claude?AccessKeyId=LWHINVH46A6T23FU2DFB&Expires=1805518652&Signature=C0oYUqRFGSltY5XWousAVCAnX7U%3D)
   3. 执行install.sh（先赋予权限：chmod+x ./install.sh，然后执行：./install.sh）；
   4. 安装成功后，在终端执行claude即可开始使用。
2. Windows
   1. 下载安装文件claude.exe 拖进云电脑里，确保文件在C:\Downloads下；
      [Claude.exe](https://mf-test.obs.cn-east-3.myhuaweicloud.com:443/test/claude.exe?AccessKeyId=LWHINVH46A6T23FU2DFB&Expires=1805518719&Signature=6XU3C0oWnBXip8h8AilaXw10R48%3D)
   2. 运行安装脚本，**install_claude.bat**，然后在终端里输入claude使用claude cli

## Claude cli轨迹导出位置

1. Windows：C:\Users\{你的用户名}\.claude\projects\{你的项目工作目录}\{session}.jsonl
2. Linux:~/.claude/projects/{你的项目工作目录}\{session}.jsonl
