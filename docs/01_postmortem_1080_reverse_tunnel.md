# 复盘：为什么 1080 反向隧道链路不推荐

## 问题背景

在配置 VS Code Remote 的代理时，一个常见的思路是：

1. 在本地机器上建立 SSH 动态端口转发（SOCKS5 代理）：
   ```bash
   ssh -D 1080 -N user@remote-server
   ```

2. 在远程服务器上配置环境变量或使用 proxychains：
   ```bash
   export http_proxy=http://127.0.0.1:1080
   export https_proxy=http://127.0.0.1:1080
   ```

3. 期望所有程序（包括 VS Code Server、Extension Host、Language Server）都能通过 1080 端口访问外网。

**然而，这条路径在实践中非常脆弱，不推荐作为稳定方案。**

---

## 为什么 1080 反向隧道链路"很难搞"

### 1. 端口依赖强：一旦 1080 没起来，整个链路崩溃

- **现象**：`proxyconnect tcp ... 127.0.0.1:1080: connect: connection refused`
- **原因**：
  - SSH 动态转发需要保持连接，一旦断开（网络波动、SSH 超时、本地机器重启），1080 端口就会消失
  - 远程服务器上的进程仍然尝试连接 1080，导致所有网络请求失败
  - 重新建立 SSH 连接后，进程不会自动重试，需要手动重启

### 2. 配置残留难排查：即使切换到其他代理，1080 仍被"记住"

- **现象**：明明已经安装了 mihomo 并监听 7890，但 VS Code 插件仍然报错 `connect: connection refused` 到 1080
- **原因**：
  - Shell 启动文件（`.bashrc`、`.profile`）中残留 `export http_proxy=http://127.0.0.1:1080`
  - VS Code Remote 的 `settings.json` 中残留 `"http.proxy": "http://127.0.0.1:1080"`
  - 这些配置会覆盖系统级代理，导致进程"死盯 1080"

- **排查难点**：
  - 配置分散在多个文件中（shell 配置、VS Code 配置、systemd 环境变量）
  - 即使删除了环境变量，VS Code 的 Extension Host 仍可能从缓存的配置中读取
  - 需要手动清理 + 重启进程才能生效

### 3. DNS 经常被忽略：代理链只解决 TCP，不必然解决 DNS

- **现象**：`getaddrinfo ENOTFOUND www.google.com`
- **原因**：
  - SOCKS5 代理可以转发 TCP 流量，但不一定处理 DNS 解析
  - Node.js 的 `https.get()` 会先调用 `getaddrinfo()` 解析域名，这一步不走代理
  - 如果远程服务器的 DNS 配置有问题（如 `/etc/resolv.conf` 指向无法访问的 DNS 服务器），即使代理通了，DNS 仍会失败

- **常见误区**：
  - 以为 `export http_proxy` 就能解决所有问题
  - 实际上需要配合 `proxychains`（但 proxychains 也有兼容性问题）
  - 或者使用 TUN 模式接管整个网络栈（包括 DNS）

### 4. VS Code Remote 的网络栈非常挑剔

- **Extension Host 和 Language Server 的特殊性**：
  - 这些进程不是简单的 HTTP 客户端，而是复杂的多进程架构
  - 它们会启动子进程（如 TypeScript Language Server、Python Language Server）
  - 子进程的网络配置可能不继承父进程的环境变量
  - 即使父进程配置了代理，子进程仍可能直连或使用错误的代理

- **实际案例**：
  - 用户配置了 `http_proxy=http://127.0.0.1:1080`
  - VS Code Server 启动成功，但 Extension Host 启动失败
  - 原因：Extension Host 尝试下载依赖时，使用了硬编码的 1080 代理
  - 即使后来切换到 7890，Extension Host 仍从缓存的配置中读取 1080

---

## 典型故障场景回放

### 场景 1：SSH 断开后，所有插件失效

1. 用户在本地执行 `ssh -D 1080 -N user@remote`
2. 远程服务器配置 `export http_proxy=http://127.0.0.1:1080`
3. VS Code Remote 连接成功，插件正常工作
4. **网络波动，SSH 连接断开**
5. 远程服务器上的 1080 端口消失
6. VS Code 插件尝试连接 1080，全部失败
7. 用户重新建立 SSH 连接，但 VS Code 进程已经缓存了失败状态
8. **需要手动重启 VS Code Remote 才能恢复**

### 场景 2：切换到 mihomo 后，插件仍连接 1080

1. 用户安装 mihomo，监听 7890
2. 用户删除了当前 shell 的 `http_proxy` 环境变量
3. 用户测试 `curl https://www.google.com` 成功（因为 TUN 模式已生效）
4. **但 VS Code 插件仍然报错 `connect: connection refused` 到 1080**
5. 原因：`.bashrc` 中仍有 `export http_proxy=http://127.0.0.1:1080`
6. VS Code Remote 启动时加载了 `.bashrc`，导致所有子进程都使用 1080
7. **需要清理 `.bashrc` + 重启 VS Code Remote 才能解决**

### 场景 3：DNS 解析失败，即使代理通了

1. 用户配置了 proxychains + 1080 代理
2. `proxychains curl https://www.google.com` 成功
3. **但 Node.js 脚本仍报错 `getaddrinfo ENOTFOUND`**
4. 原因：proxychains 只劫持 `connect()` 系统调用，不劫持 `getaddrinfo()`
5. Node.js 的 DNS 解析不走代理，直接查询 `/etc/resolv.conf`
6. 如果 DNS 服务器无法访问，解析失败
7. **需要配置 TUN 模式或修改 `/etc/resolv.conf` 才能解决**

---

## 结论：不推荐 1080 反向隧道作为稳定方案

| 问题 | 反向隧道 + 1080 | mihomo TUN |
|------|----------------|------------|
| **端口依赖** | 强（SSH 断开即失效） | 无（systemd 服务自动重启） |
| **配置残留** | 多处配置，难以清理 | 统一配置，易于管理 |
| **DNS 支持** | 需要额外配置（proxychains） | 内置 DNS 服务器 |
| **VS Code 兼容性** | 差（子进程配置不一致） | 好（TUN 接管所有流量） |
| **故障恢复** | 需要手动重启多个进程 | 自动恢复 |

**推荐做法**：
- **临时实验**：可以用 1080 反向隧道快速验证
- **长期使用**：必须切换到 mihomo TUN 模式
- **公开分享**：只推荐 TUN 方案，避免误导他人

---

## 下一步

阅读 [02_zero_to_working_mihomo_tun.md](02_zero_to_working_mihomo_tun.md) 了解如何从 0 开始配置 mihomo TUN 模式。
