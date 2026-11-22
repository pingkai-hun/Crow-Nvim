-- ═══════════════════════════════════════════════════════════
-- crow.models —— 统一模型注册表 / 一键切换
-- ═══════════════════════════════════════════════════════════
--
-- 解决的问题：
--   以前 4 个 AI 功能各自硬编码 Ollama 模型：
--     minuet      行内补全
--     codecompanion 对话 / 改写
--     crow.ai     解释 / 审查 / 提问
--     translate   文档翻译
--   想换模型要改 4 个文件，且只能换本机 Ollama 模型。
--
-- 现在：
--   · 云能力默认由注册表按角色选模型；用 <leader>om 选定后所有云能力共用一个全局模型；
--   · 也可以给某个角色单独覆盖（chat / inline / analyze / translate）；
--   · 行内补全（complete）默认仍走本机 Ollama，保持低延迟；
--   · <leader>om  一键循环切换全局模型（立即生效，无需重启）
--   · <leader>oM  打开模型面板（按角色 / 全局 / 自定义 ID 选择）
--   · :CrowModel [角色|next] 命令行版本
--
-- API Key 读取顺序（先命中先用）：
--   1. vim.g.crow_api_keys = { opencode = "sk-..." }
--   2. <leader>oK / :CrowSetup 保存的本机密钥库（stdpath("state")/crow/keys.json）
--   3. 环境变量（见 provider.env，例如 OPENCODE_API_KEY）
--   4. lua/crow/secrets.lua（已 gitignore）
--   5. provider.api_key（仅本地服务）
--
-- 菜单式配置：
--   <leader>oK 或 :CrowSetup —— 选供应商 → 输入 Key → 选模型
--   输入 Key 时不会回显，保存到本机 state 目录（权限 0600），不会写进 dotfiles。
--
-- 自定义供应商 / 模型：
--   复制 lua/crow/models_user.example.lua 为 lua/crow/models_user.lua，
--   已加入 .gitignore，可安全写内网地址。

local M = {}

-- ─── 供应商注册表 ───────────────────────────────────────────
-- protocol:
--   "openai" —— OpenAI 兼容 /v1/chat/completions（SSE）
--   "ollama" —— Ollama 原生 /api/chat（NDJSON）
-- base_url 不要带结尾斜杠；OpenAI 的完整地址由 M.url() 拼。
--
-- models 里的字符串会自动包装成 { id = ... }。
-- defaults 决定该供应商在各角色下的默认模型。

M.providers = {
  -- ★ 默认：OpenCode Console 聚合平台
  opencode = {
    label = "OpenCode",
    protocol = "openai",
    base_url = "https://opencode.ai/inference/openai/v1",
    env = "OPENCODE_API_KEY",
    requires_key = true,
    defaults = {
      chat = "kimi-k2.6",
      inline = "kimi-k2.7-code",
      analyze = "claude-sonnet-5-5",
      translate = "gemini-3.8-flash",
      complete = "kimi-k2.7-code",
    },
    -- <leader>om 循环时只在这些模型之间切换（面板里仍能看到全部）
    cycle = {
      "kimi-k2.6",
      "claude-sonnet-5-5",
      "gpt-6.2-sol",
      "gemini-4-hydrogen",
      "deepseek-v4.1-flash",
      "qwen3.8-max",
      "glm-5.3",
    },
    models = {
      -- 编程 / 通用
      { id = "kimi-k2.6", name = "Kimi K2.6", ctx = 262144 },
      { id = "kimi-k2.7-code", name = "Kimi K2.7 Code", ctx = 262144 },
      { id = "kimi-k3", name = "Kimi K3", ctx = 1048576 },
      { id = "claude-sonnet-5-5", name = "Claude Sonnet 5.5", ctx = 1000000 },
      { id = "claude-haiku-5-5", name = "Claude Haiku 5.5", ctx = 200000 },
      { id = "claude-opus-5-5", name = "Claude Opus 5.5", ctx = 1000000 },
      { id = "gpt-6.2-sol", name = "GPT 6.2 Sol", ctx = 1050000 },
      { id = "gpt-6.2-astra", name = "GPT 6.2 Astra", ctx = 1050000 },
      { id = "gemini-4-hydrogen", name = "Gemini 4 Hydrogen", ctx = 1048576 },
      { id = "gemini-4-carbon", name = "Gemini 4 Carbon", ctx = 1048576 },
      { id = "gemini-3.8-flash", name = "Gemini 3.8 Flash", ctx = 1048576 },
      { id = "deepseek-v4.1-flash", name = "DeepSeek V4.1 Flash", ctx = 1048576 },
      { id = "deepseek-v4-pro", name = "DeepSeek V4 Pro", ctx = 1048576 },
      { id = "qwen3.8-max", name = "Qwen3.8 Max", ctx = 1000000 },
      { id = "glm-5.3", name = "GLM 5.3", ctx = 1000000 },
      { id = "glm-5.3-flash", name = "GLM 5.3 Flash", ctx = 1000000 },
      { id = "minimax-m3", name = "MiniMax M3", ctx = 1000000 },
      { id = "grok-4.7", name = "Grok 4.7", ctx = 200000 },
      { id = "mistral-large-4", name = "Mistral Large 4" },
      -- 免费 / 低成本（限时）
      { id = "deepseek-v4.1-flash-free", name = "DeepSeek V4.1 Flash (free)" },
      { id = "mimo-v2.6-flash-free", name = "MiMo V2.6 Flash (free)" },
      { id = "nemotron-3.5-lightning-free", name = "Nemotron 3.5 Lightning (free)" },
      { id = "big-pickle", name = "Big Pickle (free)" },
      { id = "iceman-free", name = "Iceman (free)" },
    },
  },

  -- AMD Radeon Cloud · Token Factory：OpenAI 兼容，Bearer API Key（rc- 开头）
  -- 官方文档：https://developer.amd.com.cn/radeon-cloud-docs
  --
  -- 模型 ID 必须一字不差（区分大小写），以 GET /v1/models 返回的 id 为准；
  -- 卡片标题和 name 字段都不能代替 ID。
  -- 平台的 reasoning_effort 支持情况不一致：Qwen3.8-27B 拒收 high、GLM-5.3-Flash 拒收 xhigh，
  -- 所以这里不设 reasoning_effort，降温只作用于标了 temperature_supported 的模型。
  amd = {
    label = "AMD Radeon Cloud",
    protocol = "openai",
    base_url = "https://developer.amd.com.cn/radeon/api/v1",
    env = "RADEON_API_KEY",
    requires_key = true,
    defaults = {
      chat = "DeepSeek-V4.1-Flash",
      inline = "DeepSeek-V4.1-Flash",
      analyze = "DeepSeek-V4.1-Flash",
      translate = "DeepSeek-V4-Flash",
    },
    cycle = { "DeepSeek-V4.1-Flash", "DeepSeek-V4-Flash", "Qwen3.8-27B", "GLM-5.3-Flash", "MiMo-V2.6-Flash" },
    models = {
      { id = "DeepSeek-V4.1-Flash", name = "DeepSeek V4.1 Flash", ctx = 1048576 },
      { id = "DeepSeek-V4-Flash", name = "DeepSeek V4 Flash", ctx = 1048576 },
      { id = "DeepSeek-V4-Flash-Vision-Exp", name = "DeepSeek V4 Flash Vision (exp)", ctx = 1048576 },
      { id = "Qwen3.8-27B", name = "Qwen3.8 27B", ctx = 262144 },
      { id = "GLM-5.3-Flash", name = "GLM 5.3 Flash", ctx = 262144 },
      { id = "MiMo-V2.6-Flash", name = "MiMo V2.6 Flash", ctx = 1048576 },
      { id = "Gemma-4-31B-IT", name = "Gemma 4 31B IT", ctx = 262144 },
      { id = "MiniCPM5-2B", name = "MiniCPM5 2B", ctx = 131072 },
      { id = "MiniCPM-V-4.7-1B", name = "MiniCPM-V 4.7 1B", ctx = 262144 },
      { id = "MiniCPM-V-4.7-35B-A3B", name = "MiniCPM-V 4.7 35B A3B", ctx = 262144 },
    },
  },

  -- NVIDIA NIM（build.nvidia.com）：OpenAI 兼容，API Key 以 nvapi- 开头
  -- 文档：https://docs.api.nvidia.com
  --
  -- 模型清单在 https://integrate.api.nvidia.com/v1/models 公开可读，可随时用「自定义模型 ID」添加新模型。
  -- 注意：embedding / rerank / guard / 视频检测类模型同样出现在列表里，它们不能用于 /chat/completions。
  nvidia = {
    label = "NVIDIA NIM",
    protocol = "openai",
    base_url = "https://integrate.api.nvidia.com/v1",
    env = "NVIDIA_API_KEY",
    requires_key = true,
    defaults = {
      chat = "moonshotai/kimi-k3.1-pro",
      inline = "nvidia/nemotron-3.5-lightning-30b-a3b",
      analyze = "nvidia/nemotron-3-ultra-550b-a55b",
      translate = "z-ai/glm-5.3-flash",
    },
    cycle = {
      "nvidia/nemotron-3.5-lightning-30b-a3b",
      "moonshotai/kimi-k3.1-pro",
      "nvidia/nemotron-3-ultra-550b-a55b",
      "mistralai/mistral-large-4-1t-a52b",
      "z-ai/glm-5.3-flash",
    },
    models = {
      { id = "nvidia/nemotron-3.5-lightning-30b-a3b", name = "Nemotron 3.5 Lightning 30B A3B" },
      { id = "nvidia/nemotron-3-ultra-550b-a55b", name = "Nemotron 3 Ultra 550B A55B" },
      { id = "nvidia/nemotron-3.5-bolt-e4b", name = "Nemotron 3.5 Bolt E4B" },
      { id = "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning", name = "Nemotron 3 Nano Omni 30B A3B" },
      { id = "moonshotai/kimi-k3.1-pro", name = "Kimi K3.1 Pro" },
      { id = "mistralai/mistral-large-4-1t-a52b", name = "Mistral Large 4 1T A52B" },
      { id = "z-ai/glm-5.3-flash", name = "GLM 5.3 Flash" },
      { id = "minimaxai/minimax-m3.1-flash", name = "MiniMax M3.1 Flash" },
      { id = "google/gemma-4-31b-it", name = "Gemma 4 31B IT" },
      { id = "bigcode/starcoder2-15b", name = "StarCoder2 15B" },
    },
  },

  -- Agnes AI：OpenAI 兼容；国内站主线路
  -- 国际站主线路：https://apihub.agnes-ai.com/v1
  -- 国际站备用线路：https://apihub.agnes-ai.cn/v1
  agnes = {
    label = "Agnes AI",
    protocol = "openai",
    base_url = "https://api.agnes-ai.cn/v1",
    env = "AGNES_API_KEY",
    requires_key = true,
    defaults = {
      chat = "agnes-3.0-flash",
      inline = "agnes-3.0-flash",
      analyze = "agnes-3.0-flash",
      translate = "agnes-3.0-flash",
    },
    cycle = { "agnes-3.0-flash", "agnes-2.5-flash", "agnes-2.5-pro", "agnes-3.0-pro" },
    models = {
      { id = "agnes-3.0-flash", name = "Agnes 3.0 Flash", ctx = 524288 },
      { id = "agnes-3.0-pro", name = "Agnes 3.0 Pro", ctx = 1048576 },
      { id = "agnes-2.5-flash", name = "Agnes 2.5 Flash", ctx = 524288 },
      { id = "agnes-2.5-pro", name = "Agnes 2.5 Pro", ctx = 1048576 },
      { id = "agnes-2.5-pro-theta", name = "Agnes 2.5 Pro Theta", ctx = 1048576 },
      { id = "agnes-2.0-flash", name = "Agnes 2.0 Flash (legacy)" },
    },
  },

  -- 本机 Ollama：补全默认仍在这里
  ollama = {
    label = "本机 Ollama",
    protocol = "ollama",
    base_url = "http://127.0.0.1:11434",
    requires_key = false,
    defaults = {
      chat = "qwen2.5-coder:3b",
      inline = "qwen2.5-coder:1.5b",
      analyze = "qwen2.5-coder:3b",
      translate = "qwen2.5-coder:3b",
      complete = "qwen2.5-coder:1.5b",
    },
    cycle = { "qwen2.5-coder:3b", "qwen2.5-coder:1.5b" },
    models = {
      { id = "qwen2.5-coder:3b", name = "Qwen2.5 Coder 3B", ctx = 32768 },
      { id = "qwen2.5-coder:1.5b", name = "Qwen2.5 Coder 1.5B", ctx = 32768 },
    },
  },

  -- 其他 OpenAI 兼容供应商（按需在面板里选；没有 Key 也能保留配置）
  openrouter = {
    label = "OpenRouter",
    protocol = "openai",
    base_url = "https://openrouter.ai/api/v1",
    env = "OPENROUTER_API_KEY",
    requires_key = true,
    headers = {
      ["HTTP-Referer"] = "https://github.com/crow-nvim",
      ["X-Title"] = "CrowNvim",
    },
    defaults = {
      chat = "anthropic/claude-sonnet-5.5",
      inline = "anthropic/claude-haiku-5.5",
      analyze = "anthropic/claude-sonnet-5.5",
      translate = "google/gemini-4-hydrogen",
    },
    cycle = {
      "anthropic/claude-sonnet-5.5",
      "openai/gpt-6.2-sol",
      "google/gemini-4-hydrogen",
      "deepseek/deepseek-v4.1-flash",
      "qwen/qwen4-max",
    },
    models = {
      { id = "anthropic/claude-sonnet-5.5", name = "Claude Sonnet 5.5" },
      { id = "anthropic/claude-fable-5.2", name = "Claude Fable 5.2" },
      { id = "openai/gpt-6.2-sol", name = "GPT 6.2 Sol" },
      { id = "google/gemini-4-hydrogen", name = "Gemini 4 Hydrogen" },
      { id = "google/gemini-4-neon", name = "Gemini 4 Neon" },
      { id = "qwen/qwen4-max", name = "Qwen4 Max" },
      { id = "deepseek/deepseek-v4.1-flash", name = "DeepSeek V4.1 Flash" },
      { id = "moonshotai/kimi-k3.1-pro", name = "Kimi K3.1 Pro" },
      { id = "z-ai/glm-5.3", name = "GLM 5.3" },
      { id = "minimax/minimax-m3", name = "MiniMax M3" },
    },
  },

  dashscope = {
    label = "阿里云百炼 (Qwen)",
    protocol = "openai",
    base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1",
    env = "DASHSCOPE_API_KEY",
    requires_key = true,
    defaults = {
      chat = "qwen3.7-plus",
      inline = "qwen3-coder-flash",
      analyze = "qwen4-max",
      translate = "qwen3.8-flash",
    },
    cycle = { "qwen4-max", "qwen3.7-plus", "qwen3.8-flash", "deepseek-v4.1-flash" },
    models = {
      { id = "qwen4-max", name = "Qwen4 Max" },
      { id = "qwen3.7-plus", name = "Qwen3.7 Plus" },
      { id = "qwen3.8-flash", name = "Qwen3.8 Flash" },
      { id = "qwen3-coder-flash", name = "Qwen3 Coder Flash" },
      { id = "deepseek-v4.1-flash", name = "DeepSeek V4.1 Flash" },
      { id = "kimi-k3.1-pro", name = "Kimi K3.1 Pro" },
      { id = "glm-5.3", name = "GLM 5.3" },
    },
  },

  deepseek = {
    label = "DeepSeek",
    protocol = "openai",
    base_url = "https://api.deepseek.com",
    env = "DEEPSEEK_API_KEY",
    requires_key = true,
    defaults = {
      chat = "deepseek-flash",
      inline = "deepseek-flash",
      analyze = "deepseek-v4-pro",
      translate = "deepseek-flash",
    },
    cycle = { "deepseek-flash", "deepseek-v4-pro" },
    models = {
      { id = "deepseek-flash", name = "DeepSeek V4.1 Flash" },
      { id = "deepseek-v4-pro", name = "DeepSeek V4 Pro" },
    },
  },

  kimi = {
    label = "Moonshot Kimi",
    protocol = "openai",
    base_url = "https://api.moonshot.ai/v1",
    env = "MOONSHOT_API_KEY",
    requires_key = true,
    defaults = {
      chat = "kimi-k3",
      inline = "kimi-k2.7-code",
      analyze = "kimi-k3.1-pro",
      translate = "kimi-k3",
    },
    cycle = { "kimi-k3.1-pro", "kimi-k3", "kimi-k2.7-code" },
    models = {
      { id = "kimi-k3.1-pro", name = "Kimi K3.1 Pro" },
      { id = "kimi-k3", name = "Kimi K3" },
      { id = "kimi-k2.7-code", name = "Kimi K2.7 Code" },
    },
  },

  zhipu = {
    label = "智谱 GLM",
    protocol = "openai",
    base_url = "https://open.bigmodel.cn/api/paas/v4",
    env = "ZHIPUAI_API_KEY",
    requires_key = true,
    defaults = {
      chat = "glm-5.3",
      inline = "glm-5.3",
      analyze = "glm-5.3",
      translate = "glm-5.3",
    },
    cycle = { "glm-5.3", "glm-5.2" },
    models = {
      { id = "glm-5.3", name = "GLM 5.3" },
      { id = "glm-5.2", name = "GLM 5.2" },
      { id = "glm-5.1", name = "GLM 5.1" },
    },
  },

  siliconflow = {
    label = "硅基流动",
    protocol = "openai",
    base_url = "https://api.siliconflow.cn/v1",
    env = "SILICONFLOW_API_KEY",
    requires_key = true,
    defaults = {
      chat = "deepseek-ai/DeepSeek-V4.1-Flash",
      inline = "moonshotai/Kimi-K2.7-Code",
      analyze = "deepseek-ai/DeepSeek-V4-Pro",
      translate = "Qwen/Qwen3.8-27B",
    },
    cycle = {
      "deepseek-ai/DeepSeek-V4.1-Flash",
      "deepseek-ai/DeepSeek-V4-Pro",
      "Qwen/Qwen3.8-27B",
    },
    models = {
      { id = "deepseek-ai/DeepSeek-V4.1-Flash", name = "DeepSeek V4.1 Flash" },
      { id = "deepseek-ai/DeepSeek-V4-Pro", name = "DeepSeek V4 Pro" },
      { id = "Qwen/Qwen3.8-27B", name = "Qwen3.8 27B" },
      { id = "Qwen/Qwen3.6-35B-A3B", name = "Qwen3.6 35B A3B" },
      { id = "moonshotai/Kimi-K2.7-Code", name = "Kimi K2.7 Code" },
    },
  },
}

-- 自动挑选 / 面板展示顺序。OpenCode 放第一位。
M.order = {
  "opencode",
  "amd",
  "nvidia",
  "agnes",
  "openrouter",
  "dashscope",
  "deepseek",
  "kimi",
  "zhipu",
  "siliconflow",
  "ollama",
}

-- 角色：global 只是展示用，实际解析时不会作为 key
M.roles = { "chat", "inline", "analyze", "translate", "complete" }
M.role_labels = {
  chat = "对话 / 后台任务",
  inline = "行内改写",
  analyze = "解释 / 审查 / 提问",
  translate = "文档翻译",
  complete = "行内补全",
}

-- ─── 用户自定义供应商 / 模型 ────────────────────────────────
-- 文件不存在时静默跳过；合并策略是「同名 provider 深度覆盖」，
-- 因此可以只写要改的字段（例如 base_url / models / defaults）。
do
  local ok, user = pcall(require, "crow.models_user")
  if ok and type(user) == "table" then
    if type(user.providers) == "table" then
      for name, p in pairs(user.providers) do
        M.providers[name] = vim.tbl_deep_extend("force", M.providers[name] or {}, p)
      end
    end
    if type(user.order) == "table" then
      M.order = user.order
    end
  end
end

-- ─── 状态持久化 ────────────────────────────────────────────
-- 只保存「用户显式选过」的项；自动回退到本机不写入，
-- 这样以后配置了云端 Key，会自动优先用云端。
local state = {
  active = nil, -- { provider = "opencode", model = "kimi-k2.6" }
  overrides = {}, -- role -> { provider, model }
}

local function state_file()
  return vim.fn.stdpath("state") .. "/crow/models.json"
end

local function load_state()
  local path = state_file()
  if vim.fn.filereadable(path) == 0 then
    return
  end
  local ok, text = pcall(vim.fn.readfile, path)
  if not ok or type(text) ~= "table" then
    return
  end
  local ok2, data = pcall(vim.json.decode, table.concat(text, "\n"))
  if not ok2 or type(data) ~= "table" then
    return
  end
  if type(data.active) == "table" and data.active.provider then
    state.active = data.active
  end
  if type(data.overrides) == "table" then
    state.overrides = data.overrides
  end
end

local function save_state()
  local dir = vim.fn.stdpath("state") .. "/crow"
  pcall(vim.fn.mkdir, dir, "p")
  -- ⚠ 空 Lua 表会被 vim.json.encode 编成 `[]`，而这里两个字段都语义上是对象：
  --   · active   期望 {"provider":..., "model":...}
  --   · overrides 期望 {"chat":{...}, ...}
  -- 用 vim.empty_dict() 保证写成 `{}`，避免读回时变成数组。
  -- 注意：state.active 可能是 nil（还没选过全局模型），
  -- 直接 next(state.active) 会抛 "bad argument #1 to 'next'"。
  local function nonempty(t)
    return type(t) == "table" and next(t) ~= nil
  end
  local data = {
    active = nonempty(state.active) and state.active or vim.empty_dict(),
    overrides = nonempty(state.overrides) and state.overrides or vim.empty_dict(),
  }
  local ok, json = pcall(vim.json.encode, data)
  if ok then
    pcall(vim.fn.writefile, { json }, state_file())
  end
end

local function key_from_secrets(name)
  local ok, secrets = pcall(require, "crow.secrets")
  if not ok or type(secrets) ~= "table" then
    return nil
  end
  return secrets[name]
end

-- ─── 本机密钥库（菜单输入）──────────────────────────────────
-- 不写进 dotfiles：放在 stdpath("state")/crow/keys.json，权限 0600。
-- 这样在 Neovide / 终端里输入一次即可，重启后仍然有效。
local keys = {}

local function keys_file()
  return vim.fn.stdpath("state") .. "/crow/keys.json"
end

local function load_keys()
  local path = keys_file()
  if vim.fn.filereadable(path) == 0 then
    return
  end
  local ok, text = pcall(vim.fn.readfile, path)
  if not ok or type(text) ~= "table" then
    return
  end
  local ok2, data = pcall(vim.json.decode, table.concat(text, "\n"))
  if not ok2 or type(data) ~= "table" then
    return
  end
  for name, value in pairs(data) do
    if type(name) == "string" and type(value) == "string" and value ~= "" then
      keys[name] = value
    end
  end
end

local function save_keys()
  local dir = vim.fn.stdpath("state") .. "/crow"
  pcall(vim.fn.mkdir, dir, "p")
  local data = next(keys) and keys or vim.empty_dict()
  local ok, json = pcall(vim.json.encode, data)
  if not ok then
    return
  end
  pcall(vim.fn.writefile, { json }, keys_file())
  pcall(vim.uv.fs_chmod, keys_file(), 384) -- 0600
end

---保存 / 清除通过菜单输入的 Key
---@param name string 供应商名
---@param key string|nil 留空表示清除本机密钥库中的这一项
---@return boolean, string?
function M.set_key(name, key)
  if not M.providers[name] then
    return false, "未知供应商: " .. tostring(name)
  end
  key = vim.trim(key or ""):gsub("^[Bb]earer%s+", "")
  if key == "" then
    keys[name] = nil
  else
    if key:find("%s") then
      return false, "Key 不能包含空格或换行"
    end
    keys[name] = key
  end
  save_keys()
  return true
end

---本机密钥库中的 Key（不含环境变量 / secrets.lua）
---@param name string
---@return string|nil
function M.saved_key(name)
  return keys[name]
end

---Key 的来源，供设置面板 / :CrowAiStats 展示
---@param name string
---@return string|nil
function M.key_source(name)
  local p = M.providers[name]
  if not p then
    return nil
  end
  local globals = vim.g.crow_api_keys
  if type(globals) == "table" and type(globals[name]) == "string" and globals[name] ~= "" then
    return "vim.g"
  end
  if keys[name] then
    return "本机密钥库"
  end
  if p.env and vim.env[p.env] and vim.env[p.env] ~= "" then
    return "环境变量 " .. p.env
  end
  if key_from_secrets(name) then
    return "secrets.lua"
  end
  if type(p.api_key) == "string" and p.api_key ~= "" then
    return "供应商配置"
  end
  return nil
end

-- ─── 基础查询 ──────────────────────────────────────────────
---@param name string
---@return table|nil
function M.provider(name)
  return M.providers[name]
end

---@param name string
---@return string|nil
function M.key(name)
  local p = M.providers[name]
  if not p then
    return nil
  end

  local globals = vim.g.crow_api_keys
  local k = type(globals) == "table" and globals[name] or nil
  if not k then
    k = keys[name]
  end
  if not k and p.env and vim.env[p.env] and vim.env[p.env] ~= "" then
    k = vim.env[p.env]
  end
  if not k then
    k = key_from_secrets(name)
  end
  if not k then
    k = p.api_key
  end
  if k == "" then
    k = nil
  end
  return k
end

---@param name string
---@return boolean
function M.is_local(name)
  local p = M.providers[name]
  return p ~= nil and p.protocol == "ollama"
end

---@param name string
---@return boolean
function M.available(name)
  local p = M.providers[name]
  if not p then
    return false
  end
  if p.requires_key == false or p.protocol == "ollama" then
    return true
  end
  return M.key(name) ~= nil
end

---@param name string
---@return string
function M.base_url(name)
  local p = M.providers[name]
  local url = p and p.base_url or ""
  return (url:gsub("/+$", ""))
end

---OpenAI 兼容的 chat/completions 完整地址
---@param name string
---@return string
function M.url(name)
  local p = M.providers[name]
  if not p then
    return ""
  end
  if p.protocol == "ollama" then
    return M.base_url(name) .. "/api/chat"
  end
  return M.base_url(name) .. "/chat/completions"
end

---@param name string
---@return table[]
function M.models(name)
  local p = M.providers[name]
  if not p then
    return {}
  end
  local out = {}
  for _, m in ipairs(p.models or {}) do
    if type(m) == "string" then
      out[#out + 1] = { id = m, name = m }
    elseif type(m) == "table" and m.id then
      out[#out + 1] = m
    end
  end
  return out
end

---@param name string
---@param id string
---@return table|nil
function M.model_info(name, id)
  for _, m in ipairs(M.models(name)) do
    if m.id == id then
      return m
    end
  end
  return nil
end

---@param name string
---@param role string
---@return string
function M.default_model(name, role)
  local p = M.providers[name]
  if not p then
    return ""
  end
  local d = p.defaults and p.defaults[role]
  if type(d) == "string" and d ~= "" then
    return d
  end
  -- 退回：complete 优先 inline，其他取第一个模型
  if role == "complete" and p.defaults and p.defaults.inline then
    return p.defaults.inline
  end
  local models = M.models(name)
  return models[1] and models[1].id or ""
end

---自动选择：complete 永远优先本机；其他角色优先第一个已配置 Key 的云供应商
---@param role string
---@return { provider: string, model: string }
function M.auto(role)
  if role == "complete" then
    local local_name = "ollama"
    for _, name in ipairs(M.order) do
      if M.is_local(name) then
        local_name = name
        break
      end
    end
    return { provider = local_name, model = M.default_model(local_name, role) }
  end

  for _, name in ipairs(M.order) do
    if M.available(name) and not M.is_local(name) then
      return { provider = name, model = M.default_model(name, role) }
    end
  end

  local local_name = "ollama"
  for _, name in ipairs(M.order) do
    if M.is_local(name) then
      local_name = name
      break
    end
  end
  return { provider = local_name, model = M.default_model(local_name, role) }
end

-- ─── 当前选择 ──────────────────────────────────────────────
---@param role string
---@return { provider: string, model: string, overridden: boolean }
function M.current(role)
  local override = state.overrides[role]
  if override and M.providers[override.provider] then
    return {
      provider = override.provider,
      model = override.model or M.default_model(override.provider, role),
      overridden = true,
    }
  end
  -- 行内补全不跟随「全局模型」：它默认始终用本机 Ollama，
  -- 只有显式给 complete 角色选过模型时才改变。
  if role == "complete" then
    return vim.tbl_extend("force", M.auto(role), { overridden = false })
  end
  if state.active and M.providers[state.active.provider] then
    return {
      provider = state.active.provider,
      model = state.active.model or M.default_model(state.active.provider, role),
      overridden = false,
    }
  end
  return vim.tbl_extend("force", M.auto(role), { overridden = false })
end

---解析成一次请求需要的全部信息
---@param role string
---@param provider_override? string
---@param model_override? string
---@return table
function M.resolve(role, provider_override, model_override)
  local provider_name, model
  if provider_override then
    provider_name = provider_override
    model = model_override or M.default_model(provider_name, role)
  else
    local cur = M.current(role)
    provider_name = cur.provider
    model = model_override or cur.model
  end

  local p = M.providers[provider_name]
  if not p then
    return {
      role = role,
      provider_name = provider_name,
      provider = nil,
      provider_label = provider_name,
      model = model or "",
      protocol = "openai",
      missing_key = true,
      error = "未知供应商: " .. tostring(provider_name),
    }
  end

  local key = M.key(provider_name)
  local missing_key = (p.protocol ~= "ollama") and (p.requires_key ~= false) and not key

  return {
    role = role,
    provider_name = provider_name,
    provider = p,
    provider_label = p.label or provider_name,
    model = model or M.default_model(provider_name, role),
    model_info = M.model_info(provider_name, model or ""),
    protocol = p.protocol or "openai",
    base_url = M.base_url(provider_name),
    url = M.url(provider_name),
    key = key,
    missing_key = missing_key,
    env = p.env,
  }
end

-- ─── 修改选择 ──────────────────────────────────────────────
local listeners = {}

---注册「选择变化」回调（CodeCompanion 用它动态重建适配器）
---@param fn fun(role?: string)
function M.on_change(fn)
  listeners[#listeners + 1] = fn
end

local function fire(role)
  for _, fn in ipairs(listeners) do
    pcall(fn, role)
  end
end

---给某个角色单独指定模型（写入 override）
---@param role string
---@param provider_name string
---@param model string
---@return boolean, string?
function M.set(role, provider_name, model)
  if not M.providers[provider_name] then
    return false, "未知供应商: " .. tostring(provider_name)
  end
  if not model or model == "" then
    return false, "模型 ID 不能为空"
  end
  state.overrides[role] = { provider = provider_name, model = model }
  save_state()
  fire(role)
  return true
end

---设置全局模型，并清空所有角色覆盖（一键切换就是用它）
---@param provider_name string
---@param model string
---@return boolean, string?
function M.set_active(provider_name, model)
  if not M.providers[provider_name] then
    return false, "未知供应商: " .. tostring(provider_name)
  end
  if not model or model == "" then
    return false, "模型 ID 不能为空"
  end
  state.active = { provider = provider_name, model = model }
  state.overrides = {}
  save_state()
  fire(nil)
  return true
end

---清掉某个角色的覆盖，恢复跟随全局
---@param role string
function M.reset(role)
  if role then
    state.overrides[role] = nil
  else
    state.active = nil
    state.overrides = {}
  end
  save_state()
  fire(role)
end

-- ─── 一键循环 ──────────────────────────────────────────────
---当前可用的全局模型列表（只含有 Key 的云 + 本机）
---provider.cycle 存在时只列这些模型，避免一键切换要按几十次。
---@return table[]
function M.active_options()
  local out = {}
  for _, name in ipairs(M.order) do
    if M.available(name) then
      local p = M.providers[name]
      local wanted = {}
      if type(p.cycle) == "table" then
        for _, id in ipairs(p.cycle) do
          wanted[id] = true
        end
      end
      for _, m in ipairs(M.models(name)) do
        if not next(wanted) or wanted[m.id] then
          out[#out + 1] = {
            provider = name,
            model = m.id,
            label = (p.label or name) .. " · " .. (m.name or m.id),
          }
        end
      end
    end
  end
  return out
end

---循环到下一个全局模型
---@return boolean, string?
function M.cycle()
  local opts = M.active_options()
  if #opts == 0 then
    return false, "没有可用模型：请先设置 OPENCODE_API_KEY，或启动本机 Ollama"
  end
  if #opts == 1 then
    local o = opts[1]
    M.set_active(o.provider, o.model)
    return true, o.label
  end

  local cur = M.current("chat")
  local idx = 0
  for i, o in ipairs(opts) do
    if o.provider == cur.provider and o.model == cur.model then
      idx = i
      break
    end
  end
  local next_item = opts[(idx % #opts) + 1]
  local ok, err = M.set_active(next_item.provider, next_item.model)
  if not ok then
    return false, err
  end
  return true, next_item.label
end

-- ─── 选择面板 ──────────────────────────────────────────────
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Crow AI 模型" })
end

local function prompt_custom(role)
  local provider_name = M.current(role or "chat").provider
  local input =
    vim.fn.input({ prompt = "自定义模型 ID（" .. (M.providers[provider_name].label or provider_name) .. "）: " })
  input = vim.trim(input)
  if input == "" then
    return
  end
  local ok, err
  if role then
    ok, err = M.set(role, provider_name, input)
  else
    ok, err = M.set_active(provider_name, input)
  end
  if ok then
    notify("已切换 → " .. (M.providers[provider_name].label or provider_name) .. " / " .. input)
  else
    notify(err or "切换失败", vim.log.levels.ERROR)
  end
end

---打开选择面板
---@param role? string 传 nil 表示选「全局模型」
function M.pick(role)
  local items = {}
  for _, name in ipairs(M.order) do
    -- 云端只列出已配置 Key 的供应商；本机服务始终列出，便于给补全指定模型。
    if M.available(name) or M.is_local(name) then
      local p = M.providers[name]
      for _, m in ipairs(M.models(name)) do
        items[#items + 1] = {
          key = name .. "\0" .. m.id,
          label = (p.label or name) .. " · " .. (m.name or m.id),
          desc = m.id .. (m.ctx and ("  ·  " .. math.floor(m.ctx / 1000) .. "k ctx") or ""),
        }
      end
    end
  end

  items[#items + 1] =
    { key = "__custom__", label = "自定义模型 ID…", desc = "使用当前供应商的任意模型" }

  local labels = {}
  for _, it in ipairs(items) do
    labels[#labels + 1] = it.desc and (it.label .. "  (" .. it.desc .. ")") or it.label
  end

  vim.ui.select(labels, {
    prompt = role and ("选择「" .. (M.role_labels[role] or role) .. "」的模型") or "选择全局 AI 模型",
  }, function(_, idx)
    if not idx then
      return
    end
    local it = items[idx]
    if it.key == "__custom__" then
      prompt_custom(role)
      return
    end
    local provider_name, model = it.key:match("^(.-)%z(.*)$")
    local ok, err
    if role then
      ok, err = M.set(role, provider_name, model)
    else
      ok, err = M.set_active(provider_name, model)
    end
    if not ok then
      notify(err or "切换失败", vim.log.levels.ERROR)
      return
    end
    local sel = M.resolve(role or "chat")
    local provider = M.providers[provider_name]
    if provider.requires_key ~= false and not M.key(provider_name) then
      notify("已选择 " .. it.label .. "，但缺少 " .. (provider.env or "API Key"), vim.log.levels.WARN)
    else
      notify("已切换 → " .. it.label)
    end
  end)
end

---按角色选择（:CrowModel analyze 之类）
---@param role string
function M.pick_role(role)
  M.pick(role)
end

-- ─── 首次配置向导：供应商 → Key → 模型 ─────────────────────
local function provider_label(name)
  local p = M.providers[name]
  if not p then
    return name
  end
  local src = M.key_source(name)
  local status
  if p.requires_key == false or p.protocol == "ollama" then
    status = "本机 / 无需 Key"
  elseif src then
    status = "✓ " .. src
  else
    status = "✗ 未配置 Key"
  end
  return string.format("%s  ·  %s", p.label or name, status)
end

---选择供应商（包含尚未配置 Key 的，方便首次设置）
---@param cb fun(provider_name: string)
function M.pick_provider(cb)
  local items = {}
  for _, name in ipairs(M.order) do
    if M.providers[name] then
      items[#items + 1] = { name = name, label = provider_label(name) }
    end
  end

  local labels = {}
  for _, it in ipairs(items) do
    labels[#labels + 1] = it.label
  end

  vim.ui.select(labels, { prompt = "选择 AI 供应商" }, function(_, idx)
    if not idx then
      notify("已取消配置")
      return
    end
    cb(items[idx].name)
  end)
end

local function choose_model(provider_name)
  local p = M.providers[provider_name]
  if not p then
    return
  end

  local items = {}
  local seen = {}

  local function add(m, tag)
    if not m or not m.id or seen[m.id] then
      return
    end
    seen[m.id] = true
    local label = (m.name or m.id) .. "  ·  " .. m.id
    if m.ctx then
      label = label .. "  ·  " .. math.floor(m.ctx / 1000) .. "k ctx"
    end
    if tag then
      label = tag .. "  " .. label
    end
    items[#items + 1] = { model = m.id, label = label }
  end

  -- 推荐模型排在前面
  if type(p.cycle) == "table" then
    for _, id in ipairs(p.cycle) do
      add(M.model_info(provider_name, id), "★")
    end
  end
  for _, m in ipairs(M.models(provider_name)) do
    add(m)
  end
  items[#items + 1] = { custom = true, label = "自定义模型 ID…" }

  local labels = {}
  for _, it in ipairs(items) do
    labels[#labels + 1] = it.label
  end

  vim.ui.select(labels, {
    prompt = "选择 " .. (p.label or provider_name) .. " 的模型",
  }, function(_, idx)
    if not idx then
      notify("已取消配置")
      return
    end
    local it = items[idx]
    local model = it.model
    if it.custom then
      model = vim.trim(vim.fn.input({ prompt = "模型 ID: " }))
      if model == "" then
        notify("未输入模型 ID，已取消", vim.log.levels.WARN)
        return
      end
    end

    local ok, err = M.set_active(provider_name, model)
    if not ok then
      notify(err or "切换失败", vim.log.levels.ERROR)
      return
    end

    local sel = M.resolve("chat")
    if sel.missing_key then
      notify(
        string.format("已选择 %s / %s，但仍缺少 Key：按 <leader>oK 补上", sel.provider_label, sel.model),
        vim.log.levels.WARN
      )
    else
      notify(string.format("已启用全局模型 → %s / %s", sel.provider_label, sel.model))
    end
  end)
end

local ask_key

---@param provider_name string
---@param next_fn fun()
ask_key = function(provider_name, next_fn)
  local p = M.providers[provider_name]
  if not p then
    return
  end

  -- 本机服务不需要 Key
  if p.requires_key == false or p.protocol == "ollama" then
    next_fn()
    return
  end

  local src = M.key_source(provider_name)
  local items
  if src then
    items = {
      { action = "keep", label = "继续使用当前 Key（来源：" .. src .. "）" },
      { action = "input", label = "输入新的 Key…" },
      { action = "clear", label = "清除本机密钥库中的 Key" },
    }
  else
    items = {
      { action = "input", label = "输入 Key…" },
      { action = "skip", label = "暂时跳过（稍后可用 :CrowSetup）" },
    }
  end

  local labels = {}
  for _, it in ipairs(items) do
    labels[#labels + 1] = it.label
  end

  vim.ui.select(labels, {
    prompt = (p.label or provider_name) .. " · API Key",
  }, function(_, idx)
    if not idx then
      notify("已取消配置")
      return
    end
    local action = items[idx].action

    if action == "keep" then
      next_fn()
      return
    end

    if action == "skip" then
      next_fn()
      return
    end

    if action == "clear" then
      M.set_key(provider_name, nil)
      notify("已清除本机密钥库中的 " .. (p.label or provider_name) .. " Key")
      -- 环境变量 / secrets.lua 还可能提供 Key；否则重新询问
      ask_key(provider_name, next_fn)
      return
    end

    local input = vim.fn.inputsecret({ prompt = (p.label or provider_name) .. " API Key: " })
    input = vim.trim(input or ""):gsub("^[Bb]earer%s+", "")
    if input == "" then
      notify("未输入 Key，保持当前配置", vim.log.levels.WARN)
      next_fn()
      return
    end

    local ok, err = M.set_key(provider_name, input)
    if not ok then
      notify(err or "保存 Key 失败", vim.log.levels.ERROR)
      ask_key(provider_name, next_fn)
      return
    end
    notify("已保存 " .. (p.label or provider_name) .. " 的 Key（仅本机，权限 0600）")
    next_fn()
  end)
end

---菜单式首次配置：供应商 → 输入 Key（本机跳过）→ 选择模型
function M.setup_wizard()
  M.pick_provider(function(provider_name)
    ask_key(provider_name, function()
      choose_model(provider_name)
    end)
  end)
end

-- ─── 状态行（供 dashboard / :CrowAiStats 用）───────────────
---@param role string
---@return string
function M.describe(role)
  local sel = M.resolve(role)
  return string.format("%s / %s", sel.provider_label, sel.model)
end

-- ─── 命令与快捷键 ──────────────────────────────────────────
function M.setup()
  vim.api.nvim_create_user_command("CrowSetup", function()
    M.setup_wizard()
  end, { desc = "配置 AI 供应商 Key 与模型" })

  vim.api.nvim_create_user_command("CrowModel", function(opts)
    local arg = vim.trim(opts.args or "")
    if arg == "next" or arg == "cycle" then
      local ok, msg = M.cycle()
      notify(msg or "切换失败", ok and vim.log.levels.INFO or vim.log.levels.ERROR)
      return
    end
    if arg == "setup" or arg == "key" then
      M.setup_wizard()
      return
    end
    if arg ~= "" and not vim.tbl_contains(M.roles, arg) and arg ~= "global" then
      notify("用法: :CrowModel [next|setup|global|" .. table.concat(M.roles, "|") .. "]", vim.log.levels.ERROR)
      return
    end
    if arg == "global" or arg == "" then
      M.pick(nil)
    else
      M.pick(arg)
    end
  end, {
    nargs = "?",
    desc = "选择 / 切换 AI 模型",
    complete = function(arglead)
      local all = { "next", "setup", "global" }
      vim.list_extend(all, M.roles)
      return vim.tbl_filter(function(s)
        return s:sub(1, #arglead) == arglead
      end, all)
    end,
  })

  vim.keymap.set("n", "<leader>om", function()
    local ok, msg = M.cycle()
    notify(msg or "切换失败", ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  end, { desc = "AI 模型：一键切换" })

  vim.keymap.set("n", "<leader>oM", function()
    M.pick(nil)
  end, { desc = "AI 模型：选择面板" })

  vim.keymap.set("n", "<leader>oK", function()
    M.setup_wizard()
  end, { desc = "AI 配置：输入 Key / 选择模型" })
end

load_state()
load_keys()

return M
