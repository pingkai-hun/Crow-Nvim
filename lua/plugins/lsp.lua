-- ═══════════════════════════════════════════════════════════
-- LSP / 诊断 / 格式化（Easy-Vim 的 coc 配置迁移到原生生态）
-- ═══════════════════════════════════════════════════════════
-- 对应 ~/.vim/coc-settings.json：
--   · 诊断符号 ● ▲ ● ○，只给当前行显示虚拟文本，级别 ≥ warning
--   · rust-analyzer / clangd / pyright / bashls / vimls / gopls
--   · 保存格式化：goimports / ruff / rustfmt / clang-format / stylua / shfmt
--
-- 这里不启用 vim-go 自带的 gopls/格式化，避免和 LSP、conform 重复。

-- 找项目自带的 Python 解释器。
-- 关键：pyright 不会自动使用项目根目录下的 .venv，必须显式告诉它，
-- 否则即使 .venv 里装了包，也会报 "Import xxx could not be resolved"。
local function find_python(root)
  local candidates = {}

  -- 当前终端已经激活的虚拟环境优先
  if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
    candidates[#candidates + 1] = vim.env.VIRTUAL_ENV
  end

  if root and root ~= "" then
    for _, name in ipairs({ ".venv", "venv", "env" }) do
      candidates[#candidates + 1] = vim.fs.joinpath(root, name)
    end
  end

  for _, dir in ipairs(candidates) do
    for _, rel in ipairs({ "bin/python", "bin/python3", "Scripts/python.exe" }) do
      local path = vim.fs.joinpath(dir, rel)
      if vim.uv.fs_stat(path) then
        return path
      end
    end
  end
end

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

        -- Python：pyright 诊断，ruff 格式化
        pyright = {
          mason = false,
          -- 在启动语言服务器前，把项目自己的虚拟环境告诉 pyright。
          -- 不能只靠 python.analysis.autoSearchPaths：它只影响 import 搜索路径，
          -- 不会让 pyright 换用 .venv 里的第三方包。
          before_init = function(_, config)
            config.settings = config.settings or {}
            config.settings.python = config.settings.python or {}

            -- 已经有明确解释器（venv-selector 选中，或用户自己配置）就不要覆盖，
            -- 否则在选择器里换了环境，重启后又被这里改回项目默认的 .venv。
            local current = config.settings.python.pythonPath
            if current and current ~= "" then
              return
            end

            -- venv-selector 的 :VenvSelect 取消激活后，尊重用户的选择，
            -- 不再自动把 .venv 塞回去。
            local buf = vim.api.nvim_get_current_buf()
            if vim.b[buf].venv_selector_disabled then
              return
            end

            -- 选择器已激活时优先用它的解释器（多环境项目里可能是别的 venv）
            local ok, vs = pcall(require, "venv-selector")
            if ok then
              local selected = vs.python()
              if selected and selected ~= "" then
                config.settings.python.pythonPath = selected
                return
              end
            end

            -- 没有选择器状态时，回退到项目根目录的 .venv / venv / env
            local root = config.root_dir or vim.fn.getcwd()
            local python = find_python(root)
            if python then
              config.settings.python.pythonPath = python
            end
          end,
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                indexing = false,
                autoImportCompletions = true,
                autoSearchPaths = true,
                inlayHints = {
                  parameterTypes = true,
                  variableTypes = false,
                  functionReturnTypes = false,
                },
              },
            },
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
        python = { "ruff_organize_imports", "ruff_format" },
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
        ruff_format = {
          prepend_args = { "--line-length", "100" },
        },
      },
    },
  },
}
