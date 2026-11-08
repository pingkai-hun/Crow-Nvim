# 插件清单

> 适用版本：**CrowNvim Beta0.1.2**
> 插件版本以根目录 `lazy-lock.json` 为准。本文说明「装了什么、为什么装、配置在哪」。

---

## 目录

- [1. 底座与插件管理](#1-底座与插件管理)
- [2. 编辑增强](#2-编辑增强)
- [3. 搜索、导航与文件](#3-搜索导航与文件)
- [4. LSP、补全与格式化](#4-lsp补全与格式化)
- [5. 语言专用](#5-语言专用)
- [6. Git](#6-git)
- [7. 调试](#7-调试)
- [8. AI](#8-ai)
- [9. UI 与通知](#9-ui-与通知)
- [10. 其它工具](#10-其它工具)
- [11. 配色方案](#11-配色方案)
- [12. 已禁用 / 保留](#12-已禁用--保留)

---

## 1. 底座与插件管理

| 插件 | 作用 | 配置 |
|---|---|---|
| `LazyVim/LazyVim` | 配置底座：默认插件、extras、键位、UI | `lua/config/lazy.lua` |
| `folke/lazy.nvim` | 插件管理器，自动 bootstrap | `lua/config/lazy.lua` |
| `folke/lazydev.nvim` | Lua LSP 增强，识别 `vim.*` 与 lazy.nvim API | LazyVim 默认 |
| `folke/which-key.nvim` | 键位提示；自定义分组、横向布局 | `lua/plugins/which-key.lua` |
| `folke/tokyonight.nvim` | 安装期兜底配色 | `lua/config/lazy.lua` |

LazyVim extras：

- `lazyvim.plugins.extras.linting.eslint`
- `lazyvim.plugins.extras.formatting.prettier`
- `lazyvim.plugins.extras.dap.core`

> 更新检查器已关闭，手动 `:Lazy update`。`lazy-lock.json` 必须提交。

---

## 2. 编辑增强

| 插件 | 作用 | 配置 / 键位 |
|---|---|---|
| `nvim-mini/mini.ai` | 增强 `a` / `i` 文本对象 | LazyVim 默认 |
| `nvim-mini/mini.pairs` | 自动括号；`<leader>up` 开关 | `lua/plugins/mini-pairs.lua` |
| `nvim-mini/mini.icons` | 图标后端 | LazyVim 默认 |
| `kylechui/nvim-surround` | `ys` / `cs` / `ds` 环绕 | `lua/plugins/nvim-surround.lua` |
| `windwp/nvim-ts-autotag` | HTML/JSX 标签自动闭合与重命名 | `lua/plugins/ts-autotag.lua` |
| `folke/flash.nvim` | `s` / `S` / `r` / `R` 快速跳转；搜索标签 | `lua/plugins/flash.lua` |
| `chrisgrieser/nvim-spider` | 更聪明的 `w` / `e` / `b` | `lua/plugins/nvim-spider.lua` |
| `mg979/vim-visual-multi` | 多光标；`<A-j>` / `<A-k>` 添加光标 | `lua/plugins/multi-cursor.lua` |
| `gbprod/yanky.nvim` | Yank 历史、粘贴增强 | `lua/plugins/yanky.lua` |
| `junegunn/vim-easy-align` | `ga` 对齐 | `lua/plugins/easyvim-extra.lua` |
| `mattn/emmet-vim` | HTML/CSS Emmet 展开 | `lua/plugins/easyvim-extra.lua` |
| `HiPhish/rainbow-delimiters.nvim` | 彩虹括号，跟随语义色板 | `lua/plugins/easyvim-extra.lua` |
| `lukas-reineke/indent-blankline.nvim` | 缩进参考线 | `lua/plugins/indent-blankline.lua` |
| `nmac427/guess-indent.nvim` | 自动探测缩进风格 | `lua/plugins/guess-indent.lua` |
| `tris203/precognition.nvim` | 显示可用 motion 提示 | `lua/plugins/precognition.lua` |
| `catgoose/nvim-colorizer.lua` | 颜色值高亮 | `lua/plugins/colorizer.lua` |
| `folke/todo-comments.nvim` | TODO / FIXME 高亮与跳转 | `lua/plugins/todo-comments.lua` |
| `folke/trouble.nvim` | 诊断 / 符号 / quickfix 面板 | LazyVim 默认 + `todo-comments` |
| `nvim-treesitter/nvim-treesitter` | 语法高亮、缩进、文本对象 | LazyVim 默认 |
| `nvim-treesitter/nvim-treesitter-textobjects` | Treesitter 文本对象 | LazyVim 默认 |
| `nvim-mini/mini.surround` | nvim-surround 的依赖/替代 | `lua/plugins/nvim-surround.lua` |

---

## 3. 搜索、导航与文件

| 插件 | 作用 | 配置 / 键位 |
|---|---|---|
| `folke/snacks.nvim` | **默认 picker / explorer / notifier / dashboard / terminal** | `snacks.lua`、`ui-dashboard.lua`、`image.lua` |
| `nvim-telescope/telescope.nvim` | 备用 picker；TODO 搜索 | `todo-comments.lua` |
| `ThePrimeagen/harpoon` | 常用文件书签 | `lua/plugins/harpoon.lua` |
| `folke/flash.nvim` | 屏幕内快速跳转 | 见编辑增强 |
| `nvim-lua/plenary.nvim` | 多个插件的底层依赖 | 自动 |
| `folke/persistence.nvim` | LazyVim 会话能力（本项目另有一套 `crow` 会话命令） | LazyVim 默认 |

### snacks 的职责

`snacks.nvim` 在本配置里承担了多项工作：

- `picker.files` / `grep` / `buffers` / `lsp_symbols` / `grep_word` / `yanky` / `notifications`；
- `explorer` 文件树（`<leader>n`）；
- `notifier` 通知渲染；
- `dashboard` 启动页；
- `terminal` 浮动终端（`<F7>`）；
- 图片 / SVG 预览（`image.lua`）。

因此 telescope 只作为兼容保留，不作为默认选择器。

---

## 4. LSP、补全与格式化

| 插件 | 作用 | 配置 |
|---|---|---|
| `neovim/nvim-lspconfig` | LSP 客户端配置、诊断样式、服务器参数 | `lua/plugins/lsp.lua` |
| `saghen/blink.cmp` | 补全引擎；菜单汉化、霓虹样式、文档翻译 | `lua/plugins/blink.lua` |
| `stevearc/conform.nvim` | 保存时格式化 | `lua/plugins/lsp.lua` |
| `williamboman/mason.nvim` | 工具安装面板 | LazyVim 默认 |
| `mason-lspconfig.nvim` | Mason 与 lspconfig 桥接 | LazyVim 默认 |
| `nvim-lint` | 异步 linter（ESLint 等） | LazyVim extras |
| `pmizio/typescript-tools.nvim` | TypeScript LSP 增强 | `lua/plugins/typescript-tools.lua` |
| `folke/lazydev.nvim` | Lua LSP 识别 Neovim API | LazyVim 默认 |

### 语言服务器

| 语言 | 服务器 | 安装方式 |
|---|---|---|
| Python | `pyright` | 系统 / pipx |
| Python 格式化 | `ruff` | 系统 / pipx |
| Go | `gopls` | `go install` |
| Rust | `rust-analyzer` | rustup |
| C/C++ | `clangd` | 系统包 |
| Lua | `lua-language-server` | 系统包 / Mason |
| Shell | `bash-language-server` | npm |
| Vimscript | `vim-language-server` | npm |
| TypeScript | `typescript-language-server` | npm |
| C# | `OmniSharp` | 系统 / Mason |

> 多数服务器在 `lsp.lua` 里设置了 `mason = false`，优先使用系统可执行文件。

---

## 5. 语言专用

### Python

| 插件 | 作用 | 配置 |
|---|---|---|
| `linux-cultist/venv-selector.nvim` | 虚拟环境选择、状态栏、pyright 重启 | `lua/plugins/venv-selector.lua` |
| pyright（LSP） | 诊断、类型检查、import 解析 | `lua/plugins/lsp.lua` |
| ruff（conform） | import 整理 + 格式化 | `lua/plugins/lsp.lua` |

### Go

| 插件 | 作用 | 配置 |
|---|---|---|
| `fatih/vim-go` | `:GoBuild` / `:GoRun` / `:GoTest` 等命令 | `lua/plugins/go.lua` |
| `gopls`（LSP） | 补全、诊断、重命名 | `lua/plugins/lsp.lua` |
| `leoluz/nvim-dap-go` | delve 调试接入 | `lua/plugins/go.lua` |

### Rust

| 插件 | 作用 | 配置 |
|---|---|---|
| `rust-lang/rust.vim` | Rust 语法与基础支持 | `lua/plugins/easyvim-extra.lua` |

### TypeScript / JavaScript

| 插件 | 作用 | 配置 |
|---|---|---|
| `pmizio/typescript-tools.nvim` | import 整理、重命名、修复 | `lua/plugins/typescript-tools.lua` |
| `windwp/nvim-ts-autotag` | JSX/HTML 标签 | `lua/plugins/ts-autotag.lua` |
| ESLint（LSP） | 诊断与修复 | LazyVim extras + `lua/plugins/eslint.lua` |

### HTTP / REST

| 插件 | 作用 | 配置 |
|---|---|---|
| `mistweaverco/kulala.nvim` | `.http` 文件请求执行、响应查看 | `lua/plugins/kulala.lua` |

### Markdown

| 插件 | 作用 | 配置 |
|---|---|---|
| `iamcco/markdown-preview.nvim` | 浏览器实时预览 | `lua/plugins/markdown-preview.lua` |

---

## 6. Git

| 插件 | 作用 | 配置 / 键位 |
|---|---|---|
| `NeogitOrg/neogit` | Magit 风格 Git 界面 | `lua/plugins/neogit.lua`；`<leader>gn*` |
| `sindrets/diffview.nvim` | diff / 文件历史 / 仓库历史 | `lua/plugins/diffview.lua`；`<leader>gd` 等 |
| `lewis6991/gitsigns.nvim` | 行内 blame、hunk 操作 | LazyVim 默认 |
| `folke/grug-far.nvim` | 项目级查找替换 | LazyVim 默认 |

---

## 7. 调试

| 插件 | 作用 | 配置 |
|---|---|---|
| `mfussenegger/nvim-dap` | 调试协议核心 | LazyVim extras |
| `rcarriga/nvim-dap-ui` | 调试界面 | LazyVim extras |
| `theHamsta/nvim-dap-virtual-text` | 行内显示变量值 | LazyVim extras |
| `leoluz/nvim-dap-go` | Go delve 适配 | `lua/plugins/go.lua` |
| `mason-nvim-dap.nvim` | 调试器安装桥接 | LazyVim extras |

键位：`<F5>` / `<F9>` / `<F10>` / `<F11>` / `<F12>`、`<leader>dr` / `dq` / `dR`。

---

## 8. AI

| 插件 | 作用 | 模型 / 配置 |
|---|---|---|
| `milanglacier/minuet-ai.nvim` | 行内幽灵补全 | `qwen2.5-coder:1.5b`；`minuet.lua` |
| `olimorris/codecompanion.nvim` | 对话 / 内联改写 / 动作面板 | `qwen2.5-coder:1.5b`；`codecompanion.lua` |
| `zbirenbaum/copilot.lua` | GitHub Copilot 行内补全（默认关闭） | `copilot.lua` |
| `CopilotC-Nvim/CopilotChat.nvim` | Copilot 对话 | `copilot-chat.lua` |
| `crow.ai`（自定义） | 解释 / 审查 / 提问 / 状态 | `qwen2.5-coder:3b`；`lua/crow/ai.lua` |
| `crow.translate`（自定义） | 悬浮文档 / 补全文档翻译 | `qwen2.5-coder:3b`；`lua/crow/translate.lua` |

详见 [AI.md](AI.md)。

---

## 9. UI 与通知

| 插件 | 作用 | 配置 |
|---|---|---|
| `folke/noice.nvim` | 命令行、popupmenu、LSP 浮窗、通知路由 | `noice.lua`、`notifications.lua`、`hover-translate.lua` |
| `rcarriga/nvim-notify` | 弹窗通知渲染 | `notifications.lua` |
| `nvim-lualine/lualine.nvim` | 胶囊状态栏 | `lua/plugins/lualine.lua` |
| `nanozuki/tabby.nvim` | 标签栏 | `lua/plugins/tabby.lua` |
| `akinsho/bufferline.nvim` | Buffer 标签栏（LazyVim 默认，可能被 tabby 取代） | LazyVim |
| `nvim-tree/nvim-web-devicons` | 文件图标 | `lua/plugins/web-dev-icons.lua` |
| `MunifTanjim/nui.nvim` | Noice / 通知的 UI 依赖 | 自动 |
| `folke/trouble.nvim` | 诊断与符号面板 | LazyVim 默认 |
| `catppuccin/nvim` | 默认主题 | LazyVim 自带 + `lua/crow/theme.lua` 增强 |
| `folke/tokyonight.nvim` | 备用主题 | LazyVim 自带 |

---

## 10. 其它工具

| 插件 | 作用 | 配置 |
|---|---|---|
| `folke/snacks.nvim` | 见搜索与 UI | 多个文件 |
| `nvim-lua/plenary.nvim` | 通用 Lua 库 | 自动 |
| `nvim-nio` | 异步 IO（Mason 等依赖） | 自动 |
| `folke/persistence.nvim` | LazyVim 会话 | LazyVim 默认 |
| `folke/which-key.nvim` | 键位提示 | `which-key.lua` |
| `gbprod/yanky.nvim` | Yank 历史 | `yanky.lua` |

---

## 11. 配色方案

### 实际启用

| 配色 | 插件 | 状态 |
|---|---|---|
| Catppuccin Mocha | `catppuccin/nvim` | **默认启用**（LazyVim 自带） |
| TokyoNight | `folke/tokyonight.nvim` | 已安装，可用 `:Theme tokyonight` 切换 |
| Gruvbox Material | `sainnhe/gruvbox-material` | 可选，`lua/crow/theme.lua` 有对应色板 |

决定用哪一套的是 `lua/config/lazy.lua` 末尾这一行（**最后加载的 spec 生效**）：

```lua
{ "LazyVim/LazyVim", opts = { colorscheme = "catppuccin-mocha" } }
```

### 未启用（存档在 `extras/colorschemes/`）

| 配色 | 插件 |
|---|---|
| Nightfox | `EdenEast/nightfox.nvim` |
| OneDark（navarasu） | `navarasu/onedark.nvim` |
| OneDark（joshdick） | `joshdick/onedark.vim` |
| Dracula | `Mofiqul/dracula.nvim` |
| Palenightfall | `JoosepAlviste/palenightfall.nvim` |
| Catppuccin / TokyoNight 的独立 spec | — |

> ⚠ 这些文件**不会自动加载**。lazy.nvim 的 `import` 只扫描一层：
> `lua/plugins/*.lua` 会被加载，而 `lua/plugins/<目录>/` 需要该目录有
> `init.lua` 才会被加载。所以它们被移到了 `extras/`（不在 runtimepath 内），
> 以避免"看起来配置了、实际没生效"。
>
> 启用方法：把文件复制回 `lua/plugins/` 根目录，再 `:Lazy sync`。
> 详见 [`extras/README.md`](../extras/README.md)。

### 切换

```vim
:CrowTheme mocha|macchiato|frappe|latte   " Catppuccin 四套 flavor
:Theme tokyonight                          " 其它已注册配色
```

透明背景、斜体注释、行号配色等视觉调整**不在**配色插件配置里，而在
`lua/crow/theme.lua`（语义色板见 `lua/crow/palette.lua`），它挂
`ColorScheme` 自动命令，所以换配色后依然生效。

---

## 12. 已禁用 / 保留

| 文件 / 插件 | 说明 |
|---|---|
| `extras/` | 不在 runtimepath，存放未启用的备选配置（配色等） |
| `lua/plugins/fix-mini-ai.lua` | 防御性补丁，不改第三方源码 |
| `lua/crow/guard.lua` | 启动期 which-key 防御 |
| `lua/plugins/image.lua` | snacks 图片预览，按需启用 |

### 为什么保留 telescope

- `todo-comments` 的 `:TodoTelescope` 仍在使用；
- yanky 的 picker 逻辑对 telescope 有回退分支；
- 用户可能临时想用 telescope 的高级功能。

默认 picker 仍是 snacks。

---

## 附：如何确认插件实际加载情况

```vim
:Lazy                 " 插件面板，查看 loaded / not loaded
:Lazy profile         " 启动耗时
:checkhealth          " 健康检查
:Doctor               " 本配置体检
```

`lazy-lock.json` 中每一项的 commit 就是当前锁定的版本。更新后请提交这个文件。
