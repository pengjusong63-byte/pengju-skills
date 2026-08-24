---
name: kylin-browser-map-route
description: >-
  自动化地图路线查询：在地图网站（百度地图）搜索两地之间的地图路线，提取距离、预计耗时、主要道路等信息。
  当用户说"查一下北京到上海的路线"、"想看看从A到B开车怎么走"、"路线规划查询"时触发此 Skill。
  关键词：地图、路线、开车去、规划路线。
  本 skill 仅用于两地之间的驾车/公交/步行/骑行路线查询，不包含地图 POI 搜索、周边查询、街景查看等功能，用户要求后者时不得使用本 skill。
version: 0.0.1
author: ""
tags:
  - 生活
names:
  zh-CN: 地图路线查询
---

# 地图路线查询

通过 `scripts/kylin-browser-map-route-cli.sh` 本地 CLI 控制麒麟浏览器进行地图路线查询，所有底层调用（agent-browser、环境变量、浏览器启动、失败重试）均封装在脚本内。

## 使用场景

本 Skill 用于指导 agent 完成以下地图操作：

- 打开指定的地图网站（支持百度地图）
- 输入起点和终点
- 搜索地图路线

| 场景类型 | 示例语句 |
|---|---|
| **直接路线查询** | "查一下北京到上海的路线" |
| **简化表达** | "从广州开车去深圳怎么走" |
| **平台指定** | "用百度地图搜杭州到南京的路线" |
| **交通方式指定** | "搜一下成都到重庆的驾车路线" |

**触发关键词**：`地图`、`路线`、`开车去`、`规划路线`

## 输入说明

- `起点`：必填，出发地名称，如"北京市"。
- `终点`：必填，目的地名称，如"上海市"。
- `平台`：可选，地图网站名称，默认"百度地图"。
- `出行方式`：可选，枚举值，支持 `驾车`、`公交`、`步行`、`骑行`，默认 `驾车`。

## 输出说明

- 直接输出从百度地图页面提取的路线原始信息，禁止生成总结、摘要或格式化报告。
- 输出任务用时 X 秒。

## 权限边界

- 本 Skill 需要访问本地麒麟浏览器（kylin-browser）及远程调试端口（9225）。
- 需要 `agent-browser` CLI 工具可用。
- 不访问用户文件系统、剪贴板或网络配置。
- 不收集或上传用户路线数据至第三方。

## 执行流程

### 1. 打开百度地图

```bash
bash scripts/kylin-browser-map-route-cli.sh open-map --json
```

### 2. 等待页面加载并点击"路线"按钮

```bash
# 获取可交互元素快照，找到"路线"按钮的 ref
bash scripts/kylin-browser-map-route-cli.sh snapshot-interactive --json
```

从 snapshot 输出中识别"路线"按钮：搜索框 `textbox "搜地点、查公交、找路线"` 旁边的 `generic` 元素（带 `clickable [cursor:pointer]` 属性）即为"路线"图标按钮。

```bash
# 点击"路线"图标按钮（ref 取 generic 元素的 ref，如 e23）
bash scripts/kylin-browser-map-route-cli.sh click @<ref> --json
```

### 3. 填写起点和终点

```bash
# 获取可交互元素快照，找到起点/终点输入框的 ref
bash scripts/kylin-browser-map-route-cli.sh snapshot-interactive --json

# 填写起点和终点
bash scripts/kylin-browser-map-route-cli.sh fill @<ref1> "北京市" --json
bash scripts/kylin-browser-map-route-cli.sh fill @<ref2> "上海市" --json
```

### 4. 选择出行方式

如果用户指定的出行方式不是默认的"驾车"，则需执行此步骤：

```bash
# 获取快照，找到对应出行方式按钮的 ref
bash scripts/kylin-browser-map-route-cli.sh snapshot-interactive --json

# 点击目标出行方式按钮
bash scripts/kylin-browser-map-route-cli.sh click @<ref3> --json
```

### 5. 发起路线查询

在终点输入框已填写完毕的状态下，直接按下回车键发起搜索。

```bash
bash scripts/kylin-browser-map-route-cli.sh press Enter --json
```

### 6. 切换到搜索结果标签页（必须执行）

```bash
bash scripts/kylin-browser-map-route-cli.sh switch-result --json
```

## 约束限制

- 仅支持百度地图（map.baidu.com），不支持其他地图平台。
- 需要麒麟浏览器（kylin-browser）和 agent-browser 工具已安装。
- 需要当前系统有可用的图形会话（X11/Wayland）。
- 浏览器启动超时阈值为 15 秒。
- 禁止生成总结、摘要或格式化报告，仅输出原始路线信息。
- 零件输入建议添加省/市全称（如"北京市"、"上海市"）以提高搜索准确度。
- 如果搜索结果为空或提示"请选择正确的起点、途经点或终点"，请尝试更换关键词（如添加省/市全称）重新搜索。

## 异常处理

| 现象 | 说明 |
|---|---|
| `error: agent-browser 未安装或不可用` | 目标环境缺少 agent-browser |
| `error: 打开百度地图失败` / `连接浏览器失败` | 浏览器启动超时（15秒）或 agent-browser 无法连接远程调试端口，检查当前图形会话 |
| 搜索无结果 | 若提示"未找到路线"，尝试给起点/终点添加省/市全称后重新搜索 |
| 元素找不到 | 刷新页面重试；若仍失败，停止任务并报错 |
| 遇到登录弹窗 | 提示用户手动处理登录 |
| 结果解析失败 | 输出原始页面内容，由用户确认 |

## 调用样例

**用户需求：** 从北京到上海的驾车路线。

完整执行步骤：

1. `bash scripts/kylin-browser-map-route-cli.sh open-map --json`
2. `bash scripts/kylin-browser-map-route-cli.sh snapshot-interactive --json` → 获取"路线"按钮 ref
3. `bash scripts/kylin-browser-map-route-cli.sh click @<ref> --json`
4. `bash scripts/kylin-browser-map-route-cli.sh snapshot-interactive --json` → 获取起点/终点输入框 ref
5. `bash scripts/kylin-browser-map-route-cli.sh fill @<ref1> "北京市" --json`
6. `bash scripts/kylin-browser-map-route-cli.sh fill @<ref2> "上海市" --json`
7. `bash scripts/kylin-browser-map-route-cli.sh snapshot-interactive --json` → 确认出行方式已选中"驾车"
8. `bash scripts/kylin-browser-map-route-cli.sh press Enter --json` → 回车发起搜索
9. `bash scripts/kylin-browser-map-route-cli.sh switch-result --json`