-- ═══════════════════════════════════════════════════════════
-- Easy-Nvim 基础选项（移植自 ~/.vimrc「基础设置」）
-- ═══════════════════════════════════════════════════════════
-- LazyVim 会先加载自己的 options，这里在其后覆盖。
-- 只保留对 Neovim 有意义的项；Vim 专属项（pumborder / mousemodel 等）做了保护。

local opt = vim.opt
local g = vim.g

-- ─── 基础 ────────────────────────────────────────────────
g.mapleader = " "
g.maplocalleader = "\\"
g.autoformat = true
g.lazyvim_picker = "auto"
g.lazyvim_cmp = "auto"
g.ai_cmp = true
g.snacks_animate = true

-- go install 的工具（goimports / dlv / staticcheck / gomodifytags …）
vim.env.PATH = vim.fn.expand("~/go/bin") .. ":" .. (vim.env.PATH or "")

-- 项目根探测：与 Vim 版一致的标记文件
g.root_spec = {
  "lsp",
  { ".git", "go.mod", "go.work", "Cargo.toml", "package.json", "pyproject.toml", "Makefile" },
  "cwd",
}

-- ─── 外观 ────────────────────────────────────────────────
opt.number = true
opt.relativenumber = true
opt.cursorline = false            -- Easy-Vim 默认不亮当前行
opt.scrolloff = 5
opt.sidescrolloff = 5
opt.signcolumn = "yes"            -- 诊断/断点标志不挤动文字
opt.termguicolors = true
opt.showcmd = true
opt.laststatus = 3                -- 全局状态栏（lualine）
opt.cmdheight = 1
opt.winblend = 0                  -- 浮窗保持实色
opt.pumblend = 0                  -- 补全菜单保持实色
opt.pumheight = 12

opt.breakindent = true
opt.linebreak = true
opt.wrap = true
opt.smoothscroll = true           -- 替代 vim-smoothie

-- ─── 缩进 ────────────────────────────────────────────────
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.autoindent = true

-- ─── 搜索 ────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- ─── 编辑体验 ────────────────────────────────────────────
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.hidden = true
opt.swapfile = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("state") .. "/undo"
opt.undolevels = 100000
opt.history = 1000
opt.updatetime = 300
opt.timeoutlen = 500
opt.ttimeout = true
opt.ttimeoutlen = 10
opt.virtualedit = "block"
opt.nrformats:remove("octal")

opt.wildmenu = true
opt.wildignorecase = true
opt.wildmode = "longest:full,full"
opt.wildoptions = "pum"

opt.splitright = true
opt.splitbelow = true

opt.shortmess:append("c")
opt.diffopt:append({ "algorithm:patience", "linematch:60" })

-- 撤销目录
vim.fn.mkdir(opt.undodir:get()[1] or vim.fn.stdpath("state") .. "/undo", "p")

-- ─── 兼容保护（Vim 有、Neovim 可能没有的选项）──────────────
local function try_set(name, value)
  pcall(function()
    opt[name] = value
  end)
end
try_set("pumwidth", 20)
try_set("mousemodel", "popup")
try_set("display", "lastline")

-- ─── 主题 / 语言 ─────────────────────────────────────────
g.crow_colorscheme = "catppuccin-mocha"
g.crow_transparent = true
g.rust_clip_command = "wl-copy"
g.rustfmt_autosave = 0            -- 统一交给 conform

-- ─── 禁用不需要的 provider ───────────────────────────────
g.loaded_python3_provider = 0
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0

-- ─── 保证关键选项不被 LazyVim 覆盖 ───────────────────────
-- 重要：LazyVim 自带 lua/lazyvim/config/options.lua，它在 lazy.setup() 时才执行，
-- 比本文件**晚**，会把这些值改回去：
--   scrolloff=4 / sidescrolloff=8 / pumheight=10 / updatetime=200
-- 所以光在这里设没用，真正的写回在 config/lazy.lua 结尾（LazyVim 加载之后）
-- 由 require("crow.options").enforce() 完成。
--
-- 这里先按 Easy-Vim 的值设一遍，保证插件初始化阶段看到的就是对的。
opt.scrolloff = 5
opt.sidescrolloff = 5
opt.pumheight = 12
opt.updatetime = 300
