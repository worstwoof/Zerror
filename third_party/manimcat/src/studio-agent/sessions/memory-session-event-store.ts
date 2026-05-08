import type { StudioSessionEvent, StudioSessionEventStore } from '../domain/types'

export class InMemoryStudioSessionEventStore implements StudioSessionEventStore {
  private readonly events = new Map<string, StudioSessionEvent>()

  async create(event: StudioSessionEvent): Promise<StudioSessionEvent> {
    this.events.set(event.id, event)
    return event
  }

  async getById(eventId: string): Promise<StudioSessionEvent | null> {
    return this.events.get(eventId) ?? null
  }

  async update(eventId: string, patch: Partial<StudioSessionEvent>): Promise<StudioSessionEvent | null> {
    const current = this.events.get(eventId)
    if (!current) {
      return null
    }

    const next: StudioSessionEvent = {
      ...current,
      ...patch,
      updatedAt: new Date().toISOString()
    }

    this.events.set(eventId, next)
    return next
  }

  async listBySessionId(sessionId: string): Promise<StudioSessionEvent[]> {
    return [...this.events.values()].filter((event) => event.sessionId === sessionId)
  }
}
