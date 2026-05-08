import type { StudioMessage } from '../../protocol/studio-agent-types'

export interface StudioCommandPanelSnapshot {
  messages: StudioMessage[]
  isBusy: boolean
  latestAssistantText: string
  animatedAssistantText: string
}

type Listener = () => void

export interface StudioCommandPanelStore {
  getSnapshot(): StudioCommandPanelSnapshot
  setSnapshot(snapshot: StudioCommandPanelSnapshot): void
  subscribe(listener: Listener): () => void
}

export function createStudioCommandPanelStore(
  initialSnapshot: StudioCommandPanelSnapshot,
): StudioCommandPanelStore {
  let snapshot = initialSnapshot
  const listeners = new Set<Listener>()

  return {
    getSnapshot() {
      return snapshot
    },
    setSnapshot(nextSnapshot) {
      if (
        snapshot.messages === nextSnapshot.messages
        && snapshot.isBusy === nextSnapshot.isBusy
        && snapshot.latestAssistantText === nextSnapshot.latestAssistantText
        && snapshot.animatedAssistantText === nextSnapshot.animatedAssistantText
      ) {
        return
      }

      snapshot = nextSnapshot
      listeners.forEach((listener) => listener())
    },
    subscribe(listener) {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
  }
}
