---
name: kylin-browser-ticket-booking
description: >-
  自动化订票：在携程官网完成火车票/高铁票的查询、筛选、选座和预订操作。
  当用户说"订明天下午2点从北京到上海的高铁二等座"、"订8月15日下午1点从广州到长沙的火车票硬卧"、"买后天从上海到杭州的高铁票"时触发此 Skill。
  关键词：订票、买票、购票、抢票、携程、高铁、火车、火车票。
  本 skill 仅用于携程平台的火车票/高铁票查询与预订，不包含机票预订、酒店预订、地图路线查询、网页搜索浏览、录音录像、文件操作等功能，用户要求后者时不得使用本 skill。
  注意：携程导航栏一直有"登录""注册"按钮，即便已登录也存在，不要因看到导航栏的"登录"按钮就判定为未登录。
version: 0.0.1
author: ""
tags:
  - 生活
names:
  zh-CN: 携程订票
---

# 携程订票自动化

通过 `scripts/kylin-browser-ticket-booking-cli.sh` 本地 CLI 控制麒麟浏览器进行携程订票操作，所有底层调用（agent-browser、环境变量、浏览器启动、失败重试）均封装在脚本内。

## 执行原则

- 用户意图直接映射到一系列子命令，Agent 按步骤执行，**不做选择、推导或二次确认**。用户已明确指定车次类型、时间、座位等信息时，直接自动匹配并执行，不得向用户反问"选哪个"。
- Agent 只执行：`bash scripts/kylin-browser-ticket-booking-cli.sh <子命令> [参数] --json`（工作目录为 Skill 根目录）。
- 禁止手写 `agent-browser` 命令、设置环境变量、`nohup`、`curl`、管道、重定向、`&&/||`、后台或命令替换。
- 脚本已封装退出码：0=成功、1=一般错误、2=无效参数、3=资源未找到、4=依赖缺失、5=冲突、10=dry-run 通过。
- 成功时只转发 CLI 返回的 `result.message`；失败时只转发 `error`。
- 涉及支付、乘客信息填写等操作，Agent 仅引导用户手动完成，不尝试自动填写。

## 功能映射表

所有操作通过 `bash scripts/kylin-browser-ticket-booking-cli.sh <子命令> [参数] --json` 调用（工作目录为 Skill 根目录），支持子命令：`open-train`、`snapshot`、`snapshot-interactive`、`snapshot-grep`、`click`、`fill`、`press`、`eval`、`scroll`、`tab-new`、`tab-list`、`tab-switch`、`close`。

## 使用场景

本 Skill 用于指导 agent 完成以下订票操作：

- 打开携程火车票官网
- 登录携程账号（等待用户手动登录）
- 选择出发城市和到达城市、出发日期
- 点击搜索按钮查询车次
- 筛选车次类型（高铁/动车/普通）
- 筛选出发时间（如 12:00-18:00）
- 点击"订"按钮进入选座
- 选择座位类型（二等座/硬卧/硬座等）
- 点击"预订"按钮

| 场景类型 | 示例语句 |
|---|---|
| **直接订票需求** | "买明天下午2点从北京到上海的高铁二等座" |
| **指定出发时间** | "订8月15日下午1点从广州到长沙的火车票硬卧" |
| **抢票需求** | "抢后天下午3点从上海到杭州的高铁票二等座" |

**触发关键词**：`订票`、`买票`、`购票`、`抢票`、`携程`、`高铁`、`火车`、`火车票`

## 支持的平台

- **携程** (trains.ctrip.com) - 唯一支持

## 输入说明

- `出发地`：必填，出发城市名称，如"北京"、"北京南"。
- `目的地`：必填，目的城市名称，如"上海"、"广州"。
- `出发日期`：必填，出发日期，如"明天"、"2026-08-15"。
- `出发时间`：可选，期望的出发时间段，如"下午2点"、"14:00"、"上午"。
- `车次类型`：可选，枚举值，支持 `高铁`、`动车`、`普通`，默认全部。
- `座位类型`：可选，枚举值，支持 `二等座`、`一等座`、`商务座`、`硬卧`、`软卧`、`硬座`，默认根据车次类型选择（高铁默认二等座，火车默认硬座）。
- `平台`：可选，订票平台名称，当前仅支持 `携程`，默认 `携程`。

## 输出说明

- 直接输出操作结果，包含车次信息、出发时间、座位类型、价格。
- 禁止生成总结、摘要或格式化报告。
- 最终页面出现"乘客信息"时，告知用户订票结束，请用户自行填写乘客信息并支付。

## Agent 行为准则

1. **记忆辅助**：流程开始前自动查询记忆中的订票偏好和历史行程（阶段零）；流程结束后自动保存本次订票关键结果到记忆。记忆仅用于减少重复输入，不影响单次订票的正确决策。

## 权限边界

- 本 Skill 需要访问本地麒麟浏览器（kylin-browser）及远程调试端口（9228）。
- 需要 `agent-browser` CLI 工具可用。
- 不访问用户文件系统、剪贴板或网络配置。
- 不收集或上传用户订票数据至第三方。
- Agent 不得尝试自动填写密码、验证码或支付信息。

## 操作流程

### 阶段零：查询记忆中的订票偏好

##### 0.1 [自动] 查询用户订票常用信息

调用 `memory_recall(query: "订票常用信息、常用出发地、目的地、座位偏好")`。若命中：
- 自动记下已记录的偏好信息（如常用城市、座位类型偏好等），后续查询时优先作为默认值使用
- 向用户说明已从记忆中获取到部分信息，请用户确认或修改

若未命中，正常按输入说明向用户索要信息。

### 1. 打开携程火车票首页

```bash
bash scripts/kylin-browser-ticket-booking-cli.sh open-train ctrip --json
```

### 2. 检测登录状态（关键步骤）

打开携程后，检测是否已登录。注意：携程导航栏一直有"登录""注册"按钮，即使已登录也存在，**不要仅因看到导航栏的"登录"按钮就判定为未登录**。

```bash
# 获取可交互元素快照，检测是否已登录
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json
```

**正确判断登录状态的方法**：

**已登录的标志**（满足任一即可）：
- 页面右上角显示用户名、头像或"欢迎"等用户信息
- 导航栏中出现"我的订单"等用户专属入口
- 页面内容正常显示，没有弹出登录弹窗
- 可直接进行搜索、查询等操作

**未登录的标志**（必须满足以下条件才判定为未登录）：
- 页面中央弹出**登录弹窗/对话框**，遮挡了主内容
- 页面主要内容区域显示"请登录"大标题（不是导航栏中的"登录"链接）
- 点击搜索后跳转到登录页面

**判断规则**：
- 如果只看导航栏有"登录"按钮，但页面内容正常显示 → **视为已登录**，直接进入步骤 3
- 如果有弹出登录弹窗/对话框遮挡主内容 → **未登录**，执行登录引导流程
- 如果不确定登录状态 → **默认已登录**，先执行搜索，如果搜索失败出现登录提示再引导登录

**未登录时执行以下登录引导流程**：
1. 告知用户"携程需要登录才能订票，请完成登录"
2. 展示当前页面可交互元素快照给用户，说明需要点击哪个登录入口
3. 等待用户反馈登录完成
4. 用户确认登录后，重新获取可交互元素快照确认登录状态
5. 确认已登录后，继续执行后续步骤

### 3. 输入出发地和目的地（推荐使用 eval）

携程页面默认有"北京→上海"的预设值，必须先清空再填入新的城市。

推荐使用 `eval` 子命令通过 JavaScript 直接设置输入框值，一步完成清空、填值、触发 React 事件和选择联想下拉项，无需依赖 `ref`。

**参数化模板**：替换 `<city>` 为城市名，`<placeholder>` 为"出发"或"到达"：

```bash
# 设置城市（替换 <city> 和 <placeholder>）
bash scripts/kylin-browser-ticket-booking-cli.sh eval "
  (() => {
    const s = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    const input = ['input[placeholder*=\"<placeholder>\"]','input.origin-input','input.destination-input']
      .map(sel => document.querySelector(sel)).find(el => el);
    if (!input) return JSON.stringify({ok:false,error:'未找到输入框'});
    s.call(input, ''); input.dispatchEvent(new Event('input', {bubbles:true}));
    s.call(input, '<city>'); input.dispatchEvent(new Event('input', {bubbles:true}));
    input.dispatchEvent(new Event('change', {bubbles:true}));
    return new Promise(r => setTimeout(() => {
      const item = document.querySelector('[class*=\"suggest\"] li,[class*=\"city\"] li,[class*=\"option\"]');
      if (item) item.click();
      r(JSON.stringify({ok:true,value:'<city>'}));
    }, 1000));
  })()
" --json
```

**示例**：
- 设置出发城市"北京"：`<placeholder>` → `出发`，`<city>` → `北京`
- 设置到达城市"上海"：`<placeholder>` → `到达`，`<city>` → `上海`

**如果 `eval` 执行失败**（返回 `ok:false`），回退到 manual 方式（先对出发地执行一次，再对到达地执行一次）：

```bash
# 1. 获取可交互元素快照，找到输入框的 ref
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json

# 2. 聚焦输入框，用 eval 清空
bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json
bash scripts/kylin-browser-ticket-booking-cli.sh eval "
  (() => {
    const el = document.activeElement;
    if (!el) return JSON.stringify({ok:false});
    const s = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    s.call(el, ''); el.dispatchEvent(new Event('input', {bubbles:true}));
    el.dispatchEvent(new Event('change', {bubbles:true}));
    return JSON.stringify({ok:true});
  })()
" --json

# 3. 填入城市名（替换 <city> 为实际城市）
bash scripts/kylin-browser-ticket-booking-cli.sh fill @<ref> "<city>" --json
```

> 对出发地和到达地分别执行上述流程，第一次 `<city>` 替换为出发城市，第二次替换为到达城市。携程页面输入内容后可能弹出城市选择下拉面板，属正常行为，无需关闭。如果面板遮挡操作，可点击页面空白区域或按 Escape 关闭。

### 4. 选择出发日期

**查找策略**：日期选择器常见特征：
- `input[placeholder*="出发日期"]`、`input[placeholder*="日期"]`
- 或带日期图标的输入框（旁边有日历图标）

**优先使用 eval 设置日期**（推荐，无需找 ref）：

```bash
# 设置出发日期（替换 <date> 为实际日期，如"2026-08-25"）
bash scripts/kylin-browser-ticket-booking-cli.sh eval "
  (() => {
    const s = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    const input = ['input[placeholder*=\"出发日期\"]','input[placeholder*=\"日期\"]','input.date-input']
      .map(sel => document.querySelector(sel)).find(el => el);
    if (!input) return JSON.stringify({ok:false,error:'未找到日期输入框'});
    s.call(input, ''); input.dispatchEvent(new Event('input', {bubbles:true}));
    s.call(input, '<date>'); input.dispatchEvent(new Event('input', {bubbles:true}));
    input.dispatchEvent(new Event('change', {bubbles:true}));
    return JSON.stringify({ok:true,value:'<date>'});
  })()
" --json
```

**eval 失败时回退到 manual 方式**：

```bash
# 获取可交互元素快照，找到"今天"对应日期的 ref
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "今天" --json

# 点击日期选择器聚焦，如果日期选择器是文本框则 fill 填入日期
bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json
```

### 5. 点击搜索按钮

**查找策略**：搜索按钮常见特征：
- 文本包含"搜索"的按钮/链接（`button`、`a`、`div[class*="search"]` 等）
- 页面中带有放大镜图标的可点击元素

```bash
# 获取可交互元素快照，找到"搜索"按钮的 ref
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "搜索" --json

# 点击搜索按钮
bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json
```

### 6. 查看搜索结果并筛选

```bash
# 获取可交互元素快照，检查搜索结果是否正常加载
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json
```

**判断搜索结果状态**：
- **正常显示车次列表** → 继续筛选
- **出现"网络异常"、"请登录"等提示** → 说明很可能未登录或登录已过期，回到步骤 2 引导登录
- **页面空白或加载中** → 等待 2-3 秒后重新获取可交互元素快照，重复最多 2 次

> **重要：必须先执行步骤 6.1 和 6.2 进行筛选，筛选完成后才能进入步骤 7 选择车次。禁止在未筛选的情况下直接滚动页面查找车次或直接点击"订"按钮。**

#### 6.1 筛选车次类型

如果用户指定了车次类型（高铁/动车/普通），**必须执行**此筛选操作，不得跳过：

**操作规则**：用 `snapshot-grep "车型"` 查看车型筛选区域，根据用户需求勾选对应的选项：
- 用户要"高铁" → 勾选 `高铁(G/C)`（如果已勾选则保持）
- 用户要"动车" → 勾选 `动车(D)`（如果已勾选则保持）
- 用户要"普通" → 勾选 `普通(K/T/Z)`（如果已勾选则保持）

```bash
# 用 snapshot-grep 按 heading 关键词过滤，只返回"车型"区域附近的元素及 ref
# 输出示例：
#   - heading "车型" [level=4, ref=e111]
#     - listitem "[object Object]高铁(G/C)" [level=1, ref=e227] clickable
#     - listitem "[object Object]动车(D)" [level=1, ref=e228] clickable
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "车型" --json

# 找到对应车次类型的 listitem 的 ref 后点击（如 ref=e227 对应"高铁(G/C)"）
bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json
```

#### 6.2 筛选出发时间

如果用户指定了出发时间，**必须执行**此筛选操作，不得跳过或通过滚动查找替代：

**时间描述 → 筛选范围映射规则**（按此规则选择对应的时间段）：
- "中午12点" / "12:00" / "12点" → 选择 `12:00 -14:00`（不要选 `12:00 -18:00`，范围太宽）
- "下午2点" / "14:00" / "下午2点" → 选择 `12:00 -18:00`
- "下午3点" / "15:00" → 选择 `12:00 -18:00`
- "上午" / "早上" → 选择 `06:00 -12:00`
- "下午" / "傍晚" → 选择 `12:00 -18:00`
- "晚上" → 选择 `18:00 -24:00`

```bash
# 用 snapshot-grep 按 heading 关键词过滤，只返回"出发时间"区域附近的元素及 ref
# 输出示例：
#   - heading "出发时间" [level=4, ref=e113]
#     - listitem "12:00 -14:00" [level=1, ref=e232] clickable    ← 优先选择这个
#     - listitem "12:00 -18:00" [level=1, ref=e233] clickable
#     - listitem "18:00 -24:00" [level=1, ref=e234] clickable
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "出发时间" --json

# 找到对应时间段的 listitem 的 ref 后点击
bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json
```

### 7. 点击"订"按钮选择车次（自动匹配，不反问）

> **前置条件：必须已完成步骤 6.1、6.2，否则不得进入此步骤。**

根据用户指定的条件自动匹配车次，**不得向用户列出多个选项让用户选择**。

```bash
# 获取可交互元素快照，查看筛选后的车次列表
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json
```

**自动匹配规则**（严格按优先级，必须满足所有条件）：

1. **车型一致性校验**：如果用户指定了车次类型（如"高铁"），从 `snapshot-interactive` 输出中确认车次号（如 G1234、D1234）与用户指定类型匹配：
   - 用户要"高铁" → 只匹配 G/C 开头车次（如 G1234、C1234），**不得选择 D/K/T/Z 等非高铁车次**
   - 用户要"动车" → 只匹配 D 开头车次
   - 用户要"普通" → 只匹配 K/T/Z 等普速车次
   - 如果筛选后的车次列表中没有匹配的车次，告知用户"没有符合条件的车次"，不得降级选择其他车型

2. **出发时间匹配**：在符合车型要求的车次中，找到出发时间最接近用户指定时间的车次

3. **选择车次**：直接点击匹配到的车次对应的"订"按钮，不询问用户

```bash
# 直接点击匹配到的车次对应的"订"按钮，不询问用户
bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json
```

### 8. 选座并预订

```bash
# 获取可交互元素快照，找到对应时间（如"14:00"）的"预订"按钮的 ref
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "14:00" --json

# 根据用户需求选择座位类型（如二等座），点击对应"预订"按钮
bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json
```

### 9. 确认订票结果

```bash
# 获取可交互元素快照，查看是否出现"乘客信息"页面
bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json
```

当页面出现"乘客信息"时，说明订票成功，告知用户订票结束，请用户自行填写乘客信息并完成支付。

### 10. [自动] 保存本次订票记录到记忆

订票成功后，执行以下记忆保存：
- 调用 `memory_recall(query: "订票记录、历史行程")`，查询是否已有同主题记忆
- 若有 → 使用 file_edit 更新已有条目，追加本次行程明细
- 若无 → 使用 file_write 创建新条目（type: user），再更新 MEMORY.md 索引

记忆条目格式参考：
```yaml
name: "订票记录"
description: "用户历史订票行程明细"
type: "user"
```

保存信息包含：订票日期、出发地、目的地、出发时间、车次类型、座位类型、状态。

## 约束限制

- 仅支持携程火车票（trains.ctrip.com），不支持 12306、飞猪、去哪儿等其他平台。
- 需要用户已登录携程账号。注意：携程导航栏一直有"登录""注册"按钮，**不要仅因导航栏有"登录"二字就判定为未登录**，需判断是否有弹出登录弹窗遮挡主内容。
- 引导用户登录时，Agent 仅展示快照并等待用户手动完成登录，不得尝试自动填写密码或验证码。
- 涉及支付、乘客信息填写等操作，Agent 仅引导用户手动完成，不尝试自动填充。
- **Agent 不得向用户反问"选哪个"**。用户已明确指定车次类型、时间、座位等信息时，按自动匹配规则直接选择对应车次和座位，继续执行。
- 需要麒麟浏览器（kylin-browser）和 agent-browser 工具已安装。
- 需要当前系统有可用的图形会话（X11/Wayland）。
- 浏览器启动超时阈值为 15 秒。
- 禁止在首页勾选"只搜高铁动车"等筛选选项，如果首页已勾选"只搜高铁动车"选项，需要先取消勾选，车次类型筛选统一在搜索结果页（步骤 6.1）进行。
- 禁止生成总结、摘要或格式化报告，仅输出原始操作结果。
- 因为携程页面结构可能导致 Agent 总结的信息与浏览器实际显示不一致，需引导用户确认订票信息。
- 如果用户未指定座位类型，高铁默认选择二等座，火车默认选择硬座。
- 如果用户未指定出发日期或时间，告知用户需要给出具体信息。
- 如果搜索结果为空，告知用户没有符合条件的车次。

## 异常处理

| 现象 | 说明 |
|---|---|
| `error: dependency_missing` | 目标环境缺少 agent-browser |
| `error: browser_timeout` / `browser_connect_failed` | 浏览器启动超时（15秒）或 agent-browser 无法连接远程调试端口，检查当前图形会话 |
| 搜索返回"网络异常"或页面提示"请登录" | **最常见原因：未登录携程**。执行登录引导流程（步骤 2），让用户手动登录后重新搜索 |
| 页面出现登录弹窗/二维码 | 暂停操作，告知用户"请完成携程登录"，展示快照，等待用户确认登录完成 |
| 搜索结果为空 | 告知用户没有符合条件的车次，建议更换日期或目的地 |
| 指定座位类型缺货 | 选择相近的可用座位类型并告知用户 |
| 页面元素找不到 | 刷新页面重试；若仍失败，停止任务并报错 |
| 网络加载失败 | 让用户检查网络连接，确保浏览器可以访问互联网 |
| 页面加载慢 | 适当等待后重新获取可交互元素快照 |
| 点击失败 | 检查元素是否可点击，是否被其他元素遮挡；文本框可使用 `fill` 命令输入内容后选择下拉框选项 |

## 调用样例

**用户需求：** 买明天下午2点从北京到上海的高铁二等座。

完整执行步骤：

| # | 命令 | 说明 |
|---|---|---|
| 1 | `bash scripts/kylin-browser-ticket-booking-cli.sh open-train ctrip --json` | 打开携程火车票首页 |
| 2 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json` | 检测登录状态，若未登录则引导用户手动登录 |
| 3 | `bash scripts/kylin-browser-ticket-booking-cli.sh eval "..." --json` | 用 eval 设置出发城市"北京"（替换 `<placeholder>` 为"出发"，`<city>` 为"北京"） |
| 4 | `bash scripts/kylin-browser-ticket-booking-cli.sh eval "..." --json` | 用 eval 设置到达城市"上海"（替换 `<placeholder>` 为"到达"，`<city>` 为"上海"） |
| 5 | `bash scripts/kylin-browser-ticket-booking-cli.sh eval "..." --json` | 用 eval 设置出发日期为明天日期（如 `2026-09-29`，替换 `<date>`） |
| 6 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "搜索" --json` | 找到搜索按钮的 ref |
| 7 | `bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json` | 点击搜索按钮 |
| 8 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json` | 检查搜索结果是否正常加载 |
| 9 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "车型" --json` | 查找车型筛选区域，找到"高铁(G/C)"的 ref |
| 10 | `bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json` | 勾选"高铁(G/C)" |
| 11 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-grep "出发时间" --json` | 查找出发时间筛选区域，找到"12:00-18:00"的 ref |
| 12 | `bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json` | 选择"12:00-18:00"时间区间（下午2点映射为此区间） |
| 13 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json` | 查看筛选后的车次列表，确认车次号以 G/C 开头，找到最接近14:00的车次"订"按钮的 ref |
| 14 | `bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json` | 点击"订"按钮 |
| 15 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json` | 进入选座页面，找到"二等座"对应的"预订"按钮的 ref |
| 16 | `bash scripts/kylin-browser-ticket-booking-cli.sh click @<ref> --json` | 点击"预订" |
| 17 | `bash scripts/kylin-browser-ticket-booking-cli.sh snapshot-interactive --json` | 确认是否出现"乘客信息"页面，告知用户自行填写乘客信息并支付 |