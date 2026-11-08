# 排错指南

> 适用版本：**CrowNvim Beta0.1.2**
> 遇到问题时，先按本文的「快速诊断」收集信息，再按症状查找对应章节。

---

## 目录

- [1. 快速诊断](#1-快速诊断)
- [2. 启动与加载错误](#2-启动与加载错误)
- [3. 配置不生效](#3-配置不生效)
- [4. 通知与 UI](#4-通知与-ui)
- [5. LSP 与诊断](#5-lsp-与诊断)
- [6. Python 与 venv](#6-python-与-venv)
- [7. 格式化](#7-格式化)
- [8. 搜索与文件树](#8-搜索与文件树)
- [9. Treesitter](#9-treesitter)
- [10. 剪贴板与字体](#10-剪贴板与字体)
- [11. AI 与 Ollama](#11-ai-与-ollama)
- [12. Git 与插件更新](#12-git-与插件更新)
- [13. 性能问题](#13-性能问题)
- [14. 日志与反馈](#14-日志与反馈)

---

## 1. 快速诊断

```vim
:Doctor           " 本配置的完整体检
:checkhealth      " Neovim / 插件健康检查
:messages         " 本次会话的所有消息
:Lazy             " 插件是否加载、是否有报错
:Lazy log         " 插件加载日志
```

Shell 侧：

```bash
nvim --version
git --version
rg --version
fd --version
```

### 最小复现

出问题时先判断是不是某个插件引起的：

```bash
nvim --clean          # 不加载任何配置
nvim -u NONE          # 连内置插件都不加载
```

如果 `--clean` 正常，问题在配置或插件；如果 `--clean` 也异常，问题在 Neovim / 终端 / 系统。

---

## 2. 启动与加载错误

### `attempt to call field 'setup' (a nil value)`（which-key）

完整报错类似：

```text
which-key.nvim/plugin/which-key.lua:8: attempt to call field 'setup' (a nil value)
```

原因：which-key 的 plugin 脚本有 500ms 定时器，模块未初始化完时会调用 `wk.setup()`。

配置已经通过 `lua/crow/guard.lua` 处理：在 `lazy.setup()` 后检查 `did_setup`，必要时补一次幂等初始化。

如果仍然出现：

1. 确认 `lua/config/lazy.lua` 末尾有：

```lua
require("crow.guard").setup()
```

2. 执行：

```vim
:lua print(require("which-key").did_setup)
```

应为 `true`。

3. 检查是否有其他插件覆盖了 `which-key`。

### `attempt to call field 'add' (a nil value)`

完整报错：

```text
lazyvim/util/mini.lua:79: attempt to call field 'add' (a nil value)
snacks/toggle.lua:132:   attempt to call field 'add' (a nil value)
```

原因：LazyVim 的 mini 集成或 Snacks 在 which-key 未就绪时调用 `require("which-key").add()`。

配置已通过 `lua/plugins/fix-mini-ai.lua` 包装：

- `LazyVim.mini.ai_whichkey`
- `Snacks.util.on_module`

模块未就绪时延后重试。

如果仍然出现，确认这个文件没有被禁用：

```vim
:Lazy
```

在列表中确认 `fix-mini-ai` 对应的 spec 已加载（它不是独立插件，随 `plugins` 目录加载）。

### `# Config Change Detected. Reloading...`

这不是错误，是 lazy.nvim 的变更提示。配置里已关闭通知：

```lua
change_detection = { enabled = true, notify = false },
```

如果你仍然看到，检查是否有其他文件覆盖了 `change_detection`。

### `checker.lua → git.lua → process.lua → async.lua → vim.wait`

这是启动期更新检查阻塞主循环导致的竞态。配置已关闭：

```lua
checker = { enabled = false, notify = false },
```

需要更新插件时手动 `:Lazy update`。

### `E5108` / Lua 语法错误

```bash
luac -p ~/.config/nvim/init.lua
find ~/.config/nvim/lua -name '*.lua' -exec luac -p {} \;
```

或者用 `stylua --check`。

配置里所有文件都应是合法 Lua。常见错误：

- 少 `end`
- 表字段少了逗号
- 在 `opts = function(_, opts)` 里忘记 `return opts`

---

## 3. 配置不生效

### 选项被覆盖

```vim
:verbose set scrolloff?
```

如果最后设置者是 `lazyvim/config/options.lua`，说明需要改 `lua/crow/options.lua` 的 `M.values`，而不只是 `config/options.lua`。

原因见 [ARCHITECTURE.md](ARCHITECTURE.md#4-选项优先级与写回)。

### 键位不生效

```vim
:verbose map <leader>xx
```

- 没有输出：键位没注册；
- 输出指向别的文件：被后加载的 spec 覆盖；
- 只在某种文件里没有：那是 buffer-local 键位，检查 `FileType` 条件。

### 插件配置没生效

lazy.nvim 会合并同一个插件的多个 spec。检查：

```vim
:Lazy
```

选中插件，按 `Enter` 查看：

- `opts`
- `keys`
- `config`
- 加载时机

同一个插件在多个文件里出现时，后加载的 `init` 会覆盖前面的；`opts` 通常会合并。

### 保存配置后没重载

`BufWritePost` 会重新 `source init.lua`，但**插件 spec 的增删需要重启**：

```vim
:Lazy reload <插件名>
```

或者直接重启 Neovim。

---

## 4. 通知与 UI

### `` `vim.notify` has been overwritten by another plugin? ``

`:checkhealth noice` 报这个，说明有插件替换了 `vim.notify`。

本配置的约定：

- 只有 Noice 接管 `vim.notify`；
- venv-selector 必须设置：

```lua
override_notify = false,
```

检查：

```vim
:checkhealth noice
```

应显示：

```text
✅ OK vim.notify is set to Noice
```

如果仍有问题，搜索配置里是否有人调用：

```lua
vim.notify = require("notify")
```

不要这样做。

### 通知太多 / 太吵

- 启动统计：`lua/config/autocmds.lua` 的 `VimEnter`；
- 配置重载提示：`EasyConfigReload`；
- 大文件提示：`EasyPerformance`。

按需注释对应 `vim.notify`。

### 通知一闪而过

`lua/plugins/notifications.lua` 里错误 / 警告路由的 `timeout` 是 30 秒。检查是否有其他 route 抢先匹配。

### 命令行 / 搜索框样式异常

Noice 配置在 `lua/plugins/noice.lua`。可以临时关闭：

```vim
:Noice disable
```

确认是不是 Noice 引起的。

---

## 5. LSP 与诊断

### LSP 没启动

```vim
:LspInfo
:checkhealth lspconfig
:Doctor
```

常见原因：

1. 可执行文件不在 `PATH`；
2. 文件类型没有关联；
3. 项目根识别错误；
4. 服务器启动参数有误。

`lua/plugins/lsp.lua` 里多数服务器设置了 `mason = false`，需要系统已安装。

### `Import "xxx" could not be resolved`

这是 Python 最常见的问题，通常是 pyright 没用项目虚拟环境。

1. 打开 Python 文件；
2. 执行 `:Doctor`，看：

```text
【Python 解释器】
  项目根        ...
  .venv         存在 / 不存在
  pyright 使用  ...
  venv-selector 已选择 ...
```

3. 如果 `pyright 使用` 不是项目 `.venv`：

```vim
:VenvSelect
```

选择正确的环境，或 `<leader>cvr` 重启 Python LSP。

4. 确认包真的装在环境里：

```bash
.venv/bin/python -c "import bs4; print(bs4.__version__)"
```

5. 如果 `.venv` 存在但 pyright 仍不用，检查 `before_init` 是否被其他配置覆盖。

### 诊断不显示

`lua/plugins/lsp.lua` 的配置：

- 符号列常驻；
- 行尾虚拟文本只在当前行；
- 级别 ≥ WARN；
- 关闭了 `virtual_lines`。

检查：

```vim
:lua =vim.diagnostic.config()
```

如果 `virtual_text = false`，说明被其他插件覆盖。

### `[d` / `]d` 不弹消息

配置使用 Neovim 0.11+ 的：

```lua
jump = { on_jump = function(d) ... end }
```

如果版本较旧，会回退到 `vim.diagnostic.goto_next()`，不会弹浮窗。升级 Neovim 即可。

### 诊断消息太长

`format` 会把多行压成一行并附带规则名。想改回默认，删除 `lua/plugins/lsp.lua` 里的 `format` 字段。

---

## 6. Python 与 venv

### venv-selector 打不开

```vim
:VenvSelect
:VenvSelectLog
```

检查：

1. 当前是 Python 文件；
2. `fd` 已安装；
3. `~/.cache/venv-selector/venvs2.json` 是否可写；
4. 搜索命令里的路径是否存在。

### 搜索不到虚拟环境

默认在家目录下搜索，深度 6。可以指定根目录：

```bash
export CROW_VENV_ROOT="$HOME/venvs"
```

或修改 `lua/plugins/venv-selector.lua` 的 `projects.command`。

### 选择后 statusline 不显示

```vim
:lua print(vim.inspect(require("venv-selector").venv()))
```

- 有值但状态栏不显示：检查 `lua/plugins/lualine.lua` 的 `venv_status`；
- 无值：选择没有成功，看 `:VenvSelectLog`。

### 取消选择后 pyright 又用回 `.venv`

配置里通过 `vim.b.venv_selector_disabled` 阻止自动回退。确认：

```vim
:lua =vim.b.venv_selector_disabled
```

取消选择时应为 `true`。

---

## 7. 格式化

### 保存不格式化

1. 检查全局开关：

```vim
:lua =vim.g.autoformat
:lua =vim.b.autoformat
```

2. 检查当前 buffer 是否有格式化器：

```vim
:lua =require("conform").list_formatters(0)
```

3. 手动执行：

```vim
:lua require("conform").format({ async = true })
```

4. `:Doctor` 的「conform 格式化」一节会列出可用格式化器。

### 格式化器和 LSP / vim-go 重复执行

配置已经关闭：

```lua
g.go_fmt_autosave = 0
g.go_imports_autosave = 0
```

如果你新装了带保存格式化的插件，也要关闭它的自动格式化。

### prettier / eslint 不工作

它们来自 LazyVim extras，需要：

```bash
npm install -g prettier eslint
```

项目里有 `node_modules` 时优先用项目版本。

---

## 8. 搜索与文件树

### `<leader>p` 没反应

```vim
:lua =require("snacks").picker.files()
```

如果报错，检查 snacks 是否加载：

```vim
:Lazy
```

### 搜索很慢

- 确认 `rg` 已安装；
- 大仓库可以在项目根加 `.ignore` / `.rgignore`；
- `snacks.picker` 默认尊重 `.gitignore`。

### 文件树不显示隐藏文件

`lua/plugins/snacks.lua` 的 `picker.sources.explorer` 有隐藏文件配置。按需调整。

### `fd` 找不到

Debian/Ubuntu 的可执行文件叫 `fdfind`：

```bash
sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
```

---

## 9. Treesitter

### 解析器安装失败

```vim
:TSInstall python
:checkhealth treesitter
```

常见原因：

- 没有 C 编译器（`gcc` / `clang`）；
- 没有 `tree-sitter` CLI（部分版本需要）；
- 网络问题。

Arch：

```bash
sudo pacman -S --needed base-devel tree-sitter-cli
```

### 高亮异常 / 报错

```vim
:TSUpdate
```

大文件会自动关闭 Treesitter 高亮和缩进（>1 MB），这是预期行为。

### Markdown 注入语言不工作

确认对应语言的解析器已安装，例如：

```vim
:TSInstall markdown markdown_inline
```

---

## 10. 剪贴板与字体

### `clipboard: No provider`

安装：

```bash
# Wayland
sudo pacman -S wl-clipboard

# X11
sudo pacman -S xclip
```

检查：

```vim
:checkhealth provider
:echo has("clipboard")
```

配置里 `clipboard = "unnamedplus"`，并在 `VeryLazy` 后再次写回。

### 图标显示成方块

- 终端没有使用 Nerd Font；
- Neovide 字体不存在。

检查：

```bash
fc-list | grep -i "Maple"
```

没有就安装字体，或改 `lua/config/neovide.lua`：

```lua
vim.o.guifont = "你的 Nerd Font:h14"
```

### 透明背景不生效

透明由终端负责，不是 Neovim：

- kitty：`background_opacity`
- Ghostty：`background-opacity`
- Alacritty：`window.opacity`

Neovim 只把背景设为 `NONE`。

---

## 11. AI 与 Ollama

### `:CrowAiStats` 连接失败

```bash
ollama serve
systemctl --user status ollama
curl http://127.0.0.1:11434/api/tags
```

### 模型不存在

```bash
ollama list
ollama pull qwen2.5-coder:1.5b
ollama pull qwen2.5-coder:3b
```

### 补全不出现

- 是否在代码类 filetype；
- 是否在插入模式；
- 是否刚停止输入 400ms；
- `:messages` 是否有 minuet 报错；
- Ollama 是否在线。

### 翻译不出现

- 文本已是中文；
- 文本几乎是纯代码；
- 超过 8000 字符；
- Ollama 离线。

### 回答很慢 / 卡住

```vim
:CrowAiStop
```

然后：

```bash
ollama ps
```

降低 `num_ctx` / `num_predict`，或换 1.5B。

### `Bearer nil` 崩溃

minuet 的 `api_key` 必须返回字符串。配置里已经写成函数：

```lua
api_key = function()
  return "ollama"
end
```

不要改成环境变量，Neovide 从桌面启动时环境变量可能为空。

---

## 12. Git 与插件更新

### `:Lazy update` 后配置坏了

```vim
:Lazy restore
```

恢复到 `lazy-lock.json` 的版本。

### 插件锁定文件冲突

```bash
git diff lazy-lock.json
```

只保留你确认过的变更。不要随便删除锁文件。

### 代理 / 网络问题

GitHub 直连不稳定时，自行配置：

```bash
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
```

或用镜像 / SSH。仓库本身不绑定代理。

### `lazy.nvim` bootstrap 失败

```bash
git clone --filter=blob:none --branch=stable \
  https://github.com/folke/lazy.nvim.git \
  ~/.local/share/nvim/lazy/lazy.nvim
```

然后重新启动 Neovim。

---

## 13. 性能问题

### 启动慢

```vim
:Lazy profile
```

常见原因：

- 某个插件没有延迟加载；
- Treesitter 解析器过多；
- 大文件触发高亮；
- 更新检查器（已关闭）。

配置的启动统计会在 `VimEnter` 后显示：

```text
⚡ Neovim 123.45ms / 45/70 插件
```

### 编辑大文件卡顿

超过 1 MB 会自动降级：

- 关闭 swap；
- 关闭 undo；
- 关闭 Treesitter 高亮 / 缩进；
- 关闭 list。

仍卡时可以：

```vim
:set nosyntax
:set nospell
```

或改用 `nvim --clean` 查看是不是插件问题。

### 补全卡顿

- minuet 的 `debounce` / `throttle` 调大；
- 关闭 Copilot 行内补全；
- 减少 blink 的补全来源。

---

## 14. 日志与反馈

### 日志位置

| 内容 | 位置 / 命令 |
|---|---|
| Neovim 消息 | `:messages` |
| lazy.nvim | `:Lazy log` |
| 插件加载 | `~/.local/state/nvim/lazy/` |
| venv-selector | `:VenvSelectLog` |
| Treesitter | `:checkhealth treesitter` |
| LSP | `~/.local/state/nvim/lsp.log` |
| 启动耗时 | `:Lazy profile` |

### 反馈问题时请附上

1. `nvim --version` 第一行；
2. 操作系统；
3. `:Doctor` 输出（隐藏个人信息后）；
4. 完整报错和堆栈；
5. 最小复现步骤；
6. 是否 `nvim --clean` 也复现。

### 不要提交的内容

- 个人 Token、API Key；
- 公司内网地址、私有仓库地址；
- 带用户名的绝对路径；
- 真实项目代码片段。

本仓库的文档和配置已经移除了个人路径、代理地址和账号信息。提交前请再检查一遍。
