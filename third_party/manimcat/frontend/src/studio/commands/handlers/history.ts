import type { StudioCommandContext, StudioHistoryCommand } from '../types'

export function executeStudioHistoryCommand(_command: StudioHistoryCommand, context: StudioCommandContext) {
  context.openHistory()
}

