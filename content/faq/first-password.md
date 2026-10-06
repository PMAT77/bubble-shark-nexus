---
slug: "first-password"
title: "初始账号和密码在哪里？"
category: "登录"
keywords: ["superadmin","密码","登录","ADMIN_PASSWORD"]
errorCodes: []
relatedDocs: ["docs/install-docker.md"]
order: 3
sourceRef: "ce5a6056a10ef138dd783d34b8e2811c845a1a83"
---

管理员名默认 `superadmin`，初始密码由安装器随机生成，安装摘要里会直接打印出来。首次登录会强制改密，改密要求 8-64 位且包含大小写字母、数字与特殊字符。

安装摘要已滚走时，从 `panel.env` 读：

```bash
sudo sed -n 's/^ADMIN_PASSWORD=//p' /opt/bubblesharkpanel/panel.env
```

如果登录提示密码错误，说明容器没收到这个变量（旧版 compose 或手动 `docker run` 漏了 `-e`），改读容器内的凭据文件：

```bash
docker exec bubblesharkpanel-panel cat /app/data/admin-credentials.txt
```

首次登录会拦到改密页，改完凭据文件自动删除。
