# 执行计划审查

审查日期：2026-10-05。对照原始执行计划、本地 `D:\Code\game-serve-hub` 与 GitHub 最新正式发布记录。Panel 基线为 `v0.15.1`，commit `97e6e21ca1616e14bc65f382f4d51a2136b7a7b9`。

## 结论

独立仓库、三个 V1 路由、安装优先和内容归属的方向合理，可作为开发基线。实施时应先建立 Release 数据提取与校验，再开发依赖这些数据的页面。初始化范围按用户请求落在 Phase 0 / Phase 1，并提供首页、配置器和 FAQ 的可运行起点。

## 需要修订的事项

| 优先级 | 计划或现状 | 执行建议与本次处理 |
| --- | --- | --- |
| P0 | 计划只要求读取 tag 文档，未记录解析后的 commit | 先取最新 `draft=false`、`prerelease=false` Release，再解析 annotated tag 为 commit，所有文档和安装器读取同一个 SHA。本次已实现。Public Beta 产品阶段保留，与 GitHub prerelease 标记分别处理。 |
| P0 | Phase 6 才安排同步，而 Phase 3 已要求安装器参数准确 | 将数据基线和漂移检查前移。先确保版本、安装参数、端口有出处，再做配置器。本次同步数据已供所有页面共用。 |
| P0 | “不手工复制参数”缺少具体提取、失败和回退规则 | 从安装器默认值提取端口、用户名、目录、代理，从版本文档提取环境说明。字段、章节或脚本版本不符合预期时中止同步；构建使用已验证的快照。本次已实现哈希与派生数据校验。 |
| P0 | 安装文档用 `sed -n '9p'` 验证版本，实际变量已在第 72 行 | 这是当前 Panel 文档的失效示例。生成 FAQ 时改为按 `BSP_RELEASE_TAG` 变量定位，保留上游原文与出处；配置器显式传入 Release tag，并校验安装器源码 SHA-256。Panel 原文修订应作为独立变更。 |
| P0 | `≥4 GiB` 容易被理解为双世界、多 Mod 的普遍配置 | [MEMORY.md](../data/panel/docs/MEMORY.md) 区分 4 GiB 体验、6 GiB 双世界与中等 Mod、8 GiB+ 长期运行，且强调启动峰值。安装页面使用版本文档原文并链接内存档位。 |
| P0 | 环境表缺少架构、根分区余量和 systemd 约束 | Native 已发布制品为 linux-x64，文档要求 x86_64；根分区至少 4 GiB 空闲且需给游戏和备份另留空间。Docker 架构支持应结合实际镜像验证，不能从安装器接受 aarch64 推导 DST 已全面支持 ARM。 |
| P0 | 国内网络选项可能只增加 `--network cn` | 首次获取脚本也需要下载代理，不能只改善安装器运行后的网络。本次国内命令使用来自安装器的代理前缀，后续脚本与镜像版本显式锁定。 |
| P0 | “体检不改系统”未区分下载与执行 | `--check` 是安装器的承诺；下载到本地仍会创建脚本文件。本次界面明确说明这一点，体检命令不携带开放防火墙选项。 |
| P1 | “Panel Release 自动更新 Nexus”未定义跨仓库权限和失败处理 | 本次提供接收 dispatch 的同步与构建工作流，只生成 artifact。Panel 发送端、最小权限凭据、正式域名和托管适配仍需接入；没有发布成功前不能宣称自动更新闭环完成。 |
| P1 | FAQ 数据模型未声明正文检索、来源、稳定标识与内容升级方式 | 使用 Content schema、稳定 slug、分类、keywords、errorCodes、relatedDocs 与 order。答案从对应版本的文档章节生成，搜索覆盖正文；继续扩充时应区分自动生成文件与人工编辑内容。 |
| P1 | 将 Vue Bits 当作普通 MIT 依赖 | Vue Bits 通过复制单个组件接入，其[独立许可](https://github.com/DavidHDev/vue-bits/blob/main/LICENSE.md)包含 Commons Clause。本次只接入 SpotlightCard，保留许可和来源；整体原创代码与该组件的许可分别声明。 |
| P1 | SEO 发布域名和统计方案尚未定义 | 本次 SEO 标题、描述、favicon 已完成；正式 canonical、OG URL、sitemap 由域名配置生成。指标采集留到需求和隐私规则明确后接入。 |

## 发现的上游文档一致性问题

- [reference.md](../data/panel/docs/reference.md) 的安装参数表漏列 `--check`，但部署文档和安装器 help 已支持。本次从安装器 help 提取选项。
- [MEMORY.md](../data/panel/docs/MEMORY.md) 仍说明监控卡片展示“可用缓冲”，而 [CHANGELOG.md](../data/panel/CHANGELOG.md) 的 0.14.0 已记录移除该文案。后续编辑 FAQ 时应核对发布 UI，避免机械迁移该描述。
- 国内安装文档中固定行号的版本检查已失效，不能直接照搬至新手配置器。

## 调整后的开发顺序

1. 审核 Panel Release 内容，建立带 commit、来源与摘要的数据基线。
2. 建立 Nuxt / Content / Tailwind、设计 Token、布局和三个路由。
3. 从基线生成安装与体检命令，验证四种部署组合和可选参数。
4. 完善首次登录、端口、集群令牌、世界就绪与排错路径。
5. 将 FAQ 扩充至至少 25 条，补上忘记密码、OOM、Mod、迁移与更新的独立问题。
6. 补产品截图、首屏产品证据和首页 FAQ 预览。
7. 接通 Panel dispatch 与托管部署，配置正式域名。
8. 完成 Linux CI、Chrome / Firefox / Safari、移动设备与实际 Linux 安装验收，再上线和更新 Panel 入口。

## 本次初始化完成情况

| 项目 | 状态 |
| --- | --- |
| Phase 0：来源审查、版本基线、FAQ 模型 | 已建立 |
| Phase 1：Nuxt、Content、Tailwind、TypeScript、布局、404、三个路由 | 已完成基础工程 |
| 首页、品牌、Docker / Native 说明、支持分流 | 已建立可运行起点 |
| 安装配置器、体检、复制、端口表、登录和世界步骤 | 已实现基础交互，未执行真实 Linux 安装 |
| FAQ 分类、正文搜索、折叠、锚点和来源 | 已实现，9 条种子内容 |
| Release 同步脚本、CI 与 dispatch 接收工作流 | 已建立；GitHub 工作流和部署闭环待验证 |
| 正式上线、25+ FAQ、完整跨浏览器 QA、Panel 入口更新 | 后续 V1 里程碑 |

## 技术依据

Content 采用[官方 collections 模型](https://content.nuxt.com/docs/collections/define)，构建使用 [SSG](https://content.nuxt.com/docs/deploy/static)；Node 24 下使用[原生 SQLite connector](https://content.nuxt.com/docs/getting-started/configuration#experimentalsqliteconnector)。Tailwind 采用[官方 Nuxt Vite 插件方式](https://tailwindcss.com/docs/installation/framework-guides/nuxt)。工作流版本按 [checkout](https://github.com/actions/checkout)、[setup-node](https://github.com/actions/setup-node)、[upload-artifact](https://github.com/actions/upload-artifact) 与 [pnpm/action-setup](https://github.com/pnpm/action-setup) 当前官方用法建立，实际云端运行仍待验证。
