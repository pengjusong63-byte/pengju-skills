---
name: kylin-browser-manager
description: >-
  仅控制"麒麟浏览器"桌面应用。支持动作+对象触发短语：
  打开麒麟浏览器、用麒麟浏览器打开<网址>、打开麒麟浏览器下载/历史记录/书签/设置页面、
  在麒麟浏览器里新建/关闭/切换到指定标签页、刷新/前进/后退、
  截图麒麟浏览器当前页面、获取麒麟浏览器页面快照/可交互元素快照、
  点击麒麟浏览器页面元素、在麒麟浏览器里按键/填写文本框、关闭麒麟浏览器。
  触发话术须同时包含应用与动作，例如"打开麒麟浏览器""用麒麟浏览器打开 baidu.com"。
  排除边界：不处理其他浏览器（Chrome/Firefox/Edge/360等）、未明确提到"麒麟浏览器"的通用浏览器操作。
version: 0.0.1
author: ""
tags:
  - 麒麟
names:
  zh-CN: 麒麟浏览器管理
---

# 麒麟浏览器管理

通过 `scripts/kylin-browser-manager-cli.sh` 本地 CLI 控制麒麟浏览器，所有底层调用（agent-browser、环境变量、失败重试）均封装在脚本内。

## 执行原则

- 用户意图直接映射到一条子命令，Agent 不做选择、推导或二次确认。
- Agent 只执行：`bash scripts/kylin-browser-manager-cli.sh <子命令> --json`（工作目录为 Skill 根目录）。
- 禁止手写 `agent-browser` 命令、设置环境变量、`dbus-send`、管道、重定向、`&&/||`、后台或命令替换。
- 成功时只转发 CLI 返回的 `result.message`；失败时只转发 `error`。

## 功能映射表

| 用户意图（触发词） | 子命令 |
|---|---|
| 打开麒麟浏览器 | `open` |
| 用麒麟浏览器打开 `<url>` | `open-url <url>` |
| 打开麒麟浏览器的下载页面 | `open-downloads` |
| 打开麒麟浏览器的历史记录页面 | `open-history` |
| 打开麒麟浏览器的书签/收藏夹页面 | `open-bookmarks` |
| 打开麒麟浏览器的设置页面 | `open-settings` |
| 在麒麟浏览器里新建标签页 | `tab-new` |
| 列出麒麟浏览器的所有标签页 | `tab-list` |
| 关闭麒麟浏览器的指定标签页 | `tab-close <tab_id>` |
| 切换到麒麟浏览器的指定标签页 | `tab-switch <tab_id>` |
| 在麒麟浏览器里前进 | `nav-forward` |
| 在麒麟浏览器里后退 | `nav-back` |
| 刷新麒麟浏览器页面 | `reload` |
| 截图麒麟浏览器当前页面 | `screenshot <filename>` |
| 获取麒麟浏览器页面快照 | `snapshot` |
| 获取麒麟浏览器可交互元素快照 | `snapshot-interactive` |
| 点击麒麟浏览器页面元素 | `click <ref>` |
| 在麒麟浏览器里按键 | `press <key>` |
| 在麒麟浏览器里填写文本框 | `fill <ref> <text>` |
| 关闭麒麟浏览器 | `close` |

调用方式（工作目录为 Skill 根目录）：

```bash
bash scripts/kylin-browser-manager-cli.sh <子命令> --json
```

回复规则：
- `ok=true` 时，只转发 `result.message`。
- `ok=false` 时，只转发 `error` 内容（如有 `hint` 可一并引用）。

子命令详情见：`bash scripts/kylin-browser-manager-cli.sh --help`

## 异常处理

| 现象 | 说明 |
|---|---|
| `error: 麒麟浏览器未找到` | `/usr/bin/kylin-browser` 不存在或未安装 |
| `error: agent-browser 未安装或不可用` | 目标环境缺少 agent-browser |
| `error: 打开麒麟浏览器失败` / 连接失败 | 当前无图形会话或 agent-browser 无法连接 |
| `error: 未知子命令` / 缺少参数 | 子命令或参数错误，参见 `--help` |
| 子命令执行成功但页面未变化 | 目标页面加载超时或网络问题 |

副作用说明：本 Skill 会实时控制桌面应用，可能拉起麒麟浏览器窗口、新建/关闭标签页、改变当前页面，操作不可撤销；依赖当前用户图形会话和 agent-browser。