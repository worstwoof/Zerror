import type { StudioAgentType, StudioKind } from '../../domain/types'
import type { StudioTurnPolicyDecision } from './turn-plan-policy'
import { getStudioExecutionPolicy } from '../../orchestration/studio-execution-policy'

export function buildAgentAssistantText(input: {
  agentType: StudioAgentType
  studioKind?: StudioKind
  inputText: string
  policyDecision: StudioTurnPolicyDecision
}): string {
  return buildBuilderText(input.policyDecision, input.studioKind)
}

function buildBuilderText(
  policyDecision: StudioTurnPolicyDecision,
  studioKind?: StudioKind
): string {
  const policy = getStudioExecutionPolicy(studioKind ?? 'manim')

  switch (policyDecision.mode) {
    case 'direct-tool':
      if (policyDecision.toolCalls[0]) {
        return policy.builderDirectToolText(policyDecision.toolCalls[0].toolName)
      }
      return policy.builderDirectToolText('tool')
    case 'none':
    default:
      return policy.builderNoPlanText(false)
  }
}
