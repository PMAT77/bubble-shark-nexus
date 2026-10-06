<script setup lang="ts">
const panel = usePanel()
</script>
<template>
  <div class="table-scroll">
    <table class="port-table"><caption>默认入站端口；实例自定义端口以世界设置为准</caption><thead><tr><th scope="col">用途</th><th scope="col">协议</th><th scope="col">端口</th><th scope="col">适用</th></tr></thead><tbody><tr v-for="port in panel.ports" :key="port.sourceKey"><th scope="row">{{ port.name }}</th><td>{{ port.protocol }}</td><td><code>{{ port.port }}</code></td><td>{{ port.when }}</td></tr></tbody></table>
  </div>
</template>
