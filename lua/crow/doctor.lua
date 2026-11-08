-- ============================================================================
-- crow.doctor —— :Doctor 一键体检（Lua 移植）
-- ============================================================================
-- 把「配置里要求的」和「系统里实际有的」对一遍：
-- 语言服务器 / 格式化工具 / 插件管理器 / 主题适配 / 关键选项。
-- 结果输出到临时 buffer，方便复制和搜索。

local palette = require("crow.palette")

local M = {}

local function ok(cond)
  return cond and "✔" or "✘"
end

local function exe(name)
  return vim.fn.exepath(name)
end

local function add(lines, fmt, ...)
  lines[#lines + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt
end

local servers = {
  { "rust-analyzer", { "rust-analyzer" } },
  { "clangd", { "clangd" } },
  { "pyright", { "pyright-langserver", "pyright", "basedpyright-langserver" } },
  { "ruff (格式化)", { "ruff" } },
  { "gopls", { "gopls" } },
  { "lua-language-server", { "lua-language-server" } },
  { "vim-language-server", { "vim-language-server" } },
  { "bash-language-server", { "bash-language-server" } },
  { "typescript-language-server", { "typescript-language-server" } },
  { "omnisharp", { "OmniSharp", "omnisharp", "dotnet" } },
}

local tools = {
  { "git", { "git" } },
  { "rg", { "rg" } },
  { "fzf", { "fzf" } },
  { "goimports", { "goimports" } },
  { "dlv", { "dlv" } },
  { "staticcheck", { "staticcheck" } },
  { "stylua", { "stylua" } },
  { "shfmt", { "shfmt" } },
  { "shellcheck", { "shellcheck" } },
  { "prettier", { "prettier" } },
  { "ollama", { "ollama" } },
}

local function first_exe(cands)
  for _, name in ipairs(cands) do
    local path = exe(name)
    if path ~= "" then
      return path
    end
  end
  return nil
end

local function lsp_clients()
  local names = {}
  local okc, clients = pcall(vim.lsp.get_clients)
  if okc then
    for _, client in ipairs(clients) do
      names[#names + 1] = client.name
    end
  end
  table.sort(names)
  return names
end

function M.run()
  local lines = {}
  add(lines, "Easy-Nvim 体检报告  %s", os.date("%Y-%m-%d %H:%M:%S"))
  add(lines, ("="):rep(62))

  -- 环境
  add(lines, "")
  add(lines, "【环境】")
  add(lines, "  CrowNvim    %s", vim.g.crow_version or "unknown")
  add(lines, "  Neovim      %s", vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch)
  add(lines, "  termguicolors %s   background=%s", ok(vim.o.termguicolors), vim.o.background)
  add(lines, "  clipboard   %s   provider=%s", ok(vim.o.clipboard ~= ""), vim.fn.has("clipboard") == 1 and "builtin" or "external")
  add(lines, "  终端        %s", vim.env.TERM or "?")
  add(lines, "  插件管理器  lazy.nvim %s   插件目录: %d 个",
    ok(pcall(require, "lazy")), #vim.fn.glob(vim.fn.stdpath("data") .. "/lazy/*", false, true))

  -- 主题
  add(lines, "")
  add(lines, "【主题】")
  local pal = palette.get()
  add(lines, "  配色: %s  %s", tostring(vim.g.colors_name),
    pal.known and "（已登记 → 主题增强已适配）" or "（未登记 → 使用 Catppuccin Mocha 兜底）")
  for _, group in ipairs({ "Normal", "Comment", "Identifier", "Function", "Type", "Constant", "Pmenu", "PmenuSel", "Visual", "CursorLineNr" }) do
    local info = vim.api.nvim_get_hl(0, { name = group, link = false })
    local fg = info.fg and string.format("#%06x", info.fg) or "-"
    local bg = info.bg and string.format("#%06x", info.bg) or "-"
    add(lines, "  %-16s fg=%-9s bg=%-9s", group, fg, bg)
  end

  -- 语言服务器
  add(lines, "")
  add(lines, "【语言服务器可执行文件】")
  for _, item in ipairs(servers) do
    local path = first_exe(item[2])
    add(lines, "  %s %-26s %s", ok(path ~= nil), item[1], path or "未安装（该语言补全/诊断不可用）")
  end
  add(lines, "")
  add(lines, "【当前 buffer 的 LSP 客户端】")
  local clients = lsp_clients()
  if #clients == 0 then
    add(lines, "  （未连接；打开对应语言文件后会出现）")
  else
    for _, name in ipairs(clients) do
      add(lines, "  ✔ %s", name)
    end
  end

  -- 当前 buffer 的诊断快照
  add(lines, "")
  add(lines, "【当前 buffer 诊断】")
  local diags = vim.diagnostic.get(0)
  if #diags == 0 then
    add(lines, "  （无）")
  else
    local counts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    for _, d in ipairs(diags) do
      counts[d.severity] = (counts[d.severity] or 0) + 1
    end
    add(lines, "  E%d W%d I%d H%d（共 %d 条）", counts[1], counts[2], counts[3], counts[4], #diags)

    local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
    for i = 1, math.min(#diags, 10) do
      local d = diags[i]
      local msg = (d.message or ""):gsub("%s*\n%s*", " ")
      local code = d.code and (" [" .. tostring(d.code) .. "]") or ""
      add(lines, "  %s:%d:%d  %s%s", bufname, d.lnum + 1, d.col + 1, msg, code)
    end
    if #diags > 10 then
      add(lines, "  … 其余 %d 条见 :Trouble diagnostics（<leader>xx）", #diags - 10)
    end
  end

  -- Python 解释器：Import 报错最常见的原因就是这里选错
  if vim.bo.filetype == "python" then
    add(lines, "")
    add(lines, "【Python 解释器】")
    local root = require("crow").project_root() or vim.fn.getcwd()
    add(lines, "  项目根        %s", root)
    add(lines, "  .venv         %s", vim.uv.fs_stat(vim.fs.joinpath(root, ".venv")) and "存在" or "不存在")
    local pyright = vim.lsp.get_clients({ bufnr = 0, name = "pyright" })[1]
    local py = pyright
      and pyright.config.settings
      and pyright.config.settings.python
      and pyright.config.settings.python.pythonPath
    add(lines, "  pyright 使用  %s", py or "（未指定，回退到 PATH 中的 Python）")

    -- venv-selector 的接入状态：选中的环境会和 pyright 的 pythonPath 保持一致
    local ok_vs, vs = pcall(require, "venv-selector")
    if ok_vs then
      local selected = vs.venv()
      add(lines, "  venv-selector %s", selected and ("已选择 " .. selected) or "已加载（尚未选择环境）")
    else
      add(lines, "  venv-selector 未加载")
    end
  end

  -- 格式化 / 外部工具
  add(lines, "")
  add(lines, "【外部工具】")
  for _, item in ipairs(tools) do
    local path = first_exe(item[2])
    add(lines, "  %s %-20s %s", ok(path ~= nil), item[1], path or "未安装")
  end

  local has_conform, conform = pcall(require, "conform")
  if has_conform then
    add(lines, "")
    add(lines, "【conform 格式化】")
    local okl, formatters = pcall(conform.list_formatters, 0)
    if okl and formatters and #formatters > 0 then
      for _, name in ipairs(formatters) do
        add(lines, "  ✔ %s", name)
      end
    else
      add(lines, "  （当前 buffer 没有可用格式化器）")
    end
  end

  -- 关键配置
  add(lines, "")
  add(lines, "【关键配置】")
  add(lines, "  leader=%s   localleader=%s", vim.g.mapleader or "\\", vim.g.maplocalleader or "\\")
  add(lines, "  completeopt=%s", vim.o.completeopt)
  add(lines, "  updatetime=%dms   pumheight=%d", vim.o.updatetime, vim.o.pumheight)
  add(lines, "  Tab 映射=%s", vim.fn.maparg("<Tab>", "i"))
  add(lines, "  项目根=%s", require("crow").project_root())
  add(lines, "  配色可选: %s", table.concat(palette.names(), ", "))
  add(lines, "  切换: :Theme <名字>   /   :CrowTheme <mocha|macchiato|frappe|latte>")

  -- 输出
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "text"
  vim.api.nvim_win_set_buf(0, buf)
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.cmd("normal! gg")
end

return M
