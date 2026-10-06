import { createHash } from 'node:crypto'
import { posix } from 'node:path'

export const repository = 'PMAT77/bubble-shark-panel'
export const sourcePaths = [
  'README.md', 'LICENSE', 'SECURITY.md', 'CHANGELOG.md', 'scripts/install.linux.sh',
  'docs/install-docker.md', 'docs/install-native.md', 'docs/reference.md',
  'docs/migrate-from-other-panel.md', 'docs/MEMORY.md',
  'src/assets/images/logo.png', 'public/favicon.png'
]
export const faqSeeds = [
  { slug: 'docker-or-native', title: 'Docker 与 Native 怎么选？', category: '开始之前', keywords: ['docker', 'native', 'systemd', '系统', '内存'], path: 'docs/install-native.md', section: null, also: 'docs/install-docker.md' },
  { slug: 'china-install', title: '中国大陆服务器怎么安装？', category: '安装', keywords: ['国内', '中国大陆', 'ghcr', 'waiting', 'TLS', '代理'], path: 'docs/install-docker.md', section: '安装（国内服务器）' },
  { slug: 'first-password', title: '初始账号和密码在哪里？', category: '登录', keywords: ['superadmin', '密码', '登录', 'ADMIN_PASSWORD'], path: 'docs/install-docker.md', section: '初始密码' },
  { slug: 'ports-and-nat', title: '房间搜不到、洞穴掉线，需要检查哪些端口？', category: '开服', keywords: ['10999', '11000', '9527', '端口', '安全组', 'NAT', '房间', '洞穴'], path: 'docs/install-docker.md', section: '必须开放的端口' },
  { slug: 'install-errors', title: '安装卡住或下载失败怎么办？', category: '安装', keywords: ['compose', 'TLS', 'waiting', 'GHCR', 'Mod', 'doctor'], errorCodes: ['TLS handshake timeout', 'checksum mismatch', 'Image pull failed'], path: 'docs/install-docker.md', section: '常见错误' },
  { slug: 'native-errors', title: 'Native 服务或实例启动失败怎么办？', category: '排错', keywords: ['systemd', 'native', 'bus', 'Mod', '重启'], errorCodes: ['Failed to connect to bus', 'cross-mode migration is not supported'], path: 'docs/install-native.md', section: '常见错误' },
  { slug: 'import-save', title: '已有的 DST 存档如何迁入？', category: '存档与迁移', keywords: ['迁移', '存档', '备份', 'mod', 'cluster.ini'], path: 'docs/migrate-from-other-panel.md', section: '从其他面板或裸机迁入' },
  { slug: 'docker-update', title: 'Docker 如何更新和回滚？', category: '更新', keywords: ['升级', '更新', '回滚', '数据库', '备份'], path: 'docs/install-docker.md', section: '升级', stopBefore: '需要卸载时' },
  { slug: 'mod-network', title: 'Mod 市场加载失败，代理在哪里配置？', category: 'Mod', keywords: ['mod', 'steam', '代理', '网络', '市场'], path: 'docs/reference.md', section: 'Steam 与 Mod 市场' }
]

export const sha256 = (value) => createHash('sha256').update(value).digest('hex')

function matchRequired(text, pattern, label) {
  const value = text.match(pattern)?.[1]
  if (!value) throw new Error(`Panel source format changed: ${label}`)
  return value
}

export function sectionText(markdown, heading) {
  const lines = markdown.split('\n')
  let fence = null
  const headings = []
  for (const [index, line] of lines.entries()) {
    const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/)?.[1]
    if (marker) {
      if (!fence) fence = marker
      else if (marker[0] === fence[0] && marker.length >= fence.length) fence = null
    } else if (!fence && /^#{1,2} /.test(line)) headings.push(index)
  }
  if (heading === null) return lines.slice(1, headings.find(index => index > 0)).join('\n').trim()
  const start = headings.find(index => lines[index] === `## ${heading}`) ?? -1
  if (start < 0) throw new Error(`Panel source section missing: ${heading}`)
  return lines.slice(start + 1, headings.find(index => index > start)).join('\n').trim()
}

export function rewriteDocLinks(markdown, path, sourceRef) {
  return markdown.replace(/(!?\[[^\]\n]*\])\(([^\s)]+)\)/g, (all, label, target) => {
    if (/^(https?:|mailto:)/.test(target)) return all
    if (target.startsWith('#')) return `${label}(https://github.com/${repository}/blob/${sourceRef}/${path}${target})`
    const fullPath = posix.normalize(posix.join(posix.dirname(path), target))
    return `${label}(https://github.com/${repository}/blob/${sourceRef}/${fullPath})`
  })
}

export function createBaseline(metadata, sourceRef, files) {
  if (metadata.draft || metadata.prerelease || !/^v\d+\.\d+\.\d+$/.test(metadata.tag_name)) throw new Error('Expected a published, non-prerelease semver tag')
  if (!/^[a-f0-9]{40}$/.test(sourceRef)) throw new Error('Expected an immutable commit SHA')
  for (const path of sourcePaths) if (!files[path]?.length) throw new Error(`Missing Panel source: ${path}`)
  const source = path => files[path].toString('utf8').replaceAll('\r\n', '\n')
  const installer = source('scripts/install.linux.sh')
  const readme = source('README.md')
  const version = metadata.tag_name
  const installerVersion = matchRequired(installer, /^BSP_RELEASE_TAG=.*?PANEL_IMAGE_TAG:-([^}]+)/m, 'installer version')
  if (version !== installerVersion) throw new Error(`Installer default ${installerVersion} differs from Release ${version}`)
  const defaultValue = key => matchRequired(installer, new RegExp('^' + key + '="\\$\\{' + key + ':-([^$}"]+)\\}"', 'm'), key)
  const help = matchRequired(installer, /^(  --mode MODE[\s\S]*?)^  BSP_INSTALL_MODE=/m, 'installer help')
  const installerFlags = [...new Set([...help.matchAll(/^ {2}(--[a-z-]+)[ \t]/gm)].map(match => match[1]))]
  for (const flag of ['--mode', '--network', '--check', '--open-panel-port', '--open-dst-ports']) {
    if (!installerFlags.includes(flag)) throw new Error(`Required installer option missing: ${flag}`)
  }
  const asset = name => {
    const url = metadata.assets?.find(item => item.name === name)?.browser_download_url
    if (!url?.startsWith(`https://github.com/${repository}/releases/download/${version}/`)) throw new Error(`Release asset missing or unexpected: ${name}`)
    return url
  }
  const environment = mode => matchRequired(source(`docs/install-${mode}.md`), /\*\*环境要求\*\*[：:]([^\n]+)/, `${mode} requirements`)
  const imageRepo = matchRequired(installer, /(ghcr\.io\/[a-z0-9/-]*bubblesharkpanel)/, 'Docker image')
  const release = {
    version,
    channel: readme.includes('Public Beta') ? 'Public Beta' : 'Release',
    releasedAt: metadata.published_at,
    repositoryUrl: `https://github.com/${repository}`,
    releaseUrl: `https://github.com/${repository}/releases/tag/${version}`,
    sourceRef,
    installer: `https://raw.githubusercontent.com/${repository}/${sourceRef}/scripts/install.linux.sh`,
    installerSha256: sha256(files['scripts/install.linux.sh']),
    dockerImage: `${imageRepo}:${version}`,
    nativeAsset: asset(`bubblesharkpanel-native-${version}-linux-x64.tar.gz`),
    dockerAsset: asset(`bubblesharkpanel-${version}-docker-image.tar.gz`),
    githubProxy: defaultValue('GITHUB_PROXY_SITES').split(',')[0],
    installerFlags,
    requirements: { docker: environment('docker'), native: environment('native') },
    adminUsername: defaultValue('ADMIN_USERNAME'),
    installDir: defaultValue('PANEL_INSTALL_DIR'),
    demoUrl: matchRequired(readme, /\[在线预览\]\((https?:\/\/[^)]+)\)/, 'demo URL'),
    qqGroup: matchRequired(readme, /QQ 群[：:]\s*(\d+)/, 'QQ group'),
    ports: [
      ['面板 Web', 'TCP', 'PANEL_PORT', '始终需要'],
      ['主世界 · 游戏', 'UDP', 'DST_GAME_PORT', '主世界'],
      ['主世界 · Steam 认证', 'UDP', 'DST_AUTH_PORT', '主世界'],
      ['主世界 · Steam 查询', 'UDP', 'DST_MASTER_PORT', '主世界'],
      ['洞穴 · 游戏', 'UDP', 'DST_CAVES_GAME_PORT', '开启洞穴时'],
      ['洞穴 · Steam 认证', 'UDP', 'DST_CAVES_AUTH_PORT', '开启洞穴时'],
      ['洞穴 · Steam 查询', 'UDP', 'DST_CAVES_MASTER_PORT', '开启洞穴时']
    ].map(([name, protocol, key, when]) => {
      const port = Number(defaultValue(key))
      if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error(`Invalid Panel port: ${key}`)
      return { name, protocol, port, when, sourceKey: key }
    }),
    sources: sourcePaths.map(path => ({ path, sha256: sha256(files[path]), url: `https://github.com/${repository}/blob/${sourceRef}/${path}` }))
  }
  const faq = Object.fromEntries(faqSeeds.map((seed, index) => {
    let body = sectionText(source(seed.path), seed.section)
    if (seed.stopBefore) body = body.split(seed.stopBefore)[0].trim()
    body = rewriteDocLinks(body, seed.path, sourceRef)
    // Upstream docs still use a fixed line number for this check; follow the variable instead.
    body = body.replaceAll("sed -n '9p'", "grep '^BSP_RELEASE_TAG='")
    if (seed.also) body = `### Docker\n\n${rewriteDocLinks(sectionText(source(seed.also), null), seed.also, sourceRef)}\n\n### Native\n\n${body}`
    const frontmatter = Object.entries({ slug: seed.slug, title: seed.title, category: seed.category, keywords: seed.keywords, errorCodes: seed.errorCodes ?? [], relatedDocs: [seed.path, ...(seed.also ? [seed.also] : [])], order: index + 1, sourceRef }).map(([key, value]) => `${key}: ${JSON.stringify(value)}`).join('\n')
    return [seed.slug, `---\n${frontmatter}\n---\n\n${body}\n`]
  }))
  return { release, faq }
}
