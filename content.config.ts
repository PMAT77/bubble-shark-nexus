import { defineCollection, defineContentConfig, z } from '@nuxt/content'

export default defineContentConfig({
  collections: {
    faq: defineCollection({
      type: 'page',
      source: 'faq/*.md',
      schema: z.object({
        slug: z.string().regex(/^[a-z0-9-]+$/),
        category: z.string(),
        keywords: z.array(z.string()),
        errorCodes: z.array(z.string()).default([]),
        relatedDocs: z.array(z.string()),
        order: z.number()
      })
    }),
    install: defineCollection({ type: 'page', source: 'install/*.md' })
  }
})
