---
slug: "install-errors"
title: "安装卡住或下载失败怎么办？"
category: "安装"
keywords: ["compose","TLS","waiting","GHCR","Mod","doctor"]
errorCodes: ["TLS handshake timeout","checksum mismatch","Image pull failed"]
relatedDocs: ["docs/install-docker.md"]
order: 5
sourceRef: "ce5a6056a10ef138dd783d34b8e2811c845a1a83"
---

| 报错关键词 | 怎么处理 |
| --- | --- |
| 镜像层下载 `net/http: TLS handshake timeout` 或长时间 `Waiting` | 国内最常见的形态：registry 元数据正常、层数据拉不动。`--network cn` 下默认已走离线包；若仍卡在直拉，用 `BSP_IMAGE_SOURCE=offline` 重跑。安装器连续 90 秒无进度会主动中断，不会永久挂住 |
| `Cannot reach GHCR` / `Image pull failed` | 同上。定位用 `curl -I https://ghcr.io/v2/`（返回 401 属正常）；「清单能取到、层下载超时」是网络不可达，不是鉴权问题，重试和换代理都不会成功 |
| `Docker Compose v2 plugin is required but unavailable` | 按报错里的手动命令装插件后重跑安装器，命令见「安装（国内服务器）」的折叠块 |
| 装之前想知道会走哪条路线 | `sudo bash "install-${tag}.sh" --check`：只打印体检报告（系统、架构、内存、磁盘、Docker、GHCR 与 Steam CDN 可达性、端口占用），不改动系统 |
| `download.docker.com` 不可达 | 安装器会自动回退发行版自带的 `docker.io`；apt 慢就加 `--network cn`，其余查 apt 源签名、系统时间与 HTTPS 出站 |
| `checksum mismatch` | 下载内容与 Release 不一致。清掉代理或 CDN 缓存，确认 `BSP_RELEASE_TAG` 与资源 URL 是同一版本 |
| 面板不断重启 | `docker logs --tail 100 bubblesharkpanel-panel` 定位，常见为端口占用、`panel.env` 缺键或数据库权限；修正后 `docker compose up -d panel` |
| 玩家搜不到房间 | 先查安全组是否放行了全部 6 个 UDP 端口，再确认房间没勾「离线」模式、已保存集群令牌 |
| Mod 市场列表取不到 | 面板的 Steam 请求走自己的代理配置，见[参数速查 · Steam 与 Mod 市场](https://github.com/PMAT77/bubble-shark-panel/blob/ce5a6056a10ef138dd783d34b8e2811c845a1a83/docs/reference.md#steam-与-mod-市场) |
| 从其他面板或裸机迁过来 | 把源机器的集群目录打成压缩包，再用面板「备份与恢复 → 导入外部存档」导入；能自动完成与需手工处理的项目见[从其他面板或裸机迁入](https://github.com/PMAT77/bubble-shark-panel/blob/ce5a6056a10ef138dd783d34b8e2811c845a1a83/docs/migrate-from-other-panel.md) |

排查时还能用 `bsp doctor` 做一次全面体检，或用 `bsp logs` 跟面板日志。参数与变量见[参数速查](https://github.com/PMAT77/bubble-shark-panel/blob/ce5a6056a10ef138dd783d34b8e2811c845a1a83/docs/reference.md)。
