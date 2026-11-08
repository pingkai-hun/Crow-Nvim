-- ═══════════════════════════════════════════════════════════
-- FIX - LazyVim / Snacks → which-key 集成
-- ═══════════════════════════════════════════════════════════
--
-- 报错：
--   lazyvim/util/mini.lua:79: attempt to call field 'add' (a nil value)
--   snacks/toggle.lua:132:   attempt to call field 'add' (a nil value)
--
-- 原因：which-key 是延迟加载的。LazyVim 的 mini.ai / mini.pairs 集成，
-- 以及 Snacks 的 Toggle 注册逻辑，都会在“以为 which-key 已加载”时
-- 直接调用 require("which-key").add()。但在启动、插件重载、:Lazy
-- 更新等时机，模块可能还没真正初始化完，add 仍是 nil，于是崩溃。
--
-- 这里只做防御，不改 LazyVim / Snacks / which-key 源码：
--   1. 包装 LazyVim.mini.ai_whichkey
--   2. 包装 Snacks.util.on_module，确保回调触发时模块真的可用
-- 原因子未就绪时稍后重试，而不是直接报错。

-- ─────────────────────────────────────────────────────────────
-- Snacks：安全的 on_module
-- ─────────────────────────────────────────────────────────────
-- 注意：snacks.nvim 的 init 已经被 ui-dashboard.lua 占用（lazy.nvim
-- 合并同一个插件的 spec 时，后加载的 init 会覆盖前面的），所以这里
-- 不能再用 init，只能挂 LazyLoad 事件。
local function patch_snacks()
  local ok, util = pcall(require, "snacks.util")
  if not ok or util._crow_on_module_patched then
    return
  end
  util._crow_on_module_patched = true

  local original = util.on_module

  ---判断某个模块是否真的初始化完成（而不是加载中的占位）
  local function ready(modname)
    local mod = package.loaded[modname]
    if type(mod) ~= "table" then
      return false
    end
    -- which-key 需要 add 可用才算就绪
    if modname == "which-key" then
      return type(mod.add) == "function"
    end
    return true
  end

  util.on_module = function(modname, cb)
    original(modname, function(name)
      local function run(attempt)
        if ready(name) then
          local cb_ok, err = pcall(cb, name)
          if not cb_ok then
            vim.notify("Snacks on_module(" .. name .. "): " .. tostring(err), vim.log.levels.WARN)
          end
          return
        end
        -- 模块还在加载：最多重试 50 次（约 5 秒）
        if attempt < 50 then
          vim.defer_fn(function()
            run(attempt + 1)
          end, 100)
        end
      end
      run(0)
    end)
  end
end

local snacks_group = vim.api.nvim_create_augroup("CrowSnacksWhichKeyFix", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = snacks_group,
  pattern = "LazyLoad",
  callback = function(args)
    if args.data == "snacks.nvim" then
      vim.schedule(patch_snacks)
    end
  end,
})
-- 兜底：如果 snacks 已经加载过
vim.schedule(function()
  if package.loaded["snacks.util"] then
    patch_snacks()
  end
end)

return {
  {
    "nvim-mini/mini.ai",
    init = function()
      local Util = require("lazyvim.util")
      local mini = require("lazyvim.util.mini")
      local original = mini.ai_whichkey

      local function register(opts, attempt)
        attempt = attempt or 0
        local ok, wk = pcall(require, "which-key")
        if ok and type(wk.add) == "function" then
          return original(opts)
        end
        -- 还没准备好：最多重试 10 次（约 2 秒）
        if attempt < 10 then
          vim.defer_fn(function()
            register(opts, attempt + 1)
          end, 200)
        end
      end

      mini.ai_whichkey = function(opts)
        if Util.is_loaded("which-key.nvim") then
          register(opts)
        else
          Util.on_load("which-key.nvim", function()
            vim.schedule(function()
              register(opts)
            end)
          end)
        end
      end
    end,
  },
}
