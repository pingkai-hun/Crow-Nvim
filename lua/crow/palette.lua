-- ============================================================================
-- crow.palette —— 语义色板（Easy-Vim 的 crow#model / crow#palette 移植）
-- ============================================================================
-- 主题增强只引用语义名（bg0 / grey1 / red …），具体颜色由当前配色决定。
-- 这样换主题时行号、补全菜单、搜索、诊断标志等不会花屏。
--
-- 新增配色：在 M.tables 里照着一张表补即可，至少要有
-- bg0..bg3、bg5、fg0、grey0..grey2、red/orange/yellow/green/aqua/blue/purple。

local M = {}

-- 与 catppuccin/vim 使用同一组真实色值；Neovim 的 colors_name 是连字符，
-- Vim 的是下划线，两种键都登记，便于从 Vim 配置直接迁移。
local mocha = {
  bg0 = "#181825",
  bg1 = "#1e1e2e",
  bg2 = "#313244",
  bg3 = "#45475a",
  bg5 = "#585b70",
  fg0 = "#cdd6f4",
  grey0 = "#6c7086",
  grey1 = "#9399b2",
  grey2 = "#a6adc8",
  red = "#f38ba8",
  orange = "#fab387",
  yellow = "#f9e2af",
  green = "#a6e3a1",
  aqua = "#89dceb",
  blue = "#89b4fa",
  purple = "#cba6f7",
}

local macchiato = {
  bg0 = "#1e2030",
  bg1 = "#24273a",
  bg2 = "#363a4f",
  bg3 = "#494d64",
  bg5 = "#5b6078",
  fg0 = "#cad3f5",
  grey0 = "#6e738d",
  grey1 = "#939ab7",
  grey2 = "#a5adcb",
  red = "#ed8796",
  orange = "#f5a97f",
  yellow = "#eed49f",
  green = "#a6da95",
  aqua = "#91d7e3",
  blue = "#8aadf4",
  purple = "#c6a0f6",
}

local frappe = {
  bg0 = "#292c3c",
  bg1 = "#303446",
  bg2 = "#414559",
  bg3 = "#51576d",
  bg5 = "#626880",
  fg0 = "#c6d0f5",
  grey0 = "#737994",
  grey1 = "#949cbb",
  grey2 = "#a5adce",
  red = "#e78284",
  orange = "#ef9f76",
  yellow = "#e5c890",
  green = "#a6d189",
  aqua = "#99d1db",
  blue = "#8caaee",
  purple = "#ca9ee6",
}

local latte = {
  bg0 = "#e6e9ef",
  bg1 = "#eff1f5",
  bg2 = "#ccd0da",
  bg3 = "#bcc0cc",
  bg5 = "#acb0be",
  fg0 = "#4c4f69",
  grey0 = "#9ca0b0",
  grey1 = "#7c7f93",
  grey2 = "#6c6f85",
  red = "#d20f39",
  orange = "#fe640b",
  yellow = "#df8e1d",
  green = "#40a02b",
  aqua = "#04a5e5",
  blue = "#1e66f5",
  purple = "#8839ef",
}

local gruvbox = {
  bg0 = "#282828",
  bg1 = "#32302f",
  bg2 = "#3c3836",
  bg3 = "#45403d",
  bg5 = "#5a524c",
  fg0 = "#654735",
  grey0 = "#7c6f64",
  grey1 = "#928374",
  grey2 = "#a89984",
  red = "#c14a4a",
  orange = "#c35e0a",
  yellow = "#b47109",
  green = "#6c782e",
  aqua = "#4c7a5d",
  blue = "#45707a",
  purple = "#945e80",
}

local tokyonight = {
  bg0 = "#1a1b26",
  bg1 = "#232433",
  bg2 = "#2a2b3d",
  bg3 = "#32344a",
  bg5 = "#3b3d57",
  fg0 = "#a9b1d6",
  grey0 = "#444b6a",
  grey1 = "#444b6a",
  grey2 = "#444b6a",
  red = "#f7768e",
  orange = "#ff9e64",
  yellow = "#e0af68",
  green = "#9ece6a",
  aqua = "#7aa2f7",
  blue = "#7aa2f7",
  purple = "#ad8ee6",
}

M.tables = {
  ["catppuccin-mocha"] = mocha,
  catppuccin_mocha = mocha,
  catppuccin = mocha,
  ["catppuccin-macchiato"] = macchiato,
  catppuccin_macchiato = macchiato,
  ["catppuccin-frappe"] = frappe,
  catppuccin_frappe = frappe,
  ["catppuccin-latte"] = latte,
  catppuccin_latte = latte,
  ["gruvbox-material"] = gruvbox,
  ["tokyonight-moon"] = tokyonight,
  ["tokyonight-night"] = tokyonight,
  ["tokyonight-storm"] = tokyonight,
  ["tokyonight-day"] = tokyonight,
  tokyonight = tokyonight,
}

--- 当前配色对应的语义色板。未登记的配色用 Catppuccin Mocha 兜底。
---@return table<string, string> palette 带 known/name 两个附加字段
function M.get()
  local name = vim.g.colors_name or ""
  local base = M.tables[name]
  local result = vim.deepcopy(base or mocha)
  result.known = base ~= nil
  result.name = name
  return result
end

--- 取单个语义色；不存在返回空串。
function M.color(name)
  return M.get()[name] or ""
end

--- 已登记的配色名（给 :Theme 补全用）。
function M.names()
  local seen, out = {}, {}
  for name in pairs(M.tables) do
    if not seen[name] then
      seen[name] = true
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

return M
