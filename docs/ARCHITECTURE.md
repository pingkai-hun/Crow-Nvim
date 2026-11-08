# 架构与加载顺序

> 适用版本：**CrowNvim Beta0.1.2**
> 本文解释「为什么配置这样组织」以及「一个设置最终由谁生效」。改配置前建议先读一遍。

---

## 目录

- [1. 设计原则](#1-设计原则)
- [2. 三层结构](#2-三层结构)
- [3. 启动顺序](#3-启动顺序)
- [4. 选项优先级与写回](#4-选项优先级与写回)
- [5. lazy.nvim 配置](#5-lazynvim-配置)
- [6. 键位策略](#6-键位策略)
- [7. 自动命令](#7-自动命令)
- [8. 主题管线](#8-主题管线)
- [9. 通知管线](#9-通知管线)
- [10. AI 管线](#10-ai-管线)
- [11. 启动期防御](#11-启动期防御)
- [12. 插件加载策略](#12-插件加载策略)
- [13. 排障入口](#13-排障入口)

---

## 1. 设计原则

1. **顺序显式化**
   Neovim 配置最常见的坑是「以为设置了，其实被后加载的默认值覆盖」。CrowNvim 把加载顺序写死在 `init.lua`，并在关键位置二次写回。

2. **分层，不堆一个大文件**
   - `config/`：Neovim 自身行为（选项、键位、自动命令）。
   - `crow/`：可复用的公共能力（项目根、通知、主题、AI、体检）。
   - `plugins/`：每个插件一个文件，插件配置与业务逻辑分离。

3. **插件只做一件事**
   同一类能力不装两套。例如：

   - 选择器统一用 `snacks.nvim`，不默认启用 telescope；
   - 格式化统一交给 `conform.nvim`，vim-go / LSP 的保存格式化全部关闭；
   - 行内补全统一交给 `minuet-ai.nvim`，Copilot 行内补全默认关闭；
   - 补全统一用 `blink.cmp`，旧的 `nvim-cmp` 配置改名为 `.disabled`。

4. **失败要能看见，但不能打断编辑**
   能用 `pcall` 保护的地方就保护；通知统一走 `vim.notify`，由 Noice / nvim-notify 渲染。

5. **注释解释「为什么」**
   配置里大量注释不是重复代码，而是记录踩过的坑。改之前先读。

---

## 2. 三层结构

```text
┌──────────────────────────────────────────────────────────┐
│ init.lua                                                 │
│   只负责按顺序 require，不放具体配置                      │
└───────────────┬──────────────────────────────────────────┘
                │
    ┌───────────┴────────────┬─────────────────────┐
    ▼                        ▼                     ▼
┌─────────────┐      ┌─────────────┐       ┌─────────────┐
│ config/     │      │ crow/       │       │ plugins/    │
│ 编辑器行为   │      │ 公共能力     │       │ 插件声明     │
├─────────────┤      ├─────────────┤       ├─────────────┤
│ options     │      │ init        │       │ lsp         │
│ neovide     │      │ options     │       │ blink       │
│ keymaps     │      │ theme       │       │ snacks      │
│ autocmds    │      │ palette     │       │ lualine     │
│ lazy        │      │ ai          │       │ venv-selector│
│             │      │ translate   │       │ go          │
│             │      │ doctor      │       │ …           │
│             │      │ guard       │       │             │
└─────────────┘      └─────────────┘       └─────────────┘
```

### `config/`

| 文件 | 职责 |
|---|---|
| `options.lua` | `leader`、缩进、搜索、剪贴板、撤销、外观、provider 开关 |
| `neovide.lua` | 仅 Neovide 生效：字体、缩放持久化、全屏、IME |
| `keymaps.lua` | 全局快捷键；Python buffer 的红队模板 |
| `autocmds.lua` | 光标恢复、行尾空白、文件类型、配置重载、大文件降级、启动统计 |
| `lazy.lua` | 启动 lazy.nvim、插件 spec、更新检查、选项写回、which-key 防御 |

### `crow/`

| 模块 | 职责 |
|---|---|
| `init.lua` | 项目根探测、通知、浮动终端、会话、`:Theme` / `:CrowTheme` / `:ProjectRoot` / `:Floaterm` / `:Doctor` |
| `options.lua` | 在 LazyVim 之后写回选项 |
| `palette.lua` | Catppuccin 四套 flavor 的语义颜色表 |
| `theme.lua` | `ColorScheme` 钩子，把语义色套到行号、补全、搜索、诊断等 |
| `ai.lua` | 本机 Ollama 代码解释 / 审查 / 提问 / 状态 |
| `translate.lua` | Ollama 流式翻译，带 sha256 缓存与串行队列 |
| `doctor.lua` | `:Doctor` 环境体检 |
| `guard.lua` | 启动期确保 which-key 已完成 `setup()` |

### `plugins/`

每个文件返回一个 lazy.nvim spec 或 spec 列表。命名与职责对应，例如 `lsp.lua` 只管 LSP / 诊断 / 格式化，`snacks.lua` 只管 picker / explorer / notifier。

同一个插件的 spec 可以在多个文件中出现，lazy.nvim 会合并；但 `init` 字段会被后加载的覆盖，这一点在 `fix-mini-ai.lua` 里有说明。

---

## 3. 启动顺序

`init.lua` 的实际内容（省略注释）：

```lua
vim.g.crow_version = "Beta0.1.2"

require("config.options")   -- 1
require("config.neovide")   -- 2
require("crow").setup()     -- 3
require("crow.ai").setup()  -- 4
require("config.keymaps")   -- 5
require("config.autocmds")  -- 6
require("config.lazy")      -- 7
```

为什么必须是这个顺序：

1. **`options` 必须最先**
   `leader` 必须在任何键位注册前确定，否则 `<leader>` 会被解释成默认的 `\`。

2. **`neovide` 必须在插件前**
   `vim.g.neovide_*` 和 `guifont` 要在 GUI 初始化阶段就能读到；非 Neovide 环境会直接 `return`。

3. **`crow` 要早于键位**
   `config/keymaps.lua` 里直接 `require("crow")` 使用 `crow.notify`、`crow.toggle_terminal` 等函数。

4. **`crow.ai` 要早于 lazy**
   它在 `setup()` 里注册 `<leader>oa` 等键位和 `:CrowExplain` 命令。命令先注册，插件后加载，用户随时可用。

5. **`keymaps` / `autocmds` 在 lazy 之前**
   保证全局键位和自动命令不被插件默认值覆盖；插件自己的 buffer-local 键位再在之后叠加。

6. **`lazy` 最后**
   到这一步所有前置状态已就绪，才开始加载 LazyVim 和插件。

---

## 4. 选项优先级与写回

### 冲突从哪来

LazyVim 自带的 `lua/lazyvim/config/options.lua` **不是**在 `require("LazyVim")` 时执行，而是在 `require("lazy").setup()` 内部、处理 `LazyVim` spec 时才执行。

因此实际顺序是：

```text
config/options.lua        ← 你先设
        ↓
lazy.setup()
  └─ LazyVim options      ← 它覆盖你
        ↓
crow.options.setup()      ← 你再写回
        ↓
VimEnter / VeryLazy       ← 再写回一次，防止 clipboard 被改
```

### 被写回的选项

```lua
scrolloff      = 5    -- LazyVim 默认 4
sidescrolloff  = 5    -- LazyVim 默认 8
pumheight      = 12   -- LazyVim 默认 10
updatetime     = 300  -- LazyVim 默认 200
timeoutlen     = 500
ttimeoutlen    = 10
clipboard      = "unnamedplus"
```

`clipboard` 特别麻烦：LazyVim 会在 `User VeryLazy` 时把 clipboard 恢复成它启动时记录的值。所以 `crow.options.setup()` 既在 `lazy.setup()` 之后写一次，又监听 `VimEnter` 和 `User VeryLazy` 再写一次。

### 调试选项

```vim
:set scrolloff?
:verbose set scrolloff?
```

`verbose` 会告诉你最后是哪个文件设置的。如果看到 `lazyvim/config/options.lua`，说明写回没生效，检查 `config/lazy.lua` 末尾是否还调用了 `require("crow.options").setup()`。

---

## 5. lazy.nvim 配置

`config/lazy.lua` 的关键设置：

```lua
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.linting.eslint" },
    { import = "lazyvim.plugins.extras.formatting.prettier" },
    { import = "lazyvim.plugins.extras.dap.core" },
    { import = "plugins" },
    { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin-mocha" } },
  },
  defaults = {
    lazy = false,     -- 自定义插件默认立即加载，除非自己声明 event/cmd/keys/ft
    version = false,  -- 跟随最新 commit，不依赖可能缺失的 semver tag
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = false, notify = false },
  change_detection = { enabled = true, notify = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
```

### 为什么关闭更新检查器

`checker` 会在启动阶段用 `git` 查远端 tag，期间通过 `vim.wait` 阻塞主循环。阻塞期间定时器仍会触发，可能造成：

```text
checker → git → process → async → vim.wait
   ↓
which-key 的 500ms 定时器在插件加载到一半时执行
   ↓
require("which-key") 拿到未初始化完的模块
   ↓
attempt to call field 'setup' (a nil value)
```

关闭后启动更快，也避免这条竞态。需要更新时手动 `:Lazy update`。

### 为什么关闭变更通知

`change_detection.enabled = true` 保留自动重载，但 `notify = false` 去掉每次保存插件 spec 时的：

```text
# Config Change Detected. Reloading...
```

这行不是错误，只是提示。保留自动重载、去掉弹窗，编辑体验更安静。

### 禁用的内置插件

| 插件 | 原因 |
|---|---|
| `gzip` | 很少直接编辑 `.gz` |
| `tarPlugin` | 很少直接编辑 tar |
| `zipPlugin` | 很少直接编辑 zip |
| `tohtml` | 不用 `:TOhtml` |
| `tutor` | 不用 `:Tutor` |

`matchit`、`matchparen`、`netrwPlugin` 被注释保留，方便需要时恢复。

---

## 6. 键位策略

键位分三层，优先级从低到高：

1. **插件默认键位**（LazyVim、snacks、telescope 等）
2. **全局覆盖**（`config/keymaps.lua`、各 `plugins/*.lua` 的 `keys`）
3. **buffer-local**（`FileType` 自动命令、插件自己的 `buffer = true`）

### 为什么有些键和 LazyVim 默认不同

| 键位 | CrowNvim | LazyVim 默认 | 原因 |
|---|---|---|---|
| `<leader>cd` | 切换 cwd 到当前文件目录 | 当前行诊断 | 保留 Vim 时代习惯；诊断改用 `gl` |
| `<leader>y` | Yank / 剪贴板历史 | 无 | `<leader>p` 已被「查找文件」占用 |
| `<leader>n` | 文件树 | 通知历史 | 文件树更常用；通知历史用 `<leader>N` |
| `<leader>D` | `:Doctor` | 无 | 环境体检入口 |
| `<leader>o` | 本机 Ollama / AI | 无 | 与 Copilot 的 `<leader>a` 分开 |

### 红队模板

只在 `python` buffer 生效，通过 `FileType` 自动命令注册：

```lua
<leader>ip     IP 解析模板
<leader>req    HTTP 探测模板
<leader>port   端口扫描模板
```

插入后光标停在占位文字处，直接输入即可。

### 查看键位

```vim
<leader>?      " 当前 buffer 的键位（which-key show global=false）
<leader>       " 等 1 秒，全局分组菜单
:map <leader>  " 原始映射列表
```

---

## 7. 自动命令

`config/autocmds.lua` 按 augroup 分组，避免重复注册：

| augroup | 触发 | 行为 |
|---|---|---|
| `EasyEditing` | `BufReadPost` | 恢复上次光标位置 |
| `EasyEditing` | `BufWritePre` | 删除行尾空白（跳过 markdown / text / gitcommit / diff） |
| `EasyFileType` | `FileType` | Markdown/Text 折行 + 拼写；JSON/YAML 2 空格；Rust/C/C++ 交给 conform |
| `EasyConfigReload` | `BufWritePost` | 保存配置后自动 `source init.lua` |
| `EasyWindows` | `VimResized` | 均分窗口 |
| `EasyWindows` | `FileType` | 临时窗口用 `q` 关闭 |
| `EasyPerformance` | `BufReadPre` | >1 MB 文件关闭 swap / undo / TS 高亮 |
| `EasyNotifications` | `VimEnter` | 显示启动耗时与插件数 |
| `EasyRedTeamTemplates` | `FileType python` | 注册红队模板键位 |
| `CrowSession` | `VimLeavePre` | 会话自动保存（开启时） |
| `CrowEnsureOptions` | `VimEnter` / `User VeryLazy` | 再写回选项 |

### 配置热重载的边界

保存 `lua/plugins/*.lua` 后，`BufWritePost` 会重新 `source init.lua`，但**插件 spec 的变更需要重启或 `:Lazy reload`**，因为 lazy.nvim 不会重新扫描已加载的 spec。`change_detection` 只负责提示和部分自动重载。

---

## 8. 主题管线

```text
palette.lua（语义色表）
        ↓
theme.lua（把语义色映射到具体高亮组）
        ↓
ColorScheme 事件（每次换主题重新应用）
        ↓
catppuccin / tokyonight / nightfox / onedark / dracula / palenightfall
```

### 为什么需要语义色板

直接写死 `#89b4fa` 这类颜色，换主题后会出现：

- 行号还是 Catppuccin 的灰蓝；
- 补全菜单背景和主题不搭；
- 搜索高亮刺眼；
- 彩虹括号颜色不变。

`palette.lua` 为每套主题登记一组语义名（`bg0..bg5`、`fg0`、`grey0..2`、`red/orange/yellow/green/aqua/blue/purple`），`theme.lua` 只引用语义名。未登记的主题回退到 Catppuccin Mocha 色板。

### 当前主题

- 默认 `catppuccin-mocha`，透明背景；
- `:Theme <name>` 切换任意已安装配色；
- `:CrowTheme mocha|macchiato|frappe|latte` 切换 Catppuccin flavor；
- lualine 的色板也会跟着刷新。

### 新增主题

1. 在 `lua/plugins/` **根目录**加一个 spec（不要放进子目录——lazy 的
   `import` 只扫一层，子目录需要 `init.lua` 才会被加载）；
2. 在 `crow/palette.lua` 的 `M.tables` 里登记同名色表；
3. 确保 `M.names()` 能返回它（通常自动完成）。

> 未启用的配色存档在 `extras/colorschemes/`，启用方式见
> [`extras/README.md`](../extras/README.md)。

---

## 9. 通知管线

```text
vim.notify / LSP / 插件
        ↓
noice.nvim（路由、视图、命令行）
        ↓
nvim-notify（弹窗渲染、动画、历史）
```

相关文件：

- `lua/plugins/noice.lua`：命令行、popupmenu、LSP 悬浮窗；
- `lua/plugins/notifications.lua`：通知路由、消息视图、`<leader>n*` 键位。

### 关键约定

- **只有 Noice 能接管 `vim.notify`**。
  venv-selector 的 `override_notify` 必须保持 `false`，否则 `:checkhealth noice` 会报：

  ```text
  `vim.notify` has been overwritten by another plugin?
  ```

- 错误 / 警告通知保留 30 秒，不会一闪而过；
- `<leader>nn` 通知历史，`<leader>nd` 关闭通知；
- `:checkhealth noice` 应显示 `✅ OK vim.notify is set to Noice`。

---

## 10. AI 管线

```text
                    ┌─────────────────────────────┐
                    │ Ollama 127.0.0.1:11434      │
                    └──────────────┬──────────────┘
          ┌────────────────────────┼────────────────────────┐
          ▼                        ▼                        ▼
   minuet-ai.nvim           codecompanion.nvim          crow.ai
   qwen2.5-coder:1.5b       qwen2.5-coder:1.5b          qwen2.5-coder:3b
   行内幽灵补全              对话 / 内联改写              解释 / 审查 / 提问
                                                           │
                                                           ▼
                                                    crow.translate
                                                    （悬浮文档 / 补全文档翻译）
```

- `minuet` 只在 InsertEnter 后触发，只作用于代码类 filetype；
- `codecompanion` 用 `<leader>oc` / `ov` / `oe`；
- `crow.ai` 用 `<leader>oa` / `or` / `oq` / `oi`；
- `crow.translate` 被 `hover-translate.lua` 和 `blink.lua` 复用，带 sha256 缓存，只翻译「最新」请求，过期请求丢弃。

详见 [AI.md](AI.md)。

---

## 11. 启动期防御

### `crow.guard`

which-key 的 plugin 脚本有：

```lua
local wk = require("which-key")
if not wk.did_setup then
  wk.setup()
end
```

如果模块在 500ms 定时器触发时还没初始化完，`wk.setup` 可能是 `nil`。`crow.guard` 在 `lazy.setup()` 后检查 `did_setup`，必要时补一次幂等初始化。

### `fix-mini-ai.lua`

LazyVim 的 mini.ai / mini.pairs 集成和 Snacks 的 Toggle 注册会直接调用 `require("which-key").add()`。插件延迟加载或重载时 `add` 可能还是 `nil`：

```text
lazyvim/util/mini.lua:79: attempt to call field 'add' (a nil value)
snacks/toggle.lua:132:   attempt to call field 'add' (a nil value)
```

`fix-mini-ai.lua` 不修改第三方源码，只包装：

1. `LazyVim.mini.ai_whichkey`
2. `Snacks.util.on_module`

模块未就绪时稍后重试。

---

## 12. 插件加载策略

`defaults.lazy = false` 意味着自定义插件默认立即加载，**除非**自己声明：

| 触发 | 例子 |
|---|---|
| `event = "InsertEnter"` | minuet |
| `event = "VeryLazy"` | tabby |
| `cmd = "..."` | CopilotChat、CodeCompanion |
| `keys = { ... }` | diffview、neogit、harpoon |
| `ft = "python"` | venv-selector |
| `ft = { "go", ... }` | vim-go |

启动关键路径上只剩 LazyVim 核心和少量立即加载的 UI 插件。启动耗时会在 `VimEnter` 后用通知显示。

### 启动统计

```text
⚡ Neovim 123.45ms / 45/70 插件
```

注意：`lazy.stats` 在不同时机可能是函数也可能是表，`autocmds.lua` 对两种都做了兼容。

---

## 13. 排障入口

| 命令 | 用途 |
|---|---|
| `:Doctor` | 本配置的完整体检 |
| `:checkhealth` | Neovim / 插件健康检查 |
| `:Lazy profile` | 启动耗时分析 |
| `:Lazy log` | 插件加载日志 |
| `:messages` | 历史消息（含被 Noice 路由的） |
| `:verbose set <option>?` | 选项最后由谁设置 |
| `:verbose map <key>` | 键位最后由谁映射 |
| `:Lazy restore` | 回退插件到 `lazy-lock.json` |

更具体的报错处理见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。
