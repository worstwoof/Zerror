import { randomUUID } from 'node:crypto'
import { createStudioAssistantMessage, createStudioTextPart } from '../../domain/factories'
import type {
  StudioEventBus,
  StudioMessageStore,
  StudioPartStore,
  StudioSessionEvent,
  StudioSessionEventStore,
  StudioTask
} from '../../domain/types'

export function createRenderStatusSessionEvent(input: {
  task: StudioTask
  status: 'queued' | 'running' | 'completed' | 'failed'
  summary: string
}): StudioSessionEvent {
  const timestamp = new Date().toISOString()
  return {
    id: `session_event_${randomUUID()}`,
    sessionId: input.task.sessionId,
    runId: input.task.runId,
    kind: 'render-status',
    status: 'pending',
    title: `Render ${input.status}`,
    summary: input.summary,
    metadata: {
      taskId: input.task.id,
      workId: input.task.workId,
      jobId: input.task.metadata?.jobId,
      renderStatus: input.status,
      eventKey: buildRenderEventKey(input.task, input.status),
      stage: input.task.metadata?.stage,
      bullStatus: input.task.metadata?.bullStatus,
      result: input.task.metadata?.result,
    },
    createdAt: timestamp,
    updatedAt: timestamp,
  }
}

export async function enqueueSessionEvent(input: {
  store: StudioSessionEventStore
  eventBus: StudioEventBus
  event: StudioSessionEvent
}): Promise<StudioSessionEvent> {
  const existing = await findSessionEventByKey(input.store, input.event.sessionId, readEventKey(input.event))
  if (existing) {
    return existing
  }

  const created = await input.store.create(input.event)
  input.eventBus.publish({
    type: 'session_event_queued',
    sessionId: created.sessionId,
    runId: created.runId,
    event: created
  })
  return created
}

export async function listPendingSessionEvents(
  store: StudioSessionEventStore,
  sessionId: string
): Promise<StudioSessionEvent[]> {
  const events = await store.listBySessionId(sessionId)
  return events
    .filter((event) => event.status === 'pending')
    .sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt))
}

export async function consumeSessionEvents(input: {
  store: StudioSessionEventStore
  eventIds: string[]
}): Promise<void> {
  const consumedAt = new Date().toISOString()
  for (const eventId of input.eventIds) {
    await input.store.update(eventId, {
      status: 'consumed',
      consumedAt
    })
  }
}

export async function flushTerminalSessionEventsToAssistant(input: {
  sessionId: string
  sessionEventStore: StudioSessionEventStore
  messageStore: StudioMessageStore
  partStore: StudioPartStore
}): Promise<StudioSessionEvent[]> {
  const pending = await listPendingSessionEvents(input.sessionEventStore, input.sessionId)
  const terminalEvents = pending.filter((event) => {
    const renderStatus = event.metadata?.renderStatus
    return renderStatus === 'completed' || renderStatus === 'failed'
  })

  for (const event of terminalEvents) {
    const assistantMessage = await input.messageStore.createAssistantMessage(
      createStudioAssistantMessage({
        sessionId: input.sessionId,
        agent: 'builder'
      })
    )
    const textPart = createStudioTextPart({
      messageId: assistantMessage.id,
      sessionId: input.sessionId,
      text: `[System Update] ${event.summary}`
    })
    await input.partStore.create(textPart)
    await input.messageStore.updateAssistantMessage(assistantMessage.id, {
      parts: [textPart]
    })
  }

  if (terminalEvents.length) {
    await consumeSessionEvents({
      store: input.sessionEventStore,
      eventIds: terminalEvents.map((event) => event.id)
    })
  }

  return terminalEvents
}

export function summarizeRenderStatusTask(task: StudioTask): string | null {
  const status = task.status
  const jobId = typeof task.metadata?.jobId === 'string' ? task.metadata.jobId : undefined
  if (!jobId) {
    return null
  }

  if (status === 'queued') {
    return `Render queued: ${task.title} (render_job_id: ${jobId})`
  }

  if (status === 'running') {
    return `Render running: ${task.title} (render_job_id: ${jobId})`
  }

  const result = task.metadata?.result
  if (status === 'completed' && result && typeof result === 'object') {
    const data = (result as { data?: Record<string, unknown> }).data ?? {}
    const videoUrl = typeof data.videoUrl === 'string' ? data.videoUrl : undefined
    const imageCount = typeof data.imageCount === 'number' ? data.imageCount : undefined
    const outputDetail = videoUrl
      ? `output: ${videoUrl}`
      : typeof imageCount === 'number'
        ? `image_count: ${imageCount}`
        : 'output ready'
    return `Render completed: ${task.title} (${outputDetail}, render_job_id: ${jobId})`
  }

  if (status === 'failed' && result && typeof result === 'object') {
    const data = (result as { data?: Record<string, unknown> }).data ?? {}
    const error = typeof data.error === 'string' ? data.error : 'Unknown render failure'
    return `Render failed: ${task.title} (error: ${error}, render_job_id: ${jobId})`
  }

  return null
}

export async function syncRenderTaskSessionEvents(input: {
  task: StudioTask
  sessionEventStore: StudioSessionEventStore
  eventBus: StudioEventBus
}): Promise<void> {
  const summary = summarizeRenderStatusTask(input.task)
  if (!summary) {
    return
  }

  const normalizedStatus = toRenderStatus(input.task.status)
  if (!normalizedStatus) {
    return
  }

  await enqueueSessionEvent({
    store: input.sessionEventStore,
    eventBus: input.eventBus,
    event: createRenderStatusSessionEvent({
      task: input.task,
      status: normalizedStatus,
      summary
    })
  })
}

function buildRenderEventKey(task: StudioTask, status: 'queued' | 'running' | 'completed' | 'failed'): string {
  const jobId = typeof task.metadata?.jobId === 'string' ? task.metadata.jobId : 'unknown'
  return `render:${jobId}:${status}`
}

async function findSessionEventByKey(
  store: StudioSessionEventStore,
  sessionId: string,
  eventKey?: string
): Promise<StudioSessionEvent | null> {
  if (!eventKey) {
    return null
  }

  const events = await store.listBySessionId(sessionId)
  return events.find((event) => readEventKey(event) === eventKey) ?? null
}

function readEventKey(event: StudioSessionEvent): string | undefined {
  return typeof event.metadata?.eventKey === 'string' ? event.metadata.eventKey : undefined
}

function toRenderStatus(status: StudioTask['status']): 'queued' | 'running' | 'completed' | 'failed' | null {
  if (status === 'queued' || status === 'running' || status === 'completed' || status === 'failed') {
    return status
  }
  return null
}
