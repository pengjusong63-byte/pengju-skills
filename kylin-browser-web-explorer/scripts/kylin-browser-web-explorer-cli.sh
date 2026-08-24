#!/usr/bin/env bash
set -u

PROG="kylin-browser-web-explorer-cli"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
${PROG}: 网页搜索与浏览 CLI 封装

用法:
  bash scripts/${PROG}.sh <子命令> [参数...] [--json]

子命令:
  open-search <engine>              打开麒麟浏览器并导航到指定搜索引擎
  snapshot                          获取页面快照
  snapshot-interactive              获取可交互元素快照
  click <ref>                       点击页面元素
  fill <ref> <text>                 在文本框中输入文本
  press <key>                       模拟按键
  eval <js_code>                    执行 JavaScript 并返回结果
  tab-new <url>                     在新标签页中打开链接
  tab-list                          列出所有标签页
  tab-switch <index>                切换到指定标签页
  close [--yes|--force]             关闭麒麟浏览器（需确认，--yes/--force 跳过确认）

选项:
  --json    输出单行 JSON（Agent 调用时必须使用）
  --help    显示此帮助

退出码:
  0  成功
  1  一般错误
  2  无效参数或用法错误
  3  资源未找到或不可用
  5  冲突或已存在

示例:
  bash scripts/${PROG}.sh open-search baidu --json
  bash scripts/${PROG}.sh fill @123 "搜索关键词" --json
  bash scripts/${PROG}.sh eval 'document.title' --json
  bash scripts/${PROG}.sh tab-new "https://example.com" --json
  bash scripts/${PROG}.sh tab-switch 2 --json
  bash scripts/${PROG}.sh close --yes --json
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
      "$(json_escape "$error")" "$(json_escape "$hint")" >&2
  else
    printf '{"ok":false,"error":"%s"}\n' "$(json_escape "$error")" >&2
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
    json_error "agent-browser 未安装或不可用" "请先安装 agent-browser 并确保其在 PATH 中"
    exit 3
  fi
}

REMOTE_DEBUG_PORT=9226

AGENT_OUTPUT=""
AGENT_CODE=0

run_agent() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/kylin-browser-web-explorer-cli.XXXXXX")
  agent-browser "$@" >"$tmp" 2>&1
  AGENT_CODE=$?
  AGENT_OUTPUT=$(cat "$tmp" 2>/dev/null)
  rm -f "$tmp"
}

get_search_url() {
  local engine="$1"
  case "$engine" in
    baidu|百度)
      echo "https://www.baidu.com/"
      ;;
    bing|必应)
      echo "https://www.cn.bing.com/"
      ;;
    *)
      echo "https://www.baidu.com/"
      ;;
  esac
}

browser_start_with_remote_debug() {
  local url="${1:-https://www.baidu.com}"

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
      json_error "打开搜索引擎失败" "浏览器启动超时（15秒），请检查图形会话"
      exit 3
    fi
  done

  # 连接已启动的浏览器
  run_agent connect "${REMOTE_DEBUG_PORT}"
  if [[ $AGENT_CODE -ne 0 ]]; then
    json_error "连接浏览器失败" "${AGENT_OUTPUT:-agent-browser 连接失败}"
    exit 1
  fi
}

handle_agent_result() {
  local action_label="$1"
  local success_msg="$2"
  if [[ $AGENT_CODE -eq 0 ]]; then
    json_success "$action_label" "$success_msg"
    exit 0
  else
    json_error "${action_label}失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
    exit 1
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

  setup_env
  check_agent_browser

  case "$action" in
    open-search)
      local engine="baidu"
      if [[ ${#args[@]} -ge 1 ]]; then
        engine="${args[0]}"
      fi
      local search_url
      search_url=$(get_search_url "$engine")
      browser_start_with_remote_debug "$search_url"
      json_success "open-search" "已启动麒麟浏览器（远程调试端口 ${REMOTE_DEBUG_PORT}）并导航到 ${engine} 搜索"
      exit 0
      ;;

    snapshot)
      run_agent snapshot
      handle_agent_result "snapshot" "$AGENT_OUTPUT"
      ;;

    snapshot-interactive)
      run_agent snapshot -i
      handle_agent_result "snapshot-interactive" "$AGENT_OUTPUT"
      ;;

    click)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 ref" "用法: bash scripts/${PROG}.sh click <ref> --json"
        exit 2
      fi
      local ref="${args[0]}"
      [[ "$ref" != @* ]] && ref="@$ref"
      run_agent click "$ref"
      handle_agent_result "click" "已点击页面元素"
      ;;

    fill)
      if [[ ${#args[@]} -lt 2 ]]; then
        json_error "缺少参数" "用法: bash scripts/${PROG}.sh fill <ref> <text> --json"
        exit 2
      fi
      local ref="${args[0]}"
      [[ "$ref" != @* ]] && ref="@$ref"
      local text="${args[*]:1}"
      run_agent fill "$ref" "$text"
      handle_agent_result "fill" "已填写文本框"
      ;;

    press)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 key" "用法: bash scripts/${PROG}.sh press <key> --json"
        exit 2
      fi
      run_agent press "${args[0]}"
      handle_agent_result "press" "已模拟按键 ${args[0]}"
      ;;

    eval)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 js_code" "用法: bash scripts/${PROG}.sh eval <js_code> --json"
        exit 2
      fi
      local js_code="${args[*]}"
      run_agent eval "$js_code"
      handle_agent_result "eval" "$AGENT_OUTPUT"
      ;;

    tab-new)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 url" "用法: bash scripts/${PROG}.sh tab-new <url> --json"
        exit 2
      fi
      local url="${args[0]}"
      run_agent tab new "$url"
      handle_agent_result "tab-new" "已在新标签页中打开: ${url}"
      ;;

    tab-list)
      run_agent tab list
      handle_agent_result "tab-list" "$AGENT_OUTPUT"
      ;;

    tab-switch)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 index" "用法: bash scripts/${PROG}.sh tab-switch <index> --json"
        exit 2
      fi
      local index="${args[0]}"
      run_agent tab "$index"
      handle_agent_result "tab-switch" "已切换到标签页: ${index}"
      ;;

    close)
      local has_yes=false
      local has_force=false
      local filtered_args=()
      for a in "${args[@]}"; do
        case "$a" in
          --yes) has_yes=true ;;
          --force) has_force=true ;;
          *) filtered_args+=("$a") ;;
        esac
      done
      args=("${filtered_args[@]}")

      # 非 TTY 且没有 --yes 时，要求显式确认
      if ! $use_json && ! $has_force; then
        echo "确认关闭麒麟浏览器？[y/N] " >&2
        read -r confirm
        case "$confirm" in
          y|Y|yes|YES) ;;
          *) json_error "关闭浏览器已取消"; exit 1 ;;
        esac
      fi
      if $use_json && ! $has_yes; then
        json_error "关闭浏览器需要确认" "请添加 --yes 参数确认关闭"
        exit 2
      fi

      run_agent close --all
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "close" "已关闭麒麟浏览器"
        exit 0
      else
        json_error "关闭浏览器失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
        exit 1
      fi
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