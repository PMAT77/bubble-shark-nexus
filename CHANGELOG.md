# Changelog

## [Unreleased]

### Added

- Panel 正式 Release 发布后自动同步版本基线，检查通过后推送 main 并触发 GitHub Pages 部署；支持指定 tag、SHA 核对和防止版本倒退。

- 初始化独立 Nuxt 4 / Content 3 / Tailwind 4 静态站点，提供首页、安装中心和 FAQ。
- 复用 BubbleSharkPanel 品牌素材，建立浅粉主题、响应式导航、基础 SEO 与错误页。
- 安装配置器支持 Docker / Native、国内 / 海外、防火墙选项与环境体检，安装器下载后校验 SHA-256。
- 建立基于已发布 commit 的 Panel 内容快照、Release 同步、来源检查和 9 条 FAQ 种子内容。
- 添加命令组合与文档解析检查、CI 和 Release dispatch 接收工作流。

### Changed

- Panel 内容基线同步至 v0.15.3，更新固定提交、安装器 SHA-256、部署文档与 9 条 FAQ；原文快照包含 Native 预检和 GHCR 探测失败处理修复。
