#!/usr/bin/env bash
set -u

PROG="kylin-browser-shopping-addcart-cli"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat >&2 <<EOF
${PROG}: 电商购物车自动化 CLI 封装

用法:
  bash scripts/${PROG}.sh <子命令> [参数...] [--json]

子命令:
  open-shop <platform>             打开麒麟浏览器并导航到指定电商平台
  snapshot                         获取页面快照
  snapshot-interactive             获取可交互元素快照
  click <ref>                      点击页面元素
  fill <ref> <text>                在文本框中输入文本
  press <key>                      模拟按键
  eval <js_code>                   执行 JavaScript 并返回结果
  scroll <direction> <pixels>      滚动页面（方向：down/up，像素数：如 500）
  tab-new <url>                    在新标签页中打开链接
  tab-list                         列出所有标签页
  tab-switch <index>               切换到指定标签页
  close                            关闭麒麟浏览器

选项:
  --json        输出单行 JSON（Agent 调用时必须使用）
  --dry-run     仅显示将要执行的操作，不实际执行
  --format fmt  输出格式（json / text），默认 text
  --help        显示此帮助

退出码:
  0  成功
  1  一般错误
  2  无效参数或用法错误
  3  资源未找到
  4  权限被拒绝或依赖缺失
  5  冲突或已存在
  10 dry-run 通过

示例:
  bash scripts/${PROG}.sh open-shop jd --json
  bash scripts/${PROG}.sh snapshot-interactive --json
  bash scripts/${PROG}.sh fill @123 "惠普 U盘 64G" --json
  bash scripts/${PROG}.sh click @456 --json
  bash scripts/${PROG}.sh scroll down 500 --json
  bash scripts/${PROG}.sh close --json
EOF
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
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
  local message="$2"
  local suggestion="${3:-}"
  local retryable="${4:-false}"
  if [[ -n "$suggestion" ]]; then
    printf '{"ok":false,"error":"%s","message":"%s","suggestion":"%s","retryable":%s}\n' \
      "$(json_escape "$error")" "$(json_escape "$message")" "$(json_escape "$suggestion")" "$retryable"
  else
    printf '{"ok":false,"error":"%s","message":"%s","retryable":%s}\n' \
      "$(json_escape "$error")" "$(json_escape "$message")" "$retryable"
  fi
}

setup_env() {
  local NODE_BIN
  NODE_BIN="$HOME/.nvm/versions/node/$(ls "$HOME/.nvm/versions/node" 2>/dev/null | sort -Vr | head -n1)/bin"
  if [[ -d "$NODE_BIN" && ! ":$PATH:" =~ ":$NODE_BIN:" ]]; then
    export PATH="$NODE_BIN:$PATH"
  fi
}

check_agent_browser() {
  if ! command -v agent-browser >/dev/null 2>&1; then
    json_error "dependency_missing" "agent-browser 未安装或不可用" "请先安装 agent-browser 并确保其在 PATH 中" "false"
    exit 4
  fi
}

REMOTE_DEBUG_PORT=9224

AGENT_OUTPUT=""
AGENT_CODE=0

run_agent() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/kylin-browser-shopping-addcart-cli.XXXXXX")
  agent-browser "$@" >"$tmp" 2>&1
  AGENT_CODE=$?
  AGENT_OUTPUT=$(cat "$tmp" 2>/dev/null)
  rm -f "$tmp"
}

get_shop_url() {
  local platform="$1"
  case "$platform" in
    jd|京东)
      echo "https://www.jd.com/"
      ;;
    *)
      echo "https://www.jd.com/"
      ;;
  esac
}

browser_start_with_remote_debug() {
  local url="${1:-https://www.jd.com}"

  # 关闭旧的 agent-browser 会话和麒麟浏览器
  (agent-browser close --all >/dev/null 2>&1 && pkill -f kybrowser) || true
  pkill -f "kylin-browser.*remote-debugging-port=${REMOTE_DEBUG_PORT}" 2>/dev/null || true
  sleep 1

  # 启动 kylin-browser 并开启远程调试端口
  nohup kylin-browser --remote-debugging-port="${REMOTE_DEBUG_PORT}" "$url" >/dev/null 2>&1 &
  local browser_pid=$!

  # 等待浏览器启动完成（端口可用）
  local wait_seconds=0
  while ! curl -s "http://localhost:${REMOTE_DEBUG_PORT}/json/version" >/dev/null 2>&1; do
    sleep 1
    wait_seconds=$((wait_seconds + 1))
    if [[ $wait_seconds -ge 15 ]]; then
      json_error "browser_timeout" "打开电商平台失败" "浏览器启动超时（15秒），请检查图形会话是否可用" "true"
      exit 1
    fi
  done

  # 连接已启动的浏览器
  run_agent connect "${REMOTE_DEBUG_PORT}"
  if [[ $AGENT_CODE -ne 0 ]]; then
    json_error "browser_connect_failed" "连接浏览器失败" "${AGENT_OUTPUT:-agent-browser 连接失败，请检查远程调试端口}" "true"
    exit 1
  fi
}

dry_run_msg() {
  local action="$1"
  shift
  local details="$*"
  printf '{"ok":true,"result":{"action":"dry-run","command":"%s","details":"%s"},"dry_run":true}\n' \
    "$(json_escape "$action")" "$(json_escape "$details")"
}

main() {
  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 2
  fi

  local action="$1"
  shift

  local use_json=false
  local dry_run=false
  local format="text"
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        use_json=true
        format="json"
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --format)
        if [[ $# -gt 1 ]]; then
          format="$2"
          shift 2
        else
          json_error "missing_argument" "缺少 --format 参数值" "用法: --format json|text" "false"
          exit 2
        fi
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

  # 设置 JSON 输出模式
  [[ "$format" == "json" ]] && use_json=true

  setup_env
  check_agent_browser

  case "$action" in
    open-shop)
      local platform="jd"
      if [[ ${#args[@]} -ge 1 ]]; then
        platform="${args[0]}"
      fi
      if $dry_run; then
        dry_run_msg "open-shop" "将启动麒麟浏览器（远程调试端口 ${REMOTE_DEBUG_PORT}）并导航到 ${platform}"
        exit 10
      fi
      local shop_url
      shop_url=$(get_shop_url "$platform")
      browser_start_with_remote_debug "$shop_url"
      json_success "open-shop" "已启动麒麟浏览器（远程调试端口 ${REMOTE_DEBUG_PORT}）并导航到 ${platform}"
      exit 0
      ;;

    snapshot)
      if $dry_run; then
        dry_run_msg "snapshot" "将获取当前页面快照"
        exit 10
      fi
      run_agent snapshot
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "snapshot" "$AGENT_OUTPUT"
      else
        json_error "snapshot_failed" "获取页面快照失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    snapshot-interactive)
      if $dry_run; then
        dry_run_msg "snapshot-interactive" "将获取当前页面可交互元素快照"
        exit 10
      fi
      run_agent snapshot -i
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "snapshot-interactive" "$AGENT_OUTPUT"
      else
        json_error "snapshot_failed" "获取可交互元素快照失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    click)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 ref" "用法: bash scripts/${PROG}.sh click <ref> --json" "false"
        exit 2
      fi
      local ref="${args[0]}"
      [[ "$ref" != @* ]] && ref="@$ref"
      if $dry_run; then
        dry_run_msg "click" "将点击页面元素 ${ref}"
        exit 10
      fi
      run_agent click "$ref"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "click" "已点击页面元素"
      else
        json_error "click_failed" "点击元素失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    fill)
      if [[ ${#args[@]} -lt 2 ]]; then
        json_error "missing_argument" "缺少参数" "用法: bash scripts/${PROG}.sh fill <ref> <text> --json" "false"
        exit 2
      fi
      local ref="${args[0]}"
      [[ "$ref" != @* ]] && ref="@$ref"
      local text="${args[*]:1}"
      if $dry_run; then
        dry_run_msg "fill" "将在元素 ${ref} 中输入文本"
        exit 10
      fi
      run_agent fill "$ref" "$text"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "fill" "已填写文本框"
      else
        json_error "fill_failed" "填写文本框失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    press)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 key" "用法: bash scripts/${PROG}.sh press <key> --json" "false"
        exit 2
      fi
      if $dry_run; then
        dry_run_msg "press" "将模拟按键 ${args[0]}"
        exit 10
      fi
      run_agent press "${args[0]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "press" "已模拟按键 ${args[0]}"
      else
        json_error "press_failed" "按键操作失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    eval)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 js_code" "用法: bash scripts/${PROG}.sh eval <js_code> --json" "false"
        exit 2
      fi
      local js_code="${args[*]}"
      if $dry_run; then
        dry_run_msg "eval" "将执行 JavaScript 代码"
        exit 10
      fi
      run_agent eval "$js_code"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "eval" "$AGENT_OUTPUT"
      else
        json_error "eval_failed" "执行 JavaScript 失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    scroll)
      if [[ ${#args[@]} -lt 2 ]]; then
        json_error "missing_argument" "缺少参数" "用法: bash scripts/${PROG}.sh scroll <direction> <pixels> --json" "false"
        exit 2
      fi
      local direction="${args[0]}"
      local pixels="${args[1]}"
      if $dry_run; then
        dry_run_msg "scroll" "将向 ${direction} 方向滚动 ${pixels} 像素"
        exit 10
      fi
      run_agent scroll "$direction" "$pixels"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "scroll" "已向 ${direction} 方向滚动 ${pixels} 像素"
      else
        json_error "scroll_failed" "滚动页面失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    tab-new)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 url" "用法: bash scripts/${PROG}.sh tab-new <url> --json" "false"
        exit 2
      fi
      local url="${args[0]}"
      if $dry_run; then
        dry_run_msg "tab-new" "将在新标签页中打开: ${url}"
        exit 10
      fi
      run_agent tab new "$url"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "tab-new" "已在新标签页中打开: ${url}"
      else
        json_error "tab_new_failed" "打开新标签页失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    tab-list)
      if $dry_run; then
        dry_run_msg "tab-list" "将列出所有标签页"
        exit 10
      fi
      run_agent tab list
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "tab-list" "$AGENT_OUTPUT"
      else
        json_error "tab_list_failed" "获取标签页列表失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    tab-switch)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 index" "用法: bash scripts/${PROG}.sh tab-switch <index> --json" "false"
        exit 2
      fi
      local index="${args[0]}"
      if $dry_run; then
        dry_run_msg "tab-switch" "将切换到标签页: ${index}"
        exit 10
      fi
      run_agent tab "$index"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "tab-switch" "已切换到标签页: ${index}"
      else
        json_error "tab_switch_failed" "切换标签页失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    close)
      if $dry_run; then
        dry_run_msg "close" "将关闭麒麟浏览器及所有 agent-browser 会话"
        exit 10
      fi
      run_agent close --all
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "close" "已关闭麒麟浏览器"
      else
        json_error "close_failed" "关闭浏览器失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    *)
      if $use_json; then
        json_error "unknown_command" "未知子命令: ${action}" "使用 --help 查看支持的子命令" "false"
      else
        usage >&2
      fi
      exit 2
      ;;
  esac
}

main "$@"