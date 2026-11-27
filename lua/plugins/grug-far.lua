-- ═══════════════════════════════════════════════════════════
-- grug-far.nvim —— 项目级搜索 / 替换
-- ═══════════════════════════════════════════════════════════
-- LazyVim 默认已经安装 grug-far，但默认的 <leader>sr 在本配置里被
-- 「重新加载配置」占用，所以这里补一个不冲突的入口：
--   <leader>sR  全局搜索替换（普通/可视模式）
--
-- 打开后可以只替换当前文件，也可以在预览里逐条确认；
-- 支持 regex、文件过滤、大小写等选项。

return {
  "MagicDuck/grug-far.nvim",
  keys = {
    {
      "<leader>sR",
      function()
        local ext = vim.bo.buftype == "" and vim.fn.expand("%:e") or nil
        require("grug-far").open({
          transient = true,
          prefills = {
            filesFilter = ext and ext ~= "" and "*." .. ext or nil,
          },
        })
      end,
      mode = { "n", "x" },
      desc = "全局搜索替换 (grug-far)",
    },
    {
      "<leader>sW",
      function()
        require("grug-far").open({
          transient = true,
          prefills = { search = vim.fn.expand("<cword>") },
        })
      end,
      mode = { "n", "x" },
      desc = "替换光标下的单词",
    },
  },
  opts = { headerMaxWidth = 80 },
}
