import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { sourcePaths, faqSeeds } from '../scripts/panel-baseline.mjs'
import { compareVersions, parseOptions, syncPanel } from '../scripts/sync-bubbleshark-release.mjs'

const baseline = JSON.parse(await readFile(new URL('../data/release.json', import.meta.url), 'utf8'))
const files = Object.fromEntries(await Promise.all(sourcePaths.map(async path => [path, await readFile(new URL(`../data/panel/${path}`, import.meta.url))])))
const brandLogo = await readFile(new URL('../branding/logo.png', import.meta.url))
const generatedPaths = ['data/release.json', ...sourcePaths.map(path => `data/panel/${path}`), ...faqSeeds.map(seed => `content/faq/${seed.slug}.md`), 'public/logo/shark.png', 'public/favicon.png']

async function fixture(t, metadataOverrides = {}, sha = baseline.sourceRef) {
  const root = await mkdtemp(join(tmpdir(), 'nexus-sync-'))
  t.after(() => rm(root, { recursive: true, force: true }))
  await mkdir(join(root, 'data'))
  await mkdir(join(root, 'branding'))
  await writeFile(join(root, 'branding/logo.png'), brandLogo)
  await writeFile(join(root, 'data/release.json'), JSON.stringify(baseline))
  const calls = []
  const dependencies = {
    async api(path) {
      calls.push(path)
      if (path.startsWith('releases/')) return {
        tag_name: baseline.version, published_at: baseline.releasedAt, draft: false, prerelease: false,
        assets: [baseline.nativeAsset, baseline.dockerAsset].map(url => ({ name: url.split('/').at(-1), browser_download_url: url })),
        ...metadataOverrides
      }
      if (path.startsWith('git/ref/tags/')) return { object: { type: 'tag', sha: 'a'.repeat(40) } }
      if (path === `git/tags/${'a'.repeat(40)}`) return { object: { type: 'commit', sha } }
      throw new Error(`Unexpected API request: ${path}`)
    },
    async readSource(path, sourceRef) {
      calls.push(`source:${path}`)
      assert.equal(sourceRef, sha)
      return files[path]
    }
  }
  return { root, calls, dependencies }
}

test('CLI accepts explicit/local sources and rejects invalid tags and SHA arguments', () => {
  assert.deepEqual(parseOptions(['--tag', baseline.version, '--expected-sha', baseline.sourceRef, '--local', '../bubble-shark-panel']), {
    tag: baseline.version, expectedSha: baseline.sourceRef, local: '../bubble-shark-panel'
  })
  for (const tag of ['v1.2.3-beta', 'v01.2.3', 'v1.2.3; id', '', '../main']) assert.throws(() => parseOptions(['--tag', tag]))
  assert.throws(() => parseOptions(['--expected-sha', baseline.sourceRef]))
  assert.throws(() => parseOptions(['--tag', baseline.version, '--expected-sha', 'abc']))
  assert.throws(() => parseOptions(['--unknown', 'value']))
  assert.equal(compareVersions('v0.10.0', 'v0.9.99'), 1)
  assert.equal(compareVersions('v1.0.0', 'v0.99.99'), 1)
  assert.equal(compareVersions('v1.0.0', 'v1.0.1'), -1)
  assert.equal(compareVersions('v1.0.0', 'v1.0.0'), 0)
})

test('explicit tag resolves annotated tags, writes the baseline and repeats without content changes', async t => {
  const { root, calls, dependencies } = await fixture(t)
  const options = { root, tag: baseline.version, expectedSha: baseline.sourceRef }
  await syncPanel(options, dependencies)
  assert.equal(calls[0], `releases/tags/${baseline.version}`)
  const first = await Promise.all(generatedPaths.map(path => readFile(join(root, path))))
  assert.deepEqual(await readFile(join(root, 'public/logo/shark.png')), brandLogo)
  assert.deepEqual(await readFile(join(root, 'public/favicon.png')), brandLogo)
  await syncPanel(options, dependencies)
  const second = await Promise.all(generatedPaths.map(path => readFile(join(root, path))))
  assert.deepEqual(second, first)
  assert.deepEqual(JSON.parse(first[0]), baseline)
})

test('no tag uses the latest formal Release', async t => {
  const { root, calls, dependencies } = await fixture(t)
  await syncPanel({ root }, dependencies)
  assert.equal(calls[0], 'releases/latest')
})

test('a newer formal Release advances version, source SHA and installer checksum together', async t => {
  const parts = baseline.version.slice(1).split('.').map(Number)
  parts[2]++
  const tag = `v${parts.join('.')}`
  const sha = 'b'.repeat(40)
  const assets = [baseline.nativeAsset, baseline.dockerAsset].map(url => {
    const browser_download_url = url.replaceAll(baseline.version, tag)
    return { name: browser_download_url.split('/').at(-1), browser_download_url }
  })
  const { root, dependencies } = await fixture(t, { tag_name: tag, assets }, sha)
  dependencies.readSource = async path => path === 'scripts/install.linux.sh'
    ? Buffer.from(files[path].toString().replace(`PANEL_IMAGE_TAG:-${baseline.version}`, `PANEL_IMAGE_TAG:-${tag}`))
    : files[path]
  await syncPanel({ root, tag, expectedSha: sha }, dependencies)
  const release = JSON.parse(await readFile(join(root, 'data/release.json'), 'utf8'))
  assert.equal(release.version, tag)
  assert.equal(release.sourceRef, sha)
  assert.ok(release.installer.includes(sha))
  assert.notEqual(release.installerSha256, baseline.installerSha256)
  assert.ok(release.nativeAsset.includes(tag))
  assert.ok(release.dockerAsset.includes(tag))
})

test('SHA mismatch and moved existing tags fail before writing sources', async t => {
  const { root, calls, dependencies } = await fixture(t)
  const original = await readFile(join(root, 'data/release.json'))
  await assert.rejects(syncPanel({ root, tag: baseline.version, expectedSha: 'b'.repeat(40) }, dependencies), /expected SHA/)
  const moved = await fixture(t, {}, 'b'.repeat(40))
  await assert.rejects(syncPanel({ root: moved.root, tag: baseline.version }, moved.dependencies), /different commit/)
  assert.ok(!calls.some(path => path.startsWith('source:')))
  assert.deepEqual(await readFile(join(root, 'data/release.json')), original)
})

test('older notifications are skipped without fetching sources or changing the baseline', async t => {
  const { root, calls, dependencies } = await fixture(t, { tag_name: 'v0.0.0' })
  const original = await readFile(join(root, 'data/release.json'))
  assert.deepEqual(await syncPanel({ root, tag: 'v0.0.0', expectedSha: baseline.sourceRef }, dependencies), { skipped: true, version: baseline.version })
  assert.ok(!calls.some(path => path.startsWith('source:')))
  assert.deepEqual(await readFile(join(root, 'data/release.json')), original)
})

test('draft, prerelease, mismatched tag and invalid metadata fail before writing', async t => {
  for (const overrides of [{ draft: true }, { prerelease: true }, { tag_name: 'v1.0.0-beta' }, { tag_name: 'v99.0.0' }]) {
    const { root, calls, dependencies } = await fixture(t, overrides)
    await assert.rejects(syncPanel({ root, tag: baseline.version }, dependencies), /supported published tag/)
    assert.ok(!calls.some(path => path.startsWith('source:')))
  }
})

test('upstream installer drift leaves the existing baseline untouched', async t => {
  const { root, dependencies } = await fixture(t)
  const original = await readFile(join(root, 'data/release.json'))
  dependencies.readSource = async path => path === 'scripts/install.linux.sh'
    ? Buffer.from(files[path].toString().replace(`PANEL_IMAGE_TAG:-${baseline.version}`, 'PANEL_IMAGE_TAG:-v0.0.0'))
    : files[path]
  await assert.rejects(syncPanel({ root }, dependencies), /differs from Release/)
  assert.deepEqual(await readFile(join(root, 'data/release.json')), original)
})
