-- ═══════════════════════════════════════════════════════════
-- PLUGINS - snacks.nvim (Dashboard Configuration)
-- ═══════════════════════════════════════════════════════════
--
-- Configures the snacks.nvim dashboard with a custom ASCII art header
-- and integrates LazyVim's picker as the default file/command picker.

-- ─── ASCII Art Header ──────────────────────────────────────
-- 「CrowNvim」两行式大字（最大宽度 35 列），盒子字符绘制。
-- 用两行而不是一行，是为了在窄终端（80 列）里也能完整显示，
-- 不会被 dashboard 折行成乱码。
local header = [[
 ██████╗██████╗  ██████╗ ██╗    ██╗
██╔════╝██╔══██╗██╔═══██╗██║    ██║
██║     ██████╔╝██║   ██║██║ █╗ ██║
██║     ██╔══██╗██║   ██║██║███╗██║
╚██████╗██║  ██║╚██████╔╝╚███╔███╔╝
 ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝
███╗   ██╗██╗   ██╗██╗███╗   ███╗
████╗  ██║██║   ██║██║████╗ ████║
██╔██╗ ██║██║   ██║██║██╔████╔██║
██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
]]

-- ─── 本机 AI 状态 section ──────────────────────────────────
-- snacks 的 dashboard 支持自定义 section：
--   往 snacks.dashboard.sections 里注册同名函数即可，
--   返回值格式与内置 startup 一致：{ align = ..., text = { {文字, hl=...}, ... } }
--
-- 这里探测本机 Ollama（qwen2.5-coder:3b）是否在线，让启动页一眼看到
-- 代码分析功能能不能用；离线时给出启动命令提示。
local MODEL = "qwen2.5-coder:3b"

local function ollama_online()
  if vim.fn.executable("curl") == 0 then
    return false, "未安装 curl"
  end
  -- 快速探活：0.5 秒超时，不阻塞启动
  local out = vim.fn.system({ "curl", "-s", "--max-time", "0.5", "http://127.0.0.1:11434/api/tags" })
  if vim.v.shell_error ~= 0 or type(out) ~= "string" or out == "" then
    return false, nil
  end
  -- 用 JSON 解析而不是字符串匹配：
  -- tags 接口返回 {"models":[{"name": "...", "model": "..."}, ...]}
  local ok, data = pcall(vim.json.decode, out)
  if not ok or type(data) ~= "table" or type(data.models) ~= "table" then
    -- 解析失败时退回字符串匹配（兼容不同的 ollama 版本）
    return true, out:find(MODEL, 1, true) and nil or ("缺少模型 " .. MODEL)
  end
  for _, m in ipairs(data.models) do
    -- 模型名可能是 "qwen2.5-coder:3b" 或 "qwen2.5-coder:3b-instruct-q4_K_M"
    local name = m.name or m.model or ""
    if name == MODEL or name:sub(1, #MODEL) == MODEL.."-" then
      return true, nil
    end
  end
  return true, "缺少模型 " .. MODEL
end

local registered = false

local function register_ai_section()
  if registered then
    return
  end
  local ok, Snacks = pcall(require, "snacks")
  if not ok then
    return
  end
  registered = true

  Snacks.dashboard.sections.ai = function(opts)
    opts = opts or {}
    local online, issue = ollama_online()
    local icon = opts.icon or " "
    local parts
    if online and not issue then
      parts = {
        { icon .. "AI ", hl = "footer" },
        { MODEL, hl = "special" },
        { " 在线 · ", hl = "footer" },
        { "<leader>oa", hl = "special" },
        { " 解释代码", hl = "footer" },
      }
    elseif issue then
      parts = {
        { icon .. "AI ", hl = "footer" },
        { issue, hl = "DiagnosticWarn" },
        { " · ollama pull " .. MODEL, hl = "footer" },
      }
    else
      parts = {
        { icon .. "AI ", hl = "footer" },
        { "离线", hl = "DiagnosticError" },
        { " · 运行 ", hl = "footer" },
        { "ollama serve", hl = "special" },
        { " 后可用", hl = "footer" },
      }
    end
    return { align = "center", text = parts, padding = 1 }
  end
end

return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        -- ─── Custom Picker ───────────────────────────────────
        -- Overrides the default dashboard picker with LazyVim's
        -- unified picker (snacks picker / telescope depending on config).
        -- 'cmd' is the picker command (e.g. "files", "oldfiles")
        -- and 'opts' are forwarded as picker options.
        pick = function(cmd, opts)
          return LazyVim.pick.picker(cmd, opts)()
        end,

        -- ─── Header ──────────────────────────────────────────
        -- Assigns the ASCII art defined above as the dashboard header.
        -- Displayed centered at the top of the dashboard on startup.
        header = header,
      },

      -- ─── Sections ──────────────────────────────────────────
      -- header → 本机 AI 状态 → 快捷键 → 启动耗时
      sections = {
        { section = "header", padding = 2 },
        { section = "ai" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },

  -- ─── 只注册自定义 section，绝不定义 config ─────────────────
  -- 重要：lazy.nvim 用原型链合并同一个插件的多个 spec
  -- （meta.lua 里 setmetatable(fragment.spec, { __index = super })），
  -- 后加载的 spec 里如果定义了 config，会**遮蔽**先前的 config。
  -- LazyVim 的 snacks spec 里 config = function() require("snacks").setup(opts) end，
  -- 这里一旦写 config，setup 就永远不执行 —— 表现为：
  --   欢迎页没了、picker 不工作、通知不显示（snacks.did_setup 一直是 false）。
  -- 所以只在 init 里注册 section（init 不会遮蔽任何东西）。
  init = function()
    register_ai_section()
  end,
}
