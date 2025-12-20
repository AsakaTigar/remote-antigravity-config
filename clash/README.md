# Clash 配置备份

本目录用于备份和管理 Clash 相关配置。

## 目录说明

```
clash/
├── README.md              # 本文件
├── config.yaml.example   # 配置示例（不含敏感信息）
└── cfw-settings.yaml     # Clash for Windows 兼容设置
```

## 系统中的 Clash 位置

当前系统中有两个 Clash 实例：

### 1. Mihomo (推荐)
- **二进制**: `/opt/clash/bin/mihomo`
- **配置目录**: `/opt/clash/`
- **配置文件**: 
  - `config.yaml` - 订阅配置
  - `mixin.yaml` - 混合覆盖配置
  - `runtime.yaml` - 运行时合并配置

### 2. Clash Verge (GUI)
- **二进制**: `/usr/bin/clash-verge`
- **配置目录**: `~/.config/clash/`
- **服务**: `clash-verge-service`

## 注意事项

⚠️ **不要在此目录保存订阅链接！**

订阅链接应保存在：
- `/opt/clash/url` (仅 root 可读)
- `~/secrets/subscription.txt` (已被 .gitignore 忽略)
