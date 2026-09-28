---
name: kylin-browser-oa-permission
description: >-
  OA流程自动化Skill：支持数字麒麟权限申请、办公用品领用、请假申请等OA流程的自动化填写与提交。
  触发后在浏览器中打开OA门户，完成登录认证，根据用户意图自动分流到对应流程。
  适用于OA权限申请、数字麒麟、办公用品领用、请假申请、OA审批、流程申请等任务。
  用户仅要求查看OA公告、查询OA通讯录、查看待办事项或进行其他OA查看类操作时，不得使用本skill。
version: 0.1.0
author: ""
tags:
  - 办公
names:
  zh-CN: OA流程自动化
---

# OA流程自动化

通过 `scripts/kylin-browser-oa-permission-cli.sh` 本地 CLI 控制麒麟浏览器完成OA门户登录及流程操作，所有底层调用（agent-browser、环境变量、浏览器启动、失败重试）均封装在脚本内。

## 使用场景

用户提交OA流程申请、申请数字麒麟权限、领用办公用品、申请请假时使用。触发后根据用户消息中的关键词自动识别目标流程。

## CLI 能力

| 用户意图 | CLI 路径 | 说明 |
|---|---|---|
| 打开OA门户并登录 | `open-url <url>` | 启动麒麟浏览器并导航到OA门户 |
| 获取页面快照 | `snapshot` | 获取当前完整页面快照 |
| 获取可交互元素快照 | `snapshot-interactive` | 获取页面可交互元素及其 ref 引用 |
| 点击页面元素 | `click <ref>` | 通过 ref 引用点击页面元素 |
| 填写文本框 | `fill <ref> <text>` | 在指定元素中输入文本 |
| 模拟按键 | `press <key>` | 模拟键盘按键操作 |
| 下拉框选择 | `select <ref> <option>` | 在下拉框中选择选项 |
| 滚动页面 | `scroll <x> <y>` | 滚动页面到指定位置 |
| 切换标签页 | `tab <tab_id>` | 切换到指定标签页（如 `t2`），通过 `tab-list` 获取标签页 ID，**不要用数字索引** |
| 列出标签页 | `tab-list` | 列出所有已打开的标签页 |
| 执行 JavaScript | `eval <code>` | 执行 JS 代码 |
| 从文件执行 JS | `eval-file <file> [KEY=VALUE...]` | 从 JS 文件读取并执行，可传 KEY=VALUE 注入变量（推荐），如 `eval-file f.js LEAVE_TYPE=\"年假\" --json` |
| 查找元素 | `find <type> <value> [action]` | 查找元素（text/label），可附加 `click` 动作和 `--wait N` 等待 |
| 设置 Cookie | `cookies-set <name> <value> --url <u>` | 设置浏览器 cookie（用于 cvaToken 免密登录） |
| 一键请假 | `leave-apply <KEY>=<VALUE>...` | **高级命令**：点击假勤申请 → 切换到请假页 → 执行 `leave-form-eval.js` 一键填表，参数同 `eval-file`（如 `LEAVE_TYPE="年假" START_DAY="18"`） |
| 一键登录 | `login-cookie` | **高级命令**：读取 cookie.txt → 设置 portal+sso cookie → 刷新 → 验证登录，返回 `{hasUser, userText}` |
| 关闭浏览器 | `close` | 关闭麒麟浏览器及所有 agent-browser 会话 |

所有 CLI 路径均通过本 skill 对外声明的 Agent CLI 执行，不要让 Agent 临时拼装内部 DBus、重定向或复杂 Shell 命令。

> **重要**：`snapshot` 和 `snapshot-interactive` 命令直接透传 agent-browser 的原始 JSON 输出（不再额外包装），Agent 可直接从输出中提取元素的 `ref` 字段用于后续 `click`/`fill` 等操作。

## 输入说明

Agent 根据用户意图分流后，一次性向用户索要对应流程所需的所有信息。

### 登录凭证

有两种登录方式可选：

#### 方式A：用户名+密码+验证码（默认）
- `用户名`：必填，OA登录用户名。
- `密码`：必填，OA登录密码。

#### 方式B：Cookie 免密登录
- 需要 `~/.kylinbot/workspace/cookie.txt` 文件中已有有效的 `cvaToken`
- 无需用户名密码，直接通过设置 Cookie 跳过登录页
- 如果 token 过期（>24小时），回落至方式A

### 流程A：数字麒麟权限申请 输入

Agent 向用户一次性收集：

| 字段 | 类型 | 说明 |
|---|---|---|
| **相关系统** | 多选 | 从以下列表中勾选需要权限的系统（可多选）：售后管理系统、CRM系统、终端研发统一账号系统、测试部门户、持续集成发布平台、K2CI、生态适配流转平台、知识库、适配资料归档平台、自动化适配平台、订阅平台、产品版本管理平台、研发内网邮箱、电子交付平台、门禁系统、禅道、内外网传输、麒麟官网(管理后台)、AI_API网关 |
| **账号** | 文本 | 需要开通权限的登录账号 |
| **岗位名称** | 文本 | 您的岗位/职位名称 |
| **备注** | 文本 | 补充说明（可选） |

### 流程B：办公用品领用 输入

Agent 向用户一次性收集：

| 字段 | 类型 | 说明 |
|---|---|---|
| **物品名称** | 文本 | 需要领用的办公用品名称（如：电风扇、笔记本、笔等） |
| **领用数量** | 数字 | 每种物品的领用数量 |
| **申领理由** | 文本 | 领用原因/理由（必填） |
| **备注** | 文本 | 每项物品的补充说明（可选） |

### 流程C：请假申请 输入

Agent 向用户一次性收集：

| 字段 | 类型 | 说明 |
|---|---|---|
| **请假类型** | 单选 | 如：年假、事假、病假、婚假、产假等 |
| **开始日期** | 日期 | 请假起始日期（如：9月28日） |
| **开始时段** | 单选 | `上午` 或 `下午` |
| **结束日期** | 日期 | 请假结束日期（如：9月30日） |
| **结束时段** | 单选 | `上午` 或 `下午` |
| **请假原因** | 文本 | 请假原因说明（必填） |

## 输出说明

- 执行操作后，输出申请结果（成功/失败）及页面返回的提示信息。
- 遇到验证码时，提示用户手动填写蓝信收到的验证码。
- **提交前必须让用户核实信息并确认，不得在用户未确认的情况下直接提交。**
- 禁止生成与OA流程无关的总结或报告。

## Agent 行为准则

1. **主动引导**：触发后，主动向用户一次性索要所有信息（登录凭证 + 流程所需信息），不要分步询问。
2. **分流执行**：根据用户消息中的关键词自动识别目标流程，引导用户提供对应信息。
3. **减少确认**：除验证码输入和最终提交确认外，其他中间步骤无需向用户确认。
4. **自动处理**：弹窗关闭、页面跳转、表单填写等操作性步骤自动完成，无需向用户汇报每一步。
5. **异常透明**：仅当操作失败或需要用户决策时才向用户报告。
6. **一次成功**：信息齐全后一气呵成完成流程，不要在过程中穿插询问。
7. **记忆辅助**：流程开始前自动查询记忆中的用户偏好和历史记录（阶段零）；流程结束后自动保存本次关键结果到记忆。记忆仅用于减少重复输入和跟踪待办状态，不影响单次流程的正确决策。

## 执行流程

> **运行目录**：所有命令均需在 skill 目录下执行，Agent 调用时先 `cd /home/kylin/.kylinbot/workspace/skills/builtin/kylin-browser-oa-permission` 或使用绝对路径。
> **注意**：`cookie.txt` 位于 `~/.kylinbot/workspace/cookie.txt`，不在 skill 目录下。**不得**手动检查 cookie.txt，`login-cookie` 命令内部会自动处理。
>
> **流程原则**：标有 **[自动]** 的步骤由 Agent 自动完成无需询问；标有 **[交互]** 的步骤需要用户参与。

---

### 阶段零：查询记忆中的用户偏好

> **记忆系统说明**：本 skill 集成了 KylinBot 的长期记忆（Memory）功能，能记住用户常用的个人信息、待提交的请假项目、历史申请记录等，减少重复输入。Agent 在以下步骤中会自动调用 `memory_recall` 读取记忆。

##### 0.1 [自动] 查询用户OA常用信息

调用 `memory_recall(query: "OA流程常用的个人信息、岗位名称、常用系统")`。若命中：
- 自动记下已记录的岗位名称、常用系统、账号等信息，后续填表时优先作为默认值使用
- 向用户说明已从记忆中获取到部分信息，请用户确认或修改

若未命中，正常按下方的输入说明向用户索要信息。

---

### 阶段一：启动浏览器并打开OA门户

**[自动]** 启动浏览器并导航到OA门户：

```bash
bash scripts/kylin-browser-oa-permission-cli.sh open-url "https://portal.kylinos.cn/" --json
```

### 阶段二：登录认证

> **Agent 决策优先级**：
> 1. **优先尝试 Cookie 免密登录**（方式一）：只要 `~/.kylinbot/workspace/cookie.txt` 存在就自动走此流程
> 2. **兜底使用用户名+密码+验证码**（方式二）：仅在 Cookie 登录失败（例如 token 过期、cookie 文件不存在）时才回落
> 3. **禁止**在有 cookie.txt 且内容有效的情况下跳过方式一直接走方式二

---

#### 方式一（主流程）：Cookie 免密登录

> Agent 无需向用户索要登录信息，直接执行以下命令。

##### 2.1 [自动] 一键 Cookie 免密登录

> **⚠️ 严格约束（Agent 必须遵守）**：
> 1. **必须使用 `login-cookie` 高级命令**，一步完成所有操作，中间**不得**插入 `snapshot` / `cookies-set` / `press` / `eval` / `ls` / `cat` / `file_read` 等任何操作。
> 2. **禁止手动检查 cookie.txt 是否存在** —— `login-cookie` 内部会自动读取 `~/.kylinbot/workspace/cookie.txt`，文件不存在或为空时会返回明确的错误信息。
> 3. 禁止使用 `press F5` 替代 `eval "location.reload()"` 刷新页面 —— CDP 协议设置的 Cookie 在浏览器级刷新下可能不生效。
> 4. `login-cookie` 返回的 JSON 中包含 `hasUser` 字段：`true` 表示登录成功，`false` 表示失败需回落至方式二。

```bash
bash scripts/kylin-browser-oa-permission-cli.sh login-cookie --json
```

根据用户意图分流：
- **请假意图** → 跳过阶段三，**直接执行**[分支C的C1步骤](#c1-自动-一键打开假勤申请并填充表单)（从门户首页统一处理）
- **数字麒麟/办公用品意图** → 继续执行下方的阶段三

---

#### 方式二（兜底）：用户名+密码+验证码

> 仅在方式一失败时执行。Agent 需向用户索要用户名和密码。

##### 2A.1 [自动] 识别登录表单

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
```

从 snapshot 输出中识别：用户名输入框、密码输入框、获取验证码按钮、验证码输入框、登录按钮。

##### 2A.2 [自动] 填写用户名和密码

用户已在触发时提供登录信息，直接填写：

```bash
bash scripts/kylin-browser-oa-permission-cli.sh fill @<username_ref> "用户提供的用户名" --json
bash scripts/kylin-browser-oa-permission-cli.sh fill @<pwd_ref> "用户提供的密码" --json
```

##### 2A.3 [自动] 发送验证码

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json  # 找到获取验证码按钮 ref
bash scripts/kylin-browser-oa-permission-cli.sh click @<sms_code_btn_ref> --json
```

**[交互]** 提示用户：验证码已发送到蓝信，请查收。

##### 2A.4 [自动] 填写验证码并登录

用户提供验证码后：

```bash
bash scripts/kylin-browser-oa-permission-cli.sh fill @<code_ref> "用户提供的验证码" --json
bash scripts/kylin-browser-oa-permission-cli.sh click @<login_btn_ref> --json
```

---

### 阶段三：处理弹窗并导航

> **前置路由说明**：请假意图已在阶段二出口直接跳转到 C1，**不会进入本阶段**。以下步骤仅适用于数字麒麟权限申请和办公用品领用。

#### 3.1 [自动] 关闭弹窗

登录后获取快照检查是否有弹窗并关闭：

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
bash scripts/kylin-browser-oa-permission-cli.sh click @<close_btn_ref> --json  # 如有弹窗
```

#### 3.2 [自动] 导航到目标流程

> 此步骤**仅处理数字麒麟权限申请和办公用品领用**。请假意图已在阶段二出口分流，请勿在此处处理。

获取 OA 首页快照，找到目标入口并点击。点击后轮询等待页面加载，最长 20 秒：

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
bash scripts/kylin-browser-oa-permission-cli.sh click @<target_ref> --json

# 轮询等待页面加载，最长 20 秒（每 1 秒检查一次，页面就绪后提前退出）
_waited=0
while [ $_waited -lt 20 ]; do
  sleep 1
  _waited=$((_waited + 1))
  bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json 2>/dev/null && break
done
```

---

### 分支A：数字麒麟权限申请

#### A1. [自动] 获取申请表单快照

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
```

从快照中识别：**基本信息（只读）**：单据编号、申请人、申请日期、联系电话、申请部门、登录账号、工号。**申请信息**：相关系统复选框列表、账号、岗位名称、备注输入框。

#### A2. [自动] 填写表单

用户已在触发时提供申请信息，直接填写：

```bash
# 逐个勾选用户指定的系统
bash scripts/kylin-browser-oa-permission-cli.sh click @<checkbox_ref_系统名> --json

# 填写文本字段
bash scripts/kylin-browser-oa-permission-cli.sh fill @<account_ref> "用户提供的账号" --json
bash scripts/kylin-browser-oa-permission-cli.sh fill @<position_ref> "用户提供的岗位名称" --json
bash scripts/kylin-browser-oa-permission-cli.sh fill @<remark_ref> "用户提供的备注" --json
```

#### A3. [交互] 用户核实 → 等待指令 → 提交 → 反馈结果

> **⚠ 这是 STOP 点：填写到此结束，Agent 必须停下来等用户指令，不得继续。**

**步骤1：展示已填内容给用户核实**

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
```

**步骤2：停止等待用户指令**

向用户展示已填写的全部内容，然后停下来等待用户回复：

> "已为您填写完毕，请核实：相关系统：[系统列表]，账号：[账号]，岗位名称：[岗位名称]。确认无误请回复'提交'，如需修改请告诉我具体修改内容。"

**步骤3：用户说"提交"后，Agent 再点提交按钮**

只有用户明确回复了"提交"、"确认"或"可以"之后，Agent 才能继续执行提交：

```bash
bash scripts/kylin-browser-oa-permission-cli.sh click @<submit_ref> --json
```

> **⛔ 绝对禁止：Agent 不得在用户未明确说"提交"的情况下自动点击提交按钮。**

**步骤4：提交后确认结果**

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
# 如需获取全页面快照（含非交互元素），使用：
bash scripts/kylin-browser-oa-permission-cli.sh snapshot --json
```

向用户反馈：
- 成功："数字麒麟权限申请已成功提交，请关注 OA 审批进度。"
- 失败：告知具体原因，建议重试或联系管理员。

---

### 分支B：办公用品领用

#### B1. [自动] 获取表单快照

```bash
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
```

#### B2. [自动] 搜索并添加物品

页面默认已有1行空行（序号1），第1件物品直接用这行。用户需要领用第2件及以上物品时，才需要点击"添加"按钮新增行。

**第1件物品：点击搜索按钮打开物品选择弹窗**

```bash
bash scripts/kylin-browser-oa-permission-cli.sh click @<search_btn_ref> --json
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json
bash scripts/kylin-browser-oa-permission-cli.sh fill @<search_input_ref> "用户需要的物品名称" --json
bash scripts/kylin-browser-oa-permission-cli.sh press Enter --json
bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json  # 获取搜索结果
```

判断搜索结果：有结果则直接选中；无结果则自动精简关键词重试（如"电风扇"→"风扇"），精简后仍搜不到则向用户报告。

```bash
bash scripts/kylin-browser-oa-permission-cli.sh click @<result_ref> --json  # 点击选中目标物品
```

**第2件及以上物品：** 先点击"添加"按钮新增行，再重复搜索步骤。

**关键词精简策略：** 优先去掉品牌/型号前缀 → 去掉修饰词 → 保留核心名词。

#### B3. [自动] 填写数量、备注和申领理由

```bash
bash scripts/kylin-browser-oa-permission-cli.sh fill @<quantity_ref> "用户提供的数量" --json
bash scripts/kylin-browser-oa-permission-cli.sh fill @<item_remark_ref> "用户提供的备注" --json
bash scripts/kylin-browser-oa-permission-cli.sh fill @<reason_ref> "用户提供的申领理由" --json
```

#### B4. [交互] 用户核实 → 等待指令 → 提交 → 反馈结果

> **⚠ 这是 STOP 点：填写到此结束，Agent 必须停下来等用户指令，不得继续。**

流程与分支A一致：展示已填内容 → 等待用户确认 → 用户确认后提交 → 反馈结果。

##### B5. [自动] 保存本次领用记录到记忆

提交完成后，执行以下记忆保存：
- 调用 `memory_recall(query: "办公用品领用历史记录")`，查询是否已有同主题记忆
- 若有 → 使用 file_edit 更新已有条目，追加本次领用明细
- 若无 → 使用 file_write 创建新条目（type: user），再更新 MEMORY.md 索引

记忆条目格式参考：
```yaml
name: "办公用品领用记录"
description: "用户历史领用的办公用品明细"
type: "user"
```

保存信息包含：领用日期、物品名称及数量、申领理由、状态。

---

### 分支C：请假申请

> **说明**：请假表单在 iframe 内，需要通过 `eval` 执行 JavaScript 来操作。

#### C0. [自动] 查询记忆中是否有待提交的请假项目

先调用 `memory_recall(query: "请假申请、待提交、未完成的请假申请")`。若命中"已填表单待提交"的项目记录：
1. 向用户展示已有记录："检测到您有一条已填好待提交的请假记录：[请假类型]、[日期范围]、[原因]，是否继续提交？"
2. 用户确认 → 直接跳转到 C3（用户核实步骤），无需重新填表
3. 用户否定 → 调用 memory_recall 更新该记忆的状态为"已取消"后，继续正常流程执行 C1

若未命中，正常执行 C1。

#### C1. [自动] 一键打开假勤申请并填充表单

> **⚠️ 严格约束（Agent 必须遵守）**：
> 1. **必须使用下方 `leave-apply` 高级命令**，一步完成所有操作，中间**不得**插入 `snapshot` / `click` / `find` / `snapshot-interactive` / `tab` / `eval-file` 等任何操作。
> 2. `leave-apply` 内部自动处理：点击"假勤申请"入口 → 等待新标签页 → 切换到请假页 → 执行 `leave-form-eval.js` 在 iframe 内完成全部字段填写（类别、起止日期、理由）。
> 3. 执行完此步骤后**直接跳到**下面的 C2 验证，不得额外截图或确认。

```bash
bash scripts/kylin-browser-oa-permission-cli.sh leave-apply \
  LEAVE_TYPE="年假" \
  START_DAY="18" START_MONTH=9 START_PERIOD="上午" \
  END_DAY="18" END_MONTH=9 END_PERIOD="下午" \
  REASON="家里有事" --json
```

#### C2. [自动] 验证表单填写结果

```bash
bash scripts/kylin-browser-oa-permission-cli.sh eval '(() => {
  const doc = document.querySelector("iframe")?.contentDocument;
  const get = sel => doc?.querySelector(sel)?.querySelector("input,textarea")?.value?.trim() || "";
  const fields = {
    type: get(".pk_leave_type"),
    start: get("[attrcode=showbegindate]"),
    end: get("[attrcode=showenddate]"),
    reason: get(".leaveremark")
  };
  const ok = fields.type && fields.start && fields.end && fields.reason;
  return { fields, ok, ready: ok };
})()' --json
```

#### C3. [交互] 用户核实 → 等待指令 → 提交 → 反馈结果

> **⚠ 这是 STOP 点：填写到此结束，Agent 必须停下来等用户指令，不得继续。**

向用户展示已填写的请假信息：

> "请假申请已为您填写完毕，请核实：请假类型：[类型]，开始时间：[开始日期] [开始时段]，结束时间：[结束日期] [结束时段]，原因：[请假原因]。确认无误请回复'提交'，如需修改请告诉我具体修改内容。"

只有用户明确回复了"提交"、"确认"或"可以"之后，Agent 才能继续执行提交：

```bash
bash scripts/kylin-browser-oa-permission-cli.sh eval '(() => {
  const d = document.querySelector("iframe")?.contentDocument;
  const btn = [...d?.querySelectorAll("button") || []].find(b => b.innerText?.trim() === "提交");
  if (btn) { btn.click(); return "submitted"; }
  return "not_found";
})()' --json
```

向用户反馈：
- 成功："请假申请已成功提交，请关注 OA 审批进度。"
- 失败：告知具体原因，建议重试或联系管理员。

##### C4. [自动] 保存本次请假记录到记忆

提交完成后，执行以下记忆保存：

**若提交成功：**
- 调用 `memory_recall(query: "请假申请、年假、病假、事假记录")`，查询是否已有同主题的记忆
- 若有 → 使用 file_edit 更新已有条目
- 若无 → 使用 file_write 创建新条目（type: project），再更新 MEMORY.md 索引
- 记忆内容包含：请假类型、开始/结束日期（含上下午）、原因、状态（"已提交"）

**若提交失败或用户取消：**
- 调用 `memory_recall(query: "请假申请、待提交")`，查询是否已有"已填表单待提交"的记忆
- 若已有 → 使用 file_edit 更新为当前最新状态（保留待提交信息）
- 若无 → 使用 file_write 创建新条目（type: project），标记为"已填表单待提交"

记忆条目格式参考：
```yaml
name: "请假申请记录"
description: "用户提交或待提交的请假信息"
type: "project"
```

---

## 约束限制

- 仅支持麒麟浏览器（kylin-browser）和 agent-browser 工具已安装的环境。
- 需要当前系统有可用的图形会话（X11/Wayland）。
- 浏览器启动超时阈值为 15 秒。
- 不支持自动处理验证码，需要用户手动提供蓝信收到的验证码。
- 登录信息（用户名、密码、验证码）需由用户提供，Skill 不会自行生成或猜测。
- 表单信息需由用户根据实际情况提供。
- **提交前必须让用户核实信息，不得在用户未确认的情况下直接提交。**
- 办公用品领用时，物品搜索依赖OA系统中已有的物品数据，搜索不到需提示用户更换关键词。
- Cookie 免密登录依赖 `~/.kylinbot/workspace/cookie.txt` 中有效的 `cvaToken`（有效期约24小时），token 过期后回落至用户名密码登录。
- 禁止记录、存储或上传用户的任何信息。

## 异常处理

| 现象 | 说明 |
|---|---|
| `error: agent-browser 未安装或不可用` | 目标环境缺少 agent-browser |
| `error: 打开页面失败` / `连接浏览器失败` | 浏览器启动超时（15秒）或 agent-browser 无法连接远程调试端口，检查当前图形会话 |
| 页面加载失败/404 | 确认OA门户 URL 是否正确 |
| 登录失败 | 提示用户检查用户名/密码是否正确，或用有效 token 重试 |
| 验证码错误 | 提示用户重新提供正确的验证码 |
| 弹窗无法关闭 | 尝试刷新页面或提示用户手动处理 |
| 表单字段无法识别 | 刷新页面重试；若仍失败，提示用户手动填写 |
| 元素找不到 | 刷新页面重试；若仍失败，停止任务并报错 |
| Cookie 免密登录后仍显示登录页 | token 可能已过期，回落至用户名密码登录 |
| iframe 找不到 | 检查登录状态，确认已登录后再重试 |
| 库存不足 | 告知用户库存不足，建议联系管理员确认库存或更换物品 |
| 搜索无结果 | 自动精简关键词重试；精简后仍搜不到，告知用户并请用户提供其他关键词 |
| 提交失败 | 告知用户具体失败原因，建议重试或联系OA管理员 |

## Cookie 登录说明

### 获取 Token

1. 打开 Chrome，手动登录 `portal.kylinos.cn`
2. F12 > Application > Cookies > `portal.kylinos.cn`
3. 找到 `cvaToken`，复制值
4. 保存到 `~/.kylinbot/workspace/cookie.txt`

### 注意事项

- Token 有效期约24小时，过期后需重新获取
- 必须同时为 `portal.kylinos.cn` 和 `sso.kylinos.cn` 设置 cookie
- 设置 cookie 后刷新页面即可完成登录

## 权限边界

- 本 Skill 需要访问本地麒麟浏览器（kylin-browser）及远程调试端口（9229）。
- 需要 `agent-browser` CLI 工具可用。
- 不访问用户文件系统、剪贴板或网络配置。
- 不收集或上传用户信息至第三方。
- 所有OA流程共享同一个浏览器会话，不重复启动浏览器。

## 调用样例

### 样例1：数字麒麟权限申请

**用户输入：** "帮我申请数字麒麟权限，账号 admin，密码 123456，开通售后管理系统和禅道的权限，岗位名称是研发工程师"

Agent 完整执行：

1. `bash scripts/kylin-browser-oa-permission-cli.sh open-url "https://portal.kylinos.cn/" --json`
2. `bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json` → 识别登录表单
3. `bash scripts/kylin-browser-oa-permission-cli.sh fill @<username_ref> "admin" --json`
4. `bash scripts/kylin-browser-oa-permission-cli.sh fill @<pwd_ref> "123456" --json`
5. `bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json` → 找验证码按钮
6. `bash scripts/kylin-browser-oa-permission-cli.sh click @<sms_btn_ref> --json`
7. 交互："验证码已发送到蓝信，请查收" → 用户提供验证码
8. `bash scripts/kylin-browser-oa-permission-cli.sh fill @<code_ref> "验证码" --json`
9. `bash scripts/kylin-browser-oa-permission-cli.sh click @<login_ref> --json`
10. 关闭弹窗 → 导航到"数字麒麟权限申请"
11. `bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json` → 获取表单
12. 勾选 checkbox + 填写文本字段 → 展示给用户确认
13. 用户确认 → 点击提交 → 反馈结果

### 样例2：办公用品领用

**用户输入：** "帮我领用办公用品，需要领一台电风扇，数量2个，申领理由是天气太热需要降温。OA账号 admin，密码 123456"

Agent 完整执行：

1. `bash scripts/kylin-browser-oa-permission-cli.sh open-url "https://portal.kylinos.cn/" --json`
2~9. 登录流程（同上）
10. 在 OA 首页点击"办公用品领用"
11. `bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json` → 识别表单
12. `bash scripts/kylin-browser-oa-permission-cli.sh click @<e85> --json` → 点击名称列的搜索按钮
13. `bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json` → 获取搜索弹窗，找搜索输入框 ref
14. `bash scripts/kylin-browser-oa-permission-cli.sh fill @<search_input_ref> "电风扇" --json`
15. `bash scripts/kylin-browser-oa-permission-cli.sh press Enter --json`
16. `bash scripts/kylin-browser-oa-permission-cli.sh snapshot-interactive --json` → 找搜索结果
17. `bash scripts/kylin-browser-oa-permission-cli.sh click @<result_ref> --json` → 选中物品
18. `bash scripts/kylin-browser-oa-permission-cli.sh fill @<quantity_ref> "2" --json` → 填写数量
19. `bash scripts/kylin-browser-oa-permission-cli.sh fill @<reason_ref> "天气太热需要降温" --json` → 填写申领理由
20. 展示给用户确认 → 用户确认 → 点击提交 → 反馈结果

### 样例3：请假申请（Cookie 免密登录）

**用户输入：** "帮我请年假，9月28日上午到9月30日下午，家里有事"

Agent 完整执行：

1. `bash scripts/kylin-browser-oa-permission-cli.sh open-url "https://portal.kylinos.cn/" --json`
2. 读取 cookie.txt → 设置 cookie（portal + sso）→ 刷新验证
3. 关闭弹窗 → 快照找到"假勤申请"并点击
4. 等待页面跳转（8秒左右）
5. 执行 eval Ultra-Batch 填充表单
6. 展示已填内容 → 用户确认 → 提交 → 反馈结果