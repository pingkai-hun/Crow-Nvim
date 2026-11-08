-- ═══════════════════════════════════════════════════════════
-- lualine —— Easy-Vim 的胶囊状态栏（移植自 airline 布局并扩充）
-- ═══════════════════════════════════════════════════════════
-- 布局（和 Vim 版一一对应，右侧额外补充了信息）：
--   a = U+E0B6 左圆头（只有字形着色，背景透明）
--   b = 模式胶囊（实色底）
--   c = 文件图标 + 文件名 + 修改标记 + 只读 + 分支 + diff + 文档符号
--   x = 【新增】AI 补全状态 · LSP 客户端 · 诊断数
--   y = 【新增】文件格式(ff) · 编码(enc) · 文件类型(ft) · 文件大小
--   z = 进度 % · 行列位置 + U+E0B4 右圆头
--
-- 整条线只在最左 / 最右各放一个圆头，段之间不插三角分隔符，
-- 避免 Vim 版里出现过的「多个圆头叠在一起」错位问题。
--
-- 宽窗口才显示的信息（enc / ft / filesize / AI 状态）都用 cond 控制，
-- 窄分屏下自动收起，不会把文件名挤没。

local function cap_left()
  return "\u{E0B6}"
end

local function cap_right()
  return "\u{E0B4}"
end

-- ─── 自定义组件 ─────────────────────────────────────────────
-- 1. LSP 客户端：显示当前 buffer 挂着哪些语言服务器（coc 时代的状态栏提示）
local function lsp_clients()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    return ""
  end
  local names = {}
  for _, c in ipairs(clients) do
    -- 只取名字里最关键的一段：pyright / clangd / rust_analyzer → rust-analyzer
    names[#names + 1] = (c.name:gsub("_", "-"))
  end
  return " " .. table.concat(names, ",")
end

-- 2. AI 补全状态：minuet 正在请求 / 已给出建议时提示（对应 vim-ollama 的幽灵文本）
local function ai_status()
  -- minuet 的虚拟文本高亮组存在且当前行有内容 → 说明有未接受的建议
  local has_virt = vim.fn.hlexists("MinuetVirtualText") == 1
  local visible = false
  if has_virt then
    local ns = vim.api.nvim_get_namespaces()
    for name in pairs(ns) do
      if name:lower():find("minuet") then
        local marks = vim.api.nvim_buf_get_extmarks(0, ns[name], 0, -1, {})
        visible = #marks > 0
        if visible then
          break
        end
      end
    end
  end
  if visible then
    return "  AI"
  end
  -- 没有建议时，只要 provider 在跑就给个暗色的点，提示 AI 已就绪
  if package.loaded["minuet"] then
    return "  AI"
  end
  return ""
end

-- 3. 当前 Python 虚拟环境：直接复用 venv-selector 的状态栏渲染，
--    这样显示的文本由它的 options.statusline_func.lualine 决定。
local function venv_status()
  local ok, mod = pcall(require, "venv-selector.statusline.lualine")
  if not ok then
    return ""
  end
  local text = mod.render()
  return text ~= "" and (" " .. text) or ""
end

-- 4. 文件大小：只在 > 1KB 时显示，避免小文件占位
local function filesize()
  local ok, stat = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(0))
  if not ok or not stat or stat.size < 1024 then
    return ""
  end
  local size = stat.size
  if size > 1024 * 1024 then
    return string.format("%.1fM", size / 1024 / 1024)
  end
  return string.format("%.0fK", size / 1024)
end

-- 5. 是否宽窗口：窄分屏里把次要信息收起来
local function wide()
  return vim.o.columns >= 120
end

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = function(_, opts)
      opts = opts or {}

      -- Trouble 文档符号（可选）
      local has_trouble, trouble = pcall(require, "trouble")
      local symbols
      if has_trouble then
        symbols = trouble.statusline({
          mode = "lsp_document_symbols",
          groups = {},
          title = false,
          filter = { range = true },
          format = "{kind_icon}{symbol.name:Normal}",
          hl_group = "lualine_c_normal",
        })
      end

      local c_section = {
        {
          "filename",
          path = 1,
          symbols = {
            modified = " ●",
            readonly = " ",
            unnamed = "[No Name]",
          },
          padding = { right = 1, left = 2 },
        },
        {
          "branch",
          icon = "",
          padding = { right = 1, left = 1 },
        },
        {
          "diff",
          symbols = { added = " ", modified = " ", removed = " " },
          padding = { right = 1, left = 1 },
        },
      }
      if symbols then
        c_section[#c_section + 1] = {
          symbols.get,
          cond = symbols.has,
          padding = { right = 1, left = 1 },
        }
      end

      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        theme = function()
          return require("crow.theme").lualine_theme()
        end,
        component_separators = "",
        section_separators = "",
        globalstatus = true,
        disabled_filetypes = {
          statusline = { "dashboard", "alpha", "starter" },
        },
      })

      opts.sections = {
        lualine_a = {
          { cap_left, padding = { left = 0, right = 0 } },
        },
        lualine_b = {
          {
            "mode",
            padding = { left = 1, right = 2 },
          },
        },
        lualine_c = c_section,
        lualine_x = {
          -- AI 补全状态（有建议时高亮，否则暗色）
          {
            ai_status,
            cond = wide,
            color = { fg = "#a6e3a1" },
            padding = { left = 0, right = 1 },
          },
          -- 挂在当前 buffer 上的语言服务器
          {
            lsp_clients,
            cond = function()
              return wide() and #vim.lsp.get_clients({ bufnr = 0 }) > 0
            end,
            color = { fg = "#89b4fa" },
            padding = { left = 0, right = 1 },
          },
          -- 当前 Python 虚拟环境（只有 python buffer 且宽窗口才显示）
          {
            venv_status,
            cond = function()
              return wide() and vim.bo.filetype == "python"
            end,
            color = { fg = "#a6e3a1" },
            padding = { left = 0, right = 1 },
          },
          -- 诊断：错误 / 警告 / 提示 / 信息，按级别着色
          {
            "diagnostics",
            sources = { "nvim_lsp", "nvim_diagnostic" },
            symbols = { error = "●", warn = "▲", info = "●", hint = "○" },
            colored = true,
            update_in_insert = false,
            padding = { right = 1, left = 1 },
          },
        },
        lualine_y = {
          -- 文件编码
          {
            "encoding",
            cond = wide,
            padding = { right = 1, left = 1 },
          },
          -- 换行格式（unix / dos / mac）
          {
            "fileformat",
            symbols = { unix = " ", dos = " ", mac = " " },
            padding = { right = 1, left = 1 },
          },
          -- 文件类型
          {
            "filetype",
            cond = wide,
            padding = { right = 1, left = 1 },
          },
          -- 文件大小（> 1KB 才显示）
          {
            filesize,
            cond = wide,
            padding = { right = 1, left = 1 },
          },
          -- 进度百分比
          {
            "progress",
            padding = { right = 1, left = 1 },
          },
        },
        lualine_z = {
          { "location", padding = { right = 1, left = 2 } },
          { cap_right, padding = { left = 0, right = 0 } },
        },
      }

      -- 非活动窗口：只留文件名和行列，保持干净
      opts.inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
          { "filename", path = 1, padding = { left = 2 } },
          { "branch", icon = "" },
        },
        lualine_x = {
          {
            "diagnostics",
            symbols = { error = "●", warn = "▲", info = "●", hint = "○" },
            colored = true,
          },
        },
        lualine_y = {},
        lualine_z = {
          { "location", padding = { right = 1 } },
        },
      }

      opts.extensions = { "neo-tree", "lazy", "mason", "trouble", "quickfix" }

      return opts
    end,
  },
}
