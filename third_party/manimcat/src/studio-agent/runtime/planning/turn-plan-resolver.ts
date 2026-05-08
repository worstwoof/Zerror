import type {
  StudioAssistantMessage,
  StudioRun,
  StudioRuntimeTurnPlan,
  StudioSession,
  StudioWorkContext
} from '../../domain/types'

export interface StudioTurnPlanResolveInput {
  projectId: string
  session: StudioSession
  run: StudioRun
  assistantMessage: StudioAssistantMessage
  inputText: string
  workContext?: StudioWorkContext
}

export type StudioTurnPlanResolver = (
  input: StudioTurnPlanResolveInput
) => Promise<StudioRuntimeTurnPlan>
