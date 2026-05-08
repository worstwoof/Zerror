import { executeStudioHistoryCommand } from './handlers/history'
import { executeStudioNewSessionCommand } from './handlers/new-session'
import type { StudioCommandDefinition, StudioHistoryCommand, StudioNewSessionCommand } from './types'

function parseExactBasicCommand(input: string): '/history' | '/new' | null {
  const normalized = input.trim().toLowerCase()
  if (normalized === '/history' || normalized === '/new') {
    return normalized
  }
  return null
}

export const basicStudioCommands: StudioCommandDefinition[] = [
  {
    id: 'history',
    group: 'basic',
    scope: 'global',
    presentation: {
      trigger: '/history',
      titleKey: 'studio.command.historyTitle',
      descriptionKey: 'studio.command.historyDescription',
      aliases: ['/h'],
      keywords: ['session', 'recent', 'restore'],
    },
    matches(input): StudioHistoryCommand | null {
      const command = parseExactBasicCommand(input)
      if (command !== '/history') {
        return null
      }

      return {
        id: 'history',
        group: 'basic',
        raw: command,
      }
    },
    execute: executeStudioHistoryCommand,
  },
  {
    id: 'new-session',
    group: 'basic',
    scope: 'global',
    presentation: {
      trigger: '/new',
      titleKey: 'studio.command.newTitle',
      descriptionKey: 'studio.command.newDescription',
      aliases: ['/reset'],
      keywords: ['fresh', 'session', 'clear'],
    },
    matches(input): StudioNewSessionCommand | null {
      const command = parseExactBasicCommand(input)
      if (command !== '/new') {
        return null
      }

      return {
        id: 'new-session',
        group: 'basic',
        raw: command,
      }
    },
    execute: executeStudioNewSessionCommand,
  },
]
