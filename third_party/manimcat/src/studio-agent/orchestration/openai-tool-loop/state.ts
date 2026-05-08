import { buildStudioRunMetadataPatch, readStudioRunAutonomyMetadata } from '../../runs/autonomy-policy'
import type { StudioLoopAutonomy, StudioOpenAIToolLoopInput } from './types'

export class StudioLoopCheckpointManager {
  private autonomy: StudioLoopAutonomy

  constructor(private readonly input: StudioOpenAIToolLoopInput) {
    this.autonomy = readStudioRunAutonomyMetadata(input.run.metadata)
  }

  async beginStep() {
    return this.apply(buildStudioRunMetadataPatch({
      metadata: this.input.run.metadata,
      stepCount: this.autonomy.stepCount + 1,
    }))
  }

  async markSuccess() {
    return this.apply(buildStudioRunMetadataPatch({
      metadata: this.input.run.metadata,
      stepCount: this.autonomy.stepCount,
      consecutiveFailures: 0,
      stopReason: null,
    }))
  }

  async markFailure(message: string) {
    return this.apply(buildStudioRunMetadataPatch({
      metadata: this.input.run.metadata,
      stepCount: this.autonomy.stepCount,
      consecutiveFailures: this.autonomy.consecutiveFailures + 1,
      stopReason: message,
    }))
  }

  async markStopped(message: string) {
    return this.apply(buildStudioRunMetadataPatch({
      metadata: this.input.run.metadata,
      stepCount: this.autonomy.stepCount,
      consecutiveFailures: this.autonomy.consecutiveFailures,
      stopReason: message,
    }))
  }

  private async apply(metadata: Record<string, unknown>) {
    await this.input.onCheckpoint?.({ metadata })
    this.input.run.metadata = metadata
    this.autonomy = readStudioRunAutonomyMetadata(metadata)
    return this.autonomy
  }
}
