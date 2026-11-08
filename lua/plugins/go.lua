-- ═══════════════════════════════════════════════════════════
-- Go —— vim-go（命令）+ Neovim 原生 LSP gopls（补全/诊断）
-- ═══════════════════════════════════════════════════════════
-- 分工与 Vim 版一致：
--   · :GoBuild / :GoRun / :GoTest / :GoAddTags / :GoDebug …  → vim-go
--   · 补全 / 诊断 / 重命名 / gd、gy、gi、gr、K                → 原生 LSP + gopls
-- 所以这里关掉 vim-go 自带的 gopls、默认映射和保存时格式化，
-- 保存格式化统一由 conform.nvim 的 goimports 执行一次。

return {
  -- ─── vim-go ─────────────────────────────────────────────
  {
    "fatih/vim-go",
    ft = { "go", "gomod", "gowork", "gotmpl" },

    -- init 在插件加载前执行，g:go_* 必须在这时设置好
    init = function()
      local g = vim.g

      -- 和原生 LSP 分工，别起第二套 gopls
      g.go_gopls_enabled = 0
      g.go_def_mapping_enabled = 0
      g.go_doc_keywordprg_enabled = 0
      g.go_doc_popup_window = 1

      -- 保存格式化交给 conform，不让 vim-go 抢
      g.go_fmt_autosave = 0
      g.go_imports_autosave = 0
      g.go_metalinter_autosave = 0
      g.go_fmt_command = "goimports"
      g.go_imports_mode = "goimports"
      g.go_metalinter_command = "staticcheck"

      g.go_list_type = "quickfix"
      g.go_test_show_name = 1
      g.go_test_timeout = "60s"
      g.go_term_mode = "split"
      g.go_term_enabled = 1
      g.go_addtags_transform = "snakecase"

      -- vim-go 自带的语法高亮（与 Treesitter 互补）
      g.go_highlight_types = 1
      g.go_highlight_fields = 1
      g.go_highlight_functions = 1
      g.go_highlight_function_calls = 1
      g.go_highlight_function_parameters = 1
      g.go_highlight_operators = 1
      g.go_highlight_build_constraints = 1
      g.go_highlight_generate_tags = 1
      g.go_highlight_variable_declarations = 1
      g.go_highlight_variable_assignments = 1
    end,

    config = function()
      -- Go buffer 专属快捷键（<leader>g 前缀，只在 go buffer 生效）
      local map = vim.keymap.set
      local go_maps = {
        { "<leader>gb", "<cmd>GoBuild<cr>", "GoBuild" },
        { "<leader>gr", "<cmd>GoRun<cr>", "GoRun" },
        { "<leader>gt", "<cmd>GoTest<cr>", "GoTest" },
        { "<leader>gT", "<cmd>GoTestFunc<cr>", "GoTestFunc" },
        { "<leader>gc", "<cmd>GoCoverageToggle<cr>", "GoCoverageToggle" },
        { "<leader>gv", "<cmd>GoVet<cr>", "GoVet" },
        { "<leader>gl", "<cmd>GoMetaLinter<cr>", "GoMetaLinter" },
        { "<leader>ga", "<cmd>GoAddTags<cr>", "GoAddTags" },
        { "<leader>gA", "<cmd>GoRemoveTags<cr>", "GoRemoveTags" },
        {
          "<leader>gD",
          function()
            require("dap").continue()
          end,
          "Go 调试：启动 / 继续",
        },
        {
          "<leader>gX",
          function()
            require("dap").terminate()
          end,
          "Go 调试：停止",
        },
      }

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("EasyGo", { clear = true }),
        pattern = { "go", "gomod", "gowork" },
        callback = function(event)
          for _, item in ipairs(go_maps) do
            map("n", item[1], item[2], { buffer = event.buf, desc = "Go: " .. item[3] })
          end

          -- which-key：Go buffer 里的 <leader>g 组
          local ok, wk = pcall(require, "which-key")
          if ok then
            wk.add({
              { "<leader>g", group = "Go", buffer = event.buf },
            })
          end
        end,
        desc = "Go buffer 快捷键",
      })
    end,
  },

  -- ─── nvim-dap-go：把 delve 接入 nvim-dap ────────────────
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-go").setup({
        delve = {
          path = vim.fn.exepath("dlv") ~= "" and vim.fn.exepath("dlv") or "dlv",
          initialize_timeout_sec = 20,
          port = "${port}",
          args = {},
        },
      })
    end,
  },

  -- ─── Go 语法 / treesitter ───────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "go", "gomod", "gowork", "gosum" } },
  },
}
