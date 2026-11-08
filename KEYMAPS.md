# Neovim 快捷键说明

> 适用版本：**CrowNvim Beta0.1.2**
> 适用配置：`~/.config/nvim`
> `leader` = **空格**，`localleader` = `\`
> 不确定按键时按 `<leader>` 等 1 秒，或按 `<leader>?` 查看当前 buffer 的键位。

---

## 目录

- [基础操作](#基础操作)
- [文件 / 搜索](#文件--搜索)
- [Buffer 管理](#buffer-管理)
- [窗口与移动](#窗口与移动)
- [编辑增强](#编辑增强)
- [LSP 与诊断](#lsp-与诊断)
- [格式化与代码动作](#格式化与代码动作)
- [Git](#git)
- [调试](#调试)
- [终端与运行](#终端与运行)
- [Python 专用](#python-专用)
- [Go 专用](#go-专用)
- [TypeScript 专用](#typescript-专用)
- [HTTP / REST 文件](#http--rest-文件)
- [Markdown](#markdown)
- [AI](#ai)
- [通知](#通知)
- [UI 开关](#ui-开关)
- [会话](#会话)
- [Neovide（仅 GUI）](#neovide仅-gui)
- [常用命令](#常用命令)

---

## 基础操作

| 快捷键 | 功能 |
|---|---|
| `<leader>w` | 保存 |
| `<leader>wq` | 保存并退出 |
| `<leader>q` | 退出 |
| `<C-s>` | 保存（插入 / 普通 / 可视模式都可用） |
| `<leader>h` | 清除搜索高亮 |
| `<leader>ur` | 重绘屏幕 + 清搜索高亮 + 更新 diff |
| `<leader>cd` | 把当前目录（cwd）切换到当前文件所在目录 |
| `<leader>sr` | 重新加载 Neovim 配置 |
| `<leader>sc` | 打开 `init.lua` |
| `<leader>sC` | 打开 Lazy 插件管理 |
| `<leader>D` | `:Doctor` 环境体检 |
| `<leader>?` | 查看当前 buffer 的快捷键 |
| `q` | 关闭临时浮窗（通知、AI 窗口等） |

> 注意：`<leader>cd` 在本配置里是「切换 cwd」，不是 LazyVim 默认的「当前行诊断」。当前行诊断用 `gl`。

---

## 文件 / 搜索

| 快捷键 | 功能 |
|---|---|
| `<leader>n` | 文件树（Snacks Explorer） |
| `<leader>nf` | 在**当前文件所在目录**查找文件 |
| `<leader>p` | 查找文件 |
| `<leader>P` | 在**项目根目录**查找文件 |
| `<leader>/` | 全局搜索（grep） |
| `<leader>R` | 在**项目根目录**全局搜索 |
| `<leader>*` | 搜索光标下的单词 |
| `<leader>b` | 切换 buffer |
| `<leader>y` | 打开剪贴板 / yank 历史 |
| `<leader>N` | 通知历史 |

### Harpoon（常用文件书签）

| 快捷键 | 功能 |
|---|---|
| `<leader>ha` | 把当前文件加入 Harpoon 列表 |
| `<leader>hh` | 打开 Harpoon 快速菜单 |
| `<leader>h1` ~ `<leader>h4` | 直接跳到第 1~4 个书签文件 |
| `<leader>hp` | 上一个书签文件 |
| `<leader>hn` | 下一个书签文件 |

Harpoon 列表按项目（cwd）独立保存。

---

## Buffer 管理

| 快捷键 | 功能 |
|---|---|
| `<leader>b` | Buffer 选择器 |
| `<leader>bd` | 关闭当前 buffer |
| `<leader>bo` | 关闭其它 buffer |
| `<leader>bi` | 关闭不可见 buffer |
| `<leader>bD` | 关闭 buffer 和窗口 |

---

## 窗口与移动

| 快捷键 | 功能 |
|---|---|
| `<C-h>` | 移到左窗口 |
| `<C-j>` | 移到下窗口 |
| `<C-k>` | 移到上窗口 |
| `<C-l>` | 移到右窗口 |
| `<A-j>` | 下移当前行 / 选中行 |
| `<A-k>` | 上移当前行 / 选中行 |

### 快速跳转（Flash）

| 快捷键 | 功能 |
|---|---|
| `s` | 跳到屏幕上任意位置 |
| `S` | 跳到 Treesitter 语法节点 |
| `r` | 远程操作（对远处目标执行操作符） |
| `R` | 在整个 buffer 中做 Treesitter 搜索 |
| `f` / `F` / `t` / `T` | 行内跳转，并显示可跳转标签 |
| `/` / `?` | 搜索时显示 Flash 标签 |

### 智能单词移动（nvim-spider）

| 快捷键 | 功能 |
|---|---|
| `w` / `e` / `b` | 更符合代码语义的单词移动（会跳过标点、识别 camelCase / snake_case） |

---

## 编辑增强

### 注释

| 快捷键 | 功能 |
|---|---|
| `<leader>c` | 注释当前行（普通模式） |
| `<leader>c` | 注释选中行（可视模式） |
| `gcc` | 注释当前行 |
| `gc` + 动作 | 注释指定范围 |

### 环绕 / 括号（nvim-surround）

| 快捷键 | 功能 |
|---|---|
| `ys{motion}{char}` | 添加环绕，例如 `ysiw"` → `"word"` |
| `yss{char}` | 环绕整行，例如 `yss)` → `(整行)` |
| `cs{old}{new}` | 修改环绕，例如 `cs"'` |
| `ds{char}` | 删除环绕，例如 `ds"` |
| `S{char}` | 可视模式下环绕选区 |
| `a` / `b` / `B` / `r` / `q` | 快捷别名：`>` / `)` / `}` / `]` / 任意引号 |

### 对齐

| 快捷键 | 功能 |
|---|---|
| `ga` | EasyAlign 对齐（普通 / 可视模式） |

### 多光标

| 快捷键 | 功能 |
|---|---|
| `<A-J>` | 在下方添加光标 |
| `<A-K>` | 在上方添加光标 |

### 粘贴增强（Yanky）

| 快捷键 | 功能 |
|---|---|
| `p` / `P` | 粘贴，并保留 yank 历史 |
| `gp` / `gP` | 粘贴后光标停在粘贴内容之后 |
| `<C-p>` / `<C-n>` | 粘贴后向前 / 向后切换历史条目 |
| `]p` / `[p` | 按缩进粘贴到下方 / 上方 |
| `>p` / `<p` | 粘贴并向右 / 向左缩进 |

### 自动括号

| 快捷键 | 功能 |
|---|---|
| `<leader>up` | 临时开关自动括号（mini.pairs） |

---

## LSP 与诊断

| 快捷键 | 功能 |
|---|---|
| `gd` | 跳转定义 |
| `gD` | 跳转声明 |
| `gy` | 跳转类型定义 |
| `gi` | 跳转实现 |
| `gr` | 查找引用 |
| `K` | 悬浮文档 |
| `gK` | 签名帮助 |
| `gl` | 当前行诊断详情 |
| `[d` / `]d` | 上一个 / 下一个诊断（自动弹出消息） |
| `[e` / `]e` | 上一个 / 下一个错误 |
| `[w` / `]w` | 上一个 / 下一个警告 |
| `[q` / `]q` | 上一个 / 下一个 quickfix |
| `[t` / `]t` | 上一个 / 下一个 TODO |
| `<leader>rn` | 重命名符号 |
| `<leader>ac` | 代码动作 |
| `<leader>ca` | 代码动作（LazyVim 默认） |
| `<leader>cr` | 重命名符号（LazyVim 默认） |

### Trouble / 诊断面板

| 快捷键 | 功能 |
|---|---|
| `<leader>xx` | 项目全部诊断 |
| `<leader>xX` | 当前 buffer 诊断 |
| `<leader>xL` | Location List |
| `<leader>xQ` | Quickfix List |
| `<leader>xt` | TODO 列表 |
| `<leader>xT` | TODO / FIX / FIXME 列表 |
| `<leader>st` | TODO（Telescope） |
| `<leader>fT` | TODO / FIX / FIXME（Telescope） |
| `<leader>wa` | 代码大纲（Trouble symbols） |
| `<leader>wt` | 文档符号列表（Snacks） |

---

## 格式化与代码动作

| 快捷键 | 功能 |
|---|---|
| `<leader>cf` | 格式化当前文件（LazyVim / conform） |
| `<leader>uf` | 开关「保存时自动格式化」 |
| `<leader>uF` | 开关「当前 buffer 保存时格式化」 |

---

## Git

| 快捷键 | 功能 |
|---|---|
| `<leader>gn` | Neogit 状态面板 |
| `<leader>gnc` | 提交 |
| `<leader>gnp` | Push |
| `<leader>gnP` | Pull |
| `<leader>gnb` | 分支 |
| `<leader>gnl` | 日志 |
| `<leader>gd` | Diffview：与 HEAD 比较 |
| `<leader>gD` | 关闭 Diffview |
| `<leader>gv` | 当前文件历史 |
| `<leader>gV` | 仓库历史 |
| `<leader>gg` | Lazygit（项目根目录，需已安装 lazygit） |
| `<leader>gG` | Lazygit（当前目录） |
| `<leader>gb` | 当前行 Git blame |
| `<leader>gl` | Git log |
| `<leader>gf` | 当前文件 Git 历史 |
| `<leader>gB` | 在浏览器打开当前行 / 选区 |
| `<leader>gY` | 复制当前行 / 选区的远程 URL |

> Go buffer 中 `<leader>g*` 会被 Go 专用键位覆盖，见下方 Go 章节。

---

## 调试

| 快捷键 | 功能 |
|---|---|
| `<F5>` | 启动 / 继续 |
| `<F9>` | 切换断点 |
| `<F10>` | 单步跳过 |
| `<F11>` | 单步进入 |
| `<F12>` | 单步跳出 |
| `<leader>dr` | 重启调试 |
| `<leader>dq` | 停止调试 |
| `<leader>dR` | 打开 / 关闭调试 REPL |

---

## 终端与运行

| 快捷键 | 功能 |
|---|---|
| `<F7>` | 打开 / 关闭浮动终端（终端模式也可用） |
| `<F8>` | 代码大纲（Trouble symbols） |
| `<leader>tt` | 浮动终端 |
| `<F6>` | 保存并运行当前 Python 脚本 |
| `<leader>py` | 打开 Python 交互环境 |

---

## Python 专用

| 快捷键 | 功能 |
|---|---|
| `<leader>cv` | 选择 Python 虚拟环境（venv-selector） |
| `<leader>cV` | 取消当前虚拟环境 |
| `<leader>cvr` | 用当前环境重启 Python LSP |
| `<leader>ip` | 插入 IP 解析模板 |
| `<leader>req` | 插入 HTTP 探测模板 |
| `<leader>port` | 插入端口扫描模板 |
| `<F6>` | 保存并运行当前脚本 |
| `<leader>py` | 打开 Python REPL |

说明：

- venv 选择后会自动设置 `VIRTUAL_ENV`、更新 PATH，并重启 pyright。
- 每个项目会记住上次选择的环境，下次打开自动恢复。
- 状态栏显示 `🐍 环境名`。
- 查看 venv-selector 日志：`:VenvSelectLog`
- 查看环境/诊断摘要：`:Doctor`

Python 模板只在 `.py` buffer 中生效。

---

## Go 专用

仅在 Go buffer 中生效：

| 快捷键 | 功能 |
|---|---|
| `<leader>gb` | GoBuild |
| `<leader>gr` | GoRun |
| `<leader>gt` | GoTest |
| `<leader>gT` | GoTestFunc |
| `<leader>gc` | 覆盖率开关 |
| `<leader>gv` | GoVet |
| `<leader>gl` | GoMetaLinter |
| `<leader>ga` | 添加 struct tags |
| `<leader>gA` | 删除 struct tags |
| `<leader>gD` | Go 调试：启动 / 继续 |
| `<leader>gX` | Go 调试：停止 |

---

## TypeScript 专用

| 快捷键 | 功能 |
|---|---|
| `<leader>ci` | 整理 imports |
| `<leader>cu` | 删除未使用的 imports |
| `<leader>cI` | 补全缺失的 imports |
| `<leader>cR` | 重命名文件并更新 imports |
| `<leader>cF` | 修复所有可自动修复的问题 |

---

## HTTP / REST 文件

仅在 `.http` 文件中生效：

| 快捷键 | 功能 |
|---|---|
| `<leader>rr` | 运行光标下的请求 |
| `<leader>ra` | 运行文件里所有请求 |
| `<leader>rb` | 切换 body / headers 视图 |
| `<leader>rc` | 复制请求为 curl 命令 |
| `]r` / `[r` | 下一个 / 上一个请求 |

---

## Markdown

| 快捷键 | 功能 |
|---|---|
| `<leader>cp` | 打开 / 关闭 Markdown 预览 |

---

## AI

### 本机 Ollama / CodeCompanion

| 快捷键 | 功能 |
|---|---|
| `<leader>oa` | AI 解释当前函数 / 选区 |
| `<leader>or` | AI 审查代码 / 选区 |
| `<leader>oq` | 带上下文向 AI 提问 |
| `<leader>oi` | AI 状态 |
| `<leader>oc` | 打开 / 关闭 AI 对话 |
| `<leader>ov` | AI 动作面板 |
| `<leader>oe` | AI 改写选区 |

### Copilot Chat

| 快捷键 | 功能 |
|---|---|
| `<leader>aa` | 打开 / 关闭 Copilot Chat |
| `<leader>ax` | 清空当前对话 |
| `<leader>aq` | 快速提问 |
| `<leader>ap` | 选择预设 Prompt |
| `<C-s>` | 在 Copilot Chat 窗口中提交（等同回车） |

---

## 通知

| 快捷键 | 功能 |
|---|---|
| `<leader>nn` | 通知历史（Noice） |
| `<leader>nd` | 关闭当前通知 |
| `<leader>nh` | 通知历史（Telescope） |
| `<leader>nc` | 清除所有通知 |
| `<leader>N` | 通知历史（Snacks） |
| `q` / `<Esc>` | 在通知浮窗内关闭 |

---

## UI 开关

| 快捷键 | 功能 |
|---|---|
| `<leader>ud` | 开关诊断显示 |
| `<leader>uh` | 开关 LSP inlay hints |
| `<leader>us` | 开关拼写检查 |
| `<leader>uw` | 开关自动换行 |
| `<leader>uL` | 开关相对行号 |
| `<leader>ul` | 开关行号 |
| `<leader>uc` | 开关 conceal |
| `<leader>uA` | 开关 tabline |
| `<leader>uT` | 开关 Treesitter |
| `<leader>ub` | 切换明 / 暗背景 |
| `<leader>uD` | 开关 dim 模式 |
| `<leader>ua` | 开关动画 |
| `<leader>ug` | 开关缩进线 |
| `<leader>uS` | 开关 smooth scroll |
| `<leader>up` | 开关自动括号 |
| `<leader>uf` | 开关保存自动格式化 |
| `<leader>uF` | 开关当前 buffer 保存自动格式化 |
| `<leader>ur` | 重绘 / 清高亮 / 更新 diff |

---

## 会话

| 快捷键 | 功能 |
|---|---|
| `<leader>os` | 开启会话自动保存 |
| `<leader>od` | 停止并删除会话 |
| `<leader>oS` | 手动保存会话 |
| `<leader>oN` | 载入会话 |

---

## Neovide（仅 GUI）

> 终端里的 nvim 不会注册这些键位。

| 快捷键 | 功能 |
|---|---|
| `<C-=>` / `<C-+>` | 放大界面 |
| `<C-->` | 缩小界面 |
| `<C-0>` | 缩放复位 |
| `<F11>` | 全屏切换 |

缩放值会持久化到 `stdpath("state")/neovide/scale`，重启后保留。

---

## 常用命令

| 命令 | 功能 |
|---|---|
| `:Doctor` | 环境体检：LSP、工具、主题、诊断、Python 解释器 |
| `:VenvSelect` | 选择 Python 虚拟环境 |
| `:VenvSelectLog` | 查看 venv-selector 日志 |
| `:Lazy` | 插件管理 |
| `:Lazy update` | 更新全部插件 |
| `:Lazy update 插件名` | 更新单个插件 |
| `:Lazy clean` | 清理未使用的插件 |
| `:Lazy sync` | 安装缺失 + 更新 + 清理 |
| `:checkhealth` | 检查 Neovim / 插件健康状态 |
| `:checkhealth noice` | 检查通知系统 |
| `:checkhealth venv-selector` | 检查 Python 环境选择器 |
| `:Mason` | 管理 LSP / 格式化工具 |
| `:Trouble` | 诊断 / 符号 / quickfix 面板 |
| `:Neogit` | Git 状态面板 |
| `:DiffviewOpen` | 打开 diff 视图 |
| `:nohlsearch` | 清除搜索高亮 |

---

## 前缀分组速查

| 前缀 | 分组 |
|---|---|
| `<leader>a` | AI（Copilot Chat） |
| `<leader>b` | Buffer |
| `<leader>c` | Code / 代码动作 |
| `<leader>d` | Debug |
| `<leader>f` | Find |
| `<leader>g` | Git（Go buffer 中部分为 Go） |
| `<leader>h` | Harpoon / 清高亮 |
| `<leader>n` | 文件树 / 通知 |
| `<leader>o` | Ollama AI / 会话 |
| `<leader>p` | 文件查找 |
| `<leader>q` | 退出 |
| `<leader>r` | REST（仅 .http） |
| `<leader>s` | Search / 配置 |
| `<leader>u` | UI 开关 |
| `<leader>x` | 诊断 / Trouble |
| `g` | Goto |
| `[` / `]` | 上一个 / 下一个 |
