# 麒麟浏览器（kylin-browser）Skill 依赖安装说明2

涵盖了 8 个 Skill 的公共依赖及安装步骤：

| Skill | 用途 |
|---|---|
| kylin-browser-manager | 麒麟浏览器基本管理（打开/关闭/标签页等） |
| kylin-browser-web-explorer | 网页搜索浏览 |
| kylin-browser-ticket-booking | 携程订票 |
| kylin-browser-shopping-addcart | 京东加购 |
| kylin-browser-map-route | 百度地图路线查询 |
| kylin-browser-site-subpage-finder | 网站子页面发现 |
| kylin-browser-oa-permission | OA流程自动化（数字麒麟权限申请、请假申请等） |
| kylin-browser-register-account | 外部网站注册（微博、139邮箱等） |

---

## 依赖总览

| 依赖 | 必需 | 说明 |
|---|---|---|
| kylin-browser | 是 | 麒麟浏览器桌面应用，位于 `/usr/bin/kylin-browser` |
| agent-browser | 是（site-subpage-finder 除外） | Vercel 出品的浏览器自动化 CLI，Rust 原生二进制 |

> agent-browser 是 Rust 原生二进制，**不依赖 Node.js**。可通过 deb 包或 npm 安装。

---

## 安装步骤

### 1. 安装麒麟浏览器（kylin-browser）arm64 版本

通过 deb 包安装：

```bash
sudo dpkg -i <path>/kylin-browser-stable_2.0.9.0-2k35.0_arm64.deb
```

安装后确认可执行文件存在：

```bash
which kylin-browser
# 预期输出：/usr/bin/kylin-browser
```

### 2. 安装 agent-browser arm64 版本

#### 方式一（推荐）：通过 deb 包安装

```bash
# 安装 agent-browser deb 包
sudo dpkg -i <path>/agent-browser_0.27.3-1_arm64.deb

# 验证安装
agent-browser --version
```

#### 方式二：通过 npm 全局安装

如果无法使用 deb 包，可通过 npm 安装（需要先安装 Node.js）：

```bash
# 安装 Node.js（如已安装可跳过）
# 方式 A：使用 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install --lts

# 方式 B：使用系统包管理器
# sudo apt install nodejs npm

# 全局安装 agent-browser
npm install -g agent-browser

# 验证安装
agent-browser --version
```

> agent-browser 的 npm 包分发的是 Rust 原生二进制（约 11MB），安装后即为独立可执行文件，不依赖 Node.js 运行时。

### 3. 配置 kybot 的 web_fetch

安装好 kybot 后，修改 kybot 的 `config.toml` 配置文件（默认路径 `~/.kylinbot/config.toml` ），在最下面追加以下配置，然后重启 kybot：

```toml
[web_fetch]
enabled = true
allowed_domains = ["*"]
blocked_domains = []
allowed_private_hosts = []
max_response_size = 300000
timeout_secs = 15
```

### 4. 验证安装

```bash
# 测试 agent-browser 能否正常调用
agent-browser --version

# 测试能否找到麒麟浏览器
ls -l /usr/bin/kylin-browser
```

---

## 各 Skill 的额外依赖

### kylin-browser-manager

无额外依赖。

### kylin-browser-web-explorer

- 远程调试端口：**9226**（脚本默认使用）
- 网络访问：百度（www.baidu.com）或必应（www.cn.bing.com）
- **注意**：百度搜索可能会弹出图片验证码，需用户手动完成验证后方可继续搜索

### kylin-browser-ticket-booking

- 远程调试端口：**9228**（脚本默认使用）
- 网络访问：携程（trains.ctrip.com）
- **注意**：需要用户已登录携程账号，Agent 无法自动填写密码和验证码，会弹出登录页面等待用户手动完成登录

### kylin-browser-shopping-addcart

- 远程调试端口：**9224**（脚本默认使用）
- 网络访问：京东（jd.com）
- **注意**：需要用户已登录京东账号，Agent 无法自动填写密码和验证码，会弹出登录页面等待用户手动完成登录

### kylin-browser-map-route

- 远程调试端口：**9225**（脚本默认使用）
- 网络访问：百度地图（map.baidu.com）

### kylin-browser-site-subpage-finder

- **不需要** agent-browser
- 直接通过 `nohup kylin-browser` 启动浏览器
- 需 Agent 端 `web_fetch` 工具可用

### kylin-browser-oa-permission

- 远程调试端口：**9229**（脚本默认使用）
- 网络访问：OA 门户（portal.kylinos.cn）及 SSO（sso.kylinos.cn）
- 支持两种登录方式：
  - **用户名+密码+短信验证码**：用户提供登录信息，Agent 填写后触发蓝信验证码，需用户手动提供验证码
  - **Cookie 免密登录**：依赖 `~/.kylinbot/workspace/cookie.txt` 中有效的 `cvaToken`（有效期约2小时），token 过期后回落至用户名密码登录
- **注意**：提交前需要用户核实信息并确认，Agent 不得在用户未确认的情况下直接提交

### kylin-browser-register-account

- 远程调试端口：**9229**（脚本默认使用）
- 网络访问：各种外部网站注册页面（如 139邮箱、微博、知乎、京东等）
- 需搜索引擎查找直接注册 URL，禁止使用官网首页导航跳转
- **注意**：不支持自动处理滑块/拼图/点选等人工验证，需用户手动干预；短信验证码需用户提供

---

## 常见问题

### agent-browser 命令找不到

```bash
# deb 包安装后检查路径
which agent-browser
# 或
dpkg -L agent-browser  # 列出 deb 包安装的文件

# npm 安装后检查
npm list -g agent-browser
```

### 麒麟浏览器未找到

```bash
# 确认麒麟浏览器安装路径
which kylin-browser
# 或
ls /usr/bin/kylin-browser

# 如果未安装，通过 deb 包安装
```

### web_fetch 不可用

如果 Agent 提示 `web_fetch` 工具找不到或不可用，请检查：

```bash
# 1. 确认 kybot 的 config.toml 中已配置 web_fetch 段
cat ~/.kylinbot/config.toml | grep -A 6 "\[web_fetch\]"

# 2. 确认配置后已重启 kybot
# 3. 如果配置正确仍不可用，检查 kybot 版本是否支持 web_fetch
```