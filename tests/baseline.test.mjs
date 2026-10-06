import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'
import { buildInstallCommand } from '../shared/utils/install-command.ts'
import { createBaseline, sectionText, sourcePaths } from '../scripts/panel-baseline.mjs'

const release = JSON.parse(await readFile(new URL('../data/release.json', import.meta.url), 'utf8'))
const files = Object.fromEntries(await Promise.all(sourcePaths.map(async path => [path, await readFile(new URL(`../data/panel/${path}`, import.meta.url))])))
const metadata = { tag_name: release.version, published_at: release.releasedAt, draft: false, prerelease: false, assets: [release.nativeAsset, release.dockerAsset].map(url => ({ name: url.split('/').at(-1), browser_download_url: url })) }

test('all mode/network/firewall/check combinations are pinned and supported', () => {
  for (const mode of ['docker', 'native']) for (const network of ['cn', 'global']) for (const openPanelPort of [false, true]) for (const openDstPorts of [false, true]) for (const checkOnly of [false, true]) {
    const command = buildInstallCommand(release, { mode, network, openPanelPort, openDstPorts, checkOnly })
    assert.ok(command.includes(release.sourceRef))
    assert.ok(command.includes(`--mode ${mode} --network ${network}`))
    assert.ok(command.includes(`tag=${release.version}`))
    assert.ok(command.includes(' &&\n'), 'failed download must stop installation')
    assert.ok(command.includes(`${release.installerSha256}  install-\${tag}.sh`))
    assert.ok(command.indexOf('sha256sum -c - &&') < command.indexOf('sudo env'), 'checksum verification must precede execution')
    assert.equal(command.includes(`${release.githubProxy.replace(/\/$/, '')}/https://`), network === 'cn')
    assert.equal(command.includes('--open-panel-port'), openPanelPort && !checkOnly)
    assert.equal(command.includes('--open-dst-ports'), openDstPorts && !checkOnly)
    assert.equal(command.includes('--check'), checkOnly)
  }
})

test('changed upstream defaults fail instead of silently displaying stale facts', () => {
  assert.throws(() => createBaseline({ ...metadata, prerelease: true }, release.sourceRef, files))
  const changed = { ...files, 'scripts/install.linux.sh': Buffer.from(files['scripts/install.linux.sh'].toString().replace(`PANEL_IMAGE_TAG:-${release.version}`, 'PANEL_IMAGE_TAG:-v0.0.0')) }
  assert.throws(() => createBaseline(metadata, release.sourceRef, changed), /differs from Release/)
  assert.throws(() => sectionText('# Docs\n\n## New name', 'Missing'), /section missing/)
})

test('command input rejects shell metacharacters and unavailable flags', () => {
  const options = { mode: 'docker', network: 'cn', openPanelPort: false, openDstPorts: false }
  assert.throws(() => buildInstallCommand({ ...release, version: 'v1.0.0; id' }, options))
  assert.throws(() => buildInstallCommand({ ...release, githubProxy: 'https://example.com/$oops' }, options))
  assert.throws(() => buildInstallCommand({ ...release, installerFlags: [] }, options), /does not support/)
})

test('Markdown code comments do not truncate generated FAQ sections', () => {
  const text = '# Docs\n\n## Install\n\n```bash\n# A shell comment\necho done\n```\n\nFollow-up.\n\n## Next\nOther'
  assert.equal(sectionText(text, 'Install'), '```bash\n# A shell comment\necho done\n```\n\nFollow-up.')
})
