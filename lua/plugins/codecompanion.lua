-- ═══════════════════════════════════════════════════════════
-- PLUGINS - codecompanion.nvim (Local AI via Ollama)
-- ═══════════════════════════════════════════════════════════
--
-- Integrates the locally-deployed qwen2.5-coder:1.5b model (via Ollama)
-- into Neovim for professional, context-aware AI coding. Provides:
--   • Inline transformations (:CodeCompanion <prompt>) — select code,
--     ask the model to write/refactor it, then accept edits via diff
--   • Chat buffer (:CodeCompanionChat)               — Q&A, explanations
--   • Action palette (:CodeCompanionActions)         — slash commands
--
-- Runs fully offline / local — no API key, no network egress.
-- Complements the existing GitHub Copilot (online ghost-text) tooling.
-- Requires the Ollama service to be running with the model pulled:
--   ollama pull qwen2.5-coder:1.5b
--
-- NOTE: Not yet installed. When your git proxy is back, run:
--   :Lazy install
-- Docs: https://codecompanion.olimorris.dev

return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCodeReview" },

    config = function()
      require("codecompanion").setup({
        -- ─── Local Model Adapter (Ollama / qwen2.5-coder) ──────
        -- The built-in `ollama` adapter talks to the local Ollama server.
        -- Parameters tuned for the 1.5B model: a modest context window
        -- keeps memory usage low and responses snappy.
        adapters = {
          http = {
            ollama = function()
              return require("codecompanion.adapters").extend("ollama", {
                schema = {
                  model = {
                    default = "qwen2.5-coder:1.5b", -- Local coding model
                  },
                  num_ctx = {
                    default = 8192, -- Context window (tokens); model supports 32768
                  },
                  keep_alive = {
                    default = "30m", -- Keep model warm in memory between requests
                  },
                  options = {
                    default = {
                      temperature = 0.2, -- Lower temperature = more deterministic code
                    },
                  },
                },
              })
            end,
          },
        },

        -- ─── Interactions ─────────────────────────────────────
        -- Route both chat and inline transformations through the
        -- local qwen2.5-coder model.
        interactions = {
          chat = {
            adapter = { name = "ollama", model = "qwen2.5-coder:1.5b" },
            opts = {
              context_management = {
                editing = { trigger = 6000 }, -- Compact editing context at 6k tokens
                compaction = { trigger = 8000 }, -- Compact chat at 8k tokens
              },
            },
          },
          inline = {
            adapter = { name = "ollama", model = "qwen2.5-coder:1.5b" },
          },
        },
      })

      -- ─── Keymaps ─────────────────────────────────────────────
      -- CodeCompanion ships with no default keymaps; bind convenient
      -- <leader> shortcuts here. Prefix `o` = "Ollama" (local AI),
      -- distinct from CopilotChat's `<leader>a` group.
      --
      -- <leader>o 分组的分工：
      --   oa  AI 解释代码      ← crow.ai（最常用，放最好按的位置）
      --   or  AI 审查代码      ← crow.ai
      --   oq  AI 带上下文提问  ← crow.ai
      --   oi  AI 状态          ← crow.ai
      --   oc  对话式聊天       ← CodeCompanion
      --   ov  动作面板         ← CodeCompanion（原 oa，让位给「解释」）
      --   oe  改写选区         ← CodeCompanion
      --
      -- 注意：crow.ai 的映射在 lua/crow/ai.lua 的 setup() 里注册，
      -- 这里不要再定义同名键（oa/or/oq/oi），否则会互相覆盖。
      local wk = require("which-key")
      wk.add({
        { "<leader>o", group = "Ollama / AI（本机 3B 模型）" },
        { "<leader>oa", desc = "AI 解释当前函数 / 选区" },
        { "<leader>or", desc = "AI 审查代码 / 选区" },
        { "<leader>oq", desc = "AI 带上下文提问" },
        { "<leader>oi", desc = "AI 状态" },
        { "<leader>oc", "<cmd>CodeCompanionChat Toggle<CR>", desc = "AI 对话", mode = { "n", "v" } },
        { "<leader>ov", "<cmd>CodeCompanionActions<CR>", desc = "AI 动作面板", mode = { "n", "v" } },
        { "<leader>oe", "<cmd>CodeCompanion<CR>", desc = "AI 改写选区", mode = { "n", "v" } },
      })
    end,
  },
}