-- ═══════════════════════════════════════════════════════════
-- PLUGINS - blink.cmp（补全界面汉化 + 霓虹特效）
-- ═══════════════════════════════════════════════════════════
--
-- 这个文件只做三件事，不重复 LazyVim 已有的补全逻辑：
--
--   1. 汉化补全菜单里的界面文字：
--        · 补全来源名（LSP → 语言服务、Buffer → 缓冲区 …）
--        · 补全条目类型（Function → 函数、Variable → 变量 …）
--        · 加载中的 “Loading...” → “正在加载…”
--        · 弹出文档内容：调用本地 Ollama 异步翻译成中文（带缓存）
--   2. 霓虹渐变 + 圆角发光边框的视觉样式。
--   3. 重新定义 blink 相关高亮组（跟随 ColorScheme 事件，不会被
--      catppuccin 覆盖）。
--
-- 说明：LSP 返回的英文文档在“翻译完成前”会先显示原文，翻译完成后
-- 自动替换成中文，不会阻塞输入。

local KIND_ZH = {
  Text = "文本",
  Method = "方法",
  Function = "函数",
  Constructor = "构造",
  Field = "字段",
  Variable = "变量",
  Class = "类",
  Interface = "接口",
  Module = "模块",
  Property = "属性",
  Unit = "单位",
  Value = "值",
  Enum = "枚举",
  Keyword = "关键字",
  Snippet = "片段",
  Color = "颜色",
  File = "文件",
  Reference = "引用",
  Folder = "目录",
  EnumMember = "枚举值",
  Constant = "常量",
  Struct = "结构体",
  Event = "事件",
  Operator = "运算符",
  TypeParameter = "类型参数",
}

-- 补全来源的中文名（键是 blink 的 provider id）
local SOURCE_ZH = {
  lsp = "语言服务",
  path = "路径",
  snippets = "代码片段",
  buffer = "缓冲区",
  lazydev = "Lua 文档",
  cmdline = "命令行",
  omni = "补全",
}

-- ─────────────────────────────────────────────────────────────
-- 霓虹配色
-- ─────────────────────────────────────────────────────────────
local C = {
  bg = "#1e2030", -- 深色底
  fg = "#cad3f5",
  muted = "#8087a2",
  faint = "#6e738d",
  selection = "#494d64",
  aqua = "#8bd5ca", -- 霓虹青
  blue = "#8aadf4",
  mauve = "#c6a0f6", -- 霓虹紫
  pink = "#f5bde6", -- 霓虹粉
  yellow = "#eed49f",
  green = "#a6da95",
}

local HIGHLIGHTS = {
  -- 菜单
  BlinkCmpMenu = { fg = C.fg, bg = C.bg },
  BlinkCmpMenuBorder = { fg = C.aqua, bg = C.bg },
  BlinkCmpMenuSelection = { bg = C.selection, fg = C.pink, bold = true },
  BlinkCmpScrollBarGutter = { bg = C.bg },
  BlinkCmpScrollBarThumb = { bg = C.aqua },
  BlinkCmpLabel = { fg = C.fg },
  BlinkCmpLabelDetail = { fg = C.muted },
  BlinkCmpLabelDescription = { fg = C.faint },
  BlinkCmpLabelDeprecated = { fg = C.faint, strikethrough = true },
  BlinkCmpSource = { fg = C.faint, italic = true },
  BlinkCmpKind = { fg = C.blue, bold = true },

  -- 匹配字符的“霓虹渐变”：青 → 紫 → 粉 → 黄
  BlinkCmpLabelMatch1 = { fg = C.aqua, bold = true },
  BlinkCmpLabelMatch2 = { fg = C.mauve, bold = true },
  BlinkCmpLabelMatch3 = { fg = C.pink, bold = true },
  BlinkCmpLabelMatch4 = { fg = C.yellow, bold = true },

  -- 文档窗口
  BlinkCmpDoc = { fg = C.fg, bg = C.bg },
  BlinkCmpDocBorder = { fg = C.mauve, bg = C.bg },
  BlinkCmpDocSeparator = { fg = C.selection },
  BlinkCmpDocCursorLine = { bg = C.selection },

  -- 签名窗口
  BlinkCmpSignatureHelp = { fg = C.fg, bg = C.bg },
  BlinkCmpSignatureHelpBorder = { fg = C.aqua, bg = C.bg },

  -- 幽灵文本
  BlinkCmpGhostText = { fg = C.faint, italic = true },
}

local function apply_highlights()
  for group, spec in pairs(HIGHLIGHTS) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

-- ─────────────────────────────────────────────────────────────
-- 文档翻译（本地 Ollama 流式翻译）
-- ─────────────────────────────────────────────────────────────
local T = require("crow.translate")

local function doc_text(documentation)
  if type(documentation) == "string" then
    return documentation
  end
  if type(documentation) == "table" and type(documentation.value) == "string" then
    return documentation.value
  end
  return nil
end

local function with_doc_value(documentation, value)
  if type(documentation) == "table" then
    return vim.tbl_extend("force", documentation, { value = value })
  end
  return value
end

---把译文写进 blink 的文档窗口；final=true 时重新计算窗口尺寸
local function render_doc_text(opts, item, text, final)
  local ok, bufnr = pcall(function()
    return opts.window:get_buf()
  end)
  if not ok or not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local docs_ok, docs = pcall(require, "blink.cmp.completion.windows.documentation")
  if not docs_ok or docs.shown_item ~= item then
    return
  end

  require("blink.cmp.lib.window.docs").render_detail_and_documentation({
    bufnr = bufnr,
    detail = item.detail,
    documentation = with_doc_value(item.documentation, text),
    max_width = opts.window.config.max_width,
    use_treesitter_highlighting = opts.config.treesitter_highlighting,
  })

  if final and docs.update_position then
    pcall(docs.update_position)
  end

  -- 流式接收时自动滚到底部，看到最新译文
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  pcall(function()
    docs.win:set_cursor({ line_count, 0 })
  end)
end

-- 自定义文档绘制：先显示原文，流式翻译时逐段替换
local function draw_documentation(opts)
  local item = opts.item
  local original = doc_text(item.documentation)

  if not original or not T.should_translate(original) then
    return opts.default_implementation()
  end

  local cached = T.cached(original)
  if cached then
    return opts.default_implementation({
      documentation = with_doc_value(item.documentation, cached),
    })
  end

  opts.default_implementation()

  T.stream(original, {
    on_chunk = function(partial)
      if partial and partial ~= "" then
        render_doc_text(opts, item, partial, false)
      end
    end,
    on_done = function(final)
      if final and final ~= "" then
        render_doc_text(opts, item, final, true)
      end
    end,
  })
end

-- ─────────────────────────────────────────────────────────────
-- 汉化 “Loading...” 文案
-- ─────────────────────────────────────────────────────────────
local function patch_loading()
  local ok, menu = pcall(require, "blink.cmp.completion.windows.menu")
  if not ok or menu._crow_loading_patched then
    return
  end
  menu._crow_loading_patched = true

  local original = menu.open_loading
  menu.open_loading = function(context)
    original(context)

    local buf_ok, buf = pcall(function()
      return menu.win:get_buf()
    end)
    if not buf_ok or not buf or not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local changed = false
    for i, line in ipairs(lines) do
      if line:find("Loading", 1, true) then
        lines[i] = line:gsub("Loading%.%.%.", "正在加载…")
        changed = true
      end
    end
    if not changed then
      return
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  end
end

return {
  {
    "saghen/blink.cmp",

    init = function()
      -- 跟随配色方案刷新高亮，保证不被 catppuccin 覆盖
      local group = vim.api.nvim_create_augroup("CrowBlinkHighlights", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = apply_highlights,
      })

      -- blink 在 InsertEnter 才加载，等它加载完再打补丁
      vim.api.nvim_create_autocmd("InsertEnter", {
        once = true,
        callback = function()
          vim.schedule(patch_loading)
        end,
      })
    end,

    opts = function(_, opts)
      apply_highlights()

      -- ─── 汉化补全来源名 ─────────────────────────────────
      -- 注意：blink 的内置 provider 默认值不在 user opts 里，必须显式
      -- 写一份 { name = ... }，setup 时会和内置 provider 深合并。
      opts.sources = opts.sources or {}
      opts.sources.providers = opts.sources.providers or {}
      for id, name in pairs(SOURCE_ZH) do
        opts.sources.providers[id] = vim.tbl_deep_extend("force", opts.sources.providers[id] or {}, {
          name = name,
        })
      end
      -- 已存在的 provider（如 LazyVim 注入的 lazydev）也一并汉化
      for id, provider in pairs(opts.sources.providers) do
        if SOURCE_ZH[id] then
          provider.name = SOURCE_ZH[id]
        end
      end

      -- ─── <Tab> 接受 minuet 的行内代码建议 ───────────────
      -- 优先级：
      --   1. 有 minuet 幽灵文本 → 接受它
      --   2. 有 snippet 占位符 → 跳到下一个占位符
      --   3. 其他情况 → 保持原有的 Tab 缩进行为
      -- 必须在这里覆盖，否则 LazyVim 的 blink 配置函数会自己设置 <Tab>。
      opts.keymap = opts.keymap or {}
      opts.keymap["<Tab>"] = {
        function()
          local ok, vt = pcall(require, "minuet.virtualtext")
          if ok and vt.action and vt.action.is_visible() then
            vt.action.accept()
            return true
          end
          return false
        end,
        require("lazyvim.util.cmp").map({ "snippet_forward" }),
        "fallback",
      }

      -- ─── 菜单样式 ───────────────────────────────────────
      opts.completion = opts.completion or {}
      opts.completion.menu = opts.completion.menu or {}
      opts.completion.menu.border = "rounded"
      opts.completion.menu.winblend = 8
      opts.completion.menu.winhighlight =
        "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None"

      opts.completion.menu.draw = opts.completion.menu.draw or {}
      -- 前两列保持和默认一致（避免和默认列按索引深合并时错位），
      -- 追加第三列显示“类型 + 来源”。
      opts.completion.menu.draw.columns = {
        { "kind_icon" },
        { "label", "label_description", gap = 1 },
        { "kind", "source_name", gap = 1 },
      }

      opts.completion.menu.draw.components = opts.completion.menu.draw.components or {}

      -- 类型名汉化
      opts.completion.menu.draw.components.kind = {
        ellipsis = false,
        width = { max = 8 },
        text = function(ctx)
          return KIND_ZH[ctx.kind] or ctx.kind
        end,
        highlight = function(ctx)
          return ctx.kind_hl
        end,
      }

      -- 匹配字符使用青→紫→粉→黄的渐变高亮
      opts.completion.menu.draw.components.label = {
        width = { fill = true, max = 60 },
        text = function(ctx)
          return ctx.label .. ctx.label_detail
        end,
        highlight = function(ctx)
          local label = ctx.label
          local highlights = {
            {
              0,
              #label,
              group = ctx.deprecated and "BlinkCmpLabelDeprecated" or "BlinkCmpLabel",
            },
          }

          if ctx.label_detail and ctx.label_detail ~= "" then
            table.insert(highlights, {
              #label,
              #label + #ctx.label_detail,
              group = "BlinkCmpLabelDetail",
            })
          end

          if vim.list_contains(ctx.self.treesitter, ctx.source_id) and not ctx.deprecated then
            vim.list_extend(highlights, require("blink.cmp.completion.windows.render.treesitter").highlight(ctx))
          end

          local gradients = {
            "BlinkCmpLabelMatch1",
            "BlinkCmpLabelMatch2",
            "BlinkCmpLabelMatch3",
            "BlinkCmpLabelMatch4",
          }
          for i, idx in ipairs(ctx.label_matched_indices) do
            table.insert(highlights, {
              idx,
              idx + 1,
              group = gradients[(i - 1) % #gradients + 1],
              priority = 21000,
            })
          end

          return highlights
        end,
      }

      -- ─── 文档窗口样式 + 中文翻译 ────────────────────────
      opts.completion.documentation = opts.completion.documentation or {}
      opts.completion.documentation.auto_show = true
      opts.completion.documentation.auto_show_delay_ms = 200
      opts.completion.documentation.draw = draw_documentation
      opts.completion.documentation.window = opts.completion.documentation.window or {}
      opts.completion.documentation.window.border = "rounded"
      opts.completion.documentation.window.winblend = 10
      opts.completion.documentation.window.max_width = 72
      opts.completion.documentation.window.winhighlight =
        "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc,CursorLine:BlinkCmpDocCursorLine,Search:None"

      -- ─── 签名窗口样式 ───────────────────────────────────
      opts.signature = opts.signature or {}
      opts.signature.window = opts.signature.window or {}
      opts.signature.window.border = "rounded"
      opts.signature.window.winblend = 8
      opts.signature.window.winhighlight =
        "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder,Search:None"

      return opts
    end,
  },
}
