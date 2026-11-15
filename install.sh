#!/usr/bin/env bash
# ============================================================================
# CrowNvim 安装脚本
# ============================================================================
# 把本仓库安装到 Neovim 的配置目录，并完成首次插件安装。
#
#   ./install.sh --help
#
# 设计原则：
#   · 不写死用户名和路径，配置目录按 XDG 约定解析
#   · 幂等：已经装好时重复运行不会破坏现有配置
#   · 任何覆盖已有配置的操作都会先备份，除非显式 --no-backup
#   · --dry-run 只打印将要执行的操作，不做任何改动

set -euo pipefail

REPO_URL="https://github.com/pingkai-hun/Crow-Nvim.git"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
DRY_RUN=0
DO_BACKUP=1
DO_PLUGINS=1
ASSUME_YES=0
FORCE=0

# ─── 颜色 ────────────────────────────────────────────────────
use_color=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  use_color=1
fi
c() {
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
yellow() { c '33' "$1"; }
cyan() { c '36' "$1"; }

info() { printf '%s %s\n' "$(cyan "==>")" "$*"; }
ok() { printf '%s %s\n' "$(green "[OK]")" "$*"; }
warn() { printf '%s %s\n' "$(yellow "提示")" "$*"; }
err() { printf '%s %s\n' "$(red "错误")" "$*" >&2; }
die() {
  err "$1"
  exit 1
}

usage() {
  cat <<EOF
$(bold "CrowNvim 安装脚本")

$(bold "用法")
  ./install.sh [选项]

$(bold "选项")
  -h, --help            显示本说明
  -y, --yes             所有确认一律视为同意（用于 CI / 非交互）
      --dry-run         只打印将要执行的操作，不做任何改动
      --target <目录>   配置目录（默认：\${XDG_CONFIG_HOME:-~/.config}/nvim）
      --repo <地址>     仓库地址（默认：$REPO_URL）
      --skip-plugins    跳过首次插件安装
      --no-backup       已存在配置时不备份（与 --force 连用）
      --force           目标目录已存在且不是本仓库时，覆盖它

$(bold "做什么")
  1. 检查依赖（Neovim / Git / ripgrep 等）
  2. 备份已有的配置目录
  3. 克隆本仓库到配置目录
  4. 首次启动 Neovim，由 lazy.nvim 自动安装插件

$(bold "安装后")
  nvim                       首次启动
  :Lazy                      查看插件
  :Doctor                    环境体检
  scripts/features.sh        开关本机 AI 功能
EOF
}

# ─── 参数 ────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -y | --yes)
      ASSUME_YES=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --target)
      [ $# -ge 2 ] || die "--target 需要一个参数"
      CONFIG_DIR="$2"
      shift
      ;;
    --repo)
      [ $# -ge 2 ] || die "--repo 需要一个参数"
      REPO_URL="$2"
      shift
      ;;
    --skip-plugins)
      DO_PLUGINS=0
      ;;
    --no-backup)
      DO_BACKUP=0
      ;;
    --force)
      FORCE=1
      ;;
    *)
      die "未知参数 \"$1\"，加 -h 查看用法"
      ;;
  esac
  shift
done

# ─── 工具函数 ────────────────────────────────────────────────
# 执行一条命令；--dry-run 时只打印。
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s %s\n' "$(dim "[dry-run]")" "$*"
    return 0
  fi
  "$@"
}

# 目录 A 与目录 B 是否指向同一个位置（解析符号链接后比较）
same_dir() {
  local a b
  a="$(cd -P "$1" 2>/dev/null && pwd)" || return 1
  b="$(cd -P "$2" 2>/dev/null && pwd)" || return 1
  [ "$a" = "$b" ]
}

confirm() {
  local prompt="$1"
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    die "$prompt（非交互环境下请加 --yes 或 --force）"
  fi
  printf '%s [y/N] ' "$prompt"
  local reply
  read -r reply
  case "$reply" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

# 版本比较：ver_ge <需要的版本> <实际版本> → 实际 >= 需要
# 自己实现，避免依赖 GNU 的 sort -V（macOS 上没有）。
ver_ge() {
  local need="$1" have="$2"
  local -a n=() h=()
  IFS=. read -r -a n <<<"$need"
  IFS=. read -r -a h <<<"$have"
  local i nv hv
  for i in 0 1 2; do
    nv="${n[$i]:-0}"
    hv="${h[$i]:-0}"
    nv="${nv%%[!0-9]*}"
    hv="${hv%%[!0-9]*}"
    nv="${nv:-0}"
    hv="${hv:-0}"
    if [ "$hv" -gt "$nv" ]; then
      return 0
    fi
    if [ "$hv" -lt "$nv" ]; then
      return 1
    fi
  done
  return 0
}

# ─── 1. 依赖检查 ─────────────────────────────────────────────
check_deps() {
  printf '\n%s\n' "$(bold "1. 依赖检查")"
  local missing_required=0

  # 必需
  if command -v nvim >/dev/null 2>&1; then
    local ver full
    full="$(nvim --version | head -n1)"
    ver="$(nvim --version | head -n1 | sed -n 's/^NVIM v\([0-9.]*\).*/\1/p')"
    if [ -n "$ver" ] && ver_ge "0.10" "$ver"; then
      ok "Neovim  $ver"
      if ! ver_ge "0.11" "$ver"; then
        warn "低于推荐版本 0.11（LazyVim 新特性可能不可用），当前 $ver"
      fi
    else
      err "Neovim 版本过低：$full（需要 ≥ 0.10）"
      missing_required=1
    fi
  else
    err "未找到 nvim。安装方法见 docs/INSTALL.md 第 2 节"
    missing_required=1
  fi

  if command -v git >/dev/null 2>&1; then
    ok "Git     $(git --version | awk '{print $3}')"
  else
    err "未找到 git（插件管理必需）"
    missing_required=1
  fi

  if command -v rg >/dev/null 2>&1; then
    ok "ripgrep $(rg --version | head -n1 | awk '{print $2}')"
  else
    err "未找到 ripgrep（全局搜索必需，包名通常是 ripgrep）"
    missing_required=1
  fi

  # 推荐
  local opt name
  for opt in "fd:文件查找加速" "curl:Dashboard 探活 / AI 请求" "lazygit:<leader>gg" "unzip:Mason 解压"; do
    name="${opt%%:*}"
    if command -v "$name" >/dev/null 2>&1; then
      ok "$name"
    else
      warn "未找到 $name —— ${opt#*:}（可选，见 docs/INSTALL.md 第 3 节）"
    fi
  done

  # AI 可选
  if command -v ollama >/dev/null 2>&1; then
    ok "ollama  已安装"
    if curl -sf --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      ok "ollama  服务在运行"
    else
      warn "ollama 已安装但服务未运行：执行 ollama serve"
    fi
  else
    warn "未找到 ollama —— 本机 AI 功能（补全 / 对话 / 翻译）不可用，可稍后单独安装"
  fi

  [ "$missing_required" -eq 0 ] || die "缺少必需依赖，先装好再运行本脚本"
}

# ─── 2. 定位脚本自身所在的仓库 ──────────────────────────────
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
SOURCE_DIR="$(script_dir)"

# ─── 3. 目标目录 ────────────────────────────────────────────
prepare_target() {
  printf '\n%s\n' "$(bold "2. 配置目录")"
  info "目标：$CONFIG_DIR"

  # 已经在配置目录里运行（比如 cd ~/.config/nvim && ./install.sh）
  if same_dir "$SOURCE_DIR" "$CONFIG_DIR"; then
    ok "脚本就在配置目录里，跳过克隆"
    return
  fi

  if [ ! -e "$CONFIG_DIR" ]; then
    info "目录不存在，将克隆 $REPO_URL"
    run git clone "$REPO_URL" "$CONFIG_DIR"
    return
  fi

  if [ -d "$CONFIG_DIR/.git" ] && git -C "$CONFIG_DIR" remote get-url origin >/dev/null 2>&1; then
    local url
    url="$(git -C "$CONFIG_DIR" remote get-url origin)"
    if [ "$url" = "$REPO_URL" ]; then
      ok "已是同一个仓库，跳过克隆（要更新请执行 git pull）"
      return
    fi
    die "$CONFIG_DIR 是另一个仓库（origin = $url），拒绝覆盖"
  fi

  # 目标存在但不是本仓库
  if [ "$FORCE" -eq 0 ]; then
    confirm "$CONFIG_DIR 已存在且不是本仓库，要覆盖吗？" || die "已取消"
  fi

  if [ "$DO_BACKUP" -eq 1 ]; then
    local backup
    backup="$CONFIG_DIR.bak.$(date +%Y%m%d-%H%M%S)"
    info "备份 → $backup"
    run mv "$CONFIG_DIR" "$backup"
  else
    warn "--no-backup：直接移除现有目录"
    run rm -rf "$CONFIG_DIR"
  fi

  run git clone "$REPO_URL" "$CONFIG_DIR"
}

# ─── 4. 首次插件安装 ────────────────────────────────────────
install_plugins() {
  printf '\n%s\n' "$(bold "3. 插件安装")"

  if [ "$DO_PLUGINS" -eq 0 ]; then
    warn "已跳过（--skip-plugins）。首次运行 nvim 时 lazy.nvim 会自动安装。"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s %s\n' "$(dim "[dry-run]")" "nvim --headless '+Lazy! sync' +qa"
    return
  fi

  info "首次启动 Neovim 安装插件（需要网络，可能要几分钟）"
  local log
  log="$(mktemp "${TMPDIR:-/tmp}/crownvim-install.XXXXXX")"

  # GIT_TERMINAL_PROMPT=0：避免在无凭证的环境里卡在密码提示上
  if (
    cd "$CONFIG_DIR"
    GIT_TERMINAL_PROMPT=0 nvim --headless "+Lazy! sync" +qa
  ) >"$log" 2>&1; then
    ok "插件安装完成"
  else
    warn "插件安装过程中有报错，日志：$log"
    tail -n 30 "$log" | sed 's/^/    /'
    warn "可以稍后手动执行：nvim  然后 :Lazy sync"
    return
  fi

  rm -f "$log"
}

# ─── 5. 汇总 ────────────────────────────────────────────────
summary() {
  printf '\n%s\n' "$(bold "完成")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  %s\n' "$(dim "以上是 --dry-run 预览，没有做任何改动。")"
    return
  fi

  cat <<EOF

$(bold "接下来")
  $(cyan "nvim")                       首次启动
  $(cyan ":Lazy")                     查看 / 更新插件
  $(cyan ":Doctor")                   环境体检
  $(cyan "scripts/features.sh")       开关本机 AI 功能（补全 / 对话 / 翻译 …）
  $(cyan "scripts/features.sh -h")     查看全部子命令

$(bold "可选：本机 AI")
  ollama serve
  ollama pull qwen2.5-coder:3b
  ollama pull qwen2.5-coder:1.5b

$(bold "文档")
  README.md            总览与常用命令
  docs/INSTALL.md      安装与依赖排错
  docs/AI.md           本机 AI 能力
EOF
}

main() {
  printf '%s\n' "$(bold "CrowNvim 安装")"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s\n' "$(yellow "--dry-run：不会做任何改动")"
  fi

  check_deps
  prepare_target
  install_plugins
  summary
}

main
