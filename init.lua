-- ═══════════════════════════════════════════════════════════
-- Easy-Nvim 入口
-- ═══════════════════════════════════════════════════════════
-- 加载顺序（与 LazyVim 官方模板一致，顺序很重要）：
--   1. options  —— 选项必须在插件加载前设置，否则会被默认值覆盖
--      neovide  —— 仅在 Neovide GUI 中生效的字体 / 缩放 / 动画设置
--   2. crow     —— 公共函数、自定义命令、主题增强
--   3. keymaps  —— 快捷键
--   4. autocmds —— 自动命令
--   5. lazy     —— 插件管理器（最后启动）
--
-- 注意：LazyVim 不会自动 require 这几个模块，必须在这里显式调用。
-- 这份 init.lua 原先漏了 1/3/4，导致 config/ 下的选项、快捷键、自动命令
-- 全都没有生效（表现为 <leader>D、<F6>、gd 等都没有映射）。

-- ─── 版本 ───────────────────────────────────────────────────
-- 与仓库根目录的 VERSION 文件保持一致；:Doctor 会显示这个值。
vim.g.crow_version = "v1.1.1"

-- ─── 选项（必须在 lazy.nvim / LazyVim 之前）────────────────
require("config.options")

-- ─── Neovide GUI 适配（终端 nvim 自动跳过）──────────────────
require("config.neovide")

-- ─── Easy-Nvim 公共层（自定义命令 / 主题增强 / AI 模型注册表）──
require("crow").setup()

-- AI 模型注册表：:CrowModel、<leader>om / <leader>oM 在启动阶段就可用，
-- 不依赖 codecompanion / minuet 是否已加载。
require("crow.models").setup()

-- Python 工具链自动探测（:CrowPython）；插件层见 lua/plugins/python.lua
require("crow.lang.python").setup()

-- crow.ai 由功能开关控制（scripts/features.sh），关掉后
-- :CrowExplain / :CrowReview / :CrowAsk 与 <leader>oa/or/oq/oi 都不注册。
if require("crow.features").on("crow_ai") then
  require("crow.ai").setup()
end

-- ─── 快捷键 ─────────────────────────────────────────────────
require("config.keymaps")

-- ─── 自动命令 ───────────────────────────────────────────────
require("config.autocmds")

-- ─── bootstrap lazy.nvim, LazyVim 与插件 ─────────────────────
require("config.lazy")
