export function usePageSeo(title: string, description: string) {
  const config = useRuntimeConfig()
  const route = useRoute()
  const origin = config.public.siteUrl.replace(/\/$/, '')
  useSeoMeta({ title, description, ogTitle: title, ogDescription: description, ogType: 'website', ogLocale: 'zh_CN', twitterCard: 'summary' })
  if (origin) {
    useHead({ link: [{ rel: 'canonical', href: `${origin}${route.path}` }] })
    useSeoMeta({ ogUrl: `${origin}${route.path}`, ogImage: `${origin}/logo/shark.png` })
  }
}
