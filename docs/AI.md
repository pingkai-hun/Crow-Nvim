# AI 配置

> 适用版本：**CrowNvim v1.0.0**
>
> 默认架构：**云端模型负责对话 / 解释 / 审查 / 翻译，本机 Ollama 负责行内补全**。
> 没有云端 Key 时会自动回退本机 Ollama，配置不会开箱即坏。

---

## 目录

- [1. 总览](#1-总览)
- [2. 快速开始：配置云端 Key](#2-快速开始配置云端-key)
- [3. 模型注册表与切换](#3-模型注册表与切换)
- [4. 行内补全：minuet-ai](#4-行内补全minuet-ai)
- [5. 对话与改写：CodeCompanion](#5-对话与改写codecompanion)
- [6. 解释 / 审查 / 提问：crow.ai](#6-解释--审查--提问crowai)
- [7. 文档翻译：crow.translate](#7-文档翻译crowtranslate)
- [8. 功能开关](#8-功能开关)
- [9. 支持哪些供应商](#9-支持哪些供应商)
- [10. 自定义供应商 / 模型](#10-自定义供应商--模型)
- [11. GitHub Copilot（可选）](#11-github-copilot可选)
- [12. 隐私说明](#12-隐私说明)
- [13. 排错](#13-排错)

---

## 1. 总览

| 能力 | 模块 | 默认模型 | 触发 |
|---|---|---|---|
| 行内幽灵补全 | `minuet-ai.nvim` | 本机 `qwen2.5-coder:1.5b` | 插入模式自动 |
| 对话 / 内联改写 | `codecompanion.nvim` | 全局模型（OpenCode / Kimi K2.6） | `<leader>oc` / `ov` / `oe`，或命令 |
| 结构化审查 | `codecompanion.nvim` | 全局模型 | `<leader>oR` |
| 代码解释 | `crow.ai` | 全局模型（OpenCode / Claude Sonnet 5.5） | `<leader>oa` / `:CrowExplain` |
| 代码审查 | `crow.ai` | 全局模型 | `<leader>or` / `:CrowReview` |
| 带上下文提问 | `crow.ai` | 全局模型 | `<leader>oq` / `:CrowAsk` |
| 悬浮文档翻译 | `crow.translate` + Noice | 全局模型 | 自动 |
| 补全文档翻译 | `crow.translate` + blink | 全局模型 | 自动 |
| Copilot 对话 | `CopilotChat.nvim` | GitHub Copilot | `<leader>aa` 等 |

设计要点：

- **补全要快**：始终用本机小模型，稳定低延迟，且不消耗云端额度；
- **质量任务上云**：解释、审查、翻译使用云端大模型；
- **一键切换**：`<leader>om` 循环可用模型，`<leader>oM` 打开面板；
- **分层回退**：无 Key → 本机；本机也没起 → 明确报错，不静默失败。

所有 AI 请求都经过 `lua/crow/llm.lua`，统一处理：

- OpenAI 兼容 SSE（`data: {...}` / `[DONE]`）；
- Ollama NDJSON（每行一个 JSON）；
- 取消、超时、HTTP 错误、模型返回 `error`、空回复。

---

## 2. 快速开始：配置云端 Key

默认供应商是 **OpenCode 聚合平台**。任选一种方式提供 Key，优先级从高到低：

1. `vim.g.crow_api_keys`
2. 环境变量
3. `lua/crow/secrets.lua`（已 gitignore）
4. 供应商配置里的 `api_key`（只用于本地服务）

### 方式 A：环境变量（推荐）

```bash
export OPENCODE_API_KEY="sk-..."
```

放进 `~/.zshrc` / `~/.bashrc` 后重启终端。Neovide 从桌面启动时可能读不到 shell 配置，见下面的方式 B。

### 方式 B：secrets.lua

```bash
cd ~/.config/nvim
cp lua/crow/secrets.example.lua lua/crow/secrets.lua
```

编辑 `lua/crow/secrets.lua`：

```lua
return {
  opencode = "sk-...",
  -- openrouter = "sk-or-...",
  -- dashscope  = "sk-...",
  -- deepseek   = "sk-...",
}
```

该文件已在 `.gitignore` 中，不会被提交。

### 方式 C：启动时写 `vim.g`

适合从配置里注入，或临时测试：

```lua
vim.g.crow_api_keys = {
  opencode = "sk-...",
}
```

### 验证

```vim
:CrowAiStats
```

会按角色列出供应商、模型、是否有 Key，并探测本机 Ollama 是否在线。

---

## 3. 模型注册表与切换

核心文件：`lua/crow/models.lua`

### 角色

| 角色 | 用途 |
|---|---|
| `chat` | CodeCompanion 对话、后台任务 |
| `inline` | CodeCompanion 行内改写 / Cmd |
| `analyze` | `crow.ai` 解释 / 审查 / 提问 |
| `translate` | 悬浮文档、补全文档翻译 |
| `complete` | minuet 行内补全 |

### 默认行为

- 第一次使用时，云角色自动选择**第一个已配置 Key 的供应商**；
- `complete` 永远优先本机 Ollama，不跟随全局切换；
- 选择结果保存在 `stdpath("state")/crow/models.json`，重启后保留；
- 只保存「用户显式选过」的项，没选过就一直跟随自动策略。

### 键位与命令

| 操作 | 作用 |
|---|---|
| `<leader>om` | 在**推荐模型**间循环切换（由每个供应商的 `cycle` 列表决定；只有 OpenCode + 本机时默认 9 项） |
| `<leader>oM` | 打开模型面板 |
| `:CrowModel next` | 同 `<leader>om` |
| `:CrowModel` / `:CrowModel global` | 打开全局模型面板 |
| `:CrowModel analyze` | 只给某个角色选模型 |
| `:CrowModel complete` | 给补全单独选模型（需重启） |

面板底部有「自定义模型 ID…」，可以直接输入供应商新增但配置里还没列出的模型。

### 覆盖与恢复

- 选择**全局模型**会清空各角色的单独覆盖；
- 给某个角色单独选模型会写入 override，其余角色仍跟随全局；
- 想恢复自动策略：删除 `stdpath("state")/crow/models.json` 中对应项，或重新选一次全局模型。

### 全局切换不会影响补全

这是刻意的：补全对延迟最敏感，默认固定本机 `qwen2.5-coder:1.5b`。
只有显式执行 `:CrowModel complete` 更换补全模型时才需要重启 Neovim。

---

## 4. 行内补全：minuet-ai

配置：`lua/plugins/minuet.lua`

### 触发条件

- 只在 `InsertEnter` 后加载；
- 只在代码类 filetype 自动触发：Go、Python、Lua、Rust、C/C++、JS/TS、Java、Shell、Vim、JSON、YAML、HTML、CSS、Vue、Svelte、SQL 等；
- Markdown、text、gitcommit、help、quickfix 不打扰；
- 本机模型：停止输入约 400ms 后请求，最小请求间隔 400ms，超时 3s；
- 云端模型（如果手动给 `complete` 选了云端）：debounce / throttle 放宽到 600ms，超时 8s。

### 键位

| 键位 | 作用 |
|---|---|
| `<M-l>`（Alt+L） | 接受整条建议 |
| `<M-j>`（Alt+J） | 只接受当前行 |
| `<M-]>` | 下一条建议 |
| `<M-[>` | 上一条建议 |
| `<C-]>` | 忽略当前建议 |

刻意避开 `<Tab>`，因为 `<Tab>` 归 `blink.cmp` 管。

### 本机模型安装

```bash
ollama serve
ollama pull qwen2.5-coder:1.5b
```

端点：`http://127.0.0.1:11434/v1/completions`（OpenAI FIM 兼容）。

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

## 5. 对话与改写：CodeCompanion

配置：`lua/plugins/codecompanion.lua`

### 命令

| 命令 | 作用 |
|---|---|
| `:CodeCompanionChat` | 打开对话窗口 |
| `:CodeCompanionChat Toggle` | 打开 / 关闭对话窗口 |
| `:CodeCompanionActions` | 动作面板 |
| `:CodeCompanion <prompt>` | 对当前选区 / 缓冲区执行内联改写 |
| `:CodeCompanionCodeReview` | 结构化审查，逐 hunk 接受 / 撤销 |
| `:CodeCompanionCmd` | 让模型生成 Neovim 命令行 |

### 键位

| 键位 | 作用 |
|---|---|
| `<leader>oc` | 打开 / 关闭对话 |
| `<leader>ov` | 动作面板 |
| `<leader>oe` | 改写选区（可视模式选中后按） |
| `<leader>oR` | 结构化审查 |

### 模型

CodeCompanion 里有两个适配器，按角色实时解析当前选择：

- `crow_chat` → `chat` 角色
- `crow_inline` → `inline` 角色

云端使用内置 `openai_compatible` 适配器；本机使用 `ollama` 适配器。
切换模型后，配置会重新 `setup`，新开的对话 / 改写立即使用新模型。

### 与 crow.ai 的分工

- `<leader>oc` / `ov` / `oe` / `oR` → CodeCompanion，适合**对话式、多轮、带编辑**；
- `<leader>oa` / `or` / `oq` → crow.ai，适合**一次性分析**，结果在浮窗里，按 `q` 关闭。

---

## 6. 解释 / 审查 / 提问：crow.ai

配置：`lua/crow/ai.lua`

### 命令

| 命令 | 作用 |
|---|---|
| `:CrowExplain` | 解释当前函数 / 可视选区 / 光标所在代码块 |
| `:CrowReview` | 审查代码，按严重程度列问题 |
| `:CrowAsk <问题>` | 带文件上下文提问 |
| `:CrowAiStats` | 查看每个角色的模型、供应商、Key 状态 |
| `:CrowAiStop` | 中断当前请求 |

### 键位

| 键位 | 作用 |
|---|---|
| `<leader>oa` | 解释当前函数（普通模式）/ 选区（可视模式） |
| `<leader>or` | 审查当前函数 / 选区 |
| `<leader>oq` | 带上下文提问 |
| `<leader>oi` | AI 状态 |

### 行为

- 通过 `crow.llm` 流式请求，结果写入可复用浮窗，`q` 关闭；
- 普通模式下用 Treesitter 找外层函数 / 类；找不到就取整个文件；
- 可视模式下只分析选区；
- 分析类默认 `temperature = 0.2`、`max_tokens = 1024`（只对支持 temperature 的供应商发送）；
- 本机请求额外限制 `num_ctx = 8192`；
- 失败时给出明确原因：缺 Key、服务没起、模型没拉、超时、网络或代理问题。

### 提示词

系统提示要求：

- 简体中文；
- 结论先行；
- 不客套、不重复代码全文；
- 代码片段最小必要。

---

## 7. 文档翻译：crow.translate

配置：`lua/crow/translate.lua`

### 用途

- `lua/plugins/hover-translate.lua`：把 Noice 的 LSP 悬浮文档翻译成中文；
- `lua/plugins/blink.lua`：把补全菜单里的文档翻译成中文。

### 行为

- 通过 `crow.llm` 流式请求，兼容云端 SSE 与本机 NDJSON；
- 先显示英文原文，翻译完成后原地替换，**不阻塞输入**；
- 同一段文本只翻译一次（sha256 缓存）；
- 串行队列，只翻译「当前最新」的请求，过期请求直接丢弃；
- 只翻译自然语言：已经是中文、纯代码、超过 8000 字符的文本跳过；
- 翻译失败时保持原文，不阻塞 UI，错误可在 `:messages` 查看。

### 提示词约束

- 只翻译自然语言说明；
- 代码、函数名、参数名、类型名、路径、URL、代码块原样保留；
- 保留 Markdown 结构；
- 不输出解释、前缀、后缀。

### 调整

- 首选：`:CrowModel translate` 单独给翻译选一个快模型；
- 兼容旧变量：`vim.g.crow_translate_model` 可以覆盖模型 ID，但供应商仍由注册表决定；
- `max_chars = 8000` 在 `lua/crow/translate.lua` 顶部。

### 关闭翻译

```bash
scripts/features.sh off translate
```

---

## 8. 功能开关

```bash
scripts/features.sh           # 交互菜单（数字切换，a 全开，z 全关，r 恢复默认，q 退出）
scripts/features.sh status    # 查看当前状态
scripts/features.sh list      # 列出所有开关
scripts/features.sh on  minuet codecompanion
scripts/features.sh off crow_ai
scripts/features.sh toggle translate
scripts/features.sh all-off
scripts/features.sh reset     # 恢复出厂默认
```

| 开关 | 出厂默认 | 关掉之后 |
|---|---|---|
| `minuet` | 开 | 不再出幽灵补全，`<Tab>` 退回 snippet / 缩进行为 |
| `codecompanion` | 开 | `:CodeCompanion*` 命令与 `oc / ov / oe / oR` 不再注册 |
| `crow_ai` | 开 | `:CrowExplain` 等命令与 `oa / or / oq / oi` 不再注册 |
| `translate` | 开 | 文档照常显示原文，只是不翻译（Noice / blink 本体不受影响） |
| `copilot_chat` | 开 | `CopilotChat.nvim` 整个不加载（行内补全仍由 `copilot.lua` 管理） |

开关写入 `lua/crow/features_user.lua`，该文件已加入 `.gitignore`，只影响本机；
它只记录「与出厂默认不同」的项，以后调整出厂默认值时没手改过的项会自动跟上。

> 改动需要**重启 Neovim** 才生效（插件 spec 只在启动时解析一次）。

---

## 9. 支持哪些供应商

内置注册表见 `lua/crow/models.lua`，面板里只显示**已配置 Key** 的云端供应商 + 所有本机服务。

| 供应商 | 环境变量 | 默认地址 |
|---|---|---|
| OpenCode（默认） | `OPENCODE_API_KEY` | `https://opencode.ai/inference/openai/v1` |
| OpenRouter | `OPENROUTER_API_KEY` | `https://openrouter.ai/api/v1` |
| 阿里云百炼 | `DASHSCOPE_API_KEY` | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| DeepSeek | `DEEPSEEK_API_KEY` | `https://api.deepseek.com` |
| Moonshot Kimi | `MOONSHOT_API_KEY` | `https://api.moonshot.ai/v1` |
| 智谱 GLM | `ZHIPUAI_API_KEY` | `https://open.bigmodel.cn/api/paas/v4` |
| 硅基流动 | `SILICONFLOW_API_KEY` | `https://api.siliconflow.cn/v1` |
| 本机 Ollama | 无 | `http://127.0.0.1:11434` |

不同供应商的模型 ID 不一样；面板里显示的是配置内置的候选，新增模型可以用「自定义模型 ID」。

> OpenCode 的模型清单与价格会更新，以 <https://opencode.ai/docs/zen/> 为准。

---

## 10. 自定义供应商 / 模型

复制模板：

```bash
cp lua/crow/models_user.example.lua lua/crow/models_user.lua
```

该文件已 gitignore。同名 provider 会**深度覆盖**内置配置，所以只写要改的字段即可。

### 例：给 OpenCode 追加新模型

```lua
return {
  providers = {
    opencode = {
      models = {
        { id = "kimi-k2.6", name = "Kimi K2.6" },
        { id = "brand-new-model", name = "新模型" },
      },
    },
  },
}
```

### 例：接入公司内网 / 自建 OpenAI 兼容网关

```lua
return {
  order = { "my_gateway", "opencode", "ollama" },
  providers = {
    my_gateway = {
      label = "公司网关",
      protocol = "openai",
      base_url = "https://llm.example.com/v1",
      env = "MY_GATEWAY_KEY",
      requires_key = true,
      defaults = {
        chat = "qwen3.7-plus",
        inline = "qwen3.7-plus",
        analyze = "qwen4-max",
        translate = "qwen3.8-flash",
      },
      models = {
        { id = "qwen4-max", name = "Qwen4 Max" },
        { id = "qwen3.7-plus", name = "Qwen3.7 Plus" },
      },
    },
  },
}
```

### 字段说明

| 字段 | 说明 |
|---|---|
| `protocol` | `openai`（SSE）或 `ollama`（NDJSON） |
| `base_url` | 不带结尾斜杠；OpenAI 兼容地址由代码拼 `/chat/completions` |
| `env` | 环境变量名 |
| `requires_key` | `false` 表示无需 Key（本地服务） |
| `headers` | 额外请求头，如 OpenRouter 的 Referer |
| `defaults` | 各角色的默认模型 |
| `models` | `{ id, name, ctx }` 列表 |
| `cycle` | `<leader>om` 循环时使用的模型 ID 列表；不写则循环该供应商全部模型 |
| `temperature_supported` | `true` 时才发送 `temperature` |

---

## 11. GitHub Copilot（可选）

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

---

## 12. 隐私说明

| 功能 | 数据去向 |
|---|---|
| minuet 行内补全 | 默认本机 Ollama，不出网 |
| CodeCompanion | 默认云端供应商（可切回本机） |
| crow.ai | 默认云端供应商（可切回本机） |
| crow.translate | 默认云端供应商（可切回本机） |
| Dashboard 探活 | 仅在补全使用本机时访问 `127.0.0.1:11434` |
| Copilot / CopilotChat | GitHub / Microsoft（联网） |

建议：

- 涉及敏感代码时，用 `:CrowModel` 切到本机 Ollama，或关闭对应功能；
- 不要把真实 Key、公司内网地址、私有模型地址提交到仓库；
- `secrets.lua`、`models_user.lua` 已加入 `.gitignore`。

---

## 13. 排错

### `:CrowAiStats` 显示缺 Key

```vim
:CrowModel global
```

选择本机 Ollama，或设置对应环境变量 / `secrets.lua`。确认变量名与供应商匹配：

```bash
echo $OPENCODE_API_KEY
```

### 提示「模型没有返回内容」

- 模型 ID 可能不存在：用 `:CrowModel` 面板里的「自定义模型 ID」核对；
- 供应商可能要求不同的接口：确认 `protocol = "openai"` 且 `base_url` 正确；
- 查看 `:messages` 里的 HTTP 错误详情。

### `curl 退出码` / 网络错误

- 检查代理、DNS 和 `base_url`；
- 公司网络可能拦截外网 API；
- 先用命令行验证：

```bash
curl -sS https://opencode.ai/inference/openai/v1/models \
  -H "Authorization: Bearer $OPENCODE_API_KEY" | head
```

### 补全一直不出现

1. 确认是代码类 filetype；
2. 确认在插入模式；
3. `:messages` 看 minuet 是否报错；
4. 确认 Ollama 在线，且 `qwen2.5-coder:1.5b` 已拉取；
5. 确认 `:CrowModel complete` 当前指向本机（补全默认不跟随全局）。

```bash
ollama list
ollama pull qwen2.5-coder:1.5b
```

### 翻译不出现

- 文档已经是中文；
- 文本几乎是纯代码；
- 超过 8000 字符；
- 云端缺 Key 且本机离线：检查 `:messages`。

### 回答很慢

- 云端：换更快的模型（`:CrowModel`），如 Gemini Flash / DeepSeek Flash / Kimi K2.7 Code；
- 本机：降低 `num_ctx` / `max_tokens`，或改用 1.5B；
- 关闭其他占用显存 / 内存的程序。

### Copilot 没有反应

```vim
:Copilot auth
:Copilot status
```

确认订阅有效、网络可达。公司网络可能拦截 Copilot。
