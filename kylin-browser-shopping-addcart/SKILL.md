---
name: kylin-browser-shopping-addcart
description: >-
  自动化电商购物：在京东平台搜索商品、筛选品牌/价格/规格、加入购物车。
  当用户说"想在京东买XXX加入购物车"、"帮我买XX东西到购物车"、"搜索XX商品并加入购物车"时触发此 Skill。
  关键词：购物、京东、加入购物车、买、买东西、电商自动化。
  本 skill 仅用于京东电商平台的商品搜索、筛选、加入购物车操作，不包含地图路线查询、POI 搜索、网页搜索浏览、录音录像、文件操作等功能，用户要求后者时不得使用本 skill。
  使用本 skill 前需要用户已登录京东账号，若未登录则引导用户手动登录。
version: 0.0.1
author: ""
tags:
  - 生活
names:
  zh-CN: 电商购物车
---

# 电商购物车自动化

通过 `scripts/kylin-browser-shopping-addcart-cli.sh` 本地 CLI 控制麒麟浏览器进行电商购物操作，所有底层调用（agent-browser、环境变量、浏览器启动、失败重试）均封装在脚本内。

## 执行原则

- 用户意图直接映射到一系列子命令，Agent 按步骤执行，不做选择、推导或二次确认。
- Agent 只执行：`bash scripts/kylin-browser-shopping-addcart-cli.sh <子命令> [参数] --json`（工作目录为 Skill 根目录）。
- 禁止手写 `agent-browser` 命令、设置环境变量、`nohup`、`curl`、管道、重定向、`&&/||`、后台或命令替换。
- 脚本已封装退出码：0=成功、1=一般错误、2=无效参数、3=资源未找到、4=依赖缺失、5=冲突、10=dry-run 通过。
- 成功时只转发 CLI 返回的 `result.message`；失败时只转发 `error`。

## 功能映射表

| 用户意图（触发词） | 子命令 |
|---|---|
| 打开麒麟浏览器并导航到京东 | `open-shop <platform>` |
| 获取页面快照 | `snapshot` |
| 获取可交互元素快照 | `snapshot-interactive` |
| 搜索元素文本并获取 ref | `find-ref <text>` |
| 点击页面元素 | `click <ref>` |
| 在文本框中输入文本 | `fill <ref> <text>` |
| 模拟按键 | `press <key>` |
| 执行 JavaScript 提取信息 | `eval <js_code>` |
| 滚动页面加载更多商品 | `scroll <direction> <pixels>` |
| 在新标签页中打开链接 | `tab-new <url>` |
| 列出所有标签页 | `tab-list` |
| 切换到指定标签页 | `tab-switch <index>` |
| 关闭麒麟浏览器 | `close` |

调用方式（工作目录为 Skill 根目录）：

```bash
bash scripts/kylin-browser-shopping-addcart-cli.sh <子命令> [参数] --json
```

## 使用场景

本 Skill 用于指导 agent 完成以下电商操作：

- 在京东平台搜索指定商品
- 根据条件筛选商品（品牌、价格、规格等）
- 选择合适的商品 SKU
- 将商品加入购物车

| 场景类型 | 示例语句 |
|---|---|
| **直接购物需求** | "想在京东上买惠普 U盘 64G 100块左右加入到购物车" |
| **简化表达** | "帮我买iphone 16手机加入购物车" |
| **平台指定** | "京东买 Nike 鞋子 42码" |

**触发关键词**：`购物`、`加入购物车`、`京东`、`自动化购物`

## 支持的平台

- **京东** (jd.com) - 主要支持

## 输入说明

- `搜索关键词`：必填，要搜索的商品描述，如"惠普 U盘 64G"。
- `品牌`：可选，指定品牌名称，如"惠普"、"HP"。
- `规格`：可选，商品规格参数，如"64G"、"42码"。
- `价格范围`：可选，可接受的价格区间，如"80-120元"、"100块左右"。
- `平台`：可选，电商平台名称，当前仅支持 `京东`，默认 `京东`。

## 输出说明

- 直接输出操作结果，包含商品名称、最终价格、所选规格。
- 禁止生成总结、摘要或格式化报告。

## Agent 行为准则

1. **记忆辅助**：流程开始前自动查询记忆中的购物偏好和历史记录（阶段零）；流程结束后自动保存本次购物关键结果到记忆。记忆仅用于减少重复输入，不影响单次购物的正确决策。

## 权限边界

- 本 Skill 需要访问本地麒麟浏览器（kylin-browser）及远程调试端口（9224）。
- 需要 `agent-browser` CLI 工具可用。
- 不访问用户文件系统、剪贴板或网络配置。
- 不收集或上传用户购物数据至第三方。

## 操作流程

### 阶段零：查询记忆中的购物偏好

##### 0.1 [自动] 查询用户购物常用信息

调用 `memory_recall(query: "电商购物常用信息、偏好品牌、历史搜索关键词")`。若命中：
- 自动记下已记录的偏好信息（如常用品牌、价格偏好等），后续搜索时优先作为默认值使用
- 向用户说明已从记忆中获取到部分信息，请用户确认或修改

若未命中，正常按输入说明向用户索要信息。

### 1. 打开京东首页

```bash
bash scripts/kylin-browser-shopping-addcart-cli.sh open-shop jd --json
```

### 2. 检测登录状态（关键步骤）

打开京东后，必须先检测是否已登录，未登录时搜索会返回"网络异常"。

```bash
# 获取页面快照，检测是否已登录
bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot --json
```

**判断登录状态**：检查快照内容中是否包含"登录"、"注册"、"请登录"等字样，或出现明显的登录弹窗/二维码。

**已登录**：页面应显示用户名或"欢迎来到京东"等字样 → 直接进入步骤 3。

**未登录**：执行以下登录引导流程：
1. 告知用户"京东需要登录才能搜索商品，请完成登录"
2. 展示当前页面快照给用户，说明需要点击哪个登录入口
3. 等待用户反馈登录完成
4. 用户确认登录后，重新获取快照确认登录状态
5. 确认已登录后，继续执行后续步骤

### 3. 搜索商品

```bash
# 获取可交互元素快照，找到搜索输入框的 ref
bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot-interactive --json

# 在搜索框中填入关键词
bash scripts/kylin-browser-shopping-addcart-cli.sh fill @<ref> "惠普 U盘 64G" --json

# 按下回车键发起搜索
bash scripts/kylin-browser-shopping-addcart-cli.sh press Enter --json
```

### 4. 查看搜索结果

```bash
# 获取页面快照，检查搜索结果是否正常加载
bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot --json
```

**判断搜索结果状态**：
- **正常显示商品列表** → 继续步骤 4.2
- **出现"网络异常"、"无法搜索"等提示** → 说明很可能未登录或登录已过期，执行登录引导流程（回到步骤 2），然后重新搜索
- **出现"请登录"、"验证"等字样** → 执行登录引导流程（回到步骤 2）
- **页面空白或加载中** → 等待 2-3 秒后重新获取快照，重复最多 2 次

```bash
# 获取可交互元素快照，查看商品列表
bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot-interactive --json
```

如果搜索结果中看不到符合价格要求的商品，可通过滚动加载更多：

```bash
bash scripts/kylin-browser-shopping-addcart-cli.sh scroll down 500 --json
```

### 5. 选择商品进入详情页

从 `snapshot-interactive` 输出中识别符合条件的商品元素，点击进入详情页：

```bash
bash scripts/kylin-browser-shopping-addcart-cli.sh click @<ref> --json
```

### 6. 选择规格并加入购物车

```bash
# 获取可交互元素快照，找到规格选择元素
bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot-interactive --json

# 点击所需规格（如容量、颜色等）
bash scripts/kylin-browser-shopping-addcart-cli.sh click @<ref> --json

# ★ 优化：直接用 find-ref 精准 grep "加入购物车"，无需手动从快照中找 ref
# 通过匹配文本自动提取对应 ref，避免点错
bash scripts/kylin-browser-shopping-addcart-cli.sh find-ref "加入购物车" --json

# 用 find-ref 返回的 ref 点击"加入购物车"按钮
bash scripts/kylin-browser-shopping-addcart-cli.sh click @<ref> --json
```

> **提示**：对于"加入购物车"这类通用文字（页面上可能有多处，如"京东新品"区域的加入购物车），`find-ref` 会返回第一个匹配。如果点击后无效，可先用 `snapshot-interactive` 确认页面上的多个 "加入购物车" 按钮，再指定更精确的搜索文本（如 `find-ref "￥"` 定位价格区域，或 `find-ref "规格"` 定位商品规格区）。

### 7. 确认添加成功

```bash
# 获取页面快照，查看是否显示"已加入购物车"提示
bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot --json
```

### 8. [自动] 保存本次购物记录到记忆

加入购物车成功后，执行以下记忆保存：
- 调用 `memory_recall(query: "电商购物记录、历史购买商品")`，查询是否已有同主题记忆
- 若有 → 使用 file_edit 更新已有条目，追加本次购物明细
- 若无 → 使用 file_write 创建新条目（type: user），再更新 MEMORY.md 索引

记忆条目格式参考：
```yaml
name: "电商购物记录"
description: "用户历史购物商品明细"
type: "user"
```

保存信息包含：购物日期、商品名称、规格、价格、平台。

## 约束限制

- 仅支持京东（jd.com），不支持淘宝、天猫、拼多多等其他平台。
- 需要用户已登录京东账号。未登录时搜索会返回"网络异常"，必须在操作流程步骤 2 中先检测登录状态。
- 引导用户登录时，Agent 仅展示快照并等待用户手动完成登录，不得尝试自动填写密码或验证码。
- 需要麒麟浏览器（kylin-browser）和 agent-browser 工具已安装。
- 需要当前系统有可用的图形会话（X11/Wayland）。
- 浏览器启动超时阈值为 15 秒。
- 禁止生成总结、摘要或格式化报告，仅输出原始操作结果。
- 如果搜索结果为空，请尝试更换关键词重新搜索。
- 如果指定规格缺货，请选择相近的可用规格并告知用户。
- 如果价格超出范围，请停止操作并告知用户。
- 操作完成后报告商品名称、最终价格、所选规格。

## 异常处理

| 现象 | 说明 |
|---|---|
| `error: dependency_missing` | 目标环境缺少 agent-browser |
| `error: browser_timeout` / `browser_connect_failed` | 浏览器启动超时（15秒）或 agent-browser 无法连接远程调试端口，检查当前图形会话 |
| 搜索返回"网络异常"、"无法搜索" | **最常见原因：未登录京东**。执行登录引导流程（步骤 2），让用户手动登录后重新搜索 |
| 页面出现登录弹窗/二维码 | 暂停操作，告知用户"请完成京东登录"，展示快照，等待用户确认登录完成 |
| 搜索结果为空 | 更换关键词重新搜索（如"HP U盘 64GB"） |
| 指定规格缺货 | 选择相近的可用规格（如32G或128G），并告知用户 |
| 价格超出范围 | 停止操作并告知用户，与用户确认是否继续 |
| 页面元素找不到 | 刷新页面重试；若仍失败，停止任务并报错 |
| 页面加载慢 | 适当等待后重新获取快照 |

## 调用样例

**用户需求：** 在京东上买惠普 U盘 64G，100块左右，加入购物车。

完整执行步骤：

1. `bash scripts/kylin-browser-shopping-addcart-cli.sh open-shop jd --json`
2. `bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot --json` → 检测登录状态，若未登录则引导用户手动登录
3. `bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot-interactive --json` → 获取搜索框 ref
4. `bash scripts/kylin-browser-shopping-addcart-cli.sh fill @<ref> "惠普 U盘 64G" --json`
5. `bash scripts/kylin-browser-shopping-addcart-cli.sh press Enter --json` → 发起搜索
6. `bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot --json` → 检查搜索结果是否正常（排除"网络异常"）
7. `bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot-interactive --json` → 查看商品列表，识别符合条件的商品
8. `bash scripts/kylin-browser-shopping-addcart-cli.sh click @<ref> --json` → 点击进入商品详情页
9. `bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot-interactive --json` → 查看商品规格选项
10. `bash scripts/kylin-browser-shopping-addcart-cli.sh click @<ref> --json` → 选择规格
11. `bash scripts/kylin-browser-shopping-addcart-cli.sh find-ref "加入购物车" --json` → 精准搜索"加入购物车"元素，自动返回 ref
12. `bash scripts/kylin-browser-shopping-addcart-cli.sh click @<ref> --json` → 点击"加入购物车"（ref 由上一步返回）
13. `bash scripts/kylin-browser-shopping-addcart-cli.sh snapshot --json` → 确认添加成功