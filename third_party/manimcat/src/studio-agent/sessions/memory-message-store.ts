import type {
  StudioAssistantMessage,
  StudioMessage,
  StudioMessageStore,
  StudioUserMessage
} from '../domain/types'

export class InMemoryStudioMessageStore implements StudioMessageStore {
  private readonly messages = new Map<string, StudioMessage>()

  async createAssistantMessage(message: StudioAssistantMessage): Promise<StudioAssistantMessage> {
    this.messages.set(message.id, message)
    return message
  }

  async createUserMessage(message: StudioUserMessage): Promise<StudioUserMessage> {
    this.messages.set(message.id, message)
    return message
  }

  async getById(messageId: string): Promise<StudioMessage | null> {
    return this.messages.get(messageId) ?? null
  }

  async listBySessionId(sessionId: string): Promise<StudioMessage[]> {
    return [...this.messages.values()].filter((message) => message.sessionId === sessionId)
  }

  async updateAssistantMessage(
    messageId: string,
    patch: Partial<Omit<StudioAssistantMessage, 'id' | 'sessionId' | 'role'>>
  ): Promise<StudioAssistantMessage | null> {
    const current = this.messages.get(messageId)
    if (!current || current.role !== 'assistant') {
      return null
    }

    const next: StudioAssistantMessage = {
      ...current,
      ...patch,
      updatedAt: new Date().toISOString()
    }

    this.messages.set(messageId, next)
    return next
  }
}

