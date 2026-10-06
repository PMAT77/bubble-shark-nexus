export interface InstallOptions {
  mode: 'docker' | 'native'
  network: 'cn' | 'global'
  openPanelPort: boolean
  openDstPorts: boolean
  checkOnly?: boolean
}

interface InstallRelease {
  version: string
  installer: string
  installerSha256: string
  githubProxy: string
  installerFlags: string[]
}

export function buildInstallCommand(release: InstallRelease, options: InstallOptions): string {
  if (!/^v\d+\.\d+\.\d+$/.test(release.version)) throw new Error('Unsupported release tag')
  if (!/^[a-f0-9]{64}$/.test(release.installerSha256)) throw new Error('Invalid installer checksum')
  if (!['docker', 'native'].includes(options.mode) || !['cn', 'global'].includes(options.network)) throw new Error('Unsupported installation option')
  const installer = new URL(release.installer)
  const proxy = new URL(release.githubProxy)
  if (installer.protocol !== 'https:' || installer.hostname !== 'raw.githubusercontent.com' || proxy.protocol !== 'https:') throw new Error('Invalid installer source')
  const flags = ['--mode', options.mode, '--network', options.network]
  if (options.checkOnly) flags.push('--check')
  else {
    if (options.openPanelPort) flags.push('--open-panel-port')
    if (options.openDstPorts) flags.push('--open-dst-ports')
  }
  for (const flag of flags.filter(value => value.startsWith('--'))) {
    if (!release.installerFlags.includes(flag)) throw new Error(`Release installer does not support ${flag}`)
  }
  const url = options.network === 'cn' ? `${proxy.href.replace(/\/$/, '')}/${installer.href}` : installer.href
  if (/["'$`\s\\]/.test(url)) throw new Error('Unsafe download URL')
  return [
    `tag=${release.version}`,
    `curl -fL --retry 3 -o "install-\${tag}.sh" "${url}" &&`,
    `printf '%s\\n' "${release.installerSha256}  install-\${tag}.sh" | sha256sum -c - &&`,
    `sudo env BSP_RELEASE_TAG="\${tag}" bash "install-\${tag}.sh" ${flags.join(' ')}`
  ].join('\n')
}
