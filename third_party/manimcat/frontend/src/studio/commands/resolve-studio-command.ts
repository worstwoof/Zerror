import { allStudioCommands } from './all-commands'
import { parseStudioCommand } from './parse-studio-command'

export function resolveStudioCommand(input: string) {
  const command = parseStudioCommand(input)
  if (!command) {
    return null
  }

  const definition = allStudioCommands.find((item) => (
    item.id === command.id && item.matches(command.raw) !== null
  ))

  if (!definition) {
    return null
  }

  return { command, definition }
}
