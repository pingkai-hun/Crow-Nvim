-- ═══════════════════════════════════════════════════════════
-- Easy-Vim 额外插件（Vim 版专用插件的 Neovim 对应物）
-- ═══════════════════════════════════════════════════════════
--   luochen1990/rainbow          → rainbow-delimiters.nvim
--   junegunn/vim-easy-align      → vim-easy-align（ga）
--   mattn/emmet-vim              → emmet-vim
--   rust-lang/rust.vim           → rust.vim（格式化交给 conform）
--
-- 注释 / surround / 自动括号 / 缩进线等已由 LazyVim 自带的
-- ts-comments、nvim-surround、mini.pairs、indent-blankline 覆盖，不重复安装。

return {
  -- ─── 括号彩虹 ───────────────────────────────────────────
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      local rainbow = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow.strategy["global"],
          vim = rainbow.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        priority = {
          [""] = 110,
          lua = 210,
        },
        highlight = {
          "RainbowDelimiterBlue",
          "RainbowDelimiterPurple",
          "RainbowDelimiterCyan",
          "RainbowDelimiterYellow",
          "RainbowDelimiterRed",
        },
      }

      -- 用 Easy-Vim 的五色板覆盖默认颜色，并跟随主题
      local function apply()
        local pal = require("crow.palette").get()
        local groups = {
          { "RainbowDelimiterBlue", pal.blue },
          { "RainbowDelimiterPurple", pal.purple },
          { "RainbowDelimiterCyan", pal.aqua },
          { "RainbowDelimiterYellow", pal.yellow },
          { "RainbowDelimiterRed", pal.red },
          { "RainbowDelimiterOrange", pal.orange },
          { "RainbowDelimiterGreen", pal.green },
          { "RainbowDelimiterViolet", pal.purple },
        }
        for _, item in ipairs(groups) do
          pcall(vim.api.nvim_set_hl, 0, item[1], { fg = item[2] })
        end
      end
      apply()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("EasyRainbow", { clear = true }),
        callback = apply,
      })
    end,
  },

  -- ─── 对齐：ga / gaip= 等 ─────────────────────────────────
  {
    "junegunn/vim-easy-align",
    keys = {
      { "ga", "<Plug>(EasyAlign)", mode = { "n", "x" }, desc = "对齐 (EasyAlign)" },
    },
    config = function()
      -- 不需要额外设置；安装后 <Plug>(EasyAlign) 即可使用
    end,
  },

  -- ─── HTML / CSS 缩写展开 ────────────────────────────────
  {
    "mattn/emmet-vim",
    ft = { "html", "css", "scss", "javascriptreact", "typescriptreact", "vue", "svelte" },
    init = function()
      -- 与 Vim 版一致：默认 <C-y>, 展开，全局安装映射
      vim.g.user_emmet_mode = "a" -- 普通/插入/可视模式都可用
    end,
    config = function()
      -- 只在需要的文件类型里启用
      vim.g.user_emmet_settings = {
        variables = { lang = "zh-CN" },
        html = {
          options = { indent = "  " },
        },
      }
    end,
  },

  -- ─── Rust 语法 / ftplugin ───────────────────────────────
  {
    "rust-lang/rust.vim",
    ft = "rust",
    init = function()
      -- 保存格式化统一交给 conform.nvim
      vim.g.rustfmt_autosave = 0
      vim.g.rust_clip_command = "wl-copy"
    end,
  },
}
