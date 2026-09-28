---
name: kylin-browser-register-account
description: >-
   浏览器外部网站注册：通过麒麟浏览器直接打开外部网站的注册页面URL，自动填写注册表单并提交，完成账号注册。适用于用户说"帮我注册一个微博账号"、"注册一个139邮箱"等场景。关键词：注册、账号注册、申请账号、创建账号、注册账号、邮箱注册。
   本skill仅用于外部网站注册，不包含登录、密码找回、账号管理等功能。
version: 0.1.0
author: ""
tags:
  - 技术
names:
  zh-CN: 外部网站注册
---

# 外部网站注册

通过 `scripts/kylin-browser-register-account-cli.sh` 控制麒麟浏览器完成外部网站注册，所有底层调用（浏览器启动、页面导航、元素交互、失败重试）均封装在脚本内。

## 使用场景

- **直接访问注册页面**：根据用户指定平台，查找直接注册页面 URL，浏览器一步到位打开注册页，禁止先打开官网首页再通过点击导航跳转
- **先拿快照再索要信息**：打开注册页后，先获取快照识别表单字段，再根据实际字段向用户索要信息
- **填写与实时验证**：填写表单字段后触发失焦验证，通过快照检测页面提示（如"该手机号已被注册"），判断信息是否可用
- **安全验证处理**：遇到滑块/拼图等人工验证时提示用户手动完成，短信验证码则向用户索要
- **提交注册**：勾选用户协议后点击注册按钮，反馈注册结果

| 场景类型 | 示例语句 |
|---|---|
| 直接注册 | "帮我注册一个139邮箱" |
| 指定平台注册 | "注册一个微博账号" |
| 提供注册信息 | "帮我用手机号138xxxx注册一个抖音账号" |

触发关键词：注册、账号注册、申请账号、创建账号、注册账号

## 输入说明

- `注册网址`：必填，外部网站直接注册页面的 URL。
  - 用户仅提供平台名称时，Agent 应通过搜索引擎查找直接注册 URL，禁止使用官网首页 URL。
  - 常见平台参考（优先使用）：
    | 平台 | 直接注册 URL |
    |---|---|
    | 139邮箱 | `https://mail.10086.cn/default.html` |
    | 知乎账号 | `https://www.zhihu.com/signin` |
    | 微博 | `https://weibo.com/signup/signup.php` |
    | 京东 | `https://reg.jd.com/p/regPage` |
    | 小米账号 | `https://account.xiaomi.com/pass/register` |
- `注册信息`：按需提供。Agent 不应在打开注册页前索要全部信息，应先打开页面获取快照识别字段后再向用户索要。
  ```json
  {
    "phone": "13800138000",
    "password": "mypassword",
    "confirm_password": "mypassword",
    "email": "user@139.com",
    "nickname": "昵称"
  }
  ```
- `平台名称`：可选，如"139邮箱"。

## 输出说明

- 输出注册结果（成功/失败）及页面返回的提示信息。
- 遇到安全验证时，根据类型提示用户手动完成或索要短信验证码。
- 禁止生成与注册无关的总结或报告。

## Agent 行为准则

1. **先快照后询问**：打开注册页后，先获取快照识别实际字段，再基于字段向用户索要信息，不要预判。
2. **逐字段验证**：每个需要校验的字段填写后触发失焦并检查提示，发现"已被注册/已存在"立即停止。
3. **安全验证透明**：点击敏感按钮后立即检查安全验证，按规则分类处理，不得跳过检查直接索要验证码。
4. **一次成功**：信息齐全后一气呵成完成注册，不要在过程中穿插无关询问。
5. **记忆辅助**：流程开始前自动查询记忆中的用户注册偏好和历史记录（阶段零）；流程结束后自动保存本次关键结果到记忆。记忆仅用于减少重复输入和跟踪注册状态，不影响单次注册的正确决策。

## 权限边界

- 需要访问本地麒麟浏览器（kylin-browser）及远程调试端口（9229）。
- 需要 `agent-browser` CLI 工具可用。
- 不访问用户文件系统、剪贴板或网络配置。
- 不收集或上传用户注册信息至第三方。

## CLI 能力

| 用户意图 | CLI 路径 | 说明 |
|---|---|---|
| 打开注册页面 | `bash scripts/kylin-browser-register-account-cli.sh open-url <url> --json` | 启动浏览器并导航到注册页面 |
| 获取页面快照 | `bash scripts/kylin-browser-register-account-cli.sh snapshot --json` | 获取当前页面 DOM 快照 |
| 获取可交互元素快照 | `bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json` | 获取可交互元素列表及属性 |
| 点击页面元素 | `bash scripts/kylin-browser-register-account-cli.sh click <ref> --json` | 点击指定页面元素 |
| 填写输入框 | `bash scripts/kylin-browser-register-account-cli.sh fill <ref> <text> --json` | 在指定输入框中填入文本 |
| 模拟按键 | `bash scripts/kylin-browser-register-account-cli.sh press <key> --json` | 模拟键盘按键（如 Tab） |
| 选择下拉框 | `bash scripts/kylin-browser-register-account-cli.sh select <ref> <option> --json` | 在下拉框中选择选项 |
| 滚动页面 | `bash scripts/kylin-browser-register-account-cli.sh scroll <x> <y> --json` | 滚动页面到指定位置 |
| 切换标签页 | `bash scripts/kylin-browser-register-account-cli.sh tab <index> --json` | 切换到指定浏览器标签页 |
| 列出标签页 | `bash scripts/kylin-browser-register-account-cli.sh tab-list --json` | 列出所有浏览器标签页 |
| 关闭浏览器 | `bash scripts/kylin-browser-register-account-cli.sh close --json` | 关闭麒麟浏览器及 agent-browser 会话 |

## 执行流程

> **流程原则**：标有 **[自动]** 的步骤由 Agent 自动完成无需询问；标有 **[交互]** 的步骤需要用户参与。

### 阶段零：查询记忆中的注册偏好

> **记忆系统说明**：本 skill 集成了 KylinBot 的长期记忆（Memory）功能，能记住用户常用的注册信息（如手机号、邮箱前缀、昵称、常用注册平台等）和历史注册记录，减少重复输入。Agent 在以下步骤中会自动调用 `memory_recall` 读取记忆。

#### 0.1 [自动] 查询用户常用注册信息

调用 `memory_recall(query: "外部网站注册常用的手机号、邮箱、昵称、常用平台及历史注册记录")`。若命中：
- 自动记下已记录的手机号、邮箱、昵称、常用平台等信息，后续填表时优先作为默认值使用
- 向用户说明已从记忆中获取到部分信息，请用户确认或修改

若未命中，正常按输入说明向用户索要信息。

---

### 1. 打开注册页面

> 必须使用直接注册页面 URL（如 `https://reg.163.com/`），禁止使用官网首页。

```bash
bash scripts/kylin-browser-register-account-cli.sh open-url "https://mail.10086.cn/default.html" --json
```

用户仅提供平台名称时，Agent 应通过搜索引擎查找直接注册 URL。

### 2. 获取快照识别注册表单

```bash
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
```

识别字段：
- 用户名/手机号/邮箱输入框（根据 placeholder 或附近标签识别）
- 密码输入框（type 为 password 或 placeholder 含"密码"）
- 验证码输入框（如有）
- 用户协议勾选框（checkbox 类型，注意 `checked` 属性）
- 注册/提交按钮（显示"注册"、"同意协议并注册"、"立即注册"等文字）

### 3. 索要注册信息

> 不同平台表单差异大，基于快照中实际识别到的字段向用户索要，不要预判。

```text
"该页面需要填写以下信息：手机号、密码、昵称。请提供您要注册的手机号和密码等信息。"
```

- 用户已提供全部信息则跳过此步
- 信息不完整则只追问缺少的字段
- 等待用户回复后继续

### 4. 填写表单字段

```bash
bash scripts/kylin-browser-register-account-cli.sh fill @<ref1> "myusername" --json
bash scripts/kylin-browser-register-account-cli.sh fill @<ref2> "mypassword" --json
```

### 5. 字段填写后实时验证

#### 5.1 触发失焦验证

```bash
# 方式一：点击页面其他区域使输入框失焦
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
bash scripts/kylin-browser-register-account-cli.sh click @<other_element_ref> --json

# 方式二：模拟 Tab 键
bash scripts/kylin-browser-register-account-cli.sh press Tab --json
```

#### 5.2 获取快照检查验证提示

```bash
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
```

| 字段 | 常见验证提示 |
|---|---|
| 手机号 | "该手机号已被注册"、"手机号已存在"、"此手机号码已注册，可直接登录"、"号码格式不正确" |
| 用户名 | "该用户名已被注册"、"用户名已存在"、"该用户名不可用" |
| 邮箱 | "该邮箱已被注册"、"邮箱地址已被使用" |

#### 5.3 处理验证结果

- **提示"已被注册/已存在"**：立即停止，告知用户具体哪个字段被注册，请求更换后重试，不得继续提交
- **提示"可用/验证通过"**：继续填写下一个字段
- **无验证提示**：视为通过，继续后续流程

每个需验证的字段都应执行"填写 → 失焦触发验证 → 快照检查"流程。

### 6. 安全验证检测（通用子流程）

点击"获取验证码"或"注册/提交"等敏感操作后，立即获取快照检查安全验证：

```bash
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
```

**判定规则（按优先级）：**

1. **检测滑块/拼图/点选等人工验证元素**（最高优先级）：class/ID 含 `captcha`、`slider`、`nc_`、`geetest`、`tcaptcha` 等关键词，或快照文本含"请依次点击"、"拖动滑块"等提示。命中即判定为人工交互验证，不再检查其他规则。

2. **检测短信验证码**（次低优先级）：仅当规则1未命中时，检查"验证码已发送"、"短信已发送"、"已发送至手机"等提示。

3. **检测图片验证码**（最低优先级）：仅当规则1、2均未命中时，检查"请输入图片中的字符"、"图形验证码"等提示。

> 如果快照中同时包含滑块元素特征和"验证码"相关文字，按规则1处理，禁止误判为短信验证码。

| 验证类型 | 处理方式 |
|---|---|
| 滑块/拼图/点选/旋转验证（人工交互） | 提示用户手动完成，等待确认后继续 |
| 短信验证码 | 向用户索要收到的验证码并填入 |
| 图片/图形验证码 | 提示用户查看图片并告知验证码内容 |
| 无安全验证 | 继续后续步骤 |

### 7. 获取短信验证码（如需要）

```bash
# 1. 找到"获取验证码"按钮
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
# 2. 点击获取验证码
bash scripts/kylin-browser-register-account-cli.sh click @<sms_code_btn_ref> --json
# 3. 点击后立即获取快照，检查安全验证
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
```

根据步骤6判定规则处理：
- 检测到人工验证 → 提示用户手动完成，**禁止在完成前索要验证码**
- 检测到短信已发送 → 向用户索要验证码
- 无验证 → 继续后续步骤

> Agent 不得在未执行 `snapshot-interactive` 检查并确认无安全验证的情况下，直接向用户索要短信验证码。

### 8. 勾选用户协议

```bash
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
```

检查勾选框 `checked` 属性：
- `checked: true` → 已勾选，跳过点击
- `checked: false` → 点击勾选，再获取快照确认状态

### 9. 检测页面已有安全验证

点击敏感按钮前，检查页面是否已存在安全验证元素：

```bash
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json
```

如已出现安全验证，按步骤6处理。

### 10. 提交注册

```bash
bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json  # 找到注册按钮
bash scripts/kylin-browser-register-account-cli.sh click @<submit_ref> --json   # 点击注册
```

点击后按步骤6检测是否弹出安全验证，如有则处理完成后继续。

### 11. 查看注册结果

```bash
bash scripts/kylin-browser-register-account-cli.sh snapshot --json
```

### 12. 保存本次注册记录到记忆

> 注册结果明确后，自动将本次注册的关键信息保存到长期记忆，便于后续减少重复输入和跟踪注册状态。

#### 12.1 [自动] 保存注册结果

调用 `memory_recall(query: "外部网站注册历史记录、常用手机号、常用邮箱、常用昵称")`，查询是否已有同主题记忆：
- 若有 → 使用 `file_edit` 更新已有条目，追加本次注册记录
- 若无 → 使用 `file_write` 创建新条目（type: user），再更新 MEMORY.md 索引

记忆条目格式参考：
```yaml
name: "外部网站注册记录"
description: "用户历史注册的平台及账号信息"
type: "user"
```

保存信息包含：
- 注册平台名称
- 注册账号（手机号/邮箱/用户名）
- 注册时间
- 注册结果（成功/失败/待验证）
- 失败原因（如有）

## 约束限制

- 仅支持麒麟浏览器（kylin-browser）和 agent-browser 已安装的环境
- 需要可用图形会话（X11/Wayland）
- 浏览器启动超时阈值为 15 秒
- 必须使用直接注册页面 URL，禁止使用官网首页导航
- 不支持自动处理滑块/拼图/点选等人工验证，需用户手动干预
- 短信验证码需用户提供，Skill 不自行生成或猜测注册信息
- 禁止记录、存储或上传用户的注册信息
- 字段验证失败时须立即停止提交，告知用户并提供重试
- 记忆功能仅用于减少重复输入和状态跟踪，不得影响单次注册的独立决策

## 异常处理

| 现象 | 说明 |
|---|---|
| agent-browser 未安装 | 提示缺少 agent-browser 依赖 |
| 打开页面失败/连接浏览器失败 | 浏览器启动超时（15秒），检查图形会话 |
| 页面加载失败/404 | 确认注册 URL 是否正确 |
| 表单字段无法识别 | 刷新重试；仍失败则停止任务，提示用户手动填写 |
| 元素找不到 | 刷新重试；仍失败则停止任务 |
| 安全验证（滑块/拼图/点选/短信） | 按安全验证检测流程处理 |
| 手机号/用户名/邮箱已被注册 | 立即停止，告知用户该字段被注册，请求更换 |
| 注册失败 | 告知具体失败原因，建议更换信息后重试 |
| 遇到登录弹窗 | 提示用户手动处理 |
| 错误打开官网首页 | 关闭当前页面，搜索直接注册 URL 后重新打开 |

## 调用样例

**用户：** "帮我注册一个微博账号"

1. `bash scripts/kylin-browser-register-account-cli.sh open-url "https://weibo.com/signup/signup.php" --json` → 打开微博注册页
2. `bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json` → 识别字段：手机号、密码、用户协议勾选框、注册按钮
3. Agent 提示："微博注册页需要填写以下信息：**手机号、密码**。请提供您要注册的手机号和密码。" → 用户回复："手机号13800138000，密码mypassword123"
4. `bash scripts/kylin-browser-register-account-cli.sh fill @<phone_ref> "13800138000" --json`
   `bash scripts/kylin-browser-register-account-cli.sh fill @<pwd_ref> "mypassword123" --json`
5. `bash scripts/kylin-browser-register-account-cli.sh press Tab --json` → 失焦触发验证
   `bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json` → 检查页面提示
6. `bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json` → 找到用户协议勾选框，检查状态
   `bash scripts/kylin-browser-register-account-cli.sh click @<agree_ref> --json` → 勾选
   `bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json` → 确认已勾选
7. `bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json` → 找到注册按钮 ref
   `bash scripts/kylin-browser-register-account-cli.sh click @<submit_ref> --json` → 点击注册
8. `bash scripts/kylin-browser-register-account-cli.sh snapshot-interactive --json` → 检查安全验证
9. `bash scripts/kylin-browser-register-account-cli.sh snapshot --json` → 查看注册结果