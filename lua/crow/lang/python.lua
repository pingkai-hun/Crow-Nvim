-- ═══════════════════════════════════════════════════════════
-- crow.lang.python —— Python 工具链自动探测
-- ═══════════════════════════════════════════════════════════
--
-- 目标：不在配置里写死 pyright / ruff / pytest，而是根据当前项目和
-- 本机已安装的可执行文件，自动选择一套可用且不重复的方案。
--
-- 选择规则（先命中先用）：
--   LSP         basedpyright-langserver > pyright-langserver
--   格式化      ruff > black + isort > black
--   测试        pytest > unittest
--   包管理      uv > poetry > pipenv > pixi > conda > pip
--   解释器      $VIRTUAL_ENV / $CONDA_PREFIX > venv-selector > 项目 .venv
--
-- 这些函数只做轻量文件 / 可执行文件检查，不执行 Python，不会拖慢启动。
-- 项目信息可用 :CrowPython 查看。

local M = {}

local uv = vim.uv or vim.loop

local root_markers = {
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "requirements-dev.txt",
  "Pipfile",
  "poetry.lock",
  "uv.lock",
  "pixi.toml",
  "environment.yml",
  "tox.ini",
  ".python-version",
  ".git",
}

local function executable(name)
  return vim.fn.executable(name) == 1
end

local function exists(path)
  return path and path ~= "" and uv.fs_stat(path) ~= nil
end

local function first_existing(paths)
  for _, path in ipairs(paths) do
    if exists(path) then
      return path
    end
  end
end

local function file_contains(path, needle)
  if vim.fn.filereadable(path) == 0 then
    return false
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then
    return false
  end
  local text = table.concat(lines, "\n"):lower()
  return text:find(needle:lower(), 1, true) ~= nil
end

---当前 buffer 所属项目根目录
---@param bufnr? integer
---@return string
function M.root(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    local root = vim.fs.root(bufnr, root_markers)
    if root then
      return root
    end
    return vim.fs.dirname(name)
  end
  return vim.fn.getcwd()
end

local function venv_python(dir)
  return first_existing({
    vim.fs.joinpath(dir, "bin", "python"),
    vim.fs.joinpath(dir, "bin", "python3"),
    vim.fs.joinpath(dir, "Scripts", "python.exe"),
  })
end

---按优先级找项目解释器
---@param root? string
---@param bufnr? integer
---@return string|nil
function M.interpreter(root, bufnr)
  root = root or M.root(bufnr)

  for _, dir in ipairs({ vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX }) do
    if dir and dir ~= "" then
      local python = venv_python(dir)
      if python then
        return python
      end
    end
  end

  -- venv-selector 当前选择优先于目录探测（多环境项目里可能是别的 venv）
  local ok, vs = pcall(require, "venv-selector")
  if ok then
    local ok2, selected = pcall(vs.python)
    if ok2 and exists(selected) then
      return selected
    end
  end

  for _, name in ipairs({ ".venv", "venv", "env", ".env" }) do
    local python = venv_python(vim.fs.joinpath(root, name))
    if python then
      return python
    end
  end
end

---项目使用的包管理器
---@param root? string
---@return string
function M.manager(root)
  root = root or M.root()
  local at = function(name)
    return vim.fs.joinpath(root, name)
  end

  if exists(at("uv.lock")) or file_contains(at("pyproject.toml"), "[tool.uv") then
    return "uv"
  end
  if exists(at("poetry.lock")) or file_contains(at("pyproject.toml"), "[tool.poetry") then
    return "poetry"
  end
  if exists(at("Pipfile.lock")) then
    return "pipenv"
  end
  if exists(at("pixi.toml")) then
    return "pixi"
  end
  if exists(at("environment.yml")) or exists(at("environment.yaml")) then
    return "conda"
  end
  return "pip"
end

local function has_pytest(root, interpreter)
  if executable("pytest") then
    return true
  end

  if interpreter then
    local bindir = vim.fs.dirname(interpreter)
    if exists(vim.fs.joinpath(bindir, "pytest")) or exists(vim.fs.joinpath(bindir, "pytest.exe")) then
      return true
    end
  end

  for _, name in ipairs({
    "pyproject.toml",
    "requirements.txt",
    "requirements-dev.txt",
    "Pipfile",
    "setup.cfg",
    "tox.ini",
  }) do
    if file_contains(vim.fs.joinpath(root, name), "pytest") then
      return true
    end
  end
  return false
end

local function has_debugpy(interpreter)
  if executable("debugpy") then
    return true
  end
  if not interpreter then
    return false
  end
  local bindir = vim.fs.dirname(interpreter)
  return exists(vim.fs.joinpath(bindir, "debugpy")) or exists(vim.fs.joinpath(bindir, "debugpy.exe"))
end

---一次性探测，返回当前项目的最优工具组合
---@param root? string
---@param bufnr? integer
---@return table
function M.detect(root, bufnr)
  root = root or M.root(bufnr)
  local interpreter = M.interpreter(root, bufnr)
  local ruff = executable("ruff")
  local black = executable("black")
  local isort = executable("isort")
  local pytest = has_pytest(root, interpreter)

  local lsp = "pyright"
  if executable("basedpyright-langserver") then
    lsp = "basedpyright"
  elseif not executable("pyright-langserver") then
    -- 两个都没装时仍保留 pyright，让 :Lazy / :Mason 或用户自己安装后生效；
    -- 若实际不可用，Neovim 会给出明确的 LSP 启动错误。
    lsp = "pyright"
  end

  return {
    root = root,
    interpreter = interpreter,
    manager = M.manager(root),
    lsp = lsp,
    ruff = ruff,
    black = black,
    isort = isort,
    pytest = pytest,
    test_runner = pytest and "pytest" or "unittest",
    debugpy = has_debugpy(interpreter),
  }
end

---conform 使用的格式化器链
---@param tools? table
---@return string[]
function M.formatters(tools)
  tools = tools or M.detect()
  if tools.ruff then
    return { "ruff_organize_imports", "ruff_format" }
  end
  if tools.black and tools.isort then
    return { "isort", "black" }
  end
  if tools.black then
    return { "black" }
  end
  return {}
end

---根据选择的 LSP 生成 lspconfig 配置
---@param tools? table
---@return table
function M.lsp_config(tools)
  tools = tools or M.detect()
  local server = tools.lsp
  local settings = {
    analysis = {
      typeCheckingMode = server == "basedpyright" and "standard" or "basic",
      indexing = false,
      autoImportCompletions = true,
      autoSearchPaths = true,
      inlayHints = {
        parameterTypes = true,
        variableTypes = server == "basedpyright",
        functionReturnTypes = false,
      },
    },
  }

  return {
    mason = false,
    before_init = function(_, config)
      config.settings = config.settings or {}

      local key = server == "basedpyright" and "basedpyright" or "python"
      config.settings[key] = config.settings[key] or {}
      local analysis = config.settings[key].analysis or {}
      config.settings[key].analysis = vim.tbl_deep_extend("force", analysis, settings.analysis)

      -- Python 解释器路径在 basedpyright / pyright 里都走 python.pythonPath。
      config.settings.python = config.settings.python or {}

      -- 已经明确配置了解释器（venv-selector 或用户设置）就不要覆盖。
      local current = config.settings.python.pythonPath
      if current and current ~= "" then
        return
      end

      local buf = vim.api.nvim_get_current_buf()
      if vim.b[buf].venv_selector_disabled then
        return
      end

      local python = M.interpreter(config.root_dir or vim.fn.getcwd(), buf)
      if python then
        config.settings.python.pythonPath = python
      end
    end,
    settings = {
      [server == "basedpyright" and "basedpyright" or "python"] = settings,
    },
  }
end

---给 :CrowPython / 排错用的可读信息
---@return string[]
function M.describe()
  local tools = M.detect()
  local function yes(value)
    return value and "✓" or "✗"
  end
  local formatter = #M.formatters(tools) > 0 and table.concat(M.formatters(tools), " → ") or "未找到"

  return {
    "Python 项目: " .. tools.root,
    "解释器:     " .. (tools.interpreter or "未找到，回退 PATH 中的 python3"),
    "包管理:     " .. tools.manager,
    "LSP:        " .. tools.lsp,
    "格式化:     " .. formatter,
    "测试:       " .. tools.test_runner,
    string.format(
      "工具:       basedpyright %s · ruff %s · black %s · pytest %s · debugpy %s",
      yes(executable("basedpyright-langserver")),
      yes(tools.ruff),
      yes(tools.black),
      yes(tools.pytest),
      yes(tools.debugpy)
    ),
  }
end

function M.setup()
  vim.api.nvim_create_user_command("CrowPython", function()
    require("crow").notify(table.concat(M.describe(), "\n"))
  end, { desc = "查看 Python 工具链自动选择结果" })
end

return M
