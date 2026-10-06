# BubbleShark Nexus 官方社区与文档站执行计划

> 项目：BubbleSharkPanel 官方入口 / 文档 / 安装引导 / FAQ  
> 暂定名称：**BubbleShark Nexus**  
> 面向产品：BubbleSharkPanel  
> 技术方向：Nuxt + Nuxt Content + Tailwind CSS + Vue Bits  
> 文档目标：作为 Nexus V1 的产品、设计与开发执行基线

---

## 1. 项目背景

BubbleSharkPanel 当前已经具备明确的产品定位：

- 面向《饥荒联机版》（Don't Starve Together，DST）的专用服务器管理；
- 支持 Docker 与 Native systemd 两种部署方式；
- 支持实例、世界、Mod、玩家、备份、控制台、监控等核心管理能力；
- 对中国大陆服务器的 GitHub、GHCR、SteamCMD、Mod 市场网络问题做了专门处理；
- 支持已有 DST 存档迁移；
- 支持成员、角色、权限和实例授权；
- 提供 `bsp doctor`、安装预检、内存与运行状态诊断；
- 当前以 GitHub README 与 `docs/` 目录承担产品介绍、安装和故障排查职责。

目前的问题并不是“缺少文档”，而是：

1. 产品价值分散在 README、安装文档、Reference、Migration、Memory、CHANGELOG 中；
2. 新用户需要先理解项目结构，才能找到正确安装方式；
3. Docker / Native、中国大陆 / 海外等选择需要用户自己判断；
4. 常见故障仍以“查文档”为主，缺少以用户症状为入口的排错路径；
5. GitHub 更适合开发者和熟悉技术的用户，不适合作为最终的产品官网和新手入口；
6. 文档存在未来与版本更新脱节的风险。

因此需要建设独立的 **BubbleShark Nexus**。

---

# 2. 产品定位

## 2.1 Nexus 是什么

BubbleShark Nexus 定位为：

> **BubbleSharkPanel 官方文档与社区中心。**

它不是第二个管理面板，也不是简单的 README 网页版。

Nexus 需要同时承担四个角色：

1. **产品官网**  
   告诉第一次接触 BubbleSharkPanel 的用户：它是什么、为什么值得使用。

2. **安装入口**  
   根据用户环境直接生成正确安装方案，而不是要求用户先理解全部参数。

3. **官方知识库**  
   提供 FAQ、迁移、排错、版本和使用指南。

4. **社区分流中心**  
   把“使用问题 / Bug / 功能建议 / 安全问题”导向正确渠道。

---

# 3. V1 核心目标

Nexus V1 只解决三个问题：

## 3.1 让用户理解 BubbleSharkPanel

首页回答：

- BubbleSharkPanel 是什么？
- 它与手工开服有什么区别？
- 为什么选择 BubbleSharkPanel？
- Docker 与 Native 有什么区别？
- 是否支持中国大陆服务器？
- 是否能迁移已有存档？

## 3.2 让用户完成安装

安装页面应让用户：

1. 选择部署方式；
2. 选择服务器网络环境；
3. 生成安装命令；
4. 完成首次登录；
5. 配置端口；
6. 创建第一个 DST 实例；
7. 确认世界正常启动。

目标不是“让用户读完安装文档”，而是：

> **让用户顺着页面完成第一次成功开服。**

## 3.3 解决高频问题

FAQ 应覆盖：

- 安装失败；
- GitHub / GHCR 网络问题；
- 登录与管理员密码；
- 端口与安全组；
- 房间搜索不到；
- 世界长时间未就绪；
- Mod 下载失败；
- 内存不足；
- 存档迁移；
- 更新与回滚；
- Docker / Native 差异。

---

# 4. V1 范围

## 4.1 V1 页面

```text
BubbleShark Nexus
│
├── /
│   └── 首页
│
├── /install
│   └── 安装中心
│
└── /faq
    └── 常见问题与故障排查
```

顶部导航：

```text
首页
安装
FAQ
GitHub
在线体验
```

预留但 V1 不强制实现：

```text
/changelog
/migrate
/docs
/roadmap
/community
/security
```

---

# 5. V1 明确不做

第一版暂不建设：

- 用户注册；
- 论坛；
- 评论系统；
- 私信系统；
- 在线客服；
- 复杂 CMS；
- 插件市场；
- 服务器租赁市场；
- 社区帖子体系；
- 多用户内容发布系统。

原因：

> Nexus V1 的核心任务是降低 BubbleSharkPanel 的理解、安装和排错成本，而不是再开发一个大型社区产品。

---

# 6. 推荐技术架构

## 6.1 独立仓库

推荐创建：

```text
PMAT77/bubble-shark-nexus
```

不要直接放进 BubbleSharkPanel 主项目。

原因：

- Panel 是管理后台；
- Nexus 是官网 / 内容站；
- 两者 UI、SEO、构建和部署目标不同；
- Vue Bits 使用 Tailwind，与 Panel 当前 UnoCSS / Fantastic-admin 体系不同；
- 独立仓库有利于后续单独发布和演进。

---

## 6.2 推荐技术栈

```text
Nuxt
├── Vue 3
├── TypeScript
├── Nuxt Content
├── Tailwind CSS
├── Vue Bits
├── Lucide Icons
└── pnpm
```

### Nuxt

负责：

- 页面路由；
- SEO；
- SSG；
- 数据获取；
- 组件化页面结构。

### Nuxt Content

负责：

- FAQ；
- 安装指南；
- 后续迁移文档；
- 后续更新日志；
- Markdown 内容管理。

### Tailwind CSS

主要服务于：

- 官网布局；
- Vue Bits；
- 设计 Token；
- 响应式设计。

### Vue Bits

只作为视觉与动效增强。

原则：

> Vue Bits 是“品牌增强层”，不是 Nexus 的设计基础。

---

# 7. Vue Bits 使用策略

不要把 Nexus 做成 Vue Bits Demo。

每页应尽量控制复杂动态效果数量。

## 首页推荐

### Hero 背景

二选一：

- Aurora
- DotField

用途：

- 深海感；
- 粒子感；
- 服务器信号 / 声呐视觉隐喻。

### 功能卡片

使用：

- SpotlightCard

适用于：

- 世界管理；
- Mod；
- 玩家；
- 备份；
- 权限；
- 服务器监控。

### CTA

可少量使用：

- StarBorder

例如：

```text
开始安装 BubbleSharkPanel
```

## 安装页

尽量不使用复杂动画。

重点是：

- 信息清晰；
- 参数准确；
- 命令易复制；
- 状态明确。

## FAQ

不需要复杂动画。

重点是：

- 搜索；
- 分类；
- Accordion；
- URL Anchor；
- 命令复制。

---

# 8. 品牌视觉方向

建议建立 BubbleShark 独立视觉语言。

关键词：

```text
Deep Ocean
Sonar
Bubble
Server Signal
Bioluminescence
Network
```

推荐风格：

```text
背景：深海蓝黑
主色：Aqua / Cyan
高光：冰蓝
成功：海藻绿
警告：暖黄
错误：珊瑚红
```

视觉元素：

- 气泡；
- 声呐圆环；
- 微粒；
- 网格；
- 服务状态脉冲；
- 低对比度水下光束。

品牌素材优先复用 BubbleSharkPanel 当前鲨鱼 Logo。

目标：

> Panel 与 Nexus 一眼能被识别为同一套产品生态。

---

# 9. 首页信息架构

首页应遵循用户认知路径：

```text
这是什么？
↓
能解决什么？
↓
为什么选它？
↓
是否适合我？
↓
安装难不难？
↓
开始安装
```

推荐页面顺序如下。

---

## 9.1 Hero

核心文案建议：

```text
BubbleSharkPanel

让开服，像点一下那么简单。

专为《饥荒联机版》打造的自托管服务器管理面板。
创建实例、管理世界与 Mod、玩家、备份和服务器状态，
都可以在浏览器里完成。
```

CTA：

```text
[ 开始安装 ]
[ 在线体验 ]

GitHub →
```

状态：

```text
Public Beta
当前稳定版本
MIT
```

---

## 9.2 四步开服

推荐：

```text
01 准备 Linux 服务器
        ↓
02 安装 BubbleSharkPanel
        ↓
03 创建 DST 实例
        ↓
04 配置世界并启动
```

补充说明：

> 不需要手工维护 SteamCMD、Compose、systemd 或 DST 分片启动脚本。

---

## 9.3 六个核心能力

首页建议只重点讲六项。

### DST 深度适配

强调：

- 世界；
- 洞穴；
- Mod；
- 玩家；
- 集群令牌；
- 存档。

### 一键安装

支持：

- Docker；
- Native systemd。

### 中国大陆网络支持

强调：

- `--network cn`
- GitHub Proxy；
- Release 离线镜像；
- GHCR fallback；
- SteamCMD 重试；
- Mod 市场代理。

建议传播文案：

> 不用再和 GHCR Waiting 死磕。

### 自动备份

表达重点：

> 改世界、迁移、恢复和关键操作之前，先留下一条退路。

### 多人协作

强调：

- 成员；
- 角色；
- 权限；
- 实例范围；
- 操作记录。

### 现有服务器迁移

强调：

> 已经有 DST 服务器，不需要重新开荒。

---

# 10. Docker / Native 选择区

这是用户的第一个重要决策。

建议首页直接提供对比。

| 项目 | Docker | Native |
|---|---|---|
| 推荐 | 默认推荐 | 有明确需求再选 |
| 面板 | Container | systemd |
| DST | Container | systemd |
| Docker | 需要 | 不需要 |
| 管理方式 | Docker Compose | `bsp` + systemd |
| 典型用户 | 社区 / 容器用户 | 个人服主 |

默认建议：

> 不确定选择哪个时，使用 Docker。

Native 面向：

> 明确不希望使用 Docker，并理解 systemd 运维方式的用户。

---

# 11. 安装中心设计

安装页是 V1 最高优先级页面。

目标：

> 把“阅读安装文档”转化为“配置安装方案”。

---

## 11.1 Installation Configurator

### Step 1：部署模式

```text
● Docker
○ Native
```

### Step 2：网络环境

```text
● 中国大陆
○ Global
```

### Step 3：高级选项

```text
□ 自动开放面板本机防火墙端口
□ 自动开放 DST 本机防火墙端口
```

### 输出

实时生成：

```bash
curl ...
```

并提供：

```text
[复制安装命令]
```

---

## 11.2 安装环境信息

安装配置器旁边显示：

```text
当前稳定版本
vX.Y.Z

支持系统
Debian 12
Ubuntu 22.04
Ubuntu 24.04

内存
≥ 4 GiB

权限
root / sudo
```

版本必须来自 Release 数据，不允许写死。

---

# 12. 安装教程流程

安装页下半部分按任务流组织，而不是按实现组织。

推荐结构：

## 12.1 安装前检查

解释：

- Linux；
- 架构；
- 内存；
- 磁盘；
- root / sudo。

并提供：

```bash
--check
```

说明：

> 只做环境检查，不修改系统。

---

## 12.2 安装 BubbleSharkPanel

根据配置器选择展示对应命令。

---

## 12.3 第一次登录

明确：

```text
默认管理员：superadmin
初始密码：安装完成摘要中生成
```

同时提供：

- 密码滚屏后如何找回；
- 首次登录强制改密说明。

---

## 12.4 开放端口

可视化展示：

### Panel

```text
9527 TCP
```

### Master

```text
10999 UDP
8766 UDP
12346 UDP
```

### Caves

```text
11000 UDP
8768 UDP
12348 UDP
```

必须明确：

> 云服务安全组和 Linux 本机防火墙是两层不同配置。

---

## 12.5 创建第一个 DST 实例

推荐步骤：

```text
进入 Panel
↓
实例管理
↓
创建实例
↓
安装 DST
↓
填写 Cluster Token
↓
配置世界
↓
启动
↓
等待「世界已就绪」
```

安装页不应在“Panel 安装成功”后立即结束。

真正完成的终点应该是：

> 用户看到第一个世界成功就绪。

---

# 13. 中国大陆安装体验

“中国大陆服务器”必须作为一级使用场景，而不是附录。

配置器应直接询问：

```text
服务器位于哪里？

[ 中国大陆 ]
[ 海外 / Global ]
```

选择中国大陆后自动应用正确安装方式。

用户不需要理解：

- GHCR Registry；
- Blob；
- Docker Layer；
- Release Archive；
- Proxy Pool。

Nexus 应把这些复杂性隐藏在背后。

---

# 14. FAQ 信息架构

第一版建议至少整理 25～35 个 FAQ。

分类如下。

---

## 14.1 开始之前

- BubbleSharkPanel 是什么？
- 支持哪些系统？
- 支持 Windows 吗？
- 最低需要多少内存？
- Docker 与 Native 怎么选？

---

## 14.2 安装

- 中国大陆服务器怎么安装？
- `--check` 是什么？
- GHCR 一直 Waiting 怎么办？
- `TLS handshake timeout` 怎么办？
- Docker Compose v2 缺失怎么办？
- GitHub Raw 无法访问怎么办？

---

## 14.3 登录

- 初始用户名是什么？
- 初始密码在哪里？
- 忘记管理员密码怎么办？
- 为什么首次登录要求改密码？

---

## 14.4 开服

- 需要开放哪些端口？
- 为什么服务器列表搜不到？
- 为什么 Panel 显示运行中但玩家进不去？
- 为什么世界一直没有显示“已就绪”？
- 为什么主世界可以进、洞穴掉线？
- NAT 端口映射需要注意什么？

---

## 14.5 Mod

- Mod 市场加载失败怎么办？
- Mod 下载失败怎么办？
- 中国大陆 Steam 网络不稳定怎么办？
- 为什么启用了 Mod 但游戏里没有？

---

## 14.6 存档与迁移

- 可以导入已有 DST 存档吗？
- 可以从其他面板迁移吗？
- 会不会丢档？
- Mod 可以一起迁移吗？

---

## 14.7 更新

- 更新会删除实例吗？
- 更新后页面异常怎么办？
- 可以回滚吗？
- Docker 与 Native 能直接互相切换吗？

---

## 14.8 安全

- 可以把 9527 直接暴露公网吗？
- 为什么 Docker 模式需要 Docker Socket？
- 如何安全公开 Panel？

---

## 14.9 排错

- 如何快速检查服务器状态？
- `bsp doctor` 有什么用？
- 内存不足怎么办？
- 实例反复重启怎么办？

---

# 15. FAQ 搜索

FAQ 顶部提供搜索：

```text
搜索问题、错误提示或关键词
```

需要支持：

- 标题；
- 正文；
- keyword；
- error code；
- CLI；
- 端口；
- 常见错误字符串。

例如：

```text
waiting
TLS
10999
密码
洞穴
Mod
OOM
doctor
```

都能定位对应内容。

---

# 16. 二阶段功能：按症状排错

可作为 V1.1 或 V2。

入口：

```text
你遇到了什么问题？

○ 安装失败
○ 面板打不开
○ 登录失败
○ 房间搜不到
○ 世界未就绪
○ Mod 下载失败
○ 内存不足
```

例如：

```text
房间搜不到
↓
世界显示「已就绪」吗？
↓
否
→ 检查 Mod / 内存 / Console
↓
是
→ 检查 6 个 UDP 端口
↓
检查安全组
↓
检查 NAT
↓
bsp doctor
```

目标：

> 把传统文档搜索升级成故障决策树。

---

# 17. 内容 Source of Truth

这是 Nexus 架构中最重要的规则之一。

不能手工复制 BubbleSharkPanel 的技术参数。

---

## 17.1 Panel 仓库负责技术事实

来源包括：

```text
README.md

docs/
├── install-docker.md
├── install-native.md
├── migrate-from-other-panel.md
├── MEMORY.md
└── reference.md

CHANGELOG.md
GitHub Release
```

---

## 17.2 Nexus 负责体验层

Nexus 负责：

- 内容重组；
- 新手解释；
- 安装配置器；
- FAQ；
- 页面导航；
- 搜索；
- SEO；
- 视觉展示。

原则：

> Nexus 不创造第二份安装事实。

---

# 18. Release 自动同步

需要建立：

```text
BubbleSharkPanel
        │
        │ Release vX.Y.Z
        ▼
GitHub Actions
        │
        └── Dispatch
                │
                ▼
BubbleShark Nexus
        │
        ├── 获取最新稳定 Release
        ├── 获取对应 Tag 文档
        ├── 生成 release.json
        ├── 构建
        └── 部署
```

关键原则：

> Nexus 应读取 Release Tag 对应的文档，而不是直接读取 `main`。

原因：

`main` 可能已经包含尚未发布的下一版本参数。

---

# 19. release.json 建议结构

```json
{
  "version": "v0.15.1",
  "channel": "Public Beta",
  "releasedAt": "2026-10-05",
  "installer": "...",
  "dockerImage": "...",
  "nativeAsset": "...",
  "releaseUrl": "..."
}
```

首页和安装页统一消费这一数据。

禁止：

- 页面硬编码版本号；
- FAQ 硬编码安装 Tag；
- 安装命令手写固定版本。

---

# 20. 推荐目录结构

```text
bubble-shark-nexus/
│
├── app/
│   ├── components/
│   │   ├── nexus/
│   │   │   ├── InstallConfigurator.vue
│   │   │   ├── CommandBlock.vue
│   │   │   ├── FeatureCard.vue
│   │   │   ├── ReleaseBadge.vue
│   │   │   ├── FaqSearch.vue
│   │   │   ├── PortTable.vue
│   │   │   └── SupportChannels.vue
│   │   │
│   │   └── vue-bits/
│   │       ├── Aurora/
│   │       ├── SpotlightCard/
│   │       └── StarBorder/
│   │
│   ├── layouts/
│   │   └── default.vue
│   │
│   └── pages/
│       ├── index.vue
│       ├── install.vue
│       └── faq.vue
│
├── content/
│   ├── install/
│   ├── faq/
│   └── guides/
│
├── data/
│   └── release.json
│
├── public/
│   ├── logo/
│   ├── screenshots/
│   └── og/
│
├── scripts/
│   └── sync-bubbleshark-release.ts
│
├── content.config.ts
├── nuxt.config.ts
└── package.json
```

---

# 21. 社区支持入口

Nexus 要负责问题分流。

推荐统一组件：

```text
还是没有解决？
```

然后显示：

### 部署 / 配置 / 使用问题

```text
→ QQ 群
```

### 可复现 Bug

```text
→ GitHub Issue
```

### 功能建议

```text
→ GitHub Issue
```

### 安全漏洞

```text
→ SECURITY.md / 官方安全渠道
```

目标：

- 减少 QQ 群重复问答；
- 减少 Issue 中纯使用问题；
- 提高 Bug 报告质量。

---

# 22. SEO 规划

品牌词只能覆盖已经认识 BubbleSharkPanel 的用户。

Nexus 还应覆盖搜索意图：

```text
饥荒开服面板
DST 开服面板
饥荒服务器面板
饥荒专用服务器
DST Docker 开服
饥荒 Linux 开服
饥荒服务器怎么开
DST Mod 服务器
Don't Starve Together server panel
```

建议：

首页 Title：

```text
BubbleSharkPanel - 饥荒联机版 DST 开服与服务器管理面板
```

安装页：

```text
BubbleSharkPanel 安装教程 - Docker / Native DST 开服
```

FAQ：

```text
BubbleSharkPanel 常见问题与故障排查
```

同时完善：

- description；
- OpenGraph；
- favicon；
- sitemap；
- canonical；
- structured data。

---

# 23. 开发阶段规划

---

## Phase 0：内容基线

### 任务

- 审核 README；
- 审核 Docker 安装文档；
- 审核 Native 安装文档；
- 审核 Reference；
- 审核 Migration；
- 审核 Memory；
- 审核 CHANGELOG；
- 确定 Release 数据字段；
- 建立 FAQ 数据模型。

### FAQ 数据结构建议

```ts
interface FaqItem {
  id: string
  title: string
  category: string
  keywords: string[]
  errorCodes?: string[]
  relatedDocs?: string[]
}
```

### 验收

- 所有安装参数都能追溯到 Panel；
- 不存在 Nexus 自己维护的第二套参数事实。

---

# Phase 1：基础工程

### 任务

建立：

```text
Nuxt
Nuxt Content
Tailwind CSS
Vue Bits
TypeScript
pnpm
```

完成：

- Header；
- Footer；
- Dark Theme；
- Typography；
- Container；
- Button；
- Badge；
- CodeBlock；
- SEO；
- 404；
- Responsive Layout。

### 验收

- 首页 /install /faq 路由可访问；
- Desktop / Mobile 基础布局稳定；
- 支持静态构建。

---

# Phase 2：首页

### 任务

完成：

- Hero；
- 产品截图；
- 四步开服；
- 六项核心能力；
- Docker / Native 对比；
- 国内网络能力；
- 迁移入口；
- FAQ Preview；
- Community CTA；
- Footer。

### Vue Bits

最多使用：

- Aurora 或 DotField；
- SpotlightCard；
- StarBorder。

### 验收

第一次访问的人在不打开 GitHub README 的情况下能回答：

1. BubbleSharkPanel 是什么；
2. 能解决什么；
3. 是否支持自己的服务器；
4. 应该选择 Docker 还是 Native；
5. 去哪里安装。

---

# Phase 3：Installation Configurator

### 优先级

**P0**

### 任务

支持：

```text
部署模式
Docker / Native

网络
China / Global

可选
Open Panel Port
Open DST Ports
```

动态输出安装命令。

同时显示：

- 当前稳定版本；
- 系统要求；
- 内存要求；
- sudo / root 要求；
- Copy 按钮。

### 验收

任意配置组合生成的命令必须与当前 Release 安装器参数一致。

---

# Phase 4：安装完整路径

### 任务

将现有安装知识重新组织为：

```text
准备
↓
环境检查
↓
安装
↓
首次登录
↓
开放端口
↓
创建实例
↓
配置 DST
↓
世界已就绪
↓
升级
↓
排错
```

### 验收

一个第一次使用 Linux 游戏面板的用户能按页面完成第一个 DST 世界启动。

---

# Phase 5：FAQ

### 任务

实现：

- FAQ Search；
- Category；
- Accordion；
- URL Anchor；
- Copy Command；
- Related Docs；
- Related FAQ；
- 支持 error keyword。

初始 FAQ：

```text
25～35 条
```

### 验收

常见问题可以通过：

- 自然语言；
- 错误关键词；
- CLI；
- 端口；
- 功能名；

快速找到。

---

# Phase 6：Release 自动同步

### 任务

实现：

```text
Panel Release
↓
GitHub Action
↓
Nexus Dispatch
↓
读取稳定 Release
↓
读取 Tag 文档
↓
生成 release.json
↓
Build
↓
Deploy
```

### 验收

发布 BubbleSharkPanel 新版本后：

- Nexus 版本号自动更新；
- 安装命令自动更新；
- Release URL 自动更新；
- 无需人工修改首页版本。

---

# Phase 7：QA

至少验证：

## 设备

- Desktop；
- Tablet；
- Mobile。

## 浏览器

- Chrome；
- Firefox；
- Safari。

## 安装组合

- Docker + China；
- Docker + Global；
- Native + China；
- Native + Global。

## UI

- Dark Mode；
- Reduced Motion；
- Mobile Animation；
- Copy；
- Search；
- Anchor；
- 404。

## SEO

- Title；
- Description；
- OG；
- Sitemap；
- Robots；
- Canonical。

---

# Phase 8：发布

V1 推荐静态部署。

构建：

```text
Nuxt generate
```

发布后更新：

- BubbleSharkPanel README；
- GitHub About；
- Panel 首页；
- Release；
- QQ 群公告。

统一指向 Nexus。

最终生态：

```text
                GitHub
                   ↘
BubbleSharkPanel → Nexus → Install
                   ↓
                  FAQ
                   ↓
        QQ / Issue / Security
```

---

# 24. 功能优先级

## P0

必须完成：

- Nexus 基础工程；
- 首页；
- Installation Configurator；
- Docker / Native；
- China / Global；
- 安装教程；
- FAQ；
- Release 自动同步；
- SEO；
- 响应式。

## P1

上线后尽快：

- 迁移指南；
- Changelog 页面；
- FAQ 全文增强；
- 症状式故障排查；
- Roadmap；
- 安全指南。

## P2

后续社区阶段：

- 插件生态；
- 社区内容；
- Showcase；
- 第三方教程；
- Server Provider 集成；
- 多语言。

---

# 25. 成功指标

V1 的核心成功标准：

> **一个第一次听说 BubbleSharkPanel 的 DST 服主，可以不询问作者，从 Nexus 了解项目、完成安装并解决大多数常见问题。**

建议关注以下数据：

### 首页

- 首页 → Install 点击率；
- 在线体验点击率；
- GitHub 点击率。

### Install

- Configurator 使用率；
- Copy Command 次数；
- Docker / Native 选择比例；
- China / Global 比例。

### FAQ

- 搜索词；
- 无结果搜索词；
- FAQ 点击率；
- FAQ → QQ / Issue 跳转率。

这些数据可以直接指导后续文档补全。

---

# 26. 三个最关键的 Nexus 功能

## 第一优先级：Installation Configurator

```text
Docker / Native
+
China / Global
↓
正确安装命令
```

它能最大程度降低部署门槛。

---

## 第二优先级：症状导向 FAQ

用户不会思考：

> “这个错误属于部署层还是 Runtime 层？”

用户只知道：

> “房间搜不到。”

所以 Nexus 要从用户语言开始排错。

---

## 第三优先级：Release 自动同步

如果 Nexus 与 Panel 版本不同步，整个官方站的可信度会迅速下降。

因此：

> 所有安装内容必须跟 Stable Release 绑定。

---

# 27. 推荐 V1 开发顺序

实际开发建议严格按照以下顺序推进：

```text
1. 创建 bubble-shark-nexus
2. 搭 Nuxt / Content / Tailwind
3. 完成 Design Token
4. Header / Footer / Layout
5. 首页静态结构
6. 首页视觉与 Vue Bits
7. release.json
8. GitHub Release 数据同步
9. Installation Configurator
10. 安装教程
11. FAQ 数据模型
12. FAQ 内容迁移
13. FAQ Search
14. Community Support 分流
15. SEO
16. Mobile / Reduced Motion
17. QA
18. 上线
19. Panel README 接 Nexus
20. 收集搜索词与真实使用问题
```

---

# 28. V1 Definition of Done

满足以下条件即可认为 BubbleShark Nexus V1 完成：

- [ ] 独立 Nexus 仓库建立；
- [ ] `/` 首页上线；
- [ ] `/install` 安装中心上线；
- [ ] `/faq` FAQ 上线；
- [ ] 首页正确表达 BubbleSharkPanel 定位；
- [ ] Docker / Native 有清晰选择说明；
- [ ] China / Global 可生成正确安装命令；
- [ ] 安装命令与当前 Stable Release 同步；
- [ ] 支持一键复制安装命令；
- [ ] 安装后步骤完整；
- [ ] 端口要求清晰；
- [ ] 至少 25 条 FAQ；
- [ ] FAQ 支持关键词搜索；
- [ ] QQ / Issue / Security 分流完成；
- [ ] Release 自动同步；
- [ ] Desktop / Mobile 可用；
- [ ] Reduced Motion 可用；
- [ ] SEO Metadata 完成；
- [ ] BubbleSharkPanel README 指向 Nexus。

---

# 29. 最终原则

BubbleShark Nexus 的核心不是“做一个漂亮官网”。

它应该解决三个真实问题：

> **看懂 BubbleSharkPanel。**  
> **装上 BubbleSharkPanel。**  
> **自己解决 BubbleSharkPanel 的常见问题。**

GitHub 继续承担代码、Issue、Release 和开发者协作。

Nexus 则成为普通用户真正进入 BubbleSharkPanel 生态的第一站。

最终定位可以概括为：

> **GitHub 是开发者了解 BubbleSharkPanel 的地方；BubbleShark Nexus 是普通服主真正开始使用 BubbleSharkPanel 的地方。**
