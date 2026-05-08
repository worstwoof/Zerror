import type { StudioAgentEvent, StudioEventBus } from '../domain/types'

export type StudioEventListener = (event: StudioAgentEvent) => void

export class InMemoryStudioEventBus implements StudioEventBus {
  private readonly events: StudioAgentEvent[] = []
  private readonly listeners = new Set<StudioEventListener>()

  publish(event: StudioAgentEvent): void {
    this.events.push(event)
    for (const listener of this.listeners) {
      listener(event)
    }
  }

  list(): StudioAgentEvent[] {
    return [...this.events]
  }

  clear(): void {
    this.events.length = 0
  }

  subscribe(listener: StudioEventListener): () => void {
    this.listeners.add(listener)
    return () => {
      this.listeners.delete(listener)
    }
  }
}
