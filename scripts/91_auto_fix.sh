#!/usr/bin/env bash
# ===========================================
# Mihomo 代理一键修复脚本
# 路径: scripts/91_auto_fix.sh
# 用途: 自动修复常见的代理问题
# ===========================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE} Mihomo 代理一键修复${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# 1. 检查并清理磁盘空间
echo -e "${BLUE}[1/6] 检查磁盘空间...${NC}"
DISK_USE=$(df / --output=pcent | tail -1 | tr -d '% ')
if [ "$DISK_USE" -ge 90 ]; then
    echo -e "${YELLOW}  磁盘使用率 ${DISK_USE}%，开始清理...${NC}"
    
    # 清理 syslog
    sudo systemctl stop rsyslog 2>/dev/null || true
    sudo truncate -s 0 /var/log/syslog 2>/dev/null || true
    [ -f /var/log/syslog.1 ] && sudo truncate -s 0 /var/log/syslog.1 2>/dev/null || true
    sudo rm -f /var/log/syslog.*.gz 2>/dev/null || true
    sudo systemctl start rsyslog 2>/dev/null || true
    
    # 清理 journal
    sudo journalctl --vacuum-size=100M 2>/dev/null || true
    
    NEW_DISK_USE=$(df / --output=pcent | tail -1 | tr -d '% ')
    echo -e "${GREEN}  ✓ 清理完成: ${DISK_USE}% -> ${NEW_DISK_USE}%${NC}"
else
    echo -e "${GREEN}  ✓ 磁盘空间正常 (${DISK_USE}%)${NC}"
fi

# 2. 确保 mihomo 进程运行
echo ""
echo -e "${BLUE}[2/6] 检查 Mihomo 进程...${NC}"
if ! pgrep -f '/opt/clash/bin/mihomo' > /dev/null 2>&1; then
    echo -e "${YELLOW}  Mihomo 未运行，尝试启动...${NC}"
    if [ -f /opt/clash/bin/mihomo ]; then
        cd /opt/clash
        sudo nohup /opt/clash/bin/mihomo -d /opt/clash -f /opt/clash/runtime.yaml > /dev/null 2>&1 &
        sleep 2
        if pgrep -f '/opt/clash/bin/mihomo' > /dev/null 2>&1; then
            echo -e "${GREEN}  ✓ Mihomo 启动成功${NC}"
        else
            echo -e "${RED}  ✗ Mihomo 启动失败${NC}"
        fi
    else
        echo -e "${RED}  ✗ Mihomo 未安装，请先运行: bash scripts/20_install_mihomo.sh${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Mihomo 进程运行中${NC}"
fi

# 3. 清理 1080 端口配置残留
echo ""
echo -e "${BLUE}[3/6] 清理 1080 端口配置...${NC}"
CLEANED=0

# ~/.bashrc
if grep -q '127\.0\.0\.1:1080' ~/.bashrc 2>/dev/null; then
    sed -i.bak '/127\.0\.0\.1:1080/d' ~/.bashrc
    echo -e "${GREEN}  ✓ 清理 ~/.bashrc${NC}"
    CLEANED=1
fi

# ~/.profile
if grep -q '127\.0\.0\.1:1080' ~/.profile 2>/dev/null; then
    sed -i.bak '/127\.0\.0\.1:1080/d' ~/.profile
    echo -e "${GREEN}  ✓ 清理 ~/.profile${NC}"
    CLEANED=1
fi

# VS Code settings.json
VSCODE_SETTINGS="$HOME/.antigravity-server/data/Machine/settings.json"
if [ -f "$VSCODE_SETTINGS" ] && grep -q '"http.proxy"' "$VSCODE_SETTINGS" 2>/dev/null; then
    python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home()/".antigravity-server/data/Machine/settings.json"
if p.exists():
    d = json.loads(p.read_text(encoding="utf-8"))
    changed = False
    for k in ["http.proxy","http.proxyStrictSSL","http.proxySupport"]:
        if k in d:
            d.pop(k)
            changed = True
    if changed:
        p.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
        print("  Cleaned VS Code settings.json")
PY
    echo -e "${GREEN}  ✓ 清理 VS Code settings.json${NC}"
    CLEANED=1
fi

if [ $CLEANED -eq 0 ]; then
    echo -e "${GREEN}  ✓ 无需清理${NC}"
fi

# 4. 清除当前 shell 的代理环境变量
echo ""
echo -e "${BLUE}[4/6] 清除代理环境变量...${NC}"
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy 2>/dev/null || true
echo -e "${GREEN}  ✓ 已清除代理环境变量${NC}"
echo -e "${YELLOW}  提示: 新开的终端会话会自动应用${NC}"

# 5. 重启 VS Code Remote 进程
echo ""
echo -e "${BLUE}[5/6] 重启 VS Code Remote 进程...${NC}"
pkill -u "$USER" -f 'bootstrap-fork--type=extensionHost' 2>/dev/null || true
pkill -u "$USER" -f 'remoteExtensionHost|extensionHost|antigravity|language_server' 2>/dev/null || true
echo -e "${GREEN}  ✓ 已发送重启信号${NC}"
echo -e "${YELLOW}  提示: VS Code 会自动重新连接${NC}"

# 6. 验证
echo ""
echo -e "${BLUE}[6/6] 验证代理状态...${NC}"
sleep 1

# DNS 测试
if getent hosts www.google.com > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ DNS 解析正常${NC}"
else
    echo -e "${RED}  ✗ DNS 解析失败${NC}"
fi

# HTTP 测试
if curl -s --connect-timeout 5 -I https://www.google.com 2>&1 | grep -q 'HTTP'; then
    echo -e "${GREEN}  ✓ 网络连接正常${NC}"
else
    echo -e "${RED}  ✗ 网络连接失败${NC}"
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}🎉 修复完成！${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "如果问题仍然存在，请尝试:"
echo -e "  1. 重新打开终端"
echo -e "  2. 重新连接 VS Code Remote"
echo -e "  3. 运行诊断: bash scripts/90_diagnose_proxy.sh"
