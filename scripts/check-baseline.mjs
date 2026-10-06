import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createBaseline, sourcePaths } from './panel-baseline.mjs'

const root = new URL('../', import.meta.url)
const release = JSON.parse(await readFile(new URL('data/release.json', root), 'utf8'))
const files = Object.fromEntries(await Promise.all(sourcePaths.map(async path => [path, await readFile(new URL(`data/panel/${path}`, root))])))
const assets = [release.nativeAsset, release.dockerAsset].map(url => ({ name: url.split('/').at(-1), browser_download_url: url }))
const expected = createBaseline({ tag_name: release.version, published_at: release.releasedAt, draft: false, prerelease: false, assets }, release.sourceRef, files)
assert.deepEqual(release, expected.release, 'release.json drifted from the checked-in Panel sources; run sync:panel')
for (const [slug, markdown] of Object.entries(expected.faq)) assert.equal(await readFile(new URL(`content/faq/${slug}.md`, root), 'utf8'), markdown, `Generated FAQ drifted: ${slug}`)
console.log(`Panel ${release.version}: source hashes, installer facts and FAQ provenance verified.`)
