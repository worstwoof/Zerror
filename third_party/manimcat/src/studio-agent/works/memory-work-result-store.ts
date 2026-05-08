import type { StudioWorkResult, StudioWorkResultStore } from '../domain/types'

export class InMemoryStudioWorkResultStore implements StudioWorkResultStore {
  private readonly results = new Map<string, StudioWorkResult>()

  async create(result: StudioWorkResult): Promise<StudioWorkResult> {
    this.results.set(result.id, result)
    return result
  }

  async getById(resultId: string): Promise<StudioWorkResult | null> {
    return this.results.get(resultId) ?? null
  }

  async update(resultId: string, patch: Partial<StudioWorkResult>): Promise<StudioWorkResult | null> {
    const current = this.results.get(resultId)
    if (!current) {
      return null
    }

    const next: StudioWorkResult = {
      ...current,
      ...patch
    }
    this.results.set(resultId, next)
    return next
  }

  async listByWorkId(workId: string): Promise<StudioWorkResult[]> {
    return [...this.results.values()].filter((result) => result.workId === workId)
  }
}
