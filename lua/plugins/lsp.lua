-- ═══════════════════════════════════════════════════════════
-- LSP / 诊断 / 格式化（Easy-Vim 的 coc 配置迁移到原生生态）
-- ═══════════════════════════════════════════════════════════
-- 对应 ~/.vim/coc-settings.json：
--   · 诊断符号 ● ▲ ● ○，只给当前行显示虚拟文本，级别 ≥ warning
--   · rust-analyzer / clangd / bashls / vimls / gopls
--   · 保存格式化：goimports / rustfmt / clang-format / stylua / shfmt
--
-- Python 的 LSP / 格式化 / 测试由 lua/plugins/python.lua 动态选择，
-- 本文件只保留与语言无关的 LSP 诊断展示和其余语言服务器。
--
-- 这里不启用 vim-go 自带的 gopls/格式化，避免和 LSP、conform 重复。

return {
  -- ─── nvim-lspconfig ─────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- 诊断显示方式：符号列常驻，虚拟文本只在当前行
      diagnostics = {
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        -- 显式关闭 Neovim 0.11+ 的整行虚拟文本，避免和下面的行尾提示重复
        virtual_lines = false,
        virtual_text = {
          current_line = true,
          severity = { min = vim.diagnostic.severity.WARN },
          -- 用严重级别图标代替纯空格，扫一眼就知道是错还是警告
          prefix = function(d)
            local icons = {
              [vim.diagnostic.severity.ERROR] = "●",
              [vim.diagnostic.severity.WARN] = "▲",
              [vim.diagnostic.severity.INFO] = "●",
              [vim.diagnostic.severity.HINT] = "○",
            }
            return (icons[d.severity] or "●") .. " "
          end,
          spacing = 2,
          source = "if_many",
          -- 把多行消息压成一行，并带上规则名（例如 reportMissingImports），
          -- 这样不用打开浮窗也能知道是哪条检查报的。
          format = function(d)
            local msg = (d.message or ""):gsub("%s*\n%s*", " ")
            local code = d.code and (" [" .. tostring(d.code) .. "]") or ""
            return msg .. code
          end,
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "●",
            [vim.diagnostic.severity.WARN] = "▲",
            [vim.diagnostic.severity.INFO] = "●",
            [vim.diagnostic.severity.HINT] = "○",
          },
        },
        float = {
          border = "rounded",
          source = true,
          header = "",
          prefix = "",
          focusable = true,
          wrap = true,
          max_width = 100,
          max_height = 20,
        },
        -- [d / ]d 跳转时顺带弹出完整消息，否则只跳位置不知道错在哪
        -- Neovim 0.12 起 jump.float 已废弃，用 on_jump 实现同样行为
        jump = {
          on_jump = function(diagnostic, bufnr)
            if not diagnostic then
              return
            end
            vim.diagnostic.open_float({
              bufnr = bufnr,
              scope = "cursor",
              focus = false,
            })
          end,
          wrap = true,
        },
      },

      servers = {
        -- Go：补全/诊断/重命名由这里负责，:GoXxx 命令交给 vim-go
        gopls = {
          mason = false,
          init_options = {
            semanticTokens = true,
          },
          settings = {
            gopls = {
              gofumpt = false, -- 统一用 goimports
              usePlaceholders = true,
              completeUnimported = true,
              staticcheck = true,
              directoryFilters = { "-.git", "-.vscode", "-.idea", "-node_modules" },
              codelenses = {
                gc_details = false,
                generate = true,
                regenerate_cgo = true,
                run_govulncheck = true,
                test = true,
                tidy = true,
                upgrade_dependency = true,
                vendor = true,
              },
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                compositeLiteralTypes = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
              analyses = {
                nilness = true,
                unusedparams = true,
                unusedwrite = true,
                useany = true,
              },
            },
          },
        },

        -- Rust
        rust_analyzer = {
          mason = false,
          settings = {
            ["rust-analyzer"] = {
              checkOnSave = true,
              check = { command = "clippy" },
              cargo = { allTargets = true },
              procMacro = { enable = true },
              inlayHints = {
                typeHints = { enable = true },
                parameterHints = { enable = true },
                chainingHints = { enable = false },
                closingBraceHints = { enable = false },
                bindingModeHints = { enable = false },
                lifetimeElisionHints = { enable = "never" },
                maxLength = 25,
              },
              completion = {
                postfix = { enable = true },
                autoimport = { enable = true },
                callable = { snippets = "fill_arguments" },
                addSemicolonToUnit = true,
              },
              imports = {
                granularity = { group = "crate" },
                merge = { glob = true },
              },
              updates = { checkOnStartup = false },
            },
          },
        },

        -- C / C++
        clangd = {
          mason = false,
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=never",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--all-scopes-completion",
            "--pch-storage=memory",
            "-j=6",
          },
        },

        -- Shell
        bashls = {
          mason = false,
          settings = {
            bashIde = {
              shellcheckPath = "/usr/bin/shellcheck",
              shfmt = { path = "/usr/bin/shfmt" },
              logLevel = "warning",
            },
          },
        },

        -- Vimscript
        vimls = { mason = false },
      },
    },
  },

  -- ─── conform.nvim：保存格式化 ───────────────────────────
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        go = { "goimports" },
        rust = { "rustfmt" },
        c = { "clang_format" },
        cpp = { "clang_format" },
        lua = { "stylua" },
        sh = { "shfmt" },
        bash = { "shfmt" },
      },
      formatters = {
        goimports = {
          -- 与 Vim 版一致：100 列以内不强制，交给 goimports 默认
          prepend_args = {},
        },
      },
    },
  },
}
