-- ═══════════════════════════════════════════════════════════
-- Easy-Nvim 自动命令（移植自 ~/.vimrc「自动命令」）
-- ═══════════════════════════════════════════════════════════
-- Neovim 侧只保留真正需要的自动命令：
--   · 恢复上次光标位置
--   · 按文件类型设置缩进 / 折行 / 拼写
--   · 保存时清理行尾空白（跳过 markdown / text / diff）
--   · 保存 Neovim 配置后自动重载
--   · 终端尺寸变化时均分窗口
--   · 大文件降级、临时窗口 q 关闭、启动统计
--
-- 格式化不在这里做：全部交给 conform.nvim（见 lua/plugins/lsp.lua），
-- 避免和 vim-go / LSP 的保存格式化重复执行。

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local opt_local = vim.opt_local

-- ─── 通用编辑 ────────────────────────────────────────────
local editing = augroup("EasyEditing", { clear = true })

-- 恢复上次退出时的光标位置
autocmd("BufReadPost", {
  group = editing,
  pattern = "*",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "恢复上次光标位置",
})

-- 保存时删除行尾空白（保留光标位置）
-- markdown / text / gitcommit / diff 对空白敏感，跳过。
autocmd("BufWritePre", {
  group = editing,
  pattern = "*",
  callback = function()
    local ft = vim.bo.filetype
    if ft == "markdown" or ft == "text" or ft == "gitcommit" or ft == "diff" then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
  desc = "删除行尾空白",
})

-- ─── 文件类型 ────────────────────────────────────────────
local filetypes = augroup("EasyFileType", { clear = true })

autocmd("FileType", {
  group = filetypes,
  pattern = { "markdown", "text" },
  callback = function()
    opt_local.wrap = true
    opt_local.spell = true
    opt_local.spelllang = "en,cjk"
  end,
  desc = "Markdown/Text：折行 + 拼写",
})

autocmd("FileType", {
  group = filetypes,
  pattern = { "json", "jsonc", "yaml", "yml" },
  callback = function()
    opt_local.tabstop = 2
    opt_local.shiftwidth = 2
    opt_local.softtabstop = 2
  end,
  desc = "JSON/YAML：2 空格缩进",
})

autocmd("FileType", {
  group = filetypes,
  pattern = { "rust", "c", "cpp", "h", "hpp" },
  callback = function()
    -- rustfmt / clang-format 全部交给 conform，不要插件各自保存格式化
    vim.b.autoformat = true
  end,
  desc = "Rust/C/C++：格式化交给 conform",
})

-- ─── 配置重载 ────────────────────────────────────────────
local config_group = augroup("EasyConfigReload", { clear = true })

autocmd("BufWritePost", {
  group = config_group,
  pattern = {
    vim.fn.stdpath("config") .. "/init.lua",
    vim.fn.stdpath("config") .. "/lua/config/*.lua",
    vim.fn.stdpath("config") .. "/lua/plugins/*.lua",
    vim.fn.stdpath("config") .. "/lua/crow/*.lua",
  },
  callback = function()
    -- 重新加载 colorscheme / 自动命令即可；插件 spec 需要重启或 :Lazy reload
    pcall(vim.cmd, "source " .. vim.fn.fnameescape(vim.fn.stdpath("config") .. "/init.lua"))
    vim.notify("配置已重新载入", vim.log.levels.INFO, { title = "Easy-Nvim" })
  end,
  desc = "保存配置后自动重载",
})

-- ─── 窗口与 UI ───────────────────────────────────────────
local windows = augroup("EasyWindows", { clear = true })

autocmd("VimResized", {
  group = windows,
  pattern = "*",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
  desc = "终端尺寸变化时均分窗口",
})

local ephemeral = {
  "qf",
  "man",
  "help",
  "query",
  "lspinfo",
  "startuptime",
  "checkhealth",
  "spectre_panel",
  "lazy",
  "mason",
}

autocmd("FileType", {
  group = windows,
  pattern = ephemeral,
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
  desc = "临时窗口用 q 关闭",
})

-- ─── 性能：大文件降级 ────────────────────────────────────
local performance = augroup("EasyPerformance", { clear = true })

autocmd("BufReadPre", {
  group = performance,
  pattern = "*",
  callback = function()
    local max_filesize = 1024 * 1024 -- 1 MB
    local name = vim.api.nvim_buf_get_name(0)
    local ok, stats = pcall((vim.uv or vim.loop).fs_stat, name)
    if ok and stats and stats.size and stats.size > max_filesize then
      vim.notify("大文件：已关闭部分高开销功能", vim.log.levels.WARN)
      opt_local.swapfile = false
      opt_local.foldmethod = "manual"
      opt_local.undolevels = -1
      opt_local.undoreload = 0
      opt_local.list = false
      pcall(vim.cmd, "TSBufDisable highlight")
      pcall(vim.cmd, "TSBufDisable indent")
    end
  end,
  desc = "大文件降级",
})

-- ─── 启动统计 ────────────────────────────────────────────
local notifications = augroup("EasyNotifications", { clear = true })

autocmd("VimEnter", {
  group = notifications,
  once = true,
  callback = function()
    vim.defer_fn(function()
      -- 注意：require("lazy").stats 的类型在不同时机/版本下不一样：
      --   · 多数情况是 function（lazy/init.lua 里的 M.stats()）
      --   · 但在 defer_fn / git checker 的后台回调里，它可能是
      --     lazy.stats 内部共享的「表」本身（{ times, startuptime, loaded, count }）
      -- 直接 stats() 就会报 "attempt to call local 'stats' (a table value)"。
      -- 所以这里两种都兼容：是函数就调用，是表就直接用。
      local ok, stats = pcall(function()
        local lazy = require("lazy")
        local s = lazy.stats
        if type(s) == "function" then
          return s()
        end
        return s
      end)
      if not ok or type(stats) ~= "table" then
        return
      end
      local ms = math.floor((stats.startuptime or 0) * 100 + 0.5) / 100
      vim.notify(
        string.format("⚡ Neovim %.2fms / %d/%d 插件", ms, stats.loaded or 0, stats.count or 0),
        vim.log.levels.INFO,
        { title = "Easy-Nvim" }
      )
    end, 100)
  end,
  desc = "启动统计",
})
