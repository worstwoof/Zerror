import fs from 'node:fs'
import path from 'node:path'

export const DEFAULT_STUDIO_WORKSPACE_DIRNAME = '.studio-workspace'

export function getDefaultStudioWorkspacePath(): string {
  return path.join(process.cwd(), DEFAULT_STUDIO_WORKSPACE_DIRNAME)
}

export function ensureDefaultStudioWorkspaceExists(): string {
  const directory = getDefaultStudioWorkspacePath()
  fs.mkdirSync(directory, { recursive: true })
  return directory
}
