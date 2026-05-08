import type { StudioCommandContext, StudioImageInputCommand } from '../types'

export function executeStudioImageInputCommand(
  _command: StudioImageInputCommand,
  context: StudioCommandContext,
) {
  context.openImageInputMode?.()
}
