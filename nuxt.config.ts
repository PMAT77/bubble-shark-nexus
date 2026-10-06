import tailwindcss from '@tailwindcss/vite'

const baseURL = process.env.NUXT_APP_BASE_URL || '/'
const faviconURL = `${baseURL.endsWith('/') ? baseURL : `${baseURL}/`}favicon.png`

export default defineNuxtConfig({
  compatibilityDate: '2026-10-05',
  devtools: { enabled: false },
  modules: ['@nuxt/content'],
  css: ['~/assets/css/main.css'],
  vite: { plugins: [tailwindcss()] },
  content: { experimental: { sqliteConnector: 'native' } },
  runtimeConfig: { public: { siteUrl: '' } },
  app: {
    head: {
      htmlAttrs: { lang: 'zh-CN' },
      meta: [{ name: 'theme-color', content: '#f7f6f8' }],
      link: [{ rel: 'icon', type: 'image/png', href: faviconURL }]
    }
  },
  nitro: { prerender: { routes: ['/', '/install', '/faq', '/robots.txt', '/sitemap.xml'], failOnError: true } },
  typescript: { strict: true }
})
