<script setup lang="ts">
import { ArrowUpRight, CodeXml, Menu, X } from '@lucide/vue'
const panel = usePanel()
const menuOpen = ref(false)
const route = useRoute()
watch(() => route.path, () => { menuOpen.value = false })
</script>

<template>
  <div class="site-shell">
    <a class="skip-link" href="#main-content">跳至主要内容</a>
    <header class="site-header">
      <div class="container header-inner">
        <NuxtLink to="/" class="brand" aria-label="BubbleShark Nexus 首页">
          <img src="/logo/shark.png" alt="" width="44" height="44" class="brand-mark" />
          <span>BubbleShark<span class="brand-subtitle">NEXUS</span></span>
        </NuxtLink>
        <button class="mobile-menu" type="button" :aria-expanded="menuOpen" aria-controls="site-nav" :aria-label="menuOpen ? '关闭导航' : '打开导航'" @click="menuOpen = !menuOpen"><X v-if="menuOpen" :size="22" /><Menu v-else :size="22" /></button>
        <nav id="site-nav" :class="['site-nav', { 'is-open': menuOpen }]" aria-label="主导航">
          <NuxtLink to="/">首页</NuxtLink><NuxtLink to="/install">安装中心</NuxtLink><NuxtLink to="/faq">FAQ</NuxtLink>
          <a :href="panel.repositoryUrl" target="_blank" rel="noopener noreferrer" class="github-link"><CodeXml :size="16" aria-hidden="true" />GitHub</a>
          <a :href="panel.demoUrl" target="_blank" rel="noopener noreferrer" class="nav-demo">在线体验<ArrowUpRight :size="15" aria-hidden="true" /></a>
        </nav>
      </div>
    </header>
    <main id="main-content"><slot /></main>
    <footer class="site-footer container">
      <div><NuxtLink to="/" class="footer-brand">BubbleShark Nexus</NuxtLink><p>让开服，像点一下那么简单。</p></div>
      <div class="footer-meta"><a :href="`${panel.repositoryUrl}/blob/${panel.sourceRef}/LICENSE`">MIT License</a><a :href="panel.releaseUrl">Panel {{ panel.version }}</a><span>为 DST 服主而建</span></div>
    </footer>
  </div>
</template>
