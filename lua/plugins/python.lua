-- ═══════════════════════════════════════════════════════════
-- Python —— 按项目 / 本机工具自动选择最优组合
-- ═══════════════════════════════════════════════════════════
--
-- 探测逻辑集中在 lua/crow/lang/python.lua，本文件只负责把结果接到插件：
--   LSP       basedpyright > pyright（只启动一个，避免重复诊断）
--   格式化    ruff > black + isort > black
--   测试      pytest > unittest（neotest-python）
--   调试      nvim-dap-python（使用项目解释器）
--
-- 查看当前选择：:CrowPython
-- 手动换解释器：<leader>cv（venv-selector）

local py = require("crow.lang.python")

---@return table
local function tools()
  return py.detect()
end

return {
  -- ─── LSP：动态替换 pyright / basedpyright ──────────────
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local t = tools()
      opts.servers = opts.servers or {}

      -- 两个都配会同时启动、重复报诊断；根据实际可执行文件二选一。
      opts.servers.pyright = nil
      opts.servers.basedpyright = nil
      opts.servers[t.lsp] = py.lsp_config(t)
    end,
  },

  -- ─── 格式化：ruff 优先，缺失时回退 black / isort ───────
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      -- 每个 buffer 按自己所属项目重新探测，切换项目不需要重启 Neovim。
      opts.formatters_by_ft.python = function(bufnr)
        local t = py.detect(py.root(bufnr), bufnr)
        return py.formatters(t)
      end

      opts.formatters.ruff_format = {
        prepend_args = { "--line-length", "100" },
      }
      opts.formatters.black = {
        prepend_args = { "--line-length", "100" },
      }
      opts.formatters.isort = {
        prepend_args = { "--profile", "black", "--line-length", "100" },
      }
    end,
  },

  -- ─── 调试：使用项目自己的解释器 ────────────────────────
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local t = tools()
      require("dap-python").setup(t.interpreter or "python3")
    end,
  },

  -- ─── 测试：pytest > unittest，快捷键放在 <leader>cT ────
  {
    "nvim-neotest/neotest",
    ft = "python",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/neotest-python",
    },
    config = function()
      local t = tools()
      local ok, adapter = pcall(require, "neotest-python")
      if not ok then
        return
      end

      local adapter_opts = {
        dap = { justMyCode = false },
        -- neotest-python 会按项目解释器自动选择 pytest / unittest；
        -- 这里用函数而不是固定路径，venv-selector 切换后也能跟随。
        python = function(root)
          return py.interpreter(root) or "python3"
        end,
      }

      require("neotest").setup({
        adapters = { adapter(adapter_opts) },
        status = { virtual_text = true },
        output = { open_on_run = true },
        quickfix = {
          open = function()
            local has_trouble, trouble = pcall(require, "trouble")
            if has_trouble then
              trouble.open({ mode = "quickfix", focus = false })
            else
              vim.cmd("copen")
            end
          end,
        },
      })

      local map = vim.keymap.set
      local function attach(buf)
        local neotest = function()
          return require("neotest")
        end
        map("n", "<leader>cTr", function()
          neotest().run.run()
        end, { buffer = buf, desc = "Python: 运行最近的测试" })
        map("n", "<leader>cTf", function()
          neotest().run.run(vim.fn.expand("%"))
        end, { buffer = buf, desc = "Python: 运行当前测试文件" })
        map("n", "<leader>cTs", function()
          neotest().summary.toggle()
        end, { buffer = buf, desc = "Python: 测试汇总" })
        map("n", "<leader>cTo", function()
          neotest().output.open({ enter = true, auto_close = true })
        end, { buffer = buf, desc = "Python: 测试输出" })
        map("n", "<leader>cTd", function()
          neotest().run.run({ strategy = "dap" })
        end, { buffer = buf, desc = "Python: 调试最近的测试" })
      end

      -- 插件由当前 Python buffer 的 FileType 触发加载，此时事件已经在处理中，
      -- 新建的 autocmd 不会补跑当前 buffer，所以先手动挂一次。
      if vim.bo.filetype == "python" then
        attach(vim.api.nvim_get_current_buf())
      end

      local group = vim.api.nvim_create_augroup("CrowPythonTest", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "python",
        callback = function(event)
          attach(event.buf)
        end,
        desc = "Python: neotest 快捷键",
      })
    end,
  },

  -- ─── 语法 ─────────────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "python", "requirements" } },
  },
}
