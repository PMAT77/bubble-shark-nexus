---
slug: "mod-network"
title: "Mod 市场加载失败，代理在哪里配置？"
category: "Mod"
keywords: ["mod","steam","代理","网络","市场"]
errorCodes: []
relatedDocs: ["docs/reference.md"]
order: 9
sourceRef: "24a9a42dacd3708f7219b29fb0d46ba928225c71"
---

面板自身的 Steam 请求与 SteamCMD 是**两套配置**：上面这组管 Mod 市场列表与详情，下面这组管游戏与 Mod 文件的下载。

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `BSP_STEAM_HTTPS_PROXY` | 空 | 面板侧代理。Docker 模式下代理在宿主机时写 `http://host.docker.internal:7890` |
| `BSP_STEAM_WEBAPI_BASE_URL` | 官方 | `api.steampowered.com` 的反代，**带路径前缀时结尾必须加 `/`** |
| `BSP_STEAM_COMMUNITY_BASE_URL` | 官方 | `steamcommunity.com` 的反代 |
| `BSP_STEAM_WEBAPI_KEY` | 空 | 用官方 Web API 拉列表，稳定性高于页面抓取 |
| `BSP_STEAM_RELAY_URL` | 空 | 完全连不上 Steam 时走海外中继 |
| `BSP_STEAMCMD_DOWNLOAD_REGION` | 不设置 | 已废弃；旧配置兼容读取并忽略，下载节点由 SteamCMD 自动选择 |
| `BSP_STEAMCMD_INSTALL_MAX_ATTEMPTS` | `5` | 安装重试次数，最多 20；国内建议 `8` |
| `BSP_STEAMCMD_APP_UPDATE_TIMEOUT_MS` | `3600000` | 单次 app_update 超时（毫秒），大体积游戏慢链路上调到 2 小时 |
| `BSP_STEAMCMD_HTTPS_PROXY` | 空 | SteamCMD 侧代理配置；游戏 CDN 是否走代理需实际验证。桥接容器访问宿主机代理使用 `host.docker.internal`，`127.0.0.1` 指容器自己 |
| `BSP_STEAMCMD_INSTALL_RETRY_DELAYS_MS` | `4000,8000,8000,8000` | 每次重试前的等待毫秒数，逗号分隔 |

<details>
<summary>连不上 Steam 时面板会怎样</summary>

Mod 市场列表会退回最近一次成功拉取的内容（默认 7 天内），界面上标注「离线数据 · 最后更新于 X」；单个请求最多等 10 秒。要确认当前实际生效的链路与代理状态，看面板「系统设置 → 环境自检」里的「Mod 市场上游」一项。

</details>

---

完整键名与逐条注释见仓库根目录 [`panel.env.example`](https://github.com/PMAT77/bubble-shark-panel/blob/24a9a42dacd3708f7219b29fb0d46ba928225c71/panel.env.example)，内存档位的推荐取值见[内存档位](https://github.com/PMAT77/bubble-shark-panel/blob/24a9a42dacd3708f7219b29fb0d46ba928225c71/docs/MEMORY.md)。本页与脚本默认值不一致时，以 `sudo bash ./scripts/install.linux.sh --help` 的输出为准。
