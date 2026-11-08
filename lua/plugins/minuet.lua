-- ═══════════════════════════════════════════════════════════
-- PLUGINS - minuet-ai.nvim (Local LLM Inline Completion)
-- ═══════════════════════════════════════════════════════════
--
-- Local, offline "ghost text" code completion powered by the Ollama-hosted
-- qwen2.5-coder:1.5b model (Fill-In-the-Middle / FIM).
--
-- Replaces GitHub Copilot's cloud inline suggestions (copilot.lua's
-- suggestion is disabled in copilot.lua). CopilotChat stays available.
--
-- Uses the recommended `virtualtext` frontend (standalone ghost text; no
-- need to inject minuet into blink.cmp). Accept keys reuse the previous
-- Copilot Alt-* bindings, so they don't clash with LazyVim's <Tab> (blink).
--
-- Requires the Ollama service running with the model pulled:
--   ollama pull qwen2.5-coder:1.5b
--
-- Docs: https://github.com/milanglacier/minuet-ai.nvim

return {
  {
    "milanglacier/minuet-ai.nvim",
    event = "InsertEnter",

    opts = {
      provider = "openai_fim_compatible",
      n_completions = 1, -- keep at 1 for a local model (saves compute)
      context_window = 2048, -- 与 Vim 版 context_lines=40 接近，本地模型更快
      request_timeout = 3, -- seconds
      throttle = 400, -- min ms between requests
      debounce = 400, -- 停止输入 400ms 后请求补全（与 Vim 版一致）

      provider_options = {
        openai_fim_compatible = {
          -- Ollama 不需要密钥。不要用 "TERM" 之类的环境变量名：
          -- Neovide 从桌面环境启动时 TERM 可能是空的，minuet 取到 nil
          -- 就会在拼接 "Bearer " .. nil 时崩溃。直接用函数返回固定值。
          api_key = function()
            return "ollama"
          end,
          name = "Ollama",
          end_point = "http://localhost:11434/v1/completions",
          model = "qwen2.5-coder:1.5b",
          optional = {
            max_tokens = 128,
            top_p = 0.9,
            stop = { "\n\n" },
          },
        },
      },

      -- ─── Ghost text (virtual text) frontend ────────────────
      virtualtext = {
        -- 只在代码类文件里触发；markdown / text / gitcommit / help / qf 等不打扰
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

        -- Keymaps reuse the previous Copilot Alt-* muscle memory and
        -- deliberately avoid <Tab> (owned by blink.cmp / LazyVim).
        keymap = {
          accept = "<M-l>", -- accept the whole suggestion
          accept_line = "<M-j>", -- accept only the current line
          next = "<M-]>", -- cycle to the next suggestion
          prev = "<M-[>", -- cycle to the previous suggestion
          dismiss = "<C-]>", -- dismiss without accepting
        },
      },
    },

    -- minuet's module is `minuet` (not derived from the repo name), so wire
    -- setup() explicitly rather than relying on lazy.nvim's module guessing.
    config = function(_, opts)
      require("minuet").setup(opts)
    end,
  },
}
