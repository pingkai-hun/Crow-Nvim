# CrowNvim

> **版本：Beta0.1.2**
> 基于 [LazyVim](https://github.com/LazyVim/LazyVim) 的个人 Neovim 配置。
> 目标：把 Vim 时代顺手的工作流完整搬到 Neovim，同时保持启动快、行为可预测、出问题能自己查。

![Neovim](https://img.shields.io/badge/Neovim-%E2%89%A50.10-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)
![License](https://img.shields.io/badge/License-MPL--2.0-blue)

---

## 目录

- [这是什么](#这是什么)
- [界面预览](#界面预览)
- [核心特性](#核心特性)
- [界面组成](#界面组成)
- [快速开始](#快速开始)
- [依赖清单](#依赖清单)
- [目录结构](#目录结构)
- [配置分层与加载顺序](#配置分层与加载顺序)
- [常用命令](#常用命令)
- [键位速查](#键位速查)
- [Python / 虚拟环境](#python--虚拟环境)
- [AI 能力](#ai-能力)
- [主题与外观](#主题与外观)
- [更新与回退](#更新与回退)
- [完整文档](#完整文档)
- [已知限制](#已知限制)
- [致谢与许可](#致谢与许可)

---

## 这是什么

CrowNvim 是一套以 **LazyVim 为底座**、但大量重写了默认行为的 Neovim 配置。

它不是「装完就能用」的极简模板，而是一份**有明确取舍的个人工作环境**：

- 键位以空格 `<Space>` 作为 `leader`，保留了大量 Vim 时代的肌肉记忆；
- 用 Neovim 原生 LSP + `blink.cmp` + `conform.nvim` 替代了 coc.nvim；
- 用 `snacks.nvim` 替代 fzf.vim / telescope 作为默认选择器；
- 用 `nvim-dap` 替代 vimspector；
- 中文界面与中文文档优先，LSP 悬浮文档和补全文档可以走本机 Ollama 翻译；
- 所有「为什么这么配」都写在对应 Lua 文件的头部注释里，方便日后自己改。

当前版本为 **Beta0.1.2**，配置仍在持续迭代，接口和键位可能小幅调整。

---

## 界面预览

启动页（`snacks.nvim` dashboard，艺术字是 `lua/plugins/ui-dashboard.lua` 里的 header）：

```text
                    ██████╗██████╗  ██████╗ ██╗    ██╗
                   ██╔════╝██╔══██╗██╔═══██╗██║    ██║
                   ██║     ██████╔╝██║   ██║██║ █╗ ██║
                   ██║     ██╔══██╗██║   ██║██║███╗██║
                   ╚██████╗██║  ██║╚██████╔╝╚███╔███╔╝
                     ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝
                    ███╗   ██╗██╗   ██╗██╗███╗   ███╗
                    ████╗  ██║██║   ██║██║████╗ ████║
                    ██╔██╗ ██║██║   ██║██║██╔████╔██║
                    ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
                    ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
                    ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝

              AI qwen2.5-coder:3b 在线 · <leader>oa 解释代码

                   Find File                    f
                   New File                     n
                   Projects                     p
                   Find Text                    g
                   Recent Files                 r
                   Config                       c
                   Restore Session              s
                   Lazy Extras                  x
                   Lazy                         l
                   Quit                         q

                ⚡ Neovim loaded 15/66 plugins in 72.64ms
```

状态栏是 lualine 的**圆角胶囊**样式：整条背景连成一整块，两端用
`\u{E0B6}` / `\u{E0B4}` 画半圆（需要终端字体含这两个 Nerd Font 字形）。

从左到右的分段：

| 段 | 内容 | 说明 |
|---|---|---|
| a | 左圆头 | 只是个半圆装饰，把整条状态栏"包"起来 |
| b | 模式 | `NORMAL` / `INSERT` / `VISUAL`，按模式变色 |
| c | 文件名 · 分支 · 改动行数 | 文件名带路径；`●` 表示已修改；`diff` 显示增删行数 |
| x | AI 状态 · LSP 客户端 · 诊断 | 有 AI 建议时亮起；LSP 显示已连接服务名（如 `pyright`）；诊断用 `● ▲ ○` 区分级别 |
| y | 编码 · 文件格式 · 文件类型 · 进度 | `utf-8` / `unix` / `lua` / `42%`（窄窗口自动隐藏部分段） |
| z | 行:列 + 右圆头 | `42:1`，末尾是右半圆 |

> 各段的实现见 `lua/plugins/lualine.lua`，界面文案是中文。

---

## 核心特性

### 编辑体验

- **原生 LSP**：跳转、引用、重命名、代码动作、签名帮助、诊断浮窗全部使用 Neovim 内置能力。
- **诊断展示**：符号列常驻，行尾虚拟文本只显示当前行；消息自动压成单行并附带规则名（如 `reportMissingImports`）。
- **`[d` / `]d` 跳转即预览**：跳到上/下一条诊断时自动弹出完整消息，不用再按 `gl`。
- **补全**：`blink.cmp`，菜单文案汉化，支持 LSP / Buffer / Path / Snippet / Emoji 等来源。
- **格式化**：`conform.nvim` 统一负责保存时格式化，避免和 LSP、vim-go 重复执行。
- **Treesitter**：语法高亮、缩进、文本对象、自动安装解析器。
- **Flash**：`s` / `S` / `r` / `R` 快速跳转与语法节点选择。
- **Surround / 多光标 / Yanky / EasyAlign / 自动括号**：常用编辑增强一应俱全。
- **大文件降级**：超过 1 MB 自动关闭 swap、undo、Treesitter 高亮与缩进，防止卡死。

### 搜索与导航

- `snacks.nvim` picker：文件、grep、buffer、LSP 符号、yank 历史、通知历史。
- 项目根智能识别：`.git` / `go.mod` / `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile` 等。
- `harpoon` 常用文件书签，按项目独立保存。
- `nvim-spider` 更符合代码语义的 `w` / `e` / `b` 移动。

### 语言支持

| 语言 | LSP | 格式化 | 其他 |
|---|---|---|---|
| Python | pyright（自动识别 `.venv` / venv-selector） | ruff（organize imports + format） | venv-selector、红队模板 |
| Go | gopls | goimports | vim-go 命令、nvim-dap-go 调试 |
| Rust | rust-analyzer（clippy on save） | rustfmt | rust.vim |
| C / C++ | clangd | clang-format | — |
| TypeScript / JavaScript | typescript-tools / tsserver | prettier | ESLint、自动 import 整理 |
| Lua | lua-language-server | stylua | lazydev |
| Shell | bash-language-server | shfmt | shellcheck |
| Vimscript | vim-language-server | — | — |
| C# | OmniSharp | — | — |

### Git

- `neogit`：Magit 风格状态面板、提交、分支、日志。
- `gitsigns`：行内 blame、hunk 暂存/重置/预览。
- `diffview.nvim`：文件历史、仓库历史、与 HEAD 对比。
- Lazygit 集成（需自行安装 `lazygit`）。

### AI

- **本机 Ollama**（完全离线）：
  - `minuet-ai.nvim` 行内幽灵补全（`qwen2.5-coder:1.5b`）；
  - `codecompanion.nvim` 对话 / 内联改写（`qwen2.5-coder:1.5b`）；
  - `crow.ai` 代码解释 / 审查 / 提问（`qwen2.5-coder:3b`）；
  - LSP 悬浮文档与补全文档自动翻译成中文（`qwen2.5-coder:3b`）。
- **GitHub Copilot**（可选，需登录）：CopilotChat 对话；行内补全默认关闭，避免和本地模型抢幽灵文本。

### 通知与 UI

- `noice.nvim` + `nvim-notify`：统一通知、命令行、LSP 悬浮窗风格。
- `lualine` 胶囊状态栏：模式、Git、诊断、LSP 客户端、AI 状态、Python venv、编码、文件类型、文件大小、进度。
- `tabby.nvim` 标签栏、`indent-blankline` 缩进线、`rainbow-delimiters` 彩虹括号。
- Catppuccin Mocha + 透明背景，语义色板让换主题时不会花屏。

---

## 界面组成

启动后你会看到：

```
┌──────────────────────────────────────────────────────────────┐
│  tabby 标签栏（多个 tab 时才有存在感）                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   CrowNvim Dashboard                                         │
│   ┌──────────────┐  ┌──────────────────────────────┐         │
│   │ 最近文件      │  │ 本机 AI 状态（Ollama 探活）   │         │
│   │ 快捷动作      │  │ 插件数量 / 启动耗时           │         │
│   └──────────────┘  └──────────────────────────────┘         │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│  lualine： NORMAL │ file │  git  │ diag │ LSP │ 🐍 .venv │ … │
└──────────────────────────────────────────────────────────────┘
```

Dashboard 的 ASCII 头是「CROW NVIM」两行式大字，窄终端也不会折行。右侧会探测 `http://127.0.0.1:11434`，显示 Ollama 是否在线以及模型是否已拉取。

---

## 快速开始

### 1. 备份现有配置

```bash
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak      # 可选：插件与缓存
mv ~/.local/state/nvim ~/.local/state/nvim.bak      # 可选：undo / session
```

### 2. 克隆仓库

```bash
git clone <仓库地址> ~/.config/nvim
```

如果 GitHub 直连不稳定，请自行配置 Git 代理或镜像，仓库本身不绑定任何特定代理。

### 3. 首次启动

```bash
nvim
```

首次启动会：

1. 自动安装 `lazy.nvim`；
2. 按 `lazy-lock.json` 安装全部插件；
3. 首次打开某类文件时自动安装对应 Treesitter 解析器；
4. 提示缺失的外部工具（见下一节）。

### 4. 体检

```bash
nvim +checkhealth
```

进入 Neovim 后执行：

```vim
:Doctor
```

`:Doctor` 会检查 Neovim 版本、主题、LSP 可执行文件、当前 buffer 诊断、Python 解释器、venv-selector 状态、外部工具、conform 格式化器、关键选项。

> 详细安装步骤、按平台的依赖安装命令见 **[docs/INSTALL.md](docs/INSTALL.md)**。

---

## 依赖清单

### 必需

| 依赖 | 用途 | 检查方式 |
|---|---|---|
| Neovim ≥ 0.10（推荐 0.11+） | 本体 | `nvim --version` |
| Git | 插件管理 | `git --version` |
| ripgrep (`rg`) | 全局搜索 | `rg --version` |
| Nerd Font | 图标 | 终端字体设置 |

### 强烈推荐

| 依赖 | 用途 |
|---|---|
| `fd` | 文件查找加速 |
| `lazygit` | `<leader>gg` / `<leader>gG` |
| `wl-clipboard`（Wayland）或 `xclip`（X11） | 系统剪贴板 |
| `curl` | Dashboard Ollama 探活、AI 请求 |
| `unzip` / `tar` / `gzip` | Mason / 插件安装 |

### 语言工具链

| 语言 | 需要安装 |
|---|---|
| Python | `pyright`、`ruff`，以及项目自己的 `.venv` |
| Go | `gopls`、`goimports`、`dlv`、`staticcheck` |
| Rust | `rust-analyzer`、`rustfmt`、`clippy` |
| C/C++ | `clangd`、`clang-format` |
| TypeScript | `typescript-language-server`、`prettier`、`eslint` |
| Lua | `lua-language-server`、`stylua` |
| Shell | `bash-language-server`、`shfmt`、`shellcheck` |
| Vimscript | `vim-language-server` |
| C# | `OmniSharp` / `dotnet` |

> LSP 配置里大多数服务器显式设置了 `mason = false`，因此**优先使用系统里已安装的可执行文件**。`:Mason` 仍可用于安装部分工具，但不要假设所有服务器都会由 Mason 自动装上。

### AI（可选）

| 依赖 | 用途 |
|---|---|
| [Ollama](https://ollama.com/) | 本地模型服务 |
| `qwen2.5-coder:3b` | `crow.ai`、文档翻译 |
| `qwen2.5-coder:1.5b` | 行内补全、CodeCompanion 对话 |
| GitHub Copilot 订阅 | CopilotChat（可选） |

```bash
ollama serve
ollama pull qwen2.5-coder:3b
ollama pull qwen2.5-coder:1.5b
```

---

## 目录结构

```text
~/.config/nvim
├── init.lua                 # 入口：按顺序加载 options / neovide / crow / keymaps / autocmds / lazy
├── VERSION                  # 当前版本（Beta0.1.2）
├── KEYMAPS.md               # 完整快捷键说明
├── lazy-lock.json           # 插件版本锁（提交到仓库，保证可复现）
├── lazyvim.json             # LazyVim extras 记录
├── stylua.toml              # Lua 格式化风格
├── LICENSE
├── docs/                    # 详细文档（安装、架构、插件、定制、AI、排错）
├── extras/                  # 未启用的备选配置（配色等），不在 runtimepath 内
└── lua/
    ├── config/
    │   ├── options.lua      # 基础选项（leader、缩进、搜索、剪贴板、外观）
    │   ├── neovide.lua      # 仅 Neovide 生效：字体、缩放、全屏、输入法
    │   ├── keymaps.lua      # 全局快捷键（Vim 风格 + 红队模板）
    │   ├── autocmds.lua     # 自动命令（光标恢复、行尾空白、配置重载、大文件降级）
    │   └── lazy.lua         # lazy.nvim 启动、插件 spec、更新检查、选项写回
    ├── crow/                # 自定义公共层
    │   ├── init.lua         # 项目根、通知、浮动终端、会话、:Theme/:Doctor 等命令
    │   ├── options.lua      # 在 LazyVim 之后写回选项
    │   ├── theme.lua        # 语义色板 + ColorScheme 高亮增强
    │   ├── palette.lua      # Catppuccin 四套 flavor 的语义颜色表
    │   ├── ai.lua           # 本机 Ollama 代码解释 / 审查 / 提问
    │   ├── translate.lua    # Ollama 流式翻译（缓存 + 串行队列）
    │   ├── doctor.lua       # :Doctor 环境体检
    │   └── guard.lua        # which-key 启动期防御
    └── plugins/             # 每个文件一个插件或一组插件
        ├── lsp.lua          # LSP + 诊断 + conform
        ├── blink.lua        # 补全汉化 / 文档翻译 / 样式
        ├── snacks.lua       # picker / explorer / notifier
        ├── ui-dashboard.lua # 启动页
        ├── lualine.lua      # 状态栏
        ├── venv-selector.lua
        ├── go.lua
        ├── typescript-tools.lua
        └── …
```

`extras/` 不在 runtimepath 里，存放**未启用**的备选配置（多套配色），
详见 [`extras/README.md`](extras/README.md)。

---

## 配置分层与加载顺序

`init.lua` 的顺序是刻意设计的，**不要随意调整**：

```lua
require("config.options")   -- 1. 选项必须先于 LazyVim
require("config.neovide")   -- 2. 仅 GUI 生效
require("crow").setup()     -- 3. 公共命令 / 主题 / 会话
require("crow.ai").setup()  -- 4. 本机 AI 命令
require("config.keymaps")   -- 5. 全局快捷键
require("config.autocmds")  -- 6. 自动命令
require("config.lazy")      -- 7. 最后启动 lazy.nvim
```

其中有两个容易踩的坑，配置里已经处理：

1. **LazyVim 会覆盖你的选项**
   LazyVim 的 `lazyvim/config/options.lua` 在 `lazy.setup()` 内部执行，比 `config/options.lua` **更晚**。所以 `scrolloff`、`sidescrolloff`、`pumheight`、`updatetime`、`clipboard` 这些值会在 `config/lazy.lua` 末尾由 `crow.options` 再写回一次，并监听 `VeryLazy` 防止被二次覆盖。

2. **which-key 的 500ms 定时器**
   which-key 的 plugin 脚本会在模块未初始化完时调用 `wk.setup()`，导致 `attempt to call field 'setup' (a nil value)`。`crow.guard` 在 `lazy.setup()` 之后幂等地补一次初始化，把崩溃变成正常。

更完整的解释见 **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**。

---

## 常用命令

| 命令 | 作用 |
|---|---|
| `:Lazy` | 插件管理面板 |
| `:Lazy update` | 更新全部插件 |
| `:Lazy update 插件名` | 更新单个插件 |
| `:Lazy sync` | 安装缺失 + 更新 + 清理 |
| `:Lazy clean` | 清理未使用插件 |
| `:checkhealth` | Neovim / 插件健康检查 |
| `:Doctor` | 本配置的环境体检 |
| `:Mason` | LSP / 工具安装面板 |
| `:Trouble` | 诊断 / 符号 / quickfix 面板 |
| `:Neogit` | Git 状态面板 |
| `:DiffviewOpen` | Diff 视图 |
| `:Theme <name>` | 切换任意配色 |
| `:CrowTheme <flavour>` | 切换 Catppuccin flavor（mocha / macchiato / frappe / latte） |
| `:ProjectRoot` | 切换到项目根目录 |
| `:Floaterm <cmd>` | 浮动终端执行命令 |
| `:VenvSelect` | 选择 Python 虚拟环境 |
| `:VenvSelectLog` | 查看 venv-selector 日志 |
| `:CrowExplain` | AI 解释当前函数 / 选区 |
| `:CrowReview` | AI 审查代码 |
| `:CrowAsk <问题>` | 带上下文向 AI 提问 |
| `:CrowAiStats` | 本机 AI 状态 |
| `:CrowAiStop` | 中断 AI 请求 |
| `:CodeCompanionChat` | 打开 CodeCompanion 对话 |
| `:Copilot auth` | 登录 GitHub Copilot |

---

## 键位速查

> `leader` = **空格**，`localleader` = `\`
> 完整键位见 **[KEYMAPS.md](KEYMAPS.md)**。不确定时按 `<leader>` 等 1 秒，或按 `<leader>?` 查看当前 buffer 的键位。

| 快捷键 | 作用 |
|---|---|
| `<leader>w` / `<leader>wq` / `<leader>q` | 保存 / 保存退出 / 退出 |
| `<leader>p` / `<leader>P` | 查找文件 / 在项目根查找文件 |
| `<leader>/` / `<leader>R` | 全局搜索 / 在项目根搜索 |
| `<leader>n` | 文件树 |
| `<leader>b` | 切换 buffer |
| `<leader>y` | Yank / 剪贴板历史 |
| `<leader>gg` | Lazygit |
| `<leader>gn` | Neogit 状态面板 |
| `gd` / `gr` / `K` / `gl` | 定义 / 引用 / 悬浮文档 / 诊断详情 |
| `[d` / `]d` | 上一条 / 下一条诊断（自动弹消息） |
| `<leader>rn` / `<leader>ac` | 重命名 / 代码动作 |
| `<leader>cf` | 格式化当前文件 |
| `<leader>xx` / `<leader>xX` | 项目诊断 / 当前 buffer 诊断 |
| `<F5>` / `<F9>` / `<F10>` / `<F11>` / `<F12>` | 调试：继续 / 断点 / 跳过 / 进入 / 跳出 |
| `<F6>` | 保存并运行当前 Python 脚本 |
| `<F7>` | 浮动终端 |
| `<F8>` | 代码大纲 |
| `<leader>cv` / `<leader>cV` / `<leader>cvr` | 选择 venv / 取消 / 重启 Python LSP |
| `<leader>oa` / `<leader>or` / `<leader>oq` / `<leader>oi` | AI 解释 / 审查 / 提问 / 状态 |
| `<leader>nn` / `<leader>nd` | 通知历史 / 关闭通知 |
| `<leader>?` | 当前 buffer 键位 |

---

## Python / 虚拟环境

CrowNvim 对 Python 做了专门处理：

1. **pyright 自动找解释器**
   启动 pyright 前按以下顺序选择：
   - 已激活的 `$VIRTUAL_ENV`；
   - venv-selector 当前选中的解释器；
   - 项目根目录下的 `.venv` / `venv` / `env`。

2. **venv-selector**
   - `<leader>cv`：打开选择器（picker 为 `snacks`）；
   - `<leader>cV`：取消激活（会设置 `venv_selector_disabled`，防止 pyright 又自动塞回 `.venv`）；
   - `<leader>cvr`：用当前环境重启 Python LSP；
   - 状态栏显示 `🐍 环境名`；
   - 每个项目记住上次选择。

3. **红队模板**（仅 Python buffer）
   - `<leader>ip`：IP 解析模板；
   - `<leader>req`：HTTP 探测模板；
   - `<leader>port`：端口扫描模板。

4. **诊断**
   `.venv` 里没装的包报 `reportMissingImports` 时，先执行 `:Doctor` 看 pyright 实际使用的解释器，再确认 venv-selector 的选择。

---

## AI 能力

| 能力 | 插件 / 模块 | 模型 | 触发方式 |
|---|---|---|---|
| 行内补全 | `minuet-ai.nvim` | `qwen2.5-coder:1.5b` | 插入模式自动触发 |
| 对话 / 内联改写 | `codecompanion.nvim` | `qwen2.5-coder:1.5b` | `:CodeCompanionChat` 等 |
| 代码解释 / 审查 / 提问 | `crow.ai` | `qwen2.5-coder:3b` | `<leader>oa` / `or` / `oq` |
| 悬浮文档翻译 | `crow.translate` + `noice` | `qwen2.5-coder:3b` | 自动 |
| 补全文档翻译 | `crow.translate` + `blink.cmp` | `qwen2.5-coder:3b` | 自动 |
| Copilot Chat | `CopilotChat.nvim` | GitHub Copilot | `<leader>aa` 等 |

所有本地 AI 都要求 Ollama 正在运行。Dashboard 会显示在线状态；`:CrowAiStats` 可以查看模型和服务详情。

详见 **[docs/AI.md](docs/AI.md)**。

---

## 主题与外观

- 默认主题：**Catppuccin Mocha**，透明背景。
- `:Theme <name>` 切换任意已安装配色。
- `:CrowTheme <flavour>` 在 Catppuccin 四套 flavor 间切换。
- 语义色板（`crow/palette.lua`）让行号、补全菜单、搜索、诊断标志、彩虹括号在换主题时保持一致。
- 已登记主题：Catppuccin、TokyoNight、Nightfox、OneDark（两套）、Dracula、Palenightfall（后四类需 `:Lazy sync` 安装，默认只装 Catppuccin 与 TokyoNight）。
- 未登记主题会回退到 Catppuccin Mocha 色板，不会花屏。

Neovide 额外支持：

| 快捷键 | 作用 |
|---|---|
| `<C-=>` / `<C-+>` | 放大 |
| `<C-->` | 缩小 |
| `<C-0>` | 缩放复位 |
| `<F11>` | 全屏切换 |

缩放值持久化到 `stdpath("state")/neovide/scale`。

---

## 更新与回退

### 更新插件

更新检查器已关闭（避免启动期 `git` 阻塞导致 which-key 报错），需要手动更新：

```vim
:Lazy update
```

更新后建议：

```bash
git -C ~/.config/nvim diff lazy-lock.json
```

确认无异常再提交。想回退某个插件：

```vim
:Lazy restore <插件名>
```

### 回退整个配置

```bash
git -C ~/.config/nvim log --oneline
git -C ~/.config/nvim checkout <commit> -- .
```

`lazy-lock.json` 已提交，因此回退配置后执行 `:Lazy restore` 可以把插件也恢复到锁定版本。

---

## 完整文档

| 文档 | 内容 |
|---|---|
| [KEYMAPS.md](KEYMAPS.md) | 全量快捷键说明（按功能分类） |
| [docs/INSTALL.md](docs/INSTALL.md) | 安装步骤、平台依赖、首次启动、卸载 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 加载顺序、分层设计、选项写回、关键兼容处理 |
| [docs/PLUGINS.md](docs/PLUGINS.md) | 插件清单与职责划分 |
| [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md) | 如何加插件、改键位、换主题、加 LSP / 格式化器 |
| [docs/AI.md](docs/AI.md) | 本机 Ollama、Copilot、翻译链路、模型选择 |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | 常见报错与修复方法 |
| [extras/README.md](extras/README.md) | 未启用的备选配置（配色）与启用方法 |

---

## 已知限制

- **GitHub 直连不稳定**时，需要自行配置 Git 代理或镜像。代理属于机器级设置，不写进仓库。
- **LSP 服务器不走 Mason 自动安装**（多数 `mason = false`），需要系统里已有可执行文件。
- **Copilot 行内补全默认关闭**，因为本地 minuet 已经占用幽灵文本；需要云端补全时改 `lua/plugins/copilot.lua` 的 `suggestion.enabled = true`。
- **AI 功能依赖本机 Ollama**，没有服务时所有翻译/解释会明确报错，不会静默失败。
- **配置仍在 Beta**，键位和插件选择可能变化。

---

## 致谢与许可

- 底座：[LazyVim](https://github.com/LazyVim/LazyVim) by folke
- 插件管理器：[lazy.nvim](https://github.com/folke/lazy.nvim)
- 主题：[Catppuccin](https://github.com/catppuccin/nvim)
- 以及 `lazy-lock.json` 中列出的所有插件作者。

本仓库代码采用 **Mozilla Public License 2.0（MPL 2.0）**，见 [LICENSE](LICENSE)。

> 如果你要直接使用这份配置，建议先通读 `docs/ARCHITECTURE.md` 和 `KEYMAPS.md`，再按自己的习惯改。配置里的注释比文档更详细，遇到「为什么这么写」优先看对应 Lua 文件头部。
