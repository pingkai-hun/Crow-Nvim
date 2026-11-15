#!/usr/bin/env bash
# ============================================================================
# CrowNvim 功能开关
# ============================================================================
# 管理 lua/crow/features_user.lua（该文件已被 .gitignore 忽略，不会随仓库分发）。
# 改动只影响本机，且需要重启 Neovim 才生效。
#
# 用法：
#   scripts/features.sh                     交互菜单
#   scripts/features.sh status              查看状态
#   scripts/features.sh list                列出可用开关
#   scripts/features.sh on   <名字...>      开启
#   scripts/features.sh off  <名字...>      关闭
#   scripts/features.sh toggle <名字>       切换
#   scripts/features.sh all-on | all-off    全开 / 全关
#   scripts/features.sh reset               恢复出厂默认
#
# 依赖：bash 4+，无其它外部依赖。

set -euo pipefail

# ─── 定位配置目录 ────────────────────────────────────────────
# 优先用脚本自身的位置推导，避免写死 ~ 或用户名；
# 也允许用 CROW_NVIM_CONFIG 覆盖。
script_dir() {
  local src="${BASH_SOURCE[0]}"
  while [ -L "$src" ]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

if [ -n "${CROW_NVIM_CONFIG:-}" ]; then
  CONFIG_DIR="$CROW_NVIM_CONFIG"
else
  CONFIG_DIR="$(dirname "$(script_dir)")"
fi

FEATURES_LUA="$CONFIG_DIR/lua/crow/features.lua"
USER_FILE="$CONFIG_DIR/lua/crow/features_user.lua"

if [ ! -f "$FEATURES_LUA" ]; then
  echo "错误：在 $CONFIG_DIR 下找不到 lua/crow/features.lua" >&2
  echo "       这不是 CrowNvim 配置目录？可用 CROW_NVIM_CONFIG 指定。" >&2
  exit 1
fi

# ─── 开关清单 ────────────────────────────────────────────────
# 格式： key|出厂默认|名称|说明
# 必须与 lua/crow/features.lua 的 M.defaults 保持一致（脚本启动时会校验）。
CATALOG=(
  "minuet|true|行内幽灵补全|minuet-ai.nvim + qwen2.5-coder:1.5b，插入模式自动出建议"
  "codecompanion|true|对话 / 内联改写|:CodeCompanionChat 等命令，<leader>oc/ov/oe/oR"
  "crow_ai|true|解释 / 审查 / 提问|:CrowExplain 等命令，<leader>oa/or/oq/oi"
  "translate|true|文档翻译|悬停文档与补全文档的中文流式翻译（依赖 Ollama）"
  "copilot_chat|true|CopilotChat|GitHub Copilot 对话（需先 :Copilot auth）"
)

# ─── 输出样式 ────────────────────────────────────────────────
use_color=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  use_color=1
fi
c() { # c <code> <text>
  if [ "$use_color" -eq 1 ]; then
    printf '\033[%sm%s\033[0m' "$1" "$2"
  else
    printf '%s' "$2"
  fi
}
bold() { c '1' "$1"; }
dim() { c '2' "$1"; }
green() { c '32' "$1"; }
red() { c '31' "$1"; }
cyan() { c '36' "$1"; }

die() {
  printf '%s\n' "$(red "错误")：$1" >&2
  exit 1
}

# ─── 与 features.lua 校验 ────────────────────────────────────
check_catalog() {
  local entry key
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ <<<"$entry"
    if ! grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$FEATURES_LUA"; then
      die "开关 \"$key\" 在 $FEATURES_LUA 里找不到，脚本清单与 Lua 默认值不同步"
    fi
  done
}

# ─── 状态 ────────────────────────────────────────────────────
declare -A DEFAULT STATE

load_state() {
  local entry key def
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key def _ <<<"$entry"
    if [ "$def" = "true" ]; then
      DEFAULT[$key]=1
    else
      DEFAULT[$key]=0
    fi
    STATE[$key]=${DEFAULT[$key]}
  done

  # 只读取「与默认值不同」的覆盖项
  if [ -f "$USER_FILE" ]; then
    local line k v
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*(true|false) ]]; then
        k="${BASH_REMATCH[1]}"
        v="${BASH_REMATCH[2]}"
        if [ -n "${DEFAULT[$k]+x}" ]; then
          if [ "$v" = "true" ]; then STATE[$k]=1; else STATE[$k]=0; fi
        fi
      fi
    done <"$USER_FILE"
  fi
}

save_state() { # 把与默认值不同的项写回；全一致则删掉文件
  local entry key
  local -a diff=()
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ <<<"$entry"
    if [ "${STATE[$key]}" != "${DEFAULT[$key]}" ]; then
      if [ "${STATE[$key]}" = "1" ]; then
        diff+=("$key = true")
      else
        diff+=("$key = false")
      fi
    fi
  done

  if [ ${#diff[@]} -eq 0 ]; then
    rm -f "$USER_FILE"
    return
  fi

  mkdir -p "$(dirname "$USER_FILE")"
  local tmp
  tmp="$(mktemp "$USER_FILE.XXXXXX")"
  {
    echo "-- 由 scripts/features.sh 生成，请勿随仓库提交。"
    echo "-- 只记录与出厂默认值不同的项；格式：  <开关名> = true|false"
    echo "-- 可以手改，改完重启 Neovim 生效。"
    echo "return {"
    local line
    for line in "${diff[@]}"; do
      printf '  %s,\n' "$line"
    done
    echo "}"
  } >"$tmp"
  mv -f "$tmp" "$USER_FILE"
}

# ─── 参数规范化 ──────────────────────────────────────────────
normalize() { # crow-ai → crow_ai
  printf '%s' "${1//-/_}"
}

known_key() {
  [ -n "${DEFAULT[$1]+x}" ]
}

label_of() {
  local entry key
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ label _ <<<"$entry"
    if [ "$key" = "$1" ]; then
      printf '%s' "$label"
      return
    fi
  done
}

desc_of() {
  local entry key
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ _ desc <<<"$entry"
    if [ "$key" = "$1" ]; then
      printf '%s' "$desc"
      return
    fi
  done
}

state_word() { # 1 → 开
  if [ "$1" = "1" ]; then
    printf '开'
  else
    printf '关'
  fi
}

restart_hint() {
  printf '%s\n' "$(dim "改动需要重启 Neovim 才生效。")"
}

# ─── 子命令 ──────────────────────────────────────────────────
cmd_status() {
  printf '%s\n' "$(bold "功能开关状态")"
  printf '%s  %s\n' "$(dim "配置目录")" "$CONFIG_DIR"
  printf '\n'
  local entry key
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ label _ <<<"$entry"
    if [ "${STATE[$key]}" = "1" ]; then
      printf '  %s  %-14s %s\n' "$(green "[开]")" "$key" "$label"
    else
      printf '  %s  %-14s %s\n' "$(red "[关]")" "$key" "$label"
    fi
  done
  printf '\n'
  restart_hint
}

cmd_list() {
  local entry key
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ label desc <<<"$entry"
    printf '  %-14s %s\n' "$(cyan "$key")" "$label"
    printf '  %-14s %s\n' "" "$(dim "$desc")"
  done
}

set_feature() { # set_feature <key> <0|1>
  local key="$1" val="$2"
  if ! known_key "$key"; then
    die "未知开关 \"$1\"。可用：$(list_keys)"
  fi
  if [ "${STATE[$key]}" = "$val" ]; then
    printf '%s  %s 已经是「%s」\n' "$(dim "-")" "$key" "$(state_word "$val")"
  else
    STATE[$key]="$val"
    save_state
    local mark
    if [ "$val" = "1" ]; then mark="$(green "开")"; else mark="$(red "关")"; fi
    printf '%s  %-14s → %s\n' "$(dim "+")" "$key" "$mark"
  fi
}

list_keys() {
  local entry key
  local -a out=()
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ <<<"$entry"
    out+=("$key")
  done
  printf '%s' "${out[*]}"
}

cmd_set() { # on|off <keys...>
  local mode="$1"
  shift
  [ $# -gt 0 ] || die "请给出至少一个开关名。可用：$(list_keys)"
  local k
  for k in "$@"; do
    k="$(normalize "$k")"
    if [ "$mode" = "on" ]; then
      set_feature "$k" 1
    else
      set_feature "$k" 0
    fi
  done
  restart_hint
}

cmd_toggle() {
  [ $# -ge 1 ] || die "请给出要切换的开关名。可用：$(list_keys)"
  local k
  for k in "$@"; do
    k="$(normalize "$k")"
    if ! known_key "$k"; then
      die "未知开关 \"$k\"。可用：$(list_keys)"
    fi
    if [ "${STATE[$k]}" = "1" ]; then
      set_feature "$k" 0
    else
      set_feature "$k" 1
    fi
  done
  restart_hint
}

cmd_all() { # all-on | all-off | reset
  local mode="$1"
  local entry key
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r key _ <<<"$entry"
    case "$mode" in
      all-on) STATE[$key]=1 ;;
      all-off) STATE[$key]=0 ;;
      reset) STATE[$key]=${DEFAULT[$key]} ;;
    esac
  done
  save_state
  case "$mode" in
    all-on) printf '%s\n' "$(green "已开启全部功能")" ;;
    all-off) printf '%s\n' "$(red "已关闭全部功能")" ;;
    reset) printf '%s\n' "$(cyan "已恢复出厂默认")" ;;
  esac
  restart_hint
}

cmd_menu() {
  local choice
  while true; do
    printf '\n%s  %s\n' "$(bold "功能开关")" "$(dim "（输入序号切换，a 全开，z 全关，r 恢复默认，q 退出）")"
    printf '%s\n' "$(dim "配置目录：$CONFIG_DIR")"
    printf '\n'
    local i=1 entry key
    for entry in "${CATALOG[@]}"; do
      IFS='|' read -r key _ label _ <<<"$entry"
      if [ "${STATE[$key]}" = "1" ]; then
        printf '  %s. %s %-16s %s\n' "$(cyan "$i")" "$(green "[开]")" "$key" "$label"
      else
        printf '  %s. %s %-16s %s\n' "$(cyan "$i")" "$(red "[关]")" "$key" "$label"
      fi
      i=$((i + 1))
    done
    printf '\n  %s\n' "$(dim "选择")"

    if ! read -r choice; then
      printf '\n'
      return 0
    fi

    case "$choice" in
      q | Q | quit | exit) break ;;
      a | A) cmd_all all-on ;;
      z | Z) cmd_all all-off ;;
      r | R) cmd_all reset ;;
      '' | *[!0-9]*)
        printf '%s\n' "$(dim "请输入序号，或 a / z / r / q")"
        ;;
      *)
        if [ "$choice" -ge 1 ] && [ "$choice" -le ${#CATALOG[@]} ]; then
          local idx key
          idx=$((choice - 1))
          IFS='|' read -r key _ <<<"${CATALOG[$idx]}"
          cmd_toggle "$key"
        else
          printf '%s\n' "$(dim "序号超出范围")"
        fi
        ;;
    esac
  done
  printf '\n'
}

usage() {
  cat <<EOF
$(bold "CrowNvim 功能开关")

$(bold "用法")
  scripts/features.sh                     交互菜单
  scripts/features.sh status              查看状态
  scripts/features.sh list                列出可用开关
  scripts/features.sh on   <名字...>      开启
  scripts/features.sh off  <名字...>      关闭
  scripts/features.sh toggle <名字...>    切换
  scripts/features.sh all-on              全部开启
  scripts/features.sh all-off             全部关闭
  scripts/features.sh reset               恢复出厂默认
  scripts/features.sh -h | --help         本说明

$(bold "说明")
  · 开关写入 lua/crow/features_user.lua，该文件已被 .gitignore 忽略。
  · 改动只影响本机，不影响仓库里其它人的配置。
  · 修改后需要重启 Neovim 才生效。
  · 可用 CROW_NVIM_CONFIG 指定配置目录。

$(bold "可用开关")
$(list_keys)
EOF
}

# ─── 入口 ────────────────────────────────────────────────────
check_catalog
load_state

case "${1:-}" in
  -h | --help | help)
    usage
    ;;
  status | st)
    cmd_status
    ;;
  list | ls)
    cmd_list
    ;;
  on)
    shift
    cmd_set on "$@"
    ;;
  off)
    shift
    cmd_set off "$@"
    ;;
  toggle | t)
    shift
    cmd_toggle "$@"
    ;;
  all-on)
    cmd_all all-on
    ;;
  all-off)
    cmd_all all-off
    ;;
  reset)
    cmd_all reset
    ;;
  "")
    cmd_menu
    ;;
  *)
    die "未知子命令 \"$1\"。加 -h 查看用法。"
    ;;
esac
