-- ═══════════════════════════════════════════════════════════
-- crow.secrets —— 本机 API Key（此文件不会被提交）
-- ═══════════════════════════════════════════════════════════
--
-- 用法：
--   1. 复制本文件为 lua/crow/secrets.lua
--   2. 填入你的 Key（键名就是 models.lua 里的 provider 名）
--   3. 重启 Neovim，或 :CrowAiStats 确认已识别
--
-- 更省事：在 Neovim 里按 <leader>oK（或 :CrowSetup），
-- 按菜单选择供应商、输入 Key、选择模型。菜单输入的 Key 保存在
-- Neovim state 目录（权限 0600），不需要编辑本文件。
--
-- Key 读取顺序（先命中先用）：
--   vim.g.crow_api_keys > 菜单保存的本机密钥库 > 环境变量 > 本文件
--
-- 也可以不写文件，直接设环境变量：
--   export OPENCODE_API_KEY="sk-..."
--   export OPENROUTER_API_KEY="sk-or-..."
--   export DASHSCOPE_API_KEY="sk-..."
--   export DEEPSEEK_API_KEY="sk-..."
--
-- 注意：secrets.lua 已在 .gitignore 中；不要把真实 Key 写进这个示例文件。

return {
  opencode = "",
  agnes = "",
  -- openrouter = "sk-or-...",
  -- dashscope = "sk-...",
  -- deepseek = "sk-...",
  -- kimi = "sk-...",
  -- zhipu = "...",
  -- siliconflow = "sk-...",
}
