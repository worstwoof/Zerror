import type { StudioRun, StudioRunStore } from '../domain/types'

export class InMemoryStudioRunStore implements StudioRunStore {
  private readonly runs = new Map<string, StudioRun>()

  async create(run: StudioRun): Promise<StudioRun> {
    this.runs.set(run.id, run)
    return run
  }

  async getById(runId: string): Promise<StudioRun | null> {
    return this.runs.get(runId) ?? null
  }

  async update(runId: string, patch: Partial<StudioRun>): Promise<StudioRun | null> {
    const current = this.runs.get(runId)
    if (!current) {
      return null
    }

    const next: StudioRun = {
      ...current,
      ...patch
    }
    this.runs.set(runId, next)
    return next
  }

  async listBySessionId(sessionId: string): Promise<StudioRun[]> {
    return [...this.runs.values()].filter((run) => run.sessionId === sessionId)
  }
}

