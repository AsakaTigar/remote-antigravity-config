#!/usr/bin/env bash
# ===========================================
# Mihomo 代理状态诊断脚本
# 路径: scripts/90_diagnose_proxy.sh
# 用途: 一键诊断代理、TUN、DNS 状态
# ===========================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE} Mihomo TUN + DNS 代理状态诊断${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# 计数器
ERRORS=0
WARNINGS=0

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((ERRORS++)) || true
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((WARNINGS++)) || true
}

# 1. 检查磁盘空间
echo -e "${BLUE}[1/7] 检查磁盘空间${NC}"
DISK_USE=$(df / --output=pcent | tail -1 | tr -d '% ')
if [ "$DISK_USE" -ge 95 ]; then
    check_fail "根分区使用率 ${DISK_USE}% (>= 95%，危险！)"
elif [ "$DISK_USE" -ge 85 ]; then
    check_warn "根分区使用率 ${DISK_USE}% (>= 85%，需要清理)"
else
    check_pass "根分区使用率 ${DISK_USE}%"
fi

# 2. 检查 mihomo 进程
echo ""
echo -e "${BLUE}[2/7] 检查 Mihomo 进程${NC}"
if pgrep -f '/opt/clash/bin/mihomo' > /dev/null 2>&1; then
    check_pass "Mihomo 进程运行中"
    MIHOMO_PID=$(pgrep -f '/opt/clash/bin/mihomo' | head -1)
    echo -e "      PID: ${MIHOMO_PID}"
else
    check_fail "Mihomo 进程未运行"
fi

# 额外检查 clash-verge
if pgrep -f 'clash-verge' > /dev/null 2>&1; then
    check_warn "clash-verge GUI 也在运行（可能冲突）"
fi

# 3. 检查 TUN 设备
echo ""
echo -e "${BLUE}[3/7] 检查 TUN 设备${NC}"
if ip tuntap show 2>/dev/null | grep -qE 'Meta|tun'; then
    check_pass "TUN 设备已创建"
    ip tuntap show 2>/dev/null | grep -E 'Meta|tun' | while read line; do
        echo -e "      ${line}"
    done
else
    check_fail "TUN 设备不存在"
fi

# 4. 检查 DNS 解析
echo ""
echo -e "${BLUE}[4/7] 检查 DNS 解析${NC}"
DNS_RESULT=$(getent hosts www.google.com 2>/dev/null || echo "")
if [ -n "$DNS_RESULT" ]; then
    check_pass "DNS 解析正常"
    echo -e "      ${DNS_RESULT}"
    # 检查是否是 fake-ip
    if echo "$DNS_RESULT" | grep -q '198.18.'; then
        echo -e "      ${GREEN}(fake-ip 模式)${NC}"
    fi
else
    check_fail "DNS 解析失败"
fi

# 5. 检查代理环境变量
echo ""
echo -e "${BLUE}[5/7] 检查代理环境变量${NC}"
if env | grep -qi 'proxy'; then
    check_warn "存在代理环境变量（TUN 模式不需要）"
    env | grep -i proxy | while read line; do
        echo -e "      ${line}"
    done
else
    check_pass "无代理环境变量（TUN 模式正确）"
fi

# 6. 检查网络连接
echo ""
echo -e "${BLUE}[6/7] 检查网络连接${NC}"
if curl -s --connect-timeout 5 -I https://www.google.com 2>&1 | grep -q 'HTTP'; then
    check_pass "可以访问 Google"
else
    check_fail "无法访问 Google"
fi

# 7. 检查 1080 端口残留
echo ""
echo -e "${BLUE}[7/7] 检查 1080 端口配置残留${NC}"
FOUND_1080=0

# ~/.bashrc
if grep -q '127\.0\.0\.1:1080' ~/.bashrc 2>/dev/null; then
    check_warn "~/.bashrc 中有 1080 端口配置"
    FOUND_1080=1
fi

# ~/.profile
if grep -q '127\.0\.0\.1:1080' ~/.profile 2>/dev/null; then
    check_warn "~/.profile 中有 1080 端口配置"
    FOUND_1080=1
fi

# VS Code settings
VSCODE_SETTINGS="$HOME/.antigravity-server/data/Machine/settings.json"
if [ -f "$VSCODE_SETTINGS" ] && grep -q '"http.proxy"' "$VSCODE_SETTINGS" 2>/dev/null; then
    check_warn "VS Code settings.json 中有 http.proxy 配置"
    FOUND_1080=1
fi

if [ $FOUND_1080 -eq 0 ]; then
    check_pass "未发现 1080 端口配置残留"
fi

# 结果汇总
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE} 诊断结果汇总${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 所有检查通过！代理工作正常。${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  有 ${WARNINGS} 个警告，但无严重错误。${NC}"
else
    echo -e "${RED}❌ 发现 ${ERRORS} 个错误，${WARNINGS} 个警告。${NC}"
    echo ""
    echo -e "${YELLOW}建议运行修复脚本:${NC}"
    echo -e "  bash scripts/91_auto_fix.sh"
fi

echo ""
exit $ERRORS
