-- ============================================================================
-- crow.ai —— 本机 3B 模型辅助代码分析
-- ============================================================================
-- 本机通过 Ollama 部署了 qwen2.5-coder:3b（32768 上下文，Q4_K_M）。
-- 这个模块把「分析代码」做成一条顺手的工作流，而不是让用户自己拼 prompt：
--
--   :CrowExplain [范围]   解释当前函数 / 可视选区 / 光标所在代码块
--   :CrowReview  [范围]   代码审查：找 bug、边界条件、坏味道，按严重程度列
--   :CrowAsk     [问题]   带着文件上下文提问（不选中也能问）
--   :CrowStats            看看模型 / 服务状态
--
-- 实现上直接调 Ollama 的 /api/chat（流式），结果写进一个可复用的浮窗：
--   · 不依赖 codecompanion 也能用（那边留给对话式编辑）
--   · 流式输出，3B 模型首 token 约 1 秒，不用干等
--   · 失败时给出明确原因（服务没起 / 模型没拉 / 超时），不让用户猜
--
-- 快捷键（which-key 分组 <leader>o = Ollama）：
--   <leader>oa  分析 / 解释当前函数（普通模式）
--   <leader>or  审查当前文件或选区
--   <leader>oq  带上下文提问
--   <leader>oi  查看 AI 状态

local M = {}

local MODEL = "qwen2.5-coder:3b"
local ENDPOINT = "http://127.0.0.1:11434/api/chat"

-- 分析用的系统提示：3B 模型指令遵循能力一般，提示要短、明确、只做一件事。
local SYSTEM = table.concat({
  "你是一名资深代码审查员。回答用简体中文，结论先行。",
  "不要客套话，不要重复用户代码全文。",
  "涉及代码时只给最小必要的片段。",
}, "\n")

-- ── 状态缓存 ────────────────────────────────────────────────────────────
local state = {
  buf = nil, -- 输出浮窗的 buffer
  win = nil, -- 浮窗
  job = nil, -- 进行中的请求（避免并发打爆本地模型）
}

-- ── 工具 ────────────────────────────────────────────────────────────────
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Crow AI" })
end

--- 取当前范围要分析的代码。
--- 优先可视选区（调用方通过 '< '> 传入），否则取光标所在函数 / 代码块。
---@param explicit? { start: integer, stop: integer }
---@return string text, string desc
function M.collect(explicit)
  local start, stop
  if explicit then
    start, stop = explicit.start, explicit.stop
  elseif vim.fn.mode():find("[vV\22]") then
    start = vim.fn.line("v") < vim.fn.line(".") and vim.fn.line("v") or vim.fn.line(".")
    stop = vim.fn.line("v") > vim.fn.line(".") and vim.fn.line("v") or vim.fn.line(".")
  else
    -- 用 treesitter 找外层函数 / 类；找不到就退化为整个文件（限 200 行）
    local node = vim.treesitter.get_node({ ignore_injections = false })
    while node do
      local t = node:type()
      if t:find("function") or t:find("method") or t:find("class") then
        break
      end
      node = node:parent()
    end
    if node then
      local sr, _, er = node:range()
      start, stop = sr + 1, er + 1
    else
      start, stop = 1, math.min(vim.api.nvim_buf_line_count(0), 200)
    end
  end
  start = math.max(1, start)
  stop = math.min(vim.api.nvim_buf_line_count(0), stop)
  local lines = vim.api.nvim_buf_get_lines(0, start - 1, stop, false)
  local desc = string.format("%s:L%d-%d", vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t"), start, stop)
  return table.concat(lines, "\n"), desc
end

--- 拼装请求体。
---@param task string 任务说明
---@param code? string 待分析的代码
local function build_body(task, code)
  local filetype = vim.bo.filetype
  local content = string.format("【任务】%s\n\n【语言】%s\n\n【代码】\n```%s\n%s\n```",
    task, filetype ~= "" and filetype or "text", filetype, code or "")
  return vim.json.encode({
    model = MODEL,
    stream = true,
    messages = {
      { role = "system", content = SYSTEM },
      { role = "user", content = content },
    },
    options = {
      temperature = 0.2, -- 分析类任务要稳定，不要发挥
      num_ctx = 8192, -- 3B 支持 32k，8k 够用且更快
      num_predict = 1024, -- 单次回答上限，防止胡说八道拖时间
    },
  })
end

-- ── 输出浮窗 ────────────────────────────────────────────────────────────
--- 打开（或复用）结果浮窗，返回 buffer 编号。
---@param title string
local function open_float(title)
  -- 复用：同一 buffer 直接清空
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
  else
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].filetype = "markdown"
    vim.bo[state.buf].bufhidden = "hide"
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = state.buf, desc = "关闭" })
  end

  local width = math.min(math.max(60, math.floor(vim.o.columns * 0.7)), 100)
  local height = math.min(math.max(12, math.floor(vim.o.lines * 0.5)), 30)
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    style = "minimal",
  })
  vim.wo[state.win].wrap = true
  vim.wo[state.win].conceallevel = 2
  return state.buf
end

--- 往浮窗追加一行。
local function append(line)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  vim.bo[state.buf].modifiable = true
  local last = vim.api.nvim_buf_line_count(state.buf)
  vim.api.nvim_buf_set_lines(state.buf, last, last, false, { line })
  -- 跟随输出滚动
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_cursor(state.win, { vim.api.nvim_buf_line_count(state.buf), 0 })
  end
end

--- 把累积的文本整体重绘进浮窗（流式输出用）。
--- Ollama 的流式响应是按 token 切的，「一个字 / 半个词」一块，
--- 如果每块都 append 一行，就会变成「一个词一行」的竖排。
--- 所以要累积到 text 里，每次重绘整个 buffer。
---@param text string
---@param status? string 末尾状态行
local function render(text, status)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local lines = vim.split(text, "\n", { plain = true })
  if status and status ~= "" then
    lines[#lines + 1] = ""
    lines[#lines + 1] = status
  end
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    local n = vim.api.nvim_buf_line_count(state.buf)
    pcall(vim.api.nvim_win_set_cursor, state.win, { n, 0 })
  end
end

-- ── 核心：流式请求 ──────────────────────────────────────────────────────
-- ── 审查结果去重 ────────────────────────────────────────────────────────
-- 3B 模型的指令遵循不够稳：同一个问题常常被套进好几个分类重复列出。
-- 与其反复调 prompt（既费时又不保证），不如在展示层做去重：
--   · 提取每条的「修复建议正文」，完全相同视为同一问题，只保留最严重的那条
--   · 按 Bug > 安全 > 性能 > 可维护性 排序，方便先看要紧的
local LEVEL_ORDER = { ["Bug"] = 1, ["安全"] = 2, ["性能"] = 3, ["可维护性"] = 4 }

--- 把模型输出整理成「按级别排序 + 去重」的 Markdown。
---@param text string
---@return string
local function dedup_review(text)
  local items, others = {}, {}
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    -- 3B 输出的级别写法不固定，这里同时兼容：
    --   - **[安全] 使用参数化查询**（第 3 行）— ...
    --   - **Bug** SQL 注入风险（1）— ...
    --   - **[Bug] SQL 注入**
    --   - **安全**: 参数化查询
    local level = line:match("%*%*%[([^%]]+)%]") -- 带方括号
      or line:match("^%s*[-*]%s*%*%*([%w%/]+)%*%*") -- 不带方括号
    if level and (line:sub(1, 1) == "-" or line:sub(1, 1) == "*") then
      -- 去重键：去掉「级别」和行号后的实质内容（问题 + 建议）
      local key = line:gsub("%s+", "")
        :gsub("%*%*%[[^%]]+%]%*%*", "") -- 去掉 **[级别]**
        :gsub("%*%*[%w%/]+%*%*", "") -- 去掉 **级别**
        :gsub("第%d+行", "")
        :gsub("行号?%d+", "")
        :gsub("[（）%(%)]", "")
      items[#items + 1] = {
        raw = line,
        level = LEVEL_ORDER[level] or 99,
        level_name = level,
        key = key,
      }
    elseif line ~= "" then
      others[#others + 1] = line
    end
  end

  if #items == 0 then
    return text
  end

  -- 去重：同一个 key（问题+建议相同）只留级别最高的一条
  local seen, kept = {}, {}
  for _, it in ipairs(items) do
    if not seen[it.key] then
      seen[it.key] = true
      kept[#kept + 1] = it
    end
  end
  table.sort(kept, function(a, b)
    return a.level < b.level
  end)

  local out = {}
  local last_level = nil
  for _, it in ipairs(kept) do
    if it.level ~= last_level then
      if last_level ~= nil then
        out[#out + 1] = ""
      end
      out[#out + 1] = "### " .. it.level_name
      last_level = it.level
    end
    out[#out + 1] = it.raw
  end
  -- 模型额外的前言/结论保留在末尾，但要去掉自相矛盾的「未发现问题」
  -- （3B 常常先列出问题，末尾又补一句「未发现问题」）。
  if #others > 0 then
    local keep = {}
    for _, l in ipairs(others) do
      local is_contradiction = l:find("未发现问题") and #kept == 0
      if not (is_contradiction and #kept == 0 and #others == 1) and not l:find("未发现问题") then
        keep[#keep + 1] = l
      end
    end
    if #keep > 0 then
      out[#out + 1] = ""
      for _, l in ipairs(keep) do
        out[#out + 1] = l
      end
    end
  end
  return table.concat(out, "\n")
end

---@param task string
---@param code? string
---@param title string
---@param transform? fun(text: string): string 完成后对正文做一次后处理
function M.request(task, code, title, transform)
  if state.job then
    notify("上一个分析还在进行，请稍候（:CrowAiStop 可中断）", vim.log.levels.WARN)
    return
  end

  local body = build_body(task, code)
  local buf = open_float(title or "AI 分析")
  local pending = ""   -- 不完整的 JSON 行（跨块）
  local text = ""      -- 累积的正文（按 token 拼接，最后整体渲染）
  local started = vim.uv.now()

  local function on_chunk(_, data, _)
    -- jobstart 的 on_stdout 回调里 data 是「按行切好的数组」，
    -- 最后一段可能是不完整的行（下一块数据会接上）。
    -- 不能直接 pending .. data，那会报 attempt to concatenate (a table value)。
    if type(data) ~= "table" then
      return
    end
    local got = false
    for i, piece in ipairs(data) do
      local is_last = (i == #data)
      if is_last then
        -- 半行：留到下次
        pending = pending .. piece
      else
        local line = pending .. piece
        pending = ""
        if line ~= "" then
          local ok, obj = pcall(vim.json.decode, line)
          if ok and obj then
            if obj.error then
              text = text .. "\n**错误**: " .. tostring(obj.error) .. "\n"
              got = true
            elseif obj.message and obj.message.content then
              -- 关键：按 token 累积，不要逐块换行
              text = text .. obj.message.content
              got = true
            end
          end
        end
      end
    end
    if got then
      render(text, "_" .. MODEL .. " · 分析中…_")
    end
  end

  local function on_exit(_, code2)
    state.job = nil
    local secs = (vim.uv.now() - started) / 1000
    if code2 ~= 0 then
      render(text, string.format("_请求失败（退出码 %d）。检查：ollama serve 是否在跑，模型是否已拉取。_", code2))
    else
      local final = text
      if transform then
        local ok2, res = pcall(transform, text)
        if ok2 and type(res) == "string" then
          final = res
        end
      end
      render(final, string.format("_完成，用时 %.1fs · %s_", secs, MODEL))
    end
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      vim.bo[state.buf].modifiable = false
    end
  end

  state.job = vim.fn.jobstart({
    "curl", "-sN", "--max-time", "180",
    "-H", "Content-Type: application/json",
    "-d", body,
    ENDPOINT,
  }, {
    stdout_buffered = false,
    on_stdout = on_chunk,
    on_exit = on_exit,
  })

  if state.job <= 0 then
    state.job = nil
    append("**无法启动 curl。** 请确认系统里有 curl。")
  else
    render("", string.format("_%s · 分析中…_", MODEL))
  end
  return buf
end

-- ── 中断 ────────────────────────────────────────────────────────────────
function M.stop()
  if state.job then
    vim.fn.jobstop(state.job)
    state.job = nil
    notify("已中断当前分析", vim.log.levels.WARN)
  else
    notify("当前没有进行中的分析")
  end
end

-- ── 三个入口 ────────────────────────────────────────────────────────────
--- 解释代码
function M.explain(opts)
  local code, desc = M.collect(opts and opts.range)
  M.request(
    "逐段解释下面这段代码：它做什么、关键数据流是什么、有没有隐含假设。" ..
      "按「一句话总结 / 逐步说明 / 注意点」三段来写。",
    code,
    "解释 " .. desc
  )
end

--- 代码审查
function M.review(opts)
  local code, desc = M.collect(opts and opts.range)
  M.request(
    "审查下面这段代码。只输出确实存在的问题，每个问题只出现一次，不要重复。\n" ..
      "用一个 Markdown 列表，每条格式为：\n" ..
      "- **[级别] 问题简述**（行号）— 为什么是问题 — 怎么改\n" ..
      "级别只能从这四个里选：Bug / 安全 / 性能 / 可维护性。\n" ..
      "改动很小的修复请直接给出替换后的代码行。\n" ..
      "如果代码没问题，只输出一句「未发现问题」。",
    code,
    "审查 " .. desc,
    dedup_review
  )
end

--- 带上下文提问
---@param question? string 没有就提示输入
function M.ask(question)
  if not question or question == "" then
    question = vim.fn.input("问 AI（关于当前文件）：")
    if question == "" then
      return
    end
  end
  -- 带上整个文件的上下文（截断到 400 行），3B 的 8k 上下文足够
  local lines = vim.api.nvim_buf_get_lines(0, 0, math.min(vim.api.nvim_buf_line_count(0), 400), false)
  local code = table.concat(lines, "\n")
  M.request(question, code, "提问")
end

-- ── 状态 ────────────────────────────────────────────────────────────────
function M.stats()
  local out = { "本机 AI 状态", string.rep("─", 36) }
  if vim.fn.executable("curl") == 0 then
    out[#out + 1] = "✘ 未安装 curl"
  else
    local raw = vim.fn.system({ "curl", "-s", "--max-time", "1", "http://127.0.0.1:11434/api/tags" })
    if vim.v.shell_error ~= 0 or raw == "" then
      out[#out + 1] = "✘ Ollama 未响应（运行 ollama serve 启动）"
    else
      out[#out + 1] = "✔ Ollama 服务在线"
      local ok, data = pcall(vim.json.decode, raw)
      if ok and data.models then
        for _, m in ipairs(data.models) do
          local name = m.name or m.model or "?"
          local gb = (m.size or 0) / 1024 / 1024 / 1024
          out[#out + 1] = string.format("  %s %-20s %.1f GB", name == MODEL and "→" or " ", name, gb)
        end
      end
    end
  end
  out[#out + 1] = ""
  out[#out + 1] = "在用的模型: " .. MODEL
  out[#out + 1] = "快捷键: <leader>oa 解释 · <leader>or 审查 · <leader>oq 提问"

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  local width = 56
  local height = #out + 2
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " AI 状态 ",
    title_pos = "center",
    style = "minimal",
  })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf })
end

-- ── 注册命令与快捷键 ────────────────────────────────────────────────────
function M.setup()
  vim.api.nvim_create_user_command("CrowExplain", function()
    M.explain()
  end, { desc = "AI 解释当前函数 / 选区" })

  vim.api.nvim_create_user_command("CrowReview", function()
    M.review()
  end, { desc = "AI 审查当前文件 / 选区" })

  vim.api.nvim_create_user_command("CrowAsk", function(opts)
    M.ask(opts.args)
  end, { nargs = "*", desc = "AI 带上下文提问" })

  vim.api.nvim_create_user_command("CrowAiStats", function()
    M.stats()
  end, { desc = "本机 AI 状态" })

  vim.api.nvim_create_user_command("CrowAiStop", function()
    M.stop()
  end, { desc = "中断 AI 分析" })

  local map = vim.keymap.set
  local function visual_range()
    local s = vim.fn.line("v")
    local e = vim.fn.line(".")
    return { start = math.min(s, e), stop = math.max(s, e) }
  end

  map("n", "<leader>oa", function()
    M.explain()
  end, { desc = "AI 解释当前函数" })
  map("x", "<leader>oa", function()
    M.explain({ range = visual_range() })
  end, { desc = "AI 解释选区" })

  map("n", "<leader>or", function()
    M.review()
  end, { desc = "AI 审查当前函数" })
  map("x", "<leader>or", function()
    M.review({ range = visual_range() })
  end, { desc = "AI 审查选区" })

  map("n", "<leader>oq", function()
    M.ask()
  end, { desc = "AI 带上下文提问" })

  -- 注意：<leader>os 已被「开启会话自动保存」占用，状态改用 <leader>oi
  map("n", "<leader>oi", function()
    M.stats()
  end, { desc = "AI 状态" })

  pcall(function()
    require("which-key").add({
      { "<leader>o", group = "Ollama / AI" },
      { "<leader>oa", desc = "AI 解释" },
      { "<leader>or", desc = "AI 审查" },
      { "<leader>oq", desc = "AI 提问" },
      { "<leader>oi", desc = "AI 状态" },
    })
  end)
end

return M
