<script setup lang="ts">
import { ArrowRight, ArrowUpRight, Archive, Boxes, Globe, LifeBuoy, Network, Users } from '@lucide/vue'
import SpotlightCard from '~/components/vue-bits/SpotlightCard.vue'
const panel = usePanel()
usePageSeo('BubbleSharkPanel - 饥荒联机版 DST 开服与服务器管理面板', '专为饥荒联机版打造的自托管服务器管理面板。通过 BubbleShark Nexus 了解 Docker 与 Native 部署、安装方法和常见问题。')
const features = [
  { icon: Globe, title: '世界与洞穴，统一管理', text: '创建 DST 实例，配置世界、集群令牌与分片，查看运行状态。' },
  { icon: Boxes, title: 'Mod，不再手工搬文件', text: '浏览 Mod 市场，管理订阅与配置，也可以导入本地 Mod。' },
  { icon: Network, title: '为国内网络做好准备', text: '国内安装档位、下载代理与离线镜像回退，让安装继续向前。' },
  { icon: Archive, title: '为存档留一条退路', text: '备份与恢复世界，导入已有的 DST 集群，继续和朋友冒险。' },
  { icon: Users, title: '和朋友一起管理', text: '通过成员、角色与实例授权，分配每个人可以执行的操作。' },
  { icon: LifeBuoy, title: '看得见，也查得清', text: '在浏览器查看控制台和监控，用 bsp doctor 检查部署状态。' }
]
const steps = ['准备 Linux 服务器', '安装 BubbleSharkPanel', '创建 DST 实例', '配置世界并启动']
</script>

<template>
  <div class="container">
    <section class="hero">
      <div class="hero-copy"><div class="hero-eyebrow"><span class="status-dot" />专为饥荒联机版而建 / SELF-HOSTED</div>
        <h1>让开服，<br />像点一下<br class="mobile-break" /><em>那么简单。</em></h1>
        <p class="hero-description">你的世界，你来掌舵。<br />实例、Mod、玩家与备份，<br class="mobile-break" />在一个浏览器里管理。</p>
        <div class="hero-actions"><NuxtLink class="button button-primary" to="/install">开始安装<ArrowRight :size="18" aria-hidden="true" /></NuxtLink><a class="button button-secondary" :href="panel.demoUrl" target="_blank" rel="noopener noreferrer">在线体验<ArrowUpRight :size="17" aria-hidden="true" /></a></div>
        <div class="hero-meta"><NexusReleaseBadge /><span>开源 · 自托管 · MIT</span></div>
      </div>
      <div class="sonar-scene" aria-hidden="true"><div class="sonar-ring ring-one" /><div class="sonar-ring ring-two" /><div class="sonar-ring ring-three" /><div class="sonar-axis" /><div class="sonar-sweep" /><span class="sonar-shark" /><span class="sonar-label sonar-label-top">BUBBLESHARK / NEXUS</span><span class="sonar-label sonar-label-bottom">YOUR WORLD. YOUR SERVER.</span><span class="signal signal-one" /><span class="signal signal-two" /></div>
    </section>
    <div class="intro-strip"><p>BubbleSharkPanel <span>《饥荒联机版》专用服务器管理面板</span></p><a :href="panel.repositoryUrl" target="_blank" rel="noopener noreferrer">查看 GitHub<ArrowUpRight :size="16" aria-hidden="true" /></a></div>
    <section class="section" aria-labelledby="steps-title"><div class="section-heading"><div><p class="eyebrow">从一台服务器，到一个新世界</p><h2 id="steps-title">四步，和朋友一起出发。</h2></div><NuxtLink to="/install" class="text-link">打开安装指南<ArrowRight :size="17" aria-hidden="true" /></NuxtLink></div>
      <ol class="launch-steps"><li v-for="(step, index) in steps" :key="step"><span>{{ String(index + 1).padStart(2, '0') }}</span><strong>{{ step }}</strong></li></ol>
    </section>
    <section class="section features-section" aria-labelledby="features-title"><div class="section-heading"><div><p class="eyebrow">少一点运维，多一点冒险</p><h2 id="features-title">把开服的日常，交给面板。</h2></div><p class="heading-note">从第一次开服，到长期运行。</p></div>
      <div class="features-grid"><SpotlightCard v-for="feature in features" :key="feature.title" class-name="feature-card" spotlight-color="var(--color-blush)"><component :is="feature.icon" :size="25" class="feature-icon" aria-hidden="true" /><h3>{{ feature.title }}</h3><p>{{ feature.text }}</p></SpotlightCard></div>
    </section>
    <section class="section mode-section" aria-labelledby="mode-title"><div><p class="eyebrow">选择适合你的部署方式</p><h2 id="mode-title">同一个面板。<br />两条上船的路。</h2><p>不确定如何选择时，先使用 Docker。<br />已有 systemd 运维经验，也可以选择 Native。</p></div><div class="mode-comparison"><div><span class="eyebrow">默认推荐</span><h3>Docker</h3><p>面板与 DST 在容器中运行，<br />由 Docker Compose 管理。</p><NuxtLink class="text-link" to="/install">配置安装方案<ArrowRight :size="16" aria-hidden="true" /></NuxtLink></div><div><span class="eyebrow">无需 Docker</span><h3>Native</h3><p>面板与 DST 由 systemd 管理。<br />适合明确选择裸机部署的服主。</p><a class="text-link" :href="`${panel.repositoryUrl}/blob/${panel.sourceRef}/docs/install-native.md`">了解 Native<ArrowUpRight :size="16" aria-hidden="true" /></a></div></div></section>
    <section class="migration-callout"><Archive :size="30" aria-hidden="true" /><div><h3>已经有自己的世界？</h3><p>导入现有 DST 存档，带着朋友和进度继续冒险。</p></div><a class="text-link" :href="`${panel.repositoryUrl}/blob/${panel.sourceRef}/docs/migrate-from-other-panel.md`">查看迁移指南<ArrowUpRight :size="16" aria-hidden="true" /></a></section>
    <NexusSupportChannels />
  </div>
</template>
