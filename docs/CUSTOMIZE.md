# 定制指南

> 适用版本：**CrowNvim Beta0.1.2**
> 本文只讲「怎么改」，不重复讲每个插件怎么用。改完建议执行 `:Doctor` 和 `:checkhealth`。

---

## 目录

- [1. 添加一个插件](#1-添加一个插件)
- [2. 禁用或覆盖 LazyVim 默认插件](#2-禁用或覆盖-lazyvim-默认插件)
- [3. 修改 leader 与全局键位](#3-修改-leader-与全局键位)
- [4. 添加 buffer-local 键位](#4-添加-buffer-local-键位)
- [5. 修改选项](#5-修改选项)
- [6. 添加 LSP 服务器](#6-添加-lsp-服务器)
- [7. 添加格式化器](#7-添加格式化器)
- [8. 修改 Python / venv 行为](#8-修改-python--venv-行为)
- [9. 更换主题](#9-更换主题)
- [10. 添加自定义命令](#10-添加自定义命令)
- [11. 更换 picker](#11-更换-picker)
- [12. 调整通知行为](#12-调整通知行为)
- [13. 代码风格与提交](#13-代码风格与提交)
- [14. 安全地试验](#14-安全地试验)

---

## 1. 添加一个插件

在 `lua/plugins/` 下新建一个 `.lua` 文件，返回 lazy.nvim spec。

### 最简形式

```lua
-- lua/plugins/my-plugin.lua
return {
  "author/my-plugin.nvim",
  opts = {
    -- 传给 require("my-plugin").setup(opts)
  },
}
```

### 延迟加载

```lua
return {
  "author/my-plugin.nvim",

  -- 方式一：命令
  cmd = "MyCommand",

  -- 方式二：键位（第一次按下时才加载）
  keys = {
    { "<leader>mp", "<cmd>MyCommand<cr>", desc = "My Plugin" },
  },

  -- 方式三：文件类型
  ft = { "python", "lua" },

  -- 方式四：事件
  event = "InsertEnter",

  opts = {},
}
```

> `defaults.lazy = false`，所以不写 `event` / `cmd` / `keys` / `ft` 的插件会在启动时立即加载。新插件尽量加上触发条件。

### 带自定义 config

```lua
return {
  "author/my-plugin.nvim",
  event = "VeryLazy",
  config = function(_, opts)
    require("my-plugin").setup(opts)
  end,
}
```

### 添加依赖

```lua
return {
  "author/my-plugin.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "folke/snacks.nvim", optional = true },
  },
}
```

添加后：

```vim
:Lazy sync
```

然后提交 `lazy-lock.json`。

---

## 2. 禁用或覆盖 LazyVim 默认插件

LazyVim 的插件 spec 可以被同名 spec 覆盖。

### 禁用

```lua
return {
  { "akinsho/bufferline.nvim", enabled = false },
}
```

### 覆盖配置

```lua
return {
  {
    "folke/trouble.nvim",
    opts = {
      -- 只写要改的字段，其余沿用 LazyVim
    },
  },
}
```

### 覆盖键位

```lua
return {
  {
    "folke/trouble.nvim",
    keys = {
      { "<leader>xx", false },              -- 删除默认键位
      { "<leader>xt", "<cmd>Trouble todo<cr>", desc = "TODO" },
    },
  },
}
```

---

## 3. 修改 leader 与全局键位

### 改 leader

编辑 `lua/config/options.lua`：

```lua
g.mapleader = " "
g.maplocalleader = "\\"
```

> `leader` 必须在任何键位注册前设置。改完重启 Neovim。

### 改全局键位

编辑 `lua/config/keymaps.lua`，或在 `lua/plugins/` 新建一个键位文件：

```lua
-- lua/plugins/my-keys.lua
return {
  {
    "LazyVim/LazyVim",
    keys = {
      { "<leader>z", "<cmd>echo 'hello'<cr>", desc = "Hello" },
    },
  },
}
```

### 删除某个默认键位

```lua
{ "<leader>cd", false }
```

### 查看当前映射

```vim
:verbose map <leader>cd
:map <leader>
```

`verbose` 会显示最后设置它的文件。

---

## 4. 添加 buffer-local 键位

适合只在某类文件里生效的键位，例如 Python 模板：

```lua
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("MyPythonKeys", { clear = true }),
  pattern = "python",
  callback = function(ev)
    vim.keymap.set("n", "<leader>pr", function()
      -- ...
    end, { buffer = ev.buf, desc = "Python: run" })
  end,
})
```

配置里的红队模板就是这种模式，见 `lua/config/keymaps.lua` 末尾。

---

## 5. 修改选项

### 普通选项

编辑 `lua/config/options.lua`：

```lua
opt.number = true
opt.relativenumber = true
opt.scrolloff = 5
```

### 会被 LazyVim 覆盖的选项

如果改完没生效，先执行：

```vim
:verbose set scrolloff?
```

如果显示 `lazyvim/config/options.lua`，说明需要在 `lua/crow/options.lua` 的 `M.values` 里同步修改：

```lua
M.values = {
  scrolloff = 5,
  sidescrolloff = 5,
  pumheight = 12,
  updatetime = 300,
  -- ...
}
```

这里才是最终写回的位置。

### 文件类型选项

在 `lua/config/autocmds.lua` 里加：

```lua
autocmd("FileType", {
  group = filetypes,
  pattern = { "yaml", "yml" },
  callback = function()
    opt_local.tabstop = 2
    opt_local.shiftwidth = 2
  end,
})
```

---

## 6. 添加 LSP 服务器

### 系统已安装的服务器

在 `lua/plugins/lsp.lua` 的 `servers` 表里加：

```lua
servers = {
  my_server = {
    mason = false,
    settings = {
      my_server = {
        -- 服务器专属配置
      },
    },
  },
}
```

如果服务器名与 `nvim-lspconfig` 的配置名一致，通常只需要：

```lua
my_server = {},
```

### 让 Mason 安装

```lua
my_server = {
  mason = true,
},
```

然后：

```vim
:MasonInstall my-server
```

### 文件类型关联

有些服务器需要手动设置 `filetypes`：

```lua
my_server = {
  filetypes = { "python", "toml" },
},
```

### 检查

```vim
:LspInfo
:checkhealth lspconfig
:Doctor
```

---

## 7. 添加格式化器

在 `lua/plugins/lsp.lua` 的 `formatters_by_ft` 里加：

```lua
formatters_by_ft = {
  python = { "ruff_organize_imports", "ruff_format" },
  toml = { "taplo" },
},
```

如果格式化器有特殊参数：

```lua
formatters = {
  my_formatter = {
    prepend_args = { "--config", "path/to/config" },
  },
},
```

保存时格式化由全局 `vim.g.autoformat` 控制：

```vim
<leader>uf     " 开关全局自动格式化
<leader>uF     " 开关当前 buffer
<leader>cf     " 手动格式化
```

### 不要重复格式化

如果某个插件自带保存格式化（例如 vim-go、LSP 的 `format_on_save`），要显式关闭，统一交给 conform。配置里已经处理了：

```lua
g.go_fmt_autosave = 0
g.go_imports_autosave = 0
```

---

## 8. 修改 Python / venv 行为

### 修改自动寻找的解释器

`lua/plugins/lsp.lua` 的 `find_python(root)` 按以下顺序查找：

1. `$VIRTUAL_ENV`
2. `root/.venv`
3. `root/venv`
4. `root/env`

想加目录：

```lua
for _, name in ipairs({ ".venv", "venv", "env", ".virtualenv" }) do
  candidates[#candidates + 1] = vim.fs.joinpath(root, name)
end
```

### 修改 venv-selector 搜索范围

默认扫描家目录，限制深度 6：

```lua
command = table.concat({
  "$FD '/bin/python$' " .. (vim.env.CROW_VENV_ROOT or "~"),
  "--max-depth 6 --full-path --color never -HI -a -L",
  "-E node_modules -E .git -E site-packages",
}, " "),
```

只扫描某个目录：

```bash
export CROW_VENV_ROOT="$HOME/venvs"
```

或者直接改 `lua/plugins/venv-selector.lua` 里的 `projects` 搜索命令。

### 修改状态栏显示

`lua/plugins/venv-selector.lua` 的 `statusline_func.lualine` 返回 `"🐍 " .. venv_name`。想显示完整路径或去掉图标，改这里。

### pyright 不要自动使用 `.venv`

在 `before_init` 里已经有保护：

```lua
if vim.b[buf].venv_selector_disabled then return end
```

需要临时禁用时，执行 `<leader>cV` 取消选择，或手动设置：

```lua
vim.b[buf].venv_selector_disabled = true
```

---

## 9. 更换主题

### 临时切换

```vim
:Theme tokyonight-moon
:Theme catppuccin-mocha
:CrowTheme macchiato
```

### 永久切换

修改 `lua/config/lazy.lua` 末尾：

```lua
{ "LazyVim/LazyVim", opts = { colorscheme = "tokyonight-moon" } },
```

以及 `lua/plugins/` 里对应配色 spec 的 `opts`（若有）。

### 新增主题

1. 在 `lua/plugins/` **根目录**添加 spec：

```lua
return {
  { "author/theme.nvim", lazy = false, priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = "theme-name" } },
}
```

2. 在 `lua/crow/palette.lua` 的 `M.tables` 里登记语义色：

```lua
M.tables = {
  ["theme-name"] = {
    bg0 = "#...",
    bg1 = "#...",
    bg2 = "#...",
    bg3 = "#...",
    bg5 = "#...",
    fg0 = "#...",
    grey0 = "#...",
    grey1 = "#...",
    grey2 = "#...",
    red = "#...",
    orange = "#...",
    yellow = "#...",
    green = "#...",
    aqua = "#...",
    blue = "#...",
    purple = "#...",
  },
}
```

3. `:Theme theme-name` 验证行号、补全菜单、搜索、诊断标志是否正常。

未登记的主题会回退到 Catppuccin Mocha 色板，不会花屏。

---

## 10. 添加自定义命令

在 `lua/crow/init.lua` 的 `M.setup()` 里加：

```lua
vim.api.nvim_create_user_command("MyCommand", function(opts)
  -- opts.args / opts.fargs
end, {
  nargs = "?",
  complete = "file",
  desc = "我的命令",
})
```

或者放到自己的模块里，在 `init.lua` 中 require。

### 通知

统一使用：

```lua
require("crow").notify("消息", vim.log.levels.INFO)
```

不要直接 `require("nvim-notify")`，否则会绕过 Noice 的路由。

---

## 11. 更换 picker

默认 picker 是 `snacks`。

### 临时用 telescope

```vim
:Telescope find_files
```

### 改回 telescope 作为默认

1. 修改 `lua/config/options.lua`：

```lua
g.lazyvim_picker = "telescope"
```

2. 把 `config/keymaps.lua` 里的 `snacks().picker.*` 改为 `LazyVim.pick(...)` 或 telescope 对应命令。

3. yanky、todo-comments 等已有 telescope 分支，不需要改。

### 使用内置 picker

LazyVim 支持 `g.lazyvim_picker = "auto" | "telescope" | "fzf" | "snacks"`。`auto` 会按优先级选择，当前配置明确使用 snacks。

---

## 12. 调整通知行为

相关文件：`lua/plugins/notifications.lua`、`lua/plugins/noice.lua`。

### 调整超时

在 `routes` 里找到对应规则，修改 `opts.timeout`：

```lua
timeout = 30000, -- 30 秒
```

### 关闭某类消息

```lua
{
  filter = { event = "msg_show", find = "pattern" },
  opts = { skip = true },
},
```

### 恢复 `vim.notify`

不要让第三方插件覆盖 `vim.notify`。`:checkhealth noice` 应显示：

```text
✅ OK vim.notify is set to Noice
```

在 `lua/plugins/venv-selector.lua` 中保持：

```lua
override_notify = false,
```

---

## 13. 代码风格与提交

### 格式化 Lua

```bash
stylua lua/
```

风格配置在 `stylua.toml`。

### 检查

```bash
luac -p init.lua
find lua -name '*.lua' -exec luac -p {} \;
```

更推荐在 Neovim 里打开文件，依赖 `lua-language-server` 做诊断。

### 提交前

```vim
:Doctor
:checkhealth
```

```bash
git diff
git status
```

### 插件更新后

```bash
git diff lazy-lock.json
```

确认变更符合预期再提交。

---

## 14. 安全地试验

1. **先开分支**

```bash
git switch -c experiment
```

2. **用 `:Lazy reload` 或重启验证**

3. **出问题看日志**

```vim
:messages
: Lazy log
:checkhealth
```

4. **回退**

```bash
git checkout -- lua/
git checkout -- lazy-lock.json
```

5. **插件版本回退**

```vim
:Lazy restore <插件名>
```

### 一个实用技巧

改配置时保留一个「已知可用」的 Neovim 实例不要退出。新开一个终端启动 `nvim` 测试；如果新实例崩了，旧实例还在，可以继续修。
