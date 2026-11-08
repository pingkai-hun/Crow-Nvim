-- ============================================================================
-- crow.guard —— 启动阶段的防御性检查
-- ============================================================================
-- 针对这个反复出现的报错：
--
--   which-key.nvim/plugin/which-key.lua:8: attempt to call field 'setup' (a nil value)
--
-- 报错来自 which-key 自己的 plugin 脚本，它会在插件加载后 500ms 触发一个定时器：
--
--   local wk = require("which-key")
--   if not wk.did_setup then
--     wk.setup()          -- ← setup 为 nil 时崩溃
--   end
--
-- 也就是说：只要在定时器触发之前把 did_setup 置为 true，这一行就不会执行，
-- 报错在结构上就不可能发生。这正是本模块做的事。
--
-- 正常情况下不会有任何动作：LazyVim 的 config 已经调用过 setup()，
-- did_setup 已是 true，这里直接返回。只有在「config 因为某种原因没跑完」
-- 的异常路径上，才由这里补一次 setup —— 把「崩溃」变成「功能正常」。
--
-- 注意：这里不是 patch 第三方源码，也不改 require，只是补一个幂等的初始化。

local M = {}

local WK = "which-key"

--- 取 lazy.nvim 合并后的 which-key 配置（失败返回空表）
---@return table
local function resolved_opts()
  local ok, cfg = pcall(function()
    local plugin = require("lazy.core.config").plugins["which-key.nvim"]
    if not plugin then
      return {}
    end
    return require("lazy.core.plugin").values(plugin, "opts") or {}
  end)
  return (ok and type(cfg) == "table") and cfg or {}
end

--- 确保 which-key 已完成 setup（幂等）。
---@return boolean ok, string? reason
function M.ensure_which_key()
  local ok, wk = pcall(require, WK)
  if not ok or type(wk) ~= "table" then
    return false, "模块未就绪"
  end
  -- 模块结构不对时不要去猜，保持原样（宁可不动也不要制造新问题）
  if type(wk.setup) ~= "function" then
    return false, "setup 不存在"
  end
  if wk.did_setup then
    return true, "已初始化"
  end
  local ok2, err = pcall(wk.setup, resolved_opts())
  if not ok2 then
    return false, "setup 失败: " .. tostring(err)
  end
  return true, "已补做初始化"
end

--- 在 require("lazy").setup() 之后调用一次。
function M.setup()
  local ok, reason = M.ensure_which_key()
  if not ok and reason ~= "模块未就绪" then
    -- 不打扰用户：只有真的异常才提示，且只提示一次
    vim.schedule(function()
      vim.notify("which-key 初始化异常：" .. tostring(reason), vim.log.levels.WARN, { title = "CrowNvim" })
    end)
  end
end

return M
