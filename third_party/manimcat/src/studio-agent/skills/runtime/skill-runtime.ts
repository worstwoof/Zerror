import type { StudioSession } from '../../domain/types'
import { logPlotStudioSkillTrace } from '../../observability/plot-studio-skill-trace'
import { createStudioSkillRegistry, type StudioSkillRegistry } from '../registry/skill-registry'
import { createStudioSkillLoader } from '../resolver/skill-loader'
import type {
  StudioResolvedSkill,
  StudioSkillDiscoveryEntry,
  StudioSkillUsageSummary
} from '../schema/skill-types'
import {
  createInMemoryStudioSkillStateStore,
  type StudioSkillStateStore
} from '../state/skill-state-store'

export interface StudioSkillRuntime {
  listDiscovery(session: StudioSession): Promise<StudioSkillDiscoveryEntry[]>
  resolve(name: string, session: StudioSession): Promise<StudioResolvedSkill>
  listSummaries(session: StudioSession): Promise<StudioSkillUsageSummary[]>
  recordUsage(input: {
    session: StudioSession
    skillName: string
    reason?: string
    takeaway?: string
    stillRelevant?: boolean
  }): Promise<void>
}

export function createStudioSkillRuntime(input?: {
  registry?: StudioSkillRegistry
  stateStore?: StudioSkillStateStore
  maxFiles?: number
}): StudioSkillRuntime {
  const registry = input?.registry ?? createStudioSkillRegistry()
  const loader = createStudioSkillLoader({
    registry,
    maxFiles: input?.maxFiles
  })
  const stateStore = input?.stateStore ?? createInMemoryStudioSkillStateStore()

  return {
    async listDiscovery(session) {
      logPlotStudioSkillTrace(session.studioKind, 'skill.discovery.requested', {
        sessionId: session.id,
        sessionDirectory: session.directory,
      })
      const entries = await registry.list(session)
      logPlotStudioSkillTrace(session.studioKind, 'skill.discovery.completed', {
        sessionId: session.id,
        discoveredSkillCount: entries.length,
        discoveredSkillNames: entries.map((entry) => entry.name),
      })
      return entries
    },
    async resolve(name, session) {
      logPlotStudioSkillTrace(session.studioKind, 'skill.resolve.requested', {
        sessionId: session.id,
        skillName: name,
      })
      const skill = await loader.resolve(name, session)
      logPlotStudioSkillTrace(session.studioKind, 'skill.resolve.completed', {
        sessionId: session.id,
        skillName: skill.name,
        source: skill.source,
        scope: skill.scope,
        entryFile: skill.entryFile,
        fileCount: skill.files.length,
      })
      return skill
    },
    async listSummaries(session) {
      logPlotStudioSkillTrace(session.studioKind, 'skill.summary.requested', {
        sessionId: session.id,
      })
      const summaries = await stateStore.list(session)
      logPlotStudioSkillTrace(session.studioKind, 'skill.summary.completed', {
        sessionId: session.id,
        summaryCount: summaries.length,
        summarySkillNames: summaries.map((summary) => summary.skillName),
      })
      return summaries
    },
    async recordUsage(value) {
      await stateStore.record(value)
      logPlotStudioSkillTrace(value.session.studioKind, 'skill.usage.recorded', {
        sessionId: value.session.id,
        skillName: value.skillName,
        reason: value.reason,
        takeaway: value.takeaway,
        stillRelevant: value.stillRelevant,
      })
    }
  }
}
