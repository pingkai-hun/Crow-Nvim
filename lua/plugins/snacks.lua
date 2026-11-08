-- ═══════════════════════════════════════════════════════════
-- PLUGINS - snacks.nvim (Explorer & Notifier Configuration)
-- ═══════════════════════════════════════════════════════════
--
-- Show ignored files (dotfiles)
-- Configures snacks.nvim to display hidden and git-ignored files
-- in the file explorer, while excluding noisy build artifacts and lockfiles.

-- ─── Excluded Paths ────────────────────────────────────────
-- Files and directories listed here will never appear in the explorer,
-- even when hidden and ignored visibility are both enabled.
-- This keeps the tree clean by hiding irrelevant generated files.
local excluded = {
  ".git/", -- Git internals directory
  "dist/", -- Build output directory
  ".vite/", -- Vite cache directory
  "node_modules/", -- NPM dependency tree (usually very large)
  "bun.lock", -- Bun lockfile
  "yarn.lock", -- Yarn lockfile
  "pnpm-lock.yaml", -- PNPM lockfile
  "package-lock.json", -- NPM lockfile
}

return {
  "folke/snacks.nvim",

  -- ─── 键位覆盖 ─────────────────────────────────────────────
  -- LazyVim 默认把 <leader>n 绑成「通知历史」(snacks_picker.lua + ui.lua)。
  -- Easy-Vim / ~/.vimrc 里 <leader>n 一直是「文件树」，这里改回来；
  -- 通知历史挪到 <leader>N（大写），两者都不丢。
  --
  -- 注意：lazy.nvim 的 keys 是惰性映射，会在加载时**注册**并覆盖
  -- config/keymaps.lua 里的普通 map，所以必须在这个 spec 里声明。
  keys = {
    {
      "<leader>n",
      function()
        require("snacks").explorer()
      end,
      desc = "文件树",
    },
    {
      "<leader>N",
      function()
        local Snacks = require("snacks")
        if Snacks.config.picker and Snacks.config.picker.enabled then
          Snacks.picker.notifications()
        else
          Snacks.notifier.show_history()
        end
      end,
      desc = "通知历史",
    },
  },

  opts = {
    -- ─── Notifier ──────────────────────────────────────────────
    -- Enables the snacks notification system, which provides styled
    -- popup notifications as an alternative to nvim-notify.
    notifier = { enabled = true },

    -- ─── Picker / Explorer ─────────────────────────────────────
    -- Configures the snacks picker sources, specifically the built-in
    -- file explorer to control which files are visible.
    picker = {
      sources = {
        explorer = {
          -- Show dotfiles and other hidden files (e.g. .env, .gitignore)
          -- that are normally invisible in file explorers.
          hidden = true,

          -- Show files that are ignored by git (e.g. node_modules, dist)
          -- so they can be accessed when needed without leaving Neovim.
          ignored = true,

          -- Apply the exclusion list defined above to filter out
          -- files and directories that add noise without value.
          exclude = excluded,
        },
      },
    },
  },
}
