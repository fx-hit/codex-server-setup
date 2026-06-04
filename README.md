# Codex Server Setup

这套脚本用于在远端服务器上安装 Codex CLI，并把 Codex 的历史、登录信息、配置和会话数据保存到一个持久化目录。它同时会修复 Codex Desktop SSH 连接时需要的 `app-server-control` socket 目录，避免把整个 `CODEX_HOME` 放到不支持 Unix socket 的共享文件系统上。

主要解决“远端服务器上稳定使用 Codex”的三个痛点：

> **一句话：让 Codex 在“会重启、没公网、用共享盘”的远端服务器上也能稳定工作。**

**✓ 重启不丢历史**  
把 Codex 的登录、历史、会话、配置和数据库文件保存到持久盘，即使服务器重启后本地 home 目录被清空，也能恢复原来的 Codex 状态。

**✓ 网络受限也能用**  
通过 Mac 的 SSH 反向代理，让服务器上的 Codex CLI、下载脚本和 VS Code Remote Codex 插件都能访问外网。

**✓ 桌面版 SSH 能连上**  
保留 `$CODEX_HOME/app-server-control` 为本地真实目录，避免 FUSE/网络文件系统不支持 Unix socket 导致 Codex Desktop 连接失败。

最终目标是同一台远端服务器同时支持：

- **⌨️ 服务器终端的Codex CLI** 
- **🧩 VS Code Remote 的 Codex 插件**
- **🖥️ Mac Codex Desktop 通过 SSH 连接远端项目**

## 准备信息

开始前先确认这些路径和端口：

```text
脚本仓库目录:              codex-server-setup
Codex 本地目录 CODEX_HOME: $HOME/.codex
Codex 持久化目录:         /path/to/persistent/.codex
服务器代理端口:            127.0.0.1:18080
Mac 本地代理端口:          127.0.0.1:8888
```

`/path/to/persistent/.codex` 可以是已有的 `.codex`，也可以是全新的空目录。全新用户第一次运行时，`link.sh` 会预先创建常见的 Codex 目录软链接，让后续登录、会话、历史、配置和数据库文件直接写入持久目录。

先设置 `CODEX_HOME`。`root` 用户的 `$HOME` 是 `/root`；普通用户指的是非 root 的登录账号，例如 `alice` 或 `yfx`，它的 `$HOME` 通常是 `/home/<用户名>`。所以这条命令同时适用于 root 用户和普通用户：

```bash
export CODEX_HOME="$HOME/.codex"
```

`CODEX_HOME` 必须留在服务器本地文件系统上，不能整体放到共享盘。共享盘只用于保存持久化数据。

## 1. 启动 Mac 反向代理

如果远端服务器不能直接访问外网，可以在 Mac 上先准备一个本地 HTTP 代理，再通过 SSH 反向转发到服务器的 `127.0.0.1:18080`。

如果 Mac 可以直连国外网络，可以用 `tinyproxy` 在 Mac 上启动一个本地 HTTP 代理：

```bash
brew install tinyproxy
sudo tinyproxy
```

确认 `tinyproxy` 监听成功：

```bash
sudo lsof -nP -iTCP:8888 -sTCP:LISTEN
```

看到类似下面的输出即可：

```text
tinyproxy ... TCP *:8888 (LISTEN)
```

如果 Mac 也不能直连国外网络，可以使用 Clash 等代理工具。先查看 Clash 的 HTTP 代理端口，例如 `7897`，然后把下面命令里的 `8888` 替换成 Clash 的代理端口。

在 Mac 终端运行：

```bash
ssh -p <ssh-port> \
  -i /path/to/private-key.pem \
  -N \
  -R 18080:127.0.0.1:8888 \
  <user>@<ssh-host>
```

保持这个 SSH 进程运行。然后在服务器终端检查代理是否可用：

```bash
curl -x http://127.0.0.1:18080 https://www.google.com
```

如果这个命令能返回网页内容，说明服务器可以通过 Mac 的反向代理访问外网。`download.sh` 和 `wrapper.sh` 默认都会使用 `http://127.0.0.1:18080`。

## 2. 初始化服务器

在服务器 clone 仓库：

```bash
export HTTP_PROXY=http://127.0.0.1:18080
export HTTPS_PROXY=http://127.0.0.1:18080
export ALL_PROXY=http://127.0.0.1:18080
git clone https://github.com/fx-hit/codex-server-setup.git
cd codex-server-setup
```

如果服务器能直连 GitHub SSH，也可以改用：

```bash
git clone git@github.com:fx-hit/codex-server-setup.git
cd codex-server-setup
```

一键初始化：

```bash
export PERSISTENT_CODEX_HOME=/path/to/persistent/.codex
bash setup.sh "$PERSISTENT_CODEX_HOME"
```

`setup.sh` 会按顺序执行：

1. `download.sh`: 下载最新 Codex Linux 二进制并安装到 `$HOME/.local/bin/codex`
2. `wrapper.sh`: 把原始二进制保存为 `$HOME/.local/bin/codex-real`，并创建带代理环境变量的 `$HOME/.local/bin/codex`
3. `link.sh`: 配置 `$CODEX_HOME`，让历史/配置保存在持久盘，同时让 `app-server-control` 保持本地真实目录

也可以手动分步执行：

```bash
bash download.sh
bash wrapper.sh
export PERSISTENT_CODEX_HOME=/path/to/persistent/.codex
bash link.sh "$PERSISTENT_CODEX_HOME"
```

### 服务器重启后的恢复顺序

如果服务器重启后 `CODEX_HOME` 所在的本地目录会被清空，需要先恢复 `$CODEX_HOME` 的软链接结构，再启动 Codex CLI、VS Code Codex 插件或 Codex Desktop SSH：

```bash
export CODEX_HOME="$HOME/.codex"
export PERSISTENT_CODEX_HOME=/path/to/persistent/.codex
bash /path/to/codex-server-setup/link.sh "$PERSISTENT_CODEX_HOME"
```

如果重启后已经先运行过 `codex`、VS Code Codex 插件或 Codex Desktop SSH，Codex 可能已经在本地重新生成了一套 `$CODEX_HOME` 缓存。此时状态会分叉：旧登录和历史还在持久目录，新缓存却写在本地 `$CODEX_HOME`。

如果确认这套误生成的本地缓存不需要保留，可以先删除它，再重新链接：

```bash
rm -rf "$CODEX_HOME"
bash /path/to/codex-server-setup/link.sh "$PERSISTENT_CODEX_HOME"
```

如果不确定里面是否有新会话或新配置，先备份再重新链接：

```bash
mv "$CODEX_HOME" "${CODEX_HOME}.local-cache.$(date +%Y%m%d%H%M%S)"
bash /path/to/codex-server-setup/link.sh "$PERSISTENT_CODEX_HOME"
```

## 3. 验证服务器状态

检查 Codex 是否安装成功：

```bash
export PATH="$HOME/.local/bin:$PATH"
codex --version
```

新用户在服务器终端登录 Codex：

```bash
codex login
codex login status
```

因为第 2 步已经执行过 `link.sh`，`$CODEX_HOME/auth.json`、`$CODEX_HOME/config.toml`、`$CODEX_HOME/history.jsonl` 和会话目录都已经指向持久目录。登录产生的认证缓存会通过这些软链接写到 `$PERSISTENT_CODEX_HOME`。

登录后可以检查认证文件是否仍然指向持久目录：

```bash
ls -la "$CODEX_HOME/auth.json"
ls -la "$PERSISTENT_CODEX_HOME/auth.json"
```

检查 `$CODEX_HOME/app-server-control` 是否在本地文件系统上，并且不是软链接：

```bash
stat -f -c '%T %n' "$CODEX_HOME" "$CODEX_HOME/app-server-control"
ls -la "$CODEX_HOME/app-server-control"
```

期望 `$CODEX_HOME` 和 `$CODEX_HOME/app-server-control` 都在本地文件系统上，例如 `overlayfs`；`app-server-control` 应该是目录，不是软链接。

## 4. 配置 VS Code Remote 代理

如果要在远端服务器的 VS Code 里使用 Codex 插件，需要在 VS Code 的远端设置里配置代理：

1. 打开远端窗口的 Settings。
2. 切到 `Remote [SSH: <host>]` 作用域。
3. 找到 `Application > Proxy`。
4. 将 `Http: Proxy` 设置为：

   ```text
   http://127.0.0.1:18080
   ```

5. 在同一页的 `Http: No Proxy` 处填入本机地址，让 VS Code 访问远端本机服务时不要走代理：

   ```text
   127.0.0.1,localhost,::1
   ```

## 5. 配置 Codex Desktop SSH

可以在 Mac 的 `~/.ssh/config` 里复制一份专门给 Codex Desktop 使用的 SSH Host alias，避免影响原本给 VS Code 使用的连接配置。

示例：

```sshconfig
Host my-remote
  HostName <ssh-host>
  User <user>
  Port <ssh-port>
  IdentityFile /path/to/private-key.pem

Host my-remote-codex
  HostName <ssh-host>
  User <user>
  Port <ssh-port>
  IdentityFile /path/to/private-key.pem
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

在 Codex Desktop 里选择 `my-remote-codex` 这个 host 连接远端项目。

## 脚本参数

`link.sh` 和 `setup.sh` 都支持把持久化目录作为第一个参数传入；也可以用 `PERSISTENT_CODEX_HOME` 环境变量传入。

```bash
PERSISTENT_CODEX_HOME=/path/to/persistent/.codex bash link.sh
```

常用环境变量：

```bash
CODEX_DOWNLOAD_PROXY=http://127.0.0.1:18080
CODEX_INSTALL_DIR="$HOME/.local/bin"
PERSISTENT_CODEX_HOME=/path/to/persistent/.codex
```

`download.sh` 默认安装到官方安装脚本使用的用户级目录 `$HOME/.local/bin/codex`。如果当前 shell 的 `PATH` 里还没有 `$HOME/.local/bin`，先临时加入：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

也可以显式指定安装位置：

```bash
CODEX_INSTALL_PATH=/usr/local/bin/codex bash download.sh
CODEX_BIN=/usr/local/bin/codex CODEX_REAL=/usr/local/bin/codex-real bash wrapper.sh
```

`CODEX_HOME` 通常直接使用当前登录用户的 home 目录：

```bash
CODEX_HOME="$HOME/.codex"
```

也可以在同一条命令里临时指定本地 Codex 目录和共享盘持久目录：

```bash
CODEX_HOME="$HOME/.codex" bash link.sh /path/to/persistent/.codex
```

如果也要用 `setup.sh` 一键初始化：

```bash
CODEX_HOME="$HOME/.codex" bash setup.sh /path/to/persistent/.codex
```

## 目录结构

`link.sh` 配置完成后的结构：

```text
$CODEX_HOME                         本地真实目录
$CODEX_HOME/app-server-control      本地真实目录，用于 socket
$CODEX_HOME/auth.json               软链接到持久盘
$CODEX_HOME/sessions                软链接到持久盘
$CODEX_HOME/*.sqlite                软链接到持久盘
```

对于完全从零开始的新用户，`link.sh` 会在持久目录为空时预置这些常见路径：

```text
auth.json
config.toml
history.jsonl
installation_id
models_cache.json
session_index.jsonl
goals_1.sqlite*
logs_2.sqlite*
memories_1.sqlite*
state_5.sqlite*
sessions/
attachments/
plugins/
skills/
cache/
```

如果 Codex 后续版本新增了其他本地文件，重新运行一次 `link.sh "$PERSISTENT_CODEX_HOME"` 会把非 runtime 的本地文件迁移到持久目录并建立软链接。

## 排障

### 为什么 link.sh 不直接软链接整个 CODEX_HOME

Codex Desktop SSH 会在 `$CODEX_HOME/app-server-control` 下创建 Unix domain socket。当前持久盘可能是 FUSE/网络文件系统，不支持 socket 文件，所以不能把整个 `CODEX_HOME` 软链接过去。

实际遇到的服务器端日志：

```text
WARNING: failed to clean up stale arg0 temp dirs: Directory not empty (os error 39)
Error: Not supported (os error 95)
```

如果把 `app-server-control` 本身做成软链接，Codex 还会报。下面以 root 用户的 `/root/.codex` 为例：

```text
WARNING: failed to clean up stale arg0 temp dirs: Directory not empty (os error 39)
Error: socket directory path exists and is not a directory: /root/.codex/app-server-control
```

`link.sh` 的做法是让 `$CODEX_HOME` 和 `$CODEX_HOME/app-server-control` 保持本地真实目录，只把历史、登录、配置和数据库文件软链接到持久盘。这样既能保留历史记录，又能让 Codex Desktop SSH 正常创建 app-server socket。

### Mac Desktop 日志

Mac 桌面端对应的日志现象是 SSH 已经认证成功，但连接远端 app-server socket 失败。

在 Mac 上可以用下面的命令过滤最近 5 分钟的 Codex Desktop 日志：

```bash
LOGDIR="$HOME/Library/Logs/com.openai.codex"

find "$LOGDIR" -type f -mmin -5 -print0 \
  | xargs -0 grep -nEi \
  'proxy_command_failed|failed to connect to socket|desktop-ssh-websocket|1006|socket hang up' \
  2>/dev/null
```

典型日志：

```text
Authenticated to <ssh-host> using "publickey".
Sending command: ... codex app-server proxy --sock "${CODEX_HOME:-$HOME/.codex}/app-server-control/desktop-ssh-websocket-v0.sock"
Error: failed to connect to socket at /root/.codex/app-server-control/desktop-ssh-websocket-v0.sock

Caused by:
    No such file or directory (os error 2)
Codex app-server websocket closed (code=1006)
```
