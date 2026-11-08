-- ═══════════════════════════════════════════════════════════
-- WHICH-KEY - 横向布局 + 分组说明
-- ═══════════════════════════════════════════════════════════
--
-- 这里只做两件事：调外观（opts）+ 声明分组（opts.spec）。
--
-- 为什么**不写 config**：
--   lazy.nvim 用原型链合并同一插件的多个 spec（lazy/core/meta.lua 里的
--   setmetatable(fragment.spec, { __index = super })），后加载的 spec 一旦
--   定义 config，就会遮蔽 LazyVim 自带的那份 config。
--   LazyVim 的 config 负责调用 require("which-key").setup(opts)；
--   被遮蔽后 which-key 就永远不会 setup，表现为：
--     · plugin/which-key.lua 里的兜底定时器拿不到已初始化的模块
--       → attempt to call field 'setup' (a nil value)
--     · 按 <Space> 没有反应、分组不显示
--   这和之前 snacks 欢迎页消失是同一类坑。
--
-- which-key v3 的 setup() 会读取 opts.spec（见 which-key/config.lua 的
-- M.add(M.options.spec)），所以分组直接放进 opts.spec 即可，
-- 不需要自己调 wk.add()。

return {
  {
    "folke/which-key.nvim",

    -- ─── 立即加载（lazy = false），不要用 event = "VeryLazy" ───────
    -- 原因：which-key 之前是延迟加载的，这会产生一个「模块已在
    -- package.loaded 里、但还没初始化完」的窗口。在这期间任何
    -- require("which-key") 都可能拿到不完整的表，于是出现：
    --   · LazyVim editor.lua:122  attempt to call field 'setup' (a nil value)
    --   · LazyVim util/mini.lua   attempt to call field 'add'   (a nil value)
    --   · which-key 自己的兜底定时器同样报 setup 为 nil
    -- 这些报错都来自同一个竞争条件，只靠 try-again 补丁治不好。
    --
    -- which-key 本身很小（纯 Lua，无外部依赖），启动时直接加载的开销
    -- 可以忽略，换来的是「任何时候 require 都拿到完整模块」。
    lazy = false,

    -- LazyVim 用 opts_extend 保证多个 fragment 的 spec 列表是**合并**而不是覆盖
    opts_extend = { "spec" },

    opts = function(_, opts)
      -- Delay in milliseconds before the which-key popup appears after
      -- a key is pressed. Keeps the popup from flashing on fast typists.
      opts.delay = 300

      -- Visual style preset for the popup window.
      -- Available options: 'classic' | 'modern' | 'helix'
      opts.preset = "modern"

      -- ───────────────────────────────────────────────────────
      --  NO TRIGGERS IN VISUAL MODE
      -- ───────────────────────────────────────────────────────
      -- Explicitly defines which key prefixes trigger the popup and in
      -- which modes. Visual mode (v) is intentionally omitted from most
      -- triggers to avoid blocking common visual operations like g and z.
      opts.triggers = {
        { "<leader>", mode = { "n", "v" } }, -- Leader available in both normal and visual
        { "g", mode = { "n" } }, -- Goto motions in normal mode only
        { "z", mode = { "n" } }, -- Fold commands in normal mode only
        { "]", mode = { "n" } }, -- Next item navigation in normal mode only
        { "[", mode = { "n" } }, -- Prev item navigation in normal mode only
      }

      -- ───────────────────────────────────────────────────────
      --  HORIZONTAL LAYOUT
      -- ───────────────────────────────────────────────────────
      -- Configures the popup window to appear at the very bottom of the
      -- screen in a wide horizontal layout, similar to a command palette.

      if not opts.win then
        opts.win = {}
      end
      opts.win.no_overlap = true -- Prevent the popup from overlapping buffer content
      opts.win.height = { min = 5, max = 30 } -- Constrain popup height between 5 and 30 rows
      opts.win.row = math.huge -- Push the popup to the very bottom of the screen
      opts.win.border = "rounded" -- Rounded border style for the popup window
      opts.win.padding = { 1, 2 } -- 1 row vertical padding, 2 columns horizontal padding
      opts.win.title = true -- Show the popup title bar
      opts.win.title_pos = "center" -- Center the title text in the title bar

      if not opts.layout then
        opts.layout = {}
      end
      opts.layout.width = { min = 20, max = 50 } -- Each column is between 20 and 50 characters wide
      opts.layout.spacing = 3 -- 3 spaces of padding between columns
      opts.layout.align = "left" -- Left-align key labels within each column
      opts.layout.columns = 6 -- Render 6 columns side by side for a wide layout

      if not opts.icons then
        opts.icons = {}
      end
      opts.icons.breadcrumb = "»" -- Separator shown in the keymap breadcrumb trail
      opts.icons.separator = "➜" -- Separator between the key and its description
      opts.icons.group = "+" -- Prefix icon shown before group names
      opts.icons.ellipsis = "…" -- Shown when a label is truncated due to width constraints

      opts.show_help = true -- Show the help footer line at the bottom of the popup
      opts.show_keys = true -- Show the keys that were pressed to open the popup

      -- ───────────────────────────────────────────────────────
      --  KEY GROUPS（通过 opts.spec 注册，见文件头说明）
      -- ───────────────────────────────────────────────────────
      -- 给 <leader> 下的各个前缀和常用 motion 前缀起名，
      -- 这样弹窗里显示的是分组标题而不是一堆裸键位。
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { "<leader>a", group = "AI", icon = "", mode = "n" },
        { "<leader>b", group = "Buffers", icon = "", mode = "n" }, -- Buffer management
        { "<leader>c", group = "Code", icon = "", mode = "n" }, -- Code actions, LSP commands
        { "<leader>d", group = "Debug", icon = "", mode = "n" }, -- DAP debugger commands
        { "<leader>f", group = "Find", icon = "", mode = "n" }, -- File and text search
        { "<leader>g", group = "Git", icon = "", mode = "n" }, -- Git operations
        { "<leader>gh", group = "Hunks", icon = "", mode = "n" }, -- Git hunk staging
        { "<leader>l", group = "LSP", icon = "", mode = "n" }, -- LSP actions and info
        { "<leader>n", group = "Notify", icon = "", mode = "n" }, -- Notification management
        { "<leader>o", group = "Ollama / AI", icon = "", mode = "n" }, -- 本机 3B 模型
        { "<leader>p", group = "Files", icon = "", mode = "n" }, -- Easy-Vim 风格文件查找
        { "<leader>q", group = "Quit", icon = "", mode = "n" }, -- Quit / session commands
        { "<leader>s", group = "Search", icon = "", mode = "n" }, -- Search and grep commands
        { "<leader>u", group = "UI", icon = "", mode = "n" }, -- UI toggles
        { "<leader>w", group = "Window", icon = "", mode = "n" }, -- Window/split management
        { "<leader>x", group = "Diag", icon = "", mode = "n" }, -- Diagnostics and Trouble
        { "g", group = "Goto", icon = "", mode = "n" }, -- Go-to motions (gd, gr, etc.)
        { "gs", group = "Surround", icon = "", mode = "n" }, -- Surround text objects
        { "z", group = "Fold", icon = "", mode = "n" }, -- Fold open/close commands
        { "]", group = "Next", icon = "", mode = "n" }, -- Jump to next item
        { "[", group = "Prev", icon = "", mode = "n" }, -- Jump to previous item
      })

      return opts
    end,

    -- ─── Keymaps ───────────────────────────────────────────────
    -- <leader>? 打开只显示当前 buffer 键位的 which-key 弹窗，
    -- 用来查看 buffer-local 的绑定。
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Keymaps",
        mode = "n",
      },
    },
  },
}
