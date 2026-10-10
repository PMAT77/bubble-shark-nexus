---
slug: "native-errors"
title: "Native 服务或实例启动失败怎么办？"
category: "排错"
keywords: ["systemd","native","bus","Mod","重启"]
errorCodes: ["Failed to connect to bus","cross-mode migration is not supported"]
relatedDocs: ["docs/install-native.md"]
order: 6
sourceRef: "dd39ea940d144c13cffd7cc6d528a860f3ae2fb2"
---

| 报错关键词 | 怎么处理 |
| --- | --- |
| `Native Release ... missing` | Release 里没有对应版本的包与 `.sha256`。换已发布版本，或用 `BSP_NATIVE_RELEASE_ARCHIVE` 指定本地包 |
| GitHub Raw / Release 取不到 | 换加速代理前缀重试；仍不通就手动下载脚本与包，见上面的折叠块 |
| `systemd user manager` / `Failed to connect to bus` | 用户的 systemd 实例没起来，按下面的命令修复。**不要用 tmux、screen 或 PM2 绕过**，那会破坏日志、自恢复与资源限制语义 |
| `has a bad unit file setting` | systemd 不说是哪一行。分片 unit 在数据目录下，用用户实例解析它：`sudo -u bsp env XDG_RUNTIME_DIR=/run/user/$(id -u bsp) systemd-analyze --user verify <unit 路径>`。**启动失败后 unit 会被删掉，要尽快看** |
| 实例启动后立刻退出 | 常见为集群令牌失效、Mod 下载不全、内存不足。面板的实例详情会直接写出原因（如「内存不足被系统终止」），一般不用登录服务器判断 |
| Docker 与 Native 混装报 `cross-mode migration is not supported` | 两种模式之间不自动迁移。保留数据目录后按目标模式重装，再手工迁移 `/var/lib/bubblesharkpanel` 下的数据 |
| 玩家搜不到房间 | 先查安全组是否放行了全部 6 个 UDP 端口，再确认房间没勾「离线」模式、已保存集群令牌 |
| Mod 市场列表取不到 | 面板的 Steam 请求走自己的代理配置，见[参数速查 · Steam 与 Mod 市场](https://github.com/PMAT77/bubble-shark-panel/blob/dd39ea940d144c13cffd7cc6d528a860f3ae2fb2/docs/reference.md#steam-与-mod-市场) |
| 从其他面板或裸机迁过来 | 把源机器的集群目录打成压缩包，再用面板「备份与恢复 → 导入外部存档」导入；能自动完成与需手工处理的项目见[从其他面板或裸机迁入](https://github.com/PMAT77/bubble-shark-panel/blob/dd39ea940d144c13cffd7cc6d528a860f3ae2fb2/docs/migrate-from-other-panel.md) |

`systemd user manager` 那一类的修复命令：

```bash
sudo loginctl enable-linger bsp
BSP_UID="$(id -u bsp)"
sudo systemctl restart "user@${BSP_UID}.service"
sudo systemctl restart bubblesharkpanel.service
sudo loginctl show-user bsp -p Linger
```

内存告警、OOM 判断与档位建议见[内存档位](https://github.com/PMAT77/bubble-shark-panel/blob/dd39ea940d144c13cffd7cc6d528a860f3ae2fb2/docs/MEMORY.md)，参数与变量见[参数速查](https://github.com/PMAT77/bubble-shark-panel/blob/dd39ea940d144c13cffd7cc6d528a860f3ae2fb2/docs/reference.md)。
