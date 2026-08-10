---
name: kylin-browser-manager
description: >-
  仅针对麒麟浏览器的自动化管理Skill。支持打开任意网址、内部管理页面（下载/历史/书签/设置）、标签页管理（新建/关闭/切换）、浏览器导航（前进/后退/刷新）等操作。
  当用户明确提到"麒麟浏览器"并说"打开麒麟浏览器的下载页面"、"打开设置页面"时触发此 Skill。
  关键词：麒麟浏览器、kylin browser、麒麟浏览器下载、麒麟浏览器历史、麒麟浏览器书签、麒麟浏览器设置、麒麟浏览器新建标签页、麒麟浏览器刷新页面。
---

# 麒麟浏览器管理 Skill

## 使用场景

本 Skill 用于指导 agent 完成麒麟浏览器以下操作：

- **内部页面导航**：打开下载（`chrome://downloads/`）、历史记录（`chrome://history/`）、书签（`chrome://bookmarks/`）、设置（`chrome://settings/`），麒麟浏览器基于Chromium内核，支持这些内部页面导航
- **标签页管理**：新建标签页、关闭标签页、切换标签页
- **浏览器页面操作**：前进/后退/刷新页面
- **自定义URL访问**：打开用户指定的任意网址
- **截图当前页面**：截图当前页面到指定文件
- **关闭浏览器**：关闭所有标签页和浏览器窗口
- **点击元素**：根据快照中的ref定位元素并点击
- **按键操作**：模拟用户按键操作，如按下Enter键、按下Tab键等
- **填写文本框**：在指定文本框中输入用户指定的文本

## 触发场景

当用户表达以下意图时，Agent 会自动应用此 Skill：

| 场景类型       | 示例语句             |
| ---------- | ---------------- |
| **内部页面导航** | "打开麒麟浏览器的下载页面"、"打开麒麟浏览器的历史记录"  |
| **标签页操作**   | "在麒麟浏览器里新建一个标签页"、"关闭麒麟浏览器的当前标签页"、"切换到麒麟浏览器的第2个标签页"    |
| **导航控制**   | "在麒麟浏览器里前进"、"后退"、"刷新麒麟浏览器页面" |
| **打开网址** | "在麒麟浏览器里打开百度首页"、"用麒麟浏览器访问taobao.com"  |

**触发关键词**：`麒麟浏览器`、`kylin browser`、`麒麟浏览器下载`、`麒麟浏览器历史`、`麒麟浏览器书签`、`麒麟浏览器设置`、`麒麟浏览器新建/关闭/切换/标签页`、`麒麟浏览器刷新页面`。

## 支持的操作映射表

|用户意图关键词|agent-browser命令/ 内部URL|
|----------|----------------|
|打开下载|`open chrome://downloads/`|
|历史/历史记录|`open chrome://history/`|
|书签/收藏夹|`open chrome://bookmarks/`|
|设置/选项/偏好设置|`open chrome://settings/`|
|新建标签页|`agent-browser tab new`|
|关闭当前标签页|`agent-browser tab close <tab_id>`（tab_id为标签页ID）|
|切换到指定标签页|`agent-browser tab <tab_id>`（tab_id为标签页ID）|
|刷新页面|`agent-browser reload`|
|前进|`agent-browser forward`|
|后退|`agent-browser back`|
|打开<任意网址>|`agent-browser open <url>`|
|截图当前页面|`agent-browser screenshot <filename>`|
|关闭浏览器|`agent-browser close`|
|点击元素|`agent-browser click <ref>`（ref为元素的快照引用）|
|按键操作|`agent-browser press <key>`（key为按键名称，如Enter、Tab等）|
|填写文本框|`agent-browser fill <ref> <text>`（ref为文本框的快照引用，text为要输入的文本）|

## 提示词模板

1. 从用户输入中识别**操作类型**。（参考上述操作映射表）
2. 如果操作需要参数（如`打开URL`需要网址），从用户输入中抽取。

### 基础模板

```
我想在麒麟浏览器中执行{操作类型}（参数：{参数}）。

任务步骤：
1. 关闭之前的浏览器用例并添加agent-browser执行路径。
2. 设置自定义浏览器环境变量和有头模式。
3. 打开浏览器。
4. 执行对应的命令。
```

### 打开下载页面示例

**用户需求：**

> 打开麒麟浏览器的下载页面。

**完整提示词：**

```
在麒麟浏览器上打开下载页面。

任务步骤：
1. 设置浏览器可执行路径指向/usr/bin/kylin-browser，并启用有头模式。
2. 打开麒麟浏览器。
3. 执行打开下载页面命令。
```

## agent-browser 统一实操指南
### 1. 关闭之前的浏览器用例并添加agent-browser执行路径

```bash
# 步骤1：关闭agent-browser用例
agent-browser close --all
# 步骤2：PATH环境变量添加agent-browser执行路径
NODE_BIN="$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node | sort -Vr | head -n1)/bin"
if [[ -d "$NODE_BIN" && ! ":$PATH:" =~ ":$NODE_BIN:" ]]; then
    export PATH="$NODE_BIN:$PATH"
fi
```

### 2. 设置自定义浏览器环境变量，有头模式打开浏览器

```bash
# 步骤1：设置自定义浏览器环境变量为kylin-browser和headed模式
export AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/kylin-browser && export AGENT_BROWSER_HEADED=true

# 步骤2: 打开浏览器(如果浏览器启动失败，可能是之前浏览器实例影响agent-browser close --all)
agent-browser open
```

### 3. 各操作的具体命令

#### A. 内部页面导航（下载、历史记录、书签、设置）

```bash
# 直接使用open命令加载对应的chrome://地址，有头模式显示浏览器窗口
agent-browser open chrome://downloads/ # 下载页面
agent-browser open chrome://history/ # 历史记录页面
agent-browser open chrome://bookmarks/ # 书签页面
agent-browser open chrome://settings/ # 设置页面
```

#### B. 标签页管理（新建、关闭、切换）

```bash
# 新建标签页
agent-browser tab new

# 关闭当前标签页（tab_id为标签页ID）
agent-browser tab close <tab_id>

# 切换到指定标签页（tab_id为标签页ID）
agent-browser tab <tab_id>

# 列出所有标签页
agent-browser tab list
```

#### C. 浏览器页面操作（前进、后退、刷新）

```bash
# 前进
agent-browser forward

# 后退
agent-browser back

# 刷新
agent-browser reload
```

#### D. 打开任意网址自定义URL

```bash
# 打开任意网址自定义URL
agent-browser open <url>
```

#### E. 截图当前页面

```bash
# 截图当前页面
agent-browser screenshot /tmp/screenshot.png
```

#### F. 关闭浏览器

```bash
agent-browser close --all
```

#### G. 获取页面快照

```bash
# 获取页面快照
agent-browser snapshot

# 获取页面快照（仅包含当前可交互元素）
agent-browser snapshot -i
```

#### H. 点击元素

```bash
# 先用snapshot命令获取页面快照
agent-browser snapshot -i

# 点击元素（根据快照中的ref定位元素）
agent-browser click @<ref>
```

#### I. 按键操作

```bash
# 按键操作
agent-browser press <key>
```

#### J. 填写文本框

```bash
# 填写文本框（根据页面快照中的ref定位元素），text为要填写的文本内容
agent-browser fill @<ref> <text>
```

### 4. 异常处理

- **执行agent-browser时出错，提示"agent-browser not found"**: 检查agent-browser是否已安装并启动。（which agent-browser、agent-browser --version）
- **agent-browser连接端口失败**：检查端口是否被占用，若被占用，尝试其他端口。
- **页面加载超时**：等待超过 10 秒仍未出现目标元素，则截图并提示用户检查网络。
- **麒麟浏览器未安装**：检查用户是否已安装麒麟浏览器，若未安装，提示用户安装。（常见检查命令：which kylin-browser、dpkg -l | grep kylin-browser）
- **执行agent-browser子命令出错**： 可以使用agent-browser --help查看所有子命令和参数。

### 4. 输出原始结果
- 必须输出任务用时。（任务已完成，用时：X 秒）