import { shouldHideDuplicateOptimisticAssistant } from '../../agent-response/visibility'
import type { StudioMessage } from '../../protocol/studio-agent-types'
import type { StudioCommandPanelSnapshot } from './store'

export interface StudioCommandRowView {
  message: StudioMessage | null
  isStreamingTarget: boolean
  streamedText: string
  showCaret: boolean
}

const emptyVisibleMessageIds: string[] = []

let visibleMessageIdsCache = {
  messages: null as StudioMessage[] | null,
  isBusy: false,
  ids: emptyVisibleMessageIds,
}

export function selectVisibleMessageIds(snapshot: StudioCommandPanelSnapshot): string[] {
  if (
    visibleMessageIdsCache.messages === snapshot.messages
    && visibleMessageIdsCache.isBusy === snapshot.isBusy
  ) {
    return visibleMessageIdsCache.ids
  }

  const ids = snapshot.messages
    .filter((message, index, messages) => {
      if (message.role === 'user') {
        return true
      }

      if (shouldHideDuplicateOptimisticAssistant(messages, index)) {
        return false
      }

      return shouldRenderAssistantMessage(message, {
        isLast: index === messages.length - 1,
        isBusy: snapshot.isBusy,
      })
    })
    .map((message) => message.renderId ?? message.id)

  visibleMessageIdsCache = {
    messages: snapshot.messages,
    isBusy: snapshot.isBusy,
    ids,
  }

  return ids
}

export function selectRowView(
  snapshot: StudioCommandPanelSnapshot,
  messageId: string,
): StudioCommandRowView {
  const message = snapshot.messages.find((entry) => (entry.renderId ?? entry.id) === messageId) ?? null
  if (!message) {
    return {
      message: null,
      isStreamingTarget: false,
      streamedText: '',
      showCaret: false,
    }
  }

  const lastMessage = snapshot.messages.at(-1) ?? null
  const streamIntoLastAssistant = Boolean(
    lastMessage
    && lastMessage.role === 'assistant'
    && (snapshot.isBusy || snapshot.latestAssistantText || snapshot.animatedAssistantText)
  )
  const isStreamingTarget = streamIntoLastAssistant && lastMessage?.id === message.id

  return {
    message,
    isStreamingTarget,
    streamedText: isStreamingTarget ? snapshot.animatedAssistantText : '',
    showCaret: Boolean(
      isStreamingTarget
      && (snapshot.isBusy || snapshot.latestAssistantText !== snapshot.animatedAssistantText)
    ),
  }
}

function shouldRenderAssistantMessage(
  message: Extract<StudioMessage, { role: 'assistant' }>,
  options: { isLast: boolean; isBusy: boolean },
): boolean {
  const hasRenderableText = message.parts.some((part) => (
    (part.type === 'text' || part.type === 'reasoning') && part.text.trim()
  ))
  const hasToolParts = message.parts.some((part) => part.type === 'tool')

  if (hasRenderableText || hasToolParts) {
    return true
  }

  return options.isLast && options.isBusy
}
