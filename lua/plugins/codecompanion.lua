-- ═══════════════════════════════════════════════════════════
-- PLUGINS - codecompanion.nvim（本机 Ollama · 全离线 AI）
-- ═══════════════════════════════════════════════════════════
--
-- 双模型分工（本机 Ollama，无 API Key、不出网）：
--   对话 / 代码审查 / 后台任务 → qwen2.5-coder:3b    质量优先
--   行内改写（Inline）         → qwen2.5-coder:1.5b  速度优先
--
-- 提供的能力：
--   :CodeCompanionChat       多轮对话、带工具的 agent 式编辑
--   :CodeCompanion <prompt>  行内改写（选中代码 → 生成 → diff 接受）
--   :CodeCompanionActions    动作面板（预设 prompt / 规则 / 扩展）
--   :CodeCompanionCodeReview 结构化审查，逐 hunk 接受 / 撤销
--   :CodeCompanionCmd        让模型写 Neovim 命令行
--
-- <leader>o = Ollama / AI 分组的分工：
--   oa  AI 解释当前函数 / 选区  ← lua/crow/ai.lua（轻量单轮）
--   or  AI 审查当前函数 / 选区  ← lua/crow/ai.lua
--   oq  AI 带上下文提问        ← lua/crow/ai.lua
--   oi  AI 状态                ← lua/crow/ai.lua
--   os  会话自动保存            ← 已被占用，不可再用
--   oc  AI 对话（Chat）         ← 本文件 init
--   ov  AI 动作面板             ← 本文件 init
--   oe  AI 改写选区（Inline）   ← 本文件 init
--   oR  AI 结构化审查（diff）   ← 本文件 init
--
-- 前置条件：Ollama 服务在跑，且两个模型都已 pull：
--   ollama serve
--   ollama pull qwen2.5-coder:3b
--   ollama pull qwen2.5-coder:1.5b
-- 文档：https://codecompanion.olimorris.dev

local CHAT_MODEL = "qwen2.5-coder:3b" -- 对话 / 审查 / 后台
local INLINE_MODEL = "qwen2.5-coder:1.5b" -- 行内改写
local NUM_CTX = 8192 -- Ollama 侧上下文窗口（tokens）

-- ─── 功能开关 ───────────────────────────────────────────────
-- scripts/features.sh off codecompanion 时整份 spec 退化为 disabled，
-- 插件不会加载、命令不会创建、下面的快捷键也不会注册。
if not require("crow.features").on("codecompanion") then
  return {
    { "olimorris/codecompanion.nvim", enabled = false },
  }
end

return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },

    -- ─── 懒加载入口 ───────────────────────────────────────
    -- v20 的用户命令是在 CodeCompanion.setup() 里创建的，
    -- 插件没加载之前一条命令都没有。lazy 的 cmd 壳负责「先占位、
    -- 首次调用时加载插件再重放」，所以这里必须列全，
    -- 否则第一条命令会报 E492: Not an editor command。
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCodeReview",
      "CodeCompanionCmd",
      "CodeCompanionCLI",
    },

    -- ─── 快捷键 + 分组（init：启动阶段就注册，不等插件加载）──
    -- 放 init 而不是 config，是因为 config 只在插件首次加载时才跑，
    -- 在那之前按这些键什么也不会发生。
    --
    -- which-key 不需要为每条映射再写 wk.add：它的 Mode:update()
    -- 会直接读 nvim_get_keymap()，只要 vim.keymap.set 带了 desc
    -- 就会显示在弹窗里。wk.add 在这里只用来声明分组名。
    init = function()
      -- <leader>o 的分组名统一在 lua/crow/init.lua 里声明（那里带重试，
      -- 不依赖本插件是否开启），这里只管自己的按键。
      --
      -- 这些键用 vim.keymap.set + desc 就够了：which-key 的
      -- Mode:update() 会直接读 nvim_get_keymap()，不需要再写 wk.add。
      local map = vim.keymap.set

      -- 注意：oa / or / oq / oi 归 crow.ai，这里绝对不要重复绑定。
      map({ "n", "v" }, "<leader>oc", "<cmd>CodeCompanionChat Toggle<cr>", {
        desc = "AI 对话",
        silent = true,
      })
      map({ "n", "v" }, "<leader>ov", "<cmd>CodeCompanionActions<cr>", {
        desc = "AI 动作面板",
        silent = true,
      })
      map({ "n", "v" }, "<leader>oe", "<cmd>CodeCompanion<cr>", {
        desc = "AI 改写选区",
        silent = true,
      })
      map("n", "<leader>oR", "<cmd>CodeCompanionCodeReview<cr>", {
        desc = "AI 结构化审查",
        silent = true,
      })
    end,

    opts = {
      -- ─── 适配器：本机 Ollama ─────────────────────────────
      adapters = {
        http = {
          -- 用「函数」覆盖内置 ollama 适配器：既保留插件自带的全部字段
          -- （handlers、schema 校验、/api/tags 拉模型列表），
          -- 只改掉我们关心的几个默认值。纯字符串覆盖做不到这点。
          ollama = function()
            return require("codecompanion.adapters").extend("ollama", {
              schema = {
                model = { default = CHAT_MODEL },
                num_ctx = { default = NUM_CTX },
                keep_alive = { default = "30m" }, -- 请求之间保持模型驻留，省掉重复加载
                -- 注意：ollama 适配器的 schema 里没有 `options` 这个键，
                -- 温度的键就叫 temperature（mapping = parameters.options）。
                -- 旧配置写的 options.default.temperature 没有 mapping，
                -- 会被 map_schema_to_params 跳过，实际一直用 Ollama 默认 0.8。
                temperature = { default = 0.2 }, -- 代码任务要的是稳定，不是发散
              },
            })
          end,
        },
      },

      -- ─── 各类交互分别用哪个模型 ──────────────────────────
      interactions = {
        chat = {
          adapter = { name = "ollama", model = CHAT_MODEL },
          roles = {
            -- 中文 UI：把消息头从 "Me" / "CodeCompanion (Ollama)" 换成中文
            llm = function(adapter)
              return "AI · " .. (adapter.formatted_name or adapter.name or "LLM")
            end,
            user = "我",
          },
          opts = {
            completion_provider = "blink", -- 聊天输入框的补全 / 斜杠命令
            context_management = {
              -- trigger 是「占满上下文的比例」，不是 token 数。
              -- 旧配置写成 6000 / 8000，会被当成 600000% / 800000%，
              -- 等于永远不触发，压缩逻辑形同虚设。
              editing = { trigger = 0.65 }, -- 65% 满时裁剪工具输出，保留最近 3 轮
              compaction = {
                trigger = 0.85, -- 85% 满时压缩历史
                -- 默认 10000 > num_ctx(8192)，永远攒不够，压缩同样不会触发。
                -- 对 8k 窗口，1.5k 是能真正生效又不会误触发的门槛。
                min_token_savings = 1500,
              },
            },
          },
        },

        inline = {
          adapter = { name = "ollama", model = INLINE_MODEL },
          opts = {
            -- 必须 < num_ctx，否则行内请求带的上下文会被 Ollama 直接拒。
            -- 旧配置写 16000，比 8192 的窗口还大。
            max_context_tokens = 6000,
          },
        },

        -- 内置默认全部指向 copilot，离线环境一用就报错，统一改成本机模型。
        cmd = { adapter = { name = "ollama", model = INLINE_MODEL } },
        background = { adapter = { name = "ollama", model = CHAT_MODEL } },
      },

      -- ─── 显示：贴合本配置的霓虹圆角风格 ──────────────────
      display = {
        -- 与本配置其他选择器保持一致（venv-selector 等都明确选了 snacks，
        -- 不用自动探测出来的 telescope）。
        action_palette = { provider = "snacks" },
        chat = {
          -- 默认 single 直角，改成 rounded 与 blink / noice / 浮窗统一
          window = { border = "rounded" },
          floating_window = { border = "rounded" }, -- diff、预览浮窗继承这里
          intro_message = "CodeCompanion 已就绪（本机 3B 模型）。按 ? 查看选项",
        },
        input = {
          window = { border = "rounded" },
        },
      },

      -- ─── 全局选项 ───────────────────────────────────────
      opts = {
        -- 会拼进系统提示："All non-code text responses must be written in
        -- the %s language."，所以模型的非代码回复会走中文。
        language = "Simplified Chinese",
      },
    },
  },
}
