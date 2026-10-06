import { execFileSync } from 'node:child_process'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { parseArgs } from 'node:util'
import { resolve, dirname, join } from 'node:path'
import { createBaseline, repository, sourcePaths } from './panel-baseline.mjs'

const versionPattern = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/
const shaPattern = /^[a-f0-9]{40}$/

export function parseOptions(args) {
  const { values } = parseArgs({ args, options: { tag: { type: 'string' }, 'expected-sha': { type: 'string' }, local: { type: 'string' } } })
  const options = { tag: values.tag, expectedSha: values['expected-sha'], local: values.local }
  if (options.tag !== undefined && !versionPattern.test(options.tag)) throw new Error('Expected a formal vX.Y.Z tag')
  if (options.expectedSha !== undefined && (!options.tag || !shaPattern.test(options.expectedSha))) throw new Error('--expected-sha requires --tag and a full commit SHA')
  if (options.local !== undefined && !options.local) throw new Error('--local requires a repository path')
  return options
}

export function compareVersions(left, right) {
  const parts = value => {
    if (!versionPattern.test(value)) throw new Error(`Unsupported version: ${value}`)
    return value.slice(1).split('.').map(BigInt)
  }
  const a = parts(left), b = parts(right)
  for (let index = 0; index < 3; index++) if (a[index] !== b[index]) return a[index] > b[index] ? 1 : -1
  return 0
}

async function githubApi(path) {
  const response = await fetch(`https://api.github.com/repos/${repository}/${path}`, {
    headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'BubbleShark-Nexus', ...(process.env.GITHUB_TOKEN ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` } : {}) },
    signal: AbortSignal.timeout(30000)
  })
  if (!response.ok) throw new Error(`GitHub API ${response.status}: ${path}`)
  return response.json()
}

async function fetchSource(path, sha) {
  const response = await fetch(`https://raw.githubusercontent.com/${repository}/${sha}/${path}`, { signal: AbortSignal.timeout(30000) })
  if (!response.ok) throw new Error(`Panel source ${response.status}: ${path}`)
  return Buffer.from(await response.arrayBuffer())
}

export async function syncPanel(options, { api = githubApi, readSource = fetchSource } = {}) {
  const { tag, expectedSha } = parseOptions([
    ...(options.tag === undefined ? [] : ['--tag', options.tag]),
    ...(options.expectedSha === undefined ? [] : ['--expected-sha', options.expectedSha])
  ])
  const root = options.root ?? fileURLToPath(new URL('../', import.meta.url))
  const local = options.local ? resolve(options.local) : null
  // Resolve Release metadata first, then its tag object to a commit. Never read main.
  const metadata = await api(tag ? `releases/tags/${tag}` : 'releases/latest')
  if (!versionPattern.test(metadata.tag_name) || metadata.draft || metadata.prerelease || (tag && metadata.tag_name !== tag)) throw new Error('Release is not a supported published tag')
  let ref = (await api(`git/ref/tags/${metadata.tag_name}`)).object
  for (let depth = 0; ref.type === 'tag' && depth < 5; depth++) ref = (await api(`git/tags/${ref.sha}`)).object
  if (ref.type !== 'commit' || !shaPattern.test(ref.sha)) throw new Error('Release tag did not resolve to a commit')
  if (expectedSha && ref.sha !== expectedSha) throw new Error('Release commit differs from expected SHA')
  let current
  try {
    current = JSON.parse(await readFile(join(root, 'data/release.json'), 'utf8'))
  } catch (error) {
    if (error.code !== 'ENOENT') throw error
  }
  if (current) {
    const comparison = compareVersions(metadata.tag_name, current.version)
    if (comparison < 0) {
      console.log(`Skipped older Panel ${metadata.tag_name}; current baseline is ${current.version}.`)
      return { skipped: true, version: current.version }
    }
    if (comparison === 0 && current.sourceRef !== ref.sha) throw new Error('Existing Release tag points to a different commit')
  }
  if (local) {
    const localCommit = execFileSync('git', ['-C', local, 'rev-parse', `${metadata.tag_name}^{commit}`], { encoding: 'utf8' }).trim()
    if (localCommit !== ref.sha) throw new Error('Local tag differs from the published Panel Release')
  }
  const files = Object.fromEntries(await Promise.all(sourcePaths.map(async path => {
    if (local) return [path, execFileSync('git', ['-C', local, 'show', `${ref.sha}:${path}`], { maxBuffer: 8 * 1024 * 1024 })]
    return [path, await readSource(path, ref.sha)]
  })))
  const brandLogo = await readFile(join(root, 'branding/logo.png'))
  files['src/assets/images/logo.png'] = brandLogo
  files['public/favicon.png'] = brandLogo
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
  return { skipped: false, version: release.version }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) await syncPanel(parseOptions(process.argv.slice(2)))
