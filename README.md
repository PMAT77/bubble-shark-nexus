# BubbleShark Nexus

BubbleSharkPanel 的产品入口、安装中心与常见问题站点。面向《饥荒联机版》自托管服务器服主，使用 Nuxt 4、Nuxt Content 3、Tailwind CSS 4、Vue 3 与 TypeScript。

当前为项目初始化版本：已建立三个页面、安装配置器、9 条来源可追溯的 FAQ、静态构建和 Release 同步基础。完整 V1 交付清单见 [计划审查](docs/plan-review.md)。

## 本地运行

需要 Node.js 24+ 与 pnpm 10.33.0。Nuxt Content 使用 Node 内置 SQLite。

```sh
pnpm install
pnpm dev
```

开发地址：`http://127.0.0.1:3000`。

```sh
pnpm check:baseline
pnpm test
pnpm typecheck
pnpm generate
pnpm preview
```

静态产物位于 `.output/public`。`pnpm preview` 使用 Nuxt 的静态预览命令，首次运行可能下载 `serve`。

部署到全新 Debian 12 服务器见 [静态网站部署步骤](docs/debian-deployment.md)，配套 Nginx 配置位于 `deploy/nginx-nexus.conf`。

## 页面

| 路由 | 内容 |
| --- | --- |
| `/` | 产品介绍、开服步骤、核心能力、部署方式与社区入口 |
| `/install` | Docker / Native、国内 / 海外、可选防火墙配置、体检命令、首次登录与端口 |
| `/faq` | 按分类、标题、正文、关键词和错误提示搜索；问题锚点与原文出处 |

## Panel 内容基线

Panel 本地参考目录为 `../bubble-shark-panel`，官方仓库为 [PMAT77/bubble-shark-panel](https://github.com/PMAT77/bubble-shark-panel)。

```sh
# 从 GitHub 最新非预发布 Release 同步
pnpm sync:panel

# 从本地仓库读取该 Release 的精确 git blob
pnpm sync:panel --local ../bubble-shark-panel
```

两种方式均查询 GitHub Release 元数据并将 tag 解析为 commit；本地方式还会校验 tag 与远端 commit 相同。同步不会读取 Panel 工作区中的未发布修改。

同步输出：

- `data/release.json`：版本、安装器 URL 与 SHA-256、端口、环境要求、资源与来源摘要。
- `data/panel/`：对应 commit 的 README、安装器、部署、迁移、内存、安全、变更记录与品牌素材原文。
- `content/faq/`：依据原文章节生成的 FAQ 种子内容；同步时覆盖，请在 `scripts/panel-baseline.mjs` 中维护生成规则。
- `public/logo/shark.png`、`public/favicon.png`：Panel 品牌素材。

安装命令先下载并校验安装器，再执行。下载失败或校验失败时不会继续安装。`--check` 不修改目标系统；下载步骤会在当前目录保存脚本。

`pnpm check:baseline` 检查来源哈希、提取事实与生成 FAQ 的一致性。常规开发和构建使用已提交的快照，无需访问 GitHub。

## 发布与 GitHub Pages

将 `.env.example` 复制为 `.env`，可为本地静态构建配置站点地址：

```dotenv
NUXT_PUBLIC_SITE_URL=https://your-domain.example
```

配置后重新生成静态站点，生成正式 canonical、OpenGraph URL、sitemap 与 robots。未配置域名时，robots 默认禁止索引且不会生成虚构的 canonical。

推送到 `main` 后，`.github/workflows/deploy-pages.yml` 会执行同一组检查、生成 `.output/public` 并发布到 GitHub Pages。首次发布默认使用 `https://pmat77.github.io/bubble-shark-nexus/`，无需配置仓库变量。

在仓库 **Settings → Pages** 中将发布源设为 **GitHub Actions**。若以后迁移到根域名 `https://bubble-shark.online`，在域名通过 Pages 验证并完成 DNS 切换后，添加以下仓库变量并重新运行部署工作流：

```text
NEXUS_APP_BASE_URL=/
NEXUS_SITE_URL=https://bubble-shark.online
```

根域名需要改为 GitHub Pages 的四条 A 记录：`185.199.108.153`、`185.199.109.153`、`185.199.110.153`、`185.199.111.153`；`www.bubble-shark.online` 使用指向 `pmat77.github.io` 的 CNAME。使用 Actions 发布时无需提交 `CNAME` 文件。

`.github/workflows/ci.yml` 执行常规验证并上传构建 artifact。`.github/workflows/sync-panel.yml` 接收 `panel-release` dispatch 或手动触发，生成最新静态产物与基线 artifact；同步结果需要经过审查并提交到 `main` 后才会发布。

Panel 端 dispatch 与自定义域名的 GitHub 设置仍需在相应账户控制台完成。工作流尚未在 GitHub 上运行验证。

## 文档与许可

- [执行计划原文](docs/execution-plan.md)
- [计划审查与后续任务](docs/plan-review.md)
- [初始化与验证记录](docs/initialization.md)

原创代码使用 [MIT](LICENSE)。Panel 原文与品牌素材保留 [Panel MIT 许可](data/panel/LICENSE)。Vue Bits SpotlightCard 使用独立的 [MIT + Commons Clause](licenses/vue-bits.txt)，出处见 [NOTICE](NOTICE)。
