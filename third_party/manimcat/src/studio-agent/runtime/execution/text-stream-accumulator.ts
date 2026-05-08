import { createStudioTextPart } from '../../domain/factories'
import type {
  StudioAssistantMessage,
  StudioPartStore
} from '../../domain/types'
import { StudioPartSynchronizer } from './part-synchronizer'

export class StudioTextStreamAccumulator {
  constructor(
    private readonly partStore: StudioPartStore,
    private readonly sync: StudioPartSynchronizer
  ) {}

  async startPart(
    assistantMessage: StudioAssistantMessage,
    type: 'text' | 'reasoning'
  ): Promise<string> {
    const part = createStudioTextPart({
      messageId: assistantMessage.id,
      sessionId: assistantMessage.sessionId,
      type
    })
    const created = await this.sync.appendPart(assistantMessage, part)
    return created.id
  }

  async appendDelta(
    partId: string | null,
    text: string,
    expectedType: 'text' | 'reasoning'
  ): Promise<void> {
    if (!partId) {
      return
    }

    const current = await this.partStore.getById(partId)
    if (!current || current.type !== expectedType) {
      return
    }

    await this.sync.updatePart(partId, {
      text: `${current.text}${text}`
    })
  }
}
