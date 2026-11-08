-- ═══════════════════════════════════════════════════════════
-- venv-selector.nvim —— Python 虚拟环境选择 / 切换
-- ═══════════════════════════════════════════════════════════
-- 打开 Python 文件后按 <leader>cv 打开选择器，选中后：
--   · 设置 VIRTUAL_ENV / CONDA_PREFIX，之后新开的终端自动激活
--   · 用所选解释器重启 pyright，Import 报错随之消失
--   · 记住每个项目上次使用的环境，下次打开自动恢复
--
-- 选择器优先用 snacks（LazyVim 已带），没有时再回退 telescope。

-- 把结果里的家目录缩写成 ~，并去掉 /bin/python 后缀，列表更短
local function shorter_name(filename)
  return (filename:gsub(vim.env.HOME, "~"):gsub("[/\\]bin[/\\]python[%d.]*$", ""))
end

return {
  "linux-cultist/venv-selector.nvim",
  branch = "main",
  dependencies = {
    -- 二选一即可；两者都没装时插件会退回内置 native 选择器
    { "folke/snacks.nvim", optional = true },
    { "nvim-telescope/telescope.nvim", optional = true },
  },
  -- 只在 Python 文件里加载，避免拖慢启动
  ft = "python",
  cmd = "VenvSelect",
  keys = {
    { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "选择 Python 虚拟环境" },
    {
      "<leader>cV",
      function()
        require("venv-selector").deactivate()
      end,
      desc = "取消虚拟环境",
    },
    {
      "<leader>cvr",
      function()
        require("venv-selector").restart_lsp_servers()
      end,
      desc = "用当前环境重启 Python LSP",
    },
  },
  opts = {
    options = {
      -- ─── 选择器 ──────────────────────────────────────────
      -- auto 会优先选 telescope，这里明确用 snacks
      picker = "snacks",
      picker_filter_type = "substring",
      picker_options = {
        snacks = {
          -- select: 居中选择框；需要下拉风格可改成 "dropdown"
          layout = { preset = "select" },
        },
      },
      picker_columns = { "marker", "search_icon", "search_name", "search_result" },
      picker_icons = {
        venv = "🐍",
        virtualenvs = "📦",
        poetry = "📝",
        pipenv = "🐍",
        pyenv = "🧰",
        anaconda = "🅰️",
        miniconda = "🅰️",
        pixi = "🧚",
        hatch = "🔨",
        uv = "⚡",
        projects = "📁",
        default = "🐍",
      },
      -- 已选中的环境在列表里打勾并染成主题绿色
      selected_venv_marker_icon = "✔",
      selected_venv_marker_color = "#a6e3a1",
      -- 缩短列表中的路径（仅 telescope 使用；snacks 自己展示 name）
      on_telescope_result_callback = shorter_name,

      -- ─── 搜索 ────────────────────────────────────────────
      enable_default_searches = true,
      search_timeout = 10,
      fd_binary_name = "fd",
      shell = {
        shell = vim.o.shell,
        shellcmdflag = vim.o.shellcmdflag,
      },

      -- ─── 激活行为 ────────────────────────────────────────
      enable_cached_venvs = true,
      cached_venv_automatic_activation = true,
      activate_venv_in_terminal = true,
      set_environment_variables = true,
      require_lsp_activation = true,
      notify_user_on_venv_activation = true,
      -- 不要再让 venv-selector 把 vim.notify 替换成 nvim-notify：
      -- 本机通知由 noice + nvim-notify 统一接管，插件再改一次会导致
      -- noice 的 checkhealth 报 “vim.notify has been overwritten”。
      override_notify = false,

      -- ─── 日志 ────────────────────────────────────────────
      -- 排查问题时改成 "DEBUG" 或 "TRACE"，再用 :VenvSelectLog 查看
      log_level = "NONE",

      -- ─── 状态栏 ──────────────────────────────────────────
      statusline_func = {
        lualine = function()
          local ok, vs = pcall(require, "venv-selector")
          if not ok then
            return ""
          end
          local venv_path = vs.venv()
          if not venv_path or venv_path == "" then
            return ""
          end
          local venv_name = vim.fn.fnamemodify(venv_path, ":t")
          if not venv_name or venv_name == "" then
            return ""
          end
          return "🐍 " .. venv_name
        end,
      },
    },

    search = {
      -- 在家目录下查找虚拟环境（包含隐藏目录 .venv）。
      -- 限制搜索深度，避免在超大目录里耗时过久；
      -- 如需只扫描特定目录，可通过环境变量 CROW_VENV_ROOT 覆盖。
      projects = {
        command = table.concat({
          "$FD '/bin/python$' " .. (vim.env.CROW_VENV_ROOT or "~"),
          "--max-depth 6 --full-path --color never -HI -a -L",
          "-E node_modules -E .git -E site-packages",
        }, " "),
      },
    },
  },
}
