import { execFileSync } from 'node:child_process'
import { mkdir, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { resolve, dirname, join } from 'node:path'
import { createBaseline, repository, sourcePaths } from './panel-baseline.mjs'

const root = fileURLToPath(new URL('../', import.meta.url))
const args = process.argv.slice(2)
if (args.length && !(args.length === 2 && args[0] === '--local')) throw new Error('Usage: pnpm sync:panel [--local ../game-serve-hub]')
const local = args[0] === '--local' ? resolve(args[1]) : null
async function api(path) {
  const response = await fetch(`https://api.github.com/repos/${repository}/${path}`, {
    headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'BubbleShark-Nexus', ...(process.env.GITHUB_TOKEN ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` } : {}) },
    signal: AbortSignal.timeout(30000)
  })
  if (!response.ok) throw new Error(`GitHub API ${response.status}: ${path}`)
  return response.json()
}

// Resolve Release metadata first, then its tag object to a commit. Never read main.
const metadata = await api('releases/latest')
if (!/^v\d+\.\d+\.\d+$/.test(metadata.tag_name) || metadata.draft || metadata.prerelease) throw new Error('Latest Release is not a supported published tag')
let ref = (await api(`git/ref/tags/${metadata.tag_name}`)).object
for (let depth = 0; ref.type === 'tag' && depth < 5; depth++) ref = (await api(`git/tags/${ref.sha}`)).object
if (ref.type !== 'commit' || !/^[a-f0-9]{40}$/.test(ref.sha)) throw new Error('Release tag did not resolve to a commit')
if (local) {
  const localCommit = execFileSync('git', ['-C', local, 'rev-parse', `${metadata.tag_name}^{commit}`], { encoding: 'utf8' }).trim()
  if (localCommit !== ref.sha) throw new Error('Local tag differs from the published Panel Release')
}
const files = Object.fromEntries(await Promise.all(sourcePaths.map(async path => {
  if (local) return [path, execFileSync('git', ['-C', local, 'show', `${ref.sha}:${path}`], { maxBuffer: 8 * 1024 * 1024 })]
  const response = await fetch(`https://raw.githubusercontent.com/${repository}/${ref.sha}/${path}`, { signal: AbortSignal.timeout(30000) })
  if (!response.ok) throw new Error(`Panel source ${response.status}: ${path}`)
  return [path, Buffer.from(await response.arrayBuffer())]
})))
const { release, faq } = createBaseline(metadata, ref.sha, files)
async function save(path, contents) {
  const target = join(root, path)
  await mkdir(dirname(target), { recursive: true })
  await writeFile(target, contents)
}
// No writes until all upstream files and all extracted facts have been validated.
for (const [path, bytes] of Object.entries(files)) await save(`data/panel/${path}`, bytes)
for (const [slug, markdown] of Object.entries(faq)) await save(`content/faq/${slug}.md`, markdown)
await save('public/logo/shark.png', files['src/assets/images/logo.png'])
await save('public/favicon.png', files['public/favicon.png'])
await save('data/release.json', `${JSON.stringify(release, null, 2)}\n`)
console.log(`Synced ${release.version} @ ${ref.sha.slice(0, 12)}; ${sourcePaths.length} source files, ${Object.keys(faq).length} FAQ seeds.`)
