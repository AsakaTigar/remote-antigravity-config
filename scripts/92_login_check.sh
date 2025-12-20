#!/usr/bin/env bash
# ===========================================
# 用户登录时自动检查并修复代理
# 路径: scripts/92_login_check.sh
# 由 systemd user service 调用
# ===========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$HOME/.local/share/antigravity-proxy-check.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== 开始登录检查 ==="

# 检查 mihomo 进程
if ! pgrep -f '/opt/clash/bin/mihomo' > /dev/null 2>&1; then
    log "WARNING: Mihomo 未运行，尝试启动..."
    if [ -f /opt/clash/bin/mihomo ]; then
        cd /opt/clash
        sudo nohup /opt/clash/bin/mihomo -d /opt/clash -f /opt/clash/runtime.yaml > /dev/null 2>&1 &
        sleep 2
        if pgrep -f '/opt/clash/bin/mihomo' > /dev/null 2>&1; then
            log "OK: Mihomo 启动成功"
        else
            log "ERROR: Mihomo 启动失败"
            # 发送桌面通知（如果有 GUI）
            notify-send "Proxy Alert" "Mihomo 启动失败，请手动检查" 2>/dev/null || true
        fi
    fi
else
    log "OK: Mihomo 进程运行中"
fi

# 检查 TUN 设备
if ! ip tuntap show 2>/dev/null | grep -qE 'Meta|tun'; then
    log "WARNING: TUN 设备不存在"
    notify-send "Proxy Alert" "TUN 设备不存在，代理可能无法正常工作" 2>/dev/null || true
else
    log "OK: TUN 设备正常"
fi

# 检查 DNS
if ! getent hosts www.google.com > /dev/null 2>&1; then
    log "WARNING: DNS 解析失败"
    notify-send "Proxy Alert" "DNS 解析失败，建议运行修复脚本" 2>/dev/null || true
else
    log "OK: DNS 解析正常"
fi

# 检查磁盘空间
DISK_USE=$(df / --output=pcent | tail -1 | tr -d '% ')
if [ "$DISK_USE" -ge 90 ]; then
    log "WARNING: 磁盘使用率 ${DISK_USE}%"
    notify-send "Disk Alert" "根分区使用率 ${DISK_USE}%，建议清理" 2>/dev/null || true
    
    # 自动清理 syslog
    sudo truncate -s 0 /var/log/syslog 2>/dev/null || true
    [ -f /var/log/syslog.1 ] && sudo truncate -s 0 /var/log/syslog.1 2>/dev/null || true
    sudo rm -f /var/log/syslog.*.gz 2>/dev/null || true
    log "OK: 已清理 syslog"
else
    log "OK: 磁盘使用率 ${DISK_USE}%"
fi

log "=== 登录检查完成 ==="
