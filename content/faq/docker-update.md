---
slug: "docker-update"
title: "Docker 如何更新和回滚？"
category: "更新"
keywords: ["升级","更新","回滚","数据库","备份"]
errorCodes: []
relatedDocs: ["docs/install-docker.md"]
order: 8
sourceRef: "24a9a42dacd3708f7219b29fb0d46ba928225c71"
---

面板内「系统设置 → 面板与游戏版本」两步走：先「下载更新」，再「立即安装」。下载段默认优先取 Release 离线镜像包（走加速代理并校验同名 `.sha256`），失败才回退 GHCR 拉取；下载中断会断点续传，不影响正在运行的面板。

**安装完成后请刷新浏览器页面**（Ctrl/Cmd+Shift+R），否则还在跑升级前的界面脚本。

不想用面板也可以用旧 tag 重跑安装脚本，或把 `panel.env` 的 `PANEL_IMAGE` 指向旧 tag 后执行 `bsp update`——两种都是同模式原地升级，保留数据库、实例、存档与自定义配置，升级前会自动备份数据库。

> 回滚不碰游戏存档，但**旧版本可能不认识新版本迁移过的数据库**。跨版本回滚前先在面板「备份与恢复」页做一次数据库快照。
