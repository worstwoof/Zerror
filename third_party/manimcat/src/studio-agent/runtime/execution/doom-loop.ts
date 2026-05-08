import type {
  StudioAssistantMessage,
  StudioPartStore
} from '../../domain/types'

const DOOM_LOOP_THRESHOLD = 3

export async function isDoomLoop(input: {
  assistantMessage: StudioAssistantMessage
  partStore: StudioPartStore
  toolName: string
  toolInput: Record<string, unknown>
}): Promise<boolean> {
  const latestParts = await input.partStore.listByMessageId(input.assistantMessage.id)
  const lastThree = latestParts.slice(-DOOM_LOOP_THRESHOLD)

  return (
    lastThree.length === DOOM_LOOP_THRESHOLD &&
    lastThree.every(
      (part) =>
        part.type === 'tool' &&
        part.tool === input.toolName &&
        JSON.stringify(part.state.input) === JSON.stringify(input.toolInput)
    )
  )
}
