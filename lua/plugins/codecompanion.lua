-- ═══════════════════════════════════════════════════════════
-- PLUGINS - codecompanion.nvim（云端 / 本机多模型）
-- ═══════════════════════════════════════════════════════════
--
-- 模型不再写死：由 lua/crow/models.lua 统一决定。
--   · 默认走 OpenCode 聚合平台（OpenAI 兼容）
--   · 没有云端 Key 时自动回退本机 Ollama
--   · <leader>om 一键循环切换全局模型，<leader>oM 打开面板
--   · 想给「对话 / 行内改写」单独指定模型：:CrowModel chat / :CrowModel inline
--
-- 两个适配器按角色读取当前选择：
--   crow_chat    对话 / 后台任务
--   crow_inline  行内改写 / Cmd
--
-- 提供的能力：
--   :CodeCompanionChat       多轮对话、带工具的 agent 式编辑
--   :CodeCompanion <prompt>  行内改写（选中代码 → 生成 → diff 接受）
--   :CodeCompanionActions    动作面板（预设 prompt / 规则 / 扩展）
--   :CodeCompanionCodeReview 结构化审查，逐 hunk 接受 / 撤销
--   :CodeCompanionCmd        让模型写 Neovim 命令行
--
-- <leader>o = AI 分组：
--   oa  AI 解释当前函数 / 选区  ← lua/crow/ai.lua（轻量单轮）
--   or  AI 审查当前函数 / 选区  ← lua/crow/ai.lua
--   oq  AI 带上下文提问        ← lua/crow/ai.lua
--   oi  AI 状态                ← lua/crow/ai.lua
--   om  一键切换全局模型        ← lua/crow/models.lua
--   oM  模型选择面板            ← lua/crow/models.lua
--   oc  AI 对话（Chat）         ← 本文件 init
--   ov  AI 动作面板             ← 本文件 init
--   oe  AI 改写选区（Inline）   ← 本文件 init
--   oR  AI 结构化审查（diff）   ← 本文件 init
--
-- 文档：https://codecompanion.olimorris.dev

local models = require("crow.models")

-- ─── 功能开关 ───────────────────────────────────────────────
-- scripts/features.sh off codecompanion 时整份 spec 退化为 disabled，
-- 插件不会加载、命令不会创建、下面的快捷键也不会注册。
if not require("crow.features").on("codecompanion") then
  return {
    { "olimorris/codecompanion.nvim", enabled = false },
  }
end

---当前角色所在供应商的可选模型（给 CodeCompanion 的 :model 切换器用）
---@param role string
---@return table<string, table>
local function model_choices(role)
  local choices = {}
  local cur = models.resolve(role)
  local name = cur.provider_name
  local p = models.providers[name]
  if p then
    for _, m in ipairs(models.models(name)) do
      choices[m.id] = {
        formatted_name = (p.label or name) .. " · " .. (m.name or m.id),
        meta = { context_window = m.ctx },
        opts = {},
      }
    end
  end

  -- 用户手动输入的模型 ID 也要能在聊天里正常显示
  if not choices[cur.model] then
    choices[cur.model] = { formatted_name = cur.model, opts = {} }
  end
  return choices
end

---基于 OpenAI 兼容适配器，构造一个按角色取模型的适配器
---@param role string
---@param name string
local function openai_adapter(role, name)
  local sel = models.resolve(role)
  local provider_name = sel.provider_name
  local p = sel.provider or {}

  local headers = {
    ["Content-Type"] = "application/json",
    Authorization = "Bearer ${api_key}",
  }
  for k, v in pairs(p.headers or {}) do
    if type(v) == "string" then
      headers[k] = v
    end
  end

  return require("codecompanion.adapters").extend("openai_compatible", {
    name = name,
    formatted_name = "AI · " .. sel.provider_label,
    -- ${url} 由 env.url 提供，${chat_url} 拼上 /chat/completions
    url = "${url}${chat_url}",
    env = {
      -- 用函数读取，切换模型后重建适配器时不会残留旧 Key
      api_key = function()
        return models.key(provider_name) or ""
      end,
      url = function()
        return models.base_url(provider_name)
      end,
      chat_url = "/chat/completions",
      models_endpoint = "/models",
    },
    headers = headers,
    parameters = {
      stream = true,
      -- 不同模型对 temperature 的兼容性不一，默认不主动发送。
      -- 想强制发送：在 models_user.lua 的 provider 上标 temperature_supported = true。
    },
    opts = {
      stream = true,
      tools = true,
      vision = true,
    },
    schema = {
      model = {
        default = sel.model,
        choices = model_choices(role),
      },
    },
    handlers = {
      -- 覆盖 openai_compatible 的 setup：它默认会带 stream_options.include_usage，
      -- 部分网关不接受这个字段。
      setup = function(self)
        self.parameters.stream = true
        return true
      end,
    },
  })
end

---本机 Ollama 适配器
---@param role string
---@param name string
local function ollama_adapter(role, name)
  local sel = models.resolve(role)
  local provider_name = sel.provider_name

  return require("codecompanion.adapters").extend("ollama", {
    name = name,
    formatted_name = "AI · " .. sel.provider_label,
    env = {
      url = function()
        return models.base_url(provider_name)
      end,
    },
    parameters = {
      stream = true,
    },
    schema = {
      model = {
        default = sel.model,
        choices = model_choices(role),
      },
      num_ctx = { default = 8192 },
      keep_alive = { default = "30m" },
      temperature = { default = 0.2 },
    },
  })
end

---@param role string
---@param name string
local function role_adapter(role, name)
  local sel = models.resolve(role)
  if sel.protocol == "ollama" then
    return ollama_adapter(role, name)
  end
  return openai_adapter(role, name)
end

local function build_opts()
  local chat = models.resolve("chat")
  local inline = models.resolve("inline")

  return {
    adapters = {
      http = {
        crow_chat = function()
          return role_adapter("chat", "crow_chat")
        end,
        crow_inline = function()
          return role_adapter("inline", "crow_inline")
        end,
      },
    },

    interactions = {
      chat = {
        adapter = { name = "crow_chat", model = chat.model },
        roles = {
          llm = function(adapter)
            return "AI · " .. (adapter.formatted_name or adapter.name or "LLM")
          end,
          user = "我",
        },
        opts = {
          completion_provider = "blink",
          context_management = {
            editing = { trigger = 0.65 },
            compaction = {
              trigger = 0.85,
              -- 对 8k 本机窗口能真正生效；云端大窗口也不会被频繁误触发
              min_token_savings = 1500,
            },
          },
        },
      },

      inline = {
        adapter = { name = "crow_inline", model = inline.model },
        opts = {
          max_context_tokens = 6000,
        },
      },

      cmd = { adapter = { name = "crow_inline", model = inline.model } },
      background = { adapter = { name = "crow_chat", model = chat.model } },
    },

    display = {
      action_palette = { provider = "snacks" },
      chat = {
        window = { border = "rounded" },
        floating_window = { border = "rounded" },
        intro_message = string.format(
          "CodeCompanion 已就绪（%s / %s）。<leader>om 切换模型，按 ? 查看选项",
          chat.provider_label,
          chat.model
        ),
      },
      input = {
        window = { border = "rounded" },
      },
    },

    opts = {
      language = "Simplified Chinese",
    },
  }
end

return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },

    -- ─── 懒加载入口 ───────────────────────────────────────
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCodeReview",
      "CodeCompanionCmd",
      "CodeCompanionCLI",
    },

    init = function()
      local map = vim.keymap.set
      -- om / oM 由 crow.models.setup() 全局注册，这里不要重复绑定。
      map({ "n", "v" }, "<leader>oc", "<cmd>CodeCompanionChat Toggle<cr>", {
        desc = "AI 对话",
        silent = true,
      })
      map({ "n", "v" }, "<leader>ov", "<cmd>CodeCompanionActions<cr>", {
        desc = "AI 动作面板",
        silent = true,
      })
      map({ "n", "v" }, "<leader>oe", "<cmd>CodeCompanion<cr>", {
        desc = "AI 改写选区",
        silent = true,
      })
      map("n", "<leader>oR", "<cmd>CodeCompanionCodeReview<cr>", {
        desc = "AI 结构化审查",
        silent = true,
      })
    end,

    opts = function()
      return build_opts()
    end,

    config = function(_, opts)
      require("codecompanion").setup(opts)

      -- 模型切换后重建适配器：新开的 chat / inline 立即用新模型，
      -- 已经打开的 chat 可以继续用，或用聊天窗口里的模型切换键。
      models.on_change(function()
        pcall(function()
          require("codecompanion").setup(build_opts())
        end)
      end)
    end,
  },
}
