import type { StudioMessage } from '../protocol/studio-agent-types'
import {
  areAssistantMessagesEquivalent,
  buildAssistantToolSignature,
  extractAssistantComparableText,
} from './utils'

export function shouldHideDuplicateOptimisticAssistant(messages: StudioMessage[], index: number): boolean {
  const message = messages[index]
  if (!message || message.role !== 'assistant') {
    return false
  }

  if (!hasAssistantDedupSignal(message)) {
    return false
  }

  return messages.slice(index + 1).some((candidate) => (
    candidate.role === 'assistant'
    && areAssistantMessagesEquivalent(message, candidate)
  ))
}

function hasAssistantDedupSignal(message: Extract<StudioMessage, { role: 'assistant' }>): boolean {
  return Boolean(extractAssistantComparableText(message) || buildAssistantToolSignature(message))
}
