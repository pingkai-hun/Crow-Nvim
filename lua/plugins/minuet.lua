-- ═══════════════════════════════════════════════════════════
-- PLUGINS - minuet-ai.nvim (Inline Completion)
-- ═══════════════════════════════════════════════════════════
--
-- 行内幽灵补全默认仍走本机 Ollama 的 deepseek-r1:1.5b（FIM），
-- 因为它对延迟最敏感；对话 / 解释 / 审查 / 翻译已经切到云端。
--
-- 模型由 crow.models 的 `complete` 角色决定：
--   · 默认：本机 Ollama，低延迟
--   · 也可以在面板里给 complete 单独选云端模型（部分网关支持 /chat/completions
--     的补全模式，效果因供应商而异）
--   · 补全模型变更后需要重启 Neovim（插件在 InsertEnter 时才加载）
--
-- 使用 OpenAI FIM 兼容（本机）或 OpenAI Chat 兼容（云端）协议。
--
-- 文档：https://github.com/milanglacier/minuet-ai.nvim
--
-- 功能开关：scripts/features.sh off minuet
-- 关掉后 blink.lua 的 <Tab> 接受建议会因为 pcall 探测不到 minuet 而自动
-- 退回 snippet / 缩进行为，不需要额外处理。

local models = require("crow.models")

if not require("crow.features").on("minuet") then
  return {
    { "milanglacier/minuet-ai.nvim", enabled = false },
  }
end

local complete = models.resolve("complete")
local is_local = complete.protocol == "ollama"
local base_url = models.base_url(complete.provider_name)
local provider_name = is_local and "openai_fim_compatible" or "openai_compatible"
local endpoint = is_local and (base_url .. "/v1/completions") or (base_url .. "/chat/completions")

return {
  {
    "milanglacier/minuet-ai.nvim",
    event = "InsertEnter",

    opts = {
      provider = provider_name,
      n_completions = 1,
      context_window = is_local and 2048 or 4096,
      request_timeout = is_local and 3 or 8,
      throttle = is_local and 400 or 600,
      debounce = is_local and 400 or 600,

      provider_options = {
        [provider_name] = {
          -- 本机不需要密钥；云端从环境变量 / secrets.lua 读取。
          -- 用函数而不是环境变量名，避免 Neovide 从桌面启动时取到 nil。
          api_key = function()
            return models.key(complete.provider_name) or (is_local and "ollama" or "")
          end,
          name = complete.provider_label,
          end_point = endpoint,
          model = complete.model,
          optional = {
            max_tokens = 128,
            top_p = 0.9,
            stop = { "\n\n" },
          },
        },
      },

      -- ─── Ghost text (virtual text) frontend ────────────────
      virtualtext = {
        auto_trigger_ft = {
          "go",
          "gomod",
          "python",
          "lua",
          "rust",
          "c",
          "cpp",
          "h",
          "hpp",
          "javascript",
          "typescript",
          "javascriptreact",
          "typescriptreact",
          "java",
          "sh",
          "bash",
          "vim",
          "json",
          "yaml",
          "html",
          "css",
          "scss",
          "vue",
          "svelte",
          "sql",
        },

        keymap = {
          accept = "<M-l>",
          accept_line = "<M-j>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
    },

    config = function(_, opts)
      require("minuet").setup(opts)

      -- 全局切换不会影响补全；只有单独给 complete 角色换模型时才提示重启。
      models.on_change(function(role)
        if role == "complete" then
          vim.notify(
            "行内补全模型已变更，重启 Neovim 后生效",
            vim.log.levels.WARN,
            { title = "Crow AI 模型" }
          )
        end
      end)
    end,
  },
}
