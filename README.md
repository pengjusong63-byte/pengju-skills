# pengju-skills
集合了可直接由 agent-browser 调用的自动化 Skill，覆盖常见的办公与电商场景，便于复用与二次开发。

## 目录

- [`agent-browser-oa-leave`](agent-browser-oa-leave/SKILL.md) - 在 Kylin OA 门户（https://portal.kylinos.cn/）上自动提交请假申请的 Skill。
- [`agent-browser-shopping-addcart`](agent-browser-shopping-addcart/SKILL.md) - 在京东/淘宝上搜索并将目标 SKU 加入购物车的 Skill。

## 简介

每个 Skill 的目录下包含 `SKILL.md`，里面有：

- 功能概述
- 前置条件（浏览器/agent-browser、cookie/token、环境依赖）
- 使用示例（命令行 / JSON / agent-browser 操作序列）
- 安全与隐私说明（如何安全使用 token/cookie）
- 故障排查与常见问题

## 快速开始

1. 克隆仓库并进入目录（若尚未）

2. 阅读并准备 Skill 所需的前置项：
	- 启动并可连接的 agent-browser 或兼容代理浏览器。
	- 准备好登录态（cookie 或 token），严格按照 Skill 中的安全提示处理敏感信息。

3. 查看某个 Skill 的使用说明并按示例执行：
	- `agent-browser-oa-leave` 详见：`agent-browser-oa-leave/SKILL.md`
	- `agent-browser-shopping-addcart` 详见：`agent-browser-shopping-addcart/SKILL.md`

4. 在执行会影响真实数据（如提交表单、下单）前，建议先在测试环境或使用只读/快照模式验证流程。

## 安全与隐私

- 切勿在公开仓库或日志里提交完整的 cookie、cvaToken 或其他认证凭据。
- 若 Skill 需要临时凭据，请采用环境变量或受限配置文件，并在文档中注明过期策略与回收流程。

## 贡献

欢迎 PR、Issue 或直接在相应 Skill 下补充示例与兼容性说明。请遵循仓库的贡献规范（编辑 `SKILL.md` 并提供可复现的示例步骤）。

---

更多细节请查看各 Skill 的 `SKILL.md`：

- `agent-browser-oa-leave/SKILL.md`
- `agent-browser-shopping-addcart/SKILL.md`
