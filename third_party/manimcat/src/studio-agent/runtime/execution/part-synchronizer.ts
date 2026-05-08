import type {
  StudioAssistantMessage,
  StudioMessagePart,
  StudioMessageStore,
  StudioPartStore
} from '../../domain/types'
import { replaceMessagePart } from '../../domain/factories'

export class StudioPartSynchronizer {
  constructor(
    private readonly messageStore: StudioMessageStore,
    private readonly partStore: StudioPartStore
  ) {}

  async appendPart(
    assistantMessage: StudioAssistantMessage,
    part: StudioMessagePart
  ): Promise<StudioMessagePart> {
    await this.partStore.create(part)

    const currentMessage = await this.messageStore.getById(assistantMessage.id)
    const currentParts = currentMessage && currentMessage.role === 'assistant'
      ? currentMessage.parts
      : assistantMessage.parts

    const refreshed = replaceMessagePart(currentParts, part)
    const updated = await this.messageStore.updateAssistantMessage(assistantMessage.id, {
      parts: refreshed
    })
    assistantMessage.parts = updated?.parts ?? refreshed
    return part
  }

  async updatePart(partId: string, patch: Partial<StudioMessagePart> | StudioMessagePart): Promise<void> {
    const current = await this.partStore.getById(partId)
    if (!current) {
      return
    }

    const next = {
      ...current,
      ...patch
    } as StudioMessagePart

    await this.partStore.update(partId, next)
    const message = await this.messageStore.getById(current.messageId)
    if (!message || message.role !== 'assistant') {
      return
    }

    const refreshed = replaceMessagePart(message.parts, next)
    await this.messageStore.updateAssistantMessage(message.id, {
      parts: refreshed
    })
  }
}

