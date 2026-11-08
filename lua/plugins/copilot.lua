-- ═══════════════════════════════════════════════════════════
-- PLUGINS - copilot.lua (GitHub Copilot Inline Suggestions)
-- ═══════════════════════════════════════════════════════════
--
-- Integrates GitHub Copilot into Neovim as inline ghost text suggestions.
-- Provides real-time AI code completions triggered automatically as you type,
-- with fine-grained keymaps for accepting suggestions at different granularities.

return {
  {
    "zbirenbaum/copilot.lua",

    -- Only load the plugin when the :Copilot command is invoked explicitly,
    -- keeping it out of the startup critical path.
    cmd = "Copilot",

    -- Runs ':Copilot auth' after installation to authenticate the user
    -- with their GitHub account and activate the Copilot license.
    build = ":Copilot auth",

    opts = {
      -- ─── Inline Suggestions ──────────────────────────────────
      -- DISABLED: cloud ghost text is replaced by the local model
      -- (minuet-ai.nvim / Ollama qwen2.5-coder — see lua/plugins/minuet.lua).
      -- Running both would render two overlapping sets of ghost text.
      -- Set enabled = true to switch back to Copilot inline suggestions.
      suggestion = {
        enabled = false, -- Local (minuet-ai) now owns inline ghost text
        auto_trigger = false, -- (no-op while disabled)

        -- ─── Suggestion Keymaps ────────────────────────────────
        -- Keymaps for interacting with the active inline suggestion.
        -- All bindings use <M-> (Alt) to avoid conflicts with standard motions.
        keymap = {
          accept = "<M-l>", -- Accept the entire suggestion
          accept_word = "<M-w>", -- Accept only the next word of the suggestion
          accept_line = "<M-j>", -- Accept only the next line of the suggestion
          next = "<M-]>", -- Cycle to the next available suggestion
          prev = "<M-[>", -- Cycle to the previous available suggestion
          dismiss = "<C-]>", -- Dismiss the current suggestion without accepting
        },
      },

      -- ─── Suggestion Panel ────────────────────────────────────
      -- Enables the Copilot panel, which displays multiple alternative
      -- suggestions in a separate split window via :Copilot panel.
      panel = { enabled = true },
    },
  },
}
