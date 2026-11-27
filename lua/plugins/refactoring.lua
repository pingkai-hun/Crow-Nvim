-- ═══════════════════════════════════════════════════════════
-- refactoring.nvim —— 结构化重构
-- ═══════════════════════════════════════════════════════════
-- 依赖 LSP / Treesitter，提供比「重命名」更进一步的代码操作：
--   · 抽取函数 / 变量 / 代码块
--   · 内联变量
--   · 提取到新文件
--
-- 只在代码类文件里按需加载，不拖慢启动。
--
-- 常用键位（<leader>cx 前缀，x = extract；避开 LazyVim 的
-- <leader>cr 重命名 与 <leader>cR 重命名文件，否则重命名会等待 timeoutlen）：
--   <leader>cxf  抽取函数（可视模式）
--   <leader>cxv  抽取变量
--   <leader>cxi  内联变量
--   <leader>cxb  抽取代码块（可视模式）

return {
  "ThePrimeagen/refactoring.nvim",
  ft = {
    "python",
    "lua",
    "go",
    "rust",
    "typescript",
    "typescriptreact",
    "javascript",
    "javascriptreact",
    "c",
    "cpp",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "lewis6991/async.nvim", -- 0.12 下 refactoring 需要 async 模块
  },
  keys = {
    {
      "<leader>cxf",
      "<cmd>RefactorExtractFunction<cr>",
      mode = { "n", "x" },
      desc = "重构：抽取函数",
    },
    {
      "<leader>cxv",
      "<cmd>RefactorExtractVariable<cr>",
      mode = { "n", "x" },
      desc = "重构：抽取变量",
    },
    {
      "<leader>cxi",
      "<cmd>RefactorInlineVar<cr>",
      mode = { "n", "x" },
      desc = "重构：内联变量",
    },
    {
      "<leader>cxb",
      "<cmd>RefactorExtractBlock<cr>",
      mode = { "n", "x" },
      desc = "重构：抽取代码块",
    },
  },
  opts = {},
}
