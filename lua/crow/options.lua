-- ============================================================================
-- crow.options —— 在 LazyVim 之后写回 Easy-Vim 的选项
-- ============================================================================
-- 背景：LazyVim 自带 lua/lazyvim/config/options.lua，在 lazy.setup() 内部执行，
-- 时机比用户的 config/options.lua **更晚**，因此会把下面这些值覆盖回去：
--
--   scrolloff      LazyVim 4   ← Easy-Vim 5
--   sidescrolloff  LazyVim 8   ← Easy-Vim 5
--   pumheight      LazyVim 10  ← Easy-Vim 12
--   updatetime     LazyVim 200 ← Easy-Vim 300
--
-- 所以必须在 require("config.lazy") 之后调用本模块的 enforce()，
-- 才能得到和 ~/.vimrc 一致的手感。

local M = {}

-- Easy-Vim 的目标值（对应 ~/.vimrc「基础设置」）
M.values = {
  scrolloff = 5, -- 滚动边距
  sidescrolloff = 5,
  pumheight = 12, -- 补全菜单最多 12 行
  updatetime = 300, -- 更快的 CursorHold（诊断 / 悬浮文档）
  timeoutlen = 500, -- leader 序列超时
  ttimeoutlen = 10, -- Esc 立即生效
  clipboard = "unnamedplus", -- 与系统剪贴板互通（wl-copy / xclip）
}

--- 把上表的值写回当前会话。
function M.enforce()
  for name, value in pairs(M.values) do
    pcall(function()
      vim.opt[name] = value
    end)
  end
end

--- 在 LazyVim 加载完成后调用。
--- 注意 clipboard 特别麻烦：LazyVim 会在 User VeryLazy 时把 clipboard
--- 恢复成它启动时记录的值（lazyvim/config/init.lua 的 lazy_clipboard），
--- 时机晚于 lazy.setup()，所以这里要再挂一次 VeryLazy 才能压住。
function M.setup()
  M.enforce()
  vim.api.nvim_create_autocmd({ "VimEnter", "User" }, {
    group = vim.api.nvim_create_augroup("CrowEnsureOptions", { clear = true }),
    pattern = { "*", "VeryLazy" },
    callback = function()
      -- 延后一拍，等 LazyVim / 插件把选项改完
      vim.schedule(M.enforce)
    end,
    desc = "写回 Easy-Vim 选项",
  })
end

return M
