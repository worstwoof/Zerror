import path from 'node:path'
import type { StudioSession } from '../../domain/types'
import { logPlotStudioSkillTrace } from '../../observability/plot-studio-skill-trace'
import type { StudioSkillDiscoveryEntry, StudioSkillSource } from '../schema/skill-types'
import { createFileSystemSkillSource } from './file-system-skill-source'

export interface StudioSkillRegistry {
  list(session: StudioSession): Promise<StudioSkillDiscoveryEntry[]>
  findByName(name: string, session: StudioSession): Promise<StudioSkillDiscoveryEntry | null>
}

export function createStudioSkillRegistry(
  sources: StudioSkillSource[] = createDefaultSkillSources()
): StudioSkillRegistry {
  return {
    async list(session: StudioSession): Promise<StudioSkillDiscoveryEntry[]> {
      const sourceEntries = await Promise.all(sources.map((source) => source.list(session)))
      const merged = mergeEntries(sourceEntries.flat())
      const filtered = merged.filter((entry) => matchesStudioScope(entry.scope, session.studioKind))
      logPlotStudioSkillTrace(session.studioKind, 'skill.registry.list', {
        sessionId: session.id,
        sourceCount: sources.length,
        mergedSkillCount: merged.length,
        filteredSkillCount: filtered.length,
        filteredSkillNames: filtered.map((entry) => entry.name),
      })
      return filtered
    },
    async findByName(name: string, session: StudioSession): Promise<StudioSkillDiscoveryEntry | null> {
      const entries = await this.list(session)
      const match = entries.find((entry) => entry.name.toLowerCase() === name.toLowerCase()) ?? null
      logPlotStudioSkillTrace(session.studioKind, 'skill.registry.match', {
        sessionId: session.id,
        requestedSkillName: name,
        matchedSkillName: match?.name ?? null,
        matchedEntryFile: match?.entryFile ?? null,
      }, match ? 'info' : 'warn')
      return match
    }
  }
}

export function createDefaultSkillSources(): StudioSkillSource[] {
  const catalogRoot = path.join(process.cwd(), 'src', 'studio-agent', 'skills', 'catalog')

  return [
    createFileSystemSkillSource({
      rootDirectory: path.join(catalogRoot, 'common'),
      source: 'catalog'
    }),
    createFileSystemSkillSource({
      rootDirectory: (session) => path.join(catalogRoot, session.studioKind ?? 'manim'),
      source: 'catalog'
    }),
    createFileSystemSkillSource({
      rootDirectory: (session) => path.join(session.directory, '.manimcat', 'skills'),
      source: 'workspace'
    })
  ]
}

function mergeEntries(entries: StudioSkillDiscoveryEntry[]): StudioSkillDiscoveryEntry[] {
  const merged = new Map<string, StudioSkillDiscoveryEntry>()
  for (const entry of entries) {
    merged.set(entry.name.toLowerCase(), entry)
  }
  return [...merged.values()].sort((left, right) => left.name.localeCompare(right.name))
}

function matchesStudioScope(
  scope: StudioSkillDiscoveryEntry['scope'],
  studioKind: StudioSession['studioKind']
): boolean {
  if (!scope || scope === 'common') {
    return true
  }

  return scope === (studioKind ?? 'manim')
}
