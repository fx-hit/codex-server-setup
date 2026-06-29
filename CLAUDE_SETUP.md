# Claude Code CLI 离线服务器 + 第三方 API 通用配置

> ← [返回总览](README.md)

## 0. 前提

这里说的“离线服务器”通常是指服务器本身不能直连外网，但可以通过本机端口代理访问外部 API，例如：

```
http://127.0.0.1:18080
```

如果服务器完全不能访问外部 API，即使安装好了 Claude Code，也无法真正对话，只能把安装包离线拷进去。

第三方 API 必须兼容 Anthropic Messages API。比如 DeepSeek 提供 `https://api.deepseek.com/anthropic` 这种 Anthropic-compatible endpoint；GLM / Z.ai 也提供面向 Claude Code 的 Anthropic-compatible 配置方式。

## 1. 下载 Claude Code tar.gz

服务器能走代理时：

```bash
cd ~

export HTTP_PROXY=http://127.0.0.1:18080
export HTTPS_PROXY=http://127.0.0.1:18080
export http_proxy=http://127.0.0.1:18080
export https_proxy=http://127.0.0.1:18080

curl -LO https://github.com/anthropics/claude-code/releases/latest/download/claude-linux-x64.tar.gz
```

如果服务器无法下载，就在本地机器下载后传到服务器：

```bash
scp claude-linux-x64.tar.gz root@server:~
```

也可以使用仓库中的一键下载脚本：

```bash
bash claude/download.sh
```

## 2. 安装真实二进制为 claude-real

```bash
mkdir -p "$HOME/.local/bin"

tmpdir="$(mktemp -d)"
tar -xzf "$HOME/claude-linux-x64.tar.gz" -C "$tmpdir"

CLAUDE_EXE="$(find "$tmpdir" -maxdepth 5 -type f -name "claude" | head -n 1)"

if [ -z "$CLAUDE_EXE" ]; then
  echo "ERROR: did not find claude binary in tarball"
  find "$tmpdir" -maxdepth 5 -type f -print
  exit 1
fi

install -m 755 "$CLAUDE_EXE" "$HOME/.local/bin/claude-real"

rm -rf "$tmpdir"
```

验证：

```bash
"$HOME/.local/bin/claude-real" --version
```

## 3. 配置 PATH

```bash
export PATH="$HOME/.local/bin:$PATH"
```

写入 `.bashrc`：

```bash
grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
```

## 4. 创建通用密钥文件 provider.env

这个文件只保存当前 provider 的 API Key。

```bash
mkdir -p "$HOME/.claude"
chmod 700 "$HOME/.claude"

cat > "$HOME/.claude/provider.env" <<'EOF'
export ANTHROPIC_AUTH_TOKEN="sk-你的第三方API_KEY"
EOF

chmod 600 "$HOME/.claude/provider.env"
```

Claude Code 可以使用 `ANTHROPIC_AUTH_TOKEN` 作为认证 token；第三方 Anthropic-compatible API 一般也复用这个变量。

## 5. 创建 wrapper：~/.local/bin/claude

wrapper 只做稳定的启动工作：代理、NO_PROXY、读取密钥、执行真实 Claude Code。

```bash
cat > "$HOME/.local/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Remote server accesses internet through local reverse proxy.
export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:18080}"
export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:18080}"
export http_proxy="${http_proxy:-http://127.0.0.1:18080}"
export https_proxy="${https_proxy:-http://127.0.0.1:18080}"

# Keep localhost traffic out of proxy.
export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost,::1}"
export no_proxy="${no_proxy:-127.0.0.1,localhost,::1}"

# Avoid ALL_PROXY breaking localhost / internal tools.
unset ALL_PROXY
unset all_proxy

# Load current provider API key.
if [ -f "$HOME/.claude/provider.env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.claude/provider.env"
fi

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  echo "ERROR: ANTHROPIC_AUTH_TOKEN is not set." >&2
  echo "Please create $HOME/.claude/provider.env with:" >&2
  echo '  export ANTHROPIC_AUTH_TOKEN="sk-..."' >&2
  exit 1
fi

exec "$HOME/.local/bin/claude-real" "$@"
EOF

chmod +x "$HOME/.local/bin/claude"
```

检查：

```bash
which claude
ls -l "$HOME/.local/bin/claude" "$HOME/.local/bin/claude-real"
claude --version
```

也可以使用仓库中的 wrapper 脚本自动生成：

```bash
bash claude/wrapper.sh
```

## 6. 用 settings.json 配置第三方 API 和模型

### 通用模板

```bash
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://你的-anthropic-compatible-api-endpoint",

    "ANTHROPIC_MODEL": "你的主模型名",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "你的强模型名",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "你的主模型名",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "你的快模型名",
    "CLAUDE_CODE_SUBAGENT_MODEL": "你的快模型名",

    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_LOGIN_COMMAND": "1",
    "DISABLE_LOGOUT_COMMAND": "1",
    "DISABLE_UPGRADE_COMMAND": "1",
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  }
}
EOF
```

其中最关键的是：

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_BASE_URL` | 第三方 Anthropic-compatible API 地址 |
| `ANTHROPIC_AUTH_TOKEN` | 第三方 API Key，放在 `provider.env` |
| `ANTHROPIC_MODEL` | Claude Code 默认使用的模型 |

## 7. DeepSeek 示例

### provider.env

```bash
cat > "$HOME/.claude/provider.env" <<'EOF'
export ANTHROPIC_AUTH_TOKEN="sk-你的DeepSeekKey"
EOF

chmod 600 "$HOME/.claude/provider.env"
```

### settings.json

```bash
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",

    "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-flash",

    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_LOGIN_COMMAND": "1",
    "DISABLE_LOGOUT_COMMAND": "1",
    "DISABLE_UPGRADE_COMMAND": "1",
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  }
}
EOF
```

DeepSeek 官方文档给 Claude Code 的环境变量就是 `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic`、`ANTHROPIC_AUTH_TOKEN=<DeepSeek API Key>`，并映射 DeepSeek 模型名。

## 8. GLM / Z.ai 示例

如果使用 Z.ai / GLM 的 Claude Code 兼容接口，可以按它们文档给的 Anthropic-compatible endpoint 和模型名配置。Z.ai 文档给 Claude Code 的场景是使用 `https://api.z.ai/api/anthropic` 作为 Anthropic-compatible endpoint。

### provider.env

```bash
cat > "$HOME/.claude/provider.env" <<'EOF'
export ANTHROPIC_AUTH_TOKEN="你的GLM或ZAI_KEY"
EOF

chmod 600 "$HOME/.claude/provider.env"
```

### settings.json 示例

```bash
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",

    "ANTHROPIC_MODEL": "GLM-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "GLM-4.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "GLM-4.7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "GLM-4.5-Air",
    "CLAUDE_CODE_SUBAGENT_MODEL": "GLM-4.5-Air",

    "API_TIMEOUT_MS": "3000000",

    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_LOGIN_COMMAND": "1",
    "DISABLE_LOGOUT_COMMAND": "1",
    "DISABLE_UPGRADE_COMMAND": "1",
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  }
}
EOF
```

> **注意：** 如果你用的是智谱开放平台而不是 Z.ai 平台，需要以你账号对应文档中的 Anthropic-compatible base URL 和模型名为准。

## 9. 启动使用

```bash
cd /path/to/your/project
claude
```

不要 `/login`。如果第三方 API 配置正确，Claude Code 会直接用 `ANTHROPIC_AUTH_TOKEN` 走第三方 API。

也可以临时换模型：

```bash
ANTHROPIC_MODEL=deepseek-v4-flash claude
```

或者改 `~/.claude/settings.json` 后重新启动 `claude`。

## 10. 推荐的 provider 切换方式

你可以分别保存多个 provider key：

```
~/.claude/deepseek.env
~/.claude/glm.env
~/.claude/company_gateway.env
```

然后用软链接切换：

```bash
ln -sf "$HOME/.claude/deepseek.env" "$HOME/.claude/provider.env"
```

切到 GLM：

```bash
ln -sf "$HOME/.claude/glm.env" "$HOME/.claude/provider.env"
```

同时修改：

```bash
vim "$HOME/.claude/settings.json"
```

只要改两处：

- `provider.env` — 当前 API Key
- `settings.json` — 当前 base_url 和模型名

## 11. 常见报错

### Not logged in · Please run /login

通常是 wrapper 没读到 `ANTHROPIC_AUTH_TOKEN`。

检查：

```bash
ls -l "$HOME/.claude/provider.env"
cat "$HOME/.local/bin/claude" | grep provider.env
```

不要打印完整 key，可以这样检查：

```bash
source "$HOME/.claude/provider.env"

python - <<'PY'
import os
v = os.environ.get("ANTHROPIC_AUTH_TOKEN", "")
print("HAS_TOKEN =", bool(v))
print("TOKEN_PREFIX =", v[:6] + "..." if v else "")
PY
```

### claude-real: No such file or directory

说明只写了 wrapper，没有安装真实二进制：

```bash
ls -l "$HOME/.local/bin/claude-real"
```

重新执行安装真实二进制那一步（见第 2 节）。

### which claude 不是 $HOME/.local/bin/claude

PATH 顺序不对：

```bash
export PATH="$HOME/.local/bin:$PATH"
which claude
```

### 请求超时或连接失败

先测代理：

```bash
curl -v -x http://127.0.0.1:18080 https://api.deepseek.com
```

或者替换为当前 provider 的 API 域名。

## 最终推荐结构

```
~/.local/bin/claude
  只做：
  - 设置 HTTP_PROXY / HTTPS_PROXY
  - 设置 NO_PROXY
  - unset ALL_PROXY
  - source ~/.claude/provider.env
  - exec ~/.local/bin/claude-real

~/.claude/provider.env
  只放：
  - ANTHROPIC_AUTH_TOKEN

~/.claude/settings.json
  只放：
  - ANTHROPIC_BASE_URL
  - ANTHROPIC_MODEL
  - OPUS / SONNET / HAIKU 映射
  - 关闭登录、升级、遥测等非必要功能
```

## 仓库脚本说明

本仓库 `claude/` 目录提供了与上述步骤对应的自动化脚本：

| 脚本 | 功能 |
|------|------|
| `claude/download.sh` | 下载 Claude Code Linux 二进制并安装为 `~/.local/bin/claude-real` |
| `claude/wrapper.sh` | 创建带代理、密钥加载的 `~/.local/bin/claude` wrapper |
| `claude/setup.sh` | 一键执行 download + wrapper |

### 一键初始化

```bash
# 进入仓库目录
cd codex_script

# 设置代理后一键安装
export HTTP_PROXY=http://127.0.0.1:18080
export HTTPS_PROXY=http://127.0.0.1:18080
bash claude/setup.sh
```

### 手动分步执行

```bash
bash claude/download.sh
bash claude/wrapper.sh
```

然后手动创建 `~/.claude/provider.env` 和 `~/.claude/settings.json`，参见上文第 4–8 节。
