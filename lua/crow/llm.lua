-- ═══════════════════════════════════════════════════════════
-- crow.llm —— 统一流式请求客户端
-- ═══════════════════════════════════════════════════════════
--
-- 同时支持两种协议：
--   · openai  —— /chat/completions，SSE（data: {...} / [DONE]）
--                OpenCode、OpenRouter、DashScope、DeepSeek、Kimi、GLM、
--                硅基流动，以及任何 OpenAI 兼容网关
--   · ollama  —— /api/chat，NDJSON（本机补全 / 离线兜底）
--
-- 对外只有一个入口：
--   local job = require("crow.llm").stream({
--     role = "analyze",                -- chat / inline / analyze / translate
--     system = "...",                  -- 可选
--     messages = { { role = "user", content = "..." } },
--     temperature = 0.2,               -- 可选（部分推理模型会忽略）
--     max_tokens = 1024,               -- 可选
--     timeout = 180,                   -- 秒
--     on_chunk = function(total, delta) end,
--     on_done  = function(total, meta) end,
--     on_error = function(msg, partial) end,
--   })
--   require("crow.llm").cancel(job)
--
-- 出错时不会静默：缺少 Key、HTTP 错误、模型返回 error、空回复都会走
-- on_error，并带上尽量具体的原因。

local M = {}

local models = require("crow.models")

---@type table<integer, { cancelled: boolean }>
local active = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function error_text(obj)
  local err = obj.error
  if type(err) == "table" then
    return err.message or err.msg or vim.json.encode(err)
  end
  return tostring(err)
end

---构造请求体
---@param sel table
---@param messages table[]
---@param opts table
---@return table
local function build_body(sel, messages, opts)
  if sel.protocol == "ollama" then
    local body = {
      model = sel.model,
      messages = messages,
      stream = true,
    }
    -- ⚠ Ollama 的 options 必须是 JSON **对象**。
    -- 空 Lua 表会被 vim.json.encode 编成 `[]`（数组），服务端直接拒绝：
    --   json: cannot unmarshal array into Go struct field .options of type map[string]interface {}
    -- 所以这里只在确实有参数时才加 options。
    local options = {}
    if opts.temperature ~= nil then
      options.temperature = opts.temperature
    end
    if opts.num_ctx ~= nil then
      options.num_ctx = opts.num_ctx
    end
    if opts.max_tokens ~= nil then
      options.num_predict = opts.max_tokens
    end
    if next(options) ~= nil then
      body.options = options
    end
    return body
  end

  -- 云端：只发送调用方明确要求、且模型普遍接受的字段。
  -- 部分推理模型（GPT-6 / Claude Fable / Gemini 4 等）会拒绝 temperature，
  -- 因此默认不主动发送；需要时在 provider 上标 temperature_supported = true。
  local body = {
    model = sel.model,
    messages = messages,
    stream = true,
    max_tokens = opts.max_tokens,
  }
  if opts.temperature ~= nil and (sel.provider.temperature_supported == true) then
    body.temperature = opts.temperature
  end
  return body
end

---发起一次流式请求
---@param opts table
---@return integer|nil job, string|nil err
function M.stream(opts)
  opts = opts or {}
  local role = opts.role or "chat"
  local sel = models.resolve(role, opts.provider, opts.model)

  if sel.error then
    if opts.on_error then
      vim.schedule(function()
        opts.on_error(sel.error, "")
      end)
    end
    return nil, sel.error
  end
  if sel.missing_key then
    local msg = string.format(
      "缺少 API Key：请设置 %s，或写入 lua/crow/secrets.lua（当前供应商：%s）",
      sel.env or "对应环境变量",
      sel.provider_label
    )
    if opts.on_error then
      vim.schedule(function()
        opts.on_error(msg, "")
      end)
    end
    return nil, msg
  end

  local messages = {}
  if type(opts.system) == "string" and opts.system ~= "" then
    messages[#messages + 1] = { role = "system", content = opts.system }
  end
  if type(opts.messages) == "table" then
    vim.list_extend(messages, opts.messages)
  elseif type(opts.prompt) == "string" then
    messages[#messages + 1] = { role = "user", content = opts.prompt }
  end
  if #messages == 0 then
    local msg = "请求缺少 messages / prompt"
    if opts.on_error then
      vim.schedule(function()
        opts.on_error(msg, "")
      end)
    end
    return nil, msg
  end

  local body = build_body(sel, messages, opts)
  local ok, payload = pcall(vim.json.encode, body)
  if not ok then
    local msg = "请求体无法编码: " .. tostring(payload)
    if opts.on_error then
      vim.schedule(function()
        opts.on_error(msg, "")
      end)
    end
    return nil, msg
  end

  local args = {
    "curl",
    "-sS",
    "-N", -- 关闭缓冲，保证逐行到达
    "--max-time",
    tostring(opts.timeout or 300),
    "-H",
    "Content-Type: application/json",
  }

  if sel.key and sel.key ~= "" then
    args[#args + 1] = "-H"
    args[#args + 1] = "Authorization: Bearer " .. sel.key
  end
  for k, v in pairs(sel.provider.headers or {}) do
    if type(v) == "string" then
      args[#args + 1] = "-H"
      args[#args + 1] = k .. ": " .. v
    end
  end

  vim.list_extend(args, { "--data-binary", "@-", sel.url })

  local pending = "" -- 跨块半行
  local total = "" -- 累积正文
  local stderr_buf = ""
  local api_error = nil
  local finished = false
  local cancelled = false
  local job

  local function emit(delta)
    vim.schedule(function()
      if not cancelled and opts.on_chunk then
        pcall(opts.on_chunk, total, delta)
      end
    end)
  end

  local function handle_line(line)
    line = line:gsub("\r$", "")
    if line == "" then
      return
    end

    if sel.protocol == "ollama" then
      local ok2, obj = pcall(vim.json.decode, line)
      if not ok2 or type(obj) ~= "table" then
        return
      end
      if obj.error then
        api_error = error_text(obj)
        return
      end
      local delta = (obj.message and obj.message.content) or obj.response
      if type(delta) == "string" and delta ~= "" then
        total = total .. delta
        emit(delta)
      end
      return
    end

    -- OpenAI SSE
    local data
    if line:sub(1, 5) == "data:" then
      data = trim(line:sub(6))
    elseif line:sub(1, 1) == "{" then
      -- 有些网关在 HTTP 错误时直接返回裸 JSON，没有 data: 前缀
      data = line
    else
      return
    end

    if data == "" or data == "[DONE]" then
      return
    end

    local ok2, obj = pcall(vim.json.decode, data)
    if not ok2 or type(obj) ~= "table" then
      return
    end
    if obj.error then
      api_error = error_text(obj)
      return
    end

    local choice = obj.choices and obj.choices[1]
    local delta = choice
      and (
        (choice.delta and choice.delta.content)
        or (choice.message and choice.message.content)
        or (choice.text and choice.text)
      )
    if type(delta) == "string" and delta ~= "" then
      total = total .. delta
      emit(delta)
    end
  end

  local function feed(data)
    if type(data) ~= "table" or #data == 0 then
      return
    end
    -- data[1] 是上一块留下的半行；最后一项可能仍是半行
    pending = pending .. data[1]
    for i = 2, #data do
      handle_line(pending)
      pending = data[i]
    end
  end

  local function finish(err)
    if finished then
      return
    end
    finished = true
    active[job] = nil

    vim.schedule(function()
      if err then
        if opts.on_error then
          pcall(opts.on_error, err, total)
        end
      elseif opts.on_done then
        pcall(opts.on_done, total, { selection = sel })
      end
    end)
  end

  job = vim.fn.jobstart(args, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      feed(data)
    end,
    on_stderr = function(_, data)
      if type(data) == "table" then
        stderr_buf = stderr_buf .. table.concat(data, "\n")
      end
    end,
    on_exit = function(_, code)
      if cancelled then
        active[job] = nil
        return
      end
      if pending ~= "" then
        handle_line(pending)
        pending = ""
      end

      if api_error then
        finish("模型接口报错：" .. api_error)
      elseif code ~= 0 then
        local detail = trim(stderr_buf)
        finish(
          string.format(
            "请求失败（curl 退出码 %d）%s",
            code,
            detail ~= "" and ("：" .. detail) or "。检查网络、代理或 base_url"
          )
        )
      elseif total == "" then
        local detail = trim(stderr_buf)
        finish("模型没有返回内容" .. (detail ~= "" and ("：" .. detail) or ""))
      else
        finish(nil)
      end
    end,
  })

  if job <= 0 then
    active[job] = nil
    local msg = "无法启动 curl，请确认系统已安装 curl"
    if opts.on_error then
      vim.schedule(function()
        opts.on_error(msg, "")
      end)
    end
    return nil, msg
  end

  active[job] = { cancelled = false }
  vim.fn.chansend(job, payload)
  vim.fn.chanclose(job, "stdin")

  return job
end

---中断请求
---@param job integer|nil
---@return boolean
function M.cancel(job)
  if not job or job <= 0 then
    return false
  end
  local entry = active[job]
  if entry then
    entry.cancelled = true
  end
  active[job] = nil
  pcall(vim.fn.jobstop, job)
  return true
end

---取消所有进行中的请求（目前未使用，留给 :CrowAiStop 扩展）
function M.cancel_all()
  for job in pairs(active) do
    M.cancel(job)
  end
end

return M
