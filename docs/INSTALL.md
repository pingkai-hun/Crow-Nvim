# 安装与依赖

> 适用版本：**CrowNvim Beta0.1.2**
> 本文假设你把配置放在 `~/.config/nvim`。路径不同时请自行替换。

---

## 目录

- [1. 系统要求](#1-系统要求)
- [2. 安装 Neovim](#2-安装-neovim)
- [3. 基础工具](#3-基础工具)
- [4. 语言工具链](#4-语言工具链)
- [5. 字体与终端](#5-字体与终端)
- [6. 获取配置](#6-获取配置)
- [7. 首次启动](#7-首次启动)
- [8. 安装后检查](#8-安装后检查)
- [9. 可选：本机 AI](#9-可选本机-ai)
- [10. 可选：GitHub Copilot](#10-可选github-copilot)
- [11. 卸载](#11-卸载)
- [12. 更新](#12-更新)

---

## 1. 系统要求

| 项目 | 要求 |
|---|---|
| Neovim | **≥ 0.10**，推荐 0.11 或 0.12 |
| Git | 任意较新版本 |
| 操作系统 | Linux 优先（Arch / Debian / Fedora 均可）；macOS 可用 |
| 终端 | 支持真彩色（termguicolors）与 Nerd Font |
| 磁盘 | 约 200 MB（插件、Treesitter 解析器、Mason 工具） |

配置里用到了 `vim.uv`、`vim.fs`、`vim.diagnostic.jump`（有回退）、`vim.islist` 等 API。低于 0.10 会缺少部分能力，不保证可用。

---

## 2. 安装 Neovim

### Arch Linux

```bash
sudo pacman -S --needed neovim
```

想用最新稳定版可以用 `neovim-git`（AUR）：

```bash
yay -S neovim-git
```

### Debian / Ubuntu

发行版仓库的版本往往偏旧，建议使用官方 AppImage 或 PPA：

```bash
# 官方 AppImage（推荐）
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod +x nvim-linux-x86_64.appimage
sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim
```

### Fedora

```bash
sudo dnf install -y neovim
```

### macOS

```bash
brew install neovim
```

安装后确认：

```bash
nvim --version | head -1
```

---

## 3. 基础工具

### Arch Linux

```bash
sudo pacman -S --needed git ripgrep fd unzip curl wget \
  wl-clipboard xclip lazygit
```

> Wayland 用 `wl-clipboard`，X11 用 `xclip`，装一个即可。

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install -y git ripgrep fd-find unzip curl wget \
  wl-clipboard xclip
# Ubuntu 的 fd 可执行文件叫 fdfind，建议做个别名：
sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
```

Lazygit 需要单独安装，参考官方 release。

### macOS

```bash
brew install git ripgrep fd unzip curl wget lazygit
```

### 必需 / 推荐一览

| 工具 | 是否必需 | 用途 |
|---|---|---|
| `git` | 必需 | lazy.nvim 拉取插件 |
| `rg`（ripgrep） | 必需 | `<leader>/`、`<leader>R` 全局搜索 |
| `fd` | 推荐 | 文件查找、venv 搜索加速 |
| `curl` | 推荐 | Dashboard Ollama 探活、AI 请求 |
| `unzip` / `tar` / `gzip` | 推荐 | 插件与工具解压 |
| `lazygit` | 可选 | `<leader>gg` / `<leader>gG` |
| `wl-clipboard` / `xclip` | 推荐 | 系统剪贴板 |
| Nerd Font | 推荐 | 图标显示 |

---

## 4. 语言工具链

> 本配置中的 LSP 大多显式设置了 `mason = false`，因此**优先使用系统里已安装的可执行文件**。`:Mason` 仍然可用，但不要假设所有服务器都会被自动装上。

### Python

```bash
# 推荐用 pipx 隔离安装
pipx install pyright
pipx install ruff

# 或者在项目虚拟环境里
pip install pyright ruff
```

`pyright` 需要 Node.js（`pipx` 版本会自带依赖，npm 版本需要 `nodejs`）。

### Go

```bash
go install golang.org/x/tools/gopls@latest
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
```

确保 `~/go/bin` 在 `PATH` 中。配置已经在 Neovim 内部把 `~/go/bin` 加到 `PATH` 前面。

### Rust

```bash
rustup component add rust-analyzer rustfmt clippy
```

### C / C++

```bash
# Arch
sudo pacman -S --needed clang

# Debian / Ubuntu
sudo apt install -y clang clangd clang-format
```

### TypeScript / JavaScript

```bash
npm install -g typescript typescript-language-server prettier eslint
```

### Lua

```bash
# Arch
sudo pacman -S --needed lua-language-server stylua

# 或通过 Mason
# :MasonInstall lua-language-server stylua
```

### Shell

```bash
# Arch
sudo pacman -S --needed bash-language-server shfmt shellcheck

# Debian / Ubuntu
sudo apt install -y shellcheck shfmt
npm install -g bash-language-server
```

### Vimscript

```bash
npm install -g vim-language-server
```

### C#

安装 .NET SDK 与 OmniSharp，或通过 Mason 安装。

### 快速检查

进入 Neovim 后执行：

```vim
:Doctor
```

会逐项列出语言服务器、格式化工具、外部命令是否存在。

---

## 5. 字体与终端

- 推荐字体：**Maple Mono NF CN**（Neovide 配置里默认使用 `Maple Mono NF CN:h14`）。
- 终端里使用任意 **Nerd Font** 即可，否则图标会显示成方块。
- 终端需要支持真彩色：

```vim
:set termguicolors?
```

- 透明背景由终端（Ghostty / kitty 的 `background-opacity`）负责，Neovim 只负责把背景色设为 `NONE`。

Neovide 用户：

```bash
# Arch
yay -S neovide
```

字体不存在时修改 `lua/config/neovide.lua` 里的 `vim.o.guifont`。

---

## 6. 获取配置

### 备份现有配置

```bash
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak      # 可选：插件与缓存
mv ~/.local/state/nvim ~/.local/state/nvim.bak      # 可选：undo / session
```

### 克隆

```bash
git clone <仓库地址> ~/.config/nvim
```

如果 GitHub 直连不稳定，请自行配置 Git 代理或镜像。仓库本身不绑定任何特定代理。

### 目录权限

确保配置目录归当前用户所有：

```bash
chown -R "$USER":"$USER" ~/.config/nvim
```

---

## 7. 首次启动

```bash
nvim
```

首次启动流程：

1. `init.lua` 加载选项、Neovide 适配、`crow` 公共层、键位、自动命令；
2. `config/lazy.lua` 检测并自动安装 `lazy.nvim`；
3. 按 `lazy-lock.json` 安装全部插件；
4. 打开文件时按需安装 Treesitter 解析器；
5. Dashboard 显示 Ollama 在线状态（未安装 Ollama 时显示离线提示）。

首次安装可能较慢，取决于网络。安装完成后建议重启一次 Neovim。

> **不要跳过 `lazy-lock.json`**：它锁定了所有插件的 commit，保证换机器后行为一致。

---

## 8. 安装后检查

### 健康检查

```vim
:checkhealth
```

重点看：

- `provider`：Python / Perl / Ruby provider 已被显式关闭，属正常；
- `clipboard`：是否找到 `wl-copy` / `xclip`；
- `treesitter`：解析器是否齐全；
- `noice`：`vim.notify` 是否由 Noice 接管；
- `venv-selector`：Python 环境选择器是否正常。

### 环境体检

```vim
:Doctor
```

输出包含：

- CrowNvim 版本、Neovim 版本、主题、剪贴板；
- 各语言服务器可执行文件路径；
- 当前 buffer 的 LSP 客户端；
- 当前 buffer 诊断摘要；
- Python 解释器、`.venv`、venv-selector 状态；
- 外部工具、conform 格式化器；
- leader、`completeopt`、`updatetime` 等关键选项。

### 快速验证

| 操作 | 预期 |
|---|---|
| 按 `<leader>` 等 1 秒 | which-key 弹出分组菜单 |
| `<leader>p` | snacks 文件选择器 |
| `:Lazy` | 插件面板，无红色报错 |
| 打开 `.py` 文件 | pyright 连接，状态栏显示 LSP 客户端 |
| `<leader>cv` | venv-selector 打开 |
| `<leader>D` | `:Doctor` 报告 |

---

## 9. 可选：本机 AI

### 安装 Ollama

```bash
# Arch
sudo pacman -S --needed ollama
# 或官方脚本
curl -fsSL https://ollama.com/install.sh | sh
```

启动服务：

```bash
systemctl --user enable --now ollama
# 或前台运行
ollama serve
```

### 拉取模型

```bash
ollama pull qwen2.5-coder:3b     # crow.ai / 文档翻译
ollama pull qwen2.5-coder:1.5b   # 行内补全 / CodeCompanion
```

### 验证

```bash
curl http://127.0.0.1:11434/api/tags
```

Neovim 内：

```vim
:CrowAiStats
```

Dashboard 也会显示 AI 状态。详见 [AI.md](AI.md)。

---

## 10. 可选：GitHub Copilot

Copilot **不是必需**。行内补全默认关闭，只用 CopilotChat 时也需要订阅。

```vim
:Copilot auth
```

按提示在浏览器完成授权。授权后可用的键位：

| 键位 | 作用 |
|---|---|
| `<leader>aa` | 打开 / 关闭 CopilotChat |
| `<leader>ax` | 清空对话 |
| `<leader>aq` | 快速提问 |
| `<leader>ap` | 预设 Prompt |

想让 Copilot 重新接管行内补全，修改 `lua/plugins/copilot.lua`：

```lua
suggestion = { enabled = true, auto_trigger = true },
```

同时建议关闭 `lua/plugins/minuet.lua`，避免两套幽灵文本重叠。

---

## 11. 卸载

```bash
rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.cache/nvim
```

如果之前备份过：

```bash
mv ~/.config/nvim.bak ~/.config/nvim
mv ~/.local/share/nvim.bak ~/.local/share/nvim
mv ~/.local/state/nvim.bak ~/.local/state/nvim
```

---

## 12. 更新

更新检查器已关闭，避免启动期 `git` 阻塞引发 which-key 报错。手动更新：

```vim
:Lazy update
```

更新后检查锁文件：

```bash
git -C ~/.config/nvim diff lazy-lock.json
```

确认无异常再提交。回退单个插件：

```vim
:Lazy restore <插件名>
```

回退全部插件到锁文件版本：

```vim
:Lazy restore
```
