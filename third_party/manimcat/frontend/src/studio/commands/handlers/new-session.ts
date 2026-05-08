import type { StudioCommandContext, StudioNewSessionCommand } from '../types'

export async function executeStudioNewSessionCommand(
  _command: StudioNewSessionCommand,
  context: StudioCommandContext,
) {
  await context.createSession()
}

