# extras/ —— 未启用的可选配置

这个目录**不在 Neovim 的 runtimepath 里**，其中的文件不会被加载，只是备选方案的存档。

## 为什么放在这里

lazy.nvim 的插件导入（`import = "plugins"`）**只扫描一层**：

```
lua/plugins/*.lua        → 会被加载
lua/plugins/<目录>/       → 只有该目录存在 init.lua 时才会被加载
```

所以以前放在 `lua/plugins/colorscheme/` 下的 7 个文件**从未被加载过**——
它们既不安装插件，也不修改任何设置。为了避免"看起来生效、实际没生效"，
统一挪到了这里。

配色实际的来源是：

| 来源 | 位置 |
|---|---|
| Catppuccin / TokyoNight 插件本体 | LazyVim 自带（`lazyvim/plugins/colorscheme.lua`） |
| 默认使用哪套配色 | `lua/config/lazy.lua` 里的 `opts = { colorscheme = "catppuccin-mocha" }` |
| 透明背景、斜体注释、语义色板 | `lua/crow/theme.lua` + `lua/crow/palette.lua` |

## colorschemes/

| 文件 | 配色 |
|---|---|
| `colorscheme-catppuccin.lua` | Catppuccin（当前默认，但本仓库的主配置在 `crow/theme.lua`） |
| `colorscheme-tokyonight.lua` | TokyoNight |
| `colorscheme-dracula.lua` | Dracula |
| `colorscheme-nightfox.lua` | Nightfox |
| `colorscheme-one-dark-theme-1.lua` | OneDark（navarasu） |
| `colorscheme-one-dark-theme-2.lua` | OneDark（joshdick） |
| `colorscheme-palenightfall.lua` | Palenightfall |

## 怎么启用其中一套

1. 把对应文件复制回 `lua/plugins/` 根目录：

   ```bash
   cp extras/colorschemes/colorscheme-dracula.lua lua/plugins/
   ```

2. 重启 Neovim，让 lazy.nvim 安装插件：

   ```vim
   :Lazy sync
   ```

3. 确认生效：

   ```vim
   :echo g:colors_name
   ```

> 注意：多套配色文件同时放进 `lua/plugins/` 时，它们都会设置
> `LazyVim.opts.colorscheme`，最终以加载顺序靠后的为准（按文件名排序）。
> 想稳定用某一套，请在 `lua/config/lazy.lua` 的 spec 末尾显式写一行
> `{ "LazyVim/LazyVim", opts = { colorscheme = "dracula" } }`。

## 配色切换（已启用的范围内）

Catppuccin 的四个 flavor 可以在运行时直接切：

```vim
:CrowTheme mocha
:CrowTheme macchiato
:CrowTheme frappe
:CrowTheme latte
```

其它已注册的配色：

```vim
:Theme tokyonight
:Theme gruvbox-material
```
