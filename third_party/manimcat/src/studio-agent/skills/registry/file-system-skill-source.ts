import { access, readFile, readdir } from 'node:fs/promises'
import path from 'node:path'
import type { StudioSession } from '../../domain/types'
import { logPlotStudioSkillTrace } from '../../observability/plot-studio-skill-trace'
import { buildDiscoveryEntry } from '../schema/parse-skill-manifest'
import type { StudioSkillDiscoveryEntry, StudioSkillSource } from '../schema/skill-types'

export function createFileSystemSkillSource(input: {
  rootDirectory: string | ((session: StudioSession) => string)
  source: 'catalog' | 'workspace'
}): StudioSkillSource {
  return {
    async list(session: StudioSession): Promise<StudioSkillDiscoveryEntry[]> {
      const rootDirectory = typeof input.rootDirectory === 'function'
        ? input.rootDirectory(session)
        : input.rootDirectory
      const directories = await collectSkillDirectories(rootDirectory)
      const entries = await Promise.all(
        directories.map(async (directory) => {
          const entryFile = path.join(directory, 'SKILL.md')
          const content = await readFile(entryFile, 'utf8')
          return buildDiscoveryEntry({
            directory,
            entryFile,
            content,
            source: input.source
          })
        })
      )

      logPlotStudioSkillTrace(session.studioKind, 'skill.source.scan', {
        sessionId: session.id,
        source: input.source,
        rootDirectory,
        discoveredDirectoryCount: directories.length,
        discoveredSkillNames: entries.map((entry) => entry.name),
      })

      return entries.sort((left, right) => left.name.localeCompare(right.name))
    }
  }
}

async function collectSkillDirectories(root: string): Promise<string[]> {
  try {
    const entries = await readdir(root, { withFileTypes: true })
    const directories = await Promise.all(
      entries
        .filter((entry) => entry.isDirectory())
        .map(async (entry) => {
          const fullPath = path.join(root, entry.name)
          const skillPath = path.join(fullPath, 'SKILL.md')
          const children = await collectSkillDirectories(fullPath)
          try {
            await access(skillPath)
            return [fullPath, ...children]
          } catch {
            return children
          }
        })
    )

    return directories.flat()
  } catch {
    return []
  }
}
