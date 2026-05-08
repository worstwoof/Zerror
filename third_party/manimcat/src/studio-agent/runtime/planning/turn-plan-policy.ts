import type { StudioAgentType, StudioKind, StudioPlannedToolCall, StudioWorkContext } from '../../domain/types'
import { createPlannedCallId, parseStudioTurnIntent } from './turn-plan-intent'

export type StudioTurnPolicyDecisionMode = 'direct-tool' | 'none'

export interface StudioTurnPolicyDecision {
  mode: StudioTurnPolicyDecisionMode
  toolCalls: StudioPlannedToolCall[]
}

interface ResolveStudioTurnPolicyInput {
  agentType: StudioAgentType
  studioKind?: StudioKind
  inputText: string
  supportedToolNames: Set<string>
  workContext?: StudioWorkContext
}

export function resolveStudioTurnPolicy(input: ResolveStudioTurnPolicyInput): StudioTurnPolicyDecision {
  const intent = parseStudioTurnIntent(input.inputText)
  if (intent.directTool && input.supportedToolNames.has(intent.directTool.toolName)) {
    return {
      mode: 'direct-tool',
      toolCalls: [
        {
          toolName: intent.directTool.toolName,
          callId: createPlannedCallId(intent.directTool.toolName),
          input: intent.directTool.input
        }
      ]
    }
  }

  return {
    mode: 'none',
    toolCalls: []
  }
}
