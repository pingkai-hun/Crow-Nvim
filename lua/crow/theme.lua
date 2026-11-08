-- ============================================================================
-- crow.theme —— 主题增强 / 透明背景 / lualine 胶囊调色板
-- ============================================================================
-- 移植自 ~/.vim/autoload/crow/util.vim（Vim9）。只改 highlight、不执行
-- colorscheme，所以可以被 ColorScheme 事件安全地重复调用。
--
-- 原则和 Vim 版一致：配色已经定义好的语法组一律不动，只补它漏掉或压成
-- 同色的几处；UI 组按语义色板重算，切换配色时自动跟着变。

local palette = require("crow.palette")

local M = {}

-- ── 工具 ────────────────────────────────────────────────────────────────
local function hl(name)
  local ok, info = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and info or {}
end

local function hex(n)
  if type(n) ~= "number" then
    return nil
  end
  return string.format("#%06x", n)
end

-- 取当前配色里某个语法组的有效前景色（已解析 link）
local function fg_of(name)
  return hex(hl(name).fg)
end

local function set(list)
  for _, item in ipairs(list) do
    local name = item.name
    item.name = nil
    pcall(vim.api.nvim_set_hl, 0, name, item)
  end
end

-- ── 1. 语法增强 ────────────────────────────────────────────────────────
local VIM_DEFAULTS = {
  Comment = "#80a0ff",
  Constant = "#ffa0a0",
  Special = "#ffa500",
  Identifier = "#40ffff",
  Statement = "#ffff60",
  PreProc = "#ff80ff",
  Type = "#60ff60",
  Underlined = "#80a0ff",
}

local function syntax_foreground(group, pal)
  local fg = fg_of(group)
  if fg and fg ~= "#000000" then
    return fg
  end
  local fallback = {
    Comment = "grey1",
    Constant = "aqua",
    Special = "yellow",
    Identifier = "blue",
    Statement = "red",
    PreProc = "purple",
    Type = "yellow",
    Normal = "fg0",
    Underlined = "blue",
  }
  if VIM_DEFAULTS[group] then
    return VIM_DEFAULTS[group]
  end
  return pal[fallback[group] or "fg0"]
end

-- ── 2. 按当前色板应用主题 ──────────────────────────────────────────────
function M.apply()
  local pal = palette.get()
  local C = function(key)
    return pal[key]
  end

  -- (1) PreCondit：有些配色把它和 PreProc 压成同色
  local preproc = syntax_foreground("PreProc", pal)
  local precondit = fg_of("PreCondit")
  if preproc and precondit and preproc == precondit then
    set({ { name = "PreCondit", fg = C("purple") } })
  end

  -- (2) Constant：tokyonight 把 Constant / Identifier 都设成 orange
  local ident, const = syntax_foreground("Identifier", pal), syntax_foreground("Constant", pal)
  if ident and const and ident == const then
    set({ { name = "Constant", fg = C("aqua") } })
  end

  -- (3) Todo：配色用 reverse 时会变成刺眼的反色块
  local todo = hl("Todo")
  if todo.reverse then
    set({ { name = "Todo", fg = C("bg0"), bg = C("yellow"), bold = true } })
  end

  -- ── UI：透明背景下的可读性 ────────────────────────────────────────
  set({
    { name = "LineNr", fg = C("bg5"), bg = "NONE" },
    { name = "CursorLineNr", fg = C("yellow"), bg = "NONE", bold = true },
    { name = "CursorLine", bg = "NONE" },
    { name = "WinSeparator", fg = C("bg3"), bg = "NONE" },
    { name = "VertSplit", fg = C("bg3"), bg = "NONE" },
    { name = "Search", fg = C("bg0"), bg = C("yellow") },
    { name = "IncSearch", fg = C("bg0"), bg = C("orange"), bold = true },
    { name = "CurSearch", fg = C("bg0"), bg = C("orange"), bold = true },
    { name = "MatchParen", fg = C("bg0"), bg = C("aqua"), bold = true },
    { name = "Visual", fg = "NONE", bg = C("bg3") },
    { name = "Pmenu", fg = C("fg0"), bg = C("bg1") },
    { name = "PmenuSel", fg = C("bg0"), bg = C("blue"), bold = true },
    { name = "PmenuSbar", bg = C("bg1") },
    { name = "PmenuThumb", bg = C("grey0") },
    { name = "NormalFloat", fg = C("fg0"), bg = C("bg0") },
    { name = "FloatBorder", fg = C("grey0"), bg = C("bg0") },
    { name = "FloatTitle", fg = C("blue"), bg = C("bg0"), bold = true },
    { name = "FloatShadow", bg = C("bg0") },
    { name = "PmenuBorder", fg = C("grey0"), bg = C("bg1") },
    { name = "PmenuShadow", bg = C("bg0") },
    -- 诊断标志只染颜色，不铺底色
    { name = "DiagnosticSignError", fg = C("red"), bg = "NONE" },
    { name = "DiagnosticSignWarn", fg = C("yellow"), bg = "NONE" },
    { name = "DiagnosticSignInfo", fg = C("blue"), bg = "NONE" },
    { name = "DiagnosticSignHint", fg = C("aqua"), bg = "NONE" },
    -- 行尾诊断消息同理：只保留前景色。
    -- 默认主题会给这组铺一块底色，长消息会把代码盖住，看起来像弹窗糊在行上。
    { name = "DiagnosticVirtualTextError", fg = C("red"), bg = "NONE" },
    { name = "DiagnosticVirtualTextWarn", fg = C("yellow"), bg = "NONE" },
    { name = "DiagnosticVirtualTextInfo", fg = C("blue"), bg = "NONE" },
    { name = "DiagnosticVirtualTextHint", fg = C("aqua"), bg = "NONE" },
    -- 兼容 coc 时代留下的组名（不影响 Neovim）
    { name = "CocErrorSign", fg = C("red"), bg = "NONE" },
    { name = "CocWarningSign", fg = C("yellow"), bg = "NONE" },
    { name = "CocInfoSign", fg = C("blue"), bg = "NONE" },
    { name = "CocHintSign", fg = C("aqua"), bg = "NONE" },
    -- AI 幽灵文本：比注释还淡一档
    { name = "MinuetVirtualText", fg = C("grey1"), bg = "NONE", italic = true },
    { name = "OllamaSuggestion", fg = C("grey1"), bg = "NONE", italic = true },
  })
end

-- ── 3. 半透明背景 ──────────────────────────────────────────────────────
-- 终端负责整体透明度，Neovim 侧把这些组的底色清成 NONE 才能透出终端背景。
-- 补全菜单 / 浮动窗口保持实色，否则叠字会糊。
function M.transparent()
  if vim.g.crow_transparent == false then
    return
  end
  local keep = { ColorColumn = true }
  local groups = {
    "Normal",
    "NormalNC",
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "LineNrAbove",
    "LineNrBelow",
    "CursorLine",
    "CursorLineSign",
    "CursorLineFold",
    "FoldColumn",
    "EndOfBuffer",
    "ColorColumn",
    "StatusLineNC",
    "TabLineFill",
  }
  for _, group in ipairs(groups) do
    if not keep[group] then
      local info = hl(group)
      if info.bg ~= nil then
        pcall(vim.api.nvim_set_hl, 0, group, { bg = "NONE" })
      end
    end
  end

  local pal = palette.get()
  set({
    { name = "Pmenu", bg = pal.bg1 },
    { name = "PmenuSbar", bg = pal.bg1 },
    { name = "NormalFloat", bg = pal.bg1 },
    { name = "FloatBorder", bg = pal.bg1 },
    { name = "PmenuBorder", fg = pal.grey0, bg = pal.bg1 },
    { name = "PmenuShadow", bg = pal.bg0 },
  })
end

-- ── 4. lualine 胶囊主题 ────────────────────────────────────────────────
-- 对应 Easy-Vim 的 airline 分段：
--   a = 左圆头、b = 模式胶囊、c = 文件名/诊断、z = 位置 + 右圆头
-- 数据段一律透明，只有模式胶囊是实色。
function M.lualine_theme()
  local pal = palette.get()
  local ink = pal.bg0
  local fg = pal.fg0
  local muted = pal.grey2

  local function mode(accent, inactive)
    return {
      a = { fg = accent, bg = "NONE", bold = true },
      b = {
        fg = inactive and muted or ink,
        bg = inactive and "NONE" or accent,
        bold = not inactive,
      },
      c = { fg = fg, bg = "NONE" },
      x = { fg = fg, bg = "NONE" },
      y = { fg = muted, bg = "NONE" },
      z = { fg = fg, bg = "NONE" },
    }
  end

  return {
    normal = mode(pal.blue),
    insert = mode(pal.green),
    visual = mode(pal.purple),
    replace = mode(pal.red),
    command = mode(pal.orange),
    terminal = mode(pal.aqua),
    inactive = mode(muted, true),
  }
end

-- ── 5. 初始化 ──────────────────────────────────────────────────────────
function M.setup()
  local group = vim.api.nvim_create_augroup("CrowTheme", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      vim.schedule(M.apply)
      vim.schedule(M.transparent)
    end,
  })
  vim.schedule(function()
    M.apply()
    M.transparent()
  end)
end

return M
