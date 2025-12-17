# 磁盘 100% 问题：syslog 膨胀与修复

## 问题现象

```bash
$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   50G     0 100% /
```

**典型症状**：
- 无法创建新文件：`No space left on device`
- 无法安装软件包：`dpkg: error processing package`
- VS Code Remote 无法更新插件
- 日志写入失败，导致服务异常

---

## 根本原因：syslog 异常膨胀

### 为什么 syslog 会膨胀？

1. **日志轮转失败**：
   - 默认情况下，`rsyslog` 会将日志写入 `/var/log/syslog`
   - `logrotate` 负责定期轮转日志（压缩旧日志，清空当前日志）
   - 如果 `logrotate` 配置错误或未运行，`syslog` 会无限增长

2. **大量重复日志**：
   - 某些服务（如网络服务、systemd）会产生大量日志
   - 如果服务配置不当（如频繁重试失败的操作），日志会快速膨胀
   - 常见案例：代理服务反复尝试连接失败的端口，每秒产生数百条日志

3. **磁盘满导致恶性循环**：
   - 磁盘满后，`logrotate` 无法创建新的压缩文件
   - `rsyslog` 继续写入当前文件，导致文件越来越大
   - 最终磁盘完全耗尽，系统无法正常工作

### 如何定位大文件？

```bash
sudo du -ah /var/log --one-file-system 2>/dev/null | sort -rh | head -n 30
```

**典型输出**：
```
45G     /var/log/syslog
2.3G    /var/log/syslog.1
500M    /var/log/kern.log
100M    /var/log/auth.log
...
```

如果 `syslog` 超过 10GB，说明已经异常。

---

## 修复步骤

### Step 1：停止 rsyslog 服务

```bash
sudo systemctl stop rsyslog || true
```

> 💡 **为什么要停止？**  
> 如果不停止，`rsyslog` 会继续写入 `syslog`，导致清空操作失败。

### Step 2：清空 syslog（安全方式）

```bash
# 清空当前 syslog
sudo truncate -s 0 /var/log/syslog

# 清空轮转后的 syslog.1（如果存在）
[ -f /var/log/syslog.1 ] && sudo truncate -s 0 /var/log/syslog.1

# 删除旧的压缩日志
sudo rm -f /var/log/syslog.*.gz 2>/dev/null || true
```

> 💡 **为什么用 `truncate` 而不是 `rm`？**  
> - `truncate` 只清空文件内容，不删除文件本身
> - 避免 `rsyslog` 重启后找不到文件
> - 更安全，不会影响文件权限和所有者

### Step 3：重启 rsyslog 服务

```bash
sudo systemctl start rsyslog || true
```

### Step 4：验证磁盘空间

```bash
df -h /
```

**期望输出**：
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   5G   42G  11% /
```

如果 `Use%` 仍接近 100%，继续下一步。

---

## 进阶排查：已删除但仍被占用的文件

### 问题现象

即使删除了大文件，`df` 仍显示磁盘满。

### 原因

某些进程打开了文件后，即使文件被删除，磁盘空间仍不会释放，直到进程关闭文件句柄。

### 定位占用文件的进程

```bash
sudo lsof +L1 | sort -k7 -h | tail -n 20
```

**输出示例**：
```
COMMAND   PID USER   FD   TYPE DEVICE    SIZE/OFF NLINK NODE NAME
rsyslogd 1234 root    3w   REG  8,1   45000000000     0 1234 /var/log/syslog (deleted)
```

**解读**：
- `SIZE/OFF`：文件大小（45GB）
- `NLINK`：链接数（0 表示已删除）
- `NAME`：文件路径（`(deleted)` 表示已删除但仍被占用）

### 释放空间

重启占用文件的进程：

```bash
sudo systemctl restart rsyslog
```

或者直接杀掉进程：

```bash
sudo kill -9 1234
```

### 验证

```bash
df -h /
```

空间应该已经释放。

---

## 预防措施

### 1. 配置 logrotate

编辑 `/etc/logrotate.d/rsyslog`：

```bash
sudo nano /etc/logrotate.d/rsyslog
```

确保包含以下配置：

```
/var/log/syslog
{
    rotate 7
    daily
    missingok
    notifempty
    delaycompress
    compress
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
```

**关键参数**：
- `rotate 7`：保留 7 天的日志
- `daily`：每天轮转一次
- `compress`：压缩旧日志
- `delaycompress`：延迟一天再压缩（避免正在写入的文件被压缩）

### 2. 手动测试 logrotate

```bash
sudo logrotate -f /etc/logrotate.d/rsyslog
```

检查是否生成了 `syslog.1` 和 `syslog.2.gz`：

```bash
ls -lh /var/log/syslog*
```

### 3. 限制日志大小

编辑 `/etc/rsyslog.conf`：

```bash
sudo nano /etc/rsyslog.conf
```

添加以下配置（限制单个文件最大 100MB）：

```
$outchannel log_rotation,/var/log/syslog,104857600,/usr/lib/rsyslog/rsyslog-rotate
*.* :omfile:$log_rotation
```

重启 rsyslog：

```bash
sudo systemctl restart rsyslog
```

### 4. 定期监控磁盘

添加 cron 任务，每天检查磁盘使用率：

```bash
crontab -e
```

添加：

```
0 2 * * * df -h / | grep -E '^/dev/' | awk '{if ($5+0 > 90) print "Disk usage:", $5}' | mail -s "Disk Alert" your@email.com
```

---

## 总结

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| syslog 膨胀 | logrotate 未运行或配置错误 | 配置 logrotate，定期轮转 |
| 删除文件后空间未释放 | 进程仍占用文件句柄 | 重启占用进程 |
| 磁盘满导致服务异常 | 无法写入新文件 | 清空 syslog，释放空间 |

**推荐做法**：
- 定期检查 `/var/log` 大小
- 配置 logrotate 自动轮转
- 限制单个日志文件大小
- 监控磁盘使用率，及时告警

---

## 下一步

阅读 [04_vscode_remote_proxy_cleanup.md](04_vscode_remote_proxy_cleanup.md) 了解如何清理 VS Code Remote 的代理配置。
