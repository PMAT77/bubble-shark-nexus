# BubbleSharkPanel · 饥荒联机版专用服务器管理面板

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/PMAT77/bubble-shark-panel/actions/workflows/ci.yml/badge.svg)](https://github.com/PMAT77/bubble-shark-panel/actions/workflows/ci.yml)
![Public Beta](https://img.shields.io/badge/status-Public%20Beta-orange)

**在浏览器里管理你的饥荒联机版专用服务器。**

创建实例、安装游戏、管理世界与 Mod、查看控制台、管理玩家和备份，都可以在一个面板里完成。

支持 Docker 与 Native（裸机）systemd 两种部署方式。

**开始使用： [官方社区](https://bubble-shark.online/) · [在线体验](#在线体验) · [立即安装](#快速安装) · [存档导入](#存档导入)**

![BubbleSharkPanel 面板预览](https://cdn.jsdelivr.net/gh/PMAT77/PMAT77CDN@main/imgs/game-server-hub/GameServer_B_1005.png)

## 在线体验

不用安装，也不用注册。

打开[在线预览](http://111.170.172.120:50155)，直接查看真实面板中的实例、世界配置、Mod、玩家和备份。

预览环境为只读模式，不会对真实服务器执行操作。

## 为什么用 BubbleSharkPanel

### 浏览器管理服务器

创建实例、安装游戏、启动世界、查看日志，都可以直接在面板中完成。

### 存档和面板备份

修改世界、导入存档、回档或重置世界前自动创建备份；面板数据库支持独立快照与恢复。

### 多人维护服务器

可以为不同运维成员创建独立账号，分别控制功能权限和实例范围，并记录操作账号。

角色决定能做什么，实例授权决定能管理哪些实例。

### 国内服务器支持

Steam 与 Mod 请求支持代理和缓存；镜像下载失败时，安装器会尝试使用 Release 离线镜像包完成部署。

### Docker 与 Native 双模式支持

Docker 模式运行面板与游戏容器；Native 模式使用 systemd 管理面板和游戏进程。

## 已经在用其他 DST 面板？

可以从下面这些使用场景判断 BubbleSharkPanel 是否适合你：

| 你需要什么                   | BubbleSharkPanel                 |
| ----------------------- | ------------------------------- |
| 快速创建 DST 服务器            | 图形化创建实例，SteamCMD 自动安装与更新        |
| 担心改错世界或丢存档              | 操作前自动备份，支持数据库快照与恢复              |
| 多人一起维护服务器               | 角色权限与实例授权分开管理                   |
| 国内服务器访问 Steam / Mod 不稳定 | 支持代理、缓存、镜像回退与离线部署               |
| 希望服务器完全由自己掌控            | 自托管，运行在自己的服务器上                  |
| 想选择 Docker 或裸机部署        | 提供 Docker 与 Native systemd 两种方式 |
| 已经有 DST 存档              | 支持导入既有存档                        |

## 存档导入

已有 DST 存档可以导入现有实例继续使用。

面板支持导入既有集群数据，并在导入过程中处理实例所需的配置。

支持分片端口重写、玩家名单与 Mod 清单带入，可选包含 Mod 文件供离线恢复；安全组需手工放行 6 个 UDP 端口。支持范围与手工步骤见[从其他面板或裸机迁入](docs/migrate-from-other-panel.md)。

## 快速安装

**强烈建议使用：[安装指南](https://bubble-shark.online/install)**

### Docker

海外或网络正常的 Linux 服务器，一条命令即可开始安装：

```bash
curl -fsSL "https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/v0.19.0/scripts/install.linux.sh" \
  | sudo bash -s -- --mode docker
```

安装完成后：

```text
打开浏览器
→
首次登录并修改密码
→
进入「实例管理」
→
创建第一个 DST 实例
```

安装器会自动安装 Docker 与 Compose 插件，并启动面板。

### 国内服务器或网络受限环境

先加上国内档位安装：

```bash
curl -fsSL "https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/v0.19.0/scripts/install.linux.sh" \
  | sudo bash -s -- --mode docker --network cn
```

<details>
<summary>只想看这台机器能不能装，先不安装</summary>

加 `--check` 只打印体检报告就退出：不装依赖、不建目录、不写安装状态文件、不拉镜像。

```bash
curl -fsSL "https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/v0.19.0/scripts/install.linux.sh" \
  | sudo bash -s -- --check
```

体检有阻塞项时返回退出码 1，也能直接串进自动化脚本。

</details>

详细说明见：

* [Docker 模式安装](docs/install-docker.md)
* [参数速查](docs/reference.md)

遇到安装问题可以运行：

```bash
sudo bsp doctor
```

### 裸机 systemd

不使用 Docker 时：

```bash
curl -fsSL "https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/v0.19.0/scripts/install.linux.sh" \
  | sudo bash -s -- --mode native
```

详细说明见：

* [裸机 systemd 模式安装](docs/install-native.md)

当前版本：

```text
v0.19.0 · Public Beta
```

## 能做什么

* **开服** —— 创建实例并安装 DST，之后在面板里更新和启动。
* **世界管理** —— 修改房间与世界配置，管理现有存档。
* **Mod 管理** —— 搜索、订阅、启停创意工坊 Mod，支持单 Mod ZIP 本地导入。
* **玩家管理** —— 管理管理员、白名单和黑名单，查看、踢出或封禁在线玩家。
* **备份** —— 定时备份，并在重要操作前创建安全备份。
* **控制台** —— 实时查看日志，直接向游戏下发命令。
* **多实例** —— 一台服务器同时运行多个独立实例。
* **权限管理** —— 角色控制操作权限，实例授权控制可管理范围。
* **服务器监控** —— 查看 CPU、内存、磁盘和网络状态。
* **环境自检** —— 检查运行环境、存储空间、实例状态和相关服务。
* **世界地形图** —— 从游戏地形数据导出世界地图。
* **面板快照** —— 备份、下载、恢复面板数据库。

## 部署方式

| 部署方式           | 适合场景               | 运行方式                |
| -------------- | ------------------ | ------------------- |
| Docker         | 游戏社区、希望使用容器的服务器    | 面板与游戏运行在 Docker 容器中 |
| Native systemd | 个人服务器、不希望使用 Docker | 面板与游戏直接由 systemd 管理 |

两种方式使用不同的运行环境，安装时选择一种即可。

## 适合谁

* 有自己的 Linux 服务器，希望用浏览器管理 DST。
* 不想频繁 SSH、修改配置文件和手动重启服务器。
* 需要多人一起维护服务器，并希望分别控制操作权限。
* 已经有 DST 存档，希望继续使用现有数据。

## 当前限制

* **Windows**：目前不支持 Windows 部署，当前部署目标为 Debian 12、Ubuntu 22.04 / 24.04 等 apt 系 Linux。
* **更多游戏**：目前完整适配的首个游戏是《饥荒联机版》。
* **多节点与租户能力**：多节点统一管理、组织 / 租户隔离和 SSO 仍在规划中。

## 安全

Docker 模式需要访问 Docker Socket 才能管理游戏容器，因此面板具有较高的宿主机控制能力。

使用 Docker 部署时：

* 请为面板设置强密码。
* 不建议将面板直接暴露在公网。
* 建议限制面板访问来源，并在反向代理层增加访问控制。
* 面板中的权限控制只限制面板操作，不等于宿主机隔离。

完整说明见 [SECURITY.md](SECURITY.md)。

## 常见问题

### 可以导入现有 DST 存档吗？

可以。

把源机器的集群目录打成压缩包，用面板「备份与恢复 → 导入外部存档」导入即可；支持范围与手工步骤见[从其他面板或裸机迁入](docs/migrate-from-other-panel.md)。

### 会不会丢存档？

重要操作前会自动创建备份，面板数据库还支持独立快照与恢复。

涉及存档迁移、回档和恢复时，建议先保留一份额外备份。

### 支持 Windows 吗？

目前不支持 Windows 部署。

当前支持 Debian 12、Ubuntu 22.04 / 24.04 等 apt 系 Linux。

### Docker 和裸机有什么区别？

Docker 模式通过容器运行面板和游戏。

Native 模式直接使用 systemd 管理面板和游戏进程。

根据你的服务器环境选择即可。

### 国内服务器可以安装吗？

可以。

安装器支持国内网络环境下的安装路径，并在镜像下载失败时尝试使用 Release 离线镜像包。

详细步骤见[国内服务器安装说明](docs/install-docker.md#安装国内服务器)。

### 为什么 Docker 模式需要 Docker Socket？

面板需要通过 Docker 管理游戏容器，因此必须访问 Docker Socket。

这也是 Docker 部署需要特别注意宿主机安全的原因。

### 为什么现在只支持 DST？

当前先把《饥荒联机版》的开服与日常运维体验做好，之后再逐步增加其他 Steam 专用服务器。

### 升级会不会删除实例和存档？

正常升级会保留现有实例、存档和配置，并在升级前自动备份面板数据库。

具体升级行为见对应部署方式的安装文档。

## Roadmap

当前阶段重点：

* 完善 DST 开服体验
* 完善 DST 日常运维能力
* 提升安装与升级稳定性
* 持续优化国内网络环境下的部署体验

后续方向：

* 更多 Steam 专用服务器适配
* 多节点管理
* 组织 / 租户隔离
* SSO
* 插件在线分发

## 参与贡献

欢迎提交 [Issue](https://github.com/PMAT77/bubble-shark-panel/issues) 与 [Pull Request](https://github.com/PMAT77/bubble-shark-panel/pulls)。

开发流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

安全问题见 [SECURITY.md](SECURITY.md)。

版本变更见 [CHANGELOG.md](CHANGELOG.md)。

### 技术栈

* 前端：Vue 3、Vite、Fantastic-admin
* 后端：Fastify、Drizzle ORM
* 数据库：SQLite
* 包管理：pnpm

## 交流与反馈

![QQ 群：1055694763](https://img.shields.io/badge/QQ%E7%BE%A4-1055694763-12B7F5?logo=tencentqq\&logoColor=white)

公测版本、安装部署、使用问题和功能建议都可以在群里交流。

* 部署 / 配置 / 使用问题 → QQ 群
* 可复现 Bug / 功能请求 → [提交 Issue](https://github.com/PMAT77/bubble-shark-panel/issues)

## 赞助与商业服务

**Community 核心功能永久免费开源。**

如果项目帮你节省了服务器运维时间，可以通过微信支持项目。

<table>
  <tr>
    <td align="center"><img src="https://cdn.jsdelivr.net/gh/PMAT77/PMAT77CDN@main/imgs/common/collection_wechat.jpg" alt="微信赞助" width="200" /><br />微信赞赏</td>
    <td align="center"><img src="https://cdn.jsdelivr.net/gh/PMAT77/PMAT77CDN@main/imgs/common/WeChat.jpg" alt="微信联系：PMAT77" width="195" /><br />微信联系</td>
  </tr>
</table>

同时提供：

* 服务器代搭建
* 存档与面板迁移
* 私有化部署
* 其他 Steam 专用服务器适配
* 功能定制开发

商务联系：微信 `PMAT77`

## 许可证

Community 源代码采用 [MIT License](LICENSE)。

```text
Copyright (c) 2026 BubbleSharkPanel
SPDX-License-Identifier: MIT
```

**BubbleSharkPanel** — 让开服像点一下那么简单。
