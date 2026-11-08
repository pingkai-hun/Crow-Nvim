# AI 配置

> 适用版本：**CrowNvim Beta0.1.2**
> 本配置的 AI 能力分为两类：**本机 Ollama（完全离线）** 和 **GitHub Copilot（可选，联网）**。

---

## 目录

- [1. 总览](#1-总览)
- [2. 安装 Ollama 与模型](#2-安装-ollama-与模型)
- [3. 行内补全：minuet-ai](#3-行内补全minuet-ai)
- [4. 对话与改写：CodeCompanion](#4-对话与改写codecompanion)
- [5. 解释 / 审查 / 提问：crow.ai](#5-解释--审查--提问crowai)
- [6. 文档翻译：crow.translate](#6-文档翻译crowtranslate)
- [7. GitHub Copilot（可选）](#7-github-copilot可选)
- [8. 模型选择与性能](#8-模型选择与性能)
- [9. 隐私说明](#9-隐私说明)
- [10. 排错](#10-排错)

---

## 1. 总览

| 能力 | 模块 | 模型 | 触发 |
|---|---|---|---|
| 行内幽灵补全 | `minuet-ai.nvim` | `qwen2.5-coder:1.5b` | 插入模式自动 |
| 对话 / 内联改写 | `codecompanion.nvim` | `qwen2.5-coder:1.5b` | `<leader>oc` / `ov` / `oe`，或命令 |
| 代码解释 | `crow.ai` | `qwen2.5-coder:3b` | `<leader>oa` / `:CrowExplain` |
| 代码审查 | `crow.ai` | `qwen2.5-coder:3b` | `<leader>or` / `:CrowReview` |
| 带上下文提问 | `crow.ai` | `qwen2.5-coder:3b` | `<leader>oq` / `:CrowAsk` |
| 悬浮文档翻译 | `crow.translate` + Noice | `qwen2.5-coder:3b` | 自动 |
| 补全文档翻译 | `crow.translate` + blink | `qwen2.5-coder:3b` | 自动 |
| Copilot 对话 | `CopilotChat.nvim` | GitHub Copilot | `<leader>aa` 等 |

设计思路：

- **1.5B 负责「快」**：补全、对话，要求低延迟；
- **3B 负责「准」**：解释、审查、翻译，要求质量；
- 两套模型可以同时拉取，Ollama 会按需加载，空闲时释放显存。

---

## 2. 安装 Ollama 与模型

### 安装

```bash
# Arch
sudo pacman -S --needed ollama

# 官方脚本
curl -fsSL https://ollama.com/install.sh | sh
```

### 启动

```bash
# 用户级服务（推荐）
systemctl --user enable --now ollama

# 或前台
ollama serve
```

默认监听 `http://127.0.0.1:11434`。

### 拉取模型

```bash
ollama pull qwen2.5-coder:1.5b
ollama pull qwen2.5-coder:3b
```

### 验证

```bash
curl -s http://127.0.0.1:11434/api/tags | head
```

Neovim 内：

```vim
:CrowAiStats
```

Dashboard 也会探测并显示在线状态。

---

## 3. 行内补全：minuet-ai

配置：`lua/plugins/minuet.lua`

### 触发条件

- 只在 `InsertEnter` 后加载；
- 只在代码类 filetype 自动触发：Go、Python、Lua、Rust、C/C++、JS/TS、Java、Shell、Vim、JSON、YAML、HTML、CSS、Vue、Svelte、SQL 等；
- Markdown、text、gitcommit、help、quickfix 不打扰；
- 停止输入约 400ms 后请求，最小请求间隔 400ms，超时 3s。

### 键位

| 键位 | 作用 |
|---|---|
| `<M-l>`（Alt+L） | 接受整条建议 |
| `<M-j>`（Alt+J） | 只接受当前行 |
| `<M-]>` | 下一条建议 |
| `<M-[>` | 上一条建议 |
| `<C-]>` | 忽略当前建议 |

刻意避开 `<Tab>`，因为 `<Tab>` 归 `blink.cmp` 管。

### 参数

```lua
n_completions = 1      -- 本地模型只请求 1 条，省算力
context_window = 2048  -- 上下文窗口
request_timeout = 3    -- 秒
throttle = 400         -- 最小请求间隔（毫秒）
debounce = 400         -- 停止输入后等待（毫秒）
max_tokens = 128       -- 单次补全上限
```

觉得补全太频繁 / 太慢，优先调 `debounce` 和 `throttle`。

### 与 Copilot 的关系

Copilot 的行内补全默认关闭：

```lua
-- lua/plugins/copilot.lua
suggestion = { enabled = false, auto_trigger = false },
```

否则两套幽灵文本会重叠。想切回 Copilot：

1. 把 `suggestion.enabled` 改为 `true`；
2. 把 `lua/plugins/minuet.lua` 改为 `enabled = false` 或删除该 spec；
3. `:Lazy sync`。

---

## 4. 对话与改写：CodeCompanion

配置：`lua/plugins/codecompanion.lua`

### 命令

| 命令 | 作用 |
|---|---|
| `:CodeCompanionChat` | 打开对话窗口 |
| `:CodeCompanionChat Toggle` | 打开 / 关闭对话窗口 |
| `:CodeCompanionActions` | 动作面板 |
| `:CodeCompanion <prompt>` | 对当前选区 / 缓冲区执行内联改写 |
| `:CodeCompanionCodeReview` | 代码审查 |

### 键位

| 键位 | 作用 |
|---|---|
| `<leader>oc` | 打开 / 关闭对话 |
| `<leader>ov` | 动作面板 |
| `<leader>oe` | 改写选区（可视模式选中后按） |

### 模型

默认使用 Ollama 的 `qwen2.5-coder:1.5b`：

```lua
adapter = { name = "ollama", model = "qwen2.5-coder:1.5b" },
```

想换成 3B 或其他模型，改这里即可。CodeCompanion 的上下文窗口、压缩阈值也在同一文件里：

```lua
editing = { trigger = 6000 },
compaction = { trigger = 8000 },
```

### 与 crow.ai 的分工

- `<leader>oc` / `ov` / `oe` → CodeCompanion，适合**对话式、多轮、带编辑**；
- `<leader>oa` / `or` / `oq` → crow.ai，适合**一次性分析**，结果在浮窗里，按 `q` 关闭。

---

## 5. 解释 / 审查 / 提问：crow.ai

配置：`lua/crow/ai.lua`

### 命令

| 命令 | 作用 |
|---|---|
| `:CrowExplain` | 解释当前函数 / 可视选区 / 光标所在代码块 |
| `:CrowReview` | 审查代码，按严重程度列问题 |
| `:CrowAsk <问题>` | 带文件上下文提问 |
| `:CrowAiStats` | 查看模型和服务状态 |
| `:CrowAiStop` | 中断当前请求 |

### 键位

| 键位 | 作用 |
|---|---|
| `<leader>oa` | 解释当前函数（普通模式）/ 选区（可视模式） |
| `<leader>or` | 审查当前函数 / 选区 |
| `<leader>oq` | 带上下文提问 |
| `<leader>oi` | AI 状态 |

### 行为

- 调用 Ollama 的 `/api/chat`，流式输出；
- 结果写入可复用的浮窗，`q` 关闭；
- 普通模式下用 Treesitter 找外层函数 / 类；找不到就取整个文件（最多 200 行）；
- 可视模式下只分析选区；
- 参数：

```lua
temperature = 0.2   -- 分析类任务要稳定
num_ctx = 8192      -- 上下文
num_predict = 1024  -- 单次回答上限
```

- 失败时给出明确原因：服务没起、模型没拉、超时，不会静默。

### 提示词

系统提示要求：

- 简体中文；
- 结论先行；
- 不客套、不重复代码全文；
- 代码片段最小必要。

3B 模型的指令遵循能力有限，提示越短越明确越好。不要在这里堆很长的规则。

---

## 6. 文档翻译：crow.translate

配置：`lua/crow/translate.lua`

### 用途

- `lua/plugins/hover-translate.lua`：把 Noice 的 LSP 悬浮文档翻译成中文；
- `lua/plugins/blink.lua`：把补全菜单里的文档翻译成中文。

### 行为

- 调用 Ollama `/api/generate`，流式 NDJSON；
- 先显示英文原文，翻译完成后原地替换，**不阻塞输入**；
- 同一段文本只翻译一次（sha256 缓存）；
- 串行队列，只翻译「当前最新」的请求，过期请求直接丢弃；
- 只翻译自然语言：已经是中文、纯代码、超过 8000 字符的文本跳过。

### 提示词约束

- 只翻译自然语言说明；
- 代码、函数名、参数名、类型名、路径、URL、代码块原样保留；
- 保留 Markdown 结构；
- 不输出解释、前缀、后缀。

### 调整

模型和地址在文件顶部：

```lua
M.model = vim.g.crow_translate_model or "qwen2.5-coder:3b"
M.url = vim.g.crow_translate_url or "http://127.0.0.1:11434/api/generate"
M.max_chars = 8000
```

可以提前在 `options.lua` 里设置：

```lua
vim.g.crow_translate_model = "qwen2.5-coder:1.5b"  -- 更快，但质量略低
```

### 关闭翻译

- 悬浮文档：删除或禁用 `lua/plugins/hover-translate.lua`；
- 补全文档：修改 `lua/plugins/blink.lua` 中调用 `crow.translate` 的部分。

---

## 7. GitHub Copilot（可选）

配置：`lua/plugins/copilot.lua`、`lua/plugins/copilot-chat.lua`

### 登录

```vim
:Copilot auth
```

按提示在浏览器完成授权。

### 行内补全

默认关闭，键位保留：

| 键位 | 作用 |
|---|---|
| `<M-l>` | 接受整条 |
| `<M-w>` | 接受一个词 |
| `<M-j>` | 接受一行 |
| `<M-]>` / `<M-[>` | 下一条 / 上一条 |
| `<C-]>` | 忽略 |

### CopilotChat

| 键位 | 作用 |
|---|---|
| `<leader>aa` | 打开 / 关闭对话 |
| `<leader>ax` | 清空对话 |
| `<leader>aq` | 快速提问 |
| `<leader>ap` | 预设 Prompt |
| `<C-s>` | 在对话窗口内提交（等同回车） |

### 隐私

Copilot 会把上下文发送到 GitHub / Microsoft 的服务器。涉及敏感代码时请关闭 Copilot，只使用本机 Ollama。

---

## 8. 模型选择与性能

| 模型 | 大小（约） | 适合 | 当前用途 |
|---|---|---|---|
| `qwen2.5-coder:1.5b` | ~1 GB | 低延迟补全、短对话 | minuet、CodeCompanion |
| `qwen2.5-coder:3b` | ~2 GB | 解释、审查、翻译 | crow.ai、translate |
| 7B / 14B | 4–9 GB | 更高质量 | 可按需替换 |

### 显存 / 内存

- Ollama 会按需加载模型；同时使用 1.5B 和 3B 时可能占用两份内存；
- 机器内存紧张时，可以统一用一个模型：

```lua
-- minuet.lua
model = "qwen2.5-coder:3b"
```

但补全延迟会明显上升。一般不建议。

### 想换模型

需要同时改：

1. `lua/plugins/minuet.lua` 的 `model`；
2. `lua/plugins/codecompanion.lua` 的 `adapter.model`；
3. `lua/crow/ai.lua` 的 `MODEL`；
4. `lua/crow/translate.lua` 的 `M.model`（或设置 `vim.g.crow_translate_model`）。

然后：

```bash
ollama pull <model>
```

### 查看状态

```vim
:CrowAiStats
```

或：

```bash
ollama ps
ollama list
```

---

## 9. 隐私说明

| 功能 | 数据去向 |
|---|---|
| minuet 行内补全 | 本机 Ollama，不出网 |
| CodeCompanion | 本机 Ollama，不出网 |
| crow.ai | 本机 Ollama，不出网 |
| crow.translate | 本机 Ollama，不出网 |
| Dashboard 探活 | 本机 `127.0.0.1:11434` |
| Copilot / CopilotChat | GitHub / Microsoft（联网） |

本配置不包含任何 API Key、Token 或云端模型密钥。Ollama 适配器里的 `"ollama"` 只是占位字符串，不是真实密钥。

如果你 fork 这份配置，请同样**不要把个人 Token、公司内网地址、私有模型地址提交到仓库**。

---

## 10. 排错

### `:CrowAiStats` 报连接失败

```bash
ollama serve
# 或
systemctl --user status ollama
```

确认端口：

```bash
curl http://127.0.0.1:11434/api/tags
```

### 模型不存在

```bash
ollama list
ollama pull qwen2.5-coder:1.5b
ollama pull qwen2.5-coder:3b
```

### 补全一直不出现

1. 确认是代码类 filetype；
2. 确认在插入模式；
3. 看 `:messages` 是否有 minuet 报错；
4. 确认 Ollama 在线；
5. 确认 `minuet.lua` 没有被别的 spec 覆盖。

### 翻译不出现

- 文档已经是中文：会跳过；
- 文本几乎是纯代码：会跳过；
- 超过 8000 字符：会跳过；
- Ollama 离线：会静默跳过或给出错误，检查 `:messages`。

### 回答很慢

- 3B 模型首次加载需要时间；
- 降低 `num_ctx` / `num_predict`；
- 关闭其他占用显存的程序；
- 用 1.5B 替代 3B（质量会下降）。

### Copilot 没有反应

```vim
:Copilot auth
:Copilot status
```

确认订阅有效、网络可达。公司网络可能拦截 Copilot。
