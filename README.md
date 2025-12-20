# Mihomo TUN + DNS: VS Code Remote 稳定代理方案

> **不推荐反向隧道 + 1080 代理链路**  
> 本仓库记录了从"1080 反向隧道探索"到"mihomo TUN 一步到位"的完整复盘，并提供可复用的脚本与文档。

## 📖 背景

在使用 VS Code Remote 开发时，常见的代理需求包括：
- 让远程服务器上的 VS Code Server、Extension Host、Language Server 能访问外网
- 解决 DNS 解析问题（`getaddrinfo ENOTFOUND`）
- 避免磁盘空间不足导致的各种诡异问题

**本仓库的核心价值**：
1. **复盘不推荐的路径**：反向隧道 + SOCKS 1080 + proxychains 为何难以稳定
2. **提供最短稳定路径**：mihomo TUN 模式 + DNS 一步到位
3. **一键脚本**：从环境检查、磁盘清理、mihomo 安装到 VS Code 配置清理的完整流程

---

## 🚀 快速开始（推荐路径）

### 前置条件
- Ubuntu/Debian 系统（其他发行版需调整包管理器）
- 有 sudo 权限
- 有可用的 Clash/mihomo 订阅链接

### 一键执行流程

```bash
# 1. 克隆本仓库到你的工作目录
git clone <YOUR_REPO_URL>
cd <REPO_NAME>

# 2. 检查当前环境（磁盘、端口、代理环境变量）
bash scripts/00_check_env.sh

# 3. 如果磁盘接近 100%，先清理 syslog
bash scripts/10_fix_disk_syslog.sh

# 4. 安装 mihomo（会提示输入订阅链接，不要提交到 git）
bash scripts/20_install_mihomo.sh

# 5. 启用 TUN 模式并测试 DNS + Node HTTPS
bash scripts/30_enable_tun_and_test.sh

# 6. 清理 shell 中残留的 1080 代理配置
bash scripts/40_cleanup_1080_shell_exports.sh

# 7. 清理 VS Code Remote settings.json 中的代理配置
python3 scripts/50_cleanup_vscode_proxy_settings.py

# 8. 重启 VS Code Remote 相关进程
bash scripts/60_restart_vscode_remote.sh
```

执行完成后，重新连接 VS Code Remote，应该能看到 Language Server 正常启动。

---

## 📚 文档目录

| 文档 | 说明 |
|------|------|
| [01_postmortem_1080_reverse_tunnel.md](docs/01_postmortem_1080_reverse_tunnel.md) | 复盘：为什么 1080 反向隧道链路不推荐 |
| [02_zero_to_working_mihomo_tun.md](docs/02_zero_to_working_mihomo_tun.md) | 从 0 开始：mihomo TUN 最短稳定路径 |
| [03_disk_full_syslog_fix.md](docs/03_disk_full_syslog_fix.md) | 磁盘 100% 问题：syslog 膨胀与修复 |
| [04_vscode_remote_proxy_cleanup.md](docs/04_vscode_remote_proxy_cleanup.md) | VS Code Remote 代理配置清理详解 |

---

## 🛠️ 脚本说明

| 脚本 | 功能 |
|------|------|
| `00_check_env.sh` | 检查磁盘使用率、监听端口、代理环境变量、shell 配置残留 |
| `10_fix_disk_syslog.sh` | 清理 `/var/log/syslog` 并修复日志轮转 |
| `20_install_mihomo.sh` | 安装 mihomo（使用 clash-for-linux-install） |
| `30_enable_tun_and_test.sh` | 启用 TUN 模式并测试 DNS + Node HTTPS |
| `40_cleanup_1080_shell_exports.sh` | 清理 `.bashrc` 和 `.profile` 中的 1080 代理配置 |
| `50_cleanup_vscode_proxy_settings.py` | 清理 VS Code Remote `settings.json` 中的代理配置 |
| `60_restart_vscode_remote.sh` | 重启 VS Code Remote 相关进程 |
| `90_diagnose_proxy.sh` | **诊断脚本**: 一键检查代理、TUN、DNS 状态 |
| `91_auto_fix.sh` | **一键修复**: 自动修复常见代理问题 |
| `92_login_check.sh` | **登录检查**: 开机/登录时自动检查并修复 |
| `93_install_login_check.sh` | 安装登录自动检查的 systemd user service |

---

## ⚠️ 重要提醒

### 不要提交敏感信息
- **订阅链接**：仅使用 `templates/subscription_url.example.txt` 作为模板，不要提交真实链接
- **配置文件**：`.gitignore` 已配置忽略 `config.yaml`、`runtime.yaml`、`*.mmdb` 等
- **推送前检查**：
  ```bash
  git grep -nE 'subscribe\?token=|password|secret' || echo "OK"
  ```

### 磁盘空间
- 如果 root 分区已满（`df -h /` 显示 100%），**必须先执行** `10_fix_disk_syslog.sh`
- 否则任何安装/配置操作都可能失败

### VS Code Remote 配置
- 如果之前使用过 1080 代理，**必须执行** `40_` 和 `50_` 脚本清理残留
- 否则即使系统代理已通，VS Code 插件仍会尝试连接 1080 导致失败

---

## 🔍 故障排查

### 1. `clashctl: command not found`
说明 mihomo 未正确安装，重新执行 `scripts/20_install_mihomo.sh`

### 2. `getent hosts www.google.com` 无输出
- 检查 TUN 是否启用：`clashctl tun status`
- 检查 mihomo 服务状态：`sudo systemctl status clash`
- 查看日志：`sudo journalctl -u clash -n 50`

### 3. Node HTTPS 仍报错 `ENOTFOUND`
- 确认环境变量已清空：`env | grep -i proxy`
- 确认 DNS 配置：`cat /etc/resolv.conf`（应包含 mihomo 的 DNS 服务器）
- 重启 mihomo：`sudo systemctl restart clash`

### 4. VS Code Remote 插件仍连接 1080
- 检查 `~/.bashrc` 和 `~/.profile` 是否仍有 `export http_proxy=http://127.0.0.1:1080`
- 检查 `~/.antigravity-server/data/Machine/settings.json` 是否仍有 `"http.proxy"`
- 执行 `scripts/60_restart_vscode_remote.sh` 重启进程

---

## 📦 如何使用本仓库

### 方式一：直接克隆使用

```bash
# 克隆到本地
git clone https://github.com/AsakaTigar/remote-antigravity-config.git
cd remote-antigravity-config

# 按照脚本顺序执行
bash scripts/00_check_env.sh
# ... 其他脚本
```

### 方式二：Fork 后自定义

1. 在 GitHub 上 Fork 本仓库
2. 克隆你的 Fork
3. 根据需要修改脚本和文档
4. 提交并推送到你的仓库

---

## 📄 许可证

MIT License - 可自由复用、修改、分发

---

## 🙏 致谢

- [mihomo](https://github.com/MetaCubeX/mihomo) - 强大的代理工具
- [clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install) - 一键安装脚本
- 所有在 VS Code Remote 代理配置上踩过坑的开发者
