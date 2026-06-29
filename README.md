# AI Coding CLI 离线服务器配置

本仓库包含两套离线服务器配置脚本，解决远端服务器上安装和使用 AI 编程 CLI 的常见问题：

- **Codex CLI**（OpenAI）— 服务器端安装、持久化配置、Codex Desktop SSH 支持
- **Claude Code CLI**（Anthropic）— 服务器端安装、第三方 Anthropic-compatible API 配置

两者都支持通过 Mac 反向代理让离线服务器访问外网。

---

## Codex CLI 配置

在远端服务器上安装 Codex CLI，把历史、登录、会话等数据保存到持久盘，同时保留 `app-server-control` socket 目录在本地文件系统上，确保 Codex Desktop SSH 连接正常。

**适用场景：**

- 服务器重启后 home 目录被清空，需要保留 Codex 登录和历史
- 服务器不能直连外网，需要通过 Mac SSH 反向代理访问
- Mac Codex Desktop 通过 SSH 连接远端项目

→ **[Codex 完整配置文档](CODE_SETUP.md)**

```bash
# 一键初始化
export PERSISTENT_CODEX_HOME=/path/to/persistent/.codex
bash codex/setup.sh "$PERSISTENT_CODEX_HOME"
```

| 脚本 | 功能 |
|------|------|
| `codex/download.sh` | 下载 Codex Linux 二进制 |
| `codex/wrapper.sh` | 创建带代理的 `codex` wrapper |
| `codex/link.sh` | 配置持久化目录软链接 |
| `codex/setup.sh` | 一键执行以上三步 |

---

## Claude Code CLI 配置

在远端服务器上安装 Claude Code CLI，配置第三方 Anthropic-compatible API（如 DeepSeek、GLM / Z.ai），支持多 provider 切换。

**适用场景：**

- 服务器不能直连外网，通过代理访问第三方 API
- 使用 DeepSeek、GLM 等 Anthropic-compatible API 替代 Anthropic 官方 API
- 需要在多个 API provider 之间切换

→ **[Claude Code 完整配置文档](CLAUDE_SETUP.md)**

```bash
# 一键初始化
bash claude/setup.sh
```

| 脚本 | 功能 |
|------|------|
| `claude/download.sh` | 下载 Claude Code Linux 二进制，安装为 `claude-real` |
| `claude/wrapper.sh` | 创建带代理 + 密钥加载的 `claude` wrapper |
| `claude/setup.sh` | 一键执行以上两步 |

---

## 通用前置：Mac 反向代理

两套配置都依赖 Mac 端的 SSH 反向代理让服务器访问外网。

Mac 端启动代理（以 tinyproxy 为例）：

```bash
brew install tinyproxy
sudo tinyproxy            # 默认监听 127.0.0.1:8888
```

建立 SSH 反向隧道：

```bash
ssh -p <ssh-port> \
  -i /path/to/private-key.pem \
  -N \
  -R 18080:127.0.0.1:8888 \
  <user>@<ssh-host>
```

服务器端验证代理可用：

```bash
curl -x http://127.0.0.1:18080 https://www.google.com
```

## 最终目录结构

```
~/.local/bin/
├── codex              # Codex wrapper（代理 + exec codex-real）
├── codex-real         # Codex 原始二进制
├── claude             # Claude wrapper（代理 + provider.env + exec claude-real）
└── claude-real        # Claude Code 原始二进制

~/.claude/
├── provider.env       # 当前 API Key（软链接到 deepseek.env / glm.env 等）
├── settings.json      # ANTHROPIC_BASE_URL + 模型映射
├── deepseek.env       # DeepSeek API Key
└── glm.env            # GLM API Key

~/.codex/              # Codex 本地目录（部分软链接到持久盘）
```
