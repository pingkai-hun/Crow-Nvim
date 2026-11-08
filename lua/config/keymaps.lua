-- ═══════════════════════════════════════════════════════════
-- Easy-Nvim 快捷键（移植自 ~/.vimrc「快捷键」+ coc 区块）
-- ═══════════════════════════════════════════════════════════
-- Neovim 侧用原生 LSP / snacks picker / dap 替代 coc / fzf / vimspector，
-- 键位保持和 Vim 版一致，方便两边共用肌肉记忆。

local map = vim.keymap.set
local crow = require("crow")

local function snacks()
  return require("snacks")
end

-- ─── 基础操作 ────────────────────────────────────────────
map("n", "<leader>w", "<cmd>w<cr>", { desc = "保存" })
map("n", "<leader>wq", "<cmd>wq<cr>", { desc = "保存并退出" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "退出" })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "清除搜索高亮" })
map("n", "<leader>cd", function()
  vim.cmd.lcd(vim.fn.fnameescape(vim.fn.expand("%:p:h")))
end, { desc = "cwd 切到当前文件目录" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "关闭当前 buffer" })
map("n", "<leader>sr", function()
  local file = vim.fn.stdpath("config") .. "/init.lua"
  vim.cmd.source(file)
  crow.notify("配置已重新载入")
end, { desc = "重新载入配置" })
map("n", "<leader>sc", function()
  vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
end, { desc = "编辑 Neovim 配置" })
map("n", "<leader>sC", "<cmd>Lazy<cr>", { desc = "插件管理 (Lazy)" })
map("n", "<leader>D", "<cmd>Doctor<cr>", { desc = "体检：LSP / 工具 / 主题" })

-- ─── 文件树 ──────────────────────────────────────────────
map("n", "<leader>n", function()
  snacks().explorer()
end, { desc = "文件树" })
map("n", "<leader>nf", function()
  snacks().picker.files({ cwd = vim.fn.expand("%:p:h") })
end, { desc = "在当前文件目录查找" })

-- ─── 搜索（snacks picker 替代 fzf.vim）────────────────────
map("n", "<leader>p", function()
  snacks().picker.files()
end, { desc = "查找文件" })
map("n", "<leader>P", function()
  crow.find_at_root("files")
end, { desc = "在项目根查找文件" })
map("n", "<leader>b", function()
  snacks().picker.buffers()
end, { desc = "切换 buffer" })
map("n", "<leader>/", function()
  snacks().picker.grep()
end, { desc = "全局搜索" })
map("n", "<leader>R", function()
  crow.find_at_root("grep")
end, { desc = "在项目根全局搜索" })
map("n", "<leader>*", function()
  snacks().picker.grep_word()
end, { desc = "搜索光标下单词" })

-- ─── 注释 ────────────────────────────────────────────────
map("n", "<leader>c", "gcc", { remap = true, desc = "注释当前行" })
map("x", "<leader>c", "gc", { remap = true, desc = "注释选区" })

-- ─── 窗口导航 ────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "左窗口" })
map("n", "<C-j>", "<C-w>j", { desc = "下窗口" })
map("n", "<C-k>", "<C-w>k", { desc = "上窗口" })
map("n", "<C-l>", "<C-w>l", { desc = "右窗口" })

-- ─── 调试（nvim-dap 替代 vimspector）─────────────────────
local function dap()
  return require("dap")
end
map("n", "<F5>", function()
  dap().continue()
end, { desc = "继续 / 启动调试" })
map("n", "<F9>", function()
  dap().toggle_breakpoint()
end, { desc = "切换断点" })
map("n", "<F10>", function()
  dap().step_over()
end, { desc = "单步跳过" })
map("n", "<F11>", function()
  dap().step_into()
end, { desc = "单步进入" })
map("n", "<F12>", function()
  dap().step_out()
end, { desc = "单步跳出" })
map("n", "<leader>dr", function()
  dap().restart()
end, { desc = "重启调试" })
map("n", "<leader>dq", function()
  dap().terminate()
end, { desc = "停止调试" })
map("n", "<leader>dR", function()
  dap().repl.toggle()
end, { desc = "调试 REPL" })

-- ─── 终端 ────────────────────────────────────────────────
map("n", "<F7>", crow.toggle_terminal, { desc = "浮动终端" })
map("t", "<F7>", function()
  vim.cmd.stopinsert()
  crow.toggle_terminal()
end, { desc = "关闭浮动终端" })
map("n", "<leader>tt", crow.toggle_terminal, { desc = "浮动终端" })
map("n", "<leader>py", function()
  crow.terminal({ "python3" })
end, { desc = "Python 交互环境" })

local function run_python()
  vim.cmd.write()
  crow.terminal({ "python3", vim.api.nvim_buf_get_name(0) })
end
map("n", "<F6>", run_python, { desc = "运行当前 Python 脚本" })
map("i", "<F6>", function()
  vim.cmd.stopinsert()
  run_python()
end, { desc = "运行当前 Python 脚本" })

-- ─── 代码大纲 ────────────────────────────────────────────
local function symbols()
  require("trouble").toggle({ mode = "symbols" })
end
map("n", "<F8>", symbols, { desc = "代码大纲" })
map("n", "<leader>wa", symbols, { desc = "代码大纲" })
map("n", "<leader>wt", function()
  snacks().picker.lsp_symbols()
end, { desc = "文档符号列表" })

-- ─── 会话（替代 vim-obsession）────────────────────────────
map("n", "<leader>os", crow.session_obsess, { desc = "开启会话自动保存" })
map("n", "<leader>od", crow.session_stop, { desc = "停止并删除会话" })
map("n", "<leader>oS", function()
  crow.session_save(crow.session_file())
end, { desc = "保存会话" })
map("n", "<leader>oN", function()
  crow.session_load(crow.session_file())
end, { desc = "载入会话" })

-- ─── LSP（替代 coc 的 gd/gr/K 等）────────────────────────
map("n", "gd", vim.lsp.buf.definition, { desc = "跳转定义" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "跳转声明" })
map("n", "gy", vim.lsp.buf.type_definition, { desc = "跳转类型定义" })
map("n", "gi", vim.lsp.buf.implementation, { desc = "跳转实现" })
map("n", "gr", vim.lsp.buf.references, { desc = "查找引用" })
map("n", "K", vim.lsp.buf.hover, { desc = "悬浮文档" })
map("n", "gK", vim.lsp.buf.signature_help, { desc = "签名帮助" })
map("n", "gl", vim.diagnostic.open_float, { desc = "诊断详情" })

local function diag_jump(count)
  return function()
    if vim.diagnostic.jump then
      vim.diagnostic.jump({ count = count })
    elseif count < 0 then
      vim.diagnostic.goto_prev()
    else
      vim.diagnostic.goto_next()
    end
  end
end
map("n", "[d", diag_jump(-1), { desc = "上一个诊断" })
map("n", "]d", diag_jump(1), { desc = "下一个诊断" })

map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "重命名符号" })
map("n", "<leader>ac", vim.lsp.buf.code_action, { desc = "代码动作" })

-- ─── 行移动（沿用 Neovim 侧的顺手操作）───────────────────
map("n", "<A-j>", ":m .+1<cr>==", { desc = "下移当前行" })
map("n", "<A-k>", ":m .-2<cr>==", { desc = "上移当前行" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "下移选区" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "上移选区" })

-- ─── 红队 / 渗透测试常用代码模板 ────────────────────────
-- 对应 ~/.vimrc 末尾「红队工具 Python 快速开发补丁」的 <leader>ip / <leader>req：
-- 在光标下方插入模板，光标停在第一个待填的位置，直接开始打字。
-- 只在 python buffer 里生效，避免在别的语言里霸占 <leader>ip。

--- 在下一行插入一组行，并把光标停在占位文字处。
---@param lines string[]
---@param placeholder? { line: integer, text: string } line 从 1 开始，相对插入的第一行
local function insert_template(lines, placeholder)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
  if placeholder then
    local lnum = row + placeholder.line
    local text = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
    local start = text:find(placeholder.text, 1, true) or 1
    vim.api.nvim_win_set_cursor(0, { lnum, start - 1 })
  else
    vim.api.nvim_win_set_cursor(0, { row + #lines, 0 })
  end
end

local templates = {
  -- IP 解析：填好 domain 后 <F6> 直接跑
  ip = function()
    insert_template({
      "import socket",
      "",
      "target = \"domain\"",
      "ip = socket.gethostbyname(target)",
      "print(f\"[+] {ip}\")",
    }, { line = 3, text = '"domain"' })
  end,
  -- HTTP 探测：填好 url 后 <F6> 运行看状态码 / 长度
  req = function()
    insert_template({
      "import requests",
      "",
      "url = \"http://\"",
      "headers = {\"User-Agent\": \"Mozilla/5.0\"}",
      "try:",
      "    r = requests.get(url, headers=headers, timeout=5, verify=False)",
      "    print(f\"[{r.status_code}] {len(r.text)} bytes\")",
      "except requests.RequestException as e:",
      "    print(f\"[-] {e}\")",
    }, { line = 3, text = "http://" })
  end,
  -- 端口探测（Vim 版没有，顺手补上）
  port = function()
    insert_template({
      "import socket",
      "from concurrent.futures import ThreadPoolExecutor",
      "",
      "host = \"127.0.0.1\"",
      "ports = [21, 22, 80, 443, 3306, 6379, 8080]",
      "",
      "def probe(port):",
      "    s = socket.socket()",
      "    s.settimeout(0.6)",
      "    try:",
      "        if s.connect_ex((host, port)) == 0:",
      "            print(f\"[+] {port} open\")",
      "    finally:",
      "        s.close()",
      "",
      "with ThreadPoolExecutor(max_workers=50) as ex:",
      "    ex.map(probe, ports)",
    }, { line = 4, text = "127.0.0.1" })
  end,
}

local template_desc = {
  ip = "插入：IP 解析模板",
  req = "插入：HTTP 探测模板",
  port = "插入：端口扫描模板",
}

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("EasyRedTeamTemplates", { clear = true }),
  pattern = "python",
  callback = function(ev)
    for name, fn in pairs(templates) do
      vim.keymap.set("n", "<leader>" .. name, fn, {
        buffer = ev.buf,
        desc = template_desc[name],
      })
    end
  end,
  desc = "Python：红队模板快捷键（buffer 级）",
})
