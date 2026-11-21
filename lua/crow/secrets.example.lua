-- ═══════════════════════════════════════════════════════════
-- crow.secrets —— 本机 API Key（此文件不会被提交）
-- ═══════════════════════════════════════════════════════════
--
-- 用法：
--   1. 复制本文件为 lua/crow/secrets.lua
--   2. 填入你的 Key（键名就是 models.lua 里的 provider 名）
--   3. 重启 Neovim，或 :CrowAiStats 确认已识别
--
-- 也可以不写文件，直接设环境变量（优先级：环境变量 > 本文件）：
--   export OPENCODE_API_KEY="sk-..."
--   export OPENROUTER_API_KEY="sk-or-..."
--   export DASHSCOPE_API_KEY="sk-..."
--   export DEEPSEEK_API_KEY="sk-..."
--
-- 注意：secrets.lua 已在 .gitignore 中；不要把真实 Key 写进这个示例文件。

return {
  opencode = "",
  -- openrouter = "sk-or-...",
  -- dashscope = "sk-...",
  -- deepseek = "sk-...",
  -- kimi = "sk-...",
  -- zhipu = "...",
  -- siliconflow = "sk-...",
}
