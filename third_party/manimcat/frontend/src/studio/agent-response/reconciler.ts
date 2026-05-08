import type { StudioMessage, StudioRun } from '../protocol/studio-agent-types'
import { debugStudioMessages } from './debug'
import {
  areAssistantMessagesEquivalent,
  isEmptyAssistantPlaceholder,
  isNearSameTimestamp,
  isOptimisticLocalMessageId,
  shouldMatchOptimisticAssistantMessage,
} from './utils'

export function mergeMessages(
  current: Record<string, StudioMessage>,
  incoming: StudioMessage[],
): Record<string, StudioMessage> {
  const merged = mergeMessageRecord(current, incoming)
  const incomingServerUserMessages = incoming.filter((message): message is Extract<StudioMessage, { role: 'user' }> => {
    return message.role === 'user' && !isOptimisticLocalMessageId(message.id)
  })
  const incomingServerAssistantMessages = incoming.filter((message): message is Extract<StudioMessage, { role: 'assistant' }> => {
    return message.role === 'assistant' && !isOptimisticLocalMessageId(message.id)
  })

  if (incomingServerUserMessages.length > 0) {
    for (const [messageId, message] of Object.entries(merged)) {
      if (message.role !== 'user' || !isOptimisticLocalMessageId(messageId)) {
        continue
      }

      const matchedServerMessage = incomingServerUserMessages.find((serverMessage) => (
        serverMessage.text === message.text && isNearSameTimestamp(serverMessage.createdAt, message.createdAt)
      ))

      if (matchedServerMessage) {
        debugStudioMessages('merge-user-message', {
          optimisticMessageId: messageId,
          serverMessageId: matchedServerMessage.id,
          keptRenderId: message.renderId ?? message.id,
        })
        merged[matchedServerMessage.id] = {
          ...matchedServerMessage,
          renderId: message.renderId ?? message.id,
          createdAt: message.createdAt,
        }
        delete merged[messageId]
      }
    }
  }

  if (incomingServerAssistantMessages.length > 0) {
    const usedAssistantMessageIds = new Set<string>()

    for (const [messageId, message] of Object.entries(merged)) {
      if (message.role !== 'assistant' || !isOptimisticLocalMessageId(messageId)) {
        continue
      }

      const matchedServerMessage = incomingServerAssistantMessages.find((serverMessage) => {
        if (usedAssistantMessageIds.has(serverMessage.id)) {
          return false
        }

        return shouldMatchOptimisticAssistantMessage(message, serverMessage, 30000)
      })

      if (matchedServerMessage) {
        usedAssistantMessageIds.add(matchedServerMessage.id)
        debugStudioMessages('merge-assistant-message-primary', {
          optimisticMessageId: messageId,
          serverMessageId: matchedServerMessage.id,
          keptRenderId: message.renderId ?? message.id,
          optimisticCreatedAt: message.createdAt,
          serverCreatedAt: matchedServerMessage.createdAt,
          optimisticEmpty: isEmptyAssistantPlaceholder(message),
        })
        merged[matchedServerMessage.id] = {
          ...matchedServerMessage,
          renderId: message.renderId ?? message.id,
          createdAt: message.createdAt,
        }
        delete merged[messageId]
      }
    }

    const remainingOptimisticAssistantEntries = Object.entries(merged)
      .filter((entry): entry is [string, Extract<StudioMessage, { role: 'assistant' }>] => {
        const [messageId, message] = entry
        return message.role === 'assistant' && isOptimisticLocalMessageId(messageId)
      })
      .sort(([, left], [, right]) => compareByCreatedAt(left, right))

    const remainingServerAssistantMessages = incomingServerAssistantMessages
      .filter((message) => !usedAssistantMessageIds.has(message.id))
      .sort(compareByCreatedAt)

    for (const [messageId, message] of remainingOptimisticAssistantEntries) {
      const matchedServerMessage = remainingServerAssistantMessages.find((serverMessage) => (
        shouldMatchOptimisticAssistantMessage(message, serverMessage)
      ))
      if (!matchedServerMessage) {
        continue
      }

      const matchedIndex = remainingServerAssistantMessages.findIndex((candidate) => candidate.id === matchedServerMessage.id)
      if (matchedIndex >= 0) {
        remainingServerAssistantMessages.splice(matchedIndex, 1)
      }

      merged[matchedServerMessage.id] = {
        ...matchedServerMessage,
        renderId: message.renderId ?? message.id,
        createdAt: message.createdAt,
      }
      debugStudioMessages('merge-assistant-message-fallback', {
        optimisticMessageId: messageId,
        serverMessageId: matchedServerMessage.id,
        keptRenderId: message.renderId ?? message.id,
        optimisticCreatedAt: message.createdAt,
        serverCreatedAt: matchedServerMessage.createdAt,
        optimisticEmpty: isEmptyAssistantPlaceholder(message),
      })
      delete merged[messageId]
    }
  }

  collapseEquivalentAssistantMessages(merged)
  return merged
}

export function preferNewerRun(current: StudioRun, incoming: StudioRun): StudioRun {
  const currentTerminal = isTerminalRunStatus(current.status)
  const incomingTerminal = isTerminalRunStatus(incoming.status)

  if (currentTerminal && !incomingTerminal) {
    return current
  }

  if (!currentTerminal && incomingTerminal) {
    return incoming
  }

  const currentCompletedAt = parseTimestamp(current.completedAt)
  const incomingCompletedAt = parseTimestamp(incoming.completedAt)
  if (currentCompletedAt !== null || incomingCompletedAt !== null) {
    if ((currentCompletedAt ?? -1) > (incomingCompletedAt ?? -1)) {
      return current
    }
    if ((incomingCompletedAt ?? -1) > (currentCompletedAt ?? -1)) {
      return incoming
    }
  }

  return incoming
}

function mergeMessageRecord(current: Record<string, StudioMessage>, items: StudioMessage[]): Record<string, StudioMessage> {
  return items.reduce<Record<string, StudioMessage>>((next, item) => {
    const existing = next[item.id]
    const normalizedIncoming = normalizeMessage(item, existing)
    next[item.id] = shouldPreserveMessageReference(existing, normalizedIncoming) ? existing : normalizedIncoming
    return next
  }, { ...current })
}

function collapseEquivalentAssistantMessages(record: Record<string, StudioMessage>): void {
  const assistantMessages = Object.values(record)
    .filter((message): message is Extract<StudioMessage, { role: 'assistant' }> => message.role === 'assistant')
    .sort(compareByCreatedAt)

  const removedIds = new Set<string>()
  for (let index = 0; index < assistantMessages.length; index += 1) {
    const baseMessage = assistantMessages[index]
    if (removedIds.has(baseMessage.id)) {
      continue
    }

    for (let candidateIndex = index + 1; candidateIndex < assistantMessages.length; candidateIndex += 1) {
      const candidate = assistantMessages[candidateIndex]
      if (removedIds.has(candidate.id)) {
        continue
      }

      if (!isNearSameTimestamp(baseMessage.createdAt, candidate.createdAt, 120000)) {
        continue
      }

      if (!areAssistantMessagesEquivalent(baseMessage, candidate)) {
        continue
      }

      const preferred = preferAssistantMessage(baseMessage, candidate)
      const discarded = preferred.id === baseMessage.id ? candidate : baseMessage
      removedIds.add(discarded.id)
      debugStudioMessages('collapse-assistant-duplicate', {
        keptMessageId: preferred.id,
        removedMessageId: discarded.id,
      })
    }
  }

  for (const removedId of removedIds) {
    delete record[removedId]
  }
}

function preferAssistantMessage(
  left: Extract<StudioMessage, { role: 'assistant' }>,
  right: Extract<StudioMessage, { role: 'assistant' }>,
): Extract<StudioMessage, { role: 'assistant' }> {
  const leftOptimistic = isOptimisticLocalMessageId(left.id)
  const rightOptimistic = isOptimisticLocalMessageId(right.id)
  if (leftOptimistic !== rightOptimistic) {
    return leftOptimistic ? right : left
  }

  const leftUpdated = new Date(left.updatedAt).getTime()
  const rightUpdated = new Date(right.updatedAt).getTime()
  if (leftUpdated !== rightUpdated) {
    return leftUpdated > rightUpdated ? left : right
  }

  return new Date(left.createdAt).getTime() >= new Date(right.createdAt).getTime() ? left : right
}

function shouldPreserveMessageReference(current: StudioMessage | undefined, incoming: StudioMessage): current is StudioMessage {
  if (!current) {
    return false
  }

  if (
    current.id !== incoming.id
    || (current.renderId ?? current.id) !== (incoming.renderId ?? incoming.id)
    || current.role !== incoming.role
    || current.createdAt !== incoming.createdAt
    || current.updatedAt !== incoming.updatedAt
  ) {
    return false
  }

  if (current.role === 'user' && incoming.role === 'user') {
    return current.text === incoming.text
  }

  if (current.role === 'assistant' && incoming.role === 'assistant') {
    return JSON.stringify(current.parts) === JSON.stringify(incoming.parts)
  }

  return false
}

function normalizeMessage(message: StudioMessage, existing?: StudioMessage): StudioMessage {
  const renderId = existing?.renderId ?? message.renderId ?? message.id
  if (message.renderId === renderId) {
    return message
  }
  return {
    ...message,
    renderId,
  }
}

function isTerminalRunStatus(status: StudioRun['status']): boolean {
  return status === 'completed' || status === 'failed' || status === 'cancelled'
}

function parseTimestamp(value?: string): number | null {
  if (!value) {
    return null
  }

  const timestamp = new Date(value).getTime()
  return Number.isFinite(timestamp) ? timestamp : null
}

function compareByCreatedAt<T extends { createdAt: string }>(left: T, right: T): number {
  return new Date(left.createdAt).getTime() - new Date(right.createdAt).getTime()
}
