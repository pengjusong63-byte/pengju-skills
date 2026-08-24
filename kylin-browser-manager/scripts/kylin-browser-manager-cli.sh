#!/usr/bin/env bash
set -u

PROG="kylin-browser-cli"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
${PROG}: 麒麟浏览器本地 CLI 封装

示例:
  bash scripts/${PROG}.sh open --json
  bash scripts/${PROG}.sh open-url https://www.baidu.com --json

用法:
  bash scripts/${PROG}.sh <子命令> [--json]

子命令:
  open                                    打开麒麟浏览器
  open-url <url>                          用麒麟浏览器打开指定网址
  open-downloads                          打开下载页面
  open-history                            打开历史记录页面
  open-bookmarks                          打开书签页面
  open-settings                           打开设置页面
  tab-new                                 新建标签页
  tab-close <tab_id>                      关闭指定标签页
  tab-switch <tab_id>                     切换到指定标签页
  nav-forward                             前进
  nav-back                                后退
  reload                                  刷新页面
  screenshot <filename>                   截图当前页面
  snapshot                                获取页面快照
  snapshot-interactive                    获取可交互元素快照
  click <ref>                             点击页面元素
  press <key>                             模拟按键
  fill <ref> <text>                       在文本框中输入文本
  close                                   关闭麒麟浏览器

选项:
  --json    输出单行 JSON（Agent 调用时必须使用）
  --help    显示此帮助

副作用说明:
  本脚本会实时控制桌面应用，可能拉起麒麟浏览器窗口、新建/关闭标签页、
  改变当前页面，操作不可撤销。依赖当前用户图形会话和 agent-browser。
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

setup_env() {
  export AGENT_BROWSER_EXECUTABLE_PATH="${AGENT_BROWSER_EXECUTABLE_PATH:-/usr/bin/kylin-browser}"
  export AGENT_BROWSER_HEADED="${AGENT_BROWSER_HEADED:-true}"
  
  # 确保用npm安装的agent-browser 在 PATH 中
  local NODE_BIN
  NODE_BIN="$HOME/.nvm/versions/node/$(ls "$HOME/.nvm/versions/node" 2>/dev/null | sort -Vr | head -n1)/bin"
  if [[ -d "$NODE_BIN" && ! ":$PATH:" =~ ":$NODE_BIN:" ]]; then
    export PATH="$NODE_BIN:$PATH"
  fi
}

check_browser() {
  if [[ ! -x "$AGENT_BROWSER_EXECUTABLE_PATH" ]]; then
    json_error "麒麟浏览器未找到" "请确认 /usr/bin/kylin-browser 已安装"
    exit 5
  fi
}

check_agent_browser() {
  if ! command -v agent-browser >/dev/null 2>&1; then
    json_error "agent-browser 未安装或不可用" "请先安装 agent-browser 并确保其在 PATH 中"
    exit 5
  fi
}

AGENT_OUTPUT=""
AGENT_CODE=0

run_agent() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/kylin-browser-cli.XXXXXX")
  agent-browser "$@" >"$tmp" 2>&1
  AGENT_CODE=$?
  AGENT_OUTPUT=$(cat "$tmp" 2>/dev/null)
  rm -f "$tmp"
}

browser_open() {
  local url="${1:-}"
  if [[ -n "$url" ]]; then
    run_agent open "$url"
  else
    run_agent open
  fi

  if [[ $AGENT_CODE -ne 0 ]]; then
    run_agent close --all
    if [[ -n "$url" ]]; then
      run_agent open "$url"
    else
      run_agent open
    fi
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
  check_browser
  check_agent_browser

  case "$action" in
    open)
      browser_open
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "open" "已打开麒麟浏览器"
      else
        json_error "打开麒麟浏览器失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    open-url)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 url" "用法: bash scripts/${PROG}.sh open-url <url> --json"
        exit 2
      fi
      browser_open "${args[0]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "open-url" "已用麒麟浏览器打开 ${args[0]}"
      else
        json_error "打开网址失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    open-downloads)
      browser_open "chrome://downloads/"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "open-downloads" "已打开麒麟浏览器的下载页面"
      else
        json_error "打开下载页面失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    open-history)
      browser_open "chrome://history/"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "open-history" "已打开麒麟浏览器的历史记录页面"
      else
        json_error "打开历史记录页面失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    open-bookmarks)
      browser_open "chrome://bookmarks/"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "open-bookmarks" "已打开麒麟浏览器的书签页面"
      else
        json_error "打开书签页面失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    open-settings)
      browser_open "chrome://settings/"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "open-settings" "已打开麒麟浏览器的设置页面"
      else
        json_error "打开设置页面失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    tab-new)
      run_agent tab new
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "tab-new" "已在麒麟浏览器中新建标签页"
      else
        json_error "新建标签页失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    tab-close)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 tab_id" "用法: bash scripts/${PROG}.sh tab-close <tab_id> --json"
        exit 2
      fi
      run_agent tab close "${args[0]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "tab-close" "已关闭麒麟浏览器的标签页"
      else
        json_error "关闭标签页失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    tab-switch)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 tab_id" "用法: bash scripts/${PROG}.sh tab-switch <tab_id> --json"
        exit 2
      fi
      run_agent tab switch "${args[0]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "tab-switch" "已切换到指定标签页"
      else
        json_error "切换标签页失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    nav-forward)
      run_agent forward
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "nav-forward" "已在麒麟浏览器中前进"
      else
        json_error "前进失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    nav-back)
      run_agent back
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "nav-back" "已在麒麟浏览器中后退"
      else
        json_error "后退失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    reload)
      run_agent reload
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "reload" "已刷新麒麟浏览器页面"
      else
        json_error "刷新页面失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    screenshot)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 filename" "用法: bash scripts/${PROG}.sh screenshot <filename> --json"
        exit 2
      fi
      run_agent screenshot "${args[0]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "screenshot" "已保存截图到 ${args[0]}"
      else
        json_error "截图失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    snapshot)
      run_agent snapshot
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "snapshot" "已获取页面快照"
      else
        json_error "获取页面快照失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    snapshot-interactive)
      run_agent snapshot -i
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "snapshot-interactive" "已获取可交互元素快照"
      else
        json_error "获取可交互元素快照失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    click)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 ref" "用法: bash scripts/${PROG}.sh click <ref> --json"
        exit 2
      fi
      local ref="${args[0]}"
      [[ "$ref" != @* ]] && ref="@$ref"
      run_agent click "$ref"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "click" "已点击页面元素"
      else
        json_error "点击元素失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    press)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "缺少参数 key" "用法: bash scripts/${PROG}.sh press <key> --json"
        exit 2
      fi
      run_agent press "${args[0]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "press" "已模拟按键 ${args[0]}"
      else
        json_error "按键操作失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
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
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "fill" "已填写文本框"
      else
        json_error "填写文本框失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
      ;;

    close)
      run_agent close --all
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "close" "已关闭麒麟浏览器"
      else
        json_error "关闭浏览器失败" "${AGENT_OUTPUT:-agent-browser 返回错误}"
      fi
      exit $AGENT_CODE
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
