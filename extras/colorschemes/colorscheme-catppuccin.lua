-- ═══════════════════════════════════════════════════════════
-- catppuccin.nvim —— Easy-Vim 主题
-- ═══════════════════════════════════════════════════════════
-- 与 Vim 版一致：Catppuccin Mocha + 透明背景。
-- 透明部分由终端（Ghostty/kitty 的 background-opacity）负责，
-- Neovim 这里把 Normal / SignColumn 等的背景清成 NONE。
-- 语义色板增强在 lua/crow/theme.lua 里，ColorScheme 后自动套用。

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,

    opts = {
      flavour = "mocha",
      transparent_background = true,

      styles = {
        comments = { "italic" },
        conditionals = { "bold" },
        keywords = { "bold" },
        functions = {},
        variables = {},
        strings = {},
        numbers = {},
        booleans = { "bold" },
        properties = {},
        types = { "bold" },
        operators = {},
      },

      integrations = {
        blink_cmp = true,
        blink_indent = true,
        blink_pairs = true,
        cmp = true,
        dap = true,
        dap_ui = true,
        flash = true,
        fzf = true,
        gitsigns = true,
        grug_far = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true, scope_color = "surface0" },
        lsp_trouble = true,
        mason = true,
        mini = { enabled = true, indentscope_color = "" },
        neotree = true,
        noice = true,
        notify = true,
        nvim_surround = true,
        rainbow_delimiters = true,
        render_markdown = true,
        snacks = true,
        telescope = { enabled = true },
        treesitter_context = true,
        which_key = true,
      },

      custom_highlights = function(colors)
        return {
          LineNrAbove = { fg = colors.overlay0 },
          LineNrBelow = { fg = colors.overlay0 },
          CursorLineNr = { fg = colors.yellow, bold = true },
          CursorLine = { bg = colors.surface0 },
        }
      end,
    },
  },

  -- 让 LazyVim 实际加载这个主题
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-mocha" },
  },
}
