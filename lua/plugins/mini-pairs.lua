-- ═══════════════════════════════════════════════════════════
-- PLUGINS - mini.pairs (Auto Pairs)
-- ═══════════════════════════════════════════════════════════
--
-- Automatically inserts closing pairs for brackets, quotes, and other
-- paired characters. Includes smart skipping logic to avoid redundant
-- pair insertion in common edge cases.

return {
  "nvim-mini/mini.pairs",

  -- Load after the UI is ready; auto-pairing is not needed during startup.
  event = "VeryLazy",

  opts = {
    -- ─── Active Modes ──────────────────────────────────────────
    -- Controls which Vim modes auto-pairing is active in.
    -- Terminal mode is disabled to avoid interfering with terminal input.
    modes = { insert = true, command = true, terminal = false },

    -- ─── Skip Next Character ───────────────────────────────────
    -- Suppresses auto-pairing when the character immediately to the right
    -- of the cursor matches this pattern. Prevents double-closing when the
    -- next character is already a word, quote, bracket, or similar symbol.
    skip_next = [=[[%w%%%'%[%"%.%`%$]]=],

    -- ─── Skip Treesitter Nodes ─────────────────────────────────
    -- Suppresses auto-pairing when the cursor is inside a Treesitter "string"
    -- node, avoiding unwanted pair insertion inside existing string literals.
    skip_ts = { "string" },

    -- ─── Skip Unbalanced Pairs ─────────────────────────────────
    -- When the next character is a closing pair and there are already more
    -- closing pairs than opening pairs in the buffer, skip auto-insertion.
    -- This prevents runaway closing brackets in already-balanced code.
    skip_unbalanced = true,

    -- ─── Markdown Support ──────────────────────────────────────
    -- Enables special handling for Markdown code blocks (``` pairs),
    -- ensuring auto-pairing behaves correctly inside and around fenced blocks.
    markdown = true,
  },

  -- ─── 不要在这里定义 config ─────────────────────────────────
  -- lazy.nvim 用原型链合并同一插件的多个 spec：本文件一旦写 config，
  -- 就会遮蔽 LazyVim 自带的 config（meta.lua 的 setmetatable 原型链）。
  -- LazyVim 的 config 里除了 mini.pairs.setup(opts) 还做了：
  --   1. 注册 <leader>up 开关（临时关闭自动括号）
  --   2. 包装 pairs.open：markdown 围栏内 ``` 换行、skip_next / skip_ts 判断
  -- 上面的 opts 会被 lazy.nvim 深度合并后传给 LazyVim 的 config，
  -- 所以这里只需给出 opts，功能一个不少。
}
