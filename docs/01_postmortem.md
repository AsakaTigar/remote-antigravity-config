# 复盘：Antigravity + VS Code Remote 在 Linux 服务器上的代理/DNS/磁盘链路故障

## 现象
- VS Code Remote 侧 Antigravity server/extensionHost 报错，提示通过 SOCKS/HTTP 代理连接失败（常见为 127.0.0.1:1080 connection refused）。
- Node/扩展进程出现 `getaddrinfo ENOTFOUND`（DNS 不可用）或被错误代理劫持。
- 系统出现 `No space left on device`，导致无法写入扩展 wrapper、无法 sed 修改配置、无法备份文件。

## 核心根因
1. 代理端口与机制混乱
   - 系统实际可用代理在 127.0.0.1:7890（mihomo mixed port）。
   - 但历史配置残留在：
     - ~/.bashrc、~/.profile（export http_proxy/https_proxy/all_proxy 指向 127.0.0.1:1080）
     - VS Code/扩展 settings.json（http.proxy 指向 127.0.0.1:1080）
     - 扩展日志/旧 wrapper 文件中也记录了 1080
   - 导致 VS Code Remote 的 extensionHost 进程持续尝试连接 1080 而失败。

2. DNS 链路未打通（在未启用 TUN 或 DNS 配置未生效时）
   - `getent hosts www.google.com` 失败，Node https 请求报 ENOTFOUND。

3. 根分区空间耗尽形成连锁故障
   - /var/log/syslog 异常膨胀到数百 GB，导致任何写操作失败。

## 修复策略总览
A. 用 mihomo + TUN 模式接管系统网络（避免 proxychains 这类 LD_PRELOAD 注入方案）
B. 清理所有 127.0.0.1:1080 的遗留代理配置（shell + VS Code/扩展 settings）
C. 释放根分区空间（重点排查 /var/log，必要时截断 syslog 并恢复 logrotate）
D. 重启 VS Code Remote 相关进程（extensionHost/antigravity）触发重新拉起

## 验证标准（成功判据）
- `getent hosts www.google.com` 有返回（DNS OK）
- `node -e 'https.get(...)'` 返回 200/302（Node/扩展链路 OK）
- `ss -lntp | grep 7890` 可看到 mihomo 监听
- VS Code Remote 侧 Antigravity 不再报 1080 connection refused
