<script setup lang="ts">
import { ArrowUpRight, CodeXml, MessagesSquare, ShieldCheck } from '@lucide/vue'
const panel = usePanel()
</script>
<template>
  <section class="support-panel" aria-labelledby="support-title">
    <div><p class="eyebrow">一起把服务器运行好</p><h2 id="support-title">需要一点帮助？</h2></div>
    <div class="support-links">
      <a :href="`${panel.repositoryUrl}#交流与反馈`" target="_blank" rel="noopener noreferrer"><MessagesSquare :size="19" aria-hidden="true" /><span>部署与使用<small>QQ 群 {{ panel.qqGroup }}</small></span><ArrowUpRight :size="16" aria-hidden="true" /></a>
      <a :href="`${panel.repositoryUrl}/issues/new/choose`" target="_blank" rel="noopener noreferrer"><CodeXml :size="19" aria-hidden="true" /><span>Bug 与功能建议<small>GitHub Issues</small></span><ArrowUpRight :size="16" aria-hidden="true" /></a>
      <a :href="`${panel.repositoryUrl}/security/policy`" target="_blank" rel="noopener noreferrer"><ShieldCheck :size="19" aria-hidden="true" /><span>安全漏洞<small>私下报告安全问题</small></span><ArrowUpRight :size="16" aria-hidden="true" /></a>
    </div>
  </section>
</template>
