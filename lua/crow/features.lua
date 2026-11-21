-- ═══════════════════════════════════════════════════════════
-- crow.features —— 功能开关
-- ═══════════════════════════════════════════════════════════
--
-- 分两层：
--
--   DEFAULTS      本文件，随仓库分发，是「出厂默认值」
--   features_user.lua   同目录，已加入 .gitignore，只存「与默认值不同」的项
--
-- features_user.lua 由 scripts/features.sh 生成，也可以手改，格式：
--
--   return {
--     minuet = false,
--   }
--
-- 只写需要覆盖的项；没写的项沿用 DEFAULTS。这样以后调整出厂默认值，
-- 没手动改过开关的用户会自动跟上。
--
-- 开关清单（key / 出厂默认 / 作用）：
--   minuet         true   行内幽灵补全（minuet-ai.nvim，默认本机 1.5b）
--   codecompanion  true   对话 / 内联改写 / 结构化审查（云端或本机）
--   crow_ai        true   :CrowExplain · :CrowReview · :CrowAsk
--   translate      true   文档翻译（悬停文档 + 补全文档，云端或本机）
--   copilot_chat   true   CopilotChat.nvim（GitHub Copilot 对话）
--
-- 用法：
--   require("crow.features").on("minuet")      -- 单个
--   require("crow.features").any({ "minuet", "codecompanion" })
--   require("crow.features").state()           -- 合并后的完整表
--
-- 改动开关后需要重启 Neovim 才生效（插件 spec 只在启动时解析一次）。

local M = {}

---@type table<string, boolean> 出厂默认值
M.defaults = {
  minuet = true,
  codecompanion = true,
  crow_ai = true,
  translate = true,
  copilot_chat = true,
}

---@type table<string, boolean>|nil
local overrides

---@type table<string, boolean>
local warned = {}

local function warn(msg)
  if warned[msg] then
    return
  end
  warned[msg] = true
  vim.notify("[crow.features] " .. msg, vim.log.levels.WARN)
end

---读取用户覆盖（只读一次，结果缓存）
---@return table<string, boolean>
local function user_overrides()
  if overrides then
    return overrides
  end
  overrides = {}

  local ok, user = pcall(require, "crow.features_user")
  if ok then
    if type(user) == "table" then
      for name, value in pairs(user) do
        if M.defaults[name] == nil then
          warn(("features_user.lua 里有未知的开关 %q，已忽略"):format(tostring(name)))
        else
          overrides[name] = value ~= false
        end
      end
    else
      warn("features_user.lua 应该 return 一个 table，已忽略")
    end
  elseif not tostring(user):find("crow.features_user", 1, true) then
    -- 「文件不存在」是正常状态；语法错误才需要报出来
    warn("features_user.lua 解析失败：" .. tostring(user))
  end

  return overrides
end

---某个功能是否开启（未知开关按开启处理并告警一次）
---@param name string
---@return boolean
function M.on(name)
  if M.defaults[name] == nil then
    warn(("未知的开关 %q，按开启处理"):format(tostring(name)))
    return true
  end

  local value = user_overrides()[name]
  if value == nil then
    return M.defaults[name] ~= false
  end
  return value ~= false
end

---列表里任意一个开启即为 true
---@param names string[]
---@return boolean
function M.any(names)
  for _, name in ipairs(names) do
    if M.on(name) then
      return true
    end
  end
  return false
end

---合并后的完整状态（默认值 + 用户覆盖）
---@return table<string, boolean>
function M.state()
  local merged = {}
  for name, value in pairs(M.defaults) do
    merged[name] = M.on(name)
  end
  return merged
end

return M
