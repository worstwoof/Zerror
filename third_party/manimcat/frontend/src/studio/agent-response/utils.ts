import type { StudioMessage } from '../protocol/studio-agent-types'

export function isOptimisticLocalMessageId(messageId: string): boolean {
  return messageId.startsWith('local-user-') || messageId.startsWith('local-assistant-')
}

export function isNearSameTimestamp(left: string, right: string, thresholdMs = 5000): boolean {
  return Math.abs(new Date(left).getTime() - new Date(right).getTime()) < thresholdMs
}

export function isEmptyAssistantPlaceholder(message: Extract<StudioMessage, { role: 'assistant' }>): boolean {
  return !message.parts.some((part) => {
    if (part.type === 'tool') {
      return true
    }

    return Boolean(part.text.trim())
  })
}

export function extractAssistantComparableText(message: Extract<StudioMessage, { role: 'assistant' }>): string {
  return message.parts
    .filter((part) => part.type === 'text' || part.type === 'reasoning')
    .map((part) => part.text.trim())
    .filter(Boolean)
    .join('\n')
    .trim()
}

export function doAssistantMessagesLookEquivalent(
  left: Extract<StudioMessage, { role: 'assistant' }> | string,
  right: Extract<StudioMessage, { role: 'assistant' }> | string,
): boolean {
  const leftText = typeof left === 'string' ? left.trim() : extractAssistantComparableText(left)
  const rightText = typeof right === 'string' ? right.trim() : extractAssistantComparableText(right)
  if (!leftText || !rightText) {
    return false
  }

  return leftText === rightText || leftText.includes(rightText) || rightText.includes(leftText)
}

export function shouldMatchOptimisticAssistantMessage(
  optimisticMessage: Extract<StudioMessage, { role: 'assistant' }>,
  serverMessage: Extract<StudioMessage, { role: 'assistant' }>,
  thresholdMs?: number,
): boolean {
  if (typeof thresholdMs === 'number' && !isNearSameTimestamp(serverMessage.createdAt, optimisticMessage.createdAt, thresholdMs)) {
    return false
  }

  if (new Date(serverMessage.createdAt).getTime() < new Date(optimisticMessage.createdAt).getTime()) {
    return false
  }

  if (isEmptyAssistantPlaceholder(optimisticMessage)) {
    return true
  }

  return doAssistantMessagesLookEquivalent(optimisticMessage, serverMessage)
}

export function buildAssistantToolSignature(message: Extract<StudioMessage, { role: 'assistant' }>): string {
  return message.parts
    .filter((part) => part.type === 'tool')
    .map((part) => {
      const input = 'input' in part.state && part.state.input ? JSON.stringify(part.state.input) : ''
      return `${part.tool}:${part.state.status}:${input}`
    })
    .join('|')
}

export function normalizeComparableText(text: string): string {
  const normalized = text.trim()
  if (!normalized) {
    return ''
  }

  return normalized
    .replace(/\r\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

export function areAssistantMessagesEquivalent(
  source: Extract<StudioMessage, { role: 'assistant' }>,
  candidate: Extract<StudioMessage, { role: 'assistant' }>,
): boolean {
  const sourceToolSignature = buildAssistantToolSignature(source)
  const candidateToolSignature = buildAssistantToolSignature(candidate)
  if (sourceToolSignature !== candidateToolSignature) {
    return false
  }

  return doAssistantMessagesLookEquivalent(
    normalizeComparableText(extractAssistantComparableText(source)),
    normalizeComparableText(extractAssistantComparableText(candidate)),
  )
}
