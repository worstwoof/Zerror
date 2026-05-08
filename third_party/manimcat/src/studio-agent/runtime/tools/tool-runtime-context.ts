import type {
  StudioSession,
  StudioPartStore,
  StudioMessageStore,
  StudioSessionStore,
  StudioToolContext
} from '../../domain/types'
import type { ActiveSkillStore } from '../../skills/state/skill-state-store'
import type {
  StudioResolvedSkill,
  StudioSkillDiscoveryEntry,
  StudioSkillUsageSummary
} from '../../skills/schema/skill-types'

export type {
  StudioResolvedSkill,
  StudioSkillDiscoveryEntry,
  StudioSkillUsageSummary
} from '../../skills/schema/skill-types'

export interface StudioRunExecutionResult {
  text: string
}

export interface StudioRuntimeBackedToolContext extends StudioToolContext {
  partStore?: StudioPartStore
  messageStore?: StudioMessageStore
  sessionStore?: StudioSessionStore
  activeSkillStore?: ActiveSkillStore
  resolveSkill?: (name: string, session: StudioSession) => Promise<StudioResolvedSkill>
  listSkills?: (session: StudioSession) => Promise<StudioSkillDiscoveryEntry[]>
  listSkillSummaries?: (session: StudioSession) => Promise<StudioSkillUsageSummary[]>
  recordSkillUsage?: (input: {
    session: StudioSession
    skillName: string
    reason?: string
    takeaway?: string
    stillRelevant?: boolean
  }) => Promise<void>
}
