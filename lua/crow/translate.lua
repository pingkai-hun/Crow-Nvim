-- ═══════════════════════════════════════════════════════════
-- crow.translate —— 本地 Ollama 流式翻译（NDJSON）
-- ═══════════════════════════════════════════════════════════
--
-- 供补全文档（blink.cmp）和悬停文档（noice.nvim）共用：
--
--   · 请求 Ollama 时开启 stream = true
--   · 逐行解析 NDJSON（每行一个 JSON 对象，取其中的 response 字段）
--   · 用 vim.schedule 把 UI 更新切回主线程
--   · 同一段文本只翻译一次（sha256 缓存）
--   · 串行队列：只翻译“当前最新”的请求，过期请求直接丢弃
--
-- 对外接口：
--   M.cached(text)            -> 已缓存的译文或 nil
--   M.should_translate(text)  -> 是否需要翻译（中文 / 纯代码返回 false）
--   M.stream(text, opts)      -> opts.on_chunk(partial), opts.on_done(final|nil)

local M = {}

M.model = vim.g.crow_translate_model or "qwen2.5-coder:3b"
M.url = vim.g.crow_translate_url or "http://127.0.0.1:11434/api/generate"
M.max_chars = 8000

local PROMPT = [[你是资深程序员兼技术译者。把下面的技术文档翻译成简体中文。
要求：
1. 只翻译自然语言说明；代码、函数名、参数名、类型名、路径、URL、代码块内容必须原样保留。
2. 保留 Markdown 结构（标题、列表、表格、代码围栏）和换行。
3. 不要输出解释、前缀、后缀或额外标题，只输出译文。
文档内容：
]]

local cache = {} -- sha256 -> 译文
local pending = {} -- sha256 -> entry
local queue = {}
local busy = false
local latest = nil -- 最近一次请求的 key，过期请求直接丢弃

-- 粗略判断是否已经含中文（UTF-8 汉字首字节范围 E4–E9）
function M.has_chinese(text)
  local _, count = text:gsub("[\228-\233]", "")
  return count > 0
end

-- 去掉代码块/行内代码后几乎没有自然语言，就认为不需要翻译
function M.is_mostly_code(text)
  local stripped = text:gsub("```.-```", ""):gsub("`[^`]-`", "")
  local letters = 0
  for _ in stripped:gmatch("%a") do
    letters = letters + 1
    if letters >= 8 then
      return false
    end
  end
  return true
end

function M.should_translate(text)
  return type(text) == "string"
    and #text >= 4
    and #text <= M.max_chars
    and not M.has_chinese(text)
    and not M.is_mostly_code(text)
end

function M.cached(text)
  if type(text) ~= "string" then
    return nil
  end
  return cache[vim.fn.sha256(text)]
end

local function trim_fence(text)
  text = vim.trim(text)
  text = text:gsub("^```[%w_-]*\n", "")
  text = text:gsub("\n```$", "")
  return text
end

local function finish(entry, translated)
  pending[entry.key] = nil
  if translated and translated ~= "" then
    cache[entry.key] = translated
  end
  for _, listener in ipairs(entry.listeners) do
    if listener.on_done then
      pcall(listener.on_done, translated)
    end
  end
end

-- 把累计到的 token 分发给监听者；真正更新 UI 时由调用方切主线程
local function emit_chunk(entry, partial)
  for _, listener in ipairs(entry.listeners) do
    if listener.on_chunk then
      vim.schedule(function()
        pcall(listener.on_chunk, partial)
      end)
    end
  end
end

local function handle_line(entry, line, chunks)
  if line == "" then
    return
  end

  local ok, obj = pcall(vim.json.decode, line)
  if not ok or type(obj) ~= "table" or type(obj.response) ~= "string" then
    return
  end

  table.insert(chunks, obj.response)

  -- 约 20fps 刷新一次，避免每个 token 都重绘
  local now = vim.uv.now()
  if not entry.last_emit or now - entry.last_emit >= 50 then
    entry.last_emit = now
    emit_chunk(entry, trim_fence(table.concat(chunks)))
  end
end

local function start_stream(entry)
  local chunks = {}
  -- 行缓冲：data[1] 可能接着上一次的残行，data 最后一项可能是半行
  local lines = { "" }

  local function feed(data)
    if not data or #data == 0 then
      return
    end
    lines[#lines] = lines[#lines] .. data[1]
    for i = 2, #data do
      lines[#lines + 1] = data[i]
    end
    -- 最后一项可能是半行，留到下次或结束时再处理
    while #lines > 1 do
      handle_line(entry, table.remove(lines, 1), chunks)
    end
  end

  local payload = vim.json.encode({
    model = M.model,
    prompt = PROMPT .. entry.text,
    stream = true,
    options = {
      temperature = 0,
      num_predict = math.min(4096, math.max(512, #entry.text)),
    },
  })

  local job = vim.fn.jobstart({
    "curl",
    "-sS",
    "-N", -- 关闭 curl 缓冲，保证逐行到达
    "-m",
    "90",
    M.url,
    "-H",
    "Content-Type: application/json",
    "--data-binary",
    "@-",
  }, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      feed(data)
    end,
    on_stderr = function() end,
    on_exit = function()
      -- 处理最后一行（可能没有换行符）
      if lines[1] ~= "" then
        handle_line(entry, lines[1], chunks)
      end
      vim.schedule(function()
        busy = false
        local final = trim_fence(table.concat(chunks))
        finish(entry, final ~= "" and final or nil)
        M._process()
      end)
    end,
  })

  if job <= 0 then
    busy = false
    finish(entry, nil)
    M._process()
    return
  end

  vim.fn.chansend(job, payload)
  vim.fn.chanclose(job, "stdin")
end

function M._process()
  if busy or #queue == 0 then
    return
  end

  -- 丢弃已经过期的请求（用户已经切换到别的补全项 / 悬停目标）
  local entry
  while #queue > 0 do
    entry = table.remove(queue, 1)
    if entry.key == latest then
      break
    end
    finish(entry, nil)
    entry = nil
  end
  if not entry then
    return
  end

  busy = true
  start_stream(entry)
end

---流式翻译一段文本
---@param text string
---@param opts { on_chunk?: fun(partial: string), on_done?: fun(final: string|nil) }
function M.stream(text, opts)
  opts = opts or {}
  local key = vim.fn.sha256(text)
  latest = key

  local cached = cache[key]
  if cached then
    if opts.on_done then
      opts.on_done(cached)
    end
    return
  end

  local entry = pending[key]
  if entry then
    table.insert(entry.listeners, opts)
    return
  end

  entry = { key = key, text = text, listeners = { opts } }
  pending[key] = entry
  table.insert(queue, entry)
  M._process()
end

return M
