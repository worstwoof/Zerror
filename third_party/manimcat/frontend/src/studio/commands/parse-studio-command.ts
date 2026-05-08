import { allStudioCommands } from './all-commands'
import type { StudioParsedCommand } from './types'

export function parseStudioCommand(input: string): StudioParsedCommand | null {
  for (const command of allStudioCommands) {
    const parsed = command.matches(input)
    if (parsed) {
      return parsed
    }
  }

  return null
}

