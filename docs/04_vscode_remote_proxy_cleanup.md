# VS Code Remote 代理配置清理详解

## 问题背景

即使系统代理已经配置正确（如 mihomo TUN 已启用），VS Code Remote 的插件仍可能报错：

```
Error: connect ECONNREFUSED 127.0.0.1:1080
```

**根本原因**：VS Code Remote 的代理配置分散在多个位置，且优先级高于系统代理。

---

## VS Code Remote 的代理配置来源

### 1. Shell 启动文件（`.bashrc`、`.profile`）

VS Code Server 启动时会加载 shell 配置文件，如果其中包含：

```bash
export http_proxy=http://127.0.0.1:1080
export https_proxy=http://127.0.0.1:1080
```

那么所有子进程（包括 Extension Host、Language Server）都会继承这些环境变量。

**优先级**：高（会覆盖系统代理）

### 2. VS Code Remote 的 `settings.json`

路径：`~/.antigravity-server/data/Machine/settings.json`

如果包含：

```json
{
  "http.proxy": "http://127.0.0.1:1080",
  "http.proxyStrictSSL": false,
  "http.proxySupport": "on"
}
```

那么 VS Code 的所有网络请求都会使用这个代理。

**优先级**：最高（会覆盖环境变量和系统代理）

### 3. systemd 环境变量（如果使用 systemd 启动 VS Code Server）

某些安装方式会将 VS Code Server 注册为 systemd 服务，环境变量可能在 service 文件中定义。

**优先级**：中（仅影响 systemd 启动的进程）

---

## 清理步骤

### Step 1：清理 shell 配置

#### 检查当前配置

```bash
grep -nE '127\.0\.0\.1:1080' ~/.bashrc ~/.profile
```

**典型输出**：
```
/home/user/.bashrc:10:export http_proxy=http://127.0.0.1:1080
/home/user/.bashrc:11:export https_proxy=http://127.0.0.1:1080
```

#### 删除相关行

```bash
sed -i.bak '/127\.0\.0\.1:1080/d' ~/.bashrc ~/.profile
```

**说明**：
- `-i.bak`：原地修改，并备份到 `.bashrc.bak` 和 `.profile.bak`
- `/127\.0\.0\.1:1080/d`：删除包含 `127.0.0.1:1080` 的行

#### 验证

```bash
grep -nE '127\.0\.0\.1:1080' ~/.bashrc ~/.profile || echo "OK"
```

---

### Step 2：清理 VS Code Remote 配置

#### 检查当前配置

```bash
cat ~/.antigravity-server/data/Machine/settings.json | grep -i proxy
```

**典型输出**：
```json
  "http.proxy": "http://127.0.0.1:1080",
  "http.proxyStrictSSL": false,
  "http.proxySupport": "on"
```

#### 使用 Python 脚本清理

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

**说明**：
- 读取 `settings.json`
- 删除 `http.proxy`、`http.proxyStrictSSL`、`http.proxySupport`
- 保存修改后的配置

#### 验证

```bash
cat ~/.antigravity-server/data/Machine/settings.json | grep -i proxy || echo "OK"
```

---

### Step 3：清理 systemd 环境变量（可选）

#### 检查是否有 systemd 服务

```bash
systemctl --user list-units | grep -i vscode
```

如果有输出，说明 VS Code Server 注册为 systemd 服务。

#### 检查服务文件

```bash
systemctl --user cat vscode-server.service
```

查找 `Environment=` 行，如果包含 `http_proxy=http://127.0.0.1:1080`，需要编辑服务文件：

```bash
systemctl --user edit vscode-server.service
```

删除相关行，保存后重启服务：

```bash
systemctl --user daemon-reload
systemctl --user restart vscode-server.service
```

---

### Step 4：重启 VS Code Remote 相关进程

```bash
pkill -u "$USER" -f 'bootstrap-fork --type=extensionHost' || true
pkill -u "$USER" -f 'remoteExtensionHost|extensionHost|antigravity|language_server' || true
```

**说明**：
- 杀掉所有 Extension Host 和 Language Server 进程
- VS Code 会自动重启这些进程，并加载新的配置

---

## 验证清理结果

### 1. 检查环境变量

在远程服务器上打开一个新的 shell：

```bash
env | grep -i proxy
```

**期望输出**：无输出（或只有 TUN 模式相关的配置）

### 2. 检查 VS Code 配置

```bash
cat ~/.antigravity-server/data/Machine/settings.json | grep -i proxy || echo "OK"
```

**期望输出**：`OK`

### 3. 测试 Node HTTPS

```bash
node -e 'require("https").get("https://www.google.com",r=>{console.log("status",r.statusCode);r.resume()}).on("error",e=>{console.error("err",e.message)})'
```

**期望输出**：
```
status 200
```

### 4. 重新连接 VS Code Remote

在本地 VS Code 中，重新连接到远程服务器，观察：
- Output 面板中是否有 Language Server 启动成功的日志
- 插件是否能正常工作（如代码补全、跳转定义）

---

## 故障排查

### 1. 清理后仍报错 `ECONNREFUSED 127.0.0.1:1080`

**可能原因**：
- shell 配置未生效（需要重新登录或 `source ~/.bashrc`）
- VS Code 进程未重启（需要手动杀掉进程）
- 还有其他配置文件残留（如 `~/.zshrc`、`~/.bash_profile`）

**解决方案**：
```bash
# 检查所有 shell 配置文件
grep -rn '127\.0\.0\.1:1080' ~ 2>/dev/null | grep -E '\.(bashrc|profile|zshrc|bash_profile):'

# 重新登录
exit
# 重新连接 SSH

# 手动杀掉所有 VS Code 进程
pkill -u "$USER" -f 'vscode|antigravity|extensionHost|language_server'
```

### 2. `settings.json` 不存在

**可能原因**：
- VS Code Remote 未正确安装
- 路径不对（不同版本的 VS Code 路径可能不同）

**解决方案**：
```bash
# 查找 settings.json
find ~ -name settings.json 2>/dev/null | grep -i vscode

# 如果找到，修改脚本中的路径
```

### 3. Python 脚本报错

**可能原因**：
- `settings.json` 格式错误（如包含注释、尾随逗号）
- Python 版本过低（需要 Python 3.6+）

**解决方案**：
```bash
# 手动编辑 settings.json
nano ~/.antigravity-server/data/Machine/settings.json

# 删除以下行：
# "http.proxy": "...",
# "http.proxyStrictSSL": ...,
# "http.proxySupport": "..."
```

---

## 总结

| 配置位置 | 优先级 | 清理方法 |
|---------|--------|---------|
| `settings.json` | 最高 | Python 脚本或手动编辑 |
| `.bashrc`/`.profile` | 高 | `sed` 删除相关行 |
| systemd 环境变量 | 中 | 编辑 service 文件 |

**推荐做法**：
- 优先清理 `settings.json`（影响最大）
- 再清理 shell 配置（影响子进程）
- 最后检查 systemd 配置（如果使用）
- 清理后必须重启 VS Code Remote 进程

---

## 下一步

所有配置清理完成后，回到 [02_zero_to_working_mihomo_tun.md](02_zero_to_working_mihomo_tun.md) 继续验证最终状态。
