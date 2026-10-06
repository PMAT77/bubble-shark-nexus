<script setup lang="ts">
const panel = usePanel()
</script>
<template>
  <a class="release-badge" :href="panel.releaseUrl" target="_blank" rel="noopener noreferrer">
    <span class="status-dot" />{{ panel.version }}<span class="badge-separator">/</span>{{ panel.channel }}
  </a>
</template>
