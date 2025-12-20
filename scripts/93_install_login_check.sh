#!/usr/bin/env bash
# ===========================================
# 安装登录自动检查服务
# 路径: scripts/93_install_login_check.sh
# 用途: 安装 systemd user service
# ===========================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo " 安装登录自动检查服务"
echo "========================================="
echo ""

# 创建用户目录
mkdir -p ~/.config/systemd/user/
mkdir -p ~/.local/bin/

# 复制脚本到用户目录
cp "$SCRIPT_DIR/92_login_check.sh" ~/.local/bin/antigravity-login-check.sh
chmod +x ~/.local/bin/antigravity-login-check.sh

# 复制并配置服务文件
cp "$REPO_DIR/systemd/antigravity-proxy-check.service" ~/.config/systemd/user/

# 确保脚本可执行
chmod +x "$SCRIPT_DIR/90_diagnose_proxy.sh"
chmod +x "$SCRIPT_DIR/91_auto_fix.sh"

# 重载 systemd
systemctl --user daemon-reload

# 启用服务
systemctl --user enable antigravity-proxy-check.service

echo ""
echo "✓ 服务安装成功！"
echo ""
echo "现在每次登录时都会自动检查代理状态。"
echo ""
echo "可用命令："
echo "  查看服务状态: systemctl --user status antigravity-proxy-check"
echo "  查看日志:     cat ~/.local/share/antigravity-proxy-check.log"
echo "  手动运行:     bash scripts/92_login_check.sh"
echo "  卸载服务:     systemctl --user disable antigravity-proxy-check.service"
