-- ============================================================================
-- crow —— Easy-Vim 的公共函数层（Lua 移植）
-- ============================================================================
-- 对应 ~/.vim/config/crow.vim：
--   · 项目根目录探测 / 在项目根里搜索
--   · 会话文件（替代 vim-obsession 的命名规则）
--   · 浮动终端 / 普通终端
--   · 通知
--   · :Theme / :CrowTheme / :ProjectRoot / :Floaterm / :Doctor
--
-- 由 init.lua 在加载 lazy.nvim 之前 require 一次，命令可以尽早可用。

local M = {}

local markers = {
  ".git",
  ".hg",
  ".svn",
  "Cargo.toml",
  "go.mod",
  "go.work",
  "package.json",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "CMakeLists.txt",
  "Makefile",
  "compile_commands.json",
  ".clangd",
  "build.zig",
  "pom.xml",
  "build.gradle",
  "deno.json",
  "mix.exs",
}

-- ── 通知 ────────────────────────────────────────────────────────────────
---@param msg string
---@param level? integer vim.log.levels
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Easy-Nvim" })
end

-- ── 项目根目录 ──────────────────────────────────────────────────────────
---@param start? string 文件或目录，默认当前 buffer
---@return string
function M.project_root(start)
  start = start or vim.api.nvim_buf_get_name(0)
  local dir
  if start == "" then
    dir = vim.fn.getcwd()
  else
    dir = vim.fn.fnamemodify(start, ":p:h")
  end
  dir = vim.fn.simplify(vim.fn.resolve(dir))

  local prev
  while dir ~= prev do
    for _, marker in ipairs(markers) do
      if vim.fn.getftype(dir .. "/" .. marker) ~= "" then
        return dir
      end
    end
    prev = dir
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return vim.fn.getcwd()
end

--- 在项目根目录里搜索（<leader>P / <leader>R）
---@param kind "files" | "grep"
function M.find_at_root(kind)
  local root = M.project_root()
  local ok, Snacks = pcall(require, "snacks")
  if not ok then
    M.notify("snacks.nvim 未加载，无法搜索", vim.log.levels.ERROR)
    return
  end
  if kind == "grep" then
    Snacks.picker.grep({ cwd = root })
  else
    Snacks.picker.files({ cwd = root })
  end
end

-- ── 终端 ────────────────────────────────────────────────────────────────
--- 在浮动终端里跑一条命令（对应 Vim 的 crow#Floaterm）
---@param cmd? string | string[]
function M.terminal(cmd)
  local ok, Snacks = pcall(require, "snacks")
  if ok then
    Snacks.terminal.open(cmd, { win = { position = "float" } })
  elseif cmd then
    vim.cmd("terminal " .. (type(cmd) == "table" and table.concat(cmd, " ") or cmd))
  else
    vim.cmd("terminal")
  end
end

--- <F7>：打开 / 关闭浮动终端
function M.toggle_terminal()
  local ok, Snacks = pcall(require, "snacks")
  if ok then
    Snacks.terminal.toggle()
  else
    vim.cmd("terminal")
  end
end

-- ── 会话 ────────────────────────────────────────────────────────────────
--- 命名规则与 Vim 版一致：主机名-目录名.vim，放在 Neovim state 目录下
---@return string
function M.session_file()
  local dir = vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("[/\\]+$", "")
  dir = vim.fn.fnamemodify(dir, ":t")
  local host = vim.fn.hostname():gsub("[^A-Za-z0-9_-]", "_")
  local base = vim.fn.stdpath("state") .. "/sessions"
  vim.fn.mkdir(base, "p")
  return base .. "/" .. host .. "-" .. dir .. ".vim"
end

---@param path string
function M.session_save(path)
  vim.cmd("mksession! " .. vim.fn.fnameescape(path))
  M.notify("会话已保存: " .. path)
end

---@param path string
function M.session_load(path)
  if vim.fn.filereadable(path) == 1 then
    vim.cmd("source " .. vim.fn.fnameescape(path))
    M.notify("会话已载入: " .. path)
  else
    M.notify("没有找到会话文件: " .. path, vim.log.levels.WARN)
  end
end

--- Obsess：开启「退出时自动保存」
function M.session_obsess()
  vim.g.crow_obsess = true
  M.session_save(M.session_file())
  M.notify("会话自动保存已开启（退出时写入）")
end

--- Obsess!：停止自动保存并删除会话文件
function M.session_stop()
  vim.g.crow_obsess = false
  local file = M.session_file()
  if vim.fn.filereadable(file) == 1 then
    vim.fn.delete(file)
  end
  M.notify("会话自动保存已停止")
end

-- ── 命令 ────────────────────────────────────────────────────────────────
local function complete_colorschemes(arglead)
  return vim.tbl_filter(function(name)
    return name:sub(1, #arglead) == arglead
  end, vim.fn.getcompletion("", "color"))
end

local function complete_palette(arglead)
  return vim.tbl_filter(function(name)
    return name:sub(1, #arglead) == arglead
  end, require("crow.palette").names())
end

local catppuccin_flavours = { "mocha", "macchiato", "frappe", "latte" }

function M.setup()
  vim.g.crow_colorscheme = vim.g.crow_colorscheme or "catppuccin-mocha"
  vim.g.crow_transparent = vim.g.crow_transparent ~= false

  -- 主题增强（ColorScheme 钩子 + 首次应用）
  require("crow.theme").setup()

  -- 退出时自动保存会话
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("CrowSession", { clear = true }),
    callback = function()
      if vim.g.crow_obsess then
        pcall(M.session_save, M.session_file())
      end
    end,
  })

  -- :Theme —— 切换任意配色
  vim.api.nvim_create_user_command("Theme", function(opts)
    vim.cmd.colorscheme(opts.args)
    vim.g.crow_colorscheme = opts.args
  end, { nargs = 1, complete = complete_colorschemes, desc = "切换配色" })

  -- :CrowTheme —— 切换 Catppuccin flavor（同时刷新 lualine 色板）
  vim.api.nvim_create_user_command("CrowTheme", function(opts)
    local name = opts.args
    local ok = pcall(function()
      require("catppuccin").setup({ flavour = name })
    end)
    if not ok then
      M.notify("catppuccin.nvim 尚未加载", vim.log.levels.WARN)
      return
    end
    vim.cmd.colorscheme("catppuccin-" .. name)
    vim.g.crow_colorscheme = "catppuccin-" .. name
    M.notify("配色已切换为 catppuccin-" .. name)
  end, {
    nargs = 1,
    complete = function(arglead)
      return vim.tbl_filter(function(name)
        return name:sub(1, #arglead) == arglead
      end, catppuccin_flavours)
    end,
    desc = "切换 Catppuccin flavor",
  })

  -- :ProjectRoot —— cd 到项目根
  vim.api.nvim_create_user_command("ProjectRoot", function(opts)
    local dir = M.project_root(opts.args ~= "" and opts.args or nil)
    vim.cmd.cd(vim.fn.fnameescape(dir))
    M.notify("cwd → " .. dir)
  end, { nargs = "?", complete = "dir", desc = "切换到项目根目录" })

  -- :Floaterm —— 浮动终端里跑命令
  vim.api.nvim_create_user_command("Floaterm", function(opts)
    M.terminal(opts.args)
  end, { nargs = "+", desc = "浮动终端执行命令" })

  -- :Doctor —— 一键体检
  vim.api.nvim_create_user_command("Doctor", function()
    require("crow.doctor").run()
  end, { desc = "Easy-Nvim 体检" })

  -- 兼容 Vim 版的补全函数名（可选）
  _G.crow = M
end

return M
