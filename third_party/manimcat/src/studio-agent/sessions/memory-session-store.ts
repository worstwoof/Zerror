import type { StudioSession, StudioSessionStore } from '../domain/types'

export class InMemoryStudioSessionStore implements StudioSessionStore {
  private readonly sessions = new Map<string, StudioSession>()

  async create(session: StudioSession): Promise<StudioSession> {
    this.sessions.set(session.id, session)
    return session
  }

  async getById(sessionId: string): Promise<StudioSession | null> {
    return this.sessions.get(sessionId) ?? null
  }

  async update(sessionId: string, patch: Partial<StudioSession>): Promise<StudioSession | null> {
    const current = this.sessions.get(sessionId)
    if (!current) {
      return null
    }

    const next: StudioSession = {
      ...current,
      ...patch,
      updatedAt: new Date().toISOString()
    }
    this.sessions.set(sessionId, next)
    return next
  }

  async listChildren(parentSessionId: string): Promise<StudioSession[]> {
    return [...this.sessions.values()].filter((session) => session.parentSessionId === parentSessionId)
  }
}

