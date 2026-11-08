-- ═══════════════════════════════════════════════════════════
-- PLUGINS - 悬停文档汉化（noice.nvim）
-- ═══════════════════════════════════════════════════════════
--
-- noice.nvim 把 vim.lsp.buf.hover 换成了自己的实现，真正渲染悬停
-- 文档的入口是 noice.lsp.hover.on_hover。这里包一层：
--
--   · 先按原文弹出，阅读不等待
--   · 同时把文档交给 crow.translate 流式翻译（Ollama）
--   · 每收到一段译文就原地刷新 noice 的 hover 消息
--
-- 有缓存时直接弹中文，避免英文一闪而过。

local T = require("crow.translate")

---从 LSP hover contents 里提取纯文本（保留原始 markdown）
local function extract_text(contents)
  if type(contents) == "string" then
    return contents
  end
  if type(contents) ~= "table" then
    return nil
  end
  if type(contents.value) == "string" then
    return contents.value
  end
  if vim.islist(contents) then
    local parts = {}
    for _, item in ipairs(contents) do
      local text = extract_text(item)
      if text then
        table.insert(parts, text)
      end
    end
    return table.concat(parts, "\n")
  end
  return nil
end

local function patch_hover()
  local ok, hover = pcall(require, "noice.lsp.hover")
  if not ok or hover._crow_translate_patched then
    return
  end
  hover._crow_translate_patched = true

  local original = hover.on_hover
  local generation = 0

  hover.on_hover = function(err, result, ctx)
    generation = generation + 1
    local my_gen = generation

    local contents = result and result.contents
    local text = contents and extract_text(contents)
    local ft = ctx and ctx.bufnr and vim.bo[ctx.bufnr].filetype or nil

    -- 已翻译过：直接用中文，避免英文先闪一下
    local cached = text and T.cached(text)
    if cached then
      return original(err, { contents = { kind = "markdown", value = cached } }, ctx)
    end

    -- 先显示英文原文
    original(err, result, ctx)

    if not text or not T.should_translate(text) then
      return
    end

    ---把当前译文刷新到已经打开的 hover 消息里
    local function apply(translated)
      if my_gen ~= generation or not translated or translated == "" then
        return
      end

      local m_ok, Manager = pcall(require, "noice.message.manager")
      local d_ok, Docs = pcall(require, "noice.lsp.docs")
      if not (m_ok and d_ok and Docs._messages) then
        return
      end

      -- 只要求 hover 消息对象存在。窗口不一定已经渲染出来（例如刚弹出、
      -- 无 UI 的 headless 环境），此时更新内容，等窗口出现自然是中文。
      local message = Docs._messages["hover"]
      if not message then
        return
      end

      message:clear()
      local formatted = pcall(function()
        require("noice.lsp.format").format(message, { { kind = "markdown", value = translated } }, { ft = ft })
      end)
      if not formatted then
        -- noice 的 markdown 配置尚未初始化时退化为纯文本。
        -- 注意 format 可能已经写入了一部分内容，这里先清空再追加，避免重复。
        message:clear()
        message:append(translated)
      end

      -- 重新加入消息队列，视图会按新内容重绘
      Manager.add(message)

      -- 流式接收时自动滚到底部，看到最新译文
      local win = message:win()
      if win then
        local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
        pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
      end
    end

    T.stream(text, {
      on_chunk = apply,
      on_done = apply,
    })
  end
end

return {
  {
    "folke/noice.nvim",

    init = function()
      -- noice 是 VeryLazy 加载的，加载完再打补丁
      -- lazy.nvim 的加载事件是 User LazyLoad，参数 data 是插件名
      local group = vim.api.nvim_create_augroup("CrowHoverTranslate", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "LazyLoad",
        callback = function(args)
          if args.data == "noice.nvim" then
            vim.schedule(patch_hover)
          end
        end,
      })

      -- 兜底：LSP 真正附着时再打一次补丁（此时 noice 一定已加载）
      vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function()
          vim.schedule(patch_hover)
        end,
      })

      -- 兜底：如果 noice 已经加载过（例如 :Lazy reload）
      vim.schedule(function()
        if package.loaded["noice.nvim"] then
          patch_hover()
        end
      end)
    end,
  },
}
