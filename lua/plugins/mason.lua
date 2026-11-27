-- ═══════════════════════════════════════════════════════════
-- Mason —— 工具 / LSP 服务器自动安装
-- ═══════════════════════════════════════════════════════════
--
-- 本配置刻意「系统优先」：lua/plugins/lsp.lua 里大部分服务器都设了
-- `mason = false`，优先使用系统已装的 gopls / rust-analyzer / clangd /
-- pyright 等，避免重复安装、省磁盘。但也因此新机器上缺工具时不会自动补。
--
-- 这个文件补一个**自动安装**能力，规则：
--   · 只自动装「本机缺失」的工具；系统里已有的一律跳过（尊重系统优先）；
--   · 用 `mason-lspconfig` 接管 LSP 服务器（lspconfig 服务器名），
--     LazyVim 的 mason.nvim spec 则负责命令行工具（格式化器 / linter 等）；
--   · 首次启动时后台异步安装，不阻塞编辑；装完触发 FileType 让 LSP 生效。
--
-- 开关（默认开，可关）：
--   · 启动前设置 `vim.g.crow_mason_auto = false` 即完全禁用自动安装；
--   · 手动补齐：:CrowMasonInstall
--
-- 想调整装哪些工具，改下面的 lsp_servers（LSP 服务器名）与
-- mason_tools（命令行工具名）。已存在的工具会被自动过滤，不会重复装。

-- 需要自动安装的 LSP 服务器（lspconfig 服务器名，经 mason-lspconfig）。
-- 这些若系统缺失才装；已设 `mason = false` 的服务器系统有就用系统。
local lsp_servers = {
  "pyright", -- Python（与 crow.lang.python 的自动选择配合）
  "lua_ls", -- Lua
  "bashls", -- Shell
  "vimls", -- Vimscript
  "gopls", -- Go（系统有则跳过）
  "rust_analyzer", -- Rust（系统有则跳过）
  "clangd", -- C / C++（系统有则跳过）
}

-- 需要自动安装的命令行工具（Mason 包名）。缺失即装。
local mason_tools = {
  "stylua", -- Lua 格式化（conform）
  "shfmt", -- shell 格式化（conform）
  "prettier", -- TS/JS/Markdown 格式化（LazyVim prettier extra）
  "goimports", -- Go import 整理（conform）
  "shellcheck", -- shell 静态检查
}

local function has_executable(name)
  return vim.fn.executable(name) == 1
end

-- 服务器名 -> 期望的可执行文件名（多数与包名同名，个别不同）
local bin_map = {
  lua_ls = "lua-language-server",
  basedpyright = "basedpyright-langserver",
  pyright = "pyright-langserver",
  bashls = "bash-language-server",
  vimls = "vim-language-server",
}

local function missing_servers(servers)
  local out = {}
  local ok, mappings = pcall(require, "mason-lspconfig.mappings")
  if not ok then
    return out
  end
  local map = mappings.get_mason_map().lspconfig_to_package
  for _, server in ipairs(servers) do
    local pkg = map[server]
    local bin = bin_map[server] or pkg
    if pkg and not has_executable(bin) then
      out[#out + 1] = server
    end
  end
  return out
end

local function missing_tools(tools)
  local out = {}
  for _, tool in ipairs(tools) do
    if not has_executable(tool) then
      out[#out + 1] = tool
    end
  end
  return out
end

-- 自动安装是否开启（默认开；vim.g.crow_mason_auto=false 关闭）
local auto_enabled = vim.g.crow_mason_auto ~= false

-- 延迟到 spec 求值阶段才探测，避免 init 阶段 require mason 相关模块
local missing_lsp
local missing_tool

local function compute_missing()
  if missing_lsp == nil then
    missing_lsp = missing_servers(lsp_servers)
    missing_tool = missing_tools(mason_tools)
  end
  return missing_lsp, missing_tool
end

return {
  -- ─── mason-lspconfig：自动装缺失的 LSP 服务器 ──────────
  -- LazyVim 不给它配 config，所以这里注册 config 是安全的（不覆盖上游）。
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      if auto_enabled then
        local miss = compute_missing()
        opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, miss)
      end
    end,
    config = function()
      -- :CrowMasonInstall —— 手动补装缺失的工具 / LSP 服务器
      vim.api.nvim_create_user_command("CrowMasonInstall", function()
        local registry = require("mason-registry")
        local map = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
        local to_install = {}
        for _, server in ipairs(missing_servers(lsp_servers)) do
          local ok, pkg = pcall(registry.get_package, map[server])
          if ok and pkg and not pkg:is_installed() then
            to_install[#to_install + 1] = pkg
          end
        end
        for _, tool in ipairs(missing_tools(mason_tools)) do
          local ok, pkg = pcall(registry.get_package, tool)
          if ok and pkg and not pkg:is_installed() then
            to_install[#to_install + 1] = pkg
          end
        end
        if #to_install == 0 then
          vim.notify("Crow Mason：没有缺失的工具需要安装", vim.log.levels.INFO, {
            title = "Crow Mason",
          })
          return
        end
        vim.notify(string.format("Crow Mason：开始安装 %d 个缺失工具", #to_install), vim.log.levels.INFO, {
          title = "Crow Mason",
        })
        registry.install(to_install)
      end, { desc = "安装缺失的 Mason 工具 / LSP 服务器" })
    end,
  },

  -- ─── mason.nvim：自动装缺失的命令行工具 ────────────────
  -- 只扩展 ensure_installed，保留 LazyVim 默认的 config（触发 FileType 等）。
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      if auto_enabled then
        local _, miss = compute_missing()
        opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, miss)
      end
    end,
  },
}
