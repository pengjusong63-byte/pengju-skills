#!/usr/bin/env bash
set -u

PROG="kylin-browser-site-subpage-finder-cli"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
${PROG}: 站点子页面查找 CLI 封装

用法:
  bash scripts/${PROG}.sh <子命令> [参数...] [--json]

子命令:
  open-url <url>    在麒麟浏览器中打开指定 URL（后台运行）
  close             关闭麒麟浏览器

选项:
  --json    输出单行 JSON（Agent 调用时必须使用）
  --help    显示此帮助

示例:
  bash scripts/${PROG}.sh open-url "https://www.kylinos.cn/download" --json
  bash scripts/${PROG}.sh close --json
EOF
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

json_success() {
  local action="$1"
  local message="$2"
  printf '{"ok":true,"result":{"action":"%s","message":"%s"}}\n' \
    "$(json_escape "$action")" "$(json_escape "$message")"
}

json_error() {
  local error="$1"
  local hint="${2:-}"
  if [[ -n "$hint" ]]; then
    printf '{"ok":false,"error":"%s","hint":"%s"}\n' \
      "$(json_escape "$error")" "$(json_escape "$hint")"
  else
    printf '{"ok":false,"error":"%s"}\n' "$(json_escape "$error")"
  fi
}

check_kylin_browser() {
  if ! command -v kylin-browser >/dev/null 2>&1; then
    json_error "kylin-browser 未安装或不可用" "请确保 kylin-browser 已安装并在 PATH 中"
    exit 5
  fi
}

main() {
  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 2
  fi

  local action="$1"
  shift

  local use_json=false
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        use_json=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  check_kylin_browser

  case "$action" in
    open-url)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 url" "用法: bash scripts/${PROG}.sh open-url <url> --json"
        exit 2
      fi
      local url="${args[0]}"
      nohup kylin-browser "$url" >/dev/null 2>&1 &
      json_success "open-url" "已在麒麟浏览器中打开: ${url}"
      exit 0
      ;;

    close)
      pkill -f "kylin-browser" 2>/dev/null || true
      json_success "close" "已关闭麒麟浏览器"
      exit 0
      ;;

    *)
      if $use_json; then
        json_error "未知子命令: $action" "使用 --help 查看支持的子命令"
      else
        usage >&2
      fi
      exit 2
      ;;
  esac
}

main "$@"