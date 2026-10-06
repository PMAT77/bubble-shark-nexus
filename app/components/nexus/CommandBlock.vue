<script setup lang="ts">
import { Check, Copy } from '@lucide/vue'
const props = defineProps<{ command: string; label?: string }>()
const status = ref('')
watch(() => props.command, () => { status.value = '' })
async function copy(command: string) {
  try {
    await navigator.clipboard.writeText(command)
    status.value = '已复制'
  } catch {
    status.value = '复制失败，请选中命令手动复制'
  }
}
</script>

<template>
  <div class="command-block">
    <div class="command-heading">
      <span>{{ label || '在 Linux 服务器终端执行' }}</span>
      <button type="button" class="copy-button" @click="copy(command)">
        <Check v-if="status === '已复制'" :size="15" aria-hidden="true" /><Copy v-else :size="15" aria-hidden="true" />
        {{ status === '已复制' ? '已复制' : '复制命令' }}
      </button>
    </div>
    <pre tabindex="0"><code>{{ command }}</code></pre>
    <span class="sr-only" role="status">{{ status }}</span>
    <p v-if="status && status !== '已复制'" class="copy-error">{{ status }}</p>
  </div>
</template>
