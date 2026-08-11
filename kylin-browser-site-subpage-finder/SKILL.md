---
name: kylin-browser-site-subpage-finder
description: >-
  自动查找网站的目标子页面（下载页、文档页、登录页、帮助中心、教程页面等）并在麒麟浏览器中打开，让用户可见。
  当用户表达"找到 XXX 的下载页面"、"XXX 的登录入口在哪"、"帮忙找找 XXX 的文档"、"找到 XXX 下 YYY 相关的页面"、"在 XXX 上找 YYY"、"打开 XXX 的 YYY 页面"等涉及访问特定网站子页面时触发。
  执行流程：用 web_fetch 抓取官网首页分析导航链接 → 构造常见子页面 URL 验证 → 在麒麟浏览器中打开最终目标页面并展示给用户。
  适用于任何需要定位并展示网站上特定页面的场景（下载、文档、API、支持、定价、教程分类等）。
  注意：当用户只是简单问 "XX 的官网是什么"（仅需要首页 URL），不需要此 skill；
  注意：此 skill 最终必须调用 nohup kylin-browser <URL> & 在浏览器中打开页面，不能只返回文字或链接。
---

# 站点子页面查找器 (Site Subpage Finder)

## 可用工具

- `web_fetch`：抓取网页内容，分析页面结构、导航链接和版本信息
- `kylin-browser`：在麒麟浏览器中打开指定 URL。

## 工作流程

```
1. 解析意图 → 2. 定位官网首页 → 3. 查找目标子页面 → 4. 在浏览器中打开验证 → 5. 输出结果
```

**完成当前步骤前，不要提前执行后续步骤。**

### Step 1: 解析用户意图

从用户输入中提取：
- **目标网站/产品名称**：如"麒麟软件"、"华为"
- **目标页面类型**：下载页面、文档/教程、登录/注册、帮助/支持、价格/定价、API 文档、商品等
- **附加筛选条件**（可选）：特定平台（Linux/Windows/macOS）、架构（x64/arm64）、语言版本
- **用户提供的 URL**（可选）：如果用户直接提供了 URL，优先使用

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
| Nginx | https://www.nginx.com |
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
| 鸿蒙 | https://developer.harmonyos.com |
| 华为鸿蒙 | https://developer.harmonyos.com |

*(上表未列出的网站，跳到优先级 C)*

#### 优先级 C: 通过 `web_fetch` 探测常见域名
如果目标不在已知域名列表中，尝试以下策略构造官网 URL：

1. **常见域名模式**：`https://www.{拼音或英文名}.cn`、`https://www.{拼音或英文名}.com`、`https://{拼音或英文名}.cn`、`https://{拼音或英文名}.com`
2. 使用 `web_fetch` 依次抓取这些候选 URL，**第一个返回 200 且包含有效 HTML 内容的即为官网首页**
3. 如果所有常见域名都失败，使用 `web_fetch` 抓取用户提供的最接近 URL（如用户提到的第三方导航站）

**确定官网首页后，记录其域名，进入 Step 3。**

### Step 3: 查找目标子页面

已知官网首页 URL 后，**按以下优先级查找目标子页面**：

#### 方案 A: 抓取首页分析导航链接（优先）
使用 `web_fetch` 获取官网首页，在页面内容中查找目标子页面的入口：
- 导航栏/菜单中包含的 `<a>` 标签
- Footer 区域链接
- 常见关键词：
  - 下载: `下载`, `Download`, `Downloads`, `Download Center`
  - 文档: `文档`, `Docs`, `Documentation`, `Help`, `Support`
  - 登录: `登录`, `Login`, `Sign in`
  - 注册: `注册`, `Register`, `Sign up`

提取到的链接应满足：
- 属于同一主域名或官方 CDN 域名
- `href` 路径包含常见子页面模式（如 `/download`, `/docs`, `/login`）

**如果首页导航中直接找到了目标子页面链接 → 标记为候选 URL，跳到 Step 4。**

#### 方案 B: 构造常见子页面 URL 并验证
如果首页导航未找到目标入口，可尝试构造常见 URL 并用 `web_fetch` 验证：
- 下载: `/download`, `/downloads`, `/download-center`, `/download-center.html`, `/support/download`, `/support/trial/download`
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

使用 `web_fetch` 依次验证这些候选 URL，**第一个返回 200 且内容与目标页面类型匹配的即为目标页面**。

#### 方案 C: 产品型网站
如果目标是一个产品而非整个网站（如"麒麟软件"下有"麒麟桌面操作系统"等）：
1. 在首页中找到产品主页链接
2. 使用 `web_fetch` 抓取产品主页
3. 在产品站内寻找目标子页面链接（重复方案 A 和方案 B）

#### 方案 D: 退而求其次
如果以上所有方案都未找到精确的目标子页面：
- 使用 `web_fetch` 抓取首页，寻找**最接近的页面**（如产品主页、支持中心、资源中心等）
- 如果确实找不到任何有效子页面，使用官网首页作为最终候选

### Step 4: 在浏览器中打开并验证结果（必须执行）

找到候选子页面 URL 后，**按以下流程执行**：

1. 使用 `web_fetch` 抓取候选页面，确认页面可正常访问（200 状态码）
2. 检查页面标题和内容是否与目标页面类型匹配（如下载页面应有下载按钮/链接列表）
3. 如果页面包含多版本（不同操作系统、架构），使用 `web_fetch` 提取所有版本及其下载链接
4. **调用 `kylin-browser` 打开最终目标页面**：必须使用 `nohup kylin-browser <URL> >/dev/null 2>&1 &` 后台运行。

**硬性要求**：
- 不要只输出 URL 或文字说明，**必须调用 `kylin-browser` 打开页面**
- `kylin-browser` 必须作为最后一步执行，且**必须在输出任何查找结果之前调用**
- **必须使用 `nohup kylin-browser <URL> >/dev/null 2>&1 &` 后台运行**
- **不得以任何文字、勾选符号或表情符号替代 `kylin-browser` 调用**；严禁在未调用 `kylin-browser` 时输出"页面已打开 ✅"、"已用麒麟浏览器打开"等描述
- 如果确实找不到精确的目标子页面，退而求其次打开**最接近的有效页面**（如官网首页、产品主页、支持中心），并在输出中说明"这是目前能找到的最接近页面"
- 对于"找到 XXX 下 YYYY 相关页面"这类意图，优先打开**最相关的一个具体子页面**（如 Python3 教程页），而不是只打开首页；若存在多个强相关页面，可打开聚合入口/分类页
- 返回给用户的输出中，必须包含一句明确说明页面已被打开的内容
- 如果未调用 `kylin-browser`，**必须返回错误并重新尝试调用，不得输出查找结果**
- 调用 `kylin-browser` 时只用一次，不得重复调用

### Step 5: 输出结果

简单输出页面信息即可，例如：

```
已打开 [网站/产品] [页面类型]：https://xxx
页面标题：xxx
页面描述：简要说明页面上有什么
```

## 常见问题处理

### 官网不易找到
- 同时尝试常见域名后缀（.com, .cn, .org, .com.cn）
- 如果目标是一个中文公司/产品，优先尝试 .cn 域名；如果是国际产品，优先尝试 .com

### 多语言网站
- 部分网站有 `/zh/`、`/en/` 等语言前缀，自动匹配用户语言或提供双语选项
- 如果用户明确指定语言，优先查找该语言版本

### 页面访问失败（404/连接失败）
- 检查 URL 路径拼写是否有其他变体
- 返回首页，重新使用 `web_fetch` 继续分析导航
- 尝试方案 B 中的其他常见路径变体
- 如确实找不到，告知用户并提供最接近的 URL

### 动态加载的 SPA 页面
有些网站（如 React/Vue 单页应用）的 `web_fetch` 结果可能不含完整内容。这种情况下：
- 使用 `web_fetch` 抓取常见子页面 URL，即使返回内容不完整，只要状态码正常即可
- 使用 `nohup kylin-browser <URL> >/dev/null 2>&1 &` 在麒麟浏览器中打开页面，让用户看到渲染后的内容

## 工具使用指南

### 1. 定位官网首页

**已知域名可直接使用**（如 `https://www.kylinos.cn`），对于不确定的域名：

```
web_fetch url: https://www.目标名称.com
web_fetch url: https://www.目标名称.cn
web_fetch url: https://www.目标名称.com.cn
```

第一个返回 200 的即为官网首页。

### 2. 抓取首页分析导航

使用 `web_fetch` 抓取官网首页：

```
url: https://www.kylinos.cn
```

在返回内容中查找包含 `下载`、`Download` 等关键词的 `<a>` 标签，提取 `href`。

### 3. 构造并验证常见子页面 URL

如果首页导航未找到入口，构造常见 URL 并用 `web_fetch` 验证：

```
url: https://www.kylinos.cn/download
url: https://www.kylinos.cn/docs
url: https://www.kylinos.cn/login
```

第一个返回 200 且内容匹配的即为目标子页面。

### 4. 验证并打开最终页面

使用 `web_fetch` 验证候选 URL 可访问且内容匹配，然后必须使用 `nohup kylin-browser <URL> >/dev/null 2>&1 &` 在麒麟浏览器中打开：

```
url: https://www.kylinos.cn/download
```

### 链接提取技巧

| 场景 | 方法 | 说明 |
|------|------|------|
| 找下载入口 | `web_fetch` + 关键词匹配 | 在首页 HTML 中搜索 `下载`、`Download` |
| 找文档入口 | `web_fetch` + 关键词匹配 | 搜索 `文档`、`Docs`、`Documentation` |
| 找登录入口 | `web_fetch` + 关键词匹配 | 搜索 `登录`、`Login`、`Sign in` |
| 找不到入口 | `web_fetch` + 构造常见路径 | 尝试 `/download`, `/docs`, `/login` 等常见路径 |
| 需要用户看到页面 | `nohup kylin-browser <URL>>/dev/null 2>&1  &`（RunCommand 设置 `blocking=false`） | 在麒麟浏览器中打开最终 URL（后台运行防超时） |

### 示例：查找麒麟软件下载页面

```
用户需求：我想找到麒麟软件镜像官方下载页面，我用的电脑是 x86_64 架构的。

任务步骤：
1. 解析意图：网站=麒麟软件，页面=下载，筛选=x86_64

2. 定位官网首页（Step 2）：
   → 已知域名：https://www.kylinos.cn（在已知域名列表中）

3. 查找目标子页面（Step 3）：
   方案A - 抓取首页分析导航：web_fetch url: https://www.kylinos.cn
   → 假设首页导航中未找到"下载"入口

   方案B - 构造常见子页面 URL：
   web_fetch url: https://www.kylinos.cn/download
   → 返回 200，页面包含下载链接 → 标记为候选 URL

4. 验证并打开（Step 4）：
   web_fetch url: https://www.kylinos.cn/download
   → 确认页面可访问、包含下载内容
   nohup kylin-browser https://www.kylinos.cn/download >/dev/null 2>&1 &

5. 输出结果：已打开麒麟软件下载页面（https://www.kylinos.cn/download），包含 x86_64 / amd64 版本镜像链接

注意事项：
- 优先从首页导航中提取链接，找不到再构造常见路径
- 如果首页没有直接下载入口，尝试 /download、/download-center.html、/downloads 等
- 必须使用 `nohup kylin-browser <URL> >/dev/null 2>&1 &` 后台运行
- 操作完成后报告：官网首页 URL、目标子页面 URL、页面标题、x86_64 版本下载链接
```

## 关键原则

1. **纯 web_fetch 驱动** — 完全依赖 `web_fetch` 抓取网页内容定位目标，不依赖任何搜索引擎
2. **已知域名优先** — 对于知名网站，直接使用已知域名，避免不必要的网络探测
3. **构造验证** — 找不到导航链接时，构造常见子页面路径并用 `web_fetch` 验证
4. **必须打开浏览器** — 找到有效子页面 URL 后，**必须调用 `nohup kylin-browser <URL> >/dev/null 2>&1 &`** 用麒麟浏览器中打开
5. **验证优先** — 用 `web_fetch` 对候选 URL 做实际访问和内容匹配确认后再 `kylin-browser`
6. **简单输出** — 页面打开后，简单输出页面信息即可
7. **诚实告知** — 如果找不到确切页面，如实告知并提供最佳近似结果，同时用 `kylin-browser` 打开该近似页面
8. **多语言支持** — 用户说中文则优先查找中文版页面，但必要时也尝试英文版
9. **多版本全列出** — 有多个版本/架构选项时全部列出，不替用户筛选