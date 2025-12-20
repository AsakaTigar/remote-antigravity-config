# Mihomo 配置管理

本目录包含 Mihomo (Meta Clash) 的配置模板和管理脚本。

## 目录结构

```
mihomo/
├── README.md              # 本文件
├── mixin.yaml            # TUN + DNS 混合配置模板
├── templates/
│   └── config.template.yaml  # 基础配置模板（不含订阅信息）
└── scripts/
    └── sync_config.sh    # 同步配置到系统目录
```

## 使用方法

### 1. 检查当前状态

```bash
bash scripts/90_diagnose_proxy.sh
```

### 2. 一键修复

```bash
bash scripts/91_auto_fix.sh
```

### 3. 手动同步配置

```bash
bash mihomo/scripts/sync_config.sh
```

## 配置说明

### mixin.yaml

这是 Mihomo 的核心配置，包含：
- **TUN 模式**：接管系统网络栈
- **DNS 配置**：fake-ip 模式 + DNS 劫持
- **系统代理**：自动设置系统代理

### 重要提示

⚠️ **不要把订阅链接提交到 git！**
- 订阅信息保存在 `~/secrets/subscription.txt`
- 或直接配置在 `/opt/clash/url` 中

## 故障排查

常见问题请参考：
- [02_zero_to_working_mihomo_tun.md](../docs/02_zero_to_working_mihomo_tun.md)
- [03_disk_full_syslog_fix.md](../docs/03_disk_full_syslog_fix.md)
