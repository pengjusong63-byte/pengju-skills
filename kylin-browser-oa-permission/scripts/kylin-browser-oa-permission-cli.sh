#!/usr/bin/env bash
set -u

PROG="kylin-browser-oa-permission-cli"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat >&2 <<EOF
${PROG}: OA数字麒麟权限申请 CLI 封装

用法:
  bash scripts/${PROG}.sh <子命令> [参数...] [--json]

子命令:
  open-url <url>                        打开麒麟浏览器并导航到指定 URL
  snapshot                              获取页面快照
  snapshot-interactive                  获取可交互元素快照
  click <ref>                           点击页面元素
  fill <ref> <text>                     在文本框中输入文本
  press <key>                           模拟按键
  select <ref> <option>                 在下拉框中选择选项
  scroll <x> <y>                        滚动页面到指定位置
  tab <index>                           切换到指定标签页
  tab-list                              列出所有标签页
  eval <code>                           执行 JavaScript 代码（用于复杂表单操作）
  eval-file <file> [KEY=VALUE...]        从文件读取 JS，可传 KEY=VALUE 注入变量（推荐）
  find <type> <value> [action]          查找元素（text/label），可附加 click 动作
  leave-apply <KEY>=<VALUE>...          高级命令：一键请假（点击假勤申请→切换标签页→填表）
  login-cookie                          高级命令：Cookie 免密登录（设 portal+sso cookie → 刷新 → 验证）
  cookies-set <name> <value> --url <u>  设置浏览器 cookie（用于免密登录）
  close                                 关闭麒麟浏览器

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
  bash scripts/${PROG}.sh open-url "https://portal.kylinos.cn/" --json
  bash scripts/${PROG}.sh snapshot --json
  bash scripts/${PROG}.sh click @123 --json
  bash scripts/${PROG}.sh fill @456 "用户名" --json
  bash scripts/${PROG}.sh press Enter --json
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
      "$(json_escape "$error")" "$(json_escape "$message")" "$(json_escape "$suggestion")" "$retryable" >&2
  else
    printf '{"ok":false,"error":"%s","message":"%s","retryable":%s}\n' \
      "$(json_escape "$error")" "$(json_escape "$message")" "$retryable" >&2
  fi
}

setup_env() {
  local NODE_BIN
  NODE_BIN="$HOME/.nvm/versions/node/$(ls "$HOME/.nvm/versions/node" 2>/dev/null | sort -Vr | head -n1)/bin"
  if [[ -d "$NODE_BIN" && ! ":$PATH:" =~ ":$NODE_BIN:" ]]; then
    export PATH="$NODE_BIN:$PATH"
  fi
  export DISPLAY=:0
}

check_agent_browser() {
  if ! command -v agent-browser >/dev/null 2>&1; then
    json_error "dependency_missing" "agent-browser 未安装或不可用" "请先安装 agent-browser 并确保其在 PATH 中" "false"
    exit 4
  fi
}

REMOTE_DEBUG_PORT=9229

AGENT_OUTPUT=""
AGENT_CODE=0

run_agent() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/kylin-oa-permission-cli.XXXXXX")
  agent-browser "$@" >"$tmp" 2>&1
  AGENT_CODE=$?
  AGENT_OUTPUT=$(cat "$tmp" 2>/dev/null)
  rm -f "$tmp"
}

run_agent_raw() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/kylin-oa-permission-cli.XXXXXX")
  agent-browser "$@" >"$tmp" 2>&1
  AGENT_CODE=$?
  cat "$tmp"
  rm -f "$tmp"
}

browser_start_with_remote_debug() {
  local url="${1:-https://example.com}"

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
      json_error "browser_timeout" "打开页面失败" "浏览器启动超时（15秒），请检查图形会话是否可用" "true"
      exit 1
    fi
  done

  # 连接已启动的浏览器
  run_agent connect "${REMOTE_DEBUG_PORT}"
  if [[ $AGENT_CODE -ne 0 ]]; then
    json_error "browser_connect_failed" "连接浏览器失败" "${AGENT_OUTPUT:-agent-browser 连接失败，请检查远程调试端口}" "true"
    exit $AGENT_CODE
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
    open-url)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 url" "用法: bash scripts/${PROG}.sh open-url <url> --json" "false"
        exit 2
      fi
      local url="${args[0]}"
      if $dry_run; then
        dry_run_msg "open-url" "将启动麒麟浏览器（远程调试端口 ${REMOTE_DEBUG_PORT}）并导航到 ${url}"
        exit 10
      fi
      browser_start_with_remote_debug "$url"
      json_success "open-url" "已启动麒麟浏览器（远程调试端口 ${REMOTE_DEBUG_PORT}）并导航到 ${url}"
      exit 0
      ;;

    snapshot)
      if $dry_run; then
        dry_run_msg "snapshot" "将获取当前页面快照"
        exit 10
      fi
      run_agent_raw snapshot
      exit $AGENT_CODE
      ;;

    snapshot-interactive)
      if $dry_run; then
        dry_run_msg "snapshot-interactive" "将获取当前页面可交互元素快照"
        exit 10
      fi
      run_agent_raw snapshot -i
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

    select)
      if [[ ${#args[@]} -lt 2 ]]; then
        json_error "missing_argument" "缺少参数" "用法: bash scripts/${PROG}.sh select <ref> <option> --json" "false"
        exit 2
      fi
      local ref="${args[0]}"
      [[ "$ref" != @* ]] && ref="@$ref"
      local option="${args[*]:1}"
      if $dry_run; then
        dry_run_msg "select" "将在下拉框 ${ref} 中选择 ${option}"
        exit 10
      fi
      run_agent select "$ref" "$option"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "select" "已选择下拉框选项"
      else
        json_error "select_failed" "选择下拉框选项失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    scroll)
      if [[ ${#args[@]} -lt 2 ]]; then
        json_error "missing_argument" "缺少参数" "用法: bash scripts/${PROG}.sh scroll <x> <y> --json" "false"
        exit 2
      fi
      local x="${args[0]}"
      local y="${args[1]}"
      if $dry_run; then
        dry_run_msg "scroll" "将滚动页面到 (${x}, ${y})"
        exit 10
      fi
      run_agent scroll "$x" "$y"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "scroll" "已滚动页面"
      else
        json_error "scroll_failed" "滚动页面失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    tab)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 index" "用法: bash scripts/${PROG}.sh tab <index> --json" "false"
        exit 2
      fi
      local tab_index="${args[0]}"
      if $dry_run; then
        dry_run_msg "tab" "将切换到标签页 ${tab_index}"
        exit 10
      fi
      run_agent tab "$tab_index"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "tab" "已切换到标签页 ${tab_index}"
      else
        json_error "tab_switch_failed" "切换标签页失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
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
        json_error "tab_list_failed" "列出标签页失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    eval)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 code" "用法: bash scripts/${PROG}.sh eval <code> --json"
        exit 2
      fi
      local code="${args[*]}"
      if $dry_run; then
        dry_run_msg "eval" "将执行 JavaScript 代码"
        exit 10
      fi
      run_agent eval "$code"
      if [[ $AGENT_CODE -eq 0 ]]; then
        echo "$AGENT_OUTPUT"
      else
        json_error "eval_failed" "执行 JavaScript 失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    eval-file)
      if [[ ${#args[@]} -eq 0 ]]; then
        json_error "missing_argument" "缺少参数 file" "用法: bash scripts/${PROG}.sh eval-file <file> [KEY=VALUE...] --json"
        exit 2
      fi
      local js_file="${args[0]}"
      if [[ ! -f "$js_file" ]]; then
        json_error "file_not_found" "JS 文件不存在: ${js_file}" "请检查文件路径" "false"
        exit 1
      fi
      if $dry_run; then
        dry_run_msg "eval-file" "将从文件 ${js_file} 读取 JS 并执行"
        exit 10
      fi

      # 读取 JS 文件内容
      local code
      code=$(cat "$js_file") || {
        json_error "file_read_failed" "读取 JS 文件失败" "${js_file}" "false"
        exit 1
      }

      # 处理 KEY=VALUE 注入：从 args[1:] 中提取，拼接到代码前面
      # 使用 globalThis.xxx = value 而非 const，避免与文件内部 const 声明冲突
      local preamble=""
      local idx=1
      while [[ $idx -lt ${#args[@]} ]]; do
        local pair="${args[$idx]}"
        if [[ "$pair" == *"="* ]]; then
          local key="${pair%%=*}"
          local val="${pair#*=}"
          # 转义值中的双引号和反斜杠，用双引号包裹
          local escaped_val="${val//\\/\\\\}"
          escaped_val="${escaped_val//\"/\\\"}"
          preamble+="globalThis.${key} = \"${escaped_val}\";"
        fi
        idx=$((idx + 1))
      done

      # 拼接 preamble + 文件内容
      run_agent eval "${preamble}${code}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        echo "$AGENT_OUTPUT"
      else
        json_error "eval_failed" "执行 JavaScript 失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    find)
      if [[ ${#args[@]} -lt 2 ]]; then
        json_error "missing_argument" "缺少参数" "用法: bash scripts/${PROG}.sh find <type> <value> [action] [--wait N] --json" "false"
        exit 2
      fi
      local find_type="${args[0]}"
      local find_value="${args[1]}"
      local find_action=""
      local find_wait=""
      local find_extra_args=()
      local idx=2
      while [[ $idx -lt ${#args[@]} ]]; do
        case "${args[$idx]}" in
          --wait)
            idx=$((idx + 1))
            find_wait="${args[$idx]}"
            ;;
          click)
            find_action="click"
            ;;
          *)
            find_extra_args+=("${args[$idx]}")
            ;;
        esac
        idx=$((idx + 1))
      done
      if $dry_run; then
        dry_run_msg "find" "将查找 ${find_type} \"${find_value}\"${find_action:+ 并点击}"
        exit 10
      fi
      local agent_args=("find" "$find_type" "$find_value")
      [[ -n "$find_action" ]] && agent_args+=("$find_action")
      [[ -n "$find_wait" ]] && agent_args+=("--wait" "$find_wait")
      [[ ${#find_extra_args[@]} -gt 0 ]] && agent_args+=("${find_extra_args[@]}")
      run_agent "${agent_args[@]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        echo "$AGENT_OUTPUT"
      else
        json_error "find_failed" "查找元素失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
        exit 1
      fi
      exit $AGENT_CODE
      ;;

    leave-apply)
      # 高级命令：一键请假（点击假勤申请 → 切换标签页 → eval-file 填表）
      local js_file="$SKILL_DIR/scripts/leave-form-eval.js"
      if [[ ! -f "$js_file" ]]; then
        json_error "file_not_found" "leave-form-eval.js 不存在: ${js_file}" "" "false"
        exit 1
      fi
      local code
      code=$(cat "$js_file") || {
        json_error "file_read_failed" "读取 leave-form-eval.js 失败" "" "false"
        exit 1
      }
      # 构建 preamble：将 KEY=VALUE 注入为 globalThis 变量
      local preamble=""
      local pair
      for pair in "${args[@]}"; do
        if [[ "$pair" == *"="* ]]; then
          local key="${pair%%=*}"
          local val="${pair#*=}"
          local escaped_val="${val//\\/\\\\}"
          escaped_val="${escaped_val//\"/\\\"}"
          preamble+="globalThis.${key} = \"${escaped_val}\";"
        fi
      done
      if $dry_run; then
        dry_run_msg "leave-apply" "将一键完成请假申请（点击假勤申请 → 切换标签页 → 填表）"
        exit 10
      fi
      # Step 1: 点击"假勤申请"
      run_agent find text "假勤申请" click
      if [[ $AGENT_CODE -ne 0 ]]; then
        json_error "leave_apply_failed" "点击'假勤申请'失败" "${AGENT_OUTPUT}" "true"
        exit 1
      fi
      # Step 2: 轮询等待请假标签页打开（替代固定 sleep 6）
      local leave_tab=""
      local wait_start=$SECONDS
      local tab_timeout=15
      while [[ -z "$leave_tab" && $((SECONDS - wait_start)) -lt $tab_timeout ]]; do
        run_agent tab list
        while IFS= read -r line; do
          if [[ "$line" =~ \[(t[0-9]+)\] ]] && ([[ "$line" == *"假勤"* ]] || [[ "$line" == *"hr.kylinos"* ]]); then
            leave_tab="${BASH_REMATCH[1]}"
            break 2
          fi
        done <<< "$AGENT_OUTPUT"
        sleep 1
      done
      # Fallback: 没找到则尝试 t2
      [[ -z "$leave_tab" ]] && leave_tab="t2"
      # Step 3: 切换到请假标签页
      run_agent tab "$leave_tab"
      if [[ $AGENT_CODE -ne 0 ]]; then
        json_error "leave_apply_failed" "切换到标签页 ${leave_tab} 失败" "${AGENT_OUTPUT}" "true"
        exit 1
      fi
      # Step 4: 轮询等待页面就绪（替代固定 sleep 4），通过 snapshot 检测"请假申请"元素
      local wait_start=$SECONDS
      local page_timeout=15
      local page_ready=false
      while [[ $((SECONDS - wait_start)) -lt $page_timeout ]]; do
        local snap_out
        snap_out=$(run_agent_raw snapshot -i 2>/dev/null)
        if echo "$snap_out" | grep -q "请假申请"; then
          page_ready=true
          break
        fi
        sleep 1
      done
      if ! $page_ready; then
        json_error "leave_apply_timeout" "等待请假页面加载超时（${page_timeout}秒）" "" "true"
        exit 1
      fi
      # Step 5: 执行 leave-form-eval.js 填表
      run_agent eval "${preamble}${code}"
      echo "$AGENT_OUTPUT"
      exit $AGENT_CODE
      ;;

    login-cookie)
      # 高级命令：Cookie 免密登录（读取 cookie → 设置 portal+sso → 刷新 → 验证）
      local cookie_file="$HOME/.kylinbot/workspace/cookie.txt"
      if [[ ! -f "$cookie_file" ]]; then
        json_error "cookie_not_found" "Cookie 文件不存在: ${cookie_file}" "请先获取 cvaToken 并保存到 cookie.txt" "false"
        exit 1
      fi
      local token
      token=$(tr -d '[:space:]' < "$cookie_file")
      if [[ -z "$token" ]]; then
        json_error "cookie_empty" "Cookie 文件为空" "请先获取有效的 cvaToken" "false"
        exit 1
      fi
      if $dry_run; then
        dry_run_msg "login-cookie" "将使用 Cookie 免密登录 OA（portal + sso）"
        exit 10
      fi
      # Step 1: 设置 portal cookie
      run_agent cookies set "cvaToken" "$token" "--url" "https://portal.kylinos.cn/"
      if [[ $AGENT_CODE -ne 0 ]]; then
        json_error "login_cookie_failed" "设置 portal cookie 失败" "$AGENT_OUTPUT" "true"
        exit 1
      fi
      # Step 2: 设置 sso cookie
      run_agent cookies set "cvaToken" "$token" "--url" "https://sso.kylinos.cn/"
      if [[ $AGENT_CODE -ne 0 ]]; then
        json_error "login_cookie_failed" "设置 sso cookie 失败" "$AGENT_OUTPUT" "true"
        exit 1
      fi
      # Step 3: 用 eval location.reload() 刷新（⚠ 必须用 eval，press F5 会导致 CDP Cookie 不生效）
      run_agent eval "(() => { location.reload(); return 'reloading'; })()"
      if [[ $AGENT_CODE -ne 0 ]]; then
        json_error "login_cookie_failed" "刷新页面失败" "$AGENT_OUTPUT" "true"
        exit 1
      fi
      # Step 4: 等待页面加载
      sleep 5
      # Step 5: 验证登录状态（结构化返回 hasUser/userText）
      run_agent eval "(() => { return new Promise(r => { let i = 0; const t = setInterval(() => { i++; if (document.readyState==='complete' || i>=15) { clearInterval(t); const userEl = document.querySelector('[class*=\"user\" i], [class*=\"name\" i], .username, .login-name, .nc-user'); r({ready: true, loaded: document.readyState==='complete', hasUser: !!userEl, userText: userEl?.innerText?.trim() || ''}); } }, 1000); }); })()"
      # 直接输出验证结果 JSON（含 hasUser 字段供 Agent 判断）
      echo "$AGENT_OUTPUT"
      exit $AGENT_CODE
      ;;

    cookies-set)
      if [[ ${#args[@]} -lt 2 ]]; then
        json_error "missing_argument" "缺少参数" "用法: bash scripts/${PROG}.sh cookies-set <name> <value> --url <url> --json" "false"
        exit 2
      fi
      local ck_name="${args[0]}"
      local ck_value="${args[1]}"
      local ck_url=""
      local ck_extra_args=()
      local idx=2
      while [[ $idx -lt ${#args[@]} ]]; do
        case "${args[$idx]}" in
          --url)
            idx=$((idx + 1))
            ck_url="${args[$idx]}"
            ;;
          *)
            ck_extra_args+=("${args[$idx]}")
            ;;
        esac
        idx=$((idx + 1))
      done
      if [[ -z "$ck_url" ]]; then
        json_error "missing_argument" "缺少 --url 参数" "用法: bash scripts/${PROG}.sh cookies-set <name> <value> --url <url> --json" "false"
        exit 2
      fi
      if $dry_run; then
        dry_run_msg "cookies-set" "将为 ${ck_url} 设置 cookie ${ck_name}"
        exit 10
      fi
      run_agent cookies set "$ck_name" "$ck_value" "--url" "$ck_url" "${ck_extra_args[@]}"
      if [[ $AGENT_CODE -eq 0 ]]; then
        json_success "cookies-set" "已设置 cookie ${ck_name} (${ck_url})"
      else
        json_error "cookies_set_failed" "设置 cookie 失败" "${AGENT_OUTPUT:-agent-browser 返回错误}" "true"
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
