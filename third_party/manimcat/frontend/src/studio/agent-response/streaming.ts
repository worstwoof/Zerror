import type { StudioExternalEvent } from '../protocol/studio-agent-events'
import type { StudioAssistantMessage } from '../protocol/studio-agent-types'
import { upsertMessages } from '../store/studio-session-store'
import type { StudioSessionState } from '../store/studio-types'
import { debugStudioMessages } from './debug'

export function applyAssistantTextEvent(
  state: StudioSessionState,
  runId: string,
  text: string,
  messageId?: string,
): StudioSessionState {
  const assistantMessageId = resolveAssistantMessageId(state, runId, messageId)
  debugStudioMessages('assistant-text-event', {
    runId,
    assistantMessageId,
    requestedMessageId: messageId,
    textLength: text.length,
  })
  const entities = assistantMessageId
    ? upsertMessages(state.entities, [buildStreamingAssistantMessage(state, assistantMessageId, text)])
    : state.entities

  return {
    ...state,
    entities,
    runtime: {
      ...state.runtime,
      activeRunId: runId,
      submitting: false,
      assistantTextByRunId: {
        ...state.runtime.assistantTextByRunId,
        [runId]: text,
      },
    },
  }
}

export function applyToolInputStartEvent(
  state: StudioSessionState,
  runId: string,
  callId: string,
  toolName: string,
  raw: string,
  messageId?: string,
): StudioSessionState {
  const assistantMessageId = resolveAssistantMessageId(state, runId, messageId)
  if (!assistantMessageId) {
    return state
  }

  const message = ensureAssistantMessage(state, assistantMessageId)
  const nextPart = {
    id: `${assistantMessageId}-${callId}`,
    messageId: assistantMessageId,
    sessionId: message.sessionId,
    type: 'tool' as const,
    tool: toolName,
    callId,
    state: {
      status: 'pending' as const,
      input: {},
      raw,
    },
  }

  return {
    ...state,
    entities: upsertMessages(state.entities, [withUpdatedAssistantParts(message, replaceToolPart(message.parts, nextPart))]),
  }
}

export function applyToolCallEvent(
  state: StudioSessionState,
  runId: string,
  callId: string,
  toolName: string,
  input: Record<string, unknown>,
  messageId?: string,
): StudioSessionState {
  const assistantMessageId = resolveAssistantMessageId(state, runId, messageId)
  if (!assistantMessageId) {
    return state
  }

  const message = ensureAssistantMessage(state, assistantMessageId)
  const existingPart = findToolPart(message.parts, callId)
  const nextPart = {
    id: existingPart?.id ?? `${assistantMessageId}-${callId}`,
    messageId: assistantMessageId,
    sessionId: message.sessionId,
    type: 'tool' as const,
    tool: toolName,
    callId,
    state: {
      status: 'running' as const,
      input,
      title: undefined,
      metadata: undefined,
      time: { start: Date.now() },
    },
  }

  return {
    ...state,
    entities: upsertMessages(state.entities, [withUpdatedAssistantParts(message, replaceToolPart(message.parts, nextPart))]),
  }
}

export function applyToolResultEvent(
  state: StudioSessionState,
  runId: string,
  callId: string,
  toolName: string,
  result: Extract<StudioExternalEvent, { type: 'tool.result' }>['properties'],
  messageId?: string,
): StudioSessionState {
  const assistantMessageId = resolveAssistantMessageId(state, runId, messageId)
  if (!assistantMessageId) {
    return state
  }

  const message = ensureAssistantMessage(state, assistantMessageId)
  const existingPart = findToolPart(message.parts, callId)
  const runningInput = existingPart?.type === 'tool' && 'input' in existingPart.state ? existingPart.state.input : {}
  const nextPart = {
    id: existingPart?.id ?? `${assistantMessageId}-${callId}`,
    messageId: assistantMessageId,
    sessionId: message.sessionId,
    type: 'tool' as const,
    tool: toolName,
    callId,
    state: result.status === 'failed'
      ? {
        status: 'error' as const,
        input: runningInput,
        error: result.error ?? `Tool failed: ${toolName}`,
        metadata: result.metadata,
        time: { start: Date.now(), end: Date.now() },
      }
      : {
        status: 'completed' as const,
        input: runningInput,
        output: result.output ?? '',
        title: result.title ?? `Completed ${toolName}`,
        metadata: result.metadata,
        attachments: result.attachments,
        time: { start: Date.now(), end: Date.now() },
      },
  }

  return {
    ...state,
    entities: upsertMessages(state.entities, [withUpdatedAssistantParts(message, replaceToolPart(message.parts, nextPart))]),
  }
}

function buildStreamingAssistantMessage(
  state: StudioSessionState,
  messageId: string,
  text: string,
): StudioAssistantMessage {
  const existing = state.entities.messagesById[messageId]
  if (existing?.role === 'assistant') {
    const toolAndReasoningParts = existing.parts.filter((part) => part.type !== 'text')
    return {
      ...existing,
      updatedAt: new Date().toISOString(),
      parts: [
        {
          id: `${messageId}-text`,
          messageId,
          sessionId: existing.sessionId,
          type: 'text',
          text,
        },
        ...toolAndReasoningParts,
      ],
    }
  }

  const sessionId = state.entities.session?.id ?? ''
  return {
    id: messageId,
    sessionId,
    role: 'assistant',
    agent: 'builder',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    parts: [
      {
        id: `${messageId}-text`,
        messageId,
        sessionId,
        type: 'text',
        text,
      },
    ],
  }
}

function ensureAssistantMessage(state: StudioSessionState, messageId: string): StudioAssistantMessage {
  const existing = state.entities.messagesById[messageId]
  if (existing?.role === 'assistant') {
    return existing
  }

  const sessionId = state.entities.session?.id ?? ''
  return {
    id: messageId,
    sessionId,
    role: 'assistant',
    agent: 'builder',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    parts: [],
  }
}

function findToolPart(parts: StudioAssistantMessage['parts'], callId: string) {
  return [...parts].reverse().find((part) => part.type === 'tool' && part.callId === callId) ?? null
}

function replaceToolPart(parts: StudioAssistantMessage['parts'], nextPart: Extract<StudioAssistantMessage['parts'][number], { type: 'tool' }>) {
  const index = parts.findIndex((part) => part.type === 'tool' && part.callId === nextPart.callId)
  if (index === -1) {
    return [...parts, nextPart]
  }

  const nextParts = [...parts]
  nextParts[index] = nextPart
  return nextParts
}

function withUpdatedAssistantParts(message: StudioAssistantMessage, parts: StudioAssistantMessage['parts']): StudioAssistantMessage {
  return {
    ...message,
    updatedAt: new Date().toISOString(),
    parts,
  }
}

function resolveAssistantMessageId(
  state: StudioSessionState,
  runId: string,
  messageId?: string,
): string | null {
  if (messageId) {
    return messageId
  }

  return state.runtime.optimisticAssistantMessageIdByRunId[runId] ?? null
}
