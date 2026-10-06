<script setup lang="ts">
defineProps<{ code?: string; language?: string; filename?: string }>()
</script>
<template>
  <NexusCommandBlock :command="code ?? ''" :label="filename || (language === 'bash' ? '在服务器终端执行' : '原文片段')" />
</template>
