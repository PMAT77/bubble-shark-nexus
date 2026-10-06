<script setup lang="ts">
import { ArrowDownToLine, Box, Server } from '@lucide/vue'
import { buildInstallCommand } from '~~/shared/utils/install-command'
const panel = usePanel()
const mode = ref<'docker' | 'native'>('docker')
const network = ref<'cn' | 'global'>('cn')
const openPanelPort = ref(false)
const openDstPorts = ref(false)
const options = computed(() => ({ mode: mode.value, network: network.value, openPanelPort: openPanelPort.value, openDstPorts: openDstPorts.value }))
const command = computed(() => buildInstallCommand(panel, options.value))
const checkCommand = computed(() => buildInstallCommand(panel, { ...options.value, checkOnly: true }))
</script>

<template>
  <section class="install-configurator" aria-labelledby="config-title">
    <div class="config-options">
      <div class="config-title"><ArrowDownToLine :size="22" aria-hidden="true" /><h2 id="config-title">配置你的安装方案</h2></div>
      <fieldset><legend><span>01</span>选择部署方式</legend>
        <div class="option-grid">
          <label :class="['option-card', { selected: mode === 'docker' }]"><input v-model="mode" type="radio" value="docker" name="mode" /><Box :size="22" aria-hidden="true" /><strong>Docker <small>推荐</small></strong><span>容器运行，由 Compose 管理</span></label>
          <label :class="['option-card', { selected: mode === 'native' }]"><input v-model="mode" type="radio" value="native" name="mode" /><Server :size="22" aria-hidden="true" /><strong>Native</strong><span>无需 Docker，由 systemd 管理</span></label>
        </div>
      </fieldset>
      <fieldset><legend><span>02</span>服务器的网络环境</legend>
        <div class="network-options"><label :class="{ selected: network === 'cn' }"><input v-model="network" type="radio" name="network" value="cn" />中国大陆</label><label :class="{ selected: network === 'global' }"><input v-model="network" type="radio" name="network" value="global" />海外 / Global</label></div>
        <p class="hint">{{ network === 'cn' ? '下载使用加速代理；安装器应用国内网络档位。' : '直接从 GitHub 下载，使用海外网络档位。' }}</p>
      </fieldset>
      <fieldset><legend><span>03</span>本机防火墙 <small>可选</small></legend>
        <label class="checkbox-label"><input v-model="openPanelPort" type="checkbox" />自动开放面板本机防火墙端口</label>
        <label class="checkbox-label"><input v-model="openDstPorts" type="checkbox" />自动开放 DST 本机防火墙端口</label>
        <p class="hint">云服务安全组仍需在云平台手动配置。</p>
      </fieldset>
    </div>
    <div class="config-result">
      <div class="result-top"><span class="eyebrow">你的安装命令</span><NexusReleaseBadge /></div>
      <NexusCommandBlock :command="command" />
      <p class="hint">在目标 Linux 服务器上执行。安装器会先检查环境，再安装面板。</p>
      <details class="preflight-details"><summary>先检查环境，再决定是否安装</summary><NexusCommandBlock :command="checkCommand" label="下载脚本后仅运行 --check" /><p class="hint">体检不会修改系统；前面的 curl 会在当前目录保存安装脚本。</p></details>
      <div class="requirements"><span class="eyebrow">服务器要求 · {{ mode === 'docker' ? 'Docker' : 'Native' }}</span><p>{{ panel.requirements[mode] }}</p><a :href="`${panel.repositoryUrl}/blob/${panel.sourceRef}/docs/MEMORY.md`" target="_blank" rel="noopener noreferrer">查看内存档位与 Mod 建议 →</a></div>
      <p class="source-note">参数来自 {{ panel.version }} 安装器。<a :href="`${panel.repositoryUrl}/blob/${panel.sourceRef}/scripts/install.linux.sh`">查看源码 ↗</a></p>
    </div>
  </section>
</template>
