-- ═══════════════════════════════════════════════════════════
-- config.neovide —— Neovide GUI 适配（只在 Neovide 中生效）
-- ═══════════════════════════════════════════════════════════
-- Neovide 没有独立的配置文件：所有 GUI 可调项都通过
-- vim.g.neovide_* 和 guifont 注入 Neovim，所以统一写在这里，
-- 跟随 ~/.config/nvim 一起保存 / 版本管理。
--
-- 终端里的 nvim 会因为 vim.g.neovide == nil 直接 return，
-- 选项、快捷键、外观完全不受影响。
--
-- 常用操作：
--   <C-=>  放大        <C-->  缩小        <C-0>  复位
--   <F11>  全屏切换
--   缩放值写入 stdpath("state")/neovide/scale，重启后保留。

if not vim.g.neovide then
  return
end

-- ─── 字体 ────────────────────────────────────────────────
-- 和 kitty（Maple Mono NF CN 11）保持一致；该字体自带中文，
-- 不需要额外的 CJK fallback。想改字号直接改 :h14。
vim.o.guifont = "Maple Mono NF CN:h14"
vim.o.linespace = 0

-- ─── 输入法 ──────────────────────────────────────────────
-- 关键：不开启的话 fcitx5 在插入模式下无法正常上屏中文。
vim.g.neovide_input_ime = true

-- ─── 缩放（持久化）───────────────────────────────────────
local scale_file = vim.fn.stdpath("state") .. "/neovide/scale"

local function read_scale()
  local f = io.open(scale_file, "r")
  if not f then
    return 1.0
  end
  local raw = f:read("*l")
  f:close()
  local n = tonumber(raw)
  if not n then
    return 1.0
  end
  -- 防止手改坏文件后窗口大到没法用
  return math.max(0.5, math.min(3.0, n))
end

local function write_scale(value)
  vim.fn.mkdir(vim.fn.fnamemodify(scale_file, ":h"), "p")
  local f = io.open(scale_file, "w")
  if not f then
    return
  end
  f:write(string.format("%.2f\n", value))
  f:close()
end

local function set_scale(value)
  value = math.max(0.5, math.min(3.0, math.floor(value * 10 + 0.5) / 10))
  vim.g.neovide_scale_factor = value
  write_scale(value)
end

local function bump_scale(delta)
  set_scale((vim.g.neovide_scale_factor or 1.0) + delta)
end

vim.g.neovide_scale_factor = read_scale()

for _, mode in ipairs({ "n", "v" }) do
  vim.keymap.set(mode, "<C-=>", function()
    bump_scale(0.1)
  end, { desc = "Neovide：放大" })
  vim.keymap.set(mode, "<C-+>", function()
    bump_scale(0.1)
  end, { desc = "Neovide：放大" })
  vim.keymap.set(mode, "<C-->", function()
    bump_scale(-0.1)
  end, { desc = "Neovide：缩小" })
  vim.keymap.set(mode, "<C-0>", function()
    set_scale(1.0)
  end, { desc = "Neovide：缩放复位" })
end

-- ─── 全屏 ────────────────────────────────────────────────
vim.keymap.set({ "n", "v", "t" }, "<F11>", function()
  vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
end, { desc = "Neovide：全屏切换" })

-- ─── 外观 ────────────────────────────────────────────────
-- 与 kitty 的 background_opacity 0.82 接近，配合 catppuccin 透明背景。
-- neovide_transparency 是旧名（0.14 起改名），这里用新名。
vim.g.neovide_opacity = 0.85
vim.g.neovide_normal_opacity = 0.85
-- 窗口模糊 / 边框目前仅 macOS 生效，Linux 上留作跨平台配置。
vim.g.neovide_window_blurred = false
vim.g.neovide_show_border = false

vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
vim.g.neovide_floating_shadow = true
vim.g.neovide_floating_z_height = 10
vim.g.neovide_light_angle_degrees = 45
vim.g.neovide_light_radius = 5
vim.g.neovide_floating_corner_radius = 0.2

-- 无边框感的留白，和终端内边距观感一致。
vim.g.neovide_padding_top = 8
vim.g.neovide_padding_bottom = 8
vim.g.neovide_padding_left = 10
vim.g.neovide_padding_right = 10

-- 记住上次的窗口尺寸 / 位置（Neovide 自己的持久化）。
vim.g.neovide_remember_window_size = true
vim.g.neovide_confirm_quit = true
vim.g.neovide_theme = "dark"

-- 标题栏跟随当前配色：默认 catppuccin-mocha，换主题时自动更新。
local function sync_title_colors()
  local ok, palette = pcall(require, "crow.palette")
  if not ok then
    return
  end
  local p = palette.get()
  vim.g.neovide_title_background_color = p.bg0
  vim.g.neovide_title_text_color = p.fg0
end

sync_title_colors()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("CrowNeovideTitle", { clear = true }),
  callback = sync_title_colors,
  desc = "Neovide：标题栏颜色跟随主题",
})

-- ─── 光标 ────────────────────────────────────────────────
vim.g.neovide_cursor_animation_length = 0.08
vim.g.neovide_cursor_short_animation_length = 0.04
vim.g.neovide_cursor_trail_size = 0.5
vim.g.neovide_cursor_animate_in_insert_mode = true
vim.g.neovide_cursor_animate_command_line = true
vim.g.neovide_cursor_unfocused_outline_width = 0.125

-- 拖影：railgun 比较克制；嫌花哨就改成 ""。
vim.g.neovide_cursor_vfx_mode = "railgun"
vim.g.neovide_cursor_vfx_opacity = 200.0
vim.g.neovide_cursor_vfx_particle_lifetime = 1.2
vim.g.neovide_cursor_vfx_particle_density = 5.0
vim.g.neovide_cursor_vfx_particle_speed = 10.0
vim.g.neovide_cursor_vfx_particle_phase = 1.5
vim.g.neovide_cursor_vfx_particle_curl = 1.0

-- ─── 滚动 / 动画 ─────────────────────────────────────────
vim.g.neovide_scroll_animation_length = 0.15
vim.g.neovide_scroll_animation_far_lines = 1
vim.g.neovide_position_animation_length = 0.1
vim.g.neovide_hide_mouse_when_typing = true

-- ─── 进度条（Neovide 0.16+，显示 LSP 加载进度）────────────
vim.g.neovide_progress_bar_enabled = true
vim.g.neovide_progress_bar_height = 3.0
vim.g.neovide_progress_bar_animation_speed = 200.0
vim.g.neovide_progress_bar_hide_delay = 0.2

-- ─── 渲染 ────────────────────────────────────────────────
vim.g.neovide_refresh_rate = 60
vim.g.neovide_refresh_rate_idle = 5
vim.g.neovide_no_idle = false
vim.g.neovide_profiler = false
