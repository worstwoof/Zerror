import type { StudioSession } from '../protocol/studio-agent-types'
import { useStudioCommandRunner } from './use-studio-command-runner'

interface UseStudioCommandControlsInput {
  session: StudioSession | null
  onRun: (inputText: string) => Promise<void>
  onOpenHistory: () => void
  onCreateSession: () => Promise<void>
}

export function useStudioCommandControls({
  session,
  onRun,
  onOpenHistory,
  onCreateSession,
}: UseStudioCommandControlsInput) {
  const submitInput = useStudioCommandRunner({
    session,
    onRun,
    openHistory: onOpenHistory,
    createSession: onCreateSession,
  })

  return {
    submitInput,
  }
}
