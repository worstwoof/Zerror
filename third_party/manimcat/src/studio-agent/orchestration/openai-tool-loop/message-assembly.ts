import type { StudioProcessorStreamEvent } from '../../domain/types'
import { toAssistantConversationMessage } from '../studio-provider-message'
import type { StudioLoopRuntime, StudioLoopStepResult } from './types'

export function appendStudioAssistantConversationTurn(
  runtime: StudioLoopRuntime,
  result: StudioLoopStepResult
) {
  runtime.conversation.push(
    toAssistantConversationMessage(result.message, result.assistantText, result.toolCalls)
  )
}

export async function* emitStudioAssistantText(text: string): AsyncGenerator<StudioProcessorStreamEvent> {
  if (!text) {
    return
  }

  yield { type: 'text-start' }
  yield { type: 'text-delta', text }
  yield { type: 'text-end' }
}

export function normalizeStudioAssistantText(content: unknown): string {
  if (typeof content === 'string') {
    return content.trim()
  }

  if (!Array.isArray(content)) {
    return ''
  }

  return content
    .map((part) => {
      if (!part || typeof part !== 'object') {
        return ''
      }
      const typedPart = part as { type?: unknown; text?: unknown }
      return typedPart.type === 'text' && typeof typedPart.text === 'string' ? typedPart.text : ''
    })
    .join('')
    .trim()
}
