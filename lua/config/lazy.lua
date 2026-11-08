-- ═══════════════════════════════════════════════════════════
-- BOOTSTRAP - lazy.nvim Plugin Manager Entry Point
-- ═══════════════════════════════════════════════════════════
--
-- Description:
--   Main entry point for Neovim's plugin system. Bootstraps
--   lazy.nvim if not already installed, then initializes it
--   with all plugin specs, performance settings, and update
--   behavior.
--
-- Location:
--   ~/.config/nvim/lua/config/lazy.lua
--
-- Installation:
--   Requires Neovim 0.9+. The bootstrap script auto-installs
--   lazy.nvim on first run — no manual plugin setup needed.
--
-- Usage:
--   nvim              (lazy.nvim auto-installs on first launch)
--   :Lazy             (open lazy.nvim dashboard)
--   :Lazy update      (update all plugins)
--   :Lazy clean       (remove unused plugins)
--
-- Theme:
--   Catppuccin Macchiato (via catppuccin/nvim plugin)
--
-- See also:
--   nvim/lua/config/options.lua   (editor settings)
--   nvim/lua/config/keymaps.lua   (keybindings)
--   nvim/lua/config/autocmds.lua  (autocommands)
--   nvim/lua/plugins/              (individual plugin specs)
--
-- Documentation:
--   https://github.com/folke/lazy.nvim

-- ─── Bootstrap lazy.nvim ───────────────────────────────────
-- Resolves the expected installation path for lazy.nvim using Neovim's
-- standard data directory (typically ~/.local/share/nvim/lazy/lazy.nvim).

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Check if lazy.nvim is already installed by verifying the directory exists.
-- vim.uv is preferred (Neovim 0.10+); vim.loop is the fallback for older versions.
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"

  -- Clone the latest stable branch of lazy.nvim using a blobless clone
  -- (--filter=blob:none) to minimize download size while preserving full history.
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })

  -- If the git clone failed (non-zero shell exit code), display a clear error
  -- message in the Neovim echo area and exit gracefully to avoid a broken state.
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Prepend lazy.nvim's path to the Neovim runtime path so it can be
-- required immediately, before any other plugins are loaded.
vim.opt.rtp:prepend(lazypath)

-- ─── Plugin Setup ──────────────────────────────────────────
-- Initialize lazy.nvim with the full plugin specification and configuration.
require("lazy").setup({

  -- ─── Plugin Specifications ─────────────────────────────────
  -- The spec table defines all plugins to be managed.
  -- Entries are evaluated in order; later entries can override earlier ones.
  spec = {
    -- Load LazyVim's core plugin suite and all its bundled plugin configurations.
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- Import LazyVim extras for ESLint linting support.
    { import = "lazyvim.plugins.extras.linting.eslint" },

    -- Import LazyVim extras for Prettier formatting support.
    { import = "lazyvim.plugins.extras.formatting.prettier" },

    -- nvim-dap 调试基础（替代 vimspector；Go 由 nvim-dap-go 接管）
    { import = "lazyvim.plugins.extras.dap.core" },

    -- Import all custom user plugins from the lua/plugins/ directory.
    -- Any plugin spec here can override or extend the LazyVim defaults above.
    { import = "plugins" },

    -- 最终主题：Catppuccin Mocha（放在最后，覆盖所有默认）
    { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin-mocha" } },
  },

  -- ─── Defaults ──────────────────────────────────────────────
  defaults = {
    -- false = only LazyVim's own plugins are lazy-loaded by default.
    -- Custom plugins load eagerly at startup unless they define their own
    -- lazy-loading triggers (event, cmd, keys, ft, etc.).
    lazy = false,

    -- false = always use the latest git commit instead of tagged releases.
    -- Many plugins have outdated or missing semver tags that could cause breakage.
    version = false,
    -- version = "*", -- Uncomment to prefer latest stable semver tag when available
  },

  -- ─── Install ───────────────────────────────────────────────
  -- Fallback colorschemes used during the initial plugin installation screen
  -- before the user's chosen colorscheme plugin has been installed.
  install = { colorscheme = { "tokyonight", "habamax" } },

  -- ─── Update Checker ────────────────────────────────────────
  -- ⚠ 关闭启动时的自动更新检查。
  --
  -- 原因：checker 会在启动阶段用 `git` 查远端 tag（fast_check），
  -- 期间通过 vim.wait 阻塞主循环。阻塞期间定时器仍然会触发，于是
  -- 出现这种交错：
  --   1. which-key 的 plugin/which-key.lua 里有个 500ms 定时器；
  --   2. checker 的 git 调用把主循环卡住；
  --   3. 定时器在「插件正在加载」的半途被调度执行；
  --   4. require("which-key") 拿到尚未初始化完的模块；
  --   5. → attempt to call field 'setup' (a nil value)
  -- 用户报的报错栈里正好能看到
  --   checker.lua → git.lua → process.lua → async.lua → vim.wait
  -- 这条完整链路，属于同一个问题。
  --
  -- 关掉后不再有这段阻塞，启动也更快。需要更新插件时手动执行：
  --   :Lazy update          （全部）
  --   :Lazy update 插件名    （单个）
  checker = {
    enabled = false,
    notify = false,
  },

  -- ─── Config Change Detection ───────────────────────────────
  -- 默认会在每次保存插件 spec 时弹一条
  --   "# Config Change Detected. Reloading..."
  -- 这不是错误，只是 lazy.nvim 的提示。保留自动重载，但关掉通知，
  -- 避免每次改配置都弹窗打断编辑。
  change_detection = {
    enabled = true,
    notify = false,
  },

  -- ─── Performance ───────────────────────────────────────────
  performance = {
    rtp = {
      -- Disable built-in Neovim plugins that are rarely needed.
      -- This reduces startup time by skipping unnecessary plugin loading.
      -- Commented-out entries are disabled by LazyVim but left for reference.
      disabled_plugins = {
        "gzip", -- Editing gzip-compressed files (rarely needed)
        -- "matchit",  -- Extended % matching (replaced by Treesitter)
        -- "matchparen",-- Highlight matching parens (can cause lag on large files)
        -- "netrwPlugin",-- Built-in file browser (replaced by neo-tree/oil)
        "tarPlugin", -- Editing tar archives
        "tohtml", -- Converting buffers to HTML
        "tutor", -- :Tutor interactive tutorial
        "zipPlugin", -- Editing zip archives
      },
    },
  },
})

-- ─── Easy-Vim 选项写回 ────────────────────────────────────
-- 必须放在 require("lazy").setup(...) 之后：
-- LazyVim 的 lazyvim/config/options.lua 在此刻才执行完，
-- 它会把 scrolloff / pumheight / updatetime 等改成自己的默认值。
-- 这里统一写回 ~/.vimrc 中的取值，保证两个编辑器手感一致。
require("crow.options").setup()

-- ─── 启动阶段防御 ────────────────────────────────────────
-- which-key 的 plugin 脚本有个 500ms 定时器，会在 did_setup 为假时调用
-- wk.setup()。若那时模块不完整就会报「attempt to call field 'setup'」。
-- 这里在 lazy.setup() 之后立刻确保 did_setup 已置位，
-- 让那一行永远不会执行（详见 lua/crow/guard.lua 的说明）。
require("crow.guard").setup()
