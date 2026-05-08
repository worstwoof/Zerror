import type { StudioMessagePart, StudioPartStore } from '../domain/types'

export class InMemoryStudioPartStore implements StudioPartStore {
  private readonly parts = new Map<string, StudioMessagePart>()

  async create(part: StudioMessagePart): Promise<StudioMessagePart> {
    this.parts.set(part.id, part)
    return part
  }

  async update(partId: string, patch: Partial<StudioMessagePart>): Promise<StudioMessagePart | null> {
    const current = this.parts.get(partId)
    if (!current) {
      return null
    }

    const next = {
      ...current,
      ...patch
    } as StudioMessagePart

    this.parts.set(partId, next)
    return next
  }

  async getById(partId: string): Promise<StudioMessagePart | null> {
    return this.parts.get(partId) ?? null
  }

  async listByMessageId(messageId: string): Promise<StudioMessagePart[]> {
    return [...this.parts.values()].filter((part) => part.messageId === messageId)
  }
}
