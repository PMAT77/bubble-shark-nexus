<script setup lang="ts">
import type { NuxtError } from '#app'
const props = defineProps<{ error: NuxtError }>()
useSeoMeta({ title: `${props.error.statusCode} · BubbleShark Nexus`, robots: 'noindex' })
</script>
<template>
  <main class="container error-page">
    <p class="eyebrow">BubbleShark Nexus / {{ error.statusCode }}</p>
    <h1>{{ error.statusCode === 404 ? '这片海域还没有航标。' : '页面暂时无法加载。' }}</h1>
    <p>{{ error.statusCode === 404 ? '页面可能已移动。回到首页，或从安装中心继续。' : '请刷新页面后重试。' }}</p>
    <button class="button button-primary" @click="clearError({ redirect: '/' })">返回首页</button>
  </main>
</template>
