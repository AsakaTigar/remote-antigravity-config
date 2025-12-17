# 从 0 开始：mihomo TUN 最短稳定路径

本文档提供一个**从零开始**的完整流程，目标是：
- ✅ 代理可用（mihomo TUN 模式）
- ✅ DNS 可用（mihomo 内置 DNS）
- ✅ VS Code Remote 不再死盯 1080
- ✅ 磁盘不再 100%

---

## Step 0：先把根分区从 100% 拉回来

> ⚠️ **如果根分区已满，任何修复都可能失败！**

### 检查磁盘使用率

```bash
df -h /
```

如果 `Use%` 接近 100%，**必须先清理**。

### 定位最大文件

```bash
sudo du -ah /var/log --one-file-system 2>/dev/null | sort -rh | head -n 30
```

通常罪魁祸首是 `/var/log/syslog`（可能膨胀到几十 GB）。

### 清空 syslog（安全方式）

```bash
# 停止 rsyslog 服务
sudo systemctl stop rsyslog || true

# 清空 syslog（不删除文件，只清空内容）
sudo truncate -s 0 /var/log/syslog
[ -f /var/log/syslog.1 ] && sudo truncate -s 0 /var/log/syslog.1

# 删除旧的压缩日志
sudo rm -f /var/log/syslog.*.gz 2>/dev/null || true

# 重启 rsyslog
sudo systemctl start rsyslog || true
```

### 检查"已删除但仍被占用"的文件

如果 `df` 仍不回升，可能有进程占用已删除的文件：

```bash
sudo lsof +L1 | sort -k7 -h | tail -n 20
```

如果发现大文件，重启对应进程即可释放空间。

### 验证

```bash
df -h /
```

确保 `Use%` 降到 90% 以下。

---

## Step 1：安装 mihomo（使用 clash-for-linux-install）

### 克隆安装脚本

```bash
mkdir -p /mnt/t2-6tb/_src && cd /mnt/t2-6tb/_src
git clone --depth 1 https://github.com/nelvko/clash-for-linux-install.git
cd clash-for-linux-install
```

### 运行安装脚本

```bash
sudo bash install.sh
```

**安装过程中会提示输入订阅链接**：
- ⚠️ **不要把订阅链接提交到 git！**
- 建议保存到 `~/secrets/subscription.txt`（已被 `.gitignore` 忽略）

### 验证安装

```bash
clashctl --help
```

应该能看到 `clashctl` 的帮助信息。

---

## Step 2：启用 TUN 模式并测试

### 启用 TUN

```bash
clashctl tun on
```

### 清空代理环境变量（重要！）

```bash
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy
```

> 💡 **为什么要清空？**  
> TUN 模式会接管整个网络栈，不需要环境变量。  
> 如果环境变量仍指向 1080，会导致冲突。

### 测试 DNS

```bash
getent hosts www.google.com
```

**期望输出**：
- 如果配置了 fake-ip，会看到 `198.18.x.x`
- 如果没有 fake-ip，会看到真实 IP（如 `142.250.x.x`）

**如果无输出**，说明 DNS 有问题，检查：
```bash
clashctl tun status
sudo systemctl status clash
sudo journalctl -u clash -n 50
```

### 测试 Node HTTPS

```bash
node -e 'require("https").get("https://www.google.com",r=>{console.log("status",r.statusCode);r.resume()}).on("error",e=>{console.error("err",e.message)})'
```

**期望输出**：
```
status 200
```
或
```
status 302
```

**如果报错 `ENOTFOUND`**，说明 DNS 仍有问题，回到上一步检查。

---

## Step 3：彻底清掉 1080 残留

> ⚠️ **这是最容易被忽略的步骤，但也是最关键的！**

### 清理 shell 配置

```bash
sed -i.bak '/127\.0\.0\.1:1080/d' ~/.bashrc ~/.profile
```

这会删除所有包含 `127.0.0.1:1080` 的行，并备份到 `.bashrc.bak` 和 `.profile.bak`。

### 清理 VS Code Remote 配置

使用 Python 脚本原地修改 `settings.json`：

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home()/".antigravity-server/data/Machine/settings.json"
if not p.exists():
    print("settings.json not found, skip")
    raise SystemExit(0)
d = json.loads(p.read_text(encoding="utf-8"))
for k in ["http.proxy","http.proxyStrictSSL","http.proxySupport"]:
    d.pop(k, None)
p.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
print("patched:", p)
PY
```

### 验证清理结果

```bash
# 检查 shell 配置
grep -nE '127\.0\.0\.1:1080' ~/.bashrc ~/.profile 2>/dev/null || echo "OK"

# 检查 VS Code 配置
grep -nE '"http\.proxy"' ~/.antigravity-server/data/Machine/settings.json 2>/dev/null || echo "OK"
```

---

## Step 4：重启 VS Code Remote 相关进程

```bash
pkill -u "$USER" -f 'bootstrap-fork --type=extensionHost' || true
pkill -u "$USER" -f 'remoteExtensionHost|extensionHost|antigravity|language_server' || true
```

### 重新连接 VS Code Remote

在本地 VS Code 中，重新连接到远程服务器。

**期望结果**：
- Extension Host 启动成功
- Language Server 启动成功（如 TypeScript、Python）
- 插件能正常下载依赖

---

## Step 5：验证最终状态

### 检查磁盘

```bash
df -h /
```

应该有足够的可用空间（建议至少 10% 可用）。

### 检查代理

```bash
# DNS 解析
getent hosts www.google.com

# Node HTTPS
node -e 'require("https").get("https://www.google.com",r=>{console.log("status",r.statusCode);r.resume()}).on("error",e=>{console.error("err",e.message)})'

# curl（可选）
curl -I https://www.google.com
```

### 检查 VS Code Remote

在 VS Code 中打开一个项目，观察：
- Output 面板中是否有 Language Server 启动成功的日志
- 插件是否能正常工作（如代码补全、跳转定义）

---

## 故障排查

### 1. `clashctl: command not found`

说明 mihomo 未正确安装，重新执行：
```bash
cd /mnt/t2-6tb/_src/clash-for-linux-install
sudo bash install.sh
```

### 2. `getent hosts www.google.com` 无输出

检查 TUN 状态：
```bash
clashctl tun status
```

如果显示 `off`，重新启用：
```bash
clashctl tun on
```

检查 mihomo 服务：
```bash
sudo systemctl status clash
```

如果服务未运行，启动：
```bash
sudo systemctl start clash
```

### 3. Node HTTPS 仍报错 `ENOTFOUND`

检查环境变量：
```bash
env | grep -i proxy
```

如果仍有 `http_proxy` 等变量，手动清空：
```bash
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy
```

检查 DNS 配置：
```bash
cat /etc/resolv.conf
```

应该包含 mihomo 的 DNS 服务器（通常是 `127.0.0.1` 或 `198.18.0.1`）。

### 4. VS Code Remote 插件仍连接 1080

检查 shell 配置：
```bash
grep -nE '127\.0\.0\.1:1080' ~/.bashrc ~/.profile
```

检查 VS Code 配置：
```bash
cat ~/.antigravity-server/data/Machine/settings.json | grep -i proxy
```

如果仍有残留，重新执行 Step 3。

---

## 下一步

- 阅读 [03_disk_full_syslog_fix.md](03_disk_full_syslog_fix.md) 了解磁盘问题的详细排查
- 阅读 [04_vscode_remote_proxy_cleanup.md](04_vscode_remote_proxy_cleanup.md) 了解 VS Code 配置的详细清理
