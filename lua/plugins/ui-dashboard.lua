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

-- ─── AI 状态 section ───────────────────────────────────────
-- 启动页只显示「当前全局模型 + 补全状态」，不主动请求云端（避免拖慢启动、
-- 也不在启动阶段消耗额度）。只有补全走本机时，才去探测 Ollama 是否在线。
local models = require("crow.models")

local function ollama_online(base_url, model)
  if vim.fn.executable("curl") == 0 then
    return false, "未安装 curl"
  end
  local out = vim.fn.system({ "curl", "-s", "--max-time", "0.5", base_url .. "/api/tags" })
  if vim.v.shell_error ~= 0 or type(out) ~= "string" or out == "" then
    return false, nil
  end
  local ok, data = pcall(vim.json.decode, out)
  if not ok or type(data) ~= "table" or type(data.models) ~= "table" then
    return true, out:find(model, 1, true) and nil or ("缺少模型 " .. model)
  end
  for _, m in ipairs(data.models) do
    local name = m.name or m.model or ""
    if name == model or name:sub(1, #model) == model .. "-" then
      return true, nil
    end
  end
  return true, "缺少模型 " .. model
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
    local icon = opts.icon or " "
    local chat = models.resolve("chat")
    local complete = models.resolve("complete")

    local parts = {
      { icon .. "AI ", hl = "footer" },
      { chat.model, hl = "special" },
      { " · " .. chat.provider_label, hl = "footer" },
      { " · 补全 ", hl = "footer" },
    }

    if complete.protocol == "ollama" then
      local online, issue = ollama_online(models.base_url(complete.provider_name), complete.model)
      if online and not issue then
        vim.list_extend(parts, {
          { complete.model .. " 在线", hl = "footer" },
        })
      elseif issue then
        vim.list_extend(parts, {
          { issue, hl = "DiagnosticWarn" },
          { " · ollama pull " .. complete.model, hl = "footer" },
        })
      else
        vim.list_extend(parts, {
          { "Ollama 离线", hl = "DiagnosticError" },
          { " · ollama serve", hl = "special" },
        })
      end
    else
      vim.list_extend(parts, {
        { complete.model, hl = "footer" },
      })
    end

    if chat.missing_key then
      vim.list_extend(parts, {
        { " · 缺 Key · ", hl = "DiagnosticWarn" },
        { "<leader>oK", hl = "special" },
        { " 配置", hl = "footer" },
      })
    else
      vim.list_extend(parts, {
        { " · ", hl = "footer" },
        { "<leader>om", hl = "special" },
        { " 切换", hl = "footer" },
        { " · ", hl = "footer" },
        { "<leader>oK", hl = "special" },
        { " 配置", hl = "footer" },
      })
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
      -- header → AI 状态 → 快捷键 → 启动耗时
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
