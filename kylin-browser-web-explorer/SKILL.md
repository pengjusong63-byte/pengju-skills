---
name: kylin-browser-web-explorer
description: >-
  自动化搜索引擎查找：自动使用百度/必应搜索网页，并在新标签页中打开前几条相关网页链接。
  当用户说"帮我找到 XXX 页面"、"帮我找2个银河麒麟镜像相关的网页"、"搜索 XXX 并打开前几个结果"时触发此 Skill。
  关键词：搜索、找网页、打开网页、bing。
  本 skill 仅用于网页搜索与浏览，不包含地图路线查询、POI 搜索、周边查询、本地文件打开、查看本地 HTML 文件、录音或录制音频等功能，用户要求后者时不得使用本 skill。
version: 0.0.1
author: ""
tags:
  - 学术
  - 生活
names:
  zh-CN: 网页浏览
---

# 网页浏览 Skill

通过 `scripts/kylin-browser-web-explorer-cli.sh` 本地 CLI 控制麒麟浏览器进行网页搜索与浏览，所有底层调用（agent-browser、环境变量、浏览器启动、失败重试）均封装在脚本内。

## 执行原则

- 用户意图直接映射到一系列子命令，Agent 按步骤执行，不做选择、推导或二次确认。
- Agent 只执行：`bash scripts/kylin-browser-web-explorer-cli.sh <子命令> [参数] --json`（工作目录为 Skill 根目录）。
- 禁止手写 `agent-browser` 命令、设置环境变量、`nohup`、`curl`、管道、重定向、`&&/||`、后台或命令替换。
- 脚本已封装退出码：0=成功、1=一般错误、2=无效参数、3=资源未找到、5=冲突。
- 成功时只转发 CLI 返回的 `result.message`；失败时只转发 `error`。

## 功能映射表

| 用户意图（触发词） | 子命令 |
|---|---|
| 打开麒麟浏览器并导航到搜索引擎 | `open-search <engine>` |
| 获取页面快照 | `snapshot` |
| 获取可交互元素快照 | `snapshot-interactive` |
| 点击页面元素 | `click <ref>` |
| 在文本框中输入文本 | `fill <ref> <text>` |
| 模拟按键 | `press <key>` |
| 执行 JavaScript 提取搜索结果 | `eval <js_code>` |
| 在新标签页中打开链接 | `tab-new <url>` |
| 列出所有标签页 | `tab-list` |
| 切换到指定标签页 | `tab-switch <index>` |
| 关闭麒麟浏览器 | `close [--yes]` |

调用方式（工作目录为 Skill 根目录）：

```bash
bash scripts/kylin-browser-web-explorer-cli.sh <子命令> [参数] --json
```

## 使用场景

本 Skill 用于指导 agent 完成以下网页搜索与浏览操作：

- 使用百度/必应搜索引擎搜索指定关键词
- 提取搜索结果中的有效网页链接
- 过滤广告、重定向、重复内容等无效链接
- 优先选择官方网站和高品质页面
- 在新标签页中打开前 N 条相关网页链接

## 触发场景

当用户表达以下意图时，Agent 会自动应用此 Skill：

| 场景类型 | 示例语句 |
|---|---|
| **查找单个页面** | "帮我找到银河麒麟操作系统页面" |
| **指定数量查找** | "帮我找2个麒麟软件相关的网页" |
| **搜索并打开结果** | "搜索华为手机并打开前几个结果" |

**触发关键词**：`搜索`、`找网页`、`打开网页`

## 支持的平台

- **百度** (www.baidu.com) - 主要支持的搜索引擎
- **必应** (www.cn.bing.com) - 支持的搜索引擎

## 输入说明

- `搜索关键词`：必填，用户要搜索的内容，如"银河麒麟操作系统"。
- `打开数量`：可选，需要打开的网页数量，默认 2-3 个，最多不超过 10 个。
- `搜索引擎`：可选，搜索引擎名称，支持 `百度`、`必应`，默认 `百度`。

## 输出说明

- 直接输出搜索结果中提取的链接信息，禁止生成总结、摘要或格式化报告。

## 注意事项

- 优先选择官方网站和高品质页面。
- 避免重复域名，同一域名尽量只保留一个结果。
- 如果搜索结果为空，告知用户没有搜索到相关内容。
- 如果用户未指定打开数量，默认打开 2-3 个网页。
- 执行 `eval` 提取搜索结果时，需根据搜索引擎选择对应的 DOM 选择器。
- 百度搜索可能会触发验证码，如果出现百度验证页面，需提示用户手动完成验证。

## 操作流程

### 1. 打开搜索引擎

```bash
bash scripts/kylin-browser-web-explorer-cli.sh open-search baidu --json
```

> 支持的 engine 参数：`baidu`（百度）、`bing`（必应）

### 2. 输入搜索关键词

```bash
# 获取可交互元素快照，找到搜索输入框的 ref
bash scripts/kylin-browser-web-explorer-cli.sh snapshot-interactive --json

# 在搜索输入框中填写关键词
bash scripts/kylin-browser-web-explorer-cli.sh fill @<ref> "银河麒麟操作系统" --json

# 按下回车键发起搜索
bash scripts/kylin-browser-web-explorer-cli.sh press Enter --json
```

### 3. 检测百度验证（可选）

百度搜索可能触发验证码，在提取结果前应先检测是否存在验证页面。

```bash
# 获取页面快照，检测是否出现百度验证
bash scripts/kylin-browser-web-explorer-cli.sh snapshot --json
```

如果快照内容包含"验证"、"请输入验证码"、"百度安全验证"等字样，则说明触发了验证码。此时执行以下操作：

```bash
# 获取可交互元素快照，查看页面上的验证元素
bash scripts/kylin-browser-web-explorer-cli.sh snapshot-interactive --json
```

**遇到验证码时的处理流程：**
1. 告知用户"百度搜索触发了验证码，请手动完成验证"
2. 将浏览器页面快照展示给用户
3. 等待用户手动完成验证后，继续执行后续步骤

### 4. 提取搜索结果链接

等待搜索结果加载完成后，使用 `eval` 执行 JavaScript 提取链接。

**百度搜索引擎：**

```bash
bash scripts/kylin-browser-web-explorer-cli.sh eval '((n) => {
   const results = [...document.querySelectorAll("h3 a")]
      .slice(0, n)
      .map((a, i) => ({
         index: i + 1,
         text: a.innerText,
         href: a.href
      }));
   return results;
})(3)' --json
```

**必应搜索引擎：**

```bash
bash scripts/kylin-browser-web-explorer-cli.sh eval '((n) => {
   const items = document.querySelectorAll("li.b_algo > h2 a, li.b_ans > h2 a");
   return [...items].slice(0, n).map((a, i) => ({
      index: i + 1,
      text: a.innerText.trim(),
      href: a.href
   }));
})(3)' --json
```

### 5. 在新标签页中打开链接

```bash
# 打开提取到的有效链接
bash scripts/kylin-browser-web-explorer-cli.sh tab-new "https://example.com" --json
```

## 示例流程

**用户需求：** 搜索"银河麒麟镜像"并打开前 2 个相关网页。

完整执行步骤：

1. `bash scripts/kylin-browser-web-explorer-cli.sh open-search baidu --json`
2. `bash scripts/kylin-browser-web-explorer-cli.sh snapshot-interactive --json` → 获取搜索输入框 ref
3. `bash scripts/kylin-browser-web-explorer-cli.sh fill @<ref> "银河麒麟镜像" --json`
4. `bash scripts/kylin-browser-web-explorer-cli.sh press Enter --json`
5. `bash scripts/kylin-browser-web-explorer-cli.sh snapshot --json` → 检测是否出现百度验证；若出现则提示用户手动验证后继续
6. `bash scripts/kylin-browser-web-explorer-cli.sh eval '((n) => { const results = [...document.querySelectorAll("h3 a")].slice(0, n).map((a, i) => ({ index: i + 1, text: a.innerText, href: a.href })); return results; })(2)' --json` → 提取前 2 条有效链接
7. 过滤无效链接（广告、重定向、重复内容等），选择有效链接
8. `bash scripts/kylin-browser-web-explorer-cli.sh tab-new "<有效链接1>" --json`
9. `bash scripts/kylin-browser-web-explorer-cli.sh tab-new "<有效链接2>" --json`
10. `bash scripts/kylin-browser-web-explorer-cli.sh tab-list --json` → 查看所有标签页
11. `bash scripts/kylin-browser-web-explorer-cli.sh tab-switch 1 --json` → 切换回搜索结果标签页展示给用户

## 异常处理

| 现象 | 说明 |
|---|---|
| `error: agent-browser 未安装或不可用` | 目标环境缺少 agent-browser |
| `error: 打开搜索引擎失败` / `连接浏览器失败` | 浏览器启动超时（15秒）或 agent-browser 无法连接远程调试端口，检查当前图形会话 |
| 搜索结果为空 | 告知用户没有搜索到相关内容，建议更换关键词 |
| 提取链接为空 | 检查页面是否加载完成，或百度页面结构是否发生变化 |
| 无效链接 | 跳过广告链接、推广链接、登录/重定向页面、空连接 |
| 重复域名 | 同一域名尽量只保留一个结果 |
| 新标签页打开失败 | 检查链接是否为有效的 HTTP/HTTPS 网址 |
| 网络加载失败 | 让用户检查网络连接，确保浏览器可以访问互联网 |
| 页面元素未找到 | 检查元素是否在页面上可见，是否被其他元素遮挡，必要时等待页面加载完成 |
| 百度验证码 | 搜索结果页面出现"百度安全验证"或"请输入验证码"字样；提示用户"百度搜索触发了验证码，请手动完成验证"，展示快照给用户，等待用户手动验证后继续 |

## 常见问题

- **搜索结果为空**：参考「异常处理 > 搜索结果为空」流程处理。
- **提取链接为空**：检查页面是否加载完成，或百度页面结构是否发生变化；可尝试等待 1-2 秒后重新提取。
- **如何切换搜索引擎**：在 `open-search` 子命令中指定 engine 参数，如 `open-search bing`。
- **遇到百度验证码怎么办**：参考「操作流程 > 检测百度验证」步骤，使用 `snapshot` 检测验证页面，若出现则提示用户手动完成验证，完成后继续执行后续步骤。