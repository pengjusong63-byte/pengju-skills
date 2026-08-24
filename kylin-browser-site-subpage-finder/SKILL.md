---
name: kylin-browser-site-subpage-finder
description: >-
  自动查找网站的目标子页面（下载页、文档页、登录页、帮助中心、教程页面等）并在麒麟浏览器中打开。
  当用户表达"找到 XXX 的下载页面"、"XXX 的登录入口在哪"、"帮忙找找 XXX 的文档"、"找到 XXX 下 YYY 相关的页面"、"在 XXX 上找 YYY"、"打开 XXX 的 YYY 页面"等涉及访问特定网站子页面时触发。
  执行流程：用 web_fetch 抓取官网首页分析导航链接 → 构造常见子页面 URL 验证 → 在麒麟浏览器中打开最终目标页面。
  注意：当用户只是简单问"XX 的官网是什么"（仅需首页 URL），不需要此 skill。
  注意：此 skill 最终必须通过 CLI 在浏览器中打开页面，不能只返回文字或链接。
version: 0.0.1
author: ""
tags:
  - 技术
  - 产品
  - 生活
names:
  zh-CN: 站点子页面查找
---

# 站点子页面查找

通过 `scripts/kylin-browser-site-subpage-finder-cli.sh` CLI 在麒麟浏览器中打开目标子页面，所有浏览器调用（nohup、重定向）均封装在脚本内。网页内容抓取使用 `web_fetch` 工具完成。

## 执行原则

- 用户意图直接映射到一系列子命令，Agent 按步骤执行，不做选择、推导或二次确认。
- Agent 只执行：`bash scripts/kylin-browser-site-subpage-finder-cli.sh <子命令> [参数] --json`。
- **执行前必须先 cd 到 Skill 根目录**（即 SKILL.md 所在目录），可使用 `dirname "$(readlink -f "$0")"` 或 `cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"` 获取根目录路径。
- 禁止手写 `nohup`、`curl`、管道、重定向、`&&/||`、后台或命令替换。
- 成功时只转发 CLI 返回的 `result.message`；失败时只转发 `error`。

## 使用场景

用户要求查找网站上特定子页面（下载、文档、登录、帮助、教程、API、定价等）时使用。适用于需要定位并展示网站上具体页面的场景。

## 输入说明

- `目标网站/产品名称`：必填，如"麒麟软件"、"华为"。
- `目标页面类型`：必填，如下载页面、文档/教程、登录/注册、帮助/支持、价格/定价、API 文档等。
- `附加筛选条件`：可选，特定平台（Linux/Windows/macOS）、架构（x64/arm64）、语言版本。
- `用户提供的 URL`：可选，如果用户直接提供了 URL，优先使用。

## 输出说明

- 告知用户已打开的页面 URL 和页面标题。
- 如果页面包含多版本（不同操作系统、架构），列出所有版本。

## 执行流程

```
1. 解析意图 → 2. 定位官网首页 → 3. 查找目标子页面 → 4. 在浏览器中打开 → 5. 输出结果
```

**完成当前步骤前，不要提前执行后续步骤。**

### Step 1: 解析用户意图

从用户输入中提取目标网站名称、目标页面类型和附加筛选条件。

示例解析：
- "我想找到麒麟软件官方下载页面" → 网站: 麒麟软件, 页面: 下载
- "Python 官方教程文档在哪" → 网站: Python, 页面: 教程/文档
- "找到菜鸟教程下 Python 相关的页面" → 网站: 菜鸟教程 (runoob.com), 页面: Python 教程

### Step 2: 定位官网首页

**按以下优先级尝试，命中即止：**

#### 优先级 A: 用户直接提供了 URL
如果用户输入中已包含 URL（如"打开 https://example.com 的下载页面"），直接使用该 URL 作为官网首页，跳到 Step 3。

#### 优先级 B: 使用已知域名
对于知名网站，直接使用已知域名：

| 网站/产品 | 官网首页 |
|-----------|---------|
| 麒麟软件 | https://www.kylinos.cn |
| 华为 | https://www.huawei.com |
| 华为昇腾 | https://www.hiascend.com |
| 华为云 | https://www.huaweicloud.com |
| 阿里云 | https://www.aliyun.com |
| 腾讯云 | https://cloud.tencent.com |
| Python | https://www.python.org |
| Docker | https://www.docker.com |
| Docker Hub | https://hub.docker.com |
| Node.js | https://nodejs.org |
| 菜鸟教程 | https://www.runoob.com |
| 百度 | https://www.baidu.com |
| 微信 | https://weixin.qq.com |
| 腾讯 | https://www.tencent.com |
| 网易 | https://www.163.com |
| 哔哩哔哩 | https://www.bilibili.com |
| 抖音 | https://www.douyin.com |
| 京东 | https://www.jd.com |
| 淘宝 | https://www.taobao.com |
| 小米 | https://www.mi.com |
| 小米澎湃OS | https://hyperos.mi.com |
| OpenEuler | https://www.openeuler.org |
| OpenHarmony | https://www.openharmony.cn |
| 中科方德 | https://www.nfschina.com |
| 统信UOS | https://www.uniontech.com |
| 达梦数据库 | https://www.dameng.com |
| 人大金仓 | https://www.kingbase.com |
| 浪潮 | https://www.inspur.com |
| 中兴 | https://www.zte.com.cn |
| Nginx | https://nginx.org |
| Nginx (com) | https://www.nginx.com |
| Redis | https://redis.io |
| MySQL | https://www.mysql.com |
| PostgreSQL | https://www.postgresql.org |
| MongoDB | https://www.mongodb.com |
| Ubuntu | https://ubuntu.com |
| Debian | https://www.debian.org |
| CentOS | https://www.centos.org |
| Fedora | https://fedoraproject.org |
| Arch Linux | https://archlinux.org |
| OpenWrt | https://openwrt.org |
| RT-Thread | https://www.rt-thread.org |
| 鸿蒙/华为鸿蒙 | https://developer.harmonyos.com |

*(上表未列出的网站，跳到优先级 C)*

#### 优先级 C: 通过 web_fetch 探测常见域名
如果目标不在已知域名列表中，依次尝试 `https://www.{名称}.cn`、`https://www.{名称}.com`、`https://{名称}.cn`、`https://{名称}.com`。使用 `web_fetch` 抓取每个候选 URL，**第一个返回 200 且包含有效 HTML 内容的即为官网首页**。

### Step 3: 查找目标子页面

**按以下优先级查找目标子页面：**

#### 方案 A: 抓取首页分析导航链接（优先）
使用 `web_fetch` 获取官网首页，在页面内容中查找目标子页面的入口：
- 导航栏/菜单中的 `<a>` 标签
- Footer 区域链接
- 常见关键词匹配：`下载`/`Download`、`文档`/`Docs`、`登录`/`Login`、`注册`/`Register` 等

提取到的链接应属于同一主域名或官方 CDN 域名，`href` 路径包含常见子页面模式（如 `/download`、`/docs`、`/login`）。

**如果首页导航中直接找到了目标子页面链接 → 标记为候选 URL，跳到 Step 4。**

#### 方案 B: 构造常见子页面 URL 并验证
如果首页导航未找到目标入口，构造常见 URL 并用 `web_fetch` 验证：
- 下载: `/download`, `/downloads`, `/download-center`, `/support/download`
- 文档: `/docs`, `/documentation`, `/doc`, `/help`, `/support`, `/manual`
- 登录: `/login`, `/signin`, `/auth`, `/login.html`
- 注册: `/register`, `/signup`, `/register.html`
- 教程: `/tutorial`, `/tutorials`, `/learn`, `/guide`, `/guides`, `/course`
- API: `/api`, `/apis`, `/developer`, `/dev`
- 定价: `/pricing`, `/price`, `/plans`
- 关于: `/about`, `/about-us`

```
https://官网域名/download
https://官网域名/docs
https://官网域名/login
```

使用 `web_fetch` 依次验证，**第一个返回 200 且内容与目标页面类型匹配的即为目标页面**。

#### 方案 C: 产品型网站
如果目标是一个产品而非整个网站（如"麒麟桌面操作系统"）：
1. 在首页中找到产品主页链接
2. 使用 `web_fetch` 抓取产品主页
3. 在产品站内寻找目标子页面链接（重复方案 A 和方案 B）

#### 方案 D: 退而求其次
如果以上所有方案都未找到精确的目标子页面：
- 使用 `web_fetch` 抓取首页，寻找最接近的页面（如产品主页、支持中心、资源中心等）
- 如果确实找不到任何有效子页面，使用官网首页作为最终候选

### Step 4: 在浏览器中打开

找到候选子页面 URL 后：
1. 使用 `web_fetch` 抓取候选页面，确认页面可正常访问（200 状态码）
2. 检查页面标题和内容是否与目标页面类型匹配
3. 如果页面包含多版本（不同操作系统、架构），提取所有版本信息
4. **先 cd 到 Skill 根目录，再调用 CLI 在麒麟浏览器中打开最终目标页面**

```bash
# 先切换到 Skill 根目录（SKILL.md 所在目录）
cd /home/kylin/.kylinbot/workspace/skills/kylin-browser-site-subpage-finder
# 再调用 CLI 打开页面
bash scripts/kylin-browser-site-subpage-finder-cli.sh open-url "<最终目标页面URL>" --json
```

**硬性要求：**
- 不要只输出 URL 或文字说明，**必须调用 CLI 打开页面**
- CLI 调用必须作为最后一步执行，且**必须在输出查找结果之前调用**
- 如果确实找不到精确的目标子页面，退而求其次打开**最接近的有效页面**
- 对于"找到 XXX 下 YYYY 相关页面"这类意图，优先打开**最相关的一个具体子页面**
- 如果未调用 CLI，**必须返回错误并重新尝试调用，不得输出查找结果**
- 调用 `open-url` 只用一次，不得重复调用

### Step 5: 输出结果

简单输出页面信息即可，例如：

```
已打开 [网站/产品] [页面类型]：https://xxx
页面标题：xxx
页面描述：简要说明页面上有什么
```

## 约束限制

- 仅依赖 `web_fetch` 抓取网页内容定位目标，不依赖搜索引擎。
- 对于 SPA（单页应用）网站，`web_fetch` 可能抓取不到完整内容，此时以状态码正常为准，直接打开浏览器让用户查看渲染后的页面。
- 同一域名只保留一个最佳结果，不重复打开。
- 多语言网站优先匹配用户语言，用户未指定时优先中文。
- 有多个版本/架构选项时全部列出，不替用户筛选。

## 异常处理

| 现象 | 说明 |
|---|---|
| 官网首页无法定位 | 同时尝试 .com、.cn、.org、.com.cn 等常见后缀；中文产品优先 .cn，国际产品优先 .com |
| 页面访问失败（404/连接失败） | 检查 URL 路径拼写是否有其他变体；返回首页重新分析导航；尝试其他常见路径变体 |
| 动态加载的 SPA 页面 | web_fetch 结果可能不含完整内容，只要状态码正常即可，直接打开浏览器 |
| 找不到目标子页面 | 如实告知用户，提供最接近的近似页面，并在浏览器中打开该近似页面 |
| kylin-browser 未安装 | CLI 返回错误信息，提示用户检查 kylin-browser 是否可用 |
| 多版本页面 | 列出所有版本/架构选项，不替用户筛选 |

## 调用样例

**用户需求：** 我想找到麒麟软件镜像官方下载页面，我用的电脑是 x86_64 架构的。

**执行步骤：**

1. 解析意图 → 网站: 麒麟软件, 页面: 下载, 筛选: x86_64
2. 定位官网首页 → 已知域名：https://www.kylinos.cn
3. `web_fetch` 抓取 `https://www.kylinos.cn` → 首页导航未找到下载入口
4. `web_fetch` 抓取 `https://www.kylinos.cn/download` → 返回 200，包含下载链接
5. 确认页面内容匹配，提取下载版本信息
6. `cd /home/kylin/.kylinbot/workspace/skills/kylin-browser-site-subpage-finder && bash scripts/kylin-browser-site-subpage-finder-cli.sh open-url "https://www.kylinos.cn/download" --json`
7. 输出：已打开麒麟软件下载页面，包含 x86_64 版本镜像链接