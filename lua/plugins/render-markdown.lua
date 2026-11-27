-- ═══════════════════════════════════════════════════════════
-- render-markdown.nvim —— 在 buffer 内渲染 Markdown
-- ═══════════════════════════════════════════════════════════
-- 与 markdown-preview.nvim 互补：
--   · markdown-preview：在浏览器打开，适合最终预览；
--   · render-markdown：在编辑器里直接渲染标题、列表、代码块、表格。
--
-- 只在 Markdown 类文件里加载，不影响普通代码文件。

return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown", "markdown.mdx", "rmd", "quarto" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    render_modes = { "n", "c", "t" },
    heading = {
      sign = false,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
    },
    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },
    bullet = {
      icons = { "●", "○", "◆", "◇" },
    },
    checkbox = {
      enabled = true,
    },
    pipe_table = {
      preset = "round",
    },
  },
}
