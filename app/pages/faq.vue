<script setup lang="ts">
import { ArrowUpRight, Search } from '@lucide/vue'
const panel = usePanel()
const route = useRoute()
const activeHash = ref('')
onMounted(() => { activeHash.value = route.hash })
watch(() => route.hash, (hash) => { activeHash.value = hash })
const query = ref('')
const category = ref('全部')
usePageSeo('BubbleSharkPanel 常见问题与故障排查', '按问题、错误提示和关键词查找 BubbleSharkPanel 安装、登录、开服、Mod、存档迁移与更新的解决方法。')
const { data: items, error } = await useAsyncData('faq', () => queryCollection('faq').order('order', 'ASC').all())
const categories = computed(() => ['全部', ...new Set(items.value?.map(item => item.category) ?? [])])
function bodyText(value: unknown): string {
  if (typeof value === 'string') return value
  if (Array.isArray(value)) return value.map(bodyText).join(' ')
  if (value && typeof value === 'object') return Object.values(value).map(bodyText).join(' ')
  return ''
}
const filtered = computed(() => {
  const terms = query.value.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean)
  return (items.value ?? []).filter(item => {
    const text = `${item.title} ${item.keywords.join(' ')} ${(item.errorCodes ?? []).join(' ')} ${bodyText(item.body)}`.toLocaleLowerCase()
    return (category.value === '全部' || category.value === item.category) && terms.every(term => text.includes(term))
  })
})
function linked(slug: string) { return activeHash.value === `#${slug}` }
</script>

<template>
  <div class="container">
    <header class="page-heading"><p class="eyebrow">问题有答案 / FIELD NOTES</p><h1>让问题停在这里。</h1><p>搜索问题、错误提示或关键词，找到下一步该做什么。</p></header>
    <div class="faq-layout"><aside class="faq-sidebar"><p class="eyebrow">按主题查找</p><div class="category-list" aria-label="FAQ 分类"><button v-for="item in categories" :key="item" type="button" :aria-pressed="category === item" :class="{ active: category === item }" @click="category = item">{{ item }}</button></div><p class="source-note">内容依据 Panel {{ panel.version }}。<br />每条答案附有原文出处。</p></aside>
      <section class="faq-main" aria-label="常见问题"><label class="search-field"><Search :size="21" aria-hidden="true" /><span class="sr-only">搜索常见问题</span><input v-model="query" type="search" placeholder="试试 Waiting、密码、洞穴、Mod…" /></label><p class="result-count" role="status">{{ filtered.length }} 个相关问题</p>
        <p v-if="error" role="alert">FAQ 加载失败，请刷新重试或打开 GitHub 部署文档。</p>
        <div v-else-if="!filtered.length" class="empty-state"><h2>暂时没有找到相关答案。</h2><p>换一个关键词，或查看全部问题。</p><button type="button" class="button button-secondary" @click="query = ''; category = '全部'">查看全部问题</button></div>
        <details v-for="item in filtered" :id="item.slug" :key="item.id" class="faq-item" :open="linked(item.slug)"><summary><span class="faq-category">{{ item.category }}</span><span>{{ item.title }}</span><span class="faq-toggle" aria-hidden="true">+</span></summary><div class="faq-answer"><ContentRenderer :value="item" class="prose" /><div class="faq-sources"><a :href="`#${item.slug}`" aria-label="链接到这个问题"># 问题链接</a><a v-for="doc in item.relatedDocs" :key="doc" :href="`${panel.repositoryUrl}/blob/${panel.sourceRef}/${doc}`" target="_blank" rel="noopener noreferrer">查看原文<ArrowUpRight :size="14" aria-hidden="true" /></a></div></div></details>
      </section>
    </div>
    <NexusSupportChannels />
  </div>
</template>
