# 初始化与验证记录

日期：2026-10-05。工作目录：`D:\Code\bubble-shark-nexus`。

## 工程基线

- 本地 Git 仓库已初始化，默认分支 `main`；尚无提交和远程配置。
- Node.js 实测 `v24.19.0`，pnpm `10.33.0`。
- Nuxt `4.5.2`、Nuxt Content `3.16.1`、Vue `3.5.43`、Tailwind `4.3.3`、TypeScript `5.9.3`。
- Lucide 使用当前 `@lucide/vue` 包；Vue Bits 仅复制 SpotlightCard 并保存独立许可。
- Panel 版本为 `v0.15.1`，发布 commit 为 `97e6e21ca1616e14bc65f382f4d51a2136b7a7b9`。
- 已从本地 `game-serve-hub` 的发布 commit 读取 12 份原始文件，生成 Release 数据、品牌素材与 9 条 FAQ。GitHub Release 元数据和远端 tag commit 已核对。
- `.gitattributes` 保留上游原始字节，避免 Windows 换行转换破坏来源哈希。

## 已完成验证

| 验证 | 结果 |
| --- | --- |
| `pnpm install` 与依赖锁文件 | 已完成 |
| `pnpm check:baseline` | 通过：来源哈希、提取参数与生成内容一致 |
| `pnpm test` | 4 项通过，含 32 种部署 / 网络 / 防火墙 / 体检组合、版本漂移、危险输入和 Markdown 代码块分节 |
| `pnpm typecheck` | 通过 |
| `pnpm generate` | 通过；预渲染首页、安装、FAQ、404、robots、sitemap 与 Content 数据，共 12 个输出路由 |
| 安装配置器 | 浏览器验证默认 Docker + 国内、Native + 海外与可选防火墙参数切换 |
| 复制命令 | “已复制”状态正确；剪贴板内容包含安装器 SHA-256 校验 |
| FAQ 搜索 | `10999` 找到端口与迁移内容；`密码` 找到登录答案；无结果状态可见 |
| FAQ 展开与锚点 | 展开正确；`/faq#first-password` 刷新后自动展开目标问题 |
| FAQ 代码块 | 已接入统一复制组件 |
| 404 | 未知路由显示自定义错误页，返回首页成功 |
| 桌面与手机 | 已检查 1440×960 与 390×844 视口；修复安装指南网格最小宽度导致的手机溢出 |
| 浏览器页面宽度 | 桌面首页及手机首页、安装、展开的 FAQ 页面无整页横向溢出；命令和表格可在自身区域内滚动 |
| 品牌与本地预览 | 鲨鱼 Logo 可见，导航随路由关闭；预览地址为 `http://localhost:3000` |

首页截图保存在本地 `.artifacts/nexus-home.png`。构建日志保存在 `.artifacts-build.log`。两者均不进入 Git。

主题已按浅粉色参考调整为灰白底、白色卡片、淡粉区块与玫瑰粉强调色，颜色统一维护在 `app/assets/css/main.css`。本次重新通过类型检查与静态构建，并验证三个页面的桌面 / 手机布局、安装方案切换、命令复制、FAQ 搜索和手机导航。正文与强调文字在白色、灰白和淡粉背景上的对比度均超过 4.5:1。新预览截图位于 `.artifacts/nexus-pink-home.png` 与 `.artifacts/nexus-pink-install.png`，不进入 Git。

## 验证边界与后续验收

- 本次验证的是工程、静态页面和命令生成；真实 Linux 安装及首次开服仍需使用一次性 Linux 测试机验收。
- Release 同步已实测本地 tag 来源模式，远端 Raw 文件下载链路及 GitHub Actions 云端运行尚待验收。
- `pnpm install` 有 Nuxt 上游的 `oxc-parser` / `unplugin` peer 提示；Windows 静态构建有 Nitro 导入提示。当前类型检查与 SSG 均通过，Linux CI 应继续核对这些依赖提示。
- Reduced Motion 与触屏动效降级已经通过 CSS 实现；系统动态偏好模拟、Firefox、Safari 和真实移动设备仍待完整 V1 QA。
- 正式域名尚未设置，因此当前 `robots.txt` 禁止索引、sitemap 为空，正式 canonical 与 OG URL 在配置域名后生成。
- FAQ 目前为 9 条自动生成的种子内容；至少 25 条编辑 FAQ、产品截图、首页 FAQ 预览和完整安装路径仍需完善。
- Panel 发布 dispatch 发送端、托管部署与 Panel 入口更新属于后续发布里程碑。

Panel 工作区未作修改。原始执行计划保留在 `D:\Temp`，项目内保存了一份参考副本。

## 2026-10-06：同步 Panel v0.15.3

- 从已发布 Release 同步 Panel v0.15.3，固定 commit 为 `d519b8b0aeae0582591bbba8299c0f8678aba939`。
- 执行 `pnpm run sync:panel --local ../bubble-shark-panel`，更新 12 份上游原文、Release 数据、品牌素材与 9 条 FAQ。
- 安装器 SHA-256 为 `cad80517c15329fb3f243225f36833836a9272ca131e5c62dbb8c9bdc53a451a`；安装中心命令、版本与发布资源链接使用同一基线。
- 上游变更记录包含 Native 安装跳过 GHCR 与 Docker 官方源探测，以及 GHCR 请求失败时继续体检和镜像路线选择的修复。
- `pnpm run check:baseline` 通过；`pnpm test` 4 项通过，覆盖 32 种命令组合；`pnpm run generate` 通过，预渲染 12 个路由。
- 静态构建仍有已记录的 Windows Nitro 导入提示；本次同步未部署到服务器。
