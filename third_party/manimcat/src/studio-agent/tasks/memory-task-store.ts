import type { StudioTask, StudioTaskStore } from '../domain/types'

export class InMemoryStudioTaskStore implements StudioTaskStore {
  private readonly tasks = new Map<string, StudioTask>()

  async create(task: StudioTask): Promise<StudioTask> {
    this.tasks.set(task.id, task)
    return task
  }

  async getById(taskId: string): Promise<StudioTask | null> {
    return this.tasks.get(taskId) ?? null
  }

  async update(taskId: string, patch: Partial<StudioTask>): Promise<StudioTask | null> {
    const current = this.tasks.get(taskId)
    if (!current) {
      return null
    }

    const next: StudioTask = {
      ...current,
      ...patch,
      updatedAt: new Date().toISOString()
    }
    this.tasks.set(taskId, next)
    return next
  }

  async listBySessionId(sessionId: string): Promise<StudioTask[]> {
    return [...this.tasks.values()].filter((task) => task.sessionId === sessionId)
  }
}

