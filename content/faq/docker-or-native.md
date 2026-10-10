---
slug: "docker-or-native"
title: "Docker 与 Native 怎么选？"
category: "开始之前"
keywords: ["docker","native","systemd","系统","内存"]
errorCodes: []
relatedDocs: ["docs/install-native.md","docs/install-docker.md"]
order: 1
sourceRef: "96a43abc752c4aeebd6cb42894d9c8ade53a0439"
---

### Docker

面板与游戏都跑在容器里，由 Docker Compose 编排。适合小型游戏社区与托管商。

**环境要求**：Debian 12 或 Ubuntu 22.04 / 24.04（只支持 apt 系），root 或 sudo，至少 4 GiB 内存，根分区至少 4 GiB 空闲——离线镜像包约 227 MB，导入后本地镜像约 560 MB（包可删），另外要给游戏本体（数 GB）和存档备份留地方。

小内存机的缓存区由安装器自动配置：总内存低于 5 GiB 且当前没有缓存区时它会创建 swapfile 并写进 `/etc/fstab`（`--no-swap` 可关闭）。分片加载整套 Mod 时内存会短时冲高，没有缓存区会被内核在加载途中杀掉，表现为「实例显示运行中但大厅搜不到」。从旧版本升级上来的机器仍可手动执行 `sudo bsp setup-swap`。档位参考[内存档位](https://github.com/PMAT77/bubble-shark-panel/blob/96a43abc752c4aeebd6cb42894d9c8ade53a0439/docs/MEMORY.md)。

Windows 不是部署目标，只用于本机开发调试。

### Native

面板是系统级 systemd 服务，游戏分片是 `bsp` 用户的 systemd 服务。不装 Docker，也不用 tmux、screen 或 PM2。适合个人服主。

**环境要求**：Debian 12 或 Ubuntu 22.04 / 24.04（只支持 apt 系），root 或 sudo，x86_64，至少 4 GiB 内存，根分区至少 4 GiB 空闲——游戏本体要数 GB，另外要给存档备份留地方。安装器会装 32 位运行库（`libcurl4:i386` 等），DST 与 SteamCMD 需要。

小内存机的缓存区由安装器自动配置（总内存低于 5 GiB 且当前没有缓存区时创建 swapfile 并写进 `/etc/fstab`，`--no-swap` 可关闭）；从旧版本升级上来的机器可手动执行 `sudo bsp setup-swap`。档位参考[内存档位](https://github.com/PMAT77/bubble-shark-panel/blob/96a43abc752c4aeebd6cb42894d9c8ade53a0439/docs/MEMORY.md)。Windows 不是部署目标，只用于本机开发调试。
