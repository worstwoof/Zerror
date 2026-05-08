import type { StudioWork, StudioWorkStore } from '../domain/types'

export class InMemoryStudioWorkStore implements StudioWorkStore {
  private readonly works = new Map<string, StudioWork>()

  async create(work: StudioWork): Promise<StudioWork> {
    this.works.set(work.id, work)
    return work
  }

  async getById(workId: string): Promise<StudioWork | null> {
    return this.works.get(workId) ?? null
  }

  async update(workId: string, patch: Partial<StudioWork>): Promise<StudioWork | null> {
    const current = this.works.get(workId)
    if (!current) {
      return null
    }

    const next: StudioWork = {
      ...current,
      ...patch,
      updatedAt: new Date().toISOString()
    }
    this.works.set(workId, next)
    return next
  }

  async listBySessionId(sessionId: string): Promise<StudioWork[]> {
    return [...this.works.values()].filter((work) => work.sessionId === sessionId)
  }
}
