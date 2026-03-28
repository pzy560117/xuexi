      
#!/bin/bash
set -e

# ===== 可配置参数 =====
INSTALL_DIR="/opt/devenv/claude"
BIN_LINK="/usr/local/bin/claude"
SRC_BINARY="./claude"   # 你下载好的文件路径

# ===== 检查 =====
if [ ! -f "$SRC_BINARY" ]; then
  echo "Error: claude binary not found at $SRC_BINARY"
  exit 1
fi

# ===== 创建目录 =====
echo "Creating install dir: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

# ===== 拷贝二进制 =====
echo "Copying binary..."
sudo cp "$SRC_BINARY" "$INSTALL_DIR/claude"

# ===== 设置权限 =====
sudo chmod +x "$INSTALL_DIR/claude"

# ===== 建立软链接 =====
echo "Linking to $BIN_LINK"
sudo ln -sf "$INSTALL_DIR/claude" "$BIN_LINK"

# ===== 验证 =====
echo "Verifying installation..."
if command -v claude >/dev/null 2>&1; then
  echo "Installed at: $(which claude)"
  claude --version || true
else
  echo "Installation failed: claude not in PATH"
  exit 1
fi

echo ""
echo "✅ Claude installed successfully!"
echo "Install dir: $INSTALL_DIR"
echo "Command: claude"

    