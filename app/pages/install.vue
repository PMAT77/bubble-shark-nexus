<script setup lang="ts">
const panel = usePanel()
usePageSeo('BubbleSharkPanel 安装教程 - Docker / Native DST 开服', '选择服务器部署方式和网络环境，生成与当前 Release 同步的 BubbleSharkPanel 安装命令，完成首次登录、开放端口和 DST 实例创建。')
const { data: guide } = await useAsyncData('install-start', () => queryCollection('install').path('/install/start').first())
const passwordCommand = `sudo sed -n 's/^ADMIN_PASSWORD=//p' ${panel.installDir}/panel.env`
</script>

<template>
  <div class="container">
    <header class="page-heading"><p class="eyebrow">从这里开始 / INSTALLATION</p><h1>下一站，你的服务器。</h1><p>选好部署方式与网络环境，跟着步骤完成第一次开服。</p></header>
    <NexusInstallConfigurator />
    <div class="install-guide"><aside class="guide-nav" aria-label="安装步骤"><p class="eyebrow">安装之后</p><a href="#first-login">01 首次登录</a><a href="#ports">02 开放端口</a><a href="#first-world">03 创建世界</a><NuxtLink to="/faq">遇到问题？查看 FAQ →</NuxtLink></aside><div>
      <section id="first-login" class="guide-section"><span class="step-label">01 / FIRST LOGIN</span><h2>找到面板，完成首次登录。</h2><p>安装摘要会显示访问地址和初始密码。默认管理员为 <code>{{ panel.adminUsername }}</code>；首次登录后按提示修改密码。</p><p>如果安装摘要已经滚走，可在服务器终端查看初始密码：</p><NexusCommandBlock :command="passwordCommand" label="只在自己的服务器上读取凭据" /><p class="hint">初始密码用于首次登录。已经改过密码时，请按部署文档处理。</p></section>
      <section id="ports" class="guide-section"><span class="step-label">02 / NETWORK</span><h2>让你的世界可以被找到。</h2><p>云平台安全组与 Linux 本机防火墙都需要放行。面板端口建议只允许自己的常用 IP 访问，游戏端口使用 UDP。</p><NexusPortTable /><p class="hint">服务器位于 NAT 后面时，逐条配置端口转发，保持外部端口与世界设置一致。</p></section>
      <section id="first-world" class="guide-section"><span class="step-label">03 / YOUR FIRST WORLD</span><h2>直到第一个世界已就绪。</h2><ContentRenderer v-if="guide" :value="guide" class="prose" /><p v-else>打开面板的「实例管理」，创建实例并安装 DST，填写集群令牌，配置世界后启动。</p><div class="ready-note"><span class="status-dot" /><span>看到「世界已就绪」，再到游戏里寻找房间。</span></div></section>
    </div></div>
    <NexusSupportChannels />
  </div>
</template>
